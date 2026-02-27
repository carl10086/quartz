
## 第一部分：核心概念理解

### 1.1 传统AI的记忆问题

让我用一个生活化的例子帮你理解：

**场景：你雇了一个助理**

```
第一天：
你："我叫张三，负责产品设计，正在做电商APP项目"
助理："好的，记住了！"

第二天：
你："帮我整理一下项目进展"
助理："请问您是哪位？什么项目？"😅
```

这就是传统AI的问题：**上下文窗口有限，对话结束记忆就清空了**。

即使有"记忆功能"(像ChatGPT的Memory)，也只是：
```
- 用户叫张三
- 做电商项目
- 喜欢简洁回复
```

这种**扁平列表**有三个问题：
1. **没有优先级**：重要的和不重要的混在一起
2. **没有结构**：找不到"张三负责的所有项目"
3. **没有时间维度**：不知道哪些是最近的、哪些过时了

---

### 1.2 人类记忆的启发

人类大脑是怎么管理记忆的？

#### 🧠 多层次存储
- **工作记忆**：正在做的事 (容量小，7±2项)
- **短期记忆**：最近几天的事
- **长期记忆**：重要的经验和知识

#### 🔥 记忆强度动态变化
- 经常用的记忆 → 更容易回忆 (巩固)
- 长期不用的记忆 → 逐渐淡忘 (衰减)
- 相关的记忆 → 互相关联 (图结构)

#### 📚 两种知识类型
- **显性知识**：可以说出来的事实 ("北京是首都")
- **隐性知识**：只可意会的经验 ("怎么骑自行车")

**OpenClaw的三层架构就是模拟这个机制！**

---

### 1.3 为什么需要三层？

| 层级 | 对应人类记忆 | 存什么 | 更新频率 |
|:---|:---|:---|:---|
| **知识图谱** | 长期记忆 | 事实和实体关系 | 有重要事件时更新 |
| **每日笔记** | 短期记忆 | 流水账和临时想法 | 每天追加 |
| **隐性知识** | 行为习惯 | 偏好和工作风格 | 发现新模式时更新 |

**核心思想**：
- 不同类型的信息，用不同方式存储
- 高频访问的放前面 (衰减机制)
- 低频但重要的可以检索到 (搜索层)

---

## 第二部分：三层架构详解

### 2.1 Layer 1: 知识图谱 (PARA)

#### 什么是PARA？

PARA是Tiago Forte发明的一种信息组织方法，名字来自四个英文单词：

```
P - Projects   (项目)     有deadline的工作
A - Areas      (领域)     持续责任区
R - Resources  (资源)     参考资料
A - Archives   (归档)     完成的内容
```

#### 为什么这样分？

**关键区别：有没有终点**

```
Projects  → "3月底前完成APP首页设计"  ✅ 有终点
Areas     → "维护和张三的合作关系"    ⭕ 无终点
Resources → "UI设计灵感收集"         📚 参考用
Archives  → "已上线的2.0版本"        📦 归档
```

#### 实际目录结构示例

让我用一个真实场景演示：

```
life/
├── projects/                    # 正在做的项目
│   ├── ecommerce-app/          # 电商APP项目
│   │   ├── summary.md          # 快速概览
│   │   └── items.json          # 详细事实
│   └── company-website/        # 公司官网重构
│       ├── summary.md
│       └── items.json
│
├── areas/                      # 持续维护的领域
│   ├── people/                 # 人际关系
│   │   ├── zhang-san/
│   │   │   ├── summary.md     # "张三是我们的产品经理"
│   │   │   └── items.json     # 详细互动记录
│   │   └── li-si/
│   │       ├── summary.md
│   │       └── items.json
│   └── companies/              # 公司和组织
│       └── acme-corp/
│           ├── summary.md
│           └── items.json
│
├── resources/                  # 参考资料
│   ├── design-patterns/
│   └── ai-prompts/
│
└── archives/                   # 归档
    └── old-projects/
```

---

### 2.2 原子化事实：items.json的设计

#### 为什么需要JSON格式？

传统笔记：
```markdown
# 张三
- 产品经理
- 2026年1月入职
- 喜欢简洁的方案
```

问题：
- AI难以精确解析
- 无法追溯历史变化
- 不知道哪条最重要

**原子化事实的解决方案**：

```json
{
  "id": "fact-001",
  "fact": "张三是产品经理",
  "category": "relationship",
  "timestamp": "2026-01-15",
  "status": "active",
  "supersededBy": null,
  "relatedEntities": ["companies/acme-corp"],
  "lastAccessed": "2026-02-27",
  "accessCount": 45
}
```

