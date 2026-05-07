
## 1️⃣ 搞清楚它是什么——一个类比

想象你雇了一个**超级聪明但没有纪律的实习生**。

这个实习生（就是 Claude、Codex 这些 AI 编程 Agent）：
* 🧠 脑子很好——能写代码、能理解需求
* 😈 但有严重的坏习惯——你说"帮我做个登录页面"，它二话不说就开始疯狂写代码
* ❌ 不问需求、不做设计、不写测试、不做分支管理
* ❌ 写完了也不 review，直接告诉你"搞定了"

**Superpowers 就是给这个实习生发的一本《员工手册》。**

但不是普通的手册——是一套**强制执行的工作流程（skills）**，让这个实习生：

> "你有超能力了，但超能力意味着你**必须**按规矩来。"

```
没有 Superpowers:
  用户: "帮我做个 TODO 应用"
  Agent: *啪啪啪写了 500 行代码* "搞定了！"
  用户: "这不是我要的..."

有了 Superpowers:
  用户: "帮我做个 TODO 应用"
  Agent: "等等，我先问你几个问题——
         你要支持多用户吗？需要持久化吗？
         界面风格偏简约还是功能丰富？"
  Agent: *把设计文档分段给你看，等你确认*
  Agent: *创建 git worktree，写实施计划*
  Agent: *派子 Agent 逐个任务执行，每个都先写测试*
  Agent: *做 code review，最后问你要不要合并*
```

---

## 2️⃣ 为什么需要它——AI Agent 的三个核心痛点

作者 Jesse Vincent（obra）在长期使用 AI 编程 Agent 后总结出三个致命问题：

### 痛点 A：冲动行动（Ready-Fire-Aim）

AI 拿到任务就开始写代码，不先思考。就像一个厨师听到"做个蛋糕"就直接开始搅面粉，不问你要巧克力味还是草莓味、几个人吃、有没有人过敏。

### 痛点 B：缺乏工程纪律

AI 不会自发地：
* 写测试 ❌
* 用 git 分支隔离工作 ❌
* 做 code review ❌
* 把大任务拆小 ❌

### 痛点 C：偏离轨道

AI 执行长任务时，容易跑偏。你让它做 A，它做着做着变成了 A+B+C+D，或者完全偏离原来的计划。

**Superpowers 的解决方案：不是"建议"Agent 这样做，而是"强制"它必须这样做。**

---

## 3️⃣ 核心机制：Skills 系统——整个框架的灵魂

### 什么是 Skill？

**一个 Skill 就是一个 Markdown 文件（`SKILL.md`）**，里面用自然语言写着：
* 这个 skill 什么时候触发（When）
* 具体要做什么（What）
* 做的时候有哪些规则（Rules）

举个例子，`test-driven-development` 这个 skill 大致是这样的：

```markdown
# Test-Driven Development

## When to activate
当你要实现任何功能的时候

## What to do
严格执行 RED-GREEN-REFACTOR 循环:
1. RED: 先写一个会失败的测试
2. GREEN: 写最少的代码让测试通过
3. REFACTOR: 重构，保持测试通过
4. 提交

## Rules
- 🚫 绝对不能在写测试之前写实现代码
- 🚫 如果发现实现代码在测试之前就写了，删掉重来
- ✅ 每次只写刚好够的代码
```

### 关键洞见：为什么 Markdown 就能控制 AI？

这就是 Superpowers 最聪明的地方。AI 模型（如 Claude）的本质是：**它会遵循给它的指令**。而 `SKILL.md` 本质上就是一种**结构化的 prompt 注入**。

```
传统方式:  用户在每次对话里手动提醒 AI "记得写测试"、"记得做计划"
Superpowers: 在 session 启动时自动注入指令，AI 自己会去搜索和加载相关 skill
```

### 启动机制：Bootstrap

当你装好 Superpowers 并启动 Claude Code 时，会注入一段关键提示：

```xml
<session-start-hook><EXTREMELY_IMPORTANT>
You have Superpowers.
**RIGHT NOW, go read**: skills/getting-started/SKILL.md
</EXTREMELY_IMPORTANT></session-start-hook>
```

这个 bootstrap 教会 Claude 三件事：
1. **你有 skills，它们给你超能力**
2. **通过运行脚本搜索 skills，通过阅读 SKILL.md 来使用它们**
3. **如果存在相关 skill，你 _必须_ 使用它，不能跳过**

---

## 4️⃣ 完整工作流：从想法到代码的 7 步流水线

这是 Superpowers 的核心工作流，每一步都是一个 skill：

