## 1. 架构概览

DeerFlow 的 Agent 中间件系统采用**责任链模式（Chain of Responsibility）**，每个中间件可以在 Agent 生命周期的不同阶段介入处理。这种设计实现了关注点分离和高度可扩展性。

### 1.1 核心抽象

```python
from langchain.agents.middleware import AgentMiddleware

class AgentMiddleware(Generic[StateSchema]):
    """
    中间件基类 - 类型安全的状态管理

    泛型参数 StateSchema 确保类型安全，与 ThreadState 兼容
    """
    state_schema: type[StateSchema]

    def before_agent(self, state, runtime):
        """Agent 执行前调用 - 可用于初始化资源"""
        pass

    def after_agent(self, state, runtime):
        """Agent 执行后调用 - 可用于清理或后处理"""
        pass

    def after_model(self, state, runtime):
        """模型推理后调用 - 可修改模型输出"""
        pass

    def wrap_tool_call(self, request, handler):
        """包装工具调用 - 可实现拦截和增强"""
        return handler(request)
```

---

## 2. 中间件执行链

### 2.1 完整执行流程

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent 执行生命周期                        │
└─────────────────────────────────────────────────────────────┘

用户请求
    ↓
[before_agent] 阶段（顺序执行）
    ├─ ThreadDataMiddleware    → 创建/获取线程目录
    ├─ UploadsMiddleware       → 处理上传文件列表
    ├─ SandboxMiddleware       → 获取沙盒实例
    └─ DanglingToolCallMiddleware → 清理残留工具调用
    ↓
模型推理（LLM 调用）
    ↓
[after_model] 阶段（顺序执行）
    ├─ SummarizationMiddleware → 上下文摘要（如需要）
    ├─ TodoListMiddleware      → 任务列表更新
    ├─ SubagentLimitMiddleware → 截断超额子代理调用
    └─ ...
    ↓
工具执行阶段
    ├─ wrap_tool_call 拦截
    │   ├─ ViewImageMiddleware    → 注入图片数据
    │   └─ ClarificationMiddleware → 拦截澄清请求
    ↓
[after_agent] 阶段（顺序执行）
    ├─ TitleMiddleware         → 生成对话标题
    ├─ MemoryMiddleware        → 队列记忆更新
    └─ ...
    ↓
返回响应
```

### 2.2 执行顺序的关键性

```python
# backend/src/agents/lead_agent/agent.py:198-206
# ThreadDataMiddleware must be before SandboxMiddleware to ensure thread_id is available
# UploadsMiddleware should be after ThreadDataMiddleware to access thread_id
# DanglingToolCallMiddleware patches missing ToolMessages before model sees the history
# SummarizationMiddleware should be early to reduce context before other processing
# TodoListMiddleware should be before ClarificationMiddleware to allow todo management
# TitleMiddleware generates title after first exchange
# MemoryMiddleware queues conversation for memory update (after TitleMiddleware)
# ViewImageMiddleware should be before ClarificationMiddleware to inject image details before LLM
# ClarificationMiddleware should be last to intercept clarification requests after model calls
```

**顺序依赖分析**:

| 中间件 A | 中间件 B | 依赖原因 |
|---------|---------|---------|
| ThreadDataMiddleware | SandboxMiddleware | 需要 thread_id 获取沙盒 |
| UploadsMiddleware | ThreadDataMiddleware | 需要 thread_id 访问上传目录 |
| TitleMiddleware | MemoryMiddleware | 标题生成后再更新记忆 |
| ViewImageMiddleware | ClarificationMiddleware | 图片数据注入后才能澄清 |
| *All* | ClarificationMiddleware | 必须是最后一个（拦截所有澄清） |

---

## 3. 核心中间件详解

### 3.1 ThreadDataMiddleware（线程数据管理）

```python
class ThreadDataMiddleware(AgentMiddleware):
    """
    为每个线程创建隔离的数据目录

    目录结构:
    backend/.deer-flow/threads/{thread_id}/user-data/
        ├── workspace/    # 临时工作文件
        ├── uploads/      # 用户上传文件
        └── outputs/      # 生成的输出文件

    延迟初始化策略:
    - lazy_init=True (默认): 仅计算路径，首次访问时创建目录
    - lazy_init=False: 在 before_agent 中立即创建目录
    """

    def before_agent(self, state, runtime):
        thread_id = runtime.context.get("thread_id")

        if self._lazy_init:
            paths = self._get_thread_paths(thread_id)  # 仅计算路径
        else:
            paths = self._create_thread_directories(thread_id)  # 立即创建

        return {"thread_data": paths}
