

## 1️⃣ 先搞懂"为什么"——一个生活类比

想象你是一家公司的 HR，你有两种工具：

### 📄 工具 A：一个超强搜索引擎（向量记忆）

你把所有员工信息写成一张张卡片，扔进一个"智能抽屉"里。当你问"谁会 React？"，它能根据**语义相似度**把最相关的卡片找出来。

> 🔑 关键词：**语义匹配**——不需要精确关键词，理解"意思"就能找到。

### 🕸️ 工具 B：一张关系网图（图记忆）

你在白板上画了一张人物关系图：谁和谁合作、谁向谁汇报、谁在哪个团队。当你问"Emma 的队友的上级是谁？"，你可以沿着线一步步走过去。

> 🔑 关键词：**关系遍历**——沿着实体之间的连接"走"，跨多步找到答案。

**核心矛盾来了：**

| 问题类型 | 搜索引擎能答吗？ | 关系网能答吗？ |
|---|---|---|
| "Emma 会什么技术？" | ✅ 完美 | 🤷 大材小用 |
| "Emma 队友的老板是谁？" | ⚠️ 给你线索，但不给答案 | ✅ 直接遍历得到 |

---

## 2️⃣ 向量记忆（Vector Memory）——语义搜索

### 它是什么？

Mem0 默认就是向量存储。当你 `client.add()` 时，文本被转成一个**高维向量**（一串数字），存进向量数据库。搜索时，你的问题也被转成向量，然后找**距离最近的**（语义最相似的）记忆。

### 例子

```python
from mem0 import MemoryClient

client = MemoryClient(api_key="your-api-key")

# 存入两条记忆
client.add("Emma 是西雅图的软件工程师", user_id="company_kb")
client.add("David 是奥斯汀的产品经理", user_id="company_kb")

# 搜索
results = client.search("Emma 是做什么的？", filters={"user_id": "company_kb"})
print(results['results'][0]['memory'])
# 输出: Emma 是西雅图的软件工程师
```

### 为什么能找到？

你问的是"Emma 是做什么的？"，存的是"Emma 是西雅图的软件工程师"。虽然用词不同，但**语义相似**——向量距离很近，所以匹配成功。

> 💡 **记住这个规则：一问一答、事实查找、独立信息 → 向量搜索就够了。**

---

## 3️⃣ 图记忆（Graph Memory）——关系遍历

### 问题引入

现在我们存了两条记忆：

```
记忆1: "Emma 和 David 一起做移动端 App 重构"
记忆2: "David 向 Rachel 汇报，Rachel 管理设计团队"
```

然后你问：**"Emma 队友的经理是谁？"**

### 向量搜索会怎样？

```python
results = client.search(
    "Emma 队友的经理是谁？",
    filters={"user_id": "company_kb"}
)

for r in results['results']:
    print(r['memory'])
```

输出：

```
Emma 和 David 一起做移动端 App 重构
David 向 Rachel 汇报，Rachel 管理设计团队
```

它**给了你两块拼图**，但没帮你拼起来。你得自己推理：
1. Emma 的队友 → David（从记忆1）
2. David 的经理 → Rachel（从记忆2）
3. 所以答案是 Rachel

**这就是"多跳问题"（multi-hop question）**——需要跳 2 步甚至更多步才能得到答案。

### 图记忆怎么解决？

```python
# 存的时候开启 enable_graph=True
client.add(
    "Emma 和 David 一起做移动端 App 重构",
    user_id="company_kb",
    enable_graph=True   # 🔑 关键开关
)

client.add(
    "David 向 Rachel 汇报，Rachel 管理设计团队",
    user_id="company_kb",
    enable_graph=True
)
```

Mem0 在背后**自动提取实体和关系**，构建了这样一张图：

```
Emma --[works_with]--> David
David --[reports_to]--> Rachel
Rachel --[manages]--> Design Team
```

现在搜索：

```python
results = client.search(
    "Emma 队友的经理是谁？",
    filters={"user_id": "company_kb"},
    enable_graph=True   # 🔑 搜索时也要开启
)

print(results['results'][0]['memory'])
# 输出: David 向 Rachel 汇报，Rachel 管理设计团队

print("关系链:")
for rel in results.get('relations', []):
    print(f"  {rel['source']} --[{rel['relationship']}]--> {rel['target']}")
# 输出:
#   emma --[works_with]--> david
#   david --[reports_to]--> rachel
```

