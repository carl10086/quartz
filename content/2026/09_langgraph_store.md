---
title: "langgraph store"
date: 2026-02-09
tags:
  - langgraph
---



## 1️⃣ 全景图：Memory 系统的整体架构

先看一张完整的地图，后面所有内容都在这张图里：

```
┌─────────────────── LangGraph Memory ───────────────────┐
│                                                         │
│  ┌──────────────┐         ┌──────────────────────────┐  │
│  │  短期记忆     │         │  长期记忆                 │  │
│  │  (State)     │         │  (Store)                 │  │
│  │              │         │                          │  │
│  │  Thread 范围  │         │  ┌────────┐ ┌────────┐   │  │
│  │  Checkpointer│         │  │语义记忆 │ │情景记忆 │   │  │
│  │              │         │  │(事实)  │ │(经验)  │   │  │
│  └──────────────┘         │  └────────┘ └────────┘   │  │
│                           │  ┌────────┐              │  │
│                           │  │程序记忆 │  写入方式：   │  │
│                           │  │(规则)  │  • Hot Path  │  │
│                           │  └────────┘  • Background│  │
│                           └──────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 2️⃣ 短期记忆

上次讲了基本概念，这次补充**管理策略的核心思想**。

### 问题本质

```
对话越来越长 → 消息列表不断增长 → 三个炸弹💣
```

| 💣 问题 | 类比 | 后果 |
|---|---|---|
| Context Window 溢出 | 书桌堆满了纸，再放一张就塌了 | **直接报错**，不可恢复 |
| 注意力分散 | 考试时桌上放了漫画书 | 回答质量**下降** |
| 成本飙升 | 每次复印都要复印全部历史文件 | 💰💰💰 |

### 管理策略的核心思想：主动遗忘

人类也不会记住每句对话，我们会**自动压缩和过滤**。LLM 需要你帮它做这件事：

```python
# 策略 1: 滑动窗口 —— 只保留最近 N 条
messages = [system_msg] + messages[-20:]

# 策略 2: Token 预算 —— 不超过 X 个 token
# 策略 3: 摘要替换 —— 用 LLM 把旧对话压缩成一段摘要

