# QMD 混合搜索技术详解

## 技术原理和背景

### 为什么需要混合搜索？

传统搜索有两种主要方式，各有优劣：

| 搜索方式 | 优势 | 劣势 |
|---------|------|------|
| **关键词搜索 (BM25)** | 精确匹配、速度快、可解释 | 无法理解语义、同义词问题 |
| **向量搜索** | 语义理解、同义词友好 | 计算成本高、可能丢失精确匹配 |

**混合搜索**结合两者优势，通过融合算法获得更好的召回率和精确率。

### QMD 的混合搜索架构

```
用户查询
    │
    ├─→ [可选] 查询扩展 (LLM 生成变体)
    │
    ├─→ BM25 搜索 (FTS5)
    │       └─→ 基于词频的精确匹配
    │
    ├─→ 向量搜索 (sqlite-vec)
    │       └─→ 基于语义的相似度匹配
    │
    ▼
RRF 融合 (Reciprocal Rank Fusion)
    │
    ▼
Top-K 候选选择
    │
    ▼
LLM 重排序 (Cross-encoder)
    │
    ▼
位置感知分数混合
    │
    ▼
最终结果
```

## 实现细节和代码走读

### 1. BM25 搜索实现

**文件位置**: `src/store.ts:2096-2147`

```typescript
export function searchFTS(db: Database, query: string, limit: number = 20, collectionName?: string): SearchResult[] {
  // 将用户查询转换为 FTS5 查询语法
  const ftsQuery = buildFTS5Query(query);
  if (!ftsQuery) return [];

  const sql = `
    SELECT
      'qmd://' || d.collection || '/' || d.path as filepath,
      d.title,
      content.doc as body,
      bm25(documents_fts, 10.0, 1.0) as bm25_score
    FROM documents_fts f
    JOIN documents d ON d.id = f.rowid
    JOIN content ON content.hash = d.hash
    WHERE documents_fts MATCH ? AND d.active = 1
    ${collectionName ? 'AND d.collection = ?' : ''}
    ORDER BY bm25_score ASC LIMIT ?
  `;

  const rows = db.prepare(sql).all(...params);
  return rows.map(row => {
    // BM25 分数转换：负数 → 0-1 范围
    const score = Math.abs(row.bm25_score) / (1 + Math.abs(row.bm25_score));
    return { ...row, score, source: "fts" };
  });
}
```

**FTS5 查询构建** (`buildFTS5Query`):

```typescript
function buildFTS5Query(query: string): string | null {
  const positive: string[] = [];
  const negative: string[] = [];

  // 支持引号短语和否定语法
  // "exact phrase" → "exact phrase" (精确匹配)
  // -term → NOT "term"* (排除)
  
  while (i < s.length) {
    // 检查否定前缀
    const negated = s[i] === '-';
    if (negated) i++;

    // 检查引号短语
    if (s[i] === '"') {
      // 提取引号内的短语
      const phrase = extractQuotedPhrase();
      if (negated) negative.push(`"${phrase}"`);
      else positive.push(`"${phrase}"`);
    } else {
      // 普通词项
      const term = extractTerm();
      if (negated) negative.push(`"${term}"*`);
      else positive.push(`"${term}"*`);  // * 表示前缀匹配
    }
  }

  // 构建最终查询：positive AND (NOT negative)
  let result = positive.join(' AND ');
  for (const neg of negative) {
    result = `${result} NOT ${neg}`;
  }
  return result;
}
```

**分数转换公式**:

```
原始 BM25: 负数（越低越好）
转换后: |score| / (1 + |score|)

示例:
-10 → 0.91  (强匹配)
-2  → 0.67  (中匹配)
-0.5 → 0.33 (弱匹配)
0   → 0     (无匹配)
```

### 2. 向量搜索实现

**文件位置**: `src/store.ts:2153-2237`

