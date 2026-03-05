# QMD 设计思想总结

## 整体架构设计哲学

### 1. 分层架构

QMD 采用清晰的分层架构，每一层都有明确的职责：

```
┌─────────────────────────────────────────────────────────────┐
│  接口层 (CLI / MCP / HTTP)                                   │
│  - 命令行界面                                                │
│  - Model Context Protocol 服务器                             │
│  - HTTP API                                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  应用层 (qmd.ts)                                             │
│  - 命令路由和参数解析                                         │
│  - 用户交互和输出格式化                                       │
│  - 生命周期管理                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  业务逻辑层 (store.ts)                                       │
│  - 搜索编排 (BM25 + Vector + Rerank)                         │
│  - 文档分块和索引                                            │
│  - Context 管理和虚拟路径                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  数据访问层 (db.ts / collections.ts)                         │
│  - SQLite 数据库操作                                         │
│  - YAML 配置管理                                             │
│  - 文件系统抽象                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  基础设施层 (llm.ts)                                         │
│  - node-llama-cpp 封装                                       │
│  - 模型加载和资源管理                                         │
│  - GPU/CPU 并行优化                                          │
└─────────────────────────────────────────────────────────────┘
```

**设计原则**：
- **依赖倒置**：上层依赖下层接口，不依赖具体实现
- **单一职责**：每个模块只做一件事，做好一件事
- **可测试性**：每层都可以独立测试，通过接口注入 mock

### 2. 数据流设计

QMD 采用**函数式数据流**，避免副作用：

```typescript
// 好的设计：纯函数，输入 -> 输出
function reciprocalRankFusion(resultLists: RankedResult[][]): RankedResult[] {
  // 不修改输入，返回新结果
  return sortedResults;
}

// 避免：副作用，修改全局状态
let globalResults: RankedResult[] = [];
function badFusion(lists: RankedResult[][]) {
  globalResults = ...;  // 副作用！
}
```

**优势**：
- 可预测性：相同输入总是产生相同输出
- 可测试性：容易编写单元测试
- 可并行性：无副作用的函数可以安全并行执行

### 3. 配置与数据分离

QMD 将**配置**（YAML）和**数据**（SQLite）分离：

```yaml
# ~/.config/qmd/index.yml (配置)
collections:
  notes:
    path: ~/notes
    pattern: "**/*.md"
    context:
      "/": "Personal notes and ideas"
```

```sql
-- ~/.cache/qmd/index.sqlite (数据)
-- documents, content, vectors 等表
```

**为什么这样设计？**

- **配置可版本控制**：YAML 可以放入 git，SQLite 不应该
- **数据可重建**：删除 SQLite 可以重新索引，配置不会丢失
- **多设备同步**：配置容易同步，数据通常不需要同步

## 关键设计决策分析

### 1. 为什么使用 SQLite + FTS5 + sqlite-vec？

**选择理由**：

| 特性 | SQLite | 其他选择 (Elasticsearch, Pinecone) |
|------|--------|-----------------------------------|
| **本地运行** | ✅ 完全本地 | ❌ 需要服务器 |
| **单文件** | ✅ 一个 .sqlite 文件 | ❌ 多文件/服务 |
| **零配置** | ✅ 开箱即用 | ❌ 需要配置 |
| **FTS5** | ✅ 内置全文搜索 | ⚠️ 需要插件 |
| **向量搜索** | ✅ sqlite-vec 扩展 | ✅ 原生支持 |
| **ACID** | ✅ 事务支持 | ✅ 支持 |
| **资源占用** | ✅ 低 | ❌ 高 |

**权衡**：
- **性能**：SQLite 单机性能不如专用搜索引擎
- **扩展性**：不适合分布式部署
- **适用场景**：个人知识管理（< 100K 文档）完全足够

### 2. 为什么使用 node-llama-cpp？

**本地推理的优势**：

```
云端 API (OpenAI, Claude)
    │
    ├─→ 需要网络连接
    ├─→ 数据离开本地（隐私问题）
    ├─→ 按 token 计费（成本问题）
    └─→ 延迟较高（RTT）

本地推理 (node-llama-cpp)
    │
    ├─→ 完全离线
    ├─→ 数据不出境
    ├─→ 一次性成本（硬件）
    └─→ 延迟低（本地计算）
```

**技术选择**：

- **GGUF 格式**：量化模型，减少内存占用
- **Metal/CUDA/Vulkan**：GPU 加速，提升推理速度
- **多上下文并行**：充分利用 GPU 计算资源