#### 字段详解

让我逐个解释：

| 字段 | 作用 | 例子 |
|:---|:---|:---|
| **id** | 唯一标识 | `fact-001` |
| **fact** | 事实内容 | "张三是产品经理" |
| **category** | 事实类型 | milestone / relationship / preference |
| **timestamp** | 创建时间 | "2026-01-15" |
| **status** | 状态 | active / superseded |
| **supersededBy** | 被哪条替代 | `fact-015` (如果职位变化) |
| **relatedEntities** | 关联实体 | `["projects/app", "people/lisi"]` |
| **lastAccessed** | 最后访问 | "2026-02-27" |
| **accessCount** | 访问次数 | 45 |

#### 🔑 核心机制：永不删除原则

**场景：张三升职了**

❌ 错误做法：
```json
// 直接改内容
{"fact": "张三是产品总监"}  // 历史丢失了！
```

✅ 正确做法：
```json
// 旧事实
{
  "id": "fact-001",
  "fact": "张三是产品经理",
  "status": "superseded",           // 标记为过时
  "supersededBy": "fact-015",       // 指向新事实
  "timestamp": "2026-01-15"
}

// 新事实
{
  "id": "fact-015",
  "fact": "张三是产品总监",
  "status": "active",
  "supersededBy": null,
  "timestamp": "2026-02-20"
}
```

**这样做的好处**：
1. 可以追溯历史："张三什么时候升职的？"
2. 形成时间链条：fact-001 → fact-015 → fact-023
3. 保留完整上下文："他做经理期间负责了哪些项目？"

---

### 2.3 分层加载策略

#### 问题：如果所有事实都加载会怎样？

假设你有：
- 10个项目，每个50条事实
- 20个联系人，每个30条事实
- 总共：10×50 + 20×30 = **1100条事实**

全部加载到AI上下文 → **爆炸💥**

#### 解决方案：summary.md + items.json 分层

```
第1层：summary.md (概览)
只包含最核心的信息，100-200字

第2层：items.json (详细)
完整的原子化事实，只在需要时加载
```

#### 实际例子

**projects/ecommerce-app/summary.md**
```markdown
# 电商APP项目

**状态**: 进行中
**负责人**: 张三
**开始日期**: 2026-01-15
**关键里程碑**: 
- 首页设计已完成 (2026-02-10)
- 正在开发购物车功能

**最近更新** (Hot 🔥):
- 2026-02-25: 用户测试反馈收集完成
- 2026-02-20: 支付接口对接完成
```

**projects/ecommerce-app/items.json**
```json
[
  {
    "id": "milestone-001",
    "fact": "项目于2026年1月15日启动",
    "category": "milestone",
    "timestamp": "2026-01-15",
    "status": "active",
    "lastAccessed": "2026-01-20",
    "accessCount": 3
  },
  {
    "id": "milestone-012",
    "fact": "首页设计于2月10日完成",
    "category": "milestone",
    "timestamp": "2026-02-10",
    "status": "active",
    "lastAccessed": "2026-02-27",
    "accessCount": 18
  },
  {
    "id": "decision-005",
    "fact": "决定使用Stripe作为支付方案",
    "category": "decision",
    "timestamp": "2026-02-15",
    "status": "active",
    "relatedEntities": ["people/zhang-san"],
    "lastAccessed": "2026-02-20",
    "accessCount": 7
  }
  // ... 更多事实
]
```

#### AI的加载策略

```
用户问："电商APP项目怎么样了？"

Step 1: 加载 summary.md (快！)
     → "项目进行中，最近完成了用户测试"

用户问："当时为什么选择Stripe支付？"

Step 2: 搜索 items.json
     → 找到 decision-005
     → "因为张三认为Stripe文档完善且易于集成"

同时更新：
     lastAccessed = 今天
     accessCount += 1
```

---

### 2.4 Layer 2: 每日笔记 (时间线)

#### 为什么需要时间线？

知识图谱解决了"是什么"，但还需要"什么时候发生"。

#### 目录结构

```
memory/
├── 2026-02-25.md
├── 2026-02-26.md
└── 2026-02-27.md    # 今天
```

#### 每日笔记的格式