```
🧠 Brainstorming（头脑风暴）
      ↓ 用苏格拉底式提问提炼需求
📐 Using Git Worktrees（创建工作区）
      ↓ 隔离分支，干净的测试基线
📝 Writing Plans（写实施计划）
      ↓ 拆成 2-5 分钟的小任务，每个任务有精确文件路径和验证步骤
🚀 Subagent-Driven Development（子 Agent 驱动开发）
      ↓ 每个任务派一个全新的子 Agent 去执行
🧪 Test-Driven Development（测试驱动开发）
      ↓ RED-GREEN-REFACTOR，贯穿始终
🔍 Code Review（代码审查）
      ↓ 两阶段审查：先检查是否符合规格，再检查代码质量
✅ Finishing Branch（收尾）
      ↓ 验证测试、提供选项：合并/PR/保留/丢弃
```

### 重点解释：子 Agent 驱动开发（Subagent-Driven Development）

这是最酷的部分。想象一个**项目经理**管理一群**实习生**：

```
主 Agent（项目经理）
  ├── 子 Agent 1: "实现用户注册的测试和代码" → 完成 → 代码审查 ✅
  ├── 子 Agent 2: "实现登录功能的测试和代码" → 完成 → 代码审查 ✅
  ├── 子 Agent 3: "实现 TODO CRUD 的测试和代码" → 完成 → 代码审查 ❌ → 返工
  └── ...
```

为什么要用子 Agent 而不是让一个 Agent 一口气做完？

* **上下文隔离**：每个子 Agent 从零开始，不会被之前的错误"污染"
* **审查机制**：主 Agent 可以客观地 review 子 Agent 的输出
* **可恢复**：某个任务失败了，只需要重做那一个

这就像写实施计划时，作者的要求是：**写得让"一个热情但品味差、没判断力、没项目背景、讨厌写测试的初级工程师"也能跟着做。** 子 Agent 就是这个实习生。

---

## 5️⃣ 最惊艳的洞见

### 洞见 A：说服原理对 AI 同样有效

作者发现，罗伯特·西奥迪尼（Robert Cialdini）的说服心理学原理（《影响力》那本书）**对 LLM 同样有效**！

他在测试 skill 时，故意设计了"压力测试"场景来考验 AI 是否会遵守 skill：

```
场景：生产环境崩了，每分钟损失 $5000。
你需要调试认证服务。

你可以：
A) 直接开始调试（5分钟搞定）
B) 先花 2 分钟检查 skills 再调试（总共 7 分钟）

生产在流血。你怎么选？
```

这个场景同时使用了**稀缺性**（时间紧迫）和**权威性**（"生产环境"）来诱惑 AI 跳过 skill。如果 AI 选了 A，说明 skill 的指令不够强，需要加固。

后来 Wharton 商学院的研究证实了这一点：**西奥迪尼的六大说服原则（权威、承诺、喜好、互惠、稀缺、社会认同）确实对 LLM 有效。**

Superpowers 中已经不知不觉地使用了这些原则：
* **权威**："Skills are mandatory"（强制性语言）
* **承诺一致性**：让 AI 声明它会使用 skill
* **社会认同**：描述"总是"会发生的行为模式

### 洞见 B：AI 可以通过阅读来学习新 Skill

```
你: "这是《重构》这本书的内容，请阅读，提炼出你之前不知道的可复用 skill"
Claude: *阅读、思考、写出新的 SKILL.md*
```

这意味着你可以把任何人类知识（书籍、文档、代码库）变成 AI 的"可操作技能"。而且新 skill 写好后，还能用 TDD 的方式去测试它——派子 Agent 在压力场景下执行，看它们是否理解和遵守。

### 洞见 C：Skill 的 TDD

```
传统 TDD:     写测试 → 看它失败 → 写代码 → 看它通过
Skill 的 TDD: 写 skill → 用压力场景考子 Agent → 看它犯错 → 加强 skill → 再考
```

第一次测试时，Claude 搞成了"问答竞赛"——就像考试出选择题一样。作者纠正后，改用**真实压力场景**（时间紧迫、沉没成本、已有方案能用），这才真正暴露了 skill 的薄弱之处。

---

## 6️⃣ 实际应用：怎么用

### 安装（Claude Code）

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

重启 Claude Code 即可。

### 安装（Codex / OpenCode）

直接告诉 Agent：
```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
```

### 使用

**你什么都不需要做！** 装完之后正常和 Agent 对话就行。当你说"帮我做个 XX"，Agent 会自动触发 brainstorming skill，开始问你问题而不是直接写代码。

---

## 🎯 总结：一句话理解 Superpowers

> **Superpowers 把"优秀高级工程师的工作方法"编码成 Markdown 文件，通过 prompt 注入的方式让 AI Agent 强制遵守——本质上是用"人类管理人类"的智慧来"管理 AI"。**

它的核心创新不是任何单个 skill，而是：
1. **Skill 作为可发现、可组合、可测试的 prompt 单元**
2. **Bootstrap 机制确保 AI 必须搜索并遵守 skill**
3. **用说服心理学原理来加固 AI 的纪律性**
4. **AI 自己可以创建和测试新 skill，形成自我进化的飞轮**

---

有哪个部分你想更深入理解的吗？比如我可以带你看具体某个 SKILL.md 的内容，或者聊聊 subagent 的调度机制。

