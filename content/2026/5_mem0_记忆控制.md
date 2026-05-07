## 阶段 1：理解核心问题 —— 为什么不能"什么都存"？

### 🎯 一个生活类比

想象你是一个医生，每天接诊很多病人。你有一个笔记本记录病人信息。

* 病人说：**"我确诊了高血压"** → ✅ 你当然要记下来
* 病人说：**"我觉得我可能对青霉素过敏吧"** → ❌ 这只是猜测，你如果直接写成"病人对青霉素过敏"，下次开药就可能出事

**AI 记忆系统的问题完全一样。** 没有控制的记忆系统会把猜测当事实存起来。

### 💻 看问题代码

```python
# 病人说了一句猜测
messages = [{"role": "user", "content": "I think I might be allergic to penicillin"}]
client.add(messages, user_id="patient_123")

# 查看存了什么
results = client.search("patient allergies", filters={"user_id": "patient_123"})
print(results['results'][0]['memory'])
```

**输出：**
```
Patient is allergic to penicillin
```

> 🚨 **注意**："I think I might be"（我觉得我可能）被直接变成了 "Patient is"（病人是）。猜测变成了确认事实！

在医疗、法律、金融这些领域，这种错误是致命的。

### 🧠 核心认知

Mem0 提供 **三道防线** 来解决这个问题：

```
用户输入 → [自定义指令过滤] → [置信度门槛] → [更新/去重] → 存入记忆
```

就像工厂的质检流水线：原料进来要过三道关卡，不合格的直接淘汰。

---

## 阶段 2：Custom Instructions —— 告诉系统"什么该存，什么该扔"

### 🎯 类比

Custom Instructions 就像你给实习医生的工作手册：

> "只记录确诊的病症，别把病人的猜测当事实写进病历。"

### 💻 代码实战

```python
instructions = """
Only store CONFIRMED medical facts.

Store:
- Confirmed diagnoses from doctors        # 医生确认的诊断
- Known allergies with documented reactions # 有记录反应的过敏
- Current medications being taken          # 正在服用的药物

Ignore:
- Speculation (words like "might", "maybe", "I think")  # 猜测性语言
- Unverified symptoms                                    # 未验证的症状
- Casual mentions without confirmation                   # 随口一提
"""

# 把指令设置到项目级别
client.project.update(custom_instructions=instructions)
```

**设置完之后，再试同样的猜测：**

```python
messages = [{"role": "user", "content": "I think I might be allergic to penicillin"}]
client.add(messages, user_id="patient_123")

results = client.get_all(filters={"user_id": "patient_123"})
print(f"Memories stored: {len(results['results'])}")
# 输出: Memories stored: 0  ← 猜测被拦截了！
```

### ⚖️ 指令设计的度：太严 vs 太松 vs 刚好

这里有一个核心权衡——**精确率 vs 召回率**：

| 策略      | 问题          | 例子                          |
| :------ | :---------- | :-------------------------- |
| **太严格** | 漏掉有用信息（假阴性） | "必须有医生全名+执照号才存" → 大量合法信息被丢弃 |
| **太宽松** | 存入垃圾数据（假阳性） | "任何健康相关信息都存" → 猜测全变事实       |
| **平衡**  | 分类明确，附带示例   | 明确列出"存什么"和"不存什么"，给出具体例子     |

**最佳实践的黄金法则：**

> 🥇 **先严后松**——先用严格规则启动，根据实际使用情况逐步放宽。清理被污染的记忆库比放宽限制难得多。

**平衡指令的模板：**

```python
"""
Store CONFIRMED facts:
- Diagnoses: "Dr. Smith diagnosed hypertension on March 15th"
- Allergies: "Patient had hives reaction to penicillin"
- Medications: "Taking Lisinopril 10mg daily"

Ignore SPECULATION:
- "I think I might have..."
- "Maybe it's..."
- "Could be related to..."
"""
```

注意这里给出了**具体的语言模式示例**，让 AI 有明确的判断依据。

---

## 阶段 3：Confidence Thresholds —— 用"信心分数"做第二道关卡

### 🎯 类比

如果 Custom Instructions 是"手册规则"，那 Confidence Threshold 就是"考试及格线"。

Mem0 在提取记忆时会给每条记忆打一个**置信度分数**，就像考试分数一样：

* 分数高 → 信息明确、有细节支撑 → 存入
* 分数低 → 信息模糊、缺乏细节 → 拦截

