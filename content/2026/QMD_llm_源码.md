# QMD LLM 模块源码分析

## 模块设计意图

`llm.ts` 是 QMD 的 **LLM 抽象层**，负责与本地 GGUF 模型的交互。设计目标：

1. **统一接口**：定义 `LLM` 接口，支持不同后端实现（目前只有 node-llama-cpp）
2. **资源管理**：自动管理模型加载/卸载、上下文生命周期、内存优化
3. **并行优化**：多上下文并行处理，充分利用 GPU/多核 CPU
4. **会话管理**：提供 scoped session 机制，保证操作原子性

## 核心类/函数详细分析

### 1. LLM 接口定义

**文件位置**: `src/llm.ts:295-327`

```typescript
export interface LLM {
  embed(text: string, options?: EmbedOptions): Promise<EmbeddingResult | null>;
  generate(prompt: string, options?: GenerateOptions): Promise<GenerateResult | null>;
  modelExists(model: string): Promise<ModelInfo>;
  expandQuery(query: string, options?: { context?: string, includeLexical?: boolean }): Promise<Queryable[]>;
  rerank(query: string, documents: RerankDocument[], options?: RerankOptions): Promise<RerankResult>;
  dispose(): Promise<void>;
}
```

**Queryable 类型** - 支持多种查询类型：
```typescript
export type QueryType = 'lex' | 'vec' | 'hyde';
export type Queryable = {
  type: QueryType;
  text: string;
};
```

- **lex**: 词汇查询 → 路由到 FTS (BM25)
- **vec**: 向量查询 → 路由到向量搜索
- **hyde**: Hypothetical Document Embedding → 生成假设文档后向量搜索

### 2. LlamaCpp 类 - node-llama-cpp 实现

**文件位置**: `src/llm.ts:361-1160`

这是核心实现类，管理三个模型：
- **Embed Model**: embeddinggemma-300M-Q8_0 (嵌入生成)
- **Generate Model**: qmd-query-expansion-1.7B-q4_k_m (查询扩展)
- **Rerank Model**: qwen3-reranker-0.6b-q8_0 (结果重排序)

#### 2.1 延迟加载与并发控制

```typescript
export class LlamaCpp implements LLM {
  private llama: Llama | null = null;
  private embedModel: LlamaModel | null = null;
  private embedContexts: LlamaEmbeddingContext[] = [];
  private generateModel: LlamaModel | null = null;
  private rerankModel: LlamaModel | null = null;
  private rerankContexts: Awaited<ReturnType<LlamaModel["createRankingContext"]>>[] = [];

  // Promise guard 防止并发加载竞争
  private embedModelLoadPromise: Promise<LlamaModel> | null = null;
  private generateModelLoadPromise: Promise<LlamaModel> | null = null;
  private rerankModelLoadPromise: Promise<LlamaModel> | null = null;
```

**Promise Guard 模式**:
```typescript
private async ensureEmbedModel(): Promise<LlamaModel> {
  if (this.embedModel) return this.embedModel;
  if (this.embedModelLoadPromise) return await this.embedModelLoadPromise;

  this.embedModelLoadPromise = (async () => {
    const llama = await this.ensureLlama();
    const modelPath = await this.resolveModel(this.embedModelUri);
    const model = await llama.loadModel({ modelPath });
    this.embedModel = model;
    return model;
  })();

  try {
    return await this.embedModelLoadPromise;
  } finally {
    this.embedModelLoadPromise = null;  // 清除 promise，但保留加载好的模型
  }
}
```

**为什么需要 Promise Guard？**
- 防止多个并发请求同时触发模型加载
- 避免重复分配 VRAM（模型加载是昂贵的）
- 第一个请求加载模型，后续请求等待同一个 promise

#### 2.2 GPU 自动检测