# 示意：
# 原始: [msg1, msg2, msg3, ..., msg50, msg51, msg52]
# 压缩后: [system_msg, summary("msg1-msg50的摘要"), msg51, msg52]
```

> 💡 **要记住**：短期记忆的挑战不是"怎么记住"，而是"**怎么聪明地遗忘**"。

---

## 3️⃣ 长期记忆 — 语义记忆（Semantic Memory）

### 什么是语义记忆？

**记住事实和概念**。不是某次具体经历，而是抽象的知识。

| 人类的语义记忆        | Agent 的语义记忆      |
| -------------- | ---------------- |
| "地球绕太阳转"       | "用户小明对花生过敏"      |
| "Python 是编程语言" | "这个公司的财年从 4 月开始" |
| "法国的首都是巴黎"     | "用户偏好简洁的回复风格"    |

> ⚠️ **语义记忆 ≠ 语义搜索**。语义记忆是心理学术语（存事实），语义搜索是检索技术（用 embedding 找相似内容）。别混淆！

### 两种存储模式：Profile vs Collection

这是本节最核心的对比，用一个生活类比来理解：

---

#### 🪪 Profile 模式 — "一张名片"

把所有关于某个实体的信息，维护成**一个 JSON 文档**，持续更新。

```python
# Profile 模式：一个用户 = 一个 JSON 文档
user_profile = {
    "name": "小明",
    "language": "zh-CN",
    "tone_preference": "formal",     # 之前是 casual，后来更新了
    "allergies": ["peanut"],
    "favorite_topics": ["Python", "AI"],
    "last_updated": "2026-02-09"
}
```

**更新流程**：

```
旧 Profile + 新对话 → LLM 生成新 Profile → 覆盖保存
```

```python
# 伪代码：更新 Profile
prompt = f"""
当前用户 Profile: {old_profile}
最近的对话: {recent_conversation}

请根据对话更新 Profile，输出新的 JSON。
"""
new_profile = llm.invoke(prompt)
store.put(namespace, "profile", new_profile)
```

**优点**：结构清晰，上下文完整，一次读取就拿到全貌
**缺点**：Profile 变大后，LLM 更新容易出错（漏掉旧信息、格式错乱）

---

#### 📂 Collection 模式 — "一个文件夹"

每条记忆是文件夹里的**一个独立文件**，不断新增、修改、删除。

```python
# Collection 模式：一个用户 = 多条独立记忆
memories = [
    {"id": "mem-001", "content": "用户名叫小明"},
    {"id": "mem-002", "content": "用户对花生过敏"},
    {"id": "mem-003", "content": "用户喜欢正式的语气"},
    {"id": "mem-004", "content": "用户在学 LangGraph"},
    # ... 可以不断增加
]
```

**优点**：
* 单条记忆小而精确，LLM 更容易生成
* 不容易丢失信息（新增比修改容易）
* 召回率（recall）更高

**缺点**：
* 更新复杂——要决定是"新增"还是"修改已有的"还是"删除旧的"
* 搜索复杂——用哪条？需要语义搜索 + 过滤
* 缺乏全局视角——单条记忆可能缺少上下文关联

---

#### 🤔 怎么选？

| 维度 | Profile | Collection |
|---|---|---|
| 信息量 | 适合少量、结构化的信息 | 适合大量、持续增长的信息 |
| 更新频率 | 低频更新 | 高频更新 |
| 信息关联性 | 信息之间有强关联 | 信息相对独立 |
| 类比 | 简历/个人资料卡 | 便利贴墙 |

**实际项目中**：可以两者结合。比如核心属性用 Profile，细碎的偏好用 Collection。

---

## 4️⃣ 长期记忆 — 情景记忆（Episodic Memory）

### 什么是情景记忆？

**记住具体的经历**。不是抽象事实，而是"那次我做了什么，结果如何"。

| 人类的情景记忆 | Agent 的情景记忆 |
|---|---|
| "上次我走那条路堵车了" | "上次用户问部署问题时，我用 Docker 方案解答效果很好" |
| "第一次骑自行车摔了" | "上次调用 API X 超时了，换成 API Y 成功了" |

### 实现方式：Few-shot Example Prompting

情景记忆在实践中，最常见的实现就是 **few-shot 示例**——把过去成功的"经验"作为示例喂给 LLM。

```python
# 假设我们存了一些过去的成功经验
past_experiences = [
    {
        "user_input": "帮我写个排序算法",
        "good_response": "这是快速排序的 Python 实现...(具体代码)"
    },
    {
        "user_input": "解释一下装饰器",
        "good_response": "装饰器就像礼物包装纸...(生动类比+代码)"
    }
]

