
## 一、什么是 Skill？（概念篇）

### 1.1 一句话定义  
  
**Skill = 领域特定的指令包 + 工作流指南**  
  
想象一下：当你在做代码审查时，你需要记住一堆检查点（代码风格、潜在 Bug、性能问题...）；当你在处理 Git 提交时，你需要遵循特定的提交信息格式...  
  
Skill 就是把这些**领域知识**和**最佳实践**打包成可复用的模块，让 AI 在需要时加载使用。


### 1.2 为什么需要 Skill？  
  
| 场景 | 没有 Skill | 有 Skill                                |  
|------|-----------|---------|  
| 代码审查 | 每次都要提醒"检查 XX、YY、ZZ" | 加载 `code-review` skill，自动遵循完整检查清单      |  
| Git 提交 | 每次都解释提交信息格式 | 加载 `commit` skill，按规范生成 commit message |  
| PR 创建 | 手动填写各项信息 | 加载 `pr` skill，自动生成规范的 PR 描述            |  
| 项目特定规范 | 每次重复项目架构说明 | 自定义 skill，一次编写，多次复用<br>                |

### 1.3 Skill vs Tool 的区别  
  
| 特性 | Tool | Skill |  
|------|------|-------|  
| 本质 | 可执行的函数 | 领域知识和指令 |  
| 作用 | 执行操作（读文件、运行命令） | 指导 AI 如何思考和行动 |  
| 返回值 | 结构化数据 | 文本指令和指南 |  
| 类比 | 编程语言的函数 | 编程语言的文档 + 最佳实践 |  
**一句话总结**：Tool 是"做什么"，Skill 是"怎么做"。

---

## 二、Skill 的结构（基础篇）  
  
### 2.1 文件结构  
  
一个 Skill 是一个**目录**，包含：  
  
```  
skill-name/  
├── SKILL.md          # 核心文件：包含元数据和指令  
├── scripts/          # 可选：辅助脚本  
├── templates/        # 可选：模板文件  
└── reference/        # 可选：参考资料  
```


### 2.2 SKILL.md 格式  
  
```markdown  
---  
name: skill-name              # 唯一标识符  
description: 简短描述        # 用于展示给 AI 的说明  
---  
  
## Use this when  
- 什么时候使用这个 skill（触发条件）  
- 另一个触发条件  
  
## 指令标题 1  
具体的指令内容...  
  
## 指令标题 2  
更多指令...  
```


### 2.3 真实示例：bun-file-io Skill

```markdown
---
name: bun-file-io
description: Use this when you are working on file operations like reading,
  writing, scanning, or deleting files...
---

## Use this when

- Editing file I/O or scans in `packages/opencode`
- Handling directory operations or external tools

## Bun file APIs (from Bun docs)

- `Bun.file(path)` is lazy; call `text`, `json`, `stream`...
- `Bun.write(dest, input)` writes strings, buffers...

## When to use node:fs

- Use `node:fs/promises` for directories (`mkdir`, `readdir`)

## Repo patterns

- Prefer Bun APIs over Node `fs` for file access
- Check `Bun.file(...).exists()` before reading
```

**关键设计**：  
1. **YAML Frontmatter** - 元数据（name, description）  
2. **触发条件明确** - `Use this when` 部分告诉 AI 何时使用  
3. **具体可操作** - 提供代码示例和最佳实践  
4. **项目特定** - 针对 opencode 项目的文件操作偏好


## 三、Skill 的发现机制（进阶篇）

### 3.1 发现顺序（优先级从高到低）

```  
┌─────────────────────────────────────────────────────────────┐  
│                    Skill 发现流程                             │├─────────────────────────────────────────────────────────────┤  
│                                                             │  
│  1. ~/.claude/skills/**/SKILL.md     (外部全局)              │  
│  2. ~/.agents/skills/**/SKILL.md     (外部全局)              │  
│         ↓                                                   │  
│  3. ./.claude/skills/**/SKILL.md     (项目级外部)            │  
│  4. ./.agents/skills/**/SKILL.md     (项目级外部)            │  
│         ↓                                                   │  
│  5. ./.opencode/skill/**/SKILL.md    (OpenCode 项目级)       │  
│  6. ./.opencode/skills/**/SKILL.md   (OpenCode 项目级)       │  
│         ↓                                                   │  
│  7. config.skills.paths[]            (配置指定路径)          │  
│         ↓                                                   │  
│  8. config.skills.urls[]             (远程 URL)              ││                                                             │  
└─────────────────────────────────────────────────────────────┘  
```