```typescript
private async ensureLlama(): Promise<Llama> {
  if (!this.llama) {
    // 检测可用 GPU 类型
    const gpuTypes = await getLlamaGpuTypes();
    // 优先级: CUDA > Metal > Vulkan
    const preferred = (["cuda", "metal", "vulkan"] as const).find(g => gpuTypes.includes(g));

    let llama: Llama;
    if (preferred) {
      try {
        llama = await getLlama({ gpu: preferred, logLevel: LlamaLogLevel.error });
      } catch {
        llama = await getLlama({ gpu: false, logLevel: LlamaLogLevel.error });
        console.error(`QMD Warning: ${preferred} reported available but failed...`);
      }
    } else {
      llama = await getLlama({ gpu: false, logLevel: LlamaLogLevel.error });
    }
    this.llama = llama;
  }
  return this.llama;
}
```

**为什么不使用 `gpu: "auto"`？**
- node-llama-cpp 的 auto 模式在某些配置下会返回 false，即使 CUDA 可用
- 手动检测更可靠，且可以按优先级选择

#### 2.3 并行度计算

**文件位置**: `src/llm.ts:578-607`

```typescript
private async computeParallelism(perContextMB: number): Promise<number> {
  const llama = await this.ensureLlama();

  if (llama.gpu) {
    const vram = await llama.getVramState();
    const freeMB = vram.free / (1024 * 1024);
    // 使用 25% 的可用 VRAM，最多 8 个上下文
    const maxByVram = Math.floor((freeMB * 0.25) / perContextMB);
    return Math.max(1, Math.min(8, maxByVram));
  }

  // CPU: 每个上下文至少 4 个线程
  const cores = llama.cpuMathCores || 4;
  const maxContexts = Math.floor(cores / 4);
  return Math.max(1, Math.min(4, maxContexts));
}
```

**设计决策**:
- **GPU**: 限制使用 25% VRAM，避免影响其他应用
- **CPU**: 每个上下文至少 4 线程，保证基本性能
- **上限**: GPU 最多 8 个，CPU 最多 4 个（经验值）

#### 2.4 批量嵌入优化

**文件位置**: `src/llm.ts:825-881`

```typescript
async embedBatch(texts: string[]): Promise<(EmbeddingResult | null)[]> {
  const contexts = await this.ensureEmbedContexts();
  const n = contexts.length;

  if (n === 1) {
    // 单上下文：顺序处理
    for (const text of texts) {
      const embedding = await context.getEmbeddingFor(text);
      // ...
    }
  } else {
    // 多上下文：将文本分块，并行处理
    const chunkSize = Math.ceil(texts.length / n);
    const chunks = Array.from({ length: n }, (_, i) =>
      texts.slice(i * chunkSize, (i + 1) * chunkSize)
    );

    const chunkResults = await Promise.all(
      chunks.map(async (chunk, i) => {
        const ctx = contexts[i]!;
        for (const text of chunk) {
          const embedding = await ctx.getEmbeddingFor(text);
          // ...
        }
      })
    );

    return chunkResults.flat();
  }
}
```

**性能提升**:
- 单 GPU 上多上下文并行，可实现 2.7x 加速
- 每个上下文有独立的序列锁，可以真正并行计算

### 3. 查询扩展 (expandQuery)

**文件位置**: `src/llm.ts:942-1023`

使用 fine-tuned Qwen3 模型生成查询变体：

```typescript
async expandQuery(query: string, options: { context?: string, includeLexical?: boolean } = {}): Promise<Queryable[]> {
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
    temperature: 0.7,  // Qwen3 推荐值
    topK: 20,
    topP: 0.8,
    repeatPenalty: { lastTokens: 64, presencePenalty: 0.5 },
  });

  // 解析结果
  const lines = result.trim().split("\n");
  const queryables: Queryable[] = lines.map(line => {
    const colonIdx = line.indexOf(":");
    const type = line.slice(0, colonIdx).trim();
    const text = line.slice(colonIdx + 1).trim();
    return { type: type as QueryType, text };
  });

  return queryables;
}
```

**Grammar 约束**:
- 强制输出格式为 `type: content`
- type 只能是 lex/vec/hyde 之一
- 防止模型输出无效格式

**为什么 temperature=0.7？**
- Qwen3 官方推荐非思考模式使用 0.7
- 不要使用 greedy decoding (temp=0)，会导致重复循环

### 4. 重排序 (rerank)

**文件位置**: `src/llm.ts:1028-1093`

使用 Qwen3-Reranker 模型对文档进行相关性排序：

