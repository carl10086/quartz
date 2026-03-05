# QMD Store 模块源码分析

## 模块设计意图

`store.ts` 是 QMD 的**核心数据访问层**，负责所有数据库操作、搜索功能和文档检索。它的设计遵循以下原则：

1. **单一职责**：所有数据操作集中在此模块，上层（CLI/MCP）只负责格式化输出
2. **可测试性**：通过 `createStore()` 工厂函数创建实例，便于测试时注入不同的数据库路径
3. **类型安全**：完整的 TypeScript 类型定义，确保数据流的类型安全
4. **性能优化**：批量操作、缓存、智能查询优化

## 关键类/函数详细分析

### 1. 智能分块系统 (Smart Chunking)

**文件位置**: `src/store.ts:65-219`

这是 QMD 的核心创新之一，不是简单的固定长度切割，而是寻找 Markdown 结构的自然断点。

```typescript
// 断点模式定义，分数越高越适合作为切割点
export const BREAK_PATTERNS: [RegExp, number, string][] = [
  [/\n#{1}(?!#)/g, 100, 'h1'],     // H1 标题 - 最高分
  [/\n#{2}(?!#)/g, 90, 'h2'],      // H2 标题
  [/\n#{3}(?!#)/g, 80, 'h3'],      // H3 标题
  [/\n#{4}(?!#)/g, 70, 'h4'],      // H4 标题
  [/\n#{5}(?!#)/g, 60, 'h5'],      // H5 标题
  [/\n#{6}(?!#)/g, 50, 'h6'],      // H6 标题
  [/\n```/g, 80, 'codeblock'],     // 代码块边界
  [/\n(?:---|\*\*\*|___)\s*\n/g, 60, 'hr'],  // 水平分隔线
  [/\n\n+/g, 20, 'blank'],         // 空行（段落边界）
  [/\n[-*]\s/g, 5, 'list'],        // 列表项
  [/\n\d+\.\s/g, 5, 'numlist'],    // 有序列表项
  [/\n/g, 1, 'newline'],           // 普通换行
];
```

**核心算法 - findBestCutoff**:

```typescript
export function findBestCutoff(
  breakPoints: BreakPoint[],
  targetCharPos: number,        // 目标切割位置（约900 tokens）
  windowChars: number = CHUNK_WINDOW_CHARS,  // 搜索窗口（约200 tokens）
  decayFactor: number = 0.7,    // 距离衰减因子
  codeFences: CodeFenceRegion[] = []
): number {
  const windowStart = targetCharPos - windowChars;
  let bestScore = -1;
  let bestPos = targetCharPos;

  for (const bp of breakPoints) {
    if (bp.pos < windowStart) continue;
    if (bp.pos > targetCharPos) break;

    // 跳过代码块内的断点
    if (isInsideCodeFence(bp.pos, codeFences)) continue;

    // 距离衰减计算：使用平方距离实现"温和早期，陡峭晚期"的衰减
    const distance = targetCharPos - bp.pos;
    const normalizedDist = distance / windowChars;
    const multiplier = 1.0 - (normalizedDist * normalizedDist) * decayFactor;
    const finalScore = bp.score * multiplier;

    if (finalScore > bestScore) {
      bestScore = finalScore;
      bestPos = bp.pos;
    }
  }

  return bestPos;
}
```

**设计决策分析**:
- **为什么用平方距离衰减？** 让远处的标题仍有一定优势，但近处的低质量断点不会完全没机会
- **为什么代码块要保护？** 代码的完整性很重要，不应该在代码中间切断
- **窗口大小 200 tokens？** 经验值，平衡了切割精度和搜索效率

### 2. 混合搜索流程 (Hybrid Query)

**文件位置**: `src/store.ts:2909-3094`

这是 QMD 最核心的搜索算法，整合了 BM25、向量搜索、查询扩展和重排序。

**完整流程**:

```typescript
export async function hybridQuery(
  store: Store,
  query: string,
  options?: HybridQueryOptions
): Promise<HybridQueryResult[]> {
  // Step 1: BM25 探测 - 强信号时跳过昂贵的 LLM 扩展
  const initialFts = store.searchFTS(query, 20, collection);
  const topScore = initialFts[0]?.score ?? 0;
  const secondScore = initialFts[1]?.score ?? 0;
  const hasStrongSignal = initialFts.length > 0
    && topScore >= STRONG_SIGNAL_MIN_SCORE  // 0.85
    && (topScore - secondScore) >= STRONG_SIGNAL_MIN_GAP;  // 0.15

  // Step 2: 查询扩展（强信号时跳过）
  const expanded = hasStrongSignal ? [] : await store.expandQuery(query);

  // Step 3: 按类型路由搜索
  // - lex 查询 → FTS (BM25)
  // - vec/hyde 查询 → 向量搜索
  // 批量嵌入所有向量查询

  // Step 4: RRF 融合 - 第一个列表（原始查询）获得 2x 权重
  const weights = rankedLists.map((_, i) => i < 2 ? 2.0 : 1.0);
  const fused = reciprocalRankFusion(rankedLists, weights);

  // Step 5: 文档分块，选择最佳块用于重排序
  // 关键优化：重排序块而不是全文，避免 O(tokens) 性能陷阱

  // Step 6: 重排序

  // Step 7: 位置感知分数混合
  // Top 1-3: 75% RRF + 25% 重排序器
  // Top 4-10: 60% RRF + 40% 重排序器
  // Top 11+: 40% RRF + 60% 重排序器
}
```

**关键设计决策**:

1. **强信号检测**: 当 BM25 最高分 ≥0.85 且与第二名差距 ≥0.15 时，直接跳过 LLM 扩展，节省 1-2 秒
2. **批量嵌入**: 所有向量查询一次性嵌入，避免多次模型调用开销
3. **块级重排序**: 不是重排序整篇文档（可能很长），而是只重排序最相关的块
4. **位置感知混合**: 保护高置信度的检索结果不被重排序器过度影响

### 3. Reciprocal Rank Fusion (RRF)

**文件位置**: `src/store.ts:2375-2418`

RRF 是融合多个排序列表的经典算法，QMD 在此基础上增加了权重和奖励机制。

```typescript
export function reciprocalRankFusion(
  resultLists: RankedResult[][],
  weights: number[] = [],
  k: number = 60  // 平滑常数
): RankedResult[] {
  const scores = new Map<string, { result: RankedResult; rrfScore: number; topRank: number }>();

  for (let listIdx = 0; listIdx < resultLists.length; listIdx++) {
    const list = resultLists[listIdx];
    const weight = weights[listIdx] ?? 1.0;

    for (let rank = 0; rank < list.length; rank++) {
      const result = list[rank];
      // RRF 公式: weight / (k + rank + 1)
      const rrfContribution = weight / (k + rank + 1);
      
      // 累加同一文档在不同列表中的得分
      const existing = scores.get(result.file);
      if (existing) {
        existing.rrfScore += rrfContribution;
        existing.topRank = Math.min(existing.topRank, rank);
      } else {
        scores.set(result.file, {
          result,
          rrfScore: rrfContribution,
          topRank: rank,
        });
      }
    }
  }

  // Top-rank 奖励：#1 获得 +0.05，#2-3 获得 +0.02
  for (const entry of scores.values()) {
    if (entry.topRank === 0) {
      entry.rrfScore += 0.05;
    } else if (entry.topRank <= 2) {
      entry.rrfScore += 0.02;
    }
  }

  return Array.from(scores.values())
    .sort((a, b) => b.rrfScore - a.rrfScore)
    .map(e => ({ ...e.result, score: e.rrfScore }));
}
```

**为什么 k=60？**
- k 是平滑常数，防止排名靠后的文档得分过于接近
- 60 是 RRF 论文推荐值，在信息检索领域广泛使用

**为什么给 Top-rank 奖励？**
- 保护原始查询的精确匹配结果
- 防止扩展查询稀释重要结果

### 4. 虚拟路径系统

**文件位置**: `src/store.ts:456-589`

QMD 使用 `qmd://collection/path` 格式统一访问所有文档，解耦了物理路径和逻辑路径。

