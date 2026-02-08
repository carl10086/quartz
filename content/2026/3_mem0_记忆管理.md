
## 第一阶段：LLM 的「失忆症」

### 🧠 一个类比帮你秒懂

想象你去健身房请了一个私教叫 Ray。

**没有 Mem0 的 Ray（普通 LLM）：**
> 每次你走进健身房，Ray 都像第一次见你一样：「你好！你的健身目标是什么？」——即使你上周刚告诉他你要跑马拉松。

**有 Mem0 的 Ray：**
> 你走进健身房，Ray 说：「上周你跑了 15 公里，膝盖有点不舒服，今天我们做低强度的交叉训练吧。」

这就是核心问题：**LLM 是无状态的（stateless）**。每次 API 调用，对 GPT 来说都是一个全新的对话。

### ❌ 笨办法：把所有历史塞进 Context Window

```
messages = [
    # 3个月前的对话...
    # 2个月前的对话...
    # 上周的对话...
    # 昨天的对话...
    # 今天的问题
]
```

问题：
* **慢** — 几万条消息，每次都要发送
* **贵** — Token 数量爆炸，按量计费
* **有上限** — Context Window 再大也有边界（GPT-4o 是 128K tokens）

### ✅ 聪明办法：Mem0

Mem0 的做法是：**从对话中抽取关键事实，存起来，需要时检索相关的几条**。

就像人的大脑：你不会记住和朋友说过的每一个字，但你记得「他要结婚了」「他对花生过敏」这些关键信息。

---

## 第二阶段：核心循环 — 取→用→存

### 🔄 三步走，这是所有记忆系统的骨架

```
用户说话 → ① 从 Mem0 取相关记忆
         → ② 把记忆 + 用户消息一起发给 LLM
         → ③ 把这轮对话存回 Mem0
```

### 代码实现

```python
from openai import OpenAI
from mem0 import MemoryClient

openai_client = OpenAI(api_key="your-openai-key")
mem0_client = MemoryClient(api_key="your-mem0-key")

def chat(user_input, user_id):
    # ① 取：用用户的输入做语义搜索，找到最相关的5条记忆
    memories = mem0_client.search(user_input, user_id=user_id, limit=5)
    context = "\n".join(m["memory"] for m in memories["results"])

    # ② 用：把记忆塞进 system prompt，让 LLM 知道这个用户的背景
    response = openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": f"You're Ray, a running coach. Memories:\n{context}"},
            {"role": "user", "content": user_input}
        ]
    ).choices[0].message.content

    # ③ 存：把这轮对话存进 Mem0，Mem0 会自动提取关键信息
    mem0_client.add([
        {"role": "user", "content": user_input},
        {"role": "assistant", "content": response}
    ], user_id=user_id)

    return response
```

### 🎯 关键理解：Mem0 的 `add` 不是存原文

很多人以为 `mem0_client.add(...)` 是把整段对话原封不动存进去。**不是的。**

Mem0 内部会用 AI 做**信息抽取**：

| 用户说的原话                    | Mem0 实际存储的        |
| ------------------------- | ----------------- |
| "嘿，我想在4小时内跑完马拉松，你觉得我能行吗？" | "Max 想跑进4小时完成马拉松" |
| "哈哈好的谢谢"                  | ❌ 不存（无信息量）        |
| "我右膝盖下坡时会疼"               | "Max 右膝盖下坡时会疼"    |

### 🧪 验证跨会话记忆

```python
# 第一天
chat("I want to run a marathon in under 4 hours", user_id="max")
# Ray: "That's a solid goal. What's your current weekly mileage?"

# ——— 关闭 app，第二天重新打开 ———

# 第二天
chat("What should I focus on today?", user_id="max")
# Ray: "Based on your sub-4 marathon goal, let's work on building your aerobic base..."
```

**App 重启了，但 Ray 还记得。** 因为记忆在 Mem0 的云端，不在你的 app 进程里。

---

## 第三阶段：记忆分类与噪音过滤

### 问题1：记忆太杂

跑一周不过滤的结果：

```python
memories = mem0_client.get_all(filters={"AND": [{"user_id": "max"}]})
# ["Max wants to run marathon under 4 hours", "hey", "lol ok", "cool thanks", "gtg bye"]
```

「hey」和「lol ok」混在里面，检索时会干扰真正有用的记忆。

### 解决方案：Custom Instructions（自定义指令）

告诉 Mem0「什么值得记，什么不值得」：