```

**设计亮点**:
- **线程隔离**: 每个 thread_id 拥有独立的数据空间，防止跨会话污染
- **延迟加载**: 避免不必要的 IO 操作，提升性能
- **虚拟路径**: Agent 看到 `/mnt/user-data/*`，实际映射到物理路径

---

### 3.2 SandboxMiddleware（沙盒生命周期）

```python
class SandboxMiddleware(AgentMiddleware):
    """
    管理沙盒执行环境的获取和复用

    生命周期策略:
    - 同一线程内复用沙盒实例（避免重复创建开销）
    - 应用关闭时统一清理（通过 SandboxProvider.shutdown()）
    - 支持多种实现：本地文件系统、Docker、Kubernetes
    """

    def _acquire_sandbox(self, thread_id: str) -> str:
        provider = get_sandbox_provider()
        sandbox_id = provider.acquire(thread_id)
        return sandbox_id

    def before_agent(self, state, runtime):
        if self._lazy_init:
            return None  # 延迟到首次工具调用

        if "sandbox" not in state:
            sandbox_id = self._acquire_sandbox(thread_id)
            return {"sandbox": {"sandbox_id": sandbox_id}}
```

**关键决策**:
- **会话级复用**: 多轮对话共享同一沙盒，保持上下文
- **进程级清理**: 不在每次请求后释放，而是在应用关闭时统一清理
- **Provider 模式**: 支持本地、Docker、K8s 多种隔离级别

---

### 3.3 SubagentLimitMiddleware（并发控制）

```python
class SubagentLimitMiddleware(AgentMiddleware):
    """
    硬性限制单响应中的子代理调用数量

    策略:
    - 检测模型输出中的 tool_calls
    - 仅保留前 max_concurrent 个 task 调用
    - 超出部分直接丢弃（记录警告日志）

    为什么不用提示词限制?
    - 提示词是"软约束"，模型可能不遵守
    - 此中间件提供"硬约束"，确保系统稳定性
    """

    def _truncate_task_calls(self, state):
        tool_calls = getattr(last_msg, "tool_calls", [])

        # 统计 task 调用索引
        task_indices = [i for i, tc in enumerate(tool_calls)
                       if tc.get("name") == "task"]

        if len(task_indices) <= self.max_concurrent:
            return None

        # 截断超出限制的调用
        indices_to_drop = set(task_indices[self.max_concurrent:])
        truncated = [tc for i, tc in enumerate(tool_calls)
                    if i not in indices_to_drop]

        # 创建新的消息（相同 ID 触发替换）
        updated_msg = last_msg.model_copy(update={"tool_calls": truncated})
        return {"messages": [updated_msg]}

    def after_model(self, state, runtime):
        return self._truncate_task_calls(state)
```

**可靠性设计**:
- **防御式编程**: 假设模型可能犯错，提供硬约束兜底
- **范围限制**: `MIN_SUBAGENT_LIMIT=2`, `MAX_SUBAGENT_LIMIT=4`，防止配置错误
- **透明处理**: 记录警告日志，便于调试模型行为

---

### 3.4 MemoryMiddleware（记忆管理）

```python
class MemoryMiddleware(AgentMiddleware):
    """
    智能记忆队列管理 - 仅保留有价值的对话内容

    过滤策略:
    ✅ 保留: HumanMessage、最终的 AIMessage（无 tool_calls）
    ❌ 过滤: ToolMessage、AI 的 tool_calls、上传文件元数据

    防抖机制:
    - 30 秒延迟写入（可配置）
    - 同一线程的多次更新合并为一次
    - 后台线程异步执行 LLM 摘要
    """

    def after_agent(self, state, runtime):
        # 1. 获取线程 ID
        thread_id = runtime.context.get("thread_id")

        # 2. 过滤消息（移除临时标记）
        filtered = _filter_messages_for_memory(messages)

        # 3. 检查有效性（至少一对问答）
        user_msgs = [m for m in filtered if m.type == "human"]
        assistant_msgs = [m for m in filtered if m.type == "ai"]

        if not user_msgs or not assistant_msgs:
            return None

        # 4. 加入队列（异步处理）
        queue = get_memory_queue()
        queue.add(thread_id=thread_id, messages=filtered)
```

**消息过滤逻辑**:

```python
def _filter_messages_for_memory(messages):
    """精确过滤，仅保留核心对话内容"""

    # 使用正则移除上传文件标记（临时性内容）
    _UPLOAD_BLOCK_RE = re.compile(r"<uploaded_files>.*?</uploaded_files>", re.I)

    for msg in messages:
        if msg.type == "human":
            content = str(msg.content)
            if "<uploaded_files>" in content:
                # 仅移除标记，保留用户真实问题
                stripped = _UPLOAD_BLOCK_RE.sub("", content).strip()
                if not stripped:
                    skip_next_ai = True  # 跳过配对的 AI 响应
                    continue
                msg.content = stripped
            filtered.append(msg)

        elif msg.type == "ai":
            if not msg.tool_calls and not skip_next_ai:
                filtered.append(msg)
            skip_next_ai = False
```

---

### 3.5 TitleMiddleware（标题生成）

```python
class TitleMiddleware(AgentMiddleware):
    """
    自动生成对话标题 - 基于第一轮对话内容

    触发条件:
    1. 标题功能已启用
    2. 当前无标题
    3. 完成第一轮对话（1 用户消息 + 1 AI 响应）

    生成策略:
    - 使用轻量级模型（thinking_enabled=False）
    - 限制字符数（默认 60 字符）
    - 失败时回退到用户消息截断
    """

    def _should_generate_title(self, state):
        # 功能开关检查
        if not config.enabled:
            return False

        # 已有标题检查
        if state.get("title"):
            return False

        # 第一轮完成检查
        user_msgs = [m for m in messages if m.type == "human"]
        assistant_msgs = [m for m in messages if m.type == "ai"]
        return len(user_msgs) == 1 and len(assistant_msgs) >= 1

    async def _generate_title(self, state):
        # 使用轻量级模型节省成本
        model = create_chat_model(thinking_enabled=False)

        prompt = config.prompt_template.format(
            max_words=config.max_words,
            user_msg=user_msg[:500],      # 限制长度避免过长
            assistant_msg=assistant_msg[:500]
        )

        try:
            response = await model.ainvoke(prompt)
            title = response.content.strip()
            return title[:config.max_chars]  # 硬性截断
        except Exception:
            # 降级策略：使用用户消息前 N 字符
            return user_msg[:50] + "..."
```

---

### 3.6 ClarificationMiddleware（澄清拦截）

```python
class ClarificationMiddleware(AgentMiddleware):
    """
    拦截 ask_clarification 工具调用，中断执行流

    工作流程:
    1. 检测 ask_clarification 工具调用
    2. 提取问题、类型、上下文、选项
    3. 格式化带图标的友好消息
    4. 返回 Command(goto=END) 强制中断
    5. 前端检测到特殊消息后展示给用户
    """

    TYPE_ICONS = {
        "missing_info": "❓",
        "ambiguous_requirement": "🤔",
        "approach_choice": "🔀",
        "risk_confirmation": "⚠️",
        "suggestion": "💡",
    }

    def _format_clarification_message(self, args):
        icon = self.TYPE_ICONS.get(clarification_type, "❓")

        if context:
            message = f"{icon} {context}\n{question}"
        else:
            message = f"{icon} {question}"

        if options:
            for i, option in enumerate(options, 1):
                message += f"\n  {i}. {option}"

        return message

    def _handle_clarification(self, request):
        formatted = self._format_clarification_message(args)

        # 创建工具消息（前端特殊处理）
        tool_message = ToolMessage(
            content=formatted,
            tool_call_id=tool_call_id,
            name="ask_clarification",
        )

        # 强制中断执行流
        return Command(
            update={"messages": [tool_message]},
            goto=END,
        )
```

**交互设计亮点**:
- **视觉编码**: 不同类型的澄清使用不同图标，快速识别意图
- **强制中断**: 使用 `Command(goto=END)` 确保执行立即停止
- **前端协同**: 工具消息 name 为 "ask_clarification"，前端据此渲染交互界面

---

## 4. 中间件开发指南

### 4.1 创建自定义中间件

```python
from langchain.agents.middleware import AgentMiddleware
from langgraph.runtime import Runtime
from typing import override

class CustomMiddleware(AgentMiddleware[ThreadState]):
    """
    自定义中间件模板

    最佳实践:
    1. 明确指定 state_schema 确保类型安全
    2. 使用 @override 标记重写方法
    3. 返回 None 表示不修改状态
    4. 返回 dict 表示状态更新
    """

    state_schema = ThreadState

    def __init__(self, custom_param: str = "default"):
        super().__init__()
        self.custom_param = custom_param

    @override
    def before_agent(self, state: ThreadState, runtime: Runtime) -> dict | None:
        """Agent 执行前的预处理"""
        thread_id = runtime.context.get("thread_id")

        # 你的逻辑...

        return {"custom_key": "custom_value"}  # 或 None

    @override
    def after_model(self, state: ThreadState, runtime: Runtime) -> dict | None:
        """模型输出后的处理"""
        messages = state.get("messages", [])

        # 修改最后一条消息示例
        if messages:
            last_msg = messages[-1]
            # 处理逻辑...

        return None  # 不修改状态

    @override
    def wrap_tool_call(self, request, handler):
        """拦截工具调用"""
        if request.tool_call.get("name") == "target_tool":
            # 拦截逻辑
            return self._handle_special(request)

        # 默认执行
        return handler(request)
```

### 4.2 中间件性能优化

| 优化策略 | 适用场景 | 示例 |
|---------|---------|------|
| **延迟初始化** | 资源密集型操作 | `lazy_init=True` 避免不必要的 IO |
| **异步方法** | IO 密集型操作 | 使用 `aafter_model` 代替 `after_model` |
| **条件执行** | 非必要操作 | `_should_generate_title()` 前置检查 |
| **批量处理** | 高频更新 | `MemoryMiddleware` 使用队列合并更新 |
| **缓存结果** | 重复计算 | 中间件间共享计算结果 |

---

## 5. 调试与监控

### 5.1 中间件执行日志

```python
# 在中间件中添加日志
import logging

logger = logging.getLogger(__name__)

class DebugMiddleware(AgentMiddleware):
    def before_agent(self, state, runtime):
        logger.info(f"[BeforeAgent] Thread: {runtime.context.get('thread_id')}")
        logger.debug(f"[BeforeAgent] State keys: {state.keys()}")
        return None

    def after_agent(self, state, runtime):
        logger.info(f"[AfterAgent] Messages count: {len(state.get('messages', []))}")
        return None
```

### 5.2 执行时间统计

```python
import time

class TimingMiddleware(AgentMiddleware):
    def before_agent(self, state, runtime):
        runtime.context["_start_time"] = time.time()
        return None

    def after_agent(self, state, runtime):
        start = runtime.context.get("_start_time")
        if start:
            elapsed = time.time() - start
            logger.info(f"Agent execution time: {elapsed:.2f}s")
        return None
```

---

## 6. 相关文档

- [[deerflow_lead_agent_源码|Lead Agent 核心架构]]
- [[deerflow_thread_state|ThreadState 状态管理]]
- [[deerflow_sandbox_源码|Sandbox 执行系统]]

---

**源码路径**:
- `backend/src/agents/middlewares/`
- `backend/src/agents/lead_agent/agent.py`（中间件链配置）

**分析日期**: 2026-03-09