### 💻 代码实战

```python
client.project.update(
    custom_instructions="""
Only extract memories with HIGH confidence.
Require specific details (dates, dosages, doctor names) for medical facts.
Skip vague or uncertain statements.
"""
)

# 测试1：模糊的陈述
messages = [{"role": "user", "content": "The doctor mentioned something about my blood pressure"}]
result1 = client.add(messages, user_id="patient_123")

# 测试2：有具体细节的确认事实
messages = [{"role": "user", "content": "Dr. Smith diagnosed me with hypertension on March 15th"}]
result2 = client.add(messages, user_id="patient_123")

print("模糊陈述被存入:", len(result1['results']) > 0)  # False
print("确认事实被存入:", len(result2['results']) > 0)  # True
```

### 📊 不同场景的推荐阈值

| 场景         | 推荐置信度 | 原因              |
| :--------- | :---- | :-------------- |
| 医疗/法律（高风险） | 0.8+  | 错误代价极大，宁可漏存不可错存 |
| 通用助手       | 0.6+  | 平衡实用性和准确性       |
| 探索性系统      | 0.4+  | 尽量多捕获信息，后续人工审核  |

---

## 阶段 4：PII 过滤 —— 阻止敏感信息入库

### 🎯 类比

这就像银行柜台的规定：客户可以告诉你身份证号来办业务，但你绝不能把它随手写在公共笔记本上。

### 💻 代码实战

```python
client.project.update(
    custom_instructions="""
NEVER STORE:
- Social Security Numbers (身份证号)
- Insurance policy numbers (保险号)
- Credit card information (信用卡信息)
- Full addresses (完整地址)
- Phone numbers (电话号码)

Replace identifiers with generic references if mentioned.
"""
)

# 测试：消息同时包含敏感信息和有用信息
messages = [
    {"role": "user", "content": "My SSN is 123-45-6789 and I'm allergic to penicillin"}
]
client.add(messages, user_id="patient_123")

results = client.get_all(filters={"user_id": "patient_123"})
for result in results['results']:
    print(result['memory'])
# 输出: Patient is allergic to penicillin
# SSN 被过滤掉了，过敏信息保留了 ✅
```

> 💡 **关键点**：系统不是把整条消息丢弃，而是**精准剥离**敏感部分，保留有价值的部分。

---

## 阶段 5：Update vs Delete —— 记忆的生命周期管理

### 🎯 类比

* **Update**（更新）= 用铅笔写病历，信息变了就擦掉重写，但保留修改痕迹
* **Delete**（删除）= 把那页纸撕掉，彻底不要了

### 💻 Update 实战

```python
# 第一次存入：确认青霉素过敏
result = client.add(
    [{"role": "user", "content": "Patient confirmed allergy to penicillin with documented hives reaction"}],
    user_id="patient_123"
)
memory_id = result['results'][0]['id']  # 记住这个 ID

# 后来复查发现是假阳性！需要更新，而不是新增一条矛盾的记录
client.update(
    memory_id=memory_id,
    text="Patient tested negative for penicillin allergy on April 2nd, 2025. Previous allergy was false positive.",
    metadata={"verified": True, "updated_date": "2025-04-02"}
)
```

### 📋 何时 Update vs 何时 Delete？

| 场景 | 操作 | 原因 |
|:---|:---|:---|
| 药物剂量从 10mg 改为 20mg | **Update** | 信息变了但仍相关，需要审计记录 |
| 之前的诊断被推翻 | **Update** | 保留修改历史，知道"曾经以为是 X" |
| 完全录错了人 | **Delete** | 信息从根本上就是错的 |
| 重复条目 | **Delete** | 只是冗余数据 |

**Update 的三大好处：**

1. **保留历史**：`created_at`（首次存入时间）和 `updated_at`（修改时间）都有记录
2. **避免冲突**：不会出现"既过敏又不过敏"的矛盾记忆
3. **维护关联**：如果用了图记忆（Graph Memory），与其他实体的连接关系不会断

---

## 阶段 6：推理模式 —— infer=True vs infer=False

### 🎯 类比

| 模式 | 类比 | 说明 |
|:---|:---|:---|
| `infer=True`（默认） | 交给聪明的助理整理 | 助理会理解内容、提取要点、自动去重 |
| `infer=False` | 直接原样归档 | 你给什么就存什么，一字不改，不做任何智能处理 |

### ⚠️ 关键陷阱