### 3.2 源码解析：discovery 流程

```typescript
// packages/opencode/src/skill/skill.ts:52-175

export const state = Instance.state(async () => {
  const skills: Record<string, Info> = {}

  const addSkill = async (match: string) => {
    // 1. 解析 Markdown + YAML Frontmatter
    const md = await ConfigMarkdown.parse(match)

    // 2. 验证必需字段
    const parsed = Info.pick({ name: true, description: true }).safeParse(md.data)

    // 3. 处理重复（后加载的覆盖先加载的）
    if (skills[parsed.data.name]) {
      log.warn("duplicate skill name", {
        name: parsed.data.name,
        existing: skills[parsed.data.name].location,
        duplicate: match,
      })
    }

    // 4. 添加到 skills 表
    skills[parsed.data.name] = {
      name: parsed.data.name,
      description: parsed.data.description,
      location: match,      // 绝对路径
      content: md.content,  // Markdown 内容（不含 frontmatter）
    }
  }

  // ========== 发现来源 1: 外部目录 ==========
  // .claude/, .agents/ 目录（兼容其他 AI 工具）
  if (!Flag.OPENCODE_DISABLE_EXTERNAL_SKILLS) {
    for (const dir of EXTERNAL_DIRS) {
      const root = path.join(Global.Path.home, dir)  // ~/.claude
      await scanExternal(root, "global")
    }

    // 项目级外部目录（从当前目录向上遍历）
    for await (const root of Filesystem.up({...})) {
      await scanExternal(root, "project")
    }
  }

  // ========== 发现来源 2: OpenCode 目录 ==========
  for (const dir of await Config.directories()) {
    for await (const match of OPENCODE_SKILL_GLOB.scan({...})) {
      await addSkill(match)  // .opencode/skill/**/SKILL.md
    }
  }

  // ========== 发现来源 3: 配置路径 ==========
  const config = await Config.get()
  for (const skillPath of config.skills?.paths ?? []) {
    // 支持 ~/ 展开和相对路径
    const resolved = path.isAbsolute(expanded)
      ? expanded
      : path.join(Instance.directory, expanded)
    // 扫描 **/SKILL.md
  }

  // ========== 发现来源 4: 远程 URL ==========
  for (const url of config.skills?.urls ?? []) {
    const list = await Discovery.pull(url)  // 下载并缓存
    for (const dir of list) {
      for await (const match of SKILL_GLOB.scan({ cwd: dir })) {
        await addSkill(match)
      }
    }
  }

  return { skills, dirs: Array.from(dirs) }
})
```

### 3.3 关键设计点  
  
1. **层级覆盖**：项目级 skill 覆盖全局 skill（同名时后加载的胜）  
2. **外部兼容**：支持 `.claude/` 和 `.agents/` 目录（与其他 AI 工具兼容）  
3. **远程支持**：可从 URL 拉取 skill（便于团队共享）  
4. **惰性加载**：只在 `Skill.all()` 或 `Skill.get()` 时执行发现

### 3.4 远程 Skill 的缓存机制  
  
```typescript  
// packages/opencode/src/skill/discovery.ts  
  
export async function pull(url: string): Promise<string[]> {  
  // 1. 获取 index.json（技能列表）  
  // 2. 下载每个技能文件到 ~/.cache/opencode/skills/  // 3. 返回本地缓存路径列表  
}  
```

这让团队可以维护一个中央 skill 仓库，所有成员自动同步。  
  
---

## 四、Skill 的执行机制（核心篇）

### 4.1 整体流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        Skill 执行流程                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  用户: "帮我审查这段代码"                                         │
│      │                                                          │
│      ▼                                                          │
│  ┌──────────────┐                                               │
│  │  LLM 判断     │  "这是代码审查任务，应该使用 code-review skill"  │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │ 调用 skill    │  name: "code-review"                           │
│  │ 工具          │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │ 权限检查      │  用户是否允许使用此 skill？                       │
│  │ (ask/allow)  │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │ 加载 skill    │  读取 SKILL.md + 列出辅助文件                     │
│  │ 内容          │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │ 注入上下文    │  <skill_content> 块加入对话                      │
│  │              │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  LLM 按照 skill 指令执行代码审查                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```


### 4.2 SkillTool 源码解析

```typescript
// packages/opencode/src/tool/skill.ts