**memory/2026-02-27.md**
```markdown
# 2026-02-27

## 📋 完成的任务
- 和张三讨论了电商APP的用户反馈
- 修改了首页布局设计
- 开会确定下周的开发计划

## 💡 重要决策
- 决定推迟购物车功能到下个迭代
- 原因：用户测试显示首页流畅度更重要

## 👥 互动记录
- 张三：对新设计很满意，建议加入动画效果
- 李四：提出性能优化建议

## 🔧 技术细节
- 使用React Native的FlatList优化长列表性能
- 集成了Sentry用于错误监控

## 💭 想法和感受
- 感觉项目进度比预期快
- 需要提前准备下个月的演示PPT
```

---

### 2.5 自动提取机制 (Heartbeat)

#### 流程图

```
每日笔记 (原始记录)
    ↓
[Heartbeat 任务]  ← 每天晚上运行
    ↓
提取重要事实
    ↓
┌─────────────────┐
│ 识别事实类型     │
│ - 新人物?        │
│ - 新项目?        │
│ - 重要决策?      │
│ - 用户偏好?      │
└─────────────────┘
    ↓
写入知识图谱
    ↓
更新 items.json + summary.md
```

#### 实际提取示例

**输入** (今天的笔记片段):
```markdown
张三对新设计很满意，建议加入动画效果
```

**提取动作**:
```json
// 1. 更新 people/zhang-san/items.json
{
  "id": "feedback-027",
  "fact": "张三对2026-02-27的首页设计表示满意",
  "category": "feedback",
  "timestamp": "2026-02-27",
  "status": "active",
  "relatedEntities": ["projects/ecommerce-app"],
  "lastAccessed": "2026-02-27",
  "accessCount": 1
}

// 2. 更新 projects/ecommerce-app/items.json
{
  "id": "feedback-028",
  "fact": "用户反馈：建议加入动画效果提升体验",
  "category": "feedback",
  "timestamp": "2026-02-27",
  "status": "active",
  "relatedEntities": ["people/zhang-san"],
  "lastAccessed": "2026-02-27",
  "accessCount": 1
}
```

**提取规则**：

| 如果笔记包含... | 提取到... | 事实类型 |
|:---|:---|:---|
| "新认识了XXX" | `areas/people/XXX/` | 创建新实体 |
| "启动XXX项目" | `projects/XXX/` | 创建新项目 |
| "决定使用..." | 相关实体的items.json | category: decision |
| "XXX喜欢..." | `tacit_knowledge.md` | 用户偏好 |
| 日常闲聊 | 不提取 | - |

---

### 2.6 Layer 3: 隐性知识

#### 什么是隐性知识？

显性知识 (Explicit):
```
"张三是产品经理"
"项目2月15日启动"
```

隐性知识 (Tacit):
```
"用户喜欢简洁的回复"
"用户倾向先做再说，不喜欢过度计划"
"用户主要用Telegram沟通"
```

这些是**行为模式和偏好**，不是具体事实。

#### 文件格式

**tacit_knowledge.md**
```markdown
# 用户隐性知识库

## 📞 沟通偏好
- **语言**: 中文交流，但代码和文档用英文
- **风格**: 喜欢简洁直接，避免冗长解释
- **工具**: 
  - 主要: Telegram
  - 次要: 邮件 (仅正式场合)
  - 不用: 微信工作交流

## 💼 工作风格
- **决策方式**: 快速迭代，边做边改
- **计划观**: 不喜欢详细的事前规划，倾向"先做80%"
- **反馈习惯**: 直接指出问题，不需要委婉

## 🤖 AI协作边界
- **允许的自主操作**:
  - ✅ 自动整理笔记
  - ✅ 提取重要事实
  - ✅ 定期生成summary
  
- **需要审批的操作**:
  - ⚠️ 发布内容到社交媒体
  - ⚠️ 删除文件
  - ⚠️ 修改代码

## 🛠️ 工具使用习惯
- **代码编辑器**: VS Code
- **笔记工具**: Obsidian
- **版本控制**: Git + GitHub
- **AI工具**: Claude (Sonnet 4.5), OpenClaw

## 📊 信息呈现偏好
- **数据**: 喜欢表格和图表，不喜欢长段落
- **代码**: 需要完整的可运行示例，不要伪代码
- **解释**: 先给结论，再展开细节
```

#### 如何更新隐性知识？

**触发条件**：
```
用户连续3次说"太长了，简短点"
  → 更新沟通偏好: "喜欢简洁回复"

用户每次都修改AI生成的计划
  → 更新工作风格: "不喜欢详细规划"

用户总是在Telegram回复，从不用邮件
  → 更新工具偏好: "主要用Telegram"
```

**更新频率**：低频（发现新模式时）

---

## 第三部分：动态机制

### 3.1 记忆衰减：Hot / Warm / Cold

#### 为什么需要衰减？