```typescript
async rerank(query: string, documents: RerankDocument[]): Promise<RerankResult> {
  const contexts = await this.ensureRerankContexts();
  const model = await this.ensureRerankModel();

  // 截断超长文档
  const queryTokens = model.tokenize(query).length;
  const maxDocTokens = LlamaCpp.RERANK_CONTEXT_SIZE - LlamaCpp.RERANK_TEMPLATE_OVERHEAD - queryTokens;

  const truncatedDocs = documents.map((doc) => {
    const tokens = model.tokenize(doc.text);
    if (tokens.length <= maxDocTokens) return doc;
    const truncatedText = model.detokenize(tokens.slice(0, maxDocTokens));
    return { ...doc, text: truncatedText };
  });

  // 分块并行处理
  const n = contexts.length;
  const chunkSize = Math.ceil(texts.length / n);
  const chunks = Array.from({ length: n }, (_, i) =>
    texts.slice(i * chunkSize, (i + 1) * chunkSize)
  );

  const allScores = await Promise.all(
    chunks.map((chunk, i) => contexts[i]!.rankAll(query, chunk))
  );

  // 合并结果并排序
  const flatScores = allScores.flat();
  return ranked.map((item, i) => ({
    file: docInfo.file,
    score: flatScores[i],
    index: docInfo.index,
  }));
}
```

**关键优化**:
- **上下文大小**: 2048 tokens（足够 rerank 使用，远低于默认值 40960）
- **Flash Attention**: 减少 20% VRAM 使用（568MB vs 711MB）
- **截断策略**: 超长文档截断到合适长度，避免超出上下文

### 5. 会话管理 (Session Management)

**文件位置**: `src/llm.ts:1170-1386`

提供 scoped session 机制，保证操作期间资源不会被释放：

```typescript
class LLMSessionManager {
  private _activeSessionCount = 0;
  private _inFlightOperations = 0;

  canUnload(): boolean {
    return this._activeSessionCount === 0 && this._inFlightOperations === 0;
  }

  acquire(): void { this._activeSessionCount++; }
  release(): void { this._activeSessionCount--; }
  operationStart(): void { this._inFlightOperations++; }
  operationEnd(): void { this._inFlightOperations--; }
}

class LLMSession implements ILLMSession {
  private manager: LLMSessionManager;
  private abortController: AbortController;

  constructor(manager: LLMSessionManager, options: LLMSessionOptions = {}) {
    this.manager = manager;
    this.abortController = new AbortController();

    // 设置最大持续时间
    const maxDuration = options.maxDuration ?? 10 * 60 * 1000; // 10分钟
    if (maxDuration > 0) {
      this.maxDurationTimer = setTimeout(() => {
        this.abortController.abort(new Error(`Session exceeded max duration`));
      }, maxDuration);
    }

    this.manager.acquire();  // 获取会话租约
  }

  release(): void {
    this.manager.release();  // 释放会话租约
  }

  private async withOperation<T>(fn: () => Promise<T>): Promise<T> {
    this.manager.operationStart();
    try {
      if (this.abortController.signal.aborted) {
        throw new SessionReleasedError();
      }
      return await fn();
    } finally {
      this.manager.operationEnd();
    }
  }
}
```

**使用示例**:
```typescript
await withLLMSession(async (session) => {
  const expanded = await session.expandQuery(query);
  const embeddings = await session.embedBatch(texts);
  const reranked = await session.rerank(query, docs);
  return reranked;
}, { maxDuration: 10 * 60 * 1000, name: 'querySearch' });
```

**为什么需要会话管理？**
- **防止资源释放**: 空闲超时器不会在有活跃会话时释放资源
- **操作原子性**: 一个操作序列要么全部完成，要么全部取消
- **超时控制**: 防止长时间运行的操作占用资源

### 6. 空闲资源管理

**文件位置**: `src/llm.ts:401-484`

