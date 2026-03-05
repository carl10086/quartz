# QMD 智能分块算法分析

## 技术原理和背景

### 为什么需要智能分块？

在 RAG (Retrieval-Augmented Generation) 系统中，文档分块是关键步骤：

**固定长度分块的问题**：
- 在句子中间切断，破坏语义完整性
- 代码块被分割，导致语法错误
- 段落被拆开，丢失上下文

**QMD 的解决方案**：
- 寻找 Markdown 结构的自然断点
- 使用评分机制选择最佳切割位置
- 保护代码块等不可分割的内容

### 分块参数

```typescript
// src/store.ts:53-62
export const CHUNK_SIZE_TOKENS = 900;        // 每块目标 token 数
export const CHUNK_OVERLAP_TOKENS = Math.floor(CHUNK_SIZE_TOKENS * 0.15);  // 15% 重叠
export const CHUNK_SIZE_CHARS = CHUNK_SIZE_TOKENS * 4;      // 约 3600 字符
export const CHUNK_OVERLAP_CHARS = CHUNK_OVERLAP_TOKENS * 4; // 约 540 字符
export const CHUNK_WINDOW_TOKENS = 200;      // 搜索窗口大小
export const CHUNK_WINDOW_CHARS = CHUNK_WINDOW_TOKENS * 4;   // 约 800 字符
```

**为什么 900 tokens？**
- 平衡精度和召回率
- 足够包含一个完整的语义单元（段落、小节）
- 不会过长导致嵌入质量下降

**为什么 15% 重叠？**
- 保证跨块边界的语义连续性
- 避免在边界处丢失信息
- 经验值，在精度和存储成本间平衡

## 实现细节和代码走读

### 1. 断点模式定义

**文件位置**: `src/store.ts:92-105`

```typescript
export const BREAK_PATTERNS: [RegExp, number, string][] = [
  [/\n#{1}(?!#)/g, 100, 'h1'],     // H1 标题 - 最高分 100
  [/\n#{2}(?!#)/g, 90, 'h2'],      // H2 标题 - 90 分
  [/\n#{3}(?!#)/g, 80, 'h3'],      // H3 标题 - 80 分
  [/\n#{4}(?!#)/g, 70, 'h4'],      // H4 标题 - 70 分
  [/\n#{5}(?!#)/g, 60, 'h5'],      // H5 标题 - 60 分
  [/\n#{6}(?!#)/g, 50, 'h6'],      // H6 标题 - 50 分
  [/\n```/g, 80, 'codeblock'],     // 代码块边界 - 80 分（同 H3）
  [/\n(?:---|\*\*\*|___)\s*\n/g, 60, 'hr'],  // 水平分隔线 - 60 分
  [/\n\n+/g, 20, 'blank'],         // 空行（段落边界）- 20 分
  [/\n[-*]\s/g, 5, 'list'],        // 无序列表项 - 5 分
  [/\n\d+\.\s/g, 5, 'numlist'],    // 有序列表项 - 5 分
  [/\n/g, 1, 'newline'],           // 普通换行 - 1 分
];
```

**评分设计原则**：

| 模式 | 分数 | 理由 |
|------|------|------|
| H1 标题 | 100 | 主要章节边界，最佳切割点 |
| H2 标题 | 90 | 子章节边界，很好的切割点 |
| H3-H6 | 80-50 | 随着层级降低，优先级递减 |
| 代码块边界 | 80 | 代码完整性很重要 |
| 水平分隔线 | 60 | 明确的逻辑分隔 |
| 空行 | 20 | 段落边界，可用但非最佳 |
| 列表项 | 5 | 尽量避免在列表中间切断 |
| 普通换行 | 1 | 最后手段 |

**正则表达式解析**：

```typescript
/\n#{1}(?!#)/g
// \n      - 匹配换行符
// #{1}    - 匹配一个 #
// (?!#)   - 负向前瞻，确保后面不是 #（避免匹配 ##）
// g       - 全局匹配
```

### 2. 扫描断点

**文件位置**: `src/store.ts:112-133`

```typescript
export function scanBreakPoints(text: string): BreakPoint[] {
  const points: BreakPoint[] = [];
  const seen = new Map<number, BreakPoint>();  // pos -> best break point at that pos

  for (const [pattern, score, type] of BREAK_PATTERNS) {
    for (const match of text.matchAll(pattern)) {
      const pos = match.index!;
      const existing = seen.get(pos);
      
      // 同一位置可能有多个模式匹配，保留最高分
      if (!existing || score > existing.score) {
        const bp = { pos, score, type };
        seen.set(pos, bp);
      }
    }
  }

  // 转换为数组并按位置排序
  for (const bp of seen.values()) {
    points.push(bp);
  }
  return points.sort((a, b) => a.pos - b.pos);
}
```

**为什么需要去重？**

同一位置可能匹配多个模式，例如：
```markdown
# Title
```
`
#` 既是换行符后，也是 H1 标题。保留最高分（H1=100，换行=1）。