export const SkillTool = Tool.define("skill", async (ctx) => {
  // ========== 初始化阶段：收集可用 skills ==========
  const skills = await Skill.all()

  // 根据 Agent 权限过滤
  const accessibleSkills = agent
    ? skills.filter((skill) => {
        const rule = PermissionNext.evaluate("skill", skill.name, agent.permission)
        return rule.action !== "deny"
      })
    : skills

  // 生成动态 description（告诉 LLM 有哪些可用 skills）
  const description = [
    "Load a specialized skill that provides domain-specific instructions...",
    "",
    "The following skills provide specialized sets of instructions...",
    "<available_skills>",
    ...accessibleSkills.flatMap((skill) => [
      `  <skill>`,
      `    <name>${skill.name}</name>`,
      `    <description>${skill.description}</description>`,
      `    <location>${pathToFileURL(skill.location).href}</location>`,
      `  </skill>`,
    ]),
    "</available_skills>",
  ].join("\n")

  // ========== 执行阶段：加载指定 skill ==========
  return {
    description,
    parameters: z.object({
      name: z.string().describe("The name of the skill from available_skills"),
    }),

    async execute(params, ctx) {
      // 1. 查找 skill
      const skill = await Skill.get(params.name)
      if (!skill) throw new Error(`Skill "${params.name}" not found`)

      // 2. 请求权限（用户确认）
      await ctx.ask({
        permission: "skill",
        patterns: [params.name],
        always: [params.name],
        metadata: {},
      })

      // 3. 获取 skill 目录
      const dir = path.dirname(skill.location)
      const base = pathToFileURL(dir).href

      // 4. 列出辅助文件（最多 10 个）
      const files = await iife(async () => {
        const arr = []
        for await (const file of Ripgrep.files({ cwd: dir })) {
          if (file.includes("SKILL.md")) continue
          arr.push(path.resolve(dir, file))
          if (arr.length >= 10) break
        }
        return arr
      })

      // 5. 返回格式化的 skill 内容
      return {
        title: `Loaded skill: ${skill.name}`,
        output: [
          `<skill_content name="${skill.name}">`,
          `# Skill: ${skill.name}`,
          "",
          skill.content.trim(),
          "",
          `Base directory: ${base}`,
          "Note: file list is sampled.",
          "",
          "<skill_files>",
          files.map(f => `<file>${f}</file>`).join("\n"),
          "</skill_files>",
          "</skill_content>",
        ].join("\n"),
        metadata: { name: skill.name, dir },
      }
    },
  }
})
```


### 4.3 输出格式解析

加载 `skill` 后，返回的内容格式如下：

```xml
<skill_content name="bun-file-io">
# Skill: bun-file-io

## Use this when
- Editing file I/O or scans in `packages/opencode`
...

Base directory: file:///path/to/.opencode/skill/bun-file-io/
Relative paths in this skill are relative to this base directory.
Note: file list is sampled.

<skill_files>
<file>/path/to/.opencode/skill/bun-file-io/scripts/helper.ts</file>
</skill_files>
</skill_content>
```

**为什么用这种格式？**

1. **XML 标签** - 清晰界定 skill 内容边界
2. **Base directory** - 让 AI 知道相对路径的基准
3. **File list** - 提供辅助资源的访问路径

---


## 五、权限系统（安全篇）

### 5.1 权限模型

```typescript
// packages/opencode/src/permission/next.ts

// 三种权限级别
"allow"  // 允许直接使用
"ask"    // 需要用户确认
"deny"   // 禁止使用
```

### 5.2 Agent 权限配置

```typescript
// 默认权限（所有 Agent 继承）
const defaults = PermissionNext.fromConfig({
  "*": "allow",
  skill: "allow",
  external_directory: {
    "*": "ask",  // 外部目录的 skill 需要确认
  },
})

// 特定 Agent 可以覆盖
const planAgent = {
  permission: PermissionNext.merge(defaults, {
    skill: "ask",  // Plan Agent 使用 skill 需要确认
  })
}
```

### 5.3 权限评估流程

```
skill 请求
    │
    ▼
┌─────────────────┐
│ 匹配权限规则     │  "skill" + skill.name 匹配 ruleset
│ (evaluate)      │
└────────┬────────┘
         │
         ▼
    ┌─────────┐
    │ allow?  │ ──→ 直接执行
    └────┬────┘
         │
    ┌────▼────┐
    │ ask?    │ ──→ 弹出确认对话框
    └────┬────┘
         │
    ┌────▼────┐
    │ deny?   │ ──→ 拒绝执行
    └─────────┘
