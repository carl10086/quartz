---
title: "sub agents"
date: 2026-02-09
tags:
  - claude
---


## 1️⃣ Subagent 是什么？——从"公司组织架构"说起

### 生活类比

想象你是一家公司的 **CEO（Claude 主对话）**，你有很多事要做。你不可能事事亲为，所以你会：

* 让**实习生（Explore subagent）** 去查资料 —— 他只能"看"，不能"改"东西
* 让**项目经理（Plan subagent）** 去做规划 —— 他可以思考策略
* 让**专业顾问（自定义 subagent）** 处理特定领域 —— 比如安全审计、数据分析

每个人有**自己的工位（独立上下文窗口）**、**自己的职责说明（system prompt）**、**自己的工具箱（tool access）**、**自己的权限级别（permissions）**。

他们干完活后，**向你汇报结果**，而不是把所有工作笔记都堆在你桌上——这就是 subagent **保护主对话上下文** 的核心价值。

### 技术定义

> **Subagent** = 一个运行在独立上下文窗口中的专用 AI 助手，拥有：
> * 自定义 system prompt
> * 独立的工具访问权限
> * 独立的权限设置
> * 完成后向父对话返回结果摘要

### Subagent 解决的 5 个核心问题

| 问题 | Subagent 怎么解决 | 例子 |
|---|---|---|
| 主对话上下文被"撑爆" | 探索和实现在子上下文中进行 | 运行测试产生 500 行输出，只返回摘要 |
| 需要限制工具使用 | 指定 tools / disallowedTools | 代码审查 agent 不能修改代码 |
| 跨项目复用配置 | 放在 `~/.claude/agents/` | 个人专属的安全审计 agent |
| 需要特定领域行为 | 编写聚焦的 system prompt | 数据分析专家只关心 SQL |
| 控制成本 | 路由到更便宜的模型 | 用 Haiku 做文件搜索 |

---

## 2️⃣ 核心架构——Subagent 到底怎么运行的？

```
┌──────────────────────────────────────────────┐
│             主对话 (Main Conversation)          │
│                                              │
│  用户: "帮我审查一下这次 PR 的代码"              │
│                                              │
│  Claude 判断 → description 匹配 → 委派任务      │
│         ┌─────────────────────┐              │
│         │   code-reviewer      │              │
│         │   独立上下文窗口       │              │
│         │   System Prompt: ... │              │
│         │   Tools: Read, Grep  │              │
│         │   Model: haiku       │              │
│         │                     │              │
│         │  执行工作...          │              │
│         │  返回: "发现3个问题"   │              │
│         └─────────────────────┘              │
│                                              │
│  Claude: "审查结果如下: ..."                    │
└──────────────────────────────────────────────┘
```

**关键点：**
* Subagent **只收到自己的 system prompt** + 基本环境信息（如工作目录），**不会收到** Claude Code 的完整系统提示
* Subagent **不能嵌套生成** 其他 subagent（只有主对话可以委派）
* 完成后结果返回主对话，subagent 的上下文**不会污染**主对话

---

## 3️⃣ 内置 Subagent

Claude Code 自带三个"员工"，开箱即用：

### Explore（探索者）
* **模型**: Haiku（快、便宜）
* **工具**: 只读（不能用 Write 和 Edit）
* **用途**: 搜索文件、grep 代码、理解代码库
* **特点**: Claude 会指定探索的"彻底程度"：quick / medium / very thorough

> 🎯 **什么时候被触发？** 当 Claude 需要"了解"代码库但不需要修改时，自动委派给 Explore。比如你问"这个项目的认证模块在哪？"

### Plan（规划者）
* 专注于制定策略和计划

### General-purpose（通用）
* 更灵活的通用 subagent

---

## 4️⃣ 动手创建你的第一个 Subagent

### 文件结构

Subagent 就是一个 **Markdown 文件**，带有 **YAML frontmatter**：

```markdown
---
name: my-agent
description: 什么时候应该用这个 agent
tools: Read, Grep, Bash
model: haiku
---

这里是 system prompt（系统提示词）。
告诉 subagent 它是谁、该做什么、怎么做。
```

### 三种存放位置（作用域）

```
优先级从高到低：
┌─────────────────────────────────────────────┐
│  1. 项目级  .claude/agents/my-agent.md       │  ← 团队共享，提交到 Git
│  2. 用户级  ~/.claude/agents/my-agent.md     │  ← 个人专属，所有项目可用
│  3. CLI级   --agents '[{...}]'              │  ← 临时使用，不存盘
│  4. 插件级  来自安装的 plugins                 │  ← 第三方分发
└─────────────────────────────────────────────┘
```

**同名 subagent 的冲突规则**：优先级高的覆盖低的。

### 完整的 frontmatter 字段

| 字段 | 必填 | 含义 | 举例 |
|---|---|---|---|
| `name` | ✅ | 唯一标识符（小写+连字符） | `code-reviewer` |
| `description` | ✅ | Claude 用来判断何时委派 | `"Expert code reviewer. Use proactively..."` |
| `tools` | ❌ | 允许使用的工具（白名单） | `Read, Grep, Bash` |
| `disallowedTools` | ❌ | 禁止的工具（黑名单） | `Write, Edit` |
| `model` | ❌ | 使用的模型 | `haiku` / `sonnet` / `opus` / `inherit` |
| `permissionMode` | ❌ | 权限模式 | `default` / `acceptEdits` / `bypassPermissions` |
| `maxTurns` | ❌ | 最大轮次限制 | `10` |
| `skills` | ❌ | 启动时注入的技能 | `[coding-standards]` |
| `mcpServers` | ❌ | 可用的 MCP 服务器 | `["slack"]` |
| `hooks` | ❌ | 生命周期钩子 | `PreToolUse`, `PostToolUse` |
| `memory` | ❌ | 持久化记忆范围 | `user` / `project` / `local` |