**问题场景**：
```
你有50个项目，AI每次都加载所有summary
→ 实际上只有3个项目是活跃的
→ 47个项目的信息只是噪音
```

**解决方案**：根据访问频率动态调整优先级

#### 三档分级

```
🔥 Hot (热记忆)
   条件: 7天内访问过
   效果: 出现在summary.md最前面
   
🌤️ Warm (温记忆)
   条件: 8-30天前访问
   效果: 在summary.md较后位置
   
❄️ Cold (冷记忆)
   条件: 30+天未访问
   效果: 从summary移除 (但保留在items.json)
```

#### 实际示例

**初始状态** (summary.md):
```markdown
# 我的项目

## 🔥 进行中
1. 电商APP - 每天都在推进
2. 公司官网 - 上周开了会
3. 博客系统 - 两个月没动了

## 📊 统计
总项目数: 3
```

**7天后** (经过衰减):
```markdown
# 我的项目

## 🔥 Hot
1. 电商APP 
   - 最后访问: 今天
   - 访问次数: 145次

## 🌤️ Warm  
2. 公司官网
   - 最后访问: 7天前
   - 访问次数: 23次

## ❄️ Cold (已归档到items.json)
3. 博客系统
   - 最后访问: 67天前
   - 访问次数: 5次
```

---

### 3.2 频次保护机制

#### 问题：高访问量的记忆不应该轻易变冷

**场景**：
```
"电商APP"项目你每周都会查看
但这周出差了，10天没提到
→ 按时间规则应该变Warm
→ 但这是最重要的项目！
```

**解决方案**：结合 `accessCount` 判断

```javascript
function calculateMemoryTemperature(fact) {
  const daysSinceAccess = getDaysSince(fact.lastAccessed);
  const accessCount = fact.accessCount;
  
  // 高频访问的记忆有保护期
  const protectionDays = Math.min(accessCount / 10, 14);
  
  if (daysSinceAccess < 7) {
    return 'Hot';
  } else if (daysSinceAccess < 30 + protectionDays) {
    return 'Warm';
  } else {
    return 'Cold';
  }
}
```

#### 例子

```json
{
  "id": "project-001",
  "fact": "电商APP项目",
  "lastAccessed": "2026-02-17",  // 10天前
  "accessCount": 145              // 高频访问
}

计算:
  daysSinceAccess = 10
  protectionDays = min(145/10, 14) = 14
  
  10 < 30 + 14 = 44
  → 仍然是 Warm (而不是立即变Cold)
```

---

### 3.3 重新激活机制

#### 场景：突然想起旧项目

```
用户："博客系统当时为什么暂停的？"

当前状态:
  blog-system → Cold (不在summary里)
  
AI操作:
  1. 通过QMD搜索找到 projects/blog-system/items.json
  2. 加载相关事实
  3. 回答问题
  4. 更新:
     lastAccessed = 今天
     accessCount += 1
     
下次summary刷新:
  blog-system → Hot 🔥 (重新出现在summary)
```

#### 代码示例

```python
def access_fact(fact_id):
    # 1. 从items.json加载事实
    fact = load_fact(fact_id)
    
    # 2. 更新访问记录
    fact['lastAccessed'] = today()
    fact['accessCount'] += 1
    
    # 3. 保存
    save_fact(fact)
    
    # 4. 标记需要刷新summary
    mark_summary_dirty(fact['entity_path'])
    
    return fact
```

---

### 3.4 每周Summary刷新流程

#### 触发时机

- **定期**: 每周日晚上
- **手动**: 用户要求时
- **自动**: 当Hot事实数量 > 50时

#### 刷新流程

```
1. 遍历所有实体目录
   ├── projects/
   ├── areas/people/
   └── areas/companies/

2. 对每个实体:
   ├── 加载 items.json
   ├── 计算每个事实的温度 (Hot/Warm/Cold)
   ├── 按温度排序
   └── 重新生成 summary.md

3. 输出统计:
   ├── Hot: 15 facts
   ├── Warm: 32 facts
   └── Cold: 78 facts (不在summary)
```

#### Summary模板

```markdown
# {实体名称}

**类型**: {Project/Person/Company}
**状态**: {Active/Archived}
**最后更新**: {日期}

---

## 🔥 最近活动 (Hot)
{7天内访问的事实，按访问次数排序}

## 🌤️ 近期相关 (Warm)
{8-30天访问的事实}

## 📊 统计
- 总事实数: {count}
- Hot: {hot_count}
- Warm: {warm_count}
- Cold: {cold_count}

## 🔗 关联实体
{relatedEntities列表}
```