```

### 5.4 为什么需要权限？

1. **安全** - 防止恶意 skill 被自动加载
2. **控制** - 用户可以选择是否遵循某个指南
3. **信任边界** - 区分项目自带 skill 和外部 skill

---

# 六、实战示例（实践篇）

### 6.1 示例 1：创建一个代码审查 Skill

**文件结构：**

```
.opencode/skill/code-review/
└── SKILL.md
```

**SKILL.md：**

```markdown
---
name: code-review
description: 进行代码审查，检查代码风格、潜在 Bug 和性能问题
---

## Use this when

- 用户要求审查代码
- 需要检查代码质量
- 准备合并代码前

## 审查清单

### 1. 代码风格
- [ ] 命名是否清晰（函数、变量、类）
- [ ] 代码是否简洁可读
- [ ] 注释是否必要且清晰

### 2. 潜在 Bug
- [ ] 空值检查是否完善
- [ ] 错误处理是否到位
- [ ] 边界条件是否考虑

### 3. 性能
- [ ] 是否有明显的性能瓶颈
- [ ] 是否存在不必要的循环/递归
- [ ] 资源是否正确释放

## 输出格式---
name: code-review
description: 进行代码审查，检查代码风格、潜在 Bug 和性能问题
---

## Use this when

- 用户要求审查代码
- 需要检查代码质量
- 准备合并代码前

## 审查清单

### 1. 代码风格
- [ ] 命名是否清晰（函数、变量、类）
- [ ] 代码是否简洁可读
- [ ] 注释是否必要且清晰

### 2. 潜在 Bug
- [ ] 空值检查是否完善
- [ ] 错误处理是否到位
- [ ] 边界条件是否考虑

### 3. 性能
- [ ] 是否有明显的性能瓶颈
- [ ] 是否存在不必要的循环/递归
- [ ] 资源是否正确释放

## 输出格式
```


### 6.2 示例 2：Git Commit Skill

```markdown
---
name: commit
description: 生成规范的 Git commit message
---

## Use this when

- 用户要求提交代码
- 需要生成 commit message
- 准备创建 git commit

## Commit Message 格式

<type>(<scope>): <subject>

<body>

<footer>

### Type 类型

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

## 工作流程

1. 运行 `git status` 查看变更
2. 运行 `git diff` 查看详细改动
3. 分析变更类型和范围
4. 生成符合格式的 commit message
5. 询问用户确认
6. 执行 `git commit -m "..."`
```

### 6.3 示例 3：项目特定 Skill

假设你有一个使用特定架构的 Web 项目：

```markdown
---
name: myproject-web
description: MyProject Web 开发指南 - 包含项目架构、命名规范和最佳实践
---

## Use this when

- 在 MyProject 中开发新功能
- 修改现有代码
- 不确定项目规范时

## 项目架构

src/
├── components/     # React 组件（PascalCase 命名）
├── hooks/          # 自定义 hooks（useXxx 命名）
├── utils/          # 工具函数（camelCase 命名）
├── types/          # TypeScript 类型定义
└── api/            # API 调用（按模块组织）

## 命名规范

- **组件**: PascalCase (e.g., `UserProfile.tsx`)
- **hooks**: camelCase with `use` prefix (e.g., `useAuth.ts`)
- **工具函数**: camelCase (e.g., `formatDate.ts`)
- **常量**: UPPER_SNAKE_CASE

## 状态管理

- 全局状态：使用 Zustand
- 服务器状态：使用 TanStack Query
- 表单状态：使用 React Hook Form

## 代码示例

### 创建新组件

// components/UserCard.tsx
import { FC } from 'react'

interface UserCardProps {
  name: string
  email: string
}

