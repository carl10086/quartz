

## 阶段 1：为什么需要记忆分区？

### 🧠 生活类比：你的大脑 vs 公司的文件柜

想象你是一个秘书，服务整栋大楼里的所有人。如果你把**所有人的信息**都写在**同一张纸**上：

> "张三对花生过敏、李四喜欢蓝色、王五下周二开会、张三要订日式酒店……"

有一天老板问你："张三吃饭要注意什么？"你翻出来的结果可能是：

> "对花生过敏、**喜欢蓝色**、**下周二开会**、要订日式酒店"

**问题来了**：喜欢蓝色是李四的，开会是王五的——**信息混在一起了**！

这就是 Mem0 **没有做分区**时会发生的事情。文档里 Nora 的例子完全一样：

> 一个招聘者的"坚果过敏"信息，意外地出现在了旅行者的晚餐预订里。

### ✅ 解决方案的核心思想

给每条记忆**贴标签**，查询时**按标签过滤**。就像文件柜里的分类：

```
📁 文件柜（Mem0）
├── 📂 张三（user_id）
│   ├── 📂 旅行助手（agent_id）
│   │   └── 🗂️ 东京之旅（run_id）
│   └── 📂 美食推荐（agent_id）
│       └── 🗂️ 4月菜单（run_id）
└── 📂 李四（user_id）
    └── ...
```

---

## 阶段 2：四把钥匙 🔑

Mem0 用**四个标识符**来给记忆打标签：

| 标识符        | 比喻           | 作用         | 例子                                         |
| ---------- | ------------ | ---------- | ------------------------------------------ |
| `user_id`  | **这是谁的记忆？**  | 区分不同用户     | `"traveler_cam"`                           |
| `agent_id` | **哪个助手在服务？** | 区分不同 AI 角色 | `"travel_planner"`, `"chef_recommender"`   |
| `app_id`   | **哪个应用/产品？** | 区分不同产品线    | `"concierge_app"`, `"sports_brand_portal"` |
| `run_id`   | **哪次会话/任务？** | 区分临时对话     | `"tokyo-2025-weekend"`                     |

### 🎯 关键理解：这四个标识符是**写入时**就要指定的

```python
client.add(
    cam_messages,
    user_id="traveler_cam",        # 🔑 谁的
    agent_id="travel_planner",     # 🔑 哪个助手
    run_id="tokyo-2025-weekend",   # 🔑 哪次任务
    app_id="concierge_app"         # 🔑 哪个应用
)
```

> 💡 **记住**：Mem0 会用 LLM 从对话中**自动抽取关键信息**（比如从 `"I avoid shellfish"` 中提取出 `"avoids shellfish"`），但**标签是你手动传的**。信息抽取 + 标签分类 = 有序的记忆系统。

---

## 阶段 3：记忆泄露 💧 —— 最重要的反模式

这是本节**最核心**的知识点。我用一个完整的故事来讲：

### 场景设定

Cam 是一个旅行者，系统里存了两条记忆：

| 记忆内容 | user_id | agent_id |
|---|---|---|
| 不吃贝类，喜欢精品酒店 | traveler_cam | travel_planner |
| 喜欢京都怀石料理 | traveler_cam | chef_recommender |

### ❌ 错误查询：只用 `user_id` 过滤

```python
chef_filters = {"AND": [{"user_id": "traveler_cam"}]}
collision = client.search("What should I cook?", filters=chef_filters)
```

结果：

```python
['avoids shellfish and prefers boutique hotels',   # ← 这是旅行助手的！
 'prefers Kyoto kaiseki dining experiences']        # ← 这才是厨师的
```

**为什么泄露了？** 因为两条记忆的 `user_id` 都是 `"traveler_cam"`。你只按用户过滤，就像在文件柜里只找"张三的文件夹"，但没有再往下翻到"美食推荐"那个子文件夹。

### ✅ 正确查询：加上 `agent_id` 精准定位

```python
safe_filters = {
    "AND": [
        {"agent_id": "chef_recommender"},
        {"app_id": "concierge_app"},
        {"run_id": "menu-planning-2025-04"}
    ]
}
chef_memories = client.search("Any food alerts?", filters=safe_filters)
```

结果：

```python
{'results': [{'memory': 'prefers Kyoto kaiseki dining experiences'}]}
# ✅ 只有厨师助手的记忆，酒店偏好不会出现
```

### 🔑 核心原则

> **写入时标签越完整，查询时越不容易泄露。查询时过滤条件越精确，越安全。**