### 3. 为什么设计 Context 系统？

**问题**：纯基于内容的搜索无法理解文档的**上下文**

**示例**：
```markdown
# Meeting Notes

## Action Items
- Fix bug #123
- Update documentation
```

没有 Context：
- 搜索 "bug" 返回这个文档
- 不知道这是什么类型的 bug

有 Context：
```bash
qmd context add qmd://meetings "Meeting notes and action items"
```

搜索 "bug" 返回：
```
meetings/2024-01-15.md #a1b2c3
Title: Meeting Notes
Context: Meeting notes and action items
Score: 85%

Action Items
- Fix bug #123
...
```

**设计思想**：
- **元数据增强**：为机器提供人类理解的上下文
- **层次化继承**：全局 -> 集合 -> 路径，层层细化
- **Agent 友好**：LLM 可以根据 Context 做出更好的选择

### 4. 为什么使用虚拟路径 (qmd://)？

**物理路径的问题**：

```
/Users/tobi/notes/work/project-a/README.md
/home/tobi/notes/work/project-a/README.md  # Linux
C:\Users\tobi\notes\work\project-a\README.md  # Windows
```

- 平台差异
- 路径变化导致链接失效
- 暴露文件系统结构

**虚拟路径的优势**：

```
qmd://notes/work/project-a/README.md
```

- **平台无关**：统一格式
- **稳定**：物理路径变化不影响虚拟路径
- **安全**：不暴露真实文件系统
- **简洁**：易于阅读和记忆

### 5. 为什么使用 RRF 而不是机器学习融合？

**RRF (Reciprocal Rank Fusion)**：

```
优点：
- 无需训练数据
- 无需调参
- 计算简单 O(n)
- 可解释性强

缺点：
- 不是最优的（相比训练好的模型）
- 不能学习特征交互
```

**机器学习融合**：

```
优点：
- 可以学习最优权重
- 可以捕捉特征交互

缺点：
- 需要大量标注数据
- 需要训练和调参
- 过拟合风险
- 难以解释
```

**QMD 的选择**：RRF + 位置感知混合

- **简单有效**：RRF 在信息检索领域验证多年
- **无需数据**：不需要收集训练数据
- **可调整**：通过位置感知混合微调
- **可解释**：用户可以理解的融合逻辑

## 代码组织和抽象层次

### 1. 类型驱动开发

QMD 大量使用 TypeScript 类型系统：

```typescript
// 明确的类型定义
export type SearchResult = DocumentResult & {
  score: number;
  source: "fts" | "vec";
  chunkPos?: number;
};

export type HybridQueryResult = {
  file: string;
  displayPath: string;
  title: string;
  body: string;
  bestChunk: string;
  bestChunkPos: number;
  score: number;
  context: string | null;
  docid: string;
};
```

**好处**：
- 编译时检查，减少运行时错误
- 自文档化：类型即文档
- IDE 支持：自动补全和重构

### 2. 函数组合

复杂功能通过简单函数组合实现：

```typescript
// 高层函数：混合搜索
async function hybridQuery(query: string): Promise<HybridQueryResult[]> {
  const expanded = await expandQuery(query);
  const results = await Promise.all([
    searchFTS(query),
    searchVec(query),
    ...expanded.map(q => search(q))
  ]);
  const fused = reciprocalRankFusion(results);
  const reranked = await rerank(query, fused);
  return blendScores(fused, reranked);
}

// 每个底层函数都是可测试的单元
function reciprocalRankFusion(lists: RankedResult[][]): RankedResult[] { ... }
function blendScores(fts: RankedResult[], reranked: RerankResult[]): HybridQueryResult[] { ... }
```

**设计思想**：
- **单一职责**：每个函数只做一件事
- **可组合性**：函数可以像积木一样组合
- **可测试性**：每个函数独立测试

### 3. 错误处理策略

QMD 采用**优雅降级**策略：

```typescript
async function searchVec(query: string): Promise<SearchResult[]> {
  try {
    const embedding = await getEmbedding(query);
    if (!embedding) return [];  // 降级：返回空结果
    
    const results = await db.query(...);
    return results;
  } catch (error) {
    console.error("Vector search failed:", error);
    return [];  // 降级：返回空结果，不中断流程
  }
}
```

**原则**：
- 部分失败不影响整体功能
- 向量搜索失败，FTS 仍然可以工作
- 记录错误，但不抛出异常中断用户操作

## 可扩展性设计

### 1. 插件化架构