```python
mem0_client.project.update(custom_instructions="""
Extract from running coach conversations:
- Training goals and race targets
- Physical constraints or injuries
- Training preferences (time of day, surfaces, weather)
- Progress milestones

Exclude:
- Greetings and filler
- Casual chatter
- Hypotheticals unless planning related
""")
```

这相当于给 Mem0 的信息抽取 AI 一套**工作手册**。

效果验证：

```python
chat("hey how's it going", user_id="max")      # ❌ 不会被存储
chat("I prefer trail running over roads", user_id="max")  # ✅ 存储

# 结果只有有意义的记忆：
# ["Max wants to run marathon under 4 hours", "Max prefers trail running over roads"]
```

### 问题2：不同类型的记忆需要分开管理

Max 的膝盖疼（临时伤病） vs 马拉松目标（长期目标），性质完全不同。

### 解决方案：Categories（分类）

```python
mem0_client.project.update(custom_categories=[
    {"goals": "Race targets and training objectives"},
    {"constraints": "Injuries, limitations, recovery needs"},
    {"preferences": "Training style, surfaces, schedules"}
])
```

### ⚠️ 重要区分：Categories vs Metadata

| | Categories（分类） | Metadata（元数据） |
|---|---|---|
| **谁来打标签？** | Mem0 AI 自动打 | 你手动指定 |
| **能强制吗？** | ❌ 不能，AI 自己判断 | ✅ 完全由你控制 |
| **适合什么场景？** | 语义分类（目标、伤病、偏好） | 结构化标签（训练类型、强度等级） |
| **类比** | 让图书管理员帮你分类 | 你自己贴标签 |

```python
# Categories：AI 自动判断这是 "constraints"
mem0_client.add(
    [{"role": "user", "content": "My right knee flares up on downhills"}],
    user_id="max"
)

# Metadata：你手动强制打标签
mem0_client.add(
    [{"role": "user", "content": "10x400m intervals"}],
    user_id="max",
    metadata={"workout_type": "speed", "intensity": "high"}
)
```

### 按分类检索

制定训练计划时，只查伤病信息：

```python
constraints = mem0_client.search(
    query="injury concerns",
    filters={
        "AND": [
            {"user_id": "max"},
            {"categories": {"in": ["constraints"]}}
        ]
    },
    threshold=0.0  # 降低阈值，确保短文本也能被召回
)
# Output: ["Max's right knee flares up on downhills"]
```

Ray 做训练计划时只拿到伤病信息，不会被马拉松目标等无关记忆干扰。

---

## 第四阶段：Agent 人格记忆

### 用户记忆 ≠ Agent 记忆

到目前为止，我们存的都是**关于用户的信息**（Max 的目标、伤病）。但 Ray 作为教练，也有自己的「性格」需要记住。

| 记忆类型 | 存什么 | 用什么 ID |
|---|---|---|
| 用户记忆 | Max 的目标、偏好、历史 | `user_id="max"` |
| Agent 记忆 | Ray 的沟通风格、教练原则 | `agent_id="ray_coach"` |

```python
# 存储 Agent 人格
mem0_client.add(
    [{"role": "system", "content": "Max wants direct, data-driven feedback. Skip motivational language."}],
    agent_id="ray_coach"
)
```

### 使用时两者结合

```python
# 取用户记忆
user_memories = mem0_client.search("training plan", user_id="max")

# 取 Agent 人格
agent_memories = mem0_client.search("coaching style", agent_id="ray_coach")

# 两者都传给 LLM
response = openai_client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[
        {"role": "system", "content": f"""
You're Ray, a running coach.
Your style: {agent_memories}
About the user: {user_memories}
"""},
        {"role": "user", "content": "How'd my run look today?"}
    ]
)
```

**效果对比：**

| 没有 Agent 记忆 | 有 Agent 记忆 |
|---|---|
| "Great job! You're doing amazing! Keep it up! 🎉" | "Pace: 8:15/mile. Heart rate 152, zone 2. On track." |

Max 喜欢直接的数据反馈，Ray 记住了这一点。

---

## 第五阶段：时间维度管理

### 短期 vs 长期记忆策略

```
┌─────────────────────────────────────┐
│         你的 App 内存               │
│   最近 10 条消息（短期上下文）        │  ← 快、免费、重启就没了
└──────────────┬──────────────────────┘
               │ 只把有意义的存下去
               ▼
┌─────────────────────────────────────┐
│         Mem0 云端存储                │
│   关键事实（长期记忆）               │  ← 持久、跨会话、有成本
└─────────────────────────────────────┘
```