# 构造 prompt 时，把相关经验作为 few-shot 示例
prompt = f"""
以下是一些好的回答示例：

示例 1:
用户: {past_experiences[0]["user_input"]}
回答: {past_experiences[0]["good_response"]}

示例 2:
用户: {past_experiences[1]["user_input"]}
回答: {past_experiences[1]["good_response"]}

现在请回答：
用户: {current_user_input}
"""
```

**核心思想**：有时候"做给你看"比"告诉你规则"更有效。LLM 从例子中学习的能力非常强。

> 💡 **存储方式的选择**：
> * 用 LangGraph **Store** → 灵活，代码控制
> * 用 LangSmith **Dataset** → 更适合和评估系统结合，内置 BM25 相似度检索

---

## 5️⃣ 长期记忆 — 程序记忆（Procedural Memory）

### 什么是程序记忆？

**记住规则和技能**。就像你骑自行车——你不用每次都"想"怎么骑，身体自动知道。

| 人类的程序记忆 | Agent 的程序记忆 |
|---|---|
| 骑自行车的肌肉记忆 | 模型权重（训练好的能力） |
| 打字时手指自动移动 | Agent 代码逻辑 |
| 做饭的步骤和习惯 | **System Prompt**（最常被修改的部分） |

### 实现方式：自我修改 Prompt（Reflection）

在实践中，Agent 一般不会改自己的代码或模型权重，但**可以改自己的 Prompt**！

这就像一个厨师根据食客反馈调整自己的烹饪习惯：

```
第1天: "我按照标准食谱做了红烧肉"
食客反馈: "太咸了"
第2天: "我记住了，少放盐" ← 修改了自己的"烹饪规则"
```

### 代码示例

```python
# 节点1: 使用当前指令来回答
def call_model(state: State, store: BaseStore):
    # 从 Store 读取当前的指令
    namespace = ("agent_instructions",)
    instructions = store.get(namespace, key="agent_a")
    
    # 用指令构造 prompt
    prompt = f"""
    你的行为准则：
    {instructions.value["instructions"]}
    
    用户消息：
    {state["messages"][-1].content}
    """
    response = llm.invoke(prompt)
    return {"messages": [response]}


# 节点2: 根据反馈更新指令
def update_instructions(state: State, store: BaseStore):
    # 读取当前指令
    namespace = ("agent_instructions",)
    current = store.get(namespace, key="agent_a")
    
    # 让 LLM 反思并改进指令
    prompt = f"""
    你当前的行为准则是：
    {current.value["instructions"]}
    
    以下是最近的对话（包含用户反馈）：
    {state["messages"]}
    
    请根据用户反馈，改进你的行为准则。
    """
    output = llm.invoke(prompt)
    
    # 保存新指令
    store.put(
        ("agent_instructions",), 
        "agent_a", 
        {"instructions": output.content}
    )
```

**流程图**：

```
用户反馈 → update_instructions → Store(新 Prompt) → call_model 读取新 Prompt → 更好的回答
    ↑                                                                           │
    └───────────────────────────────────────────────────────────────────────────┘
```

> 💡 **现实案例**：文档里提到了一个 Tweet 生成器。写论文摘要的 prompt 很难一次写好，但用户可以轻松地说"这条推文太长了"、"不够吸引人"，Agent 就据此修改自己的摘要生成策略。

---

## 6️⃣ 写入时机：Hot Path vs Background

这是一个**架构决策**，类比如下：

### 🔥 Hot Path — "边聊边记"

就像你和朋友聊天时，**当场**在笔记本上记下重要信息。

```
用户: 我下周要去东京出差
Agent: (心想：这个要记住！) 
       → 调用 save_memory 工具
       → 存储: "用户下周去东京出差"
       → 回复: "好的！需要我帮你查东京的天气或餐厅推荐吗？"
```

| ✅ 优点 | ❌ 缺点 |
|---|---|
| 实时更新，立即可用 | 增加响应延迟 |
| 用户可感知（透明） | Agent 要"一心多用" |
| 新记忆立刻生效 | 需要额外的 tool（如 `save_memories`） |

**代表产品**：ChatGPT 的记忆功能就是 Hot Path，它使用 `save_memories` 工具在对话中决定存什么。

---

### 🌙 Background — "事后整理"

就像你结束一天的会议后，**晚上回家整理笔记**。

```
用户和 Agent 正常对话（不受打扰）
        ↓
对话结束后，后台异步任务启动
        ↓
分析对话 → 提取值得记住的信息 → 存入 Store
```

| ✅ 优点 | ❌ 缺点 |
|---|---|
| 不影响主流程延迟 | 新记忆不能立即使用 |
| 应用逻辑和记忆逻辑分离 | 需要决定"多久跑一次" |
| Agent 可以专注当前任务 | 其他 Thread 可能暂时缺少最新上下文 |

**触发策略**：
* ⏰ 定时触发（如每 5 分钟）
* 📅 Cron 调度（如每天凌晨）
* 🖱️ 手动触发（用户点"保存"或对话结束时）

---

### 怎么选？

```
需要实时性？ ──是──→ 🔥 Hot Path
     │
     否
     │
     ↓