---

### 3.5 搜索层：QMD详解

#### QMD是什么？

**Q**uick **M**emory **D**atabase - 一个本地的语义搜索工具

核心特性：
- **全文搜索** (BM25算法)
- **向量搜索** (Embeddings相似度)
- **混合搜索** (两者结合 + reranking)

#### 安装和配置

```bash
# 1. 安装QMD
brew install qmd  # macOS
# 或从 https://github.com/qmd-tool/qmd 编译

# 2. 添加collections (索引目录)
qmd collection add ~/life --name life --mask "**/*.md"
qmd collection add ~/memory --name memory --mask "**/*.md"

# 3. 创建索引
qmd update

# 4. 生成embeddings (向量)
qmd embed
```

#### 三种搜索模式

##### 1️⃣ 全文搜索 (关键词精确匹配)

```bash
qmd search "张三 产品经理" -c life

# 返回:
[1] areas/people/zhang-san/summary.md
    Score: 8.5
    ... 张三是我们的**产品经理**...
    
[2] projects/ecommerce-app/summary.md
    Score: 6.2
    ... 负责人: **张三** ...
```

**优点**: 快速、精确
**缺点**: 必须用原文词汇

---

##### 2️⃣ 向量搜索 (语义相似度)

```bash
qmd vsearch "那个负责设计的同事" -c life

# 即使没提"张三"，也能找到:
[1] areas/people/zhang-san/summary.md
    Similarity: 0.87
    ... 张三负责产品设计...
```

**工作原理**:
```
1. 查询文本 → Embedding向量
   "那个负责设计的同事" → [0.23, -0.41, 0.67, ...]

2. 每个文档也有Embedding
   zhang-san/summary.md → [0.25, -0.38, 0.70, ...]

3. 计算余弦相似度
   similarity = cosine(query_vec, doc_vec)

4. 返回最相似的文档
```

**优点**: 语义理解，不需要精确词汇
**缺点**: 可能返回不相关但语义相似的内容

---

##### 3️⃣ 混合搜索 (默认，最强大)

```bash
qmd query "上周关于API的讨论" -c memory

工作流程:
1. 关键词匹配: "API" → 找到5个文档
2. 向量扩展: "讨论" → 语义匹配10个文档
3. Reranking: 综合评分，返回最相关的3个

返回:
[1] memory/2026-02-20.md  (Score: 9.1)
[2] memory/2026-02-21.md  (Score: 7.8)
[3] projects/ecommerce-app/items.json  (Score: 6.5)
```

**Reranking机制**:
```
综合评分 = 
  0.4 × BM25得分 +
  0.4 × 向量相似度 +
  0.2 × 访问频次加成
```

---

### 3.6 AI使用搜索的完整流程

#### 场景：用户提问

```
用户: "电商APP项目的支付功能进展怎么样了？"
```

#### AI的思考过程

```
Step 1: 识别实体
  → "电商APP项目" = projects/ecommerce-app

Step 2: 加载summary
  → 读取 projects/ecommerce-app/summary.md
  → 快速了解: "项目进行中，最近完成用户测试"
  
Step 3: 检查summary是否有答案
  → summary只提到"购物车功能"，没有"支付"
  
Step 4: 执行搜索
  → qmd query "支付功能 电商APP" -c life
  
Step 5: 找到相关事实
  → projects/ecommerce-app/items.json
     {
       "id": "milestone-015",
       "fact": "支付接口于2月20日对接完成",
       "category": "milestone"
     }
  
Step 6: 更新访问记录
  → lastAccessed = 2026-02-27
  → accessCount = 8 (从7变8)
  
Step 7: 返回答案
  "支付功能的接口对接已在2月20日完成，
   当时选择了Stripe作为支付方案。"
```

---

## 第四部分：实战演练

### 4.1 从零搭建完整示例

让我们用一个真实场景，手把手搭建：

**背景**：你是一个自由职业设计师，要管理多个客户和项目

#### Step 1: 创建目录结构

```bash
# 创建根目录
mkdir -p ~/life/{projects,areas/{people,companies},resources,archives}
mkdir -p ~/memory

# 创建配置目录
mkdir -p ~/clawd
```

#### Step 2: 创建第一个项目

**场景**：你接了一个logo设计项目

```bash
mkdir -p ~/life/projects/logo-design-acme
cd ~/life/projects/logo-design-acme
```