```
⚠️ 千万不要对同一条事实混用两种模式！
```

原因：`infer=True` 会做去重检查，但 `infer=False` 不会。如果你先用 `infer=False` 存了一条"青霉素过敏"，再用 `infer=True` 存同样的内容，系统不知道它们是同一件事，就会产生**重复记录**。

**最佳实践**：按数据来源分开。比如用不同的 `app_id` 区分：

```
app_id="daily_chat"     → 全部用 infer=True
app_id="bulk_import"    → 全部用 infer=False
```

---

## 阶段 7：完整 Pipeline 实战

现在把所有技术组合在一起：

```python
from mem0 import MemoryClient
import os

# 1. 初始化
client = MemoryClient(api_key=os.getenv("MEM0_API_KEY"))

# 2. 配置完整的过滤规则（三道防线合一）
client.project.update(
    custom_instructions="""
Medical memory assistant rules:

STORE:
- Confirmed diagnoses (with doctor name and date)
- Verified allergies (with reaction details)
- Current medications (with dosage)

IGNORE:
- Speculation (might, maybe, possibly)
- Unverified symptoms
- Personal identifiers (SSN, insurance numbers)

CONFIDENCE:
Require high confidence. Reject vague or uncertain statements.
Require specific details: names, dates, dosages.
"""
)

# 3. 封装安全写入函数
def add_medical_memory(content, user_id, metadata=None):
    result = client.add(
        [{"role": "user", "content": content}],
        user_id=user_id,
        metadata=metadata or {}
    )
    if result['results']:
        print(f"✓ 已存入: {result['results'][0]['memory']}")
    else:
        print(f"✗ 已拦截: {content}")
    return result

# 4. 批量测试
test_cases = [
    "I think I might be allergic to penicillin",                          # 猜测 → 拦截
    "Dr. Johnson confirmed penicillin allergy on Jan 15th with hives",    # 确认 → 存入
    "Patient SSN is 123-45-6789",                                         # PII → 拦截
    "Currently taking Lisinopril 10mg daily for hypertension",            # 药物 → 存入
    "Feeling tired lately",                                               # 模糊 → 拦截
    "Dr. Martinez diagnosed Type 2 diabetes on February 3rd, 2025"        # 确认 → 存入
]

for content in test_cases:
    add_medical_memory(content, user_id="patient_123")
```

**输出：**
```
✗ 已拦截: I think I might be allergic to penicillin
✓ 已存入: Patient has confirmed penicillin allergy diagnosed by Dr. Johnson on January 15th with hives reaction
✗ 已拦截: Patient SSN is 123-45-6789
✓ 已存入: Patient is currently taking Lisinopril 10mg daily for hypertension
✗ 已拦截: Feeling tired lately
✓ 已存入: Patient diagnosed with Type 2 diabetes by Dr. Martinez on February 3rd, 2025
```

### 🎁 彩蛋：Per-Call Instructions（临时覆盖规则）

有时候需要临时打破规则。比如急诊场景，什么都要先记下来：

```python
# 急诊模式：临时放宽规则，所有症状都先记录
client.add(
    [{"role": "user", "content": "Patient arrived with chest pain and shortness of breath"}],
    user_id="patient_456",
    custom_instructions="""Emergency intake mode:
    Store ALL symptoms and observations immediately.
    Flag for later review and verification.""",
    metadata={"type": "emergency", "review_required": True}
)
```

> 💡 `custom_instructions` 参数在 `client.add()` 中传入时，会**临时覆盖**项目级别的规则，只对这一次调用生效。

---

## 🧩 总结：完整的记忆质检流水线

```
用户输入
   │
   ▼
┌─────────────────────────┐
│  Custom Instructions    │ ← 规则过滤：猜测?PII?不相关?
│  (自定义指令)            │
└──────────┬──────────────┘
           │ 通过
           ▼
┌─────────────────────────┐
│  Confidence Threshold   │ ← 置信度检查：信息够具体吗?
│  (置信度门槛)            │
└──────────┬──────────────┘
           │ 通过
           ▼
┌─────────────────────────┐
│  Infer Pipeline         │ ← 去重检查：已经存过了吗?需要更新吗?
│  (推理管道 infer=True)   │
└──────────┬──────────────┘
           │ 通过
           ▼
      ✅ 存入记忆库
```

**记住这四个字：先严后松。** 上线时用最严格的规则，根据实际效果慢慢调整，比事后清理垃圾数据轻松一百倍。

