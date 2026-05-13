---
title: "GitNexus 深度解析:让 AI Agent 拥有代码记忆的技术拆解"
date: 2026-05-11
tags:
  - gitnexus
  - agent
  - code-intelligence
---

# GitNexus 深度解析:让 AI Agent 拥有代码记忆的技术拆解

## 定位与核心结论

**一句话**: GitNexus 把任意代码仓库索引为知识图谱(依赖、调用链、类型、执行流),然后通过 MCP(Model Context Protocol)暴露给 AI Agent,解决"AI 改代码时漏掉依赖"的问题。

**核心差异**: 传统 Graph RAG 给 LLM 原始图边让它自己探索,容易漏上下文、消耗大量 token。GitNexus 在索引时预计算关系(聚类、追踪、评分),查询时单次返回完整结构化答案。

---

## 你需要吗?

| 场景 | 建议 |
|------|------|
| 大型代码库(>1 万行),经常让 AI 重构核心模块 | 适合 |
| 微服务架构,需要跨仓库影响分析 | 适合 |
| 团队工程规范,PR review 前强制 impact analysis | 适合 |
| 小模型 + 好工具,需要接近大模型的代码理解力 | 适合 |
| 个人小项目(<50 个文件) | 不适合,索引开销 > 收益 |
| 非代码资产为主(PDF/图片/白板照片) | 不适合,选 graphify |
| 严格离线环境 | 不适合,embedding 需下载模型 |

---

## 核心能力

### 1. 编译器级代码解析

- **Chunk 化并行解析**:大仓库按 20MB 切分 source chunk,Worker Pool 并行解析,tree-sitter 跑在 Worker 线程
- **Named Binding Chain**:追踪 `import { User as U } from './models'` 和 re-export 链(最大深度 5 跳)
- **Wildcard Synthesis**:重建 Go/Python 等 wildcard import 的完整名字空间
- **Cross-File Type Propagation**:按拓扑 import 顺序传播类型,追踪泛型约束、接口继承
- **MRO**:显式记录 METHOD_OVERRIDES / METHOD_IMPLEMENTS 边

### 2. 预计算关系智能

- **Resolution Tier 体系**:
  | Tier | Confidence | 来源 |
  |------|-----------|------|
  | same-file | 0.95 | 同文件精确匹配 |
  | import-scoped | 0.9 | 遍历 caller 的 import set 在源文件查找 |
  | global | 0.5 | 全局名字扫描,可能歧义 |
- **社区聚类**:Leiden 算法,只拿 Function/Class/Method/Interface + CALLS 边聚类,过滤 File/Folder 结构噪音
- **执行流检测**:Entry Point Scoring + BFS Trace(maxDepth=10, maxBranching=4),动态调整 maxProcesses = max(20, min(300, symbolCount / 10))
- **混合搜索**:BM25 + semantic embedding + RRF 融合排序

### 3. 双模式部署

| 维度 | CLI + MCP | Web UI |
|------|-----------|--------|
| 存储 | LadybugDB Native(本地持久化) | LadybugDB WASM(浏览器内存,~5k 文件上限) |
| 解析 | tree-sitter native bindings | tree-sitter WASM |
| 隐私 | 完全本地,无网络 | 完全在浏览器,无服务器 |
| 适用 | 日常开发,任意规模 | 快速探索,演示 |
| 启动 | `gitnexus analyze` + MCP | `gitnexus serve` 打开浏览器 |

**Bridge Mode**:Web UI 通过 `gitnexus serve` 的 HTTP 服务器连接本地已索引仓库,无需在浏览器里重新索引。

---

## 架构实现

### 12-Phase Ingestion Pipeline

```
scan → structure → [markdown, cobol] → parse → [routes, tools, orm]
  → crossFile → mro → communities → processes
```

| Phase | 作用 |
|-------|------|
| scan | 遍历文件树 |
| structure | 建立 File/Folder 节点和 CONTAINS 边 |
| markdown | 解析 `.md` 文件章节结构和交叉链接 |
| cobol | 专用正则解析(无成熟 tree-sitter parser 时的兜底方案) |
| parse | 符号节点、IMPORTS/CALLS/EXTENDS 边、提取 routes/tools/ORM 查询 |
| routes | 检测 HTTP route,建立 Route → Handler 的 HANDLES_ROUTE 边 |
| tools | 检测 MCP/RPC tool 定义 |
| orm | 检测 Prisma/Supabase 查询,建立 QUERIES 边 |
| crossFile | 按拓扑 import 顺序传播类型 |
| mro | Method Resolution Order,建立 METHOD_OVERRIDES / METHOD_IMPLEMENTS 边 |
| communities | Leiden 算法聚类 |
| processes | 执行流检测 |

### Graph 存储:LadybugDB(原 KuzuDB)

- **嵌入式**:`.gitnexus/` 目录跟着项目走,克隆到别处不用重新索引
- **Cypher 查询**:MCP 暴露 `cypher` 工具,Agent 可写复杂查询
- **向量支持**:原生 embedding 索引
- **全局发现**:`~/.gitnexus/registry.json` 作为指针文件,MCP Server 懒加载连接(最多 5 并发,5 分钟闲置断开)

---

## MCP 工具链(16 个)

### 代码理解(4 个)

#### `query` — 混合搜索(BM25 + semantic + RRF)

**参数**:

| 名称 | 类型 | 必填 | 默认值 | 限制 | 描述 |
|------|------|------|--------|------|------|
| query | string | 是 | - | - | 自然语言或关键词搜索查询 |
| task_context | string | 否 | - | - | 你正在做什么(如"adding OAuth support"),帮助排名 |
| goal | string | 否 | - | - | 你想找什么(如"existing auth validation logic"),帮助排名 |
| limit | number | 否 | 5 | 1-100 | 最大返回 process 数 |
| max_symbols | number | 否 | 10 | 1-200 | 每个 process 最大 symbol 数 |
| include_content | boolean | 否 | false | - | 是否包含完整 symbol 源代码 |
| repo | string | 否 | - | - | 索引的仓库名或路径,或 group 模式 `"@<groupName>"` |
| service | string | 否 | - | minLength: 1 | monorepo 服务根路径(相对路径),仅在 group 模式下生效 |

**返回**:
- processes[]: 按 relevance 排序的执行流,每个包含 priority、symbol_count、process_type、step_count
- process_symbols[]: 执行流中的 symbol,包含 name、type、filePath、process_id、step_index
- definitions[]: 不在任何执行流中的独立类型/接口

**Group Mode**: 设置 `repo: "@<groupName>"` 搜索该组所有成员仓库,结果通过 RRF 合并。

---

#### `context` — symbol 的 360 度视图

**参数**:

| 名称 | 类型 | 必填 | 默认值 | 限制 | 描述 |
|------|------|------|--------|------|------|
| name | string | 否 | - | - | Symbol 名称(如 "validateUser") |
| uid | string | 否 | - | - | 直接从先前工具结果获取的 symbol UID(零歧义查找) |
| file_path | string | 否 | - | - | 文件路径,用于消歧同名 symbol |
| kind | string | 否 | - | - | 类型过滤器(如 'Function', 'Class', 'Method', 'Interface', 'Constructor') |
| include_content | boolean | 否 | false | - | 是否包含完整 symbol 源代码 |
| repo | string | 否 | - | - | 索引的仓库名或路径,或 group 模式 |
| service | string | 否 | - | minLength: 1 | monorepo 服务根路径,仅在 group 模式下生效 |

**返回**:
- symbol: uid、kind、filePath、startLine
- incoming: calls[]、imports[]、extends[]、implements[]、methods[]、properties[]、overrides[]、accesses[]
- outgoing: calls[]、imports[]、extends[]、implements[]
- processes: 参与的执行流名称和步骤(如 "LoginFlow (step 2/7)")