**创建 summary.md**:
```markdown
# ACME公司Logo设计

**类型**: 设计项目
**客户**: ACME公司
**状态**: 进行中
**开始日期**: 2026-02-20
**截止日期**: 2026-03-15
**预算**: ¥15,000

## 最近进展 🔥
- 2026-02-27: 提交了3个初稿方案
- 2026-02-25: 和客户开会确认设计方向
- 2026-02-20: 项目启动会议

## 关键信息
- 客户喜欢简约现代风格
- 主色调倾向蓝色系
- 需要提供SVG和PNG格式

## 关联实体
- companies/acme-corp
- people/wang-manager
```

**创建 items.json**:
```json
[
  {
    "id": "milestone-001",
    "fact": "项目于2026年2月20日启动",
    "category": "milestone",
    "timestamp": "2026-02-20",
    "status": "active",
    "supersededBy": null,
    "relatedEntities": ["companies/acme-corp"],
    "lastAccessed": "2026-02-20",
    "accessCount": 1
  },
  {
    "id": "decision-001",
    "fact": "确定使用简约现代风格，蓝色主色调",
    "category": "decision",
    "timestamp": "2026-02-25",
    "status": "active",
    "supersededBy": null,
    "relatedEntities": ["people/wang-manager"],
    "lastAccessed": "2026-02-27",
    "accessCount": 5
  },
  {
    "id": "deliverable-001",
    "fact": "需要交付SVG和PNG格式的文件",
    "category": "requirement",
    "timestamp": "2026-02-20",
    "status": "active",
    "supersededBy": null,
    "relatedEntities": [],
    "lastAccessed": "2026-02-27",
    "accessCount": 3
  }
]
```

---

#### Step 3: 创建客户联系人

```bash
mkdir -p ~/life/areas/people/wang-manager
```

**people/wang-manager/summary.md**:
```markdown
# 王经理

**关系**: ACME公司项目对接人
**职位**: 市场部经理
**认识时间**: 2026-02-20
**沟通方式**: 微信为主，邮件备份

## 特点 🔥
- 决策快，不喜欢拖延
- 对设计品质要求高
- 周五通常很忙，尽量不约会

## 最近互动
- 2026-02-27: 对初稿方案2很感兴趣
- 2026-02-25: 会议确认了设计方向

## 相关项目
- projects/logo-design-acme
```

---

#### Step 4: 写今天的每日笔记

**memory/2026-02-27.md**:
```markdown
# 2026-02-27

## 完成的工作
- 为ACME公司设计了3个logo初稿
- 方案1: 几何抽象风格
- 方案2: 字母组合 (王经理最喜欢这个)
- 方案3: 图形符号

## 重要反馈
王经理说方案2最符合他们的品牌调性，建议：
- 字体可以再粗一点
- 蓝色调整为 #2C5F9E
- 加入一点渐变效果

## 下一步计划
- 明天优化方案2
- 周五前提交修改版
- 准备3个配色变体

## 时间记录
- 设计: 4小时
- 沟通: 1小时
- 总计: 5小时
```

---

#### Step 5: 配置Heartbeat自动提取

创建一个脚本 `~/clawd/heartbeat.sh`:

```bash
#!/bin/bash

# Heartbeat - 自动提取今天的笔记到知识图谱

TODAY=$(date +%Y-%m-%d)
NOTE_FILE="$HOME/memory/$TODAY.md"

if [ ! -f "$NOTE_FILE" ]; then
  echo "No note for today"
  exit 0
fi

# 调用AI提取事实
echo "Extracting facts from today's note..."

# 这里是伪代码，实际需要用OpenClaw的API
openclaw extract-facts \
  --input "$NOTE_FILE" \
  --output-dir "$HOME/life" \
  --update-access-count

# 更新搜索索引
echo "Updating search index..."
qmd update
qmd embed

echo "✅ Heartbeat completed"
```

设置定时任务 (macOS):
```bash
# 每天晚上10点运行
echo "0 22 * * * $HOME/clawd/heartbeat.sh" | crontab -
```

---

#### Step 6: 配置QMD搜索

```bash
# 添加collections
qmd collection add ~/life --name life --mask "**/*.md"
qmd collection add ~/memory --name memory --mask "**/*.md"

# 初始化索引
qmd update

# 生成向量embeddings
qmd embed
```

测试搜索:
```bash
# 全文搜索
qmd search "ACME logo" -c life

# 语义搜索
qmd vsearch "那个蓝色logo项目" -c life

# 混合搜索
qmd query "王经理喜欢什么风格" -c life
```

---

#### Step 7: 创建隐性知识文件