```typescript
export type VirtualPath = {
  collectionName: string;
  path: string;  // 集合内的相对路径
};

// 解析虚拟路径
export function parseVirtualPath(virtualPath: string): VirtualPath | null {
  const normalized = normalizeVirtualPath(virtualPath);
  const match = normalized.match(/^qmd:\/\/([^\/]+)\/?(.*)$/);
  if (!match?.[1]) return null;
  return {
    collectionName: match[1],
    path: match[2] ?? '',
  };
}

// 构建虚拟路径
export function buildVirtualPath(collectionName: string, path: string): string {
  return `qmd://${collectionName}/${path}`;
}
```

**优势**:
1. **可移植性**：物理路径变化不影响虚拟路径
2. **唯一性**：同一物理文件可能在多个集合中，虚拟路径保证唯一
3. **安全性**：不暴露真实的文件系统结构

### 5. Context 继承系统

**文件位置**: `src/store.ts:1590-1728`

Context 是 QMD 的关键特性，为集合或路径添加描述，帮助搜索理解内容。

```typescript
export function getContextForPath(db: Database, collectionName: string, path: string): string | null {
  const contexts: string[] = [];

  // 1. 添加全局 Context（如果存在）
  if (config.global_context) {
    contexts.push(config.global_context);
  }

  // 2. 收集所有匹配的 Context（从一般到具体）
  const matchingContexts: { prefix: string; context: string }[] = [];
  for (const [prefix, context] of Object.entries(coll.context)) {
    const normalizedPrefix = prefix.startsWith("/") ? prefix : `/${prefix}`;
    if (normalizedPath.startsWith(normalizedPrefix)) {
      matchingContexts.push({ prefix: normalizedPrefix, context });
    }
  }

  // 3. 按前缀长度排序（短的在前 = 一般的在前）
  matchingContexts.sort((a, b) => a.prefix.length - b.prefix.length);

  // 4. 添加所有匹配的 Context
  for (const match of matchingContexts) {
    contexts.push(match.context);
  }

  // 5. 用双换行连接
  return contexts.length > 0 ? contexts.join('\n\n') : null;
}
```

**继承规则示例**:
```yaml
# 配置
contexts:
  /: "知识库根目录"
  /projects: "项目文档"
  /projects/qmd: "QMD 项目文档"

