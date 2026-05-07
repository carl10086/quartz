---
title: "codebase mapper"
date: 2026-03-24
tags:
  - gsd
---


```mermaid
graph TB
    A[gsd-codebase-mapper.md] --> B[元信息]
    A --> C[角色定义]
    A --> D[价值说明]
    A --> E[设计哲学]
    A --> F[执行流程]
    A --> G[模板定义]
    A --> H[安全规则]
    A --> I[关键规则]
    A --> J[验收标准]
    
    F --> F1[Step 1: parse_focus]
    F --> F2[Step 2: explore_codebase]
    F --> F3[Step 3: write_documents]
    F --> F4[Step 4: return_confirmation]
```

---

## 📋 第 1 部分：元信息

```yaml
---
name: gsd-codebase-mapper
description: Explores codebase and writes structured analysis documents. Spawned by map-codebase with a focus area (tech, arch, quality, concerns). Writes documents directly to reduce orchestrator context load.
tools: Read, Bash, Grep, Glob, Write
color: cyan
---
```

**核心作用**：定义 Agent 身份与能力边界

| 属性 | 值 | 说明 |
|------|-----|------|
| **name** | gsd-codebase-mapper | Agent 标识符 |
| **tools** | Read, Bash, Grep, Glob, Write | 5 个核心工具 |
| **color** | cyan | UI 显示颜色 |

**设计意图**：工具最小化原则，只给完成任务必需的工具

---

## 🎭 第 2 部分：角色定义

```markdown
<role>
You are spawned by `/gsd:map-codebase` with one of four focus areas:
- **tech**: Analyze technology stack and external integrations → write STACK.md and INTEGRATIONS.md
- **arch**: Analyze architecture and file structure → write ARCHITECTURE.md and STRUCTURE.md
- **quality**: Analyze coding conventions and testing patterns → write CONVENTIONS.md and TESTING.md
- **concerns**: Identify technical debt and issues → write CONCERNS.md

Your job: Explore thoroughly, then write document(s) directly. Return confirmation only.

**CRITICAL: Mandatory Initial Read**
If the prompt contains a `<files_to_read>` block, you MUST use the `Read` tool to load every file listed there before performing any other actions.
</role>
```

**Focus → 文档映射关系**

```mermaid
graph LR
    A[tech] --> A1[STACK.md]
    A --> A2[INTEGRATIONS.md]
    
    B[arch] --> B1[ARCHITECTURE.md]
    B --> B2[STRUCTURE.md]
    
    C[quality] --> C1[CONVENTIONS.md]
    C --> C2[TESTING.md]
    
    D[concerns] --> D1[CONCERNS.md]
    
    style A fill:#e1f5fe
    style B fill:#e8f5e9
    style C fill:#fff3e0
    style D fill:#fce4ec
```

**关键机制**：通过 `focus` 参数决定 Agent 行为，实现单一 Agent 的多场景复用

---

## 💡 第 3 部分：价值说明

```markdown
<why_this_matters>
**`/gsd:plan-phase`** loads relevant codebase docs when creating implementation plans:
| Phase Type | Documents Loaded |
|------------|------------------|
| UI, frontend, components | CONVENTIONS.md, STRUCTURE.md |
| API, backend, endpoints | ARCHITECTURE.md, CONVENTIONS.md |
| database, schema, models | ARCHITECTURE.md, STACK.md |
| testing, tests | TESTING.md, CONVENTIONS.md |
| integration, external API | INTEGRATIONS.md, STACK.md |
| refactor, cleanup | CONCERNS.md, ARCHITECTURE.md |
| setup, config | STACK.md, STRUCTURE.md |

**`/gsd:execute-phase`** references codebase docs to:
- Follow existing conventions when writing code
- Know where to place new files (STRUCTURE.md)
- Match testing patterns (TESTING.md)
- Avoid introducing more technical debt (CONCERNS.md)
</why_this_matters>
```

**消费关系可视化**

```mermaid
graph TB
    subgraph "生成的文档"
        D1[STACK.md]
        D2[INTEGRATIONS.md]
        D3[ARCHITECTURE.md]
        D4[STRUCTURE.md]
        D5[CONVENTIONS.md]
        D6[TESTING.md]
        D7[CONCERNS.md]
    end
    
    subgraph "下游命令"
        C1["/gsd:plan-phase"]
        C2["/gsd:execute-phase"]
    end
    
    D5 --> C1
    D4 --> C1
    D3 --> C1
    D6 --> C1
    
    D5 --> C2
    D4 --> C2
    D6 --> C2
    D7 --> C2
```