**~/clawd/tacit_knowledge.md**:
```markdown
# 我的工作偏好

## 设计风格
- 擅长: 简约现代、扁平化
- 不擅长: 复古、过于花哨

## 工作习惯
- 最佳创作时间: 上午9-12点
- 不要在周五安排重要会议 (通常很累)
- 喜欢一次性把一个项目做完，不喜欢多任务切换

## 沟通偏好
- 客户沟通用微信
- 正式交付用邮件
- 不喜欢电话会议，倾向文字沟通

## 文件管理
- 所有设计稿用Figma
- 交付文件统一命名: `{client}-{project}-{date}-{version}.{ext}`
- 归档到 ~/Design/Archives/{year}/{client}/

## AI协作边界
- ✅ 可以自动整理笔记
- ✅ 可以提醒deadline
- ⚠️ 不要直接发送文件给客户 (需要我审核)
```

---

### 4.2 完整工作流演示

#### 场景1：启动新项目

**Day 1 (2026-03-01)**

```
你: "我接了一个新项目，给某科技公司设计APP图标，
     预算¥8000，3月20日要交付"

AI: 
  1. 创建 projects/app-icon-tech/
  2. 写入 summary.md 和 items.json
  3. 记录到 memory/2026-03-01.md
  4. 自动识别"新项目"，标记为Hot 🔥
```

**生成的文件**:

`projects/app-icon-tech/summary.md`:
```markdown
# 科技公司APP图标设计

**状态**: 🔥 进行中
**开始**: 2026-03-01
**截止**: 2026-03-20
**预算**: ¥8,000
**关联**: companies/tech-corp

## 关键要求
(等待进一步信息...)
```

---

#### 场景2：一周后查询

**Day 7 (2026-03-08)**

```
你: "我现在有哪些正在做的项目？"

AI:
  1. 加载所有 projects/*/summary.md
  2. 按Hot > Warm > Cold排序
  3. 返回:
     "你有2个进行中的项目：
     
     🔥 Hot:
     1. APP图标设计 (科技公司) - 距离deadline还有12天
        最后访问: 今天
     
     🌤️ Warm:
     2. Logo设计 (ACME公司) - 已完成，等待最终确认
        最后访问: 5天前"
```

---

#### 场景3：搜索历史决策

**Day 30 (2026-03-30)**

```
你: "ACME的logo当时为什么选蓝色？"

AI:
  1. 执行搜索: qmd query "ACME logo 蓝色" -c life
  2. 找到 items.json 里的事实:
     {
       "id": "decision-001",
       "fact": "确定使用蓝色因为符合科技感和信任感",
       "timestamp": "2026-02-25"
     }
  3. 同时找到相关笔记:
     memory/2026-02-25.md
  4. 返回:
     "在2月25日的会议上，王经理提出蓝色更符合他们
      科技公司的品牌定位，能传递信任感。"
  
  5. 更新访问记录 (把这个Cold事实重新变Hot)
```

---

#### 场景4：记忆衰减

**Day 60 (2026-04-29)**

```
系统: 运行每周summary刷新

处理 projects/logo-design-acme/:
  - 最后访问: 30天前
  - 访问次数: 47次
  - 状态: active → 改为 archived (项目已完成)
  
  决策:
    ✅ 保留 items.json (完整历史)
    ✅ 从projects/ 移动到 archives/
    ❄️ 标记为Cold (summary不再显示)

结果:
  你问"我有什么项目"时，AI只返回活跃项目
  但你问"ACME项目"时，仍可通过搜索找到
```

---

### 4.3 高级场景：多实体关联

#### 场景：复杂项目网络

**关系图**:
```
Project: 电商APP
    ├── 涉及人员
    │   ├── 张三 (产品经理)
    │   ├── 李四 (开发)
    │   └── 王五 (设计)
    │
    ├── 关联公司
    │   └── ACME Corp (客户)
    │
    └── 相关技术
        ├── React Native
        └── Stripe支付
```

#### 图结构表达

**projects/ecommerce-app/items.json**:
```json
{
  "id": "project-root",
  "fact": "电商APP项目",
  "category": "project",
  "relatedEntities": [
    "people/zhang-san",
    "people/li-si",
    "people/wang-wu",
    "companies/acme-corp",
    "resources/react-native",
    "resources/stripe"
  ]
}
```

**people/zhang-san/items.json**:
```json
{
  "id": "person-root",
  "fact": "张三是产品经理",
  "category": "relationship",
  "relatedEntities": [
    "projects/ecommerce-app",
    "companies/acme-corp"
  ]
}
```

#### 查询示例