```typescript
private touchActivity(): void {
  // 清除现有定时器
  if (this.inactivityTimer) {
    clearTimeout(this.inactivityTimer);
    this.inactivityTimer = null;
  }

  // 设置新的空闲超时
  if (this.inactivityTimeoutMs > 0 && this.hasLoadedContexts()) {
    this.inactivityTimer = setTimeout(() => {
      // 检查是否可以卸载
      if (typeof canUnloadLLM === 'function' && !canUnloadLLM()) {
        this.touchActivity();  // 重新调度
        return;
      }
      this.unloadIdleResources();
    }, this.inactivityTimeoutMs);
  }
}

async unloadIdleResources(): Promise<void> {
  // 释放上下文（保留模型）
  for (const ctx of this.embedContexts) await ctx.dispose();
  this.embedContexts = [];
  for (const ctx of this.rerankContexts) await ctx.dispose();
  this.rerankContexts = [];

  // 可选：也释放模型（默认不启用）
  if (this.disposeModelsOnInactivity) {
    // ...
  }
}
```

**设计决策**:
- **默认超时**: 5 分钟（覆盖典型搜索会话）
- **只释放上下文**: 上下文是 per-session 的重对象，模型保持加载
- **会话感知**: 有活跃会话时不释放，避免中断操作

## 数据流和控制流

### 模型加载流程

```
请求嵌入/生成/重排序
    │
    ▼
检查模型是否已加载
    │
    ├─→ 已加载 ──→ 直接使用
    │
    └─→ 未加载 ──→ 检查是否有加载中的 Promise
                        │
                        ├─→ 有 ──→ 等待现有 Promise
                        └─→ 无 ──→ 创建新的加载 Promise
                                        │
                                        ▼
                                    检测 GPU 类型
                                        │
                                        ▼
                                    加载模型到 VRAM/内存
                                        │
                                        ▼
                                    创建上下文池
                                        │
                                        ▼
                                    清除 Promise，保留模型
```

### 批量嵌入流程

```
批量嵌入请求
    │
    ▼
获取/创建嵌入上下文池
    │
    ▼
计算并行度 (基于 VRAM/CPU 核心)
    │
    ▼
将文本分块
    │
    ▼
并行处理 (Promise.all)
    ├─→ 上下文 1: 文本块 1
    ├─→ 上下文 2: 文本块 2
    └─→ 上下文 N: 文本块 N
    │
    ▼
合并结果
```

## 关键代码片段

### 1. 模型 URI 解析

```typescript
// src/llm.ts:208-216
function parseHfUri(model: string): HfRef | null {
  if (!model.startsWith("hf:")) return null;
  const without = model.slice(3);
  const parts = without.split("/");
  if (parts.length < 3) return null;
  const repo = parts.slice(0, 2).join("/");
  const file = parts.slice(2).join("/");
  return { repo, file };
}

// 格式: hf:org/repo/file.gguf
// 示例: hf:ggml-org/embeddinggemma-300M-GGUF/embeddinggemma-300M-Q8_0.gguf
```

### 2. 重排序上下文大小优化

```typescript
// src/llm.ts:726-729
// Qwen3 reranker 模板开销约 200 tokens
// 文本块最大 800 tokens
// 总计约 1100 tokens
// 使用 2048 作为安全边距（相比默认值 40960 减少 17 倍）
private static readonly RERANK_CONTEXT_SIZE = 2048;
```

### 3. 嵌入格式化

```typescript
// src/llm.ts:30-40
// 查询使用 search result 任务前缀
export function formatQueryForEmbedding(query: string): string {
  return `task: search result | query: ${query}`;
}

// 文档使用 title + text 格式
export function formatDocForEmbedding(text: string, title?: string): string {
  return `title: ${title || "none"} | text: ${text}`;
}
```

## 最佳实践借鉴

1. **Promise Guard 模式**: 防止并发加载竞争，避免重复资源分配
2. **分层资源管理**: 模型（重）→ 上下文（中）→ 序列（轻），按需释放
3. **动态并行度**: 根据硬件资源自动调整并发度
4. **Grammar 约束**: 使用形式文法约束 LLM 输出，提高可靠性
5. **空闲超时**: 自动释放不活跃资源，平衡性能和内存
6. **会话管理**: 引用计数确保资源不会在操作中途被释放

## 相关文档

- [[QMD_overview|项目概览]]
- [[QMD_store_源码|核心存储模块]]
- [[QMD_混合搜索|混合搜索技术详解]]
- [[QMD_设计思想|设计思想总结]]