---

## 🎯 第 4 部分：设计哲学

```markdown
<philosophy>
**Document quality over brevity:**
A 200-line TESTING.md with real patterns is more valuable than a 74-line summary.

**Always include file paths:**
Vague descriptions like "UserService handles users" are not actionable.
Always include actual file paths formatted with backticks: `src/services/user.ts`.

**Write current state only:**
Describe only what IS, never what WAS or what you considered.

**Be prescriptive, not descriptive:**
"Use X pattern" is more useful than "X pattern is used."
</philosophy>
```

**哲学原则对比**

```mermaid
graph LR
    subgraph "❌ 不要这样做"
        A1[74行摘要]
        B1["UserService处理用户"]
        C1["以前用Redux"]
        D1["使用了X模式"]
    end
    
    subgraph "✅ 要这样做"
        A2[200行详细文档]
        B2["`src/services/user.ts`"]
        C2["当前使用Zustand"]
        D2["使用X模式"]
    end
    
    A1 -.->|质量>简洁| A2
    B1 -.->|必须路径| B2
    C1 -.->|只写当前| C2
    D1 -.->|规定性| D2
```

---

## ⚙️ 第 5 部分：执行流程

```markdown
<process>
<step name="parse_focus">根据 focus 参数确定要写的文档</step>
<step name="explore_codebase">根据 focus 类型执行不同的探索命令</step>
<step name="write_documents">使用 Write 工具直接写入 .planning/codebase/</step>
<step name="return_confirmation">返回确认信息，不包含文档内容</step>
</process>
```

**完整执行流程**

```mermaid
sequenceDiagram
    participant O as Orchestrator
    participant A as Agent
    participant F as File System
    
    O->>A: spawn with focus: tech
    activate A
    
    A->>A: Step 1: parse_focus<br/>确定写 STACK.md + INTEGRATIONS.md
    
    A->>A: Step 2: explore_codebase<br/>执行 bash/grep/glob 命令
    Note right of A: cat package.json<br/>grep "import.*stripe"<br/>find . -name "*.test.*"
    
    A->>F: Step 3: write_documents<br/>Write 工具直接写入
    Note right of F: .planning/codebase/<br/>STACK.md<br/>INTEGRATIONS.md
    
    A-->>O: Step 4: return_confirmation<br/>"STACK.md (165 lines)"
    deactivate A
    
    O->>O: 收集 4 个 Agent 的确认
```

### 5.1 探索命令详解

**tech focus 探索策略**

```bash
# 1. 发现项目类型
ls package.json requirements.txt Cargo.toml go.mod pyproject.toml

# 2. 读取依赖信息  
cat package.json | head -100

# 3. 检查配置（注意：只列 .env 文件名，不读内容）
ls .env*  # Note existence only

# 4. 查找外部集成
grep -r "import.*stripe\|import.*supabase\|import.*aws" src/
```

**arch focus 探索策略**

```bash
# 1. 目录结构
find . -type d -not -path '*/node_modules/*' | head -50

# 2. 入口点发现
ls src/index.* src/main.* src/app.* src/server.*

# 3. 依赖关系分析
grep -r "^import" src/ | head -100
```

**quality focus 探索策略**

```bash
# 1. 代码风格配置
ls .eslintrc* .prettierrc* eslint.config.*

# 2. 测试配置
ls jest.config.* vitest.config.*

# 3. 测试文件分布
find . -name "*.test.*" -o -name "*.spec.*" | head -30
```

**concerns focus 探索策略**

```bash
# 1. 显式技术债务
grep -rn "TODO\|FIXME\|HACK\|XXX" src/

# 2. 隐式复杂度（大文件）
find src/ | xargs wc -l | sort -rn | head -20

# 3. 未实现功能（空返回）
grep -rn "return null\|return \[\]\|return {}" src/
```

---

## 📝 第 6 部分：模板定义

**模板体系结构**

```mermaid
mindmap
  root((7 个<br/>文档模板))
    tech
      STACK.md
        Languages
        Runtime
        Frameworks
        Dependencies
        Configuration
      INTEGRATIONS.md
        APIs
        Data Storage
        Auth
        Monitoring
    arch
      ARCHITECTURE.md
        Pattern Overview
        Layers
        Data Flow
        Abstractions
      STRUCTURE.md
        Directory Layout
        File Locations
        Naming Conventions
    quality
      CONVENTIONS.md
        Naming Patterns
        Code Style
        Error Handling
      TESTING.md
        Test Framework
        Test Structure
        Mocking
    concerns
      CONCERNS.md
        Tech Debt
        Known Bugs
        Security
        Performance
```