```typescript
export async function searchVec(
  db: Database, 
  query: string, 
  model: string, 
  limit: number = 20,
  precomputedEmbedding?: number[]
): Promise<SearchResult[]> {
  // 1. 获取查询的嵌入向量
  const embedding = precomputedEmbedding ?? await getEmbedding(query, model);
  if (!embedding) return [];

  // 2. 两步查询（sqlite-vec 限制：不能和 JOIN 一起用）
  // Step 1: 向量匹配
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
    WHERE cv.hash || '_' || cv.seq IN (${placeholders})
  `).all(...hashSeqs);

  // 3. 按文件去重（保留最佳距离）
  const seen = new Map<string, { row: typeof docRows[0]; bestDist: number }>();
  for (const row of docRows) {
    const distance = distanceMap.get(row.hash_seq) ?? 1;
    const existing = seen.get(row.filepath);
    if (!existing || distance < existing.bestDist) {
      seen.set(row.filepath, { row, bestDist: distance });
    }
  }

  // 4. 转换距离为相似度分数
  return Array.from(seen.values())
    .sort((a, b) => a.bestDist - b.bestDist)
    .map(({ row, bestDist }) => ({
      ...row,
      score: 1 - bestDist,  // 余弦相似度 = 1 - 余弦距离
      source: "vec"
    }));
}
```

**为什么需要两步查询？**

sqlite-vec 虚拟表在与 JOIN 组合时会挂起（hang），这是已知限制。因此必须先查询向量表，再用结果查询文档表。

### 3. Reciprocal Rank Fusion (RRF)

**文件位置**: `src/store.ts:2375-2418`

RRF 是融合多个排序列表的经典算法：

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

  // Top-rank 奖励机制
  for (const entry of scores.values()) {
    if (entry.topRank === 0) entry.rrfScore += 0.05;      // #1 奖励
    else if (entry.topRank <= 2) entry.rrfScore += 0.02; // #2-3 奖励
  }

  return Array.from(scores.values())
    .sort((a, b) => b.rrfScore - a.rrfScore)
    .map(e => ({ ...e.result, score: e.rrfScore }));
}
```

**RRF 公式详解**:

```
RRF_score(d) = Σ (weight_i / (k + rank_i(d)))

其中:
- d: 文档
- weight_i: 第 i 个列表的权重
- rank_i(d): 文档 d 在第 i 个列表中的排名（从 0 开始）
- k: 平滑常数（通常 60）

为什么 k=60?
- 防止排名靠后的文档得分过于接近
- 是 RRF 论文的推荐值
- 在信息检索领域广泛使用
```

**Top-rank 奖励**:

```
#1 排名: +0.05
#2-3 排名: +0.02

目的：保护原始查询的精确匹配结果，防止扩展查询稀释重要结果
```

### 4. 查询扩展

**文件位置**: `src/llm.ts:942-1023`

```typescript
async expandQuery(query: string): Promise<Queryable[]> {
  // 使用 Grammar 约束输出格式
  const grammar = await llama.createGrammar({
    grammar: `
      root ::= line+
      line ::= type ": " content "\\n"
      type ::= "lex" | "vec" | "hyde"
      content ::= [^\\n]+
    `
  });

  const prompt = `/no_think Expand this search query: ${query}`;

  const result = await session.prompt(prompt, {
    grammar,
    maxTokens: 600,
    temperature: 0.7,
    topK: 20,
    topP: 0.8,
  });

  // 解析为 Queryable 数组
  return lines.map(line => {
    const [type, text] = parseLine(line);
    return { type, text };
  }).filter(q => hasQueryTerm(q.text));  // 过滤掉不包含原查询词项的结果
}
```

**查询类型路由**:

```typescript
// 在 hybridQuery 中根据类型路由
for (const q of expanded) {
  if (q.type === 'lex') {
    // 词汇查询 → FTS (BM25)
    const ftsResults = store.searchFTS(q.text, 20, collection);
    rankedLists.push(ftsResults);
  } else if (q.type === 'vec' || q.type === 'hyde') {
    // 向量/HyDE 查询 → 向量搜索
    const vecResults = await store.searchVec(q.text, model, 20, collection);
    rankedLists.push(vecResults);
  }
}
```

**HyDE (Hypothetical Document Embedding)**:

HyDE 是一种先进的检索技术：
1. 使用 LLM 生成一个假设的理想答案文档
2. 将这个假设文档嵌入为查询向量
3. 在向量空间中搜索相似的文档

优势：
- 将查询转换为更丰富的文档表示
- 捕获查询背后的意图
- 提高语义搜索的准确性

### 5. 重排序 (Reranking)

**文件位置**: `src/store.ts:2334-2369`