---

## 5️⃣ 高级配置详解

### 5.1 模型选择策略

```
model: haiku    → 快速、便宜，适合探索和简单任务
model: sonnet   → 平衡，适合需要推理的工作
model: opus     → 最强，适合复杂分析
model: inherit  → 跟随主对话（默认）
```

> 💡 **成本优化技巧**: 只读探索用 `haiku`，代码修改用 `sonnet`，架构设计用 `opus`。

### 5.2 工具控制——白名单 vs 黑名单

**方式一：白名单（明确列出允许的工具）**
```yaml
tools: Read, Grep, Glob, Bash
# 只能用这 4 个工具，其他全部禁止
```

**方式二：黑名单（禁止特定工具）**
```yaml
disallowedTools: Write, Edit
# 除了 Write 和 Edit，其他都能用
```

**方式三：精细控制 subagent 生成（仅对 `--agent` 模式有效）**
```yaml
tools:
  - Read
  - Bash
  - Task(worker)     # 只能生成 worker subagent
  - Task(researcher)  # 只能生成 researcher subagent
```

### 5.3 Hooks——条件性规则

Hooks 让你在**工具执行前后**运行自定义脚本。

**经典场景：只允许只读 SQL 查询**

```yaml
---
name: db-reader
description: Read-only database query agent
tools: Bash, Read
hooks:
  PreToolUse:
    - matcher: Bash
      command: "./scripts/validate-sql.sh"
---
```

验证脚本 `validate-sql.sh` 做什么？
1. 从 stdin 读取 JSON（包含即将执行的 Bash 命令）
2. 检查命令中是否包含 `INSERT`, `UPDATE`, `DELETE` 等写操作
3. 如果发现写操作 → `exit 2`（阻止执行）
4. 如果是只读查询 → `exit 0`（放行）

> 🎯 `exit 2` 是 Claude Code Hooks 的特殊退出码，意思是"**阻止这次工具调用**"。

### 5.4 持久化记忆（Memory）

```yaml
memory: user     # 存在 ~/.claude/ 下，所有项目共享
memory: project  # 存在项目目录下，团队可共享
memory: local    # 存在本地，仅个人使用
```

开启后会发生什么？
* Subagent 获得一个**持久目录**
* 自动注入 `MEMORY.md` 的前 200 行到 system prompt
* 自动启用 Read/Write/Edit 工具来管理记忆文件

**最佳实践**：
```
"Review this PR, and check your memory for patterns you've seen before."
"Now that you're done, save what you learned to your memory."
```

随着时间推移，subagent 会**越来越懂你的项目**！

---

## 6️⃣ 使用模式

### 前台 vs 后台

| 特性 | 前台（Foreground） | 后台（Background） |
|---|---|---|
| 阻塞主对话？ | ✅ 是 | ❌ 否 |
| 权限请求 | 实时询问用户 | 启动前预先批准 |
| 用户交互 | 可以问问题 | 不能问（会失败但继续） |
| MCP 工具 | ✅ 可用 | ❌ 不可用 |
| 触发方式 | 自动或手动 | 说"run in background" 或按 `Ctrl+B` |

### 串行 vs 并行

**并行研究**：
```
"调查这 3 个区域的性能问题：
1. 数据库查询
2. API 响应时间
3. 前端渲染"
```
→ Claude 可能同时启动 3 个 subagent，各自独立调查，最后综合结果。

**串行链式**：
```
分析代码 → 提出修改方案 → 实施修改 → 运行测试
```
→ 每一步的结果传给下一个 subagent。

### 恢复（Resume）

Subagent 完成后会返回一个 **agent ID**。如果需要继续：
```
"继续之前那个代码审查的工作"
```
Claude 会恢复那个 subagent 的完整历史，从断点继续。

> 📁 Subagent 的对话记录存储在：`~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`

---

## 7️⃣ 实战案例分析

### 案例 1：Code Reviewer（只读审查）

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code 
  for quality, security, and maintainability. 
  Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards...
```

**设计要点分析**：
* `tools` 里**没有 Write 和 Edit** → 保证它"只看不改"
* `description` 里写了 "Use immediately after" → **主动触发**提示
* 提供了明确的**审查清单** → 输出结构化
* 反馈按**优先级分类** → 可操作性强

### 案例 2：Debugger（可以修 bug）

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, 
  and unexpected behavior. Use proactively when encountering any issues.
tools: Read, Edit, Bash, Grep, Glob
---
```

**对比 Code Reviewer**：多了 `Edit` → 因为修 bug 需要改代码

### 案例 3：Data Scientist

```markdown
---
name: data-scientist
description: Data analysis expert for SQL queries, BigQuery operations...
tools: Bash, Read, Write
model: sonnet
---
```

**设计要点**：
* 明确指定 `model: sonnet` → 数据分析需要更强的推理能力
* 有 `Write` → 需要写查询结果到文件
* 没有 `Edit` → 不需要修改现有代码

---

## 🧠 决策树：什么时候用什么？

```
需要 AI 帮忙？
├── 简单快速的修改 → 主对话
├── 需要频繁来回沟通 → 主对话
├── 会产生大量输出（测试/日志）→ Subagent ✅
├── 需要限制工具权限 → Subagent ✅
├── 自包含任务，返回摘要即可 → Subagent ✅
├── 需要多个 agent 并行+通信 → Agent Teams
└── 需要可复用的提示词/工作流 → Skills
```

---