**歧义处理**: 当多个 symbol 同名时,返回 ranked candidates(每个带有 relevance score),用户可通过 uid 进行零歧义查找。

---

#### `cypher` — 原始 Cypher 查询

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| query | string | 是 | Cypher 查询语句 |
| repo | string | 否 | 仓库名或路径(仅一个索引仓库时可省略) |

**Schema**:

**Nodes**:
- File, Folder, Function, Class, Interface, Method, CodeElement, Community, Process, Route, Tool
- 多语言节点(需用反引号): `Struct`, `Enum`, `Trait`, `Impl` 等

**Edges** (通过 CodeRelation 表的 `type` 属性过滤):
- CONTAINS, DEFINES, CALLS, IMPORTS, EXTENDS, IMPLEMENTS
- HAS_METHOD, HAS_PROPERTY, ACCESSES
- METHOD_OVERRIDES, METHOD_IMPLEMENTS
- MEMBER_OF, STEP_IN_PROCESS
- HANDLES_ROUTE, FETCHES, HANDLES_TOOL, ENTRY_POINT_OF

**Edge Properties**:
- type (STRING)
- confidence (DOUBLE)
- reason (STRING)
- step (INT32)

**返回**: `{ markdown, row_count }` — 结果格式化为 Markdown 表格。

**常用查询示例**:

```cypher
-- 查找函数的调用者
MATCH (a)-[:CodeRelation {type: 'CALLS'}]->(b:Function {name: "validateUser"})
RETURN a.name, a.filePath

-- 查找社区成员
MATCH (f)-[:CodeRelation {type: 'MEMBER_OF'}]->(c:Community)
WHERE c.heuristicLabel = "Auth"
RETURN f.name

-- 追踪执行流
MATCH (s)-[r:CodeRelation {type: 'STEP_IN_PROCESS'}]->(p:Process)
WHERE p.heuristicLabel = "UserLogin"
RETURN s.name, r.step ORDER BY r.step

-- 查找类的所有方法
MATCH (c:Class {name: "UserService"})-[r:CodeRelation {type: 'HAS_METHOD'}]->(m:Method)
RETURN m.name, m.parameterCount, m.returnType

-- 查找字段的所有写入者
MATCH (f:Function)-[r:CodeRelation {type: 'ACCESSES', reason: 'write'}]->(p:Property)
WHERE p.name = "address"
RETURN f.name, f.filePath

-- 检测菱形继承
MATCH (d:Class)-[:CodeRelation {type: 'EXTENDS'}]->(b1),
      (d)-[:CodeRelation {type: 'EXTENDS'}]->(b2),
      (b1)-[:CodeRelation {type: 'EXTENDS'}]->(a),
      (b2)-[:CodeRelation {type: 'EXTENDS'}]->(a)
WHERE b1 <> b2
RETURN d.name, b1.name, b2.name, a.name
```

---

#### `list_repos` — 列出所有已索引仓库

**参数**: 无

**返回**: 每个仓库的 name、path、indexedAt、lastCommit(前7位)、stats(files/nodes/processes)

---

### 影响分析(3 个)

#### `impact` — 改动影响范围

**参数**:

| 名称 | 类型 | 必填 | 默认值 | 限制 | 描述 |
|------|------|------|--------|------|------|
| target | string | 是 | - | - | 要分析的函数、类或文件名 |
| target_uid | string | 否 | - | - | 直接从先前工具结果获取的 symbol UID(跳过 target 解析) |
| direction | string | 是 | - | - | "upstream"(谁依赖这个) 或 "downstream"(这个依赖谁) |
| file_path | string | 否 | - | - | 文件路径提示,用于消歧同名 symbol |
| kind | string | 否 | - | - | 类型过滤器(如 'Function', 'Class', 'Method') |
| maxDepth | number | 否 | 3 | 1-32 | 最大关系遍历深度 |
| crossDepth | number | 否 | 1 | 1-32 | 通过 contract bridge 的跨仓库跳转深度 |
| relationTypes | string[] | 否 | - | - | 过滤器: CALLS, IMPORTS, EXTENDS, IMPLEMENTS, HAS_METHOD, HAS_PROPERTY, METHOD_OVERRIDES, METHOD_IMPLEMENTS, ACCESSES(默认排除 ACCESSES) |
| includeTests | boolean | 否 | false | - | 是否包含测试文件 |
| minConfidence | number | 否 | 0 | 0-1 | 最小边置信度(默认 0,即不过滤) |
| repo | string | 否 | - | - | 索引的仓库名或路径,或 group 模式 |
| service | string | 否 | - | minLength: 1 | monorepo 服务根路径,仅在 group 模式下生效 |
| subgroup | string | 否 | - | - | 可选的 group 子组前缀,限制跨仓库 fan-out |
| timeoutMs | number | 否 | 30000 | 1-3600000 | Phase-1 本地影响分析的 wall-clock 预算(毫秒) |
| timeout | number | 否 | - | 1-3600000 | timeoutMs 的别名 |

**返回**:
- risk: LOW / MEDIUM / HIGH / CRITICAL
- summary: direct callers、受影响 processes、受影响 modules
- affected_processes: 哪些执行流会断裂及在哪一步
- affected_modules: 哪些功能区域被命中(直接 vs 间接)
- byDepth: 所有受影响 symbol 按遍历深度分组

**Depth 分组**:
- d=1: **WILL BREAK** — 直接调用者/导入者(必须更新)
- d=2: **LIKELY AFFECTED** — 间接依赖(应该测试)
- d=3: **MAY NEED TESTING** — 传递影响(关键路径上才测试)

---

#### `detect_changes` — 提交前检查

**参数**:

| 名称 | 类型 | 必填 | 默认值 | 描述 |
|------|------|------|--------|------|
| scope | string | 否 | "unstaged" | 分析范围: "unstaged"(默认)、"staged"、"all"、"compare" |
| base_ref | string | 否 | - | "compare" 范围时的分支/commit(如 "main") |
| repo | string | 否 | - | 仓库名或路径(仅一个索引仓库时可省略) |

**返回**:
- changed_count: 变更的 symbol 数量
- affected_count: 受影响的 symbol 数量
- changed_files: 变更的文件数量
- risk_level: low / medium / high / critical
- changed_symbols[]: 变更的 symbol 列表
- affected_processes[]: 受影响的执行流列表

---

#### `api_impact` — API route 改动影响

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| route | string | 否 | Route 路径(如 "/api/grants"),与 file 二选一 |
| file | string | 否 | Handler 文件路径,与 route 二选一 |
| repo | string | 否 | 仓库名或路径 |

**返回**:
- 单个 route 对象(匹配一个)或 { routes[], total }(匹配多个)
- route 对象包含: consumers、responseKeys、middleware、触发的执行流

**Risk 等级**:
- LOW: 0-3 consumers
- MEDIUM: 4-9 consumers 或任何 mismatch
- HIGH: 10+ consumers 或 mismatch + 4+ consumers

---

### 重构辅助(1 个)

#### `rename` — 多文件协调重命名

**参数**:

| 名称 | 类型 | 必填 | 默认值 | 描述 |
|------|------|------|--------|------|
| symbol_name | string | 否 | - | 当前 symbol 名称 |
| symbol_uid | string | 否 | - | 直接从先前工具结果获取的 UID(零歧义) |
| new_name | string | 是 | - | 新名称 |
| file_path | string | 否 | - | 文件路径,用于消歧同名 symbol |
| dry_run | boolean | 否 | true | 预览编辑而不修改文件 |
| repo | string | 否 | - | 仓库名或路径 |