```typescript
export async function rerank(
  query: string, 
  documents: { file: string; text: string }[], 
  model: string = DEFAULT_RERANK_MODEL
): Promise<{ file: string; score: number }[]> {
  // 1. 检查缓存
  const cachedResults: Map<string, number> = new Map();
  const uncachedDocs: RerankDocument[] = [];

  for (const doc of documents) {
    const cacheKey = getCacheKey("rerank", { query, file: doc.file, chunk: doc.text });
    const cached = getCachedResult(db, cacheKey);
    if (cached !== null) {
      cachedResults.set(doc.file, parseFloat(cached));
    } else {
      uncachedDocs.push(doc);
    }
  }

  // 2. 重排序未缓存的文档
  if (uncachedDocs.length > 0) {
    const rerankResult = await llm.rerank(query, uncachedDocs);
    
    // 3. 缓存结果
    for (const result of rerankResult.results) {
      setCachedResult(db, cacheKey, result.score.toString());
      cachedResults.set(result.file, result.score);
    }
  }

  // 4. 返回所有结果（按分数排序）
  return documents
    .map(doc => ({ file: doc.file, score: cachedResults.get(doc.file) || 0 }))
    .sort((a, b) => b.score - a.score);
}
```

**为什么使用 Cross-encoder 重排序？**

- **Bi-encoder**（向量搜索）：分别编码查询和文档，速度快但精度有限
- **Cross-encoder**：将查询和文档一起编码，精度高但速度慢

策略：先用快速的 Bi-encoder 召回候选，再用精确的 Cross-encoder 重排序

### 6. 位置感知分数混合

**文件位置**: `src/store.ts:3049-3082`

```typescript
// 混合 RRF 排名分数和重排序器分数
const blended = reranked.map(r => {
  const rrfRank = rrfRankMap.get(r.file) || candidateLimit;
  
  // 根据 RRF 排名确定权重
  let rrfWeight: number;
  if (rrfRank <= 3) rrfWeight = 0.75;      // Top 1-3: 信任检索更多
  else if (rrfRank <= 10) rrfWeight = 0.60; // Top 4-10: 平衡
  else rrfWeight = 0.40;                    // Top 11+: 信任重排序器更多
  
  const rrfScore = 1 / rrfRank;
  const blendedScore = rrfWeight * rrfScore + (1 - rrfWeight) * r.score;

  return {
    file: r.file,
    score: blendedScore,
    // ...
  };
}).sort((a, b) => b.score - a.score);
```

**权重设计原理**:

| RRF 排名 | RRF 权重 | 重排序权重 | 理由 |
|---------|---------|-----------|------|
| 1-3 | 75% | 25% | 高置信度检索结果，不应被重排序器过度影响 |
| 4-10 | 60% | 40% | 中等置信度，平衡考虑 |
| 11+ | 40% | 60% | 低置信度，更信任重排序器的判断 |

**为什么这样设计？**

1. **保护精确匹配**：原始查询的精确匹配通常排名靠前，不应被重排序器稀释
2. **渐进式信任**：排名越靠后，检索的置信度越低，越需要重排序器纠正
3. **避免过度优化**：防止重排序器过度调整，破坏检索的基本质量

## 完整搜索流程

### Hybrid Query 完整流程

**文件位置**: `src/store.ts:2909-3094`