### 3. 代码块保护

**文件位置**: `src/store.ts:139-168`

```typescript
export interface CodeFenceRegion {
  start: number;  // 起始 ``` 位置
  end: number;    // 结束 ``` 位置（或未闭合则到文档末尾）
}

export function findCodeFences(text: string): CodeFenceRegion[] {
  const regions: CodeFenceRegion[] = [];
  const fencePattern = /\n```/g;
  let inFence = false;
  let fenceStart = 0;

  for (const match of text.matchAll(fencePattern)) {
    if (!inFence) {
      fenceStart = match.index!;
      inFence = true;
    } else {
      regions.push({ start: fenceStart, end: match.index! + match[0].length });
      inFence = false;
    }
  }

  // 处理未闭合的代码块
  if (inFence) {
    regions.push({ start: fenceStart, end: text.length });
  }

  return regions;
}

export function isInsideCodeFence(pos: number, fences: CodeFenceRegion[]): boolean {
  return fences.some(f => pos > f.start && pos < f.end);
}
```

**为什么保护代码块？**

1. **语法完整性**：代码被切断会导致语法错误
2. **语义连贯性**：代码行之间有逻辑依赖
3. **可读性**：不完整的代码块难以理解

### 4. 寻找最佳切割点

**文件位置**: `src/store.ts:183-219`

```typescript
export function findBestCutoff(
  breakPoints: BreakPoint[],
  targetCharPos: number,        // 目标切割位置
  windowChars: number = CHUNK_WINDOW_CHARS,  // 搜索窗口（默认 800 字符）
  decayFactor: number = 0.7,    // 距离衰减因子
  codeFences: CodeFenceRegion[] = []
): number {
  const windowStart = targetCharPos - windowChars;
  let bestScore = -1;
  let bestPos = targetCharPos;

  for (const bp of breakPoints) {
    // 只考虑窗口内的断点
    if (bp.pos < windowStart) continue;
    if (bp.pos > targetCharPos) break;  // 已排序，可以提前结束

    // 跳过代码块内的断点
    if (isInsideCodeFence(bp.pos, codeFences)) continue;

    // 距离衰减计算
    const distance = targetCharPos - bp.pos;
    const normalizedDist = distance / windowChars;
    
    // 平方距离衰减：温和早期，陡峭晚期
    // At target: multiplier = 1.0
    // At 25% back: multiplier = 0.956
    // At 50% back: multiplier = 0.825
    // At 75% back: multiplier = 0.606
    // At window edge: multiplier = 0.3
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

**平方距离衰减公式**：

```
finalScore = baseScore × (1 - (distance/window)² × decayFactor)

示例（decayFactor=0.7, window=800）：
- 距离 0:   1.0 × baseScore = baseScore
- 距离 200: (1 - (0.25)² × 0.7) = 0.956 × baseScore
- 距离 400: (1 - (0.5)² × 0.7) = 0.825 × baseScore
- 距离 600: (1 - (0.75)² × 0.7) = 0.606 × baseScore
- 距离 800: (1 - 1² × 0.7) = 0.3 × baseScore
```

**为什么使用平方衰减？**

1. **温和早期**：距离较小时，分数衰减缓慢，远处的标题仍有竞争力
2. **陡峭晚期**：距离较大时，分数快速下降，避免选择太远的断点
3. **非线性**：比线性衰减更符合直觉，给中等距离的优质断点更多机会

### 5. 文档分块主流程

**文件位置**: `src/store.ts:1357-1418`

```typescript
export function chunkDocument(
  content: string,
  maxChars: number = CHUNK_SIZE_CHARS,      // 3600
  overlapChars: number = CHUNK_OVERLAP_CHARS, // 540
  windowChars: number = CHUNK_WINDOW_CHARS    // 800
): { text: string; pos: number }[] {
  // 短文档直接返回
  if (content.length <= maxChars) {
    return [{ text: content, pos: 0 }];
  }

  // 预扫描所有断点和代码块（只做一次）
  const breakPoints = scanBreakPoints(content);
  const codeFences = findCodeFences(content);

  const chunks: { text: string; pos: number }[] = [];
  let charPos = 0;

  while (charPos < content.length) {
    // 计算目标结束位置
    const targetEndPos = Math.min(charPos + maxChars, content.length);
    let endPos = targetEndPos;

    // 如果不是文档末尾，寻找最佳断点
    if (endPos < content.length) {
      const bestCutoff = findBestCutoff(
        breakPoints, targetEndPos, windowChars, 0.7, codeFences
      );

      // 只使用在当前块范围内的断点
      if (bestCutoff > charPos && bestCutoff <= targetEndPos) {
        endPos = bestCutoff;
      }
    }

    // 确保有进展（防止无限循环）
    if (endPos <= charPos) {
      endPos = Math.min(charPos + maxChars, content.length);
    }

    // 创建块
    chunks.push({ text: content.slice(charPos, endPos), pos: charPos });

    // 移动位置，考虑重叠
    if (endPos >= content.length) break;
    charPos = endPos - overlapChars;
    
    // 防止无限循环
    const lastChunkPos = chunks.at(-1)!.pos;
    if (charPos <= lastChunkPos) {
      charPos = endPos;
    }
  }

  return chunks;
}
```

**流程图**：

```
开始
  │
  ▼
文档长度 <= maxChars?
  │
  ├─→ 是 ──→ 返回单一块
  │
  └─→ 否
      │
      ▼
  扫描所有断点和代码块
      │
      ▼
  charPos = 0
      │
      ▼
  计算 targetEndPos = charPos + maxChars
      │
      ▼
  寻找最佳断点（在窗口内）
      │
      ▼
  使用最佳断点或强制切割
      │
      ▼
  创建块，添加到列表
      │
      ▼
  charPos = endPos - overlapChars
      │
      ▼
  还有剩余内容？
      │
      ├─→ 是 ──→ 继续循环
      │
      └─→ 否 ──→ 返回所有块
```

### 6. Token 级分块

**文件位置**: `src/store.ts:1424-1470`

```typescript
export async function chunkDocumentByTokens(
  content: string,
  maxTokens: number = CHUNK_SIZE_TOKENS,      // 900
  overlapTokens: number = CHUNK_OVERLAP_TOKENS, // 135
  windowTokens: number = CHUNK_WINDOW_TOKENS    // 200
): Promise<{ text: string; pos: number; tokens: number }[]> {
  const llm = getDefaultLlamaCpp();

  // 使用保守的字符/token 比率（混合文本约 3-4 字符/token）
  const avgCharsPerToken = 3;
  const maxChars = maxTokens * avgCharsPerToken;
  const overlapChars = overlapTokens * avgCharsPerToken;
  const windowChars = windowTokens * avgCharsPerToken;

  // 先用字符级分块（快速）
  let charChunks = chunkDocument(content, maxChars, overlapChars, windowChars);

  // 然后精确计算每个块的 token 数
  const results: { text: string; pos: number; tokens: number }[] = [];

  for (const chunk of charChunks) {
    const tokens = await llm.tokenize(chunk.text);

    if (tokens.length <= maxTokens) {
      // 块大小合适
      results.push({ text: chunk.text, pos: chunk.pos, tokens: tokens.length });
    } else {
      // 块仍然太大，使用实际比率重新分块
      const actualCharsPerToken = chunk.text.length / tokens.length;
      const safeMaxChars = Math.floor(maxTokens * actualCharsPerToken * 0.95);

      const subChunks = chunkDocument(chunk.text, safeMaxChars, ...);

      for (const subChunk of subChunks) {
        const subTokens = await llm.tokenize(subChunk.text);
        results.push({
          text: subChunk.text,
          pos: chunk.pos + subChunk.pos,
          tokens: subTokens.length,
        });
      }
    }
  }

  return results;
}
```

**两级分块策略**：

1. **快速分块**：使用字符估算（约 3-4 字符/token），快速获得近似分块
2. **精确调整**：对超出的块使用实际 token 比率重新分块

**为什么这样设计？**

- **性能**：避免对每个字符都调用 tokenizer（昂贵）
- **精度**：最终确保每个块不超过 token 限制
- **适应性**：不同内容类型（代码、散文）有不同的字符/token 比率

## 设计决策分析

### 1. 为什么使用平方距离衰减？

**对比线性衰减**：

```
线性: multiplier = 1 - (distance/window) × decayFactor
平方: multiplier = 1 - (distance/window)² × decayFactor

在距离 = 50% window 时:
线性: 1 - 0.5 × 0.7 = 0.65
平方: 1 - 0.25 × 0.7 = 0.825

在距离 = 75% window 时:
线性: 1 - 0.75 × 0.7 = 0.475
平方: 1 - 0.5625 × 0.7 = 0.606
```

**平方衰减的优势**：
- 给中等距离的优质断点更多机会
- 远处的断点快速衰减，避免选择太远的
- 更符合直觉：轻微超出目标比严重超出目标要好得多

### 2. 为什么 H1 标题 100 分？

**优先级设计**：

```
H1 (100) >> H2 (90) > H3 (80) = Code Block (80) > H4 (70) > H5 (60) = HR (60) >> Blank (20)
```

**理由**：
- H1 是主要章节边界，语义最清晰
- 代码块边界和 H3 同级，因为代码完整性很重要
- 空行只有 20 分，尽量避免在段落中间切断

### 3. 为什么 15% 重叠？

**重叠的作用**：

```
块 1: [内容 A] [重叠区] [内容 B]
块 2:              [内容 B] [重叠区] [内容 C]
```

**为什么是 15%？**

- **足够大**：保证跨块边界的语义连续性
- **不太大**：避免存储成本过高（约增加 17.6% 的存储）
- **经验值**：在 RAG 领域广泛使用

### 4. 为什么保护代码块？

**代码块的特殊性**：

```markdown
function example() {
  const x = 1;
  // 如果在这里切断...
```

```markdown
  // ...下一块从这里开始
  return x;
}
```

**问题**：
- 语法不完整，无法解析
- 语义断裂，难以理解
- 嵌入质量下降（不完整的代码语义不清）

**解决方案**：
- 识别代码块区域
- 跳过代码块内的所有断点
- 如果代码块超过最大块大小，整体保留（宁可超出也不切断）

## 可以借鉴的最佳实践

1. **结构感知分块**：利用文档结构（标题、代码块）寻找自然断点
2. **评分机制**：为不同类型的断点分配分数，量化"切割质量"
3. **距离衰减**：使用非线性衰减函数，平衡远近断点的竞争
4. **内容保护**：识别不可分割的内容（代码块），强制保护
5. **两级分块**：快速估算 + 精确调整，平衡性能和精度
6. **重叠设计**：保证跨块边界的语义连续性
7. **防无限循环**：始终确保前进，避免边界情况导致的死循环

## 相关文档

- [[QMD_overview|项目概览]]
- [[QMD_store_源码|核心存储模块]]
- [[QMD_llm_源码|LLM 集成模块]]
- [[QMD_混合搜索|混合搜索技术详解]]
- [[QMD_设计思想|设计思想总结]]