export const UserCard: FC<UserCardProps> = ({ name, email }) => {
  return (
    <div className="user-card">
      <h3>{name}</h3>
      <p>{email}</p>
    </div>
  )
}
```

---


# 七、设计哲学（思考篇）


### 7.1 为什么用 Markdown 而不是代码？

| 方案 | 优点 | 缺点 |
|------|------|------|
| Markdown | 人类可读、易编辑、版本友好 | 不能执行逻辑 |
| 代码（JS/TS） | 可编程、灵活 | 复杂、需要编译、不易维护 |

**Skill 的本质是指南，不是程序**。Markdown 让非程序员也能编写和维护 skill。

### 7.2 为什么用文件系统而不是数据库？

1. **版本控制** - Skill 可以随项目一起提交到 Git
2. **透明性** - 用户可以直接查看 skill 内容
3. **可移植性** - 复制目录即可共享
4. **层级覆盖** - 文件系统的层级天然支持"项目覆盖全局"

### 7.3 为什么需要显式加载？

为什么不自动把所有 skill 都注入到上下文中？

1. **上下文长度** - LLM 有 token 限制，加载所有 skill 会浪费空间
2. **精确性** - 只加载相关的 skill，减少干扰
3. **用户控制** - 用户决定是否要使用某个指南

### 7.4 与其他系统的对比

| 系统 | 类似概念 | 区别 |
|------|---------|------|
| Cursor | `.cursorrules` | 单文件、全局生效 |
| GitHub Copilot | 提示词 | 无法自定义、不可见 |
| OpenCode Skill | - | 多文件、可组合、有权限控制 |

---


# 八、FAQ（常见问题）

**Q1: Skill 和 System Prompt 有什么区别？**

**A:**

| 特性   | System Prompt | Skill      |
| ---- | ------------- | ---------- |
| 加载时机 | 会话开始时         | 按需加载       |
| 内容大小 | 通常较小          | 可以很大（详细指南） |
| 更新方式 | 修改配置          | 替换文件       |
| 作用范围 | 全局            | 特定任务       |

**类比**：System Prompt 是"公司文化"，Skill 是"部门操作手册"。

---

**Q2: 一个 Skill 可以依赖另一个 Skill 吗？**

**A:** 目前不支持显式依赖。但你可以：

1. **顺序加载** - 先加载基础 skill，再加载高级 skill
2. **内容引用** - 在 skill 中说明"建议先加载 xxx skill"
3. **合并内容** - 把相关内容写在一个 skill 里

---

**Q3: Skill 可以包含可执行代码吗？**

**A:** Skill 本身是指令文本，但你可以：

1. **在 skill 目录放脚本** - `scripts/` 目录下的文件会被列出
2. **在指令中告诉 AI 执行** - "运行 `./scripts/setup.sh`"
3. **使用 Tool** - Skill 指导 AI 调用相应的 tool

---

**Q4: 如何让 Skill 只在特定项目中可用？**

**A:** 放在项目目录下的 `.opencode/skill/` 中：

```
my-project/
├── .opencode/
│   └── skill/
│       └── my-skill/        # 只在 my-project 中可用
│           └── SKILL.md
```

---

**Q5: Skill 和 Tool 的命名冲突怎么办？**

**A:** 它们是不同的命名空间：

- Tool 名称：`skill`（工具名）、`read`、`edit` 等
- Skill 名称：`commit`、`code-review` 等

Skill 是通过 `skill` 工具的 `name` 参数指定的。

---

**Q6: 如何调试 Skill 是否被正确加载？**

**A:**

1. **查看日志** - OpenCode 会输出发现的 skills 列表
2. **使用 CLI** - `opencode debug skill` 命令列出所有 skills
3. **检查权限** - 确认没有被权限系统拒绝
4. **验证格式** - 确保 SKILL.md 有正确的 YAML frontmatter

---
**Q7: Skill 内容会被保存到会话中吗？**

**A: 是的，但有特殊处理：**

```typescript
// packages/opencode/src/session/compaction.ts
const PRUNE_PROTECTED_TOOLS = ["skill"]
```

**Skill 工具的输出会被保护，在会话压缩时不会被删除。这确保了一旦加载，skill 的指南会一直生效。**

**---**

**Q8: 可以给 Skill 参数吗？**

**A:** 目前不支持。Skill 是"无参数"加载的。如果需要参数化：

1. 在加载 skill 后的对话中提供参数
2. 创建多个相关 skill（如 `test-jest`、`test-vitest`）
3. 在 skill 中使用条件逻辑（"如果是 X 情况，做 Y；否则做 Z"）

---

**Q9: 远程 Skill 的安全性如何保证？**

**A:**

1. **首次使用需要确认** - 外部 skill 默认需要用户授权
2. **本地缓存** - 下载后本地存储，可手动检查
3. **权限隔离** - Skill 本身不能执行代码，只是文本指令
4. **HTTPS 强制** - 远程 URL 必须使用 HTTPS

---

**Q10: 如何设计一个好的 Skill？**

**A:** 遵循以下原则：

1. **明确的触发条件** - `Use this when` 要具体
2. **可操作的指令** - 避免模糊表述，提供具体步骤
3. **包含示例** - 展示期望的输入/输出
4. **适度的长度** - 足够详细但不冗长
5. **版本兼容** - 注明适用的项目版本