虽然 QMD 目前没有正式插件系统，但代码结构支持扩展：

```typescript
// LLM 接口可以有不同的实现
interface LLM {
  embed(text: string): Promise<EmbeddingResult>;
  rerank(query: string, docs: Document[]): Promise<RerankResult>;
}

// 当前实现
class LlamaCpp implements LLM { ... }

// 未来可能的实现
class OpenAILLM implements LLM { ... }
class OllamaLLM implements LLM { ... }
```

### 2. 配置驱动

新功能通过配置启用，无需修改代码：

```yaml
# 未来可能的扩展
collections:
  notes:
    path: ~/notes
    pattern: "**/*.md"
    # 新的配置选项
    embed_model: "custom-model"  # 自定义嵌入模型
    chunk_size: 1000             # 自定义分块大小
    preprocessors:               # 自定义预处理器
      - strip_frontmatter
      - normalize_links
```

### 3. 模块化设计

每个模块可以独立演进：

```
src/
├── qmd.ts          # CLI 入口（可以替换为 Web UI）
├── store.ts        # 业务逻辑（可以独立发布为库）
├── db.ts           # 数据库层（可以替换为其他数据库）
├── llm.ts          # LLM 层（可以支持其他推理引擎）
├── collections.ts  # 配置管理
└── formatter.ts    # 输出格式化（可以添加新格式）
```

## 性能优化策略

### 1. 延迟加载 (Lazy Loading)

```typescript
private async ensureEmbedModel(): Promise<LlamaModel> {
  if (this.embedModel) return this.embedModel;  // 已加载，直接返回
  // 否则加载模型
}
```

**优势**：
- 启动速度快（不加载未使用的模型）
- 内存占用低（只加载需要的模型）
- 按需付费（只在需要时消耗资源）

### 2. 批量处理

```typescript
// 低效：顺序嵌入
for (const text of texts) {
  await embed(text);  // N 次调用
}

// 高效：批量嵌入
await embedBatch(texts);  // 1 次调用，并行处理
```

**收益**：2-3x 性能提升

### 3. 智能缓存

```typescript
// LLM 结果缓存
const cacheKey = getCacheKey("expandQuery", { query, model });
const cached = getCachedResult(db, cacheKey);
if (cached) return JSON.parse(cached);

// 计算并缓存
const result = await llm.expandQuery(query);
setCachedResult(db, cacheKey, JSON.stringify(result));
```

**策略**：
- 缓存查询扩展结果（相同查询总是产生相同扩展）
- 缓存重排序结果（文档和查询不变，结果不变）
- LRU 清理：随机概率清理，避免集中式清理的性能尖峰

### 4. 强信号短路

```typescript
const hasStrongSignal = topScore >= 0.85 && (topScore - secondScore) >= 0.15;
if (hasStrongSignal) {
  // 跳过昂贵的 LLM 扩展
  return initialResults;
}
```

**收益**：常见情况下节省 1-2 秒

## 测试策略

### 1. 分层测试

```
test/
├── unit/           # 单元测试（纯函数）
│   ├── chunk.test.ts
│   ├── rrf.test.ts
│   └── fts.test.ts
├── integration/    # 集成测试（数据库 + 逻辑）
│   ├── search.test.ts
│   └── index.test.ts
└── e2e/            # 端到端测试（完整流程）
    └── cli.test.ts
```

### 2. 测试数据管理

```typescript
// 使用内存数据库进行测试
const db = openDatabase(":memory:");

// 测试后清理
afterEach(() => {
  db.close();
});
```

### 3. 关键路径覆盖

- **分块算法**：各种边界情况（空文档、代码块、标题）
- **RRF 融合**：多列表、重复文档、权重计算
- **搜索流程**：FTS、向量、混合、重排序

## 总结

QMD 的设计体现了以下核心思想：

1. **简单优先**：使用成熟技术（SQLite、RRF），避免过度工程
2. **本地优先**：数据不出境，保护隐私
3. **性能意识**：延迟加载、批量处理、智能缓存
4. **可扩展性**：模块化设计，接口抽象
5. **用户体验**：快速、准确、可解释

这些设计决策使得 QMD 成为一个**快速、可靠、易用**的个人知识管理搜索工具。

## 相关文档

- [[QMD_overview|项目概览]]
- [[QMD_store_源码|核心存储模块]]
- [[QMD_llm_源码|LLM 集成模块]]
- [[QMD_混合搜索|混合搜索技术详解]]
- [[QMD_智能分块|智能分块算法分析]]