用一张图总结泄露 vs 安全：

```
❌ 泄露路径：
   query → user_id only → 返回该用户ALL记忆 → 💥 混乱

✅ 安全路径：
   query → user_id + agent_id + app_id → 返回精确范围记忆 → ✅ 干净
```

---

## 阶段 4：Filter 的 AND / OR / 通配符

### AND —— 所有条件都必须满足

```python
filters = {
    "AND": [
        {"user_id": "traveler_cam"},
        {"agent_id": "travel_planner"},
        {"app_id": "concierge_app"}
    ]
}
# 只返回：user_id=cam AND agent_id=travel_planner AND app_id=concierge_app 的记忆
```

类比：找一个人，必须**同时**满足"姓张"、"男性"、"北京人"。

### OR —— 满足任一条件即可

```python
filters = {
    "OR": [
        {"user_id": "*"},
        {"agent_id": "*"}
    ]
}
# 返回：有 user_id 的记忆 或 有 agent_id 的记忆
```

### 通配符 `"*"` —— 匹配任何非空值

```python
{"agent_id": "*"}   # agent_id 不为空的都算
{"agent_id": "chef_recommender"}  # 精确匹配
```

> ⚠️ **注意**：`"*"` 只匹配**非 null** 值。如果写入时没给 `agent_id`，通配符也匹配不到。

### 排错技巧：查询为空怎么办？

```python
# 第1步：先用最宽松的条件看看有什么
all_mems = client.get_all(filters={"user_id": "traveler_cam"})
print(json.dumps(all_mems, indent=2))  # 看看实际存了哪些字段

# 第2步：逐步收紧条件，找到是哪个字段不匹配
filters = {"AND": [{"user_id": "traveler_cam"}, {"agent_id": "*"}]}
```

---

## 阶段 5：生产环境实战模式

### 模式 1：夜间审计 —— 检查某个 app 的所有数据

```python
def audit_app(app_id: str):
    filters = {
        "AND": [{"app_id": app_id}],
        "OR": [{"user_id": "*"}, {"agent_id": "*"}]
    }
    return client.get_all(filters=filters, page=1, page_size=50)
```

### 模式 2：会话清理 —— 工单关闭后删除临时记忆

```python
def close_ticket(ticket_id: str, user_id: str):
    client.delete_all(user_id=user_id, run_id=ticket_id)
```

> 💡 `run_id` 就像**临时便签**，任务结束就可以撕掉。`user_id` 是**永久档案**，一般不删。

### 模式 3：租户下线 —— 删除整个品牌的数据

```python
client.delete_all(app_id="sports_brand_portal")
```

这在 SaaS 多租户场景下非常常见：一个客户退订了，用 `app_id` 一键清除所有相关数据。

---

## 🧪 理解检验：三个小问题

**Q1**：如果你有一个客服系统，同一个用户 Cam 同时在跟"退款助手"和"技术支持助手"聊天，你应该用什么来区分这两个对话的记忆？

<details>
<summary>点击看答案</summary>

用 `agent_id` 区分（比如 `"refund_agent"` vs `"tech_support_agent"`），同时可以用 `run_id` 区分不同的会话实例。

</details>

**Q2**：为什么下面这个查询可能返回空结果？

```python
filters = {"AND": [{"user_id": "cam"}, {"agent_id": "chef"}]}
```

<details>
<summary>点击看答案</summary>

可能原因：写入时 `agent_id` 的值是 `"chef_recommender"` 而不是 `"chef"`。AND 要求**精确匹配**，拼写不一致就查不到。这就是为什么文档建议用**一致的命名规范**。

</details>

**Q3**：`app_id` 和 `agent_id` 的区别是什么？什么时候用哪个？

<details>
<summary>点击看答案</summary>

* `app_id` = **产品/应用级别**的隔离（比如 iOS 旅行 App vs 企业门户），像是不同的**公司/部门**
* `agent_id` = **同一个应用内**不同 AI 角色的隔离（比如旅行助手 vs 美食助手），像是同一个部门里的**不同员工**

</details>

---

## 📌 一句话总结

> **Mem0 的记忆分区就像给文件贴四层标签（谁的 / 哪个助手 / 哪个应用 / 哪次会话），写入时贴好，查询时按标签过滤，就不会出现"张三的过敏信息跑到李四的晚餐预订里"的问题。**

有什么不清楚的地方吗？我可以针对任何一个阶段深入展开 🎯