**原则：不是每句话都要存进 Mem0。** 最近几轮对话保持在 app 内存即可，只让 Mem0 处理值得长期保存的信息。配合 `custom_instructions`，大部分过滤是自动的。

### 会过期的记忆

Max 扭了脚踝，两周后会好。这条记忆也应该在两周后自动消失：

```python
from datetime import datetime, timedelta

expiration = (datetime.now() + timedelta(days=14)).strftime("%Y-%m-%d")

mem0_client.add(
    [{"role": "user", "content": "Rolled my left ankle, needs rest"}],
    user_id="max",
    expiration_date=expiration  # 14天后自动删除
)
```

**效果：** 两周内 Ray 会说「注意脚踝，做低强度训练」。两周后记忆消失，Ray 不再提起。就像现实中教练知道你已经恢复了。

---

## 第六阶段：生产环境实战模式

### 🏷️ 用 `run_id` 隔离不同训练周期

```python
# 备战波士顿马拉松的记忆
mem0_client.add(messages, user_id="max", run_id="boston-2025")

# 备战纽约马拉松的记忆
mem0_client.add(messages, user_id="max", run_id="nyc-2025")

# 只检索波士顿相关记忆，不会混入纽约的
boston = mem0_client.search("training plan", user_id="max", run_id="boston-2025")
```

`run_id` 就像**文件夹**——同一个用户的记忆可以按「情节」分开。

### 🔄 处理目标变更（矛盾检测）

Max 把目标从 sub-4 改成了 sub-3:45：

```python
# 找到旧记忆
memories = mem0_client.get_all(filters={"AND": [{"user_id": "max"}]})
goal_memory = [m for m in memories["results"] if "sub-4" in m["memory"]][0]

# 更新它（而不是新建一条，避免矛盾）
mem0_client.update(goal_memory["id"], "Max wants to run sub-3:45 marathon")
```

**关键：用 `update` 而不是再 `add` 一条。** 否则 Mem0 里会同时存在 "sub-4" 和 "sub-3:45"，LLM 会困惑。

### 👥 多 Agent 协作

```python
# Ray 管跑步
chat("easy run today", user_id="max", agent_id="ray")

# Jordan 管力量训练
chat("leg day workout", user_id="max", agent_id="jordan")
```

每个 Agent 有独立的人格记忆，但共享同一个用户的基本信息。

### 🗑️ 清理旧数据

```python
# 删除单条记忆
mem0_client.delete(memory_id="mem_xyz")

# 删除整个训练周期
mem0_client.delete_all(user_id="max", run_id="old-training-cycle")
```

---

## 🎯 完整配置一览

把所有知识串起来的初始化代码：

```python
from mem0 import MemoryClient
from datetime import datetime, timedelta

mem0_client = MemoryClient(api_key="your-mem0-key")

# 1. 告诉 Mem0 什么值得记
mem0_client.project.update(
    custom_instructions="""
    Extract: goals, constraints, preferences, progress
    Exclude: greetings, filler, casual chat
    """,
    custom_categories=[
        {"name": "goals", "description": "Training targets"},
        {"name": "constraints", "description": "Injuries and limitations"},
        {"name": "preferences", "description": "Training style"}
    ]
)

# 2. 存长期目标
mem0_client.add([
    {"role": "user", "content": "I want to run a sub-4 marathon"}
], user_id="max", agent_id="ray")

# 3. 存会过期的伤病
mem0_client.add(
    [{"role": "user", "content": "Rolled ankle, need light workouts"}],
    user_id="max",
    expiration_date=(datetime.now() + timedelta(days=14)).strftime("%Y-%m-%d")
)

# 4. 存 Agent 人格
mem0_client.add(
    [{"role": "system", "content": "Direct, data-driven feedback. No fluff."}],
    agent_id="ray"
)

# 5. 检索时按需过滤
memories = mem0_client.search("training plan", user_id="max", limit=5)
```

---

## ✅ 上线前 Checklist

| # | 检查项 | 为什么 |
|---|---|---|
| 1 | 设置 `custom_instructions` | 过滤噪音，只存有价值的信息 |
| 2 | 定义 2-3 个 categories | 太多会稀释标签准确度 |
| 3 | 制定过期策略 | 临时信息不应该永久存在 |
| 4 | API 调用加错误处理 | Mem0 挂了不能让主流程崩溃 |
| 5 | 在 Mem0 Dashboard 监控记忆质量 | 确认存的都是有用的 |
| 6 | 清除测试数据 | 别让「test123」出现在生产环境 |