**返回**:
- status: success / error
- files_affected: 受影响的文件数
- total_edits: 总编辑数
- graph_edits: 通过知识图谱关系找到的编辑数(高置信度,安全接受)
- text_search_edits: 通过正则文本搜索找到的编辑数(低置信度,需人工 review)
- changes[]: 每个文件的编辑列表,包含 file_path、edits[{line, old_text, new_text, confidence}]

---

### API/Web 映射(3 个)

#### `route_map` — Route → Handler → Consumer 映射

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| route | string | 否 | 按 route 路径过滤(如 "/api/grants"),省略则返回所有 |
| repo | string | 否 | 仓库名或路径 |

**返回**: route 节点及其 handler、middleware wrapper 链(如 withAuth、withRateLimit)、consumers

---

#### `tool_map` — MCP/RPC tool 定义

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| tool | string | 否 | 按 tool 名称过滤,省略则返回所有 |
| repo | string | 否 | 仓库名或路径 |

**返回**: tool 节点及其 handler 文件和描述

---

#### `shape_check` — Response shape vs consumer 访问匹配

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| route | string | 否 | 检查特定 route,省略则检查所有 |
| repo | string | 否 | 仓库名或路径 |

**返回**:
- 每个 endpoint 返回的 top-level keys(如 data、pagination、error)
- 每个 consumer 访问的 keys
- **MISMATCH** 状态: consumer 访问了 route response 中不存在的 key

**前提**: Route 节点需要有 responseKeys(索引时从 `.json({...})` 调用提取)

---

### 多仓库/微服务(5 个)

#### `group_list` — 列出配置的 repo group

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| name | string | 否 | Group 名称,省略则列出所有 group |

**返回**: 所有配置 group 的列表,或单个 group 的配置(repos、manifest links)

---

#### `group_sync` — 重建 Contract Registry

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| name | string | 是 | Group 名称 |
| skipEmbeddings | boolean | 否 | 仅 Exact + BM25(与默认 exact path 相同) |
| exactOnly | boolean | 否 | cascade 中仅精确匹配 |

**说明**: 每次调用都会写入 contracts.json;即使输出对相同输入是确定性的,也保守地标记为非幂等。

**返回**: 重建的 Contract Registry 状态

---

#### `group_contracts` — 查看 group 的 contract 和 cross-links

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| name | string | 是 | Group 名称 |

**返回**: 提取的 contract 和跨仓库 cross-links

---

#### `group_query` — 跨 repo 搜索执行流

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| name | string | 是 | Group 名称 |
| query | string | 是 | 搜索查询 |

**返回**: 跨所有成员仓库的执行流搜索结果

---

#### `group_status` — 检查 group 各成员的索引新鲜度

**参数**:

| 名称 | 类型 | 必填 | 描述 |
|------|------|------|------|
| name | string | 是 | Group 名称 |

**返回**: 每个成员的索引状态和 Contract Registry 新鲜度

---

## MCP Resources(8 个)

### Resource URI 格式

| URI | 类型 | 内容 |
|-----|------|------|
| `gitnexus://repos` | 静态 | 所有已索引仓库列表 |
| `gitnexus://setup` | 静态 | 所有索引仓库的 AGENTS.md 内容 |
| `gitnexus://repo/{name}/context` | 动态 | 代码库概览 + staleness 检查 + 可用工具 |
| `gitnexus://repo/{name}/clusters` | 动态 | 所有功能区域(Leiden 聚类) |
| `gitnexus://repo/{name}/processes` | 动态 | 所有执行流 |
| `gitnexus://repo/{name}/schema` | 动态 | 图数据库 schema(用于 Cypher) |
| `gitnexus://repo/{name}/cluster/{clusterName}` | 动态 | 特定功能区域详情 |
| `gitnexus://repo/{name}/process/{processName}` | 动态 | 逐步执行追踪 |
| `gitnexus://group/{name}/contracts?type=X&repo=Y&unmatchedOnly=true` | 动态 | 跨仓库 contract registry |
| `gitnexus://group/{name}/status` | 动态 | 组成员索引和 contract registry 新鲜度 |

### Context Resource 返回样例(YAML)

```yaml
project: my-app
staleness: "⚠️ Index is 3 commits behind HEAD. Run analyze tool to update."
stats:
  files: 142
  symbols: 918
  processes: 45
tools_available:
  - query: Process-grouped code intelligence (execution flows related to a concept)
  - context: 360-degree symbol view (categorized refs, process participation)
  - impact: Blast radius analysis (what breaks if you change a symbol)
  - detect_changes: Git-diff impact analysis (what do your changes affect)
  - rename: Multi-file coordinated rename with confidence tags
  - cypher: Raw graph queries
  - list_repos: Discover all indexed repositories
re_index: Run `npx gitnexus analyze` in terminal if data is stale
resources_available:
  - gitnexus://repos: All indexed repositories
  - gitnexus://repo/my-app/clusters: All functional areas
  - gitnexus://repo/my-app/processes: All execution flows
  - gitnexus://repo/my-app/cluster/{name}: Module details
```

### Repos Resource 返回样例(YAML)

```yaml
repos:
  - name: "my-app"
    path: "/Users/dev/projects/my-app"
    indexed: "2026-05-08T14:30:00Z"
    commit: "a1b2c3d"
    files: 142
    symbols: 918
    processes: 45
  - name: "api-service"
    path: "/Users/dev/projects/api-service"
    indexed: "2026-05-07T10:15:00Z"
    commit: "e4f5g6h"
    files: 89
    symbols: 634
    processes: 32

# Multiple repos indexed. Use repo parameter in tool calls:
# gitnexus_query({query: "auth", repo: "my-app"})
```

---

## MCP Server 实现细节

### Server 创建

```typescript
// gitnexus/src/mcp/server.ts:84
const server = new Server(
  { name: 'gitnexus', version: pkgVersion },
  { capabilities: { tools: {}, resources: {}, prompts: {} } }
);
```

### Handlers 注册

| Handler | 处理函数 | 功能 |
|---------|----------|------|
| ListResources | `getResourceDefinitions()` | 返回静态 resource 列表(repos, setup) |
| ListResourceTemplates | `getResourceTemplates()` | 返回动态 resource templates |
| ReadResource | `readResource(uri, backend)` | 解析 URI → dispatch 到具体实现 |
| ListTools | `GITNEXUS_TOOLS.map(...)` | 返回所有 tool 定义 |
| CallTool | `backend.callTool(name, args)` + `getNextStepHint(name, args)` | 执行工具并追加下一步提示 |
| ListPrompts | 返回 2 个 prompts(detect_impact, generate_map) | 列出可用 prompts |
| GetPrompt | 返回 prompt 的 messages 数组 | 获取具体 prompt 内容 |

### Next-Step Hints 机制

`server.ts:40-78` 的 `getNextStepHint(toolName, args)` 函数:

| Tool | Hint 内容 |
|------|-----------|
| list_repos | "Next: READ gitnexus://repo/{name}/context for any repo above to get its overview and check staleness." |
| query | "Next: To understand a specific symbol in depth, use context({name: \"<symbol_name>\"}) to see categorized refs and process participation." |
| context | "Next: If planning changes, use impact({target: \"<name>\", direction: \"upstream\"}) to check blast radius. To see execution flows, READ gitnexus://repo/{name}/processes." |
| impact | "Next: Review d=1 items first (WILL BREAK). To check affected execution flows, READ gitnexus://repo/{name}/processes." |
| detect_changes | "Next: Review affected processes. Use context() on high-risk changed symbols. READ gitnexus://repo/{name}/process/{name} for full execution traces." |
| rename | "Next: Run detect_changes() to verify no unexpected side effects from the rename." |
| cypher | "Next: To explore a result symbol, use context({name: \"<name>\"}). For schema reference, READ gitnexus://repo/{name}/schema." |