```
你: "电商APP项目都有谁参与？"

AI:
  1. 加载 projects/ecommerce-app/items.json
  2. 提取 relatedEntities 里的 people/*
  3. 加载每个人的 summary.md
  4. 返回:
     "参与人员：
     - 张三 (产品经理) - 主要负责需求和原型
     - 李四 (开发工程师) - 负责后端API
     - 王五 (UI设计师) - 负责界面设计"

你: "张三还参与了哪些项目？"

AI:
  1. 加载 people/zhang-san/items.json
  2. 提取 relatedEntities 里的 projects/*
  3. 返回:
     "张三参与的项目：
     1. 电商APP (进行中)
     2. 公司官网 (已完成)
     3. 内部管理系统 (暂停)"
```

---

## 总结：核心要点回顾

### 🏗️ 三层架构

| 层级 | 存储内容 | 更新频率 | 例子 |
|:---|:---|:---|:---|
| **知识图谱** | 事实和关系 | 有重要事件时 | "张三是产品经理" |
| **每日笔记** | 时间流水账 | 每天追加 | "今天和张三开会讨论..." |
| **隐性知识** | 行为偏好 | 发现新模式时 | "用户喜欢简洁回复" |

### 🔥 记忆衰减

```
Hot (7天)  → 优先显示
Warm (30天) → 次要显示  
Cold (30+天) → 搜索可得
```

### 🔍 搜索策略

```
全文搜索: 关键词精确匹配
向量搜索: 语义理解
混合搜索: 两者结合 (推荐)
```

### 🔄 自动化流程

```
每日笔记 → Heartbeat提取 → 更新知识图谱 → 刷新索引
```

---

## 常见问题解答

### Q1: 一定要用PARA吗？可以用自己的分类吗？

**答**: PARA不是强制的，但强烈推荐。

核心原则：
- ✅ 有明确的分类逻辑
- ✅ 每个实体有 summary.md + items.json
- ✅ 区分"有终点"和"无终点"的事

你可以改成:
```
work/        # 工作相关
  ├── clients/
  └── projects/
personal/    # 个人生活
  ├── health/
  └── hobbies/
learning/    # 学习记录
```

关键是**结构化**，不是具体用什么名字。

---

### Q2: items.json会不会越来越大？

**答**: 会，但不是问题。

1. **分层加载**：AI通常只读summary
2. **按需检索**：只在需要时加载items
3. **定期归档**：完成的项目移到archives/

实际数据量：
- 一个活跃项目: 50-100条事实
- 文件大小: 约10-20KB
- 即使100个项目，也只有1-2MB

现代硬盘和AI上下文窗口都能轻松处理。

---

### Q3: 如果两条事实冲突怎么办？

**答**: 用supersede机制。

```json
// 旧事实
{
  "id": "fact-001",
  "fact": "张三是产品经理",
  "status": "superseded",
  "supersededBy": "fact-015"
}

// 新事实
{
  "id": "fact-015",
  "fact": "张三已升职为产品总监",
  "status": "active",
  "timestamp": "2026-03-01"
}
```

AI会自动：
- 优先使用active状态的事实
- 在需要历史时回溯supersede链条

---

### Q4: 隐性知识是手动写还是AI自动生成？

**答**: 两者结合。

**初始**：手动写一个模板
**后续**：AI观察你的行为模式，提出更新建议

```
AI: "我注意到你最近10次回复都要求'简短点'，
     是否要更新tacit_knowledge.md，
     添加'沟通偏好：简洁直接'？"
     
你: "是的"

AI: 自动更新文件
```

---

### Q5: QMD索引多久更新一次？

**答**: 看情况。

**推荐策略**：
- `qmd update`: 每次Heartbeat后运行 (每天)
- `qmd embed`: 每周运行一次 (比较慢)

原因：
- update只更新文本索引 (快)
- embed要重新生成向量 (慢)

除非你大幅修改了内容，否则不需要频繁embed。

---

### Q6: 可以和其他工具集成吗？

**答**: 完全可以！

因为全是文件系统，所以兼容：

| 工具 | 用途 |
|:---|:---|
| **Obsidian** | 可视化编辑md文件 |
| **Git** | 版本控制和备份 |
| **Syncthing** | 跨设备同步 |
| **Raycast** | 快速搜索 |
| **Shortcuts** | 自动化流程 |

---

## 参考资料

- **PARA方法论**: 《Building a Second Brain》 by Tiago Forte
- **QMD工具**: [QMD](https://github.com/tobi/qmd)
- **OpenClaw文档**: [OpenClaw](https://github.com/openclaw/openclaw)


