
原文: [Thinking in Langgraph](https://docs.langchain.com/oss/python/langgraph/thinking-in-langgraph)

# LangGraph 思维模式：如何构建 AI Agent

## 核心思想：从流程到代码的映射

LangGraph 的本质是什么？**它帮你把业务流程转换成可执行的代码图**。就像画流程图一样，但每个节点都是可以执行的函数，节点之间通过共享的"状态"（state）来传递信息。

### 为什么需要 LangGraph？

传统编程是线性的：A → B → C，每一步都写死。但 AI Agent 需要：
- **动态决策**：根据情况选择不同路径
- **可中断恢复**：遇到问题能暂停，人工介入后继续
- **状态持久化**：记住之前做了什么
- **错误处理**：不同错误有不同策略

LangGraph 就是为了解决这些问题而生的。

---

## 五步构建法：从需求到实现

### 第一步：将流程拆解为离散步骤

**关键思考**：每个步骤应该是一个"原子操作"，只做一件事。

以客户支持邮件处理为例：
- `读取邮件`：提取邮件内容
- `分类意图`：判断紧急程度和类型
- `文档搜索`：查找相关知识库
- `创建工单`：如果是 bug，创建跟踪单
- `起草回复`：生成回复内容
- `人工审核`：复杂问题需要人工确认
- `发送回复`：最终发送邮件

**为什么这样拆分？**
- **可观测性**：每个步骤的结果都可以单独检查
- **容错性**：某个步骤失败，只需要重试这个步骤，不用从头开始
- **可复用性**：`文档搜索`节点可以在其他流程中复用

**思考题**：为什么不把"读取邮件"和"分类意图"合并成一个节点？
- 可以合并，但会失去中间状态的可见性
- 如果分类失败，需要重新读取邮件（虽然邮件内容没变，但浪费了一次 API 调用）
- 分离后，可以在分类前检查邮件格式是否正确

---

### 第二步：识别每个步骤的类型和需求

每个节点需要明确：
1. **它是什么类型**：LLM 调用、数据查询、外部操作，还是需要人工介入？
2. **它需要什么输入**：从状态中读取哪些数据？
3. **它产生什么输出**：更新状态的哪些字段？
4. **它如何决定下一步**：根据结果选择哪个节点？

#### LLM 步骤（理解、分析、生成）

**分类意图节点**：
- 静态上下文（提示词）：分类规则、紧急程度定义
- 动态上下文（从状态读取）：邮件内容、发件人信息
- 输出：结构化的分类结果，决定路由方向

**起草回复节点**：
- 静态上下文：公司政策、回复模板、语气要求
- 动态上下文：分类结果、搜索结果、客户历史
- 输出：待审核的回复草稿

**思考**：为什么要把"静态"和"动态"分开？
- 静态内容（提示词模板）可以提前优化，不需要每次都传
- 动态内容（状态数据）每次运行都不同
- 这种分离让代码更清晰，也便于测试（可以 mock 状态）

#### 数据步骤（外部数据源）

**文档搜索**：
- 参数：从意图和主题构建查询
- 重试策略：需要！网络可能临时故障
- 缓存：可以考虑，常见查询可以缓存

**客户历史查询**：
- 参数：从状态中获取客户邮箱或 ID
- 重试策略：需要，但可以降级（如果查不到，用基本信息）
- 缓存：建议缓存，客户信息不会频繁变化

**思考**：什么时候应该缓存？
- 数据变化频率低（客户信息）
- 查询成本高（API 调用、数据库查询）
- 但要注意：缓存可能导致数据过时，需要设置 TTL

#### 操作步骤（执行外部动作）

**发送回复**：
- 执行时机：审核通过后
- 重试策略：必须！不能丢失邮件
- 不能缓存：每次发送都是唯一操作

**创建工单**：
- 执行时机：意图是"bug"时
- 重试策略：必须！不能丢失 bug 报告
- 返回：工单 ID，需要存入状态（用于回复中引用）

**思考**：为什么操作步骤不能缓存？
- 操作是"副作用"（side effect），执行了就改变了外部世界
- 发送邮件、创建工单都是不可逆的
- 缓存会导致重复执行，造成问题

#### 人工介入步骤

**人工审核节点**：
- 触发条件：高紧急度、复杂问题、质量担忧
- 需要展示的信息：原始邮件、草稿回复、紧急程度、分类结果
- 期望输入：批准/拒绝 + 可选的编辑内容

**关键机制**：`interrupt()` 函数
- 暂停执行，保存所有状态
- 可以无限期等待（几天、几周都可以）
- 恢复时从暂停点继续，状态完全恢复

---

### 第三步：设计状态（State）

**状态是什么？** 所有节点共享的"笔记本"，记录整个流程中的信息。

#### 什么应该放在状态里？

**应该放**：
- ✅ 需要跨步骤持久化的数据（邮件内容、分类结果）
- ✅ 昂贵操作的结果（搜索结果、客户数据，避免重复查询）
- ✅ 中间产物（草稿回复，需要经过审核）
- ✅ 执行元数据（用于调试和恢复）

**不应该放**：
- ❌ 可以从其他数据推导出来的（比如格式化后的提示词）
- ❌ 临时变量（只在单个节点内使用）

#### 核心原则：状态存原始数据，格式化在节点内完成

**为什么？**
```python
# ❌ 错误做法：在状态中存格式化文本
state = {
    "formatted_prompt": "请分析以下邮件：\n" + email + "\n分类为..."
}

# ✅ 正确做法：状态存原始数据
state = {
    "email_content": email,
    "classification": {"intent": "bug", "urgency": "high"}
}

# 在节点内格式化
def classify_intent(state):
    prompt = f"请分析以下邮件：\n{state['email_content']}\n分类为..."
    # 使用 prompt 调用 LLM
```

**好处**：
1. **灵活性**：不同节点可以用不同格式使用同一数据
2. **可维护性**：改提示词模板不需要改状态结构
3. **可调试性**：看到的是原始数据，更清晰
4. **可演化性**：状态结构稳定，节点逻辑可以变化

**状态定义示例**：
```python
from typing import TypedDict, Literal

class EmailClassification(TypedDict):
    intent: Literal["question", "bug", "billing", "feature", "complex"]
    urgency: Literal["low", "medium", "high", "critical"]
    topic: str
    summary: str

class EmailAgentState(TypedDict):
    # 原始邮件数据
    email_content: str
    sender_email: str
    email_id: str
    
    # 分类结果
    classification: EmailClassification | None
    
    # 原始搜索结果
    search_results: list[str] | None
    customer_history: dict | None
    
    # 生成的内容
    draft_response: str | None
    messages: list[str] | None
```

**思考**：为什么用 `TypedDict` 而不是普通字典？
- 类型提示：IDE 可以自动补全，减少错误
- 文档作用：一眼看出状态结构
- 运行时仍然是普通字典，不影响性能

---

### 第四步：实现节点

节点就是函数：接收状态，返回状态更新。

#### 节点函数的基本结构

```python
def node_name(state: EmailAgentState) -> Command | dict:
    # 1. 从状态读取需要的数据
    email = state.get('email_content')
    
    # 2. 执行操作（LLM 调用、API 查询等）
    result = do_something(email)
    
    # 3. 返回状态更新
    return {"classification": result}
```

#### 路由决策：使用 Command

当节点需要决定下一步时，使用 `Command`：

```python
from langgraph.types import Command

def classify_intent(state: EmailAgentState) -> Command[Literal["search_documentation", "bug_tracking", "draft_response"]]:
    # 分类逻辑
    classification = llm_classify(state['email_content'])
    
    # 根据分类结果决定路由
    if classification['intent'] == 'bug':
        goto = "bug_tracking"
    elif classification['intent'] == 'question':
        goto = "search_documentation"
    else:
        goto = "draft_response"
    
    return Command(
        update={"classification": classification},
        goto=goto
    )
```

**思考**：为什么路由逻辑放在节点里，而不是在图的定义中？
- **显式性**：看节点代码就知道它会去哪里
- **灵活性**：同一个节点可以根据不同条件去不同地方
- **可测试性**：可以单独测试节点的路由逻辑

#### 错误处理策略

| 错误类型 | 谁处理 | 策略 | 使用场景 |
|---------|--------|------|---------|
| 临时错误（网络故障、限流） | 系统自动 | 重试策略 | 通常重试就能解决 |
| LLM 可恢复错误（工具调用失败） | LLM 自己 | 循环重试，提供更多上下文 | LLM 可以调整策略 |
| 需要人工介入的错误 | 用户 | 中断等待输入 | 权限问题、数据缺失 |
| 不可恢复错误 | 开发者 | 抛出异常，记录日志 | 代码 bug、配置错误 |

**思考**：为什么不同错误要不同处理？
- 临时错误：自动重试，用户无感知
- LLM 错误：给 LLM 更多信息，让它自己调整
- 人工错误：必须停下来，等用户解决
- 系统错误：立即失败，避免浪费资源

#### 人工介入：interrupt() 的使用

**关键规则**：`interrupt()` 必须放在节点函数的最开始！

```python
def human_review(state: EmailAgentState) -> Command[Literal["send_reply", END]]:
    # ❌ 错误：在 interrupt 之前有代码
    # processed_data = process(state)  # 这行代码会在恢复时重复执行！
    
    # ✅ 正确：interrupt 放在最前面
    human_decision = interrupt({
        "email_id": state.get('email_id'),
        "original_email": state.get('email_content'),
        "draft_response": state.get('draft_response'),
        "action": "请审核并批准/编辑此回复"
    })
    
    # interrupt 之后的代码只在恢复时执行
    if human_decision.get("approved"):
        return Command(
            update={"draft_response": human_decision.get("edited_response")},
            goto="send_reply"
        )
    else:
        return Command(update={}, goto=END)
```

**为什么 interrupt 必须在最前面？**
- LangGraph 在节点边界创建检查点
- 如果节点在 interrupt 之前有代码，恢复时会重新执行这些代码
- 可能导致重复操作（比如重复调用 API）

---

### 第五步：连接节点，构建图

图的定义很简单，因为路由逻辑已经在节点里了：

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import StateGraph, START, END

# 创建图
workflow = StateGraph(EmailAgentState)

# 添加节点（可以附加重试策略）
workflow.add_node("read_email", read_email)
workflow.add_node("classify_intent", classify_intent)
workflow.add_node(
    "search_documentation",
    search_documentation,
    retry_policy=RetryPolicy(max_attempts=3)  # 网络操作需要重试
)
workflow.add_node("bug_tracking", bug_tracking)
workflow.add_node("draft_response", draft_response)
workflow.add_node("human_review", human_review)
workflow.add_node("send_reply", send_reply)

# 只定义必要的边
workflow.add_edge(START, "read_email")
workflow.add_edge("read_email", "classify_intent")
workflow.add_edge("send_reply", END)

# 编译（需要 checkpointer 才能使用 interrupt）
memory = MemorySaver()
app = workflow.compile(checkpointer=memory)
```

**为什么只需要这么少的边？**
- 大部分路由由节点内的 `Command` 决定
- 只需要定义：起点、终点、以及某些固定流程（如"读取邮件"后总是"分类"）

**使用示例**：
```python
# 初始状态
initial_state = {
    "email_content": "我被重复扣费了！这很紧急！",
    "sender_email": "[email protected]",
    "email_id": "email_123",
    "messages": []
}

# 运行（使用 thread_id 保持状态）
config = {"configurable": {"thread_id": "customer_123"}}
result = app.invoke(initial_state, config)

# 如果遇到 interrupt，会暂停
if result.get('__interrupt__'):
    print("等待人工审核...")
    
    # 人工审核后，恢复执行
    human_response = Command(
        resume={
            "approved": True,
            "edited_response": "我们深表歉意，已立即启动退款..."
        }
    )
    final_result = app.invoke(human_response, config)
```

---

## 核心洞察：LangGraph 的设计哲学

### 1. 分解为离散步骤
- **为什么**：每个节点只做一件事，职责清晰
- **好处**：
  - 可以流式更新进度
  - 可以持久化执行（暂停/恢复）
  - 调试清晰（可以检查每步的状态）

### 2. 状态是共享内存
- **原则**：存原始数据，不存格式化文本
- **好处**：
  - 不同节点可以用不同方式使用同一数据
  - 改提示词不需要改状态结构
  - 调试时看到的是真实数据

### 3. 节点是函数
- **输入**：状态
- **输出**：状态更新 + 路由决策（可选）
- **好处**：简单、可测试、可复用

### 4. 错误是流程的一部分
- **策略**：不同错误不同处理
- **好处**：系统更健壮，用户体验更好

### 5. 人工介入是一等公民
- **机制**：`interrupt()` 可以无限期暂停
- **好处**：支持复杂的人机协作流程

### 6. 图结构自然涌现
- **原则**：只定义必要连接，路由在节点内
- **好处**：控制流清晰、可追踪

---

## 深入思考：节点粒度的权衡

### 为什么不能把所有操作合并成一个节点？

**容错性考虑**：
- LangGraph 在节点边界创建检查点
- 如果节点很大，失败时需要重做很多工作
- 小节点 = 频繁检查点 = 失败时损失更小

**为什么选择当前的拆分**：
1. **外部服务隔离**：文档搜索、工单创建调用外部 API，单独节点可以独立配置重试
2. **中间状态可见**：分类结果可以单独检查，便于调试和监控
3. **不同失败模式**：LLM、数据库、邮件发送需要不同的重试策略
4. **可复用性**：小节点更容易测试和复用

**但也可以合并**：
- 可以把"读取邮件"和"分类意图"合并
- 代价：失去中间状态的可见性，失败时需要重做更多工作
- 对于大多数应用，分离的好处大于代价

### 性能考虑

**更多节点 ≠ 更慢**：
- LangGraph 默认异步持久化（后台写检查点）
- 执行不会等待检查点完成
- 所以频繁检查点对性能影响很小

**可以调整持久化模式**：
- `"exit"`：只在完成时检查点
- `"sync"`：同步写检查点（会阻塞，但更安全）

---

## 实践建议

### 1. 从简单开始
先实现核心流程，再逐步添加复杂功能（重试、缓存、人工介入等）

### 2. 状态设计要谨慎
- 只存必要的数据
- 保持原始格式
- 使用 TypedDict 提供类型提示

### 3. 节点职责要单一
- 一个节点只做一件事
- 如果节点太复杂，考虑拆分

### 4. 错误处理要分层
- 临时错误：自动重试
- 可恢复错误：给 LLM 更多上下文
- 需要人工：使用 interrupt
- 系统错误：立即失败并记录

### 5. 测试要分层
- 单元测试：测试单个节点
- 集成测试：测试整个流程
- 使用 mock 来模拟外部服务

---

## 延伸学习方向

1. **人机协作模式**：工具执行前审批、批量审批等
2. **子图（Subgraphs）**：复杂多步操作的封装
3. **流式处理**：实时显示进度给用户
4. **可观测性**：使用 LangSmith 进行调试和监控
5. **工具集成**：网页搜索、数据库查询、API 调用
6. **重试逻辑**：指数退避等高级策略

---

## 总结

LangGraph 的核心是**将业务流程映射为可执行的图结构**。通过：
- **节点**：离散的、可测试的操作单元
- **状态**：节点间共享的原始数据
- **路由**：节点内的决策逻辑
- **持久化**：支持暂停和恢复的执行

构建出既灵活又可靠的 AI Agent 系统。

**关键思维转变：
- 从"线性代码"到"图结构"
- 从"硬编码流程"到"动态路由"
- 从"失败即终止"到"错误是流程的一部分"
- 从"一次性执行"到"可中断恢复"