# 文件 /projects/qmd/README.md 的 Context:
# 知识库根目录
#
# 项目文档
#
# QMD 项目文档
```

## 数据流和控制流

### 索引流程

```
文件系统
    │
    ▼
fast-glob 扫描 (排除 node_modules, .git 等)
    │
    ▼
读取文件内容
    │
    ▼
计算 SHA256 哈希
    │
    ▼
提取标题 (从 Markdown 标题或文件名)
    │
    ▼
插入 content 表 (内容寻址存储)
    │
    ▼
插入 documents 表 (文件系统层映射)
    │
    ▼
FTS5 触发器自动更新全文索引
```

### 搜索流程

```
用户查询
    │
    ├─→ BM25 探测 ──→ 强信号？──→ 是 ──→ 跳过扩展
    │                           └──→ 否 ──→ LLM 查询扩展
    │
    ▼
并行执行:
    ├─→ FTS (BM25) 搜索
    ├─→ 向量搜索 (嵌入查询 → sqlite-vec)
    └─→ 扩展查询的搜索
    │
    ▼
RRF 融合多个结果列表
    │
    ▼
Top 40 候选文档
    │
    ▼
文档分块 → 选择最佳块
    │
    ▼
LLM 重排序 (基于块)
    │
    ▼
位置感知分数混合
    │
    ▼
返回 Top N 结果
```

## 关键代码片段

### 1. BM25 分数转换

```typescript
// src/store.ts:2125-2131
// BM25 分数是负数（越低越好），转换为 0-1 范围（越高越好）
const score = Math.abs(row.bm25_score) / (1 + Math.abs(row.bm25_score));

// 映射关系:
// -10 (强匹配) → 0.91
// -2  (中匹配)  → 0.67
// -0.5 (弱匹配) → 0.33
// 0   (无匹配)  → 0
```

### 2. 向量搜索的两步查询

```typescript
// src/store.ts:2160-2163
// 重要：sqlite-vec 虚拟表在与 JOIN 组合时会挂起
// 必须使用两步查询方法

// Step 1: 从 sqlite-vec 获取向量匹配（不允许 JOIN）
const vecResults = db.prepare(`
  SELECT hash_seq, distance
  FROM vectors_vec
  WHERE embedding MATCH ? AND k = ?
`).all(new Float32Array(embedding), limit * 3);

// Step 2: 获取文档信息
const docRows = db.prepare(`
  SELECT ...
  FROM content_vectors cv
  JOIN documents d ON d.hash = cv.hash
  WHERE cv.hash || '_' || cv.seq IN (...)
`).all(...hashSeqs);
```

### 3. 缓存策略

```typescript
// src/store.ts:1116-1122
export function setCachedResult(db: Database, cacheKey: string, result: string): void {
  db.prepare(`INSERT OR REPLACE INTO llm_cache ...`).run(cacheKey, result, now);
  
  // 1% 概率清理旧缓存，保持缓存大小在 1000 条以内
  if (Math.random() < 0.01) {
    db.exec(`DELETE FROM llm_cache WHERE hash NOT IN (
      SELECT hash FROM llm_cache ORDER BY created_at DESC LIMIT 1000
    )`);
  }
}
```

## 最佳实践借鉴

1. **内容寻址存储**: 使用哈希作为 content 表的主键，天然去重
2. **触发器同步**: 使用 SQLite 触发器自动保持 FTS 索引同步
3. **批量操作**: 嵌入时批量处理，减少模型调用开销
4. **渐进式清理**: 随机概率清理缓存，避免集中式清理的性能尖峰
5. **强信号短路**: 高置信度时跳过昂贵操作，优化常见情况

## 相关文档

- [[QMD_overview|项目概览]]
- [[QMD_llm_源码|LLM 集成模块]]
- [[QMD_混合搜索|混合搜索技术详解]]
- [[QMD_设计思想|设计思想总结]]