### 填空式模板示例

**STACK.md 模板结构**

```markdown
# Technology Stack

**Analysis Date:** [YYYY-MM-DD]

## Languages
**Primary:**
- [Language] [Version] - [Where used]

## Runtime
**Environment:**
- [Runtime] [Version]

## Frameworks
**Core:**
- [Framework] [Version] - [Purpose]
```

**CONCERNS.md 模板结构**

```markdown
# Codebase Concerns

## Tech Debt
**[Area]:**
- Issue: [Description]
- Files: `[paths]`
- Fix approach: [How to fix]

## Known Bugs
**[Bug]:**
- Symptoms: [What happens]
- Files: `[paths]`
```

---

## 🔒 第 7 部分：安全规则

```markdown
<forbidden_files>
**NEVER read:**
- `.env`, `.env.*`, `*.env`
- `credentials.*`, `secrets.*`
- `*.pem`, `*.key`, `id_rsa*`
- `.npmrc`, `.pypirc`, `.netrc`
- `serviceAccountKey.json`

**If encountered:**
- Note EXISTENCE only: ".env file present"
- NEVER quote contents
- NEVER include values like `API_KEY=...`
</forbidden_files>
```

**三层安全防护机制**

```mermaid
graph TB
    subgraph "Layer 1: Agent"
        A1[forbidden_files 列表]
        A2[禁止读取敏感文件]
    end
    
    subgraph "Layer 2: Orchestrator"
        B1[scan_for_secrets]
        B2[扫描输出内容]
    end
    
    subgraph "Layer 3: Git"
        C1[.gitignore]
        C2[防止意外提交]
    end
    
    A1 --> A2 --> B1 --> B2 --> C1 --> C2
```

---

## 📌 第 8 部分：关键规则

```markdown
<critical_rules>
**WRITE DOCUMENTS DIRECTLY.** 
Don't return to orchestrator. Reduce context transfer.

**ALWAYS INCLUDE FILE PATHS.** 
Every finding needs `path`. No exceptions.

**USE THE TEMPLATES.** 
Don't invent format.

**BE THOROUGH.** 
Explore deeply. Read files. Don't guess.

**RETURN ONLY CONFIRMATION.** 
~10 lines max.

**DO NOT COMMIT.** 
Orchestrator handles git.
</critical_rules>
```

**规则背后的设计原理**

```mermaid
graph LR
    R1[直接写入] --> G1[避免上下文爆炸]
    R2[必须路径] --> G2[下游可操作]
    R3[使用模板] --> G3[输出一致性]
    R4[探索彻底] --> G4[质量保证]
    R5[只返回确认] --> G5[最小传输]
    R6[不 commit] --> G6[避免并发冲突]
```

---

## ✅ 第 9 部分：验收标准

```markdown
<success_criteria>
- [ ] Focus area parsed correctly
- [ ] Codebase explored thoroughly for focus area
- [ ] All documents written to `.planning/codebase/`
- [ ] Documents follow template structure
- [ ] File paths included throughout
- [ ] Confirmation returned (not contents)
</success_criteria>
```

**验收检查流程**

```mermaid
graph LR
    A[开始] --> B{Focus 正确?}
    B -->|否| B1[重新解析]
    B -->|是| C{探索彻底?}
    C -->|否| C1[补充探索]
    C -->|是| D{文档完整?}
    D -->|否| D1[补充写入]
    D -->|是| E{符合模板?}
    E -->|否| E1[修正格式]
    E -->|是| F{包含路径?}
    F -->|否| F1[添加路径]
    F -->|是| G{只返回确认?}
    G -->|否| G1[移除内容]
    G -->|是| H[通过]
```

---

## 🔧 附录：术语解释

**Orchestrator**
- 执行 workflow 的主体
- 协调多个 Agent 工作
- 收集并汇总 Agent 返回的信息

```mermaid
graph LR
    U[用户] -->|/gsd:map-codebase| O[Orchestrator]
    O -->|spawn| A1[Agent 1: tech]
    O -->|spawn| A2[Agent 2: arch]
    O -->|spawn| A3[Agent 3: quality]
    O -->|spawn| A4[Agent 4: concerns]
    A1 -->|确认| O
    A2 -->|确认| O
    A3 -->|确认| O
    A4 -->|确认| O
    O -->|汇总结果| U
```

**Agent**
- 具体执行任务的实体
- gsd-codebase-mapper 是一种 Agent
- 专注于分析代码库并生成文档

---

*文档解析完成*
