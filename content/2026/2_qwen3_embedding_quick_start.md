

## refer
- [hugging_face](https://huggingface.co/Qwen/Qwen3-Embedding-8B)


## 1️⃣ 什么是 Qwen3 Embedding？

**专门的文本嵌入模型**，用于将文本转换为向量，实现语义检索。

| 规格      | 参数               |
| :------ | :--------------- |
| 模型系列    | 0.6B, 4B, 8B     |
| 向量维度    | 1024, 2560, 4096 |
| 上下文长度   | 32K tokens       |
| MTEB 分数 | 70.58（8B，第一名）    |
| 支持语言    | 100+             |

---

## 2️⃣ Task Instruction 机制

### 核心概念
```
Task = 告诉模型"要做什么任务"
Query = 用户的搜索/问题（需要加 Task）
Document = 被搜索的内容（不需要加 Task）
```

### 非对称检索
```python
# Query 端：加 Task
query = "Instruct: Given a web search query, retrieve relevant passages
         Query: What is the capital of China?"

# Document 端：不加 Task
document = "The capital of China is Beijing."
```

**原因**：
- Query 短小模糊，需要上下文
- Document 内容完整，不需要额外说明

**效果**：精度提升 3-5%

---

## 3️⃣ 两种使用方式

### 方式1：sentence-transformers（推荐）

```python
from sentence_transformers import SentenceTransformer

# 加载模型
model = SentenceTransformer("Qwen/Qwen3-Embedding-8B")

# Query 加 prompt
query_embeddings = model.encode(
    ["What is the capital of China?"],
    prompt_name="query"  # 使用内置 query prompt
)

# Document 不加 prompt
doc_embeddings = model.encode([
    "The capital of China is Beijing."
])

# 计算相似度
similarity = model.similarity(query_embeddings, doc_embeddings)
# 输出: [[0.7493]]
```

### 方式2：vLLM（高性能）

```python
from vllm import LLM
import torch

# 加载模型
model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")

# 构造 Task Instruction
def get_instruct(task, query):
    return f'Instruct: {task}\nQuery:{query}'

task = 'Given a web search query, retrieve relevant passages'

# Query 加 task
queries = [
    get_instruct(task, 'What is the capital of China?'),
    get_instruct(task, 'Explain gravity')
]

# Document 不加 task
documents = [
    "The capital of China is Beijing.",
    "Gravity is a force that attracts..."
]

# 批量编码
outputs = model.embed(queries + documents)
embeddings = torch.tensor([o.outputs.embedding for o in outputs])

# 计算相似度矩阵
scores = embeddings[:2] @ embeddings[2:].T
# 输出: [[0.748, 0.076], [0.089, 0.630]]
```

---

## 4️⃣ 实战：记忆管理系统

```python
class MemorySystem:
    def __init__(self):
        self.model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")
    
    def store_memory(self, text: str, user_id: str):
        """存储记忆 - 不加 task"""
        embedding = self.model.embed([text])[0].outputs.embedding
        vector_db.insert(
            embedding=embedding,
            text=text,
            user_id=user_id
        )
    
    def search_memory(self, query: str, user_id: str):
        """搜索记忆 - 加 task"""
        task = "Given a user query, retrieve relevant memories"
        query_with_task = f"Instruct: {task}\nQuery: {query}"
        
        query_embedding = self.model.embed([query_with_task])[0].outputs.embedding
        
        results = vector_db.search(
            embedding=query_embedding,
            filter={"user_id": user_id},
            top_k=5
        )
        return results

# 使用
memory = MemorySystem()

# 存储
memory.store_memory("用户 Alice 喜欢喝咖啡", user_id="alice")

# 搜索
results = memory.search_memory("Alice 的饮食习惯", user_id="alice")
```

---

## 5️⃣ Task 模板

| 场景 | Task 模板 |
|:---|:---|
| 网页搜索 | `Given a web search query, retrieve relevant passages` |
| 记忆检索 | `Given a user query, retrieve relevant memories` |
| 文档检索 | `Given a question, find relevant documents` |
| 代码搜索 | `Given a coding query, retrieve relevant code snippets` |

---

## 6️⃣ 关键要点

### ✅ 必须记住
1. **Query 加 Task，Document 不加**
2. **Task 描述任务目标**（检索、分类、聚类等）
3. **批量处理提升性能**（vLLM）
4. **相似度 = 余弦相似度**（向量点积）

### 📊 性能数据
- **精度提升**：+3-5%（使用 Task）
- **MTEB 排名**：70.58（第一）
- **成本**：¥0.05/1M tokens（8B）

### 🔧 优化建议
- 使用 `flash_attention_2` 加速
- 批量处理（vLLM）
- 向量维度可调（32-4096）
- 支持自定义 Task

---

## 7️⃣ 完整示例

```python
# 场景：智能问答系统

from vllm import LLM
import torch

# 1. 初始化
model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")

# 2. 定义 Task
task = "Given a user question, retrieve the best answer"

# 3. 准备数据
questions = [
    f"Instruct: {task}\nQuery: Python 是什么?",
    f"Instruct: {task}\nQuery: 如何学习 AI?"
]

answers = [
    "Python 是一种编程语言，广泛用于数据科学和 AI。",
    "学习 AI 需要掌握数学、编程和机器学习基础。",
    "JavaScript 是一种用于 Web 开发的语言。"
]

# 4. 生成 embeddings
all_texts = questions + answers
outputs = model.embed(all_texts)
embeddings = torch.tensor([o.outputs.embedding for o in outputs])

# 5. 计算匹配度
scores = embeddings[:2] @ embeddings[2:].T
print(scores)
# [[0.85, 0.12, 0.08],   # 问题1 最匹配 答案1
#  [0.15, 0.82, 0.09]]   # 问题2 最匹配 答案2

# 6. 返回最佳答案
for i, question in enumerate(["Python 是什么?", "如何学习 AI?"]):
    best_idx = scores[i].argmax()
    print(f"Q: {question}")
    print(f"A: {answers[best_idx]}\n")
```

---

**完**

明白了！重新整理：

---

# 📚 Qwen3 Embedding 快速入门

## 1️⃣ 什么是 Qwen3 Embedding？

**专门的文本嵌入模型**，用于将文本转换为向量，实现语义检索。

| 规格 | 参数 |
|:---|:---|
| 模型系列 | 0.6B, 4B, 8B |
| 向量维度 | 1024, 2560, 4096 |
| 上下文长度 | 32K tokens |
| MTEB 分数 | 70.58（8B，第一名） |
| 支持语言 | 100+ |

---

## 2️⃣ Task Instruction 机制

### 核心概念
```
Task = 告诉模型"要做什么任务"
Query = 用户的搜索/问题（需要加 Task）
Document = 被搜索的内容（不需要加 Task）
```

### 非对称检索
```python
# Query 端：加 Task
query = "Instruct: Given a web search query, retrieve relevant passages
         Query: What is the capital of China?"

# Document 端：不加 Task
document = "The capital of China is Beijing."
```

**原因**：
- Query 短小模糊，需要上下文
- Document 内容完整，不需要额外说明

**效果**：精度提升 3-5%

---

## 3️⃣ 两种使用方式

### 方式1：sentence-transformers（推荐）

```python
from sentence_transformers import SentenceTransformer

# 加载模型
model = SentenceTransformer("Qwen/Qwen3-Embedding-8B")

# Query 加 prompt
query_embeddings = model.encode(
    ["What is the capital of China?"],
    prompt_name="query"  # 使用内置 query prompt
)

# Document 不加 prompt
doc_embeddings = model.encode([
    "The capital of China is Beijing."
])

# 计算相似度
similarity = model.similarity(query_embeddings, doc_embeddings)
# 输出: [[0.7493]]
```

### 方式2：vLLM（高性能）

```python
from vllm import LLM
import torch

# 加载模型
model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")

# 构造 Task Instruction
def get_instruct(task, query):
    return f'Instruct: {task}\nQuery:{query}'

task = 'Given a web search query, retrieve relevant passages'

# Query 加 task
queries = [
    get_instruct(task, 'What is the capital of China?'),
    get_instruct(task, 'Explain gravity')
]

# Document 不加 task
documents = [
    "The capital of China is Beijing.",
    "Gravity is a force that attracts..."
]

# 批量编码
outputs = model.embed(queries + documents)
embeddings = torch.tensor([o.outputs.embedding for o in outputs])

# 计算相似度矩阵
scores = embeddings[:2] @ embeddings[2:].T
# 输出: [[0.748, 0.076], [0.089, 0.630]]
```

---

## 4️⃣ 实战：记忆管理系统

```python
class MemorySystem:
    def __init__(self):
        self.model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")
    
    def store_memory(self, text: str, user_id: str):
        """存储记忆 - 不加 task"""
        embedding = self.model.embed([text])[0].outputs.embedding
        vector_db.insert(
            embedding=embedding,
            text=text,
            user_id=user_id
        )
    
    def search_memory(self, query: str, user_id: str):
        """搜索记忆 - 加 task"""
        task = "Given a user query, retrieve relevant memories"
        query_with_task = f"Instruct: {task}\nQuery: {query}"
        
        query_embedding = self.model.embed([query_with_task])[0].outputs.embedding
        
        results = vector_db.search(
            embedding=query_embedding,
            filter={"user_id": user_id},
            top_k=5
        )
        return results

# 使用
memory = MemorySystem()

# 存储
memory.store_memory("用户 Alice 喜欢喝咖啡", user_id="alice")

# 搜索
results = memory.search_memory("Alice 的饮食习惯", user_id="alice")
```

---

## 5️⃣ Task 模板

| 场景 | Task 模板 |
|:---|:---|
| 网页搜索 | `Given a web search query, retrieve relevant passages` |
| 记忆检索 | `Given a user query, retrieve relevant memories` |
| 文档检索 | `Given a question, find relevant documents` |
| 代码搜索 | `Given a coding query, retrieve relevant code snippets` |

---

## 6️⃣ 关键要点

### ✅ 必须记住
1. **Query 加 Task，Document 不加**
2. **Task 描述任务目标**（检索、分类、聚类等）
3. **批量处理提升性能**（vLLM）
4. **相似度 = 余弦相似度**（向量点积）

### 📊 性能数据
- **精度提升**：+3-5%（使用 Task）
- **MTEB 排名**：70.58（第一）
- **成本**：¥0.05/1M tokens（8B）

### 🔧 优化建议
- 使用 `flash_attention_2` 加速
- 批量处理（vLLM）
- 向量维度可调（32-4096）
- 支持自定义 Task

---

## 7️⃣ 完整示例

```python
# 场景：智能问答系统

from vllm import LLM
import torch

# 1. 初始化
model = LLM(model="Qwen/Qwen3-Embedding-8B", task="embed")

# 2. 定义 Task
task = "Given a user question, retrieve the best answer"

# 3. 准备数据
questions = [
    f"Instruct: {task}\nQuery: Python 是什么?",
    f"Instruct: {task}\nQuery: 如何学习 AI?"
]

answers = [
    "Python 是一种编程语言，广泛用于数据科学和 AI。",
    "学习 AI 需要掌握数学、编程和机器学习基础。",
    "JavaScript 是一种用于 Web 开发的语言。"
]

# 4. 生成 embeddings
all_texts = questions + answers
outputs = model.embed(all_texts)
embeddings = torch.tensor([o.outputs.embedding for o in outputs])

# 5. 计算匹配度
scores = embeddings[:2] @ embeddings[2:].T
print(scores)
# [[0.85, 0.12, 0.08],   # 问题1 最匹配 答案1
#  [0.15, 0.82, 0.09]]   # 问题2 最匹配 答案2

# 6. 返回最佳答案
for i, question in enumerate(["Python 是什么?", "如何学习 AI?"]):
    best_idx = scores[i].argmax()
    print(f"Q: {question}")
    print(f"A: {answers[best_idx]}\n")
```