```typescript
export async function hybridQuery(store: Store, query: string, options?: HybridQueryOptions): Promise<HybridQueryResult[]> {
  // Step 1: BM25 探测 - 强信号时跳过昂贵的 LLM 扩展
  const initialFts = store.searchFTS(query, 20, collection);
  const topScore = initialFts[0]?.score ?? 0;
  const secondScore = initialFts[1]?.score ?? 0;
  const hasStrongSignal = topScore >= 0.85 && (topScore - secondScore) >= 0.15;

  // Step 2: 查询扩展（强信号时跳过）
  const expanded = hasStrongSignal ? [] : await store.expandQuery(query);

  // Step 3: 按类型路由搜索
  // 3a: 立即执行所有 lex 查询的 FTS 搜索
  for (const q of expanded) {
    if (q.type === 'lex') {
      const ftsResults = store.searchFTS(q.text, 20, collection);
      rankedLists.push(ftsResults);
    }
  }

  // 3b: 批量嵌入所有 vec/hyde 查询，然后执行向量搜索
  const vecQueries = [query, ...expanded.filter(q => q.type === 'vec' || q.type === 'hyde')];
  const embeddings = await llm.embedBatch(vecQueries.map(q => formatQueryForEmbedding(q)));
  
  for (let i = 0; i < vecQueries.length; i++) {
    const vecResults = await store.searchVec(
      vecQueries[i]!.text, model, 20, collection, 
      undefined, embeddings[i]?.embedding
    );
    rankedLists.push(vecResults);
  }

  // Step 4: RRF 融合 - 前两个列表（原始查询）获得 2x 权重
  const weights = rankedLists.map((_, i) => i < 2 ? 2.0 : 1.0);
  const fused = reciprocalRankFusion(rankedLists, weights);
  const candidates = fused.slice(0, candidateLimit);  // Top 40

  // Step 5: 文档分块，选择最佳块用于重排序
  const chunksToRerank = candidates.map(cand => {
    const chunks = chunkDocument(cand.body);
    // 选择与查询关键词重叠最多的块
    const bestIdx = selectBestChunk(chunks, query);
    return { file: cand.file, text: chunks[bestIdx]!.text };
  });

  // Step 6: 重排序块（而非全文）
  const reranked = await store.rerank(query, chunksToRerank);

  // Step 7: 位置感知分数混合
  const blended = reranked.map(r => {
    const rrfRank = rrfRankMap.get(r.file) || candidateLimit;
    const rrfWeight = rrfRank <= 3 ? 0.75 : rrfRank <= 10 ? 0.60 : 0.40;
    const blendedScore = rrfWeight * (1 / rrfRank) + (1 - rrfWeight) * r.score;
    return { ...r, score: blendedScore };
  });

  // Step 8: 去重、过滤、返回
  return blended
    .filter(r => !seenFiles.has(r.file))
    .filter(r => r.score >= minScore)
    .slice(0, limit);
}
```

## 关键设计决策分析

### 1. 强信号检测优化

```typescript
const hasStrongSignal = topScore >= 0.85 && (topScore - secondScore) >= 0.15;
```

**为什么这样设计？**

- **阈值 0.85**：BM25 转换后的高分，表示非常强的匹配
- **差距 0.15**：确保第一名明显领先第二名，不是竞争激烈的情况
- **节省 1-2 秒**：跳过 LLM 查询扩展的时间

### 2. 块级重排序

```typescript
// 错误：重排序全文（可能很长）
const reranked = await store.rerank(query, documents);

// 正确：重排序最佳块（固定长度）
const chunksToRerank = candidates.map(cand => {
  const chunks = chunkDocument(cand.body);
  const bestIdx = selectBestChunk(chunks, query);
  return { file: cand.file, text: chunks[bestIdx]!.text };
});
const reranked = await store.rerank(query, chunksToRerank);
```

**为什么这样设计？**

- **性能**：全文可能数万 tokens，块只有 900 tokens
- **精度**：最相关的块比整篇文档更能代表相关性
- **避免 O(tokens) 陷阱**：重排序成本与输入长度成正比

### 3. 批量嵌入优化

```typescript
// 低效：顺序嵌入
for (const q of queries) {
  const embedding = await llm.embed(q);  // 每次调用都加载模型
}

// 高效：批量嵌入
const embeddings = await llm.embedBatch(queries);  // 一次调用，并行处理
```

**性能提升**：2-3x 加速，减少模型切换开销

## 可以借鉴的最佳实践

1. **多路召回**：同时使用多种搜索方式，提高召回率
2. **RRF 融合**：简单有效的列表融合算法，无需训练
3. **强信号短路**：高置信度时跳过昂贵操作，优化常见情况
4. **块级处理**：长文档分块处理，平衡精度和性能
5. **位置感知混合**：根据排名动态调整权重，保护高置信度结果
6. **智能缓存**：重排序结果缓存，避免重复计算
7. **渐进式优化**：从简单到复杂，逐步提升质量

## 相关文档

- [[QMD_overview|项目概览]]
- [[QMD_store_源码|核心存储模块]]
- [[QMD_llm_源码|LLM 集成模块]]
- [[QMD_智能分块|智能分块算法]]
- [[QMD_设计思想|设计思想总结]]