> 🎯 图记忆**自动遍历了关系链**：Emma → David → Rachel，直接给出答案！

---

## 4️⃣ 核心对比——用一张图看清楚

想象这个场景的"知识图谱"：

```
        works_with         reports_to         manages
Emma ──────────────► David ──────────────► Rachel ──────────────► Design Team
  │                    │
  │  works_on          │  works_on
  ▼                    ▼
Mobile App           Mobile App
```

| 维度 | 向量记忆 (Vector) | 图记忆 (Graph) |
|---|---|---|
| **存储方式** | 文本 → 高维向量 | 文本 → 实体 + 关系 |
| **搜索方式** | 语义相似度匹配 | 沿关系边遍历 |
| **擅长** | "Emma 会什么？"（单跳） | "Emma 队友的老板？"（多跳） |
| **返回结果** | 最相似的记忆片段 | 答案 + 关系链 |
| **速度** | 快 ⚡ | 较慢（多了 LLM 提取步骤） |
| **成本** | 低 | 高（每次 add 多 2-3 次 LLM 调用） |

---

## 5️⃣ 实战模式——什么时候用哪个？

### 决策树

```
你的查询需要"连接多条信息"吗？
│
├── 否 → 用向量搜索（默认）
│        例: "Emma 的技能是什么？"
│        例: "公司有哪些福利政策？"
│
└── 是 → 用图记忆
         例: "谁是 Emma 项目经理的上级？"（2跳）
         例: "Emma 导师带的人都在哪个团队？"（多跳）
```

### 混合使用的最佳实践

```python
# ✅ 个人事实 → 只用向量（便宜、快）
client.add("Emma 精通 React 和 TypeScript", user_id="company_kb")
client.add("David 有 5 年产品管理经验", user_id="company_kb")

# ✅ 长期组织关系 → 开启图记忆
client.add(
    "Emma 和 David 在移动端项目合作",
    user_id="company_kb",
    enable_graph=True
)
client.add(
    "David 向 Rachel 汇报",
    user_id="company_kb",
    enable_graph=True
)

# ❌ 临时信息 → 千万别用图记忆（浪费钱）
client.add(
    "Emma 今天请病假了",
    user_id="company_kb",
    run_id="daily_notes"  # 用 run_id 标记临时数据
)
```

### 适合图记忆的典型场景

* **组织架构**：谁向谁汇报，谁管理哪个团队
* **项目协作**：谁和谁一起做什么项目
* **CRM 客户关系**：哪个联系人属于哪家公司
* **商品推荐**：哪些商品经常被一起购买

---

## 6️⃣ 成本权衡——Graph 不是免费的

### 开启 Graph 后发生了什么？

```
普通 add():
  文本 → embedding → 存入向量库
  (1 次 LLM 调用)

enable_graph=True 的 add():
  文本 → embedding → 存入向量库
  文本 → LLM 提取实体 → LLM 提取关系 → 存入图数据库
  (约 3 次 LLM 调用)
```

> ⚠️ **每次带 graph 的 add() 大约多 2-3 次 LLM 调用**，成本和延迟都会增加。

### 开启方式

**方式一：按需开启（推荐入门用）**

```python
# 只在需要的时候开
client.add("Emma 和 David 合作", user_id="kb", enable_graph=True)
client.search("团队结构", filters={"user_id": "kb"}, enable_graph=True)
```

**方式二：项目级全局开启（适合数据大部分都有关系的场景）**

```python
client.project.update(enable_graph=True)

# 之后所有 add 自动走图记忆
client.add("Emma 指导 Jordan", user_id="kb")
```

---

## 🧠 终极总结

用一句话记住：

> **向量记忆是"搜索引擎"，图记忆是"关系导航"。简单查找用向量，多跳关系用图，混合使用效果最好。**

| 你想做的事 | 用什么 | 为什么 |
|---|---|---|
| 查某人的技能/信息 | Vector | 单跳语义匹配，快且便宜 |
| 查 A 的同事的上级 | Graph | 需要 2 跳遍历 |
| 存临时笔记 | Vector | 没有关系可提取，别浪费钱 |
| 建组织架构知识库 | Graph | 关系是核心价值 |
| 建 FAQ | Vector | 每条独立，无需关系 |