对延迟敏感？ ──是──→ 🌙 Background
     │
     否
     │
     ↓
两者结合：关键信息 Hot Path，其余 Background
```

---

## 7️⃣ 存储机制：Store API 实战

最后，所有长期记忆都需要一个**物理存储**。LangGraph 的 Store 就是这个存储层。

### 核心概念

```
Store
  └── Namespace (类似文件夹，支持层级)
        └── Key (类似文件名)
              └── Value (JSON 文档)
```

把它想象成一个**文件系统**：

```
/my-user/chitchat/          ← namespace = ("my-user", "chitchat")
    ├── a-memory.json        ← key = "a-memory"
    ├── b-memory.json        ← key = "b-memory"
    └── ...

/my-user/work/               ← namespace = ("my-user", "work")
    ├── project-notes.json
    └── ...

/org-abc/shared/              ← namespace = ("org-abc", "shared")
    └── guidelines.json
```

### 完整代码示例

```python
from langgraph.store.memory import InMemoryStore

# 1. 创建 Store（生产环境应使用数据库后端）
def embed(texts: list[str]) -> list[list[float]]:
    # 实际项目中替换为真正的 embedding 函数
    return [[1.0, 2.0] * len(texts)]

store = InMemoryStore(
    index={"embed": embed, "dims": 2}  # 启用语义搜索
)

# 2. 定义 namespace（用户 ID + 应用场景）
user_id = "xiaoming"
context = "chitchat"
namespace = (user_id, context)

# 3. 写入记忆
store.put(
    namespace,
    "preferences",  # key
    {
        "rules": [
            "用户喜欢简短直接的语言",
            "用户只说中文和 Python",
        ],
        "tone": "formal",
    },
)

# 4. 精确读取（知道 key）
item = store.get(namespace, "preferences")
print(item.value)
# → {"rules": [...], "tone": "formal"}

# 5. 搜索（不知道具体 key，但知道大概内容）
results = store.search(
    namespace,
    filter={"tone": "formal"},       # 内容过滤
    query="language preferences",     # 语义搜索
)
```

### 三种访问方式对比

| 方式 | 用途 | 类比 |
|---|---|---|
| `store.get(namespace, key)` | 精确获取某条记忆 | 打开书架上特定的那本书 |
| `store.search(namespace, query=...)` | 语义搜索相关记忆 | 在图书馆搜索"关于 AI 的书" |
| `store.search(namespace, filter=...)` | 按字段过滤 | 筛选"2026 年出版的书" |

---

## 🎯 终极总结

```
┌──────────────────────────────────────────────────────────────┐
│                    LangGraph Memory 全景                      │
│                                                              │
│  ┌─────────────┐    ┌──────────────────────────────────────┐ │
│  │ 短期记忆     │    │ 长期记忆                              │ │
│  │             │    │                                      │ │
│  │ State       │    │  语义记忆    情景记忆     程序记忆      │ │
│  │ Checkpointer│    │  (事实)     (经验)      (规则)       │ │
│  │             │    │  Profile/   Few-shot    Prompt       │ │
│  │ 管理:       │    │  Collection  Examples   Reflection   │ │
│  │ • 滑动窗口  │    │                                      │ │
│  │ • Token 限制│    │  写入: Hot Path / Background          │ │
│  │ • 摘要压缩  │    │  存储: Store (namespace + key + JSON) │ │
│  └─────────────┘    └──────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### 记忆三问（设计长期记忆时问自己）

1. **What** — 记什么类型？事实（语义）/ 经验（情景）/ 规则（程序）
2. **When** — 什么时候写？实时（Hot Path）/ 异步（Background）
3. **How** — 怎么组织？Profile（单文档）/ Collection（多文档）