### Prompts 实现

**detect_impact**:
```typescript
messages: [{
  role: 'user',
  content: {
    type: 'text',
    text: `Analyze the impact of my current code changes before committing.

Follow these steps:
1. Run \`detect_changes(${JSON.stringify({ scope, ...(baseRef ? { base_ref: baseRef } : {}) })}\`) to find what changed and affected processes
2. For each changed symbol in critical processes, run \`context({name: "<symbol>"})\` to see its full reference graph
3. For any high-risk items (many callers or cross-process), run \`impact({target: "<symbol>", direction: "upstream"})\` for blast radius
4. Summarize: changes, affected processes, risk level, and recommended actions

Present the analysis as a clear risk report.`
  }
}]
```

**generate_map**:
```typescript
messages: [{
  role: 'user',
  content: {
    type: 'text',
    text: `Generate architecture documentation for this codebase using the knowledge graph.

Follow these steps:
1. READ \`gitnexus://repo/{name}/context\` for codebase stats
2. READ \`gitnexus://repo/{name}/clusters\` to see all functional areas
3. READ \`gitnexus://repo/{name}/processes\` to see all execution flows
4. For the top 5 most important processes, READ \`gitnexus://repo/{name}/process/{name}\` for step-by-step traces
5. Generate a mermaid architecture diagram showing the major areas and their connections
6. Write an ARCHITECTURE.md file with: overview, functional areas, key execution flows, and the mermaid diagram`
  }
}]
```

### Stdio Transport 与 stdout Sentinel

**问题**: MCP 协议通过 stdin/stdout 通信,如果其他库(如 logger)写入 stdout,会破坏协议。

**解决方案**(`server.ts:287-349`):
1. `installGlobalStdoutSentinel()`: 捕获原始的 `process.stdout.write`
2. `safeStdout` Proxy: 拦截所有对 `process.stdout.write` 的调用
3. **Tagged writes**: MCP transport 的写入带有标记,直接通过
4. **Untagged writes**: 其他库的写入被重定向到 stderr,并加 `[mcp:stdout-redirect]` 前缀

**Graceful Shutdown**:
```typescript
const shutdown = async (exitCode = 0) => {
  await backend.disconnect();
  await server.close();
  flushLoggerSync();
  process.exit(exitCode);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
```

**Error Handling**:
- `uncaughtException`: 致命错误,写入 stderr 后退出(exit 1)
- `unhandledRejection`: 仅记录到 stderr,保持非致命(可用性优先)

---

## Claude Code 集成细节

### PreToolUse Hook

**脚本**: `gitnexus/hooks/claude/pre-tool-use.sh`

**触发**: Claude Code 调用 Grep / Glob / Bash(rg/grep) 工具前

**输入**(stdin JSON):
```json
{
  "tool_name": "Grep",
  "tool_input": {
    "pattern": "validateUser",
    "path": "/Users/dev/projects/my-app"
  },
  "cwd": "/Users/dev/projects/my-app/src"
}
```

**执行逻辑**:
1. 提取搜索 pattern:
   - `Grep` → `.tool_input.pattern`
   - `Glob` → 从 pattern 提取有意义部分(如 `auth*.ts` → `auth`)
   - `Bash` → 仅处理含 `rg` 或 `grep` 的命令,用 sed 提取 pattern
   - 其他工具 → exit 0
2. Pattern < 3 字符 → exit 0
3. 从 CWD 向上遍历 5 层目录检查 `.gitnexus/` 目录
4. 未找到索引 → exit 0
5. 运行 `npx -y gitnexus augment <pattern> 2>&1 1>/dev/null`
   - **注意**: augment 写入 stderr(因为 KuzuDB 在 OS 级别捕获 stdout)
6. 有结果 → 包装为 JSON:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[GitNexus] 3 related symbols found:\n\nvalidateUser (src/auth/validate.ts)\n  Called by: loginHandler, apiMiddleware\n  Calls: checkPassword, createSession\n  Flows: LoginFlow (step 2/7)\n"
  }
}
```

### Augmentation Engine

**源码**: `gitnexus/src/core/augmentation/engine.ts`

**性能目标**: <500ms cold start, <200ms warm

**设计决策**:
- 只用 BM25 搜索(不用 semantic/embedding) → 为了速度
- Cluster 仅用于内部排名,绝不暴露在输出中
- 输出纯关系:callers, callees, process participation
- 优雅失败:任何错误返回空字符串

**执行步骤**:

**Step 1: 查找仓库**(`findRepoForCwd`):
- 调用 `listRegisteredRepos({ validate: true })`
- 最长前缀匹配(Windows 处理大小写)
- 检查 cwd 在 repo 内、repo 在 cwd 内、或完全相等

**Step 2: 懒加载 LadybugDB**:
```typescript
const { initLbug, executeQuery, isLbugReady } = await import('../lbug/pool-adapter.js');
if (!isLbugReady(repoId)) {
  await initLbug(repoId, repo.lbugPath);
}
```

**Step 3: BM25 搜索**:
```typescript
const bm25Results = await searchFTSFromLbug(pattern, 10, repoId);
```
取前 10 个文件结果。

**Step 4: Symbol 匹配**:
对每个 BM25 结果(前 5 个),执行 Cypher:
```cypher
MATCH (n) WHERE n.filePath = '<file>' AND n.name CONTAINS '<pattern>' 
RETURN n.id, n.name, labels(n)[0], n.filePath LIMIT 3
```

**Step 5: Batch fetch callers**(15 条限制):
```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(n) 
WHERE n.id IN [ids] 
RETURN n.id AS targetId, caller.name AS name LIMIT 15
```

**Step 6: Batch fetch callees**(15 条限制):
```cypher
MATCH (n)-[:CodeRelation {type: 'CALLS'}]->(callee) 
WHERE n.id IN [ids] 
RETURN n.id AS sourceId, callee.name AS name LIMIT 15
```

**Step 7: Batch fetch processes**:
```cypher
MATCH (n)-[r:CodeRelation {type: 'STEP_IN_PROCESS'}]->(p:Process) 
WHERE n.id IN [ids] 
RETURN n.id AS nodeId, p.heuristicLabel AS label, r.step AS step, p.stepCount AS stepCount
```

**Step 8: Batch fetch cohesion**:
```cypher
MATCH (n)-[:CodeRelation {type: 'MEMBER_OF'}]->(c:Community) 
WHERE n.id IN [ids] 
RETURN n.id AS nodeId, c.cohesion AS cohesion
```

**Step 9: 组装结果**:
- callers/callees 各取前 3 个
- 按 cohesion 降序排序
- 格式化输出:
```
[GitNexus] 3 related symbols found:

validateUser (src/auth/validate.ts)
  Called by: loginHandler, apiMiddleware
  Calls: checkPassword, createSession
  Flows: LoginFlow (step 2/7)
```

### PostToolUse Hook / Staleness 检测

**实现**: `gitnexus/src/core/git-staleness.ts`

**触发**: `git commit` / `git merge` 后

**`checkStaleness(repoPath, lastCommit)`**:
```typescript
const result = execFileSync('git', ['rev-list', '--count', `${lastCommit}..HEAD`], {
  cwd: repoPath,
  encoding: 'utf-8',
  stdio: ['pipe', 'pipe', 'pipe'],
}).trim();
const commitsBehind = parseInt(result, 10) || 0;
if (commitsBehind > 0) {
  return {
    isStale: true,
    commitsBehind,
    hint: `⚠️ Index is ${commitsBehind} commit${commitsBehind > 1 ? 's' : ''} behind HEAD. Run analyze tool to update.`,
  };
}
return { isStale: false, commitsBehind: 0 };
```

**`checkCwdMatch(cwd)` 的三层匹配**:

1. **Path match**: cwd 在注册 repo 的路径内,最长前缀优先
2. **Sibling-by-remote**: cwd 不在注册路径内,但 `.git` 的 remote URL 与某个注册 repo 相同(不同克隆)
   - 计算 drift: `git rev-list --count <indexedCommit>..HEAD`
   - 如果 drift > 0,返回警告:
     ```
     ⚠️ Index for "my-app" was built at /path/to/original; 
     your cwd (/path/to/clone) is a sibling clone that is 3 commits ahead of the indexed commit. 
     Results may be stale or incorrect — re-run `gitnexus analyze` to refresh the index.
     ```
3. **None**: 不匹配

**关键设计**: PostToolUse hook 只提示 agent "Index is stale",不自动运行 analyze。
原因:
- analyze 可能阻塞 agent 长达 120 秒
- KuzuDB timeout 可能导致数据库损坏

---

## 自动安装的 Skills(7 个)

运行 `gitnexus analyze` 时,以下 skill 被自动安装到 `.claude/skills/gitnexus/`:

### 1. gitnexus-cli

```markdown
---
name: gitnexus-cli
description: "Use when the user needs to run GitNexus CLI commands like analyze/index a repo, check status, clean the index, generate a wiki, or list indexed repos. Examples: \"Index this repo\", \"Reanalyze the codebase\", \"Generate a wiki\""
---

# GitNexus CLI Commands

All commands work via `npx` — no global install required.

## Commands

### analyze — Build or refresh the index

```bash
npx gitnexus analyze
```

Run from the project root. This parses all source files, builds the knowledge graph, writes it to `.gitnexus/`, and generates CLAUDE.md / AGENTS.md context files.

| Flag                | Effect                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------- |
| `--force`           | Force full re-index even if up to date                                                                  |
| `--embeddings`      | Enable embedding generation for semantic search (off by default)                                        |
| `--drop-embeddings` | Drop existing embeddings on rebuild. By default, an `analyze` without `--embeddings` preserves them.    |

**When to run:** First time in a project, after major code changes, or when `gitnexus://repo/{name}/context` reports the index is stale. In Claude Code, a PostToolUse hook detects staleness after `git commit` and `git merge` and notifies the agent to run `analyze` — the hook does not run analyze itself, to avoid blocking the agent for up to 120s and risking KuzuDB corruption on timeout.

### status — Check index freshness

```bash
npx gitnexus status
```

Shows whether the current repo has a GitNexus index, when it was last updated, and symbol/relationship counts. Use this to check if re-indexing is needed.

### clean — Delete the index

```bash
npx gitnexus clean
```

Deletes the `.gitnexus/` directory and unregisters the repo from the global registry. Use before re-indexing if the index is corrupt or after removing GitNexus from a project.

| Flag      | Effect                                            |
| --------- | ------------------------------------------------- |
| `--force` | Skip confirmation prompt                          |
| `--all`   | Clean all indexed repos, not just the current one |

### wiki — Generate documentation from the graph

```bash
npx gitnexus wiki
```

Generates repository documentation from the knowledge graph using an LLM. Requires an API key (saved to `~/.gitnexus/config.json` on first use).

| Flag                | Effect                                    |
| ------------------- | ----------------------------------------- |
| `--force`           | Force full regeneration                   |
| `--model <model>`   | LLM model (default: minimax/minimax-m2.5) |
| `--base-url <url>`  | LLM API base URL                          |
| `--api-key <key>`   | LLM API key                               |
| `--concurrency <n>` | Parallel LLM calls (default: 3)           |
| `--gist`            | Publish wiki as a public GitHub Gist      |

### list — Show all indexed repos

```bash
npx gitnexus list
```

Lists all repositories registered in `~/.gitnexus/registry.json`. The MCP `list_repos` tool provides the same information.

## After Indexing

1. **Read `gitnexus://repo/{name}/context`** to verify the index loaded
2. Use the other GitNexus skills (`exploring`, `debugging`, `impact-analysis`, `refactoring`) for your task

## Troubleshooting

- **"Not inside a git repository"**: Run from a directory inside a git repo
- **Index is stale after re-analyzing**: Restart Claude Code to reload the MCP server
- **Embeddings slow**: Omit `--embeddings` (it's off by default) or set `OPENAI_API_KEY` for faster API-based embedding
```

---

### 2. gitnexus-exploring

```markdown
---
name: gitnexus-exploring
description: "Use when the user asks how code works, wants to understand architecture, trace execution flows, or explore unfamiliar parts of the codebase. Examples: \"How does X work?\", \"What calls this function?\", \"Show me the auth flow\""
---

# Exploring Codebases with GitNexus

## When to Use

- "How does authentication work?"
- "What's the project structure?"
- "Show me the main components"
- "Where is the database logic?"
- Understanding code you haven't seen before

## Workflow

```
1. READ gitnexus://repos                          → Discover indexed repos
2. READ gitnexus://repo/{name}/context             → Codebase overview, check staleness
3. gitnexus_query({query: "<what you want to understand>"})  → Find related execution flows
4. gitnexus_context({name: "<symbol>"})            → Deep dive on specific symbol
5. READ gitnexus://repo/{name}/process/{name}      → Trace full execution flow
```

> If step 2 says "Index is stale" → run `npx gitnexus analyze` in terminal.

## Checklist

```
- [ ] READ gitnexus://repo/{name}/context
- [ ] gitnexus_query for the concept you want to understand
- [ ] Review returned processes (execution flows)
- [ ] gitnexus_context on key symbols for callers/callees
- [ ] READ process resource for full execution traces
- [ ] Read source files for implementation details
```

## Resources

| Resource                                | What you get                                            |
| --------------------------------------- | ------------------------------------------------------- |
| `gitnexus://repo/{name}/context`        | Stats, staleness warning (~150 tokens)                  |
| `gitnexus://repo/{name}/clusters`       | All functional areas with cohesion scores (~300 tokens) |
| `gitnexus://repo/{name}/cluster/{name}` | Area members with file paths (~500 tokens)              |
| `gitnexus://repo/{name}/process/{name}` | Step-by-step execution trace (~200 tokens)              |

## Tools

**gitnexus_query** — find execution flows related to a concept:

```
gitnexus_query({query: "payment processing"})
→ Processes: CheckoutFlow, RefundFlow, WebhookHandler
→ Symbols grouped by flow with file locations
```

**gitnexus_context** — 360-degree view of a symbol:

```
gitnexus_context({name: "validateUser"})
→ Incoming calls: loginHandler, apiMiddleware
→ Outgoing calls: checkToken, getUserById
→ Processes: LoginFlow (step 2/5), TokenRefresh (step 1/3)
```

## Example: "How does payment processing work?"

```
1. READ gitnexus://repo/my-app/context       → 918 symbols, 45 processes
2. gitnexus_query({query: "payment processing"})
   → CheckoutFlow: processPayment → validateCard → chargeStripe
   → RefundFlow: initiateRefund → calculateRefund → processRefund
3. gitnexus_context({name: "processPayment"})
   → Incoming: checkoutHandler, webhookHandler
   → Outgoing: validateCard, chargeStripe, saveTransaction
4. Read src/payments/processor.ts for implementation details
```
```

---

### 3. gitnexus-debugging

```markdown
---
name: gitnexus-debugging
description: "Use when the user is debugging a bug, tracing an error, or asking why something fails. Examples: \"Why is X failing?\", \"Where does this error come from?\", \"Trace this bug\""
---

# Debugging with GitNexus

## When to Use

- "Why is this function failing?"
- "Trace where this error comes from"
- "Who calls this method?"
- "This endpoint returns 500"
- Investigating bugs, errors, or unexpected behavior

## Workflow

```
1. gitnexus_query({query: "<error or symptom>"})            → Find related execution flows
2. gitnexus_context({name: "<suspect>"})                    → See callers/callees/processes
3. READ gitnexus://repo/{name}/process/{name}                → Trace execution flow
4. gitnexus_cypher({query: "MATCH path..."})                 → Custom traces if needed
```

> If "Index is stale" → run `npx gitnexus analyze` in terminal.

## Checklist

```
- [ ] Understand the symptom (error message, unexpected behavior)
- [ ] gitnexus_query for error text or related code
- [ ] Identify the suspect function from returned processes
- [ ] gitnexus_context to see callers and callees
- [ ] Trace execution flow via process resource if applicable
- [ ] gitnexus_cypher for custom call chain traces if needed
- [ ] Read source files to confirm root cause
```

## Debugging Patterns

| Symptom              | GitNexus Approach                                          |
| -------------------- | ---------------------------------------------------------- |
| Error message        | `gitnexus_query` for error text → `context` on throw sites |
| Wrong return value   | `context` on the function → trace callees for data flow    |
| Intermittent failure | `context` → look for external calls, async deps            |
| Performance issue    | `context` → find symbols with many callers (hot paths)     |
| Recent regression    | `detect_changes` to see what your changes affect           |

## Tools

**gitnexus_query** — find code related to error:

```
gitnexus_query({query: "payment validation error"})
→ Processes: CheckoutFlow, ErrorHandling
→ Symbols: validatePayment, handlePaymentError, PaymentException
```

**gitnexus_context** — full context for a suspect:

```
gitnexus_context({name: "validatePayment"})
→ Incoming calls: processCheckout, webhookHandler
→ Outgoing calls: verifyCard, fetchRates (external API!)
→ Processes: CheckoutFlow (step 3/7)
```

**gitnexus_cypher** — custom call chain traces:

```cypher
MATCH path = (a)-[:CodeRelation {type: 'CALLS'}*1..2]->(b:Function {name: "validatePayment"})
RETURN [n IN nodes(path) | n.name] AS chain
```

## Example: "Payment endpoint returns 500 intermittently"

```
1. gitnexus_query({query: "payment error handling"})
   → Processes: CheckoutFlow, ErrorHandling
   → Symbols: validatePayment, handlePaymentError

2. gitnexus_context({name: "validatePayment"})
   → Outgoing calls: verifyCard, fetchRates (external API!)

3. READ gitnexus://repo/my-app/process/CheckoutFlow
   → Step 3: validatePayment → calls fetchRates (external)

4. Root cause: fetchRates calls external API without proper timeout
```
```

---

### 4. gitnexus-impact-analysis

```markdown
---
name: gitnexus-impact-analysis
description: "Use when the user wants to know what will break if they change something, or needs safety analysis before editing code. Examples: \"Is it safe to change X?\", \"What depends on this?\", \"What will break?\""
---

# Impact Analysis with GitNexus

## When to Use

- "Is it safe to change this function?"
- "What will break if I modify X?"
- "Show me the blast radius"
- "Who uses this code?"
- Before making non-trivial code changes
- Before committing — to understand what your changes affect

## Workflow

```
1. gitnexus_impact({target: "X", direction: "upstream"})  → What depends on this
2. READ gitnexus://repo/{name}/processes                   → Check affected execution flows
3. gitnexus_detect_changes()                               → Map current git changes to affected flows
4. Assess risk and report to user
```

> If "Index is stale" → run `npx gitnexus analyze` in terminal.

## Checklist

```
- [ ] gitnexus_impact({target, direction: "upstream"}) to find dependents
- [ ] Review d=1 items first (these WILL BREAK)
- [ ] Check high-confidence (>0.8) dependencies
- [ ] READ processes to check affected execution flows
- [ ] gitnexus_detect_changes() for pre-commit check
- [ ] Assess risk level and report to user
```

## Understanding Output

| Depth | Risk Level       | Meaning                  |
| ----- | ---------------- | ------------------------ |
| d=1   | **WILL BREAK**   | Direct callers/importers |
| d=2   | LIKELY AFFECTED  | Indirect dependencies    |
| d=3   | MAY NEED TESTING | Transitive effects       |

## Risk Assessment

| Affected                       | Risk     |
| ------------------------------ | -------- |
| <5 symbols, few processes      | LOW      |
| 5-15 symbols, 2-5 processes    | MEDIUM   |
| >15 symbols or many processes  | HIGH     |
| Critical path (auth, payments) | CRITICAL |

## Tools

**gitnexus_impact** — the primary tool for symbol blast radius:

```
gitnexus_impact({
  target: "validateUser",
  direction: "upstream",
  minConfidence: 0.8,
  maxDepth: 3
})

→ d=1 (WILL BREAK):
  - loginHandler (src/auth/login.ts:42) [CALLS, 100%]
  - apiMiddleware (src/api/middleware.ts:15) [CALLS, 100%]

→ d=2 (LIKELY AFFECTED):
  - authRouter (src/routes/auth.ts:22) [CALLS, 95%]
```

**gitnexus_detect_changes** — git-diff based impact analysis:

```
gitnexus_detect_changes({scope: "staged"})

→ Changed: 5 symbols in 3 files
→ Affected: LoginFlow, TokenRefresh, APIMiddlewarePipeline
→ Risk: MEDIUM
```

## Example: "What breaks if I change validateUser?"

```
1. gitnexus_impact({target: "validateUser", direction: "upstream"})
   → d=1: loginHandler, apiMiddleware (WILL BREAK)
   → d=2: authRouter, sessionManager (LIKELY AFFECTED)

2. READ gitnexus://repo/my-app/processes
   → LoginFlow and TokenRefresh touch validateUser

3. Risk: 2 direct callers, 2 processes = MEDIUM
```
```

---

### 5. gitnexus-refactoring

```markdown
---
name: gitnexus-refactoring
description: "Use when the user wants to rename, extract, split, move, or restructure code safely. Examples: \"Rename this function\", \"Extract this into a module\", \"Refactor this class\", \"Move this to a separate file\""
---

# Refactoring with GitNexus

## When to Use

- "Rename this function safely"
- "Extract this into a module"
- "Split this service"
- "Move this to a new file"
- Any task involving renaming, extracting, splitting, or restructuring code

## Workflow

```
1. gitnexus_impact({target: "X", direction: "upstream"})  → Map all dependents
2. gitnexus_query({query: "X"})                            → Find execution flows involving X
3. gitnexus_context({name: "X"})                           → See all incoming/outgoing refs
4. Plan update order: interfaces → implementations → callers → tests
```

> If "Index is stale" → run `npx gitnexus analyze` in terminal.

## Checklists

### Rename Symbol

```
- [ ] gitnexus_rename({symbol_name: "oldName", new_name: "newName", dry_run: true}) — preview all edits
- [ ] Review graph edits (high confidence) and ast_search edits (review carefully)
- [ ] If satisfied: gitnexus_rename({..., dry_run: false}) — apply edits
- [ ] gitnexus_detect_changes() — verify only expected files changed
- [ ] Run tests for affected processes
```

### Extract Module

```
- [ ] gitnexus_context({name: target}) — see all incoming/outgoing refs
- [ ] gitnexus_impact({target, direction: "upstream"}) — find all external callers
- [ ] Define new module interface
- [ ] Extract code, update imports
- [ ] gitnexus_detect_changes() — verify affected scope
- [ ] Run tests for affected processes
```

### Split Function/Service

```
- [ ] gitnexus_context({name: target}) — understand all callees
- [ ] Group callees by responsibility
- [ ] gitnexus_impact({target, direction: "upstream"}) — map callers to update
- [ ] Create new functions/services
- [ ] Update callers
- [ ] gitnexus_detect_changes() — verify affected scope
- [ ] Run tests for affected processes
```

## Tools

**gitnexus_rename** — automated multi-file rename:

```
gitnexus_rename({symbol_name: "validateUser", new_name: "authenticateUser", dry_run: true})
→ 12 edits across 8 files
→ 10 graph edits (high confidence), 2 ast_search edits (review)
→ Changes: [{file_path, edits: [{line, old_text, new_text, confidence}]}]
```

**gitnexus_impact** — map all dependents first:

```
gitnexus_impact({target: "validateUser", direction: "upstream"})
→ d=1: loginHandler, apiMiddleware, testUtils
→ Affected Processes: LoginFlow, TokenRefresh
```

**gitnexus_detect_changes** — verify your changes after refactoring:

```
gitnexus_detect_changes({scope: "all"})
→ Changed: 8 files, 12 symbols
→ Affected processes: LoginFlow, TokenRefresh
→ Risk: MEDIUM
```

**gitnexus_cypher** — custom reference queries:

```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function {name: "validateUser"})
RETURN caller.name, caller.filePath ORDER BY caller.filePath
```

## Risk Rules

| Risk Factor         | Mitigation                                |
| ------------------- | ----------------------------------------- |
| Many callers (>5)   | Use gitnexus_rename for automated updates |
| Cross-area refs     | Use detect_changes after to verify scope  |
| String/dynamic refs | gitnexus_query to find them               |
| External/public API | Version and deprecate properly            |

## Example: Rename `validateUser` to `authenticateUser`

```
1. gitnexus_rename({symbol_name: "validateUser", new_name: "authenticateUser", dry_run: true})
   → 12 edits: 10 graph (safe), 2 ast_search (review)
   → Files: validator.ts, login.ts, middleware.ts, config.json...

2. Review ast_search edits (config.json: dynamic reference!)

3. gitnexus_rename({symbol_name: "validateUser", new_name: "authenticateUser", dry_run: false})
   → Applied 12 edits across 8 files

4. gitnexus_detect_changes({scope: "all"})
   → Affected: LoginFlow, TokenRefresh
   → Risk: MEDIUM — run tests for these flows
```
```

---

### 6. gitnexus-pr-review

```markdown
---
name: gitnexus-pr-review
description: "Use when the user wants to review a pull request, understand what a PR changes, assess risk of merging, or check for missing test coverage. Examples: \"Review this PR\", \"What does PR #42 change?\", \"Is this PR safe to merge?\""
---

# PR Review with GitNexus

## When to Use

- "Review this PR"
- "What does PR #42 change?"
- "Is this safe to merge?"
- "What's the blast radius of this PR?"
- "Are there missing tests for this PR?"
- Reviewing someone else's code changes before merge

## Workflow

```
1. gh pr diff <number>                                    → Get the raw diff
2. gitnexus_detect_changes({scope: "compare", base_ref: "main"})  → Map diff to affected flows
3. For each changed symbol:
   gitnexus_impact({target: "<symbol>", direction: "upstream"})    → Blast radius per change
4. gitnexus_context({name: "<key symbol>"})               → Understand callers/callees
5. READ gitnexus://repo/{name}/processes                   → Check affected execution flows
6. Summarize findings with risk assessment
```

> If "Index is stale" → run `npx gitnexus analyze` in terminal before reviewing.

## Checklist

```
- [ ] Fetch PR diff (gh pr diff or git diff base...head)
- [ ] gitnexus_detect_changes to map changes to affected execution flows
- [ ] gitnexus_impact on each non-trivial changed symbol
- [ ] Review d=1 items (WILL BREAK) — are callers updated?
- [ ] gitnexus_context on key changed symbols to understand full picture
- [ ] Check if affected processes have test coverage
- [ ] Assess overall risk level
- [ ] Write review summary with findings
```

## Review Dimensions

| Dimension | How GitNexus Helps |
| --- | --- |
| **Correctness** | `context` shows callers — are they all compatible with the change? |
| **Blast radius** | `impact` shows d=1/d=2/d=3 dependents — anything missed? |
| **Completeness** | `detect_changes` shows all affected flows — are they all handled? |
| **Test coverage** | `impact({includeTests: true})` shows which tests touch changed code |
| **Breaking changes** | d=1 upstream items that aren't updated in the PR = potential breakage |

## Risk Assessment

| Signal | Risk |
| --- | --- |
| Changes touch <3 symbols, 0-1 processes | LOW |
| Changes touch 3-10 symbols, 2-5 processes | MEDIUM |
| Changes touch >10 symbols or many processes | HIGH |
| Changes touch auth, payments, or data integrity code | CRITICAL |
| d=1 callers exist outside the PR diff | Potential breakage — flag it |

## Tools

**gitnexus_detect_changes** — map PR diff to affected execution flows:

```
gitnexus_detect_changes({scope: "compare", base_ref: "main"})

→ Changed: 8 symbols in 4 files
→ Affected processes: CheckoutFlow, RefundFlow, WebhookHandler
→ Risk: MEDIUM
```

**gitnexus_impact** — blast radius per changed symbol:

```
gitnexus_impact({target: "validatePayment", direction: "upstream"})

→ d=1 (WILL BREAK):
  - processCheckout (src/checkout.ts:42) [CALLS, 100%]
  - webhookHandler (src/webhooks.ts:15) [CALLS, 100%]

→ d=2 (LIKELY AFFECTED):
  - checkoutRouter (src/routes/checkout.ts:22) [CALLS, 95%]
```

**gitnexus_impact with tests** — check test coverage:

```
gitnexus_impact({target: "validatePayment", direction: "upstream", includeTests: true})

→ Tests that cover this symbol:
  - validatePayment.test.ts [direct]
  - checkout.integration.test.ts [via processCheckout]
```

**gitnexus_context** — understand a changed symbol's role:

```
gitnexus_context({name: "validatePayment"})

→ Incoming calls: processCheckout, webhookHandler
→ Outgoing calls: verifyCard, fetchRates
→ Processes: CheckoutFlow (step 3/7), RefundFlow (step 1/5)
```

## Example: "Review PR #42"

```
1. gh pr diff 42 > /tmp/pr42.diff
   → 4 files changed: payments.ts, checkout.ts, types.ts, utils.ts

2. gitnexus_detect_changes({scope: "compare", base_ref: "main"})
   → Changed symbols: validatePayment, PaymentInput, formatAmount
   → Affected processes: CheckoutFlow, RefundFlow
   → Risk: MEDIUM

3. gitnexus_impact({target: "validatePayment", direction: "upstream"})
   → d=1: processCheckout, webhookHandler (WILL BREAK)
   → webhookHandler is NOT in the PR diff — potential breakage!

4. gitnexus_impact({target: "PaymentInput", direction: "upstream"})
   → d=1: validatePayment (in PR), createPayment (NOT in PR)
   → createPayment uses the old PaymentInput shape — breaking change!

5. gitnexus_context({name: "formatAmount"})
   → Called by 12 functions — but change is backwards-compatible (added optional param)

6. Review summary:
   - MEDIUM risk — 3 changed symbols affect 2 execution flows
   - BUG: webhookHandler calls validatePayment but isn't updated for new signature
   - BUG: createPayment depends on PaymentInput type which changed
   - OK: formatAmount change is backwards-compatible
   - Tests: checkout.test.ts covers processCheckout path, but no webhook test
```

## Review Output Format

Structure your review as:

```markdown
## PR Review: <title>

**Risk: LOW / MEDIUM / HIGH / CRITICAL**

### Changes Summary
- <N> symbols changed across <M> files
- <P> execution flows affected

### Findings
1. **[severity]** Description of finding
   - Evidence from GitNexus tools
   - Affected callers/flows

### Missing Coverage
- Callers not updated in PR: ...
- Untested flows: ...

### Recommendation
APPROVE / REQUEST CHANGES / NEEDS DISCUSSION
```
```

---

### 7. gitnexus-guide

```markdown
---
name: gitnexus-guide
description: "Use when the user asks about GitNexus itself — available tools, how to query the knowledge graph, MCP resources, graph schema, or workflow reference. Examples: \"What GitNexus tools are available?\", \"How do I use GitNexus?\""
---

# GitNexus Guide

Quick reference for all GitNexus MCP tools, resources, and the knowledge graph schema.

## Always Start Here

For any task involving code understanding, debugging, impact analysis, or refactoring:

1. **Read `gitnexus://repo/{name}/context`** — codebase overview + check index freshness
2. **Match your task to a skill below** and **read that skill file**
3. **Follow the skill's workflow and checklist**

> If step 1 warns the index is stale, run `npx gitnexus analyze` in the terminal first.

## Skills

| Task                                         | Skill to read       |
| -------------------------------------------- | ------------------- |
| Understand architecture / "How does X work?" | `gitnexus-exploring`         |
| Blast radius / "What breaks if I change X?"  | `gitnexus-impact-analysis`   |
| Trace bugs / "Why is X failing?"             | `gitnexus-debugging`         |
| Rename / extract / split / refactor          | `gitnexus-refactoring`       |
| Tools, resources, schema reference           | `gitnexus-guide` (this file) |
| Index, status, clean, wiki CLI commands      | `gitnexus-cli`               |

## Tools Reference

| Tool             | What it gives you                                                        |
| ---------------- | ------------------------------------------------------------------------ |
| `query`          | Process-grouped code intelligence — execution flows related to a concept |
| `context`        | 360-degree symbol view — categorized refs, processes it participates in  |
| `impact`         | Symbol blast radius — what breaks at depth 1/2/3 with confidence         |
| `detect_changes` | Git-diff impact — what do your current changes affect                    |
| `rename`         | Multi-file coordinated rename with confidence-tagged edits               |
| `cypher`         | Raw graph queries (read `gitnexus://repo/{name}/schema` first)           |
| `list_repos`     | Discover indexed repos                                                   |

## Resources Reference

Lightweight reads (~100-500 tokens) for navigation:

| Resource                                       | Content                                   |
| ---------------------------------------------- | ----------------------------------------- |
| `gitnexus://repo/{name}/context`               | Stats, staleness check                    |
| `gitnexus://repo/{name}/clusters`              | All functional areas with cohesion scores |
| `gitnexus://repo/{name}/cluster/{clusterName}` | Area members                              |
| `gitnexus://repo/{name}/processes`             | All execution flows                       |
| `gitnexus://repo/{name}/process/{processName}` | Step-by-step trace                        |
| `gitnexus://repo/{name}/schema`                | Graph schema for Cypher                   |

## Graph Schema

**Nodes:** File, Function, Class, Interface, Method, Community, Process
**Edges (via CodeRelation.type):** CALLS, IMPORTS, EXTENDS, IMPLEMENTS, DEFINES, MEMBER_OF, STEP_IN_PROCESS

```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function {name: "myFunc"})
RETURN caller.name, caller.filePath
```
```

---

## Repo-specific Skills(`--skills` 生成)

运行 `gitnexus analyze --skills` 时,GitNexus 通过 Leiden 社区检测识别代码库的功能区域,**每个社区生成一个 SKILL.md**。

**生成路径**: `.claude/skills/generated/SKILL.md`

**每个 skill 包含**:
- 模块名称(基于 heuristic label)
- 关键文件列表
- 入口点函数
- 执行流列表
- 跨社区连接

**示例生成内容**:
```markdown
---
name: generated-auth-module
description: "Authentication module — handles login, logout, token refresh, and session management"
---

# Authentication Module

## Key Files
- src/auth/login.ts
- src/auth/logout.ts
- src/auth/tokens.ts
- src/middleware/auth.ts

## Entry Points
- handleLogin
- handleLogout
- refreshToken

## Execution Flows
- LoginFlow: handleLogin → validateUser → checkPassword → createSession
- TokenRefreshFlow: refreshToken → verifyToken → issueNewToken

## Cross-Area Connections
- Calls: UserModule (getUserById), SessionModule (createSession)
- Called by: APIModule (authMiddleware), WebhookModule (verifyWebhook)
```

**重新生成**: 每次运行 `--skills` 时重新生成,以保持与代码库同步。

---

## 使用姿势

### 安装与初始化

```bash
npm install -g gitnexus
# 跳过可选语言(无需 C++ toolchain):
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g gitnexus

gitnexus setup  # 自动检测编辑器,写入 MCP 配置
```

### 索引仓库

```bash
cd your-project
gitnexus analyze --skills   # 生成仓库特定 SKILL.md
```

### 日常维护

```bash
gitnexus status    # 索引是否过期
gitnexus analyze   # 更新索引
gitnexus wiki      # 生成文档(需 OPENAI_API_KEY)
gitnexus serve     # 启动 Web UI(Bridge Mode)
```

---

## 竞品对比

| 维度 | GitNexus | Sourcegraph Cody | Aider | GitHub Copilot Workspace | CodeRabbit |
|------|----------|------------------|-------|-------------------------|------------|
| 代码图谱 | 预计算完整图谱(依赖+调用链+类型+执行流) | Code Graph(符号关系) | 无持久化图谱 | 无持久化图谱 | 架构图(仅 PR 阶段) |
| 影响分析 | 开发时预计算,单次返回 | 无专用影响分析工具 | LLM 推理找相关文件 | LLM 推理规划 | PR review 时分析 |
| 部署方式 | CLI + Web UI,完全本地 | SaaS/私有化 | CLI,本地 | Cloud | SaaS |
| 隐私 | 完全本地,无网络 | 需上传代码 | 本地 | 需上传代码 | 需访问 PR |
| 非代码资产 | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |

**与 graphify 的取舍**:
- graphify:支持 PDF/图片/白板照片的多模态知识图谱,代码解析停留在 AST walk + 名字匹配
- GitNexus:编译器级解析 + 预计算关系 + MCP 工具链,专为 AI Agent 改代码设计
- 两者解决的问题域几乎不重叠

---

## 结语

GitNexus 的设计指向一个明确目标:**让 AI Agent 拥有代码库的结构化记忆**。从 12-phase DAG 的编译器级解析,到数值化的 confidence 体系,到 PreToolUse/PostToolUse hooks 的 Agent 集成,每一个设计决策都围绕"Agent 改代码时不漏依赖、不打破调用链"。

在 AI 编码工具越来越强的今天,**代码库的结构化表示**正在成为新的基础设施。GitNexus 是这个方向上的一个重要探索。

---

**参考**:
- [GitNexus GitHub](https://github.com/abhigyanpatwari/GitNexus)
- 本文源码阅读基于 v1.7.0 (refer/GitNexus/)
- 关键源码文件: `gitnexus/src/core/ingestion/pipeline-phases/`, `gitnexus/src/core/ingestion/community-processor.ts`, `gitnexus/src/core/ingestion/process-processor.ts`, `gitnexus/src/mcp/tools.ts`, `gitnexus/src/mcp/server.ts`, `gitnexus/src/mcp/resources.ts`, `gitnexus/src/core/augmentation/engine.ts`, `gitnexus/src/core/git-staleness.ts`, `gitnexus/hooks/claude/pre-tool-use.sh`
