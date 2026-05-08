---
title: "agent harness failure modes"
date: 2026-05-08
tags:
  - agent
  - llm
  - anthropic
  - harness
---

> 一句话结论：Agent 的根本缺陷是"无法准确评估自身产出"。Harness 不是锦上添花的外部工具，而是弥补这一缺陷的必需基础设施——它通过结构化约束和反馈机制，把"一次性赌博"变成"可迭代的工程过程"。

## 一、为什么 Agent 需要 Harness

过去一年，AI Agent 从 Demo 走向了生产环境。但一个令人沮丧的事实是：**大多数 Agent 项目在生产环境中表现远不如预期**。

Anthropic 在其工程博客中系统性地总结了这个问题。他们不是从模型能力角度分析，而是从一个更务实的角度：**Agent 在复杂项目中的系统性失败模式**。这些失败不是偶发的 Bug，而是架构层面的结构性问题——除非引入外部控制系统，否则无法避免。

Anthropic 把这个外部控制系统叫做 **Harness**。

## 二、四种失败模式

### 2.1 试图一步到位（One-shot Syndrome）

最常见的场景：你给 Agent 一个复杂需求，它试图在单个上下文窗口内完成全部工作。前 30% 的进展看起来很顺利，然后上下文开始拥挤，模型出现 Hallucination、循环输出、格式错误的 Tool Call。最后它要么陷入死循环，要么输出一团乱麻的半成品。

Anthropic 的官方博客没有提到"40% Sweet Spot"这个具体数字（这个数据在中文社区流传甚广，但未在公开博客中找到出处），但他们明确描述了同样的现象：

> "models tend to lose coherence on lengthy tasks as the context window fills."

部分模型甚至表现出 **"context anxiety"**——当感知到上下文即将耗尽时，会提前收尾、跳过步骤、草率结束任务。Claude Sonnet 4.5 的 anxiety 强到"compaction alone wasn't sufficient"，必须通过 **Context Reset**（完全清空上下文，通过结构化 artifact 交接状态给全新 Agent 实例）才能解决。

### 2.2 过早宣布胜利（Premature Victory Declaration）

Agent 完成了约 60% 的工作，然后宣布"项目已完成"。这是 Anthropic 在实验中最常观察到的失败模式之一，官方描述非常直接：

> "Claude declares victory on the entire project too early."

根源在于 Agent 缺乏外部验收标准。它自己既是运动员又是裁判，自然会高估完成度。没有 feature list、没有明确的"完成定义"（Definition of Done），Agent 的判断标准就是"我感觉差不多了"。

### 2.3 过早标记功能完成（Premature Feature Completion）

比"宣布项目完成"更隐蔽的是"宣布某个功能完成"。Agent 写了一些代码，运行了 superficial test，就把功能标记为"done"。但端到端路径根本没有跑通。

Anthropic 的官方描述：

> "Claude marks features as done prematurely."

这背后是一个更深层的问题：**自评估偏差（Self-evaluation bias）**。

> "When asked to evaluate work they've produced, agents tend to respond by confidently praising the work—even when, to a human observer, the quality is obviously mediocre."

同一套模型既写代码又评代码，会自我合理化缺陷。在主观任务（如 UI 设计）上尤其严重。

### 2.4 环境启动困难（Cold Start）

每次新会话，Agent 都要重新理解项目结构、依赖关系、如何启动开发服务器。大量 Token 被消耗在"环境侦查"上，真正用于编码的预算被严重挤压。

Anthropic 的官方表述是：

> "Claude has to spend time figuring out how to run the app."

以及：

> "Claude leaves the environment in a state with bugs or undocumented progress."

多次会话之间缺乏持久化记忆和结构化状态交接，导致每次启动都是一次昂贵的"冷启动"。

## 三、Harness 的解法：不是更聪明的模型，而是更聪明的工作流

Anthropic 的核心洞察是：**这些失败模式的根源不是模型不够聪明，而是缺乏外部结构化约束和反馈机制**。

他们设计了三种逐步演进的 Harness 架构。

### 3.1 两段式架构：Initializer + Coding Agent

最简单的 Harness，解决"冷启动"和"过早胜利"问题：

**Initializer（第一次会话）**：
- 建立 `init.sh` 脚本——一键启动开发服务器
- 建立 `features.json`——结构化功能清单，所有功能初始状态为 "failing"
- 建立 `progress.txt`——会话间状态交接文件
- 初始化 git repo

**Coding Agent（后续每次会话）**：
- 启动协议：读 progress → 读 git log → 运行基础测试
- 工作协议：每次只选一个 feature，实现 + 测试，然后写 commit 和 progress update
- 验收协议：自我验证所有功能，仅在经过仔细测试后标记为 "passing"

**关键设计细节**：Feature list 用 JSON 而非 Markdown，因为"The model is less likely to inappropriately change or overwrite JSON files compared to Markdown files"。

### 3.2 前端设计 Harness：Generator-Evaluator 循环

当任务涉及主观判断（如 UI 设计）时，自评估偏差无法通过"自我验证"解决。必须引入**独立的 Evaluator**。

受 GAN 启发，两 Agent 循环迭代：

