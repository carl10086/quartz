
## 1-Intro

LLM 应用程序使用越来越复杂的抽象， 例如 `chains`, `agents with tools`, `advanced prompts` .
而 `langfuse` 中的 `Nested traces` 会帮助我们去理解 **What is happening?**  **The root cause of problems.**

完整上下文捕获：跟踪完整的执行流程，包括API调用、上下文、提示、并行性等
成本监控：跟踪整个应用程序的模型使用情况和成本
质量洞察：收集用户反馈并识别低质量输出
数据集创建：构建用于微调和测试的高质量数据集
根本原因分析：快速识别和调试复杂LLM应用程序中的问题

`Self-hosted` 安装 `langfuse`:

- 参考文章: [self-hosting](https://langfuse.com/self-hosting)


从页面就可以看出来能力.

- Trace: 链路追踪
- Session: 会话级别监控
- Dashboard: 首页
- Timeline: 性能监控
- Agent Graphs: 直接映射到 `LangGraph` 的图节点
- Users: 用户级别的监控


## 2-Tracing Features

### 2-1 Graph view

目前支持了 `langGraph` 这个框架的集成. 
跟 `Graph` 视图绑定在一起


### 2-2 Env

支持多个环境的隔离. 也就是一个平台, 同时支持 `dev` , `test` , `prod` 环境的逻辑隔离.

- 通过环境变量 `LANGFUSE_TRACING_ENVIRONMENT` 来实现
- 默认是 `default`
- 只能包含小写字母、数字、连字符和下划线

环境属性在Langfuse的所有事件中可用：
- 追踪（Traces）
- 观察（Observations）（跨度、事件、生成）
- 评分（Scores）
- 会话（Sessions）

```python
from langfuse.callback import CallbackHandler
 
# Either set the environment variable or the constructor parameter. The latter takes precedence.
os.environ["LANGFUSE_TRACING_ENVIRONMENT"] = "production"
handler = CallbackHandler(
  environment="production"
)
```

### 2-3  Log Levels

在Langfuse中，追踪(Traces)通常包含大量的观察(Observations)数据，这些数据记录了应用执行过程中的各种信息点。为了更有效地管理这些数据并突出重要信息，Langfuse提供了观察级别(level)属性，它允许开发者为不同的观察数据分配不同的重要性级别

```python
from langfuse.decorators import langfuse_context, observe
 
@observe()
def fn():
    langfuse_context.update_current_observation(
        level="WARNING",
        status_message="This is a warning"
    )
 
# outermost function becomes the trace, level and status message are only available on observations
@observe()
def main():
    fn()
 
main()
```

如果是 `langGraph`, 则是全自动的.

自动为执行流程中的各个步骤设置适当的级别(level)和状态消息( `statusMessage`)。这种自动化大大简化了开发工作，同时确保了追踪数据的一致性和完整性。

### 2-4 Masking

处理敏感数据.

```python
from langfuse.callback import CallbackHandler
 
def masking_function(data):
  if isinstance(data, str) and data.startswith("SECRET_"):
    return "REDACTED"
 
  return data
 
handler = CallbackHandler(
  mask=masking_function
)
```

掩码是一项允许精确控制发送到Langfuse服务器的追踪数据的功能。通过自定义掩码函数，您可以控制和净化被追踪并发送到服务器的数据。无论是出于合规原因还是为了保护用户隐私，掩码处理敏感数据都是负责任的应用程序开发中的关键步骤。它使您能够：

- 从追踪或观察的输入和输出中编辑敏感信息。
- 在传输前自定义事件的内容。
- 根据您的特定要求实现精细的数据过滤。

在我们的数据安全和隐私文档中了解更多关于Langfuse对存储数据的安全和隐私措施。

**工作原理**
1. 您定义一个自定义掩码函数并将其传递给Langfuse客户端构造函数。
2. 所有事件输入和输出都通过此函数处理。
3. 然后将掩码处理后的数据发送到Langfuse服务器。

有一个库，叫做 `llm-guard` . 可以专门用来做这个事情.


### 2-5 Metadata

在Langfuse中，元数据(metadata)是一个强大的功能，它允许开发者为追踪(Traces)和观察(Observations)添加额外的上下文信息。这些信息以灵活的JSON格式存储，可以包含任何对理解和分析LLM应用行为有帮助的数据.

```python
handler = CallbackHandler( metadata={"key":"value"})
```

### 2-6 Multi-Modality

**1. 全面的媒体类型支持**

Langfuse能够处理现代多模态LLM应用中使用的各种媒体类型：
• **文本**：传统的LLM输入和输出
• **图像**：用于视觉理解、图像生成等场景
• **音频**：语音输入、文本转语音输出等
• **其他附件**：PDF、JSON数据等应用特定的文件格式

**2. 智能媒体处理机制**

Langfuse SDK实现了媒体数据的自动处理流程：
• **检测和提取**：自动识别负载中的Base64编码数据URI
• **转换和上传**：将媒体内容上传到Langfuse的对象存储
• **引用关联**：在追踪中保存对上传媒体的引用，而非原始数据
• **访问控制**：确保媒体资源遵循与追踪数据相同的访问权限

这种机制既保证了数据的完整性，又优化了存储和传输效率。


### 2-7 releases & Versioning

```python
from langfuse.callback import CallbackHandler
 
handler = CallbackHandler(release="<release_tag>")
```


```python
from langfuse.callback import CallbackHandler
 
handler = CallbackHandler(version="1.0")
```

**1. 生产环境A/B测试**

版本跟踪功能使开发者能够在真实用户环境中安全地测试变更，并量化其影响：

• **模型切换评估**：比较不同LLM模型的成本效益和响应质量
• **提示工程优化**：测量提示变更对输出质量和延迟的影响
• **参数调整**：评估温度、最大令牌数等参数变化的效果

通过对比不同版本的性能指标，团队可以做出基于数据的决策，而非仅依赖主观判断。

**2. 性能变化分析**

当指标出现变化时，版本跟踪提供了强大的上下文信息来解释这些变化：

• **延迟增加排查**：确定延迟增加是由代码更改、模型变更还是外部因素导致
• **成本波动解释**：追踪成本变化与特定版本更新的关联
• **错误率分析**：确定哪些版本更新可能引入了新的错误模式


### 2-8 Sampling

采样率


### 2-9 Sessions(Chats, Threads, etc)

```python
handler = CallbackHandler(
  session_id="your-session-id"
)
```


**Sessions的工作原理**

Sessions功能基于一个简单而强大的机制：sessionId。当您为多个追踪分配相同的sessionId时，Langfuse自动将它们识别为同一会话的一部分。

关键特点：

• **一对多关系**：一个会话可以包含多个追踪
• **简单标识**：sessionId可以是任何字符串，无特定格式要求
• **灵活分组**：相同sessionId的所有追踪会自动分组显示


**1. SessionId选择策略**

有效的sessionId应该：
• **唯一**：能够唯一标识特定的用户会话
• **持久**：在整个会话中保持一致
• **有意义**：理想情况下包含有助于识别的信息

常见的sessionId模式包括：

• 用户ID结合时间戳：⁠user123-20240323T142512
• 会话或对话唯一标识符：⁠conversation-789abc
• 带前缀的UUID：⁠session-550e8400-e29b-41d4-a716-446655440000


### 2-10 tags

标签(Tags)是Langfuse提供的一种轻量级而灵活的分类机制，它允许开发者以一种简单直观的方式组织和筛选追踪数据。与结构化的元数据相比，标签提供了更加简洁的方式来标记和分类追踪，特别适合表示高级概念或类别。

```python
handler = CallbackHandler(
  tags=["tag-1", "tag-2"]
)
```


### 2-11 traceId

```python
from langfuse.callback import CallbackHandler
import uuid
 
predefined_run_id = str(uuid.uuid4())
 
langfuse_handler = CallbackHandler()
 
# Pass run_id to the chain invocation
chain.invoke(
    {"input": "test"},
    config={
        "callbacks": [langfuse_handler],
        "run_id": predefined_run_id,  # This becomes the trace ID
    },
)
```



> [!NOTE] Tips
> It is recommended to use your own domain specific IDs (e.g., messageId, traceId, correlationId) as it helps with downstream use cases like:

- [deeplinking](https://langfuse.com/docs/tracing-features/url) to the trace from your own ui or logs
- [evaluating](https://langfuse.com/docs/scores) and adding custom metrics to the trace
- [fetching](https://langfuse.com/docs/api) the trace from the API


### 2-12 users

```python
handler = CallbackHandler(
  user_id="user-id"
)
```

`llm` 的终端用户.


## 3-Develop

开发能力集成.

- Prompt Management
- Playground
- LLM Security
- Fine-tuning




## refer

- [docs](https://langfuse.com/docs/integrations/langchain/example-python-langgraph)