- **Generator**：创建 HTML/CSS/JS
- **Evaluator**：用 Playwright MCP 直接与运行中的页面交互，按四个维度打分：
  1. **Design quality**——是否像有机整体而非拼凑
  2. **Originality**——是否有定制决策，还是全是模板/默认模式
  3. **Craft**——排版层级、间距一致性、色彩和谐
  4. **Functionality**——独立于美观性的可用性

实验数据：5-15 次迭代，完整运行长达 4 小时。一个有趣的案例是荷兰艺术博物馆网站——在第 10 轮迭代时，Generator 完全推翻了之前的设计方向，将其重新构想为 CSS 3D 透视的空间体验。

### 3.3 全栈 Harness：Planner-Generator-Evaluator

最完整的架构，用于复杂的全栈项目：

```
Planner ──→ Generator ──→ Evaluator (QA)
   ↑                        │
   └────────────────────────┘
```

| 角色 | 职责 | 关键约束 |
|------|------|---------|
| **Planner** | 将 1-4 句 prompt 扩展为完整产品 spec | 只做高层设计，不写实现细节 |
| **Generator** | 按 sprint 实现功能 | 每次一个 feature，结束后自评估 |
| **Evaluator** | 用 Playwright 像真实用户一样测试 | 评估深度、功能、设计、代码质量；每项有 hard threshold |

**Sprint Contract**：每轮 sprint 前，Generator 和 Evaluator 协商"完成标准"，沟通通过文件进行。这解决了"过早标记完成"的问题——"完成"不是 Generator 自己说了算，而是双方事先约定的可验证标准。

## 四、实验数据：Harness 到底值不值

### 4.1 Retro Game Maker

| 方案 | 时长 | 成本 | 结果 |
|------|------|------|------|
| Solo Agent | 20 min | $9 | 核心功能 broken：entity definitions 与 game runtime 的 wiring 断裂 |
| Full Harness | 6 hr | $200 | 16 个 feature，10 个 sprint，play mode 可用，内置 Claude integration |

Solo Agent 便宜但不可用。Harness 昂贵但产出了可运行的产品。

### 4.2 DAW（数字音频工作站，Opus 4.6）

Opus 4.6 上下文窗口更大、任务 sustained 能力更强，Harness 被简化（移除 sprint，Evaluator 改为单次 pass）：

| Phase | 时长 | 成本 |
|-------|------|------|
| Planner | 4.7 min | $0.46 |
| Build (R1) | 2 hr 7 min | $71.08 |
| QA (R1) | 8.8 min | $3.24 |
| Build (R2) | 1 hr 2 min | $36.89 |
| QA (R2) | 6.8 min | $3.09 |
| Build (R3) | 10.9 min | $5.88 |
| QA (R3) | 9.6 min | $4.06 |
| **Total** | **3 hr 50 min** | **$124.70** |

即使模型能力提升了，QA 仍然发现了真实问题：
- "clips can't be dragged/moved on the timeline"
- "Audio recording is still stub-only"
- "Clip resize by edge drag and clip split not implemented"

这说明：**Evaluator 的价值不随模型能力提升而消失，只是 Harness 的具体形态在演变**。

### 4.3 Evaluator 的调优难度

> "Out of the box, Claude is a poor QA agent."

早期实验中，Evaluator 会：
1. 识别出合理问题后，自我说服"这不是大问题"
2. 测试流于表面（superficial testing）

需要多轮 prompt tuning 和 few-shot examples 才能让它成为合格的 QA。

## 五、关键设计原则

1. **Agent 无法准确评估自身产出**——这是根本缺陷，Harness 的核心价值是引入外部评估
2. **执行者与评判者必须分离**——同一 Agent 既写代码又测代码，会自我合理化缺陷
3. **结构化状态交接 > 上下文压缩**——Context reset 配合 artifact 传递，比 compaction 更有效
4. **JSON > Markdown 用于状态文件**——模型更不容易误改 JSON
5. **Hard threshold 优于软性评估**——"passing/failing" 比 "looks good" 更有效
6. **Harness 组件应随模型进化而移除**——"every component in a harness encodes an assumption about what the model can't do on its own"

最后一条尤其重要。模型在进化，Harness 也应该进化。Opus 4.6 的出现让部分 anxiety-mitigation 脚手架变得不再必要，但解锁了需要更复杂 Evaluator 的新任务。正如 Anthropic 所说：

> "the space of interesting harness combinations doesn't shrink as models improve. Instead, it moves."

## 六、对实际工作的启发

如果你正在构建 Agent 系统，不必一步到位实现 Planner-Generator-Evaluator。可以从最简单的开始：

**第一步**：给 Agent 一个 `features.json` 和一个 `progress.txt`。让它每次只做一个功能，做完写进度。

**第二步**：引入独立的验证步骤——可以是另一个 Agent，也可以是自动化测试脚本。关键是"验证者"不能是"执行者"自己。

**第三步**：当任务涉及主观判断（设计、产品体验）时，引入 Evaluator Agent，用 Browser Automation 做端到端验证。

Harness 的本质不是增加复杂度，而是**把不确定的 Agent 行为约束到可预测、可验证、可迭代的工程框架中**。

---

**参考来源**：
- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic: Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Addy Osmani: Agent Harness Engineering](https://addyosmani.com/blog/agent-harness-engineering/)
