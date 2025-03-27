


## 1-Introduction

```python
from typing_extensions import TypedDict

class State(TypedDict):
    graph_state: str
```

```python
def node_1(state):
    print("---Node 1---")
    return {"graph_state": state['graph_state'] +" I am"}

def node_2(state):
    print("---Node 2---")
    return {"graph_state": state['graph_state'] +" happy!"}

def node_3(state):
    print("---Node 3---")
    return {"graph_state": state['graph_state'] +" sad!"}
```


`LangGraph` 采用了函数式编程的范式: 

1. 不可变状态：
	- 在 LangGraph 中，节点函数不会直接修改传入的状态对象
	- 每个节点接收当前状态，然后返回一个新的状态字典，而不是修改原始状态
2. 纯函数：
	- 示例中的节点函数 node_1、node_2、node_3 都是纯函数
	- 它们仅依赖于输入参数（状态），并返回新的状态值，没有副作用
	- 相同的输入总是产生相同的输出
3. 状态转换而非状态修改：
	- 这里没有修改原始 state 对象，而是返回一个包含新 graph_state 值的新字典
4. 数据流:
	- 整个图的执行是数据流动的过程
	- 数据（状态）从一个节点流向下一个节点，每个节点产生新的状态
5. 声明式而非命令式:
	- 图的构建过程是声明式的，指定"什么"而不是"如何"
	- 我们声明节点和边缘的关系，而不是命令式地指定执行步骤


### 1-1 Chain

`DEMO` 中:

1. 使用 `ChatMessages` 作为图的状态 ;
2. 在图的 节点中使用聊天模型 ;
3. 将 `Tools` 绑定到聊天模型 ;
4. 在图 节点中执行 工具调用, `Tool Calls` ;



> [!NOTE] 1.Messages:
> 在 `LangChain` 中， 消息是捕获对话中不同角色的对象


- `HumanMessage`: 用户消息
- `AIMessage`: `AI` 模型生成的消息
- `SystemMessage`: 给模型的指令消息
- `ToolMessage`: 工具调用的消息

每个消息可以包含:
- `content`: 内容
- `name`: 可选的作者
- `response_metadata`: 可选的， 一个字典，用来存放元数据， 一般 `AiMessage` 中会用来说明 `Model Provider`

```python
from pprint import pprint
from langchain_core.messages import AIMessage, HumanMessage

messages = [AIMessage(content=f"So you said you were researching ocean mammals?", name="Model")]
messages.append(HumanMessage(content=f"Yes, that's right.",name="Lance"))
messages.append(AIMessage(content=f"Great, what would you like to learn about.", name="Model"))
messages.append(HumanMessage(content=f"I want to learn about the best place to see Orcas in the US.", name="Lance"))

for m in messages:
    m.pretty_print()
```



> [!NOTE] 2.Tools
> 工具可以让 模型和外部进行交互


```python
def multiply(a: int, b: int) -> int:
    """Multiply a and b.

    Args:
        a: first int
        b: second int
    """
    return a * b

llm_with_tools = llm.bind_tools([multiply])
```

可以查看某个 `llm` 的 `tool_calls`

```python
tool_call.tool_calls
```



> [!NOTE] 3.Reducers
> 默认情况下，节点返回的状态会覆盖旧状态。但对于消息列表，我们希望新消息被添加到现有列表中，而不是替换它


这个会覆盖掉

```python
from typing_extensions import TypedDict
from langchain_core.messages import AnyMessage

class MessagesState(TypedDict):
    messages: list[AnyMessage]
```


使用 reducer 

```python
from typing import Annotated
from langgraph.graph.message import add_messages

class MessagesState(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
```


### 1-2 Router

tool_condition 就是一种 `router`

```python
from IPython.display import Image, display
from langgraph.graph import StateGraph, START, END
from langgraph.graph import MessagesState
from langgraph.prebuilt import ToolNode
from langgraph.prebuilt import tools_condition

# Node
def tool_calling_llm(state: MessagesState):
    return {"messages": [llm_with_tools.invoke(state["messages"])]}

# Build graph
builder = StateGraph(MessagesState)
builder.add_node("tool_calling_llm", tool_calling_llm)
builder.add_node("tools", ToolNode([multiply]))
builder.add_edge(START, "tool_calling_llm")
builder.add_conditional_edges(
    "tool_calling_llm",
    # If the latest message (result) from assistant is a tool call -> tools_condition routes to tools
    # If the latest message (result) from assistant is a not a tool call -> tools_condition routes to END
    tools_condition,
)
builder.add_edge("tools", END)
graph = builder.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))
```

可以更强大一些.

```python
def multiply(a: int, b: int) -> int:
    """Multiply a and b.

    Args:
        a: first int
        b: second int
    """
    return a * b

# This will be a tool
def add(a: int, b: int) -> int:
    """Adds a and b.

    Args:
        a: first int
        b: second int
    """
    return a + b

def divide(a: int, b: int) -> float:
    """Divide a and b.

    Args:
        a: first int
        b: second int
    """
    return a / b

tools = [add, multiply, divide]
llm = ChatOpenAI(model="gpt-4o")
```


```python
from langgraph.graph import MessagesState
from langchain_core.messages import HumanMessage, SystemMessage

# System message
sys_msg = SystemMessage(content="You are a helpful assistant tasked with performing arithmetic on a set of inputs.")

# Node
def assistant(state: MessagesState):
   return {"messages": [llm_with_tools.invoke([sys_msg] + state["messages"])]}
```

```python
from langgraph.graph import START, StateGraph
from langgraph.prebuilt import tools_condition
from langgraph.prebuilt import ToolNode
from IPython.display import Image, display

# Graph
builder = StateGraph(MessagesState)

# Define nodes: these do the work
builder.add_node("assistant", assistant)
builder.add_node("tools", ToolNode(tools))

# Define edges: these determine how the control flow moves
builder.add_edge(START, "assistant")
builder.add_conditional_edges(
    "assistant",
    # If the latest message (result) from assistant is a tool call -> tools_condition routes to tools
    # If the latest message (result) from assistant is a not a tool call -> tools_condition routes to END
    tools_condition,
)
builder.add_edge("tools", "assistant")
react_graph = builder.compile()

# Show
display(Image(react_graph.get_graph(xray=True).draw_mermaid_png()))
```


## 2-State And Memory

### 2-1 Multiple Schema

通常来说， 一个 `graph` 中所有的 `nodes` 都通过一个单一的 `schema` 进行通信.

但是有一些特殊的场景下， 刻意希望灵活一些.

1. 内部的部分 `Node` 需要传递不需要出现在 `Graph` 这个层面的 `Input` 和 `Output`.
2. 我们希望为 `Graph` 使用不同的 `Input/Output`, 比如说 `Output` 中仅仅只包含了一个相关的键 .

**1)-例子1  `node_2` 需要一个私有的状态**


```python
from typing_extensions import TypedDict
from IPython.display import Image, display
from langgraph.graph import StateGraph, START, END

class OverallState(TypedDict):
    foo: int

class PrivateState(TypedDict):
    baz: int

def node_1(state: OverallState) -> PrivateState:
    print("---Node 1---")
    return {"baz": state['foo'] + 1}

def node_2(state: PrivateState) -> OverallState:
    print("---Node 2---")
    return {"foo": state['baz'] + 1}

# Build graph
builder = StateGraph(OverallState)
builder.add_node("node_1", node_1)
builder.add_node("node_2", node_2)

# Logic
builder.add_edge(START, "node_1")
builder.add_edge("node_1", "node_2")
builder.add_edge("node_2", END)

# Add
graph = builder.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))
```

**2)-例子2: Input|output 需要不一样.**

```python
class InputState(TypedDict):
    question: str

class OutputState(TypedDict):
    answer: str

class OverallState(TypedDict):
    question: str
    answer: str
    notes: str

def thinking_node(state: InputState):
    return {"answer": "bye", "notes": "... his is name is Lance"}

def answer_node(state: OverallState) -> OutputState:
    return {"answer": "bye Lance"}

graph = StateGraph(OverallState, input=InputState, output=OutputState)
graph.add_node("answer_node", answer_node)
graph.add_node("thinking_node", thinking_node)
graph.add_edge(START, "thinking_node")
graph.add_edge("thinking_node", "answer_node")
graph.add_edge("answer_node", END)

graph = graph.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))

graph.invoke({"question":"hi"})
```

- 其中 `InputState` : 仅仅包含了 `question` 字段
- 其中 `OutputState` : 仅仅包含了 `answer` 字段
- `OverallState` 则包含了所有. 

创建图的时候， 可以使用 `type hint` 指定这些东西.

```python
graph = StateGraph(OverallState, input=InputState, output=OutputState)
```


### 2-2 Filtering and trimming messages

随着对话的进行， 消息的历史会不断地增长, 随着对话的进行, 消息历史会不断的增长, 这可能会导致2个主要的问题.

- `token` 的使用量增加
- 响应的延迟变高

为了解决这2个问题, `langGraph` 直接提供了几种管理消息历史的技术:

1. 消息过滤: `Message Filtering`
2. 消息修剪: `Message Trimming`


#### 2-2-1 Message Filtering

**1)-例子: 直接加个 node 用来消息修剪**


```python
from langchain_core.messages import RemoveMessage

# Nodes
def filter_messages(state: MessagesState):
    # Delete all but the 2 most recent messages
    delete_messages = [RemoveMessage(id=m.id) for m in state["messages"][:-2]]
    return {"messages": delete_messages}

def chat_model_node(state: MessagesState):    
    return {"messages": [llm.invoke(state["messages"])]}

# Build graph
builder = StateGraph(MessagesState)
builder.add_node("filter", filter_messages)
builder.add_node("chat_model", chat_model_node)
builder.add_edge(START, "filter")
builder.add_edge("filter", "chat_model")
builder.add_edge("chat_model", END)
graph = builder.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))
```

- 这个代码中仅仅保留了最新的2条数据
- 核心是使用了 `RemoveMessage` 和 `add_messages` `reducer`

通过如下代码可以测试

```python
# Message list with a preamble
messages = [AIMessage("Hi.", name="Bot", id="1")]
messages.append(HumanMessage("Hi.", name="Lance", id="2"))
messages.append(AIMessage("So you said you were researching ocean mammals?", name="Bot", id="3"))
messages.append(HumanMessage("Yes, I know about whales. But what others should I learn about?", name="Lance", id="4"))

# Invoke
output = graph.invoke({'messages': messages})
for m in output['messages']:
    m.pretty_print()
```


**2)-例子2: 传递给大模型的时候仅仅给最后1条**

```python
# Node
def chat_model_node(state: MessagesState):
    return {"messages": [llm.invoke(state["messages"][-1:])]}

# Build graph
builder = StateGraph(MessagesState)
builder.add_node("chat_model", chat_model_node)
builder.add_edge(START, "chat_model")
builder.add_edge("chat_model", END)
graph = builder.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))
```

仅仅给了最后1条, *这样还保存了完整的消息历史*， 也没有修改图的状态


#### 2-2-2 Message Trims

```python
from langchain_core.messages import trim_messages

# Node
def chat_model_node(state: MessagesState):
    messages = trim_messages(
            state["messages"],
            max_tokens=100,
            strategy="last",
            token_counter=ChatOpenAI(model="gpt-4o"),
            allow_partial=False,
        )
    return {"messages": [llm.invoke(messages)]}

# Build graph
builder = StateGraph(MessagesState)
builder.add_node("chat_model", chat_model_node)
builder.add_edge(START, "chat_model")
builder.add_edge("chat_model", END)
graph = builder.compile()

# View
display(Image(graph.get_graph().draw_mermaid_png()))****
```


- `max_tokens`: 允许的最大 `tokens` 数目 ;
- `strategy` : 采取 `last` 策略, 表示从最后1条消息开始保留, 直到达到 `token` 的限制 ;
- `token_counter`: 用于计算 `token` 数量的工具 ;
- `allow_partial`: 是否允许部分消息, 设为 `False` 表示已经包含了完整的消息列表 ;


可以直接用下面的代码进行测试:

```python
# Example of trimming messages
trim_messages(
            messages,
            max_tokens=100,
            strategy="last",
            token_counter=ChatOpenAI(model="gpt-4o"),
            allow_partial=False
        )
```


## 2-3 Chatbot with message summarization

之前的方案中, 在处理长对话的时候会面临2个主要问题:

1. 随着对话长度增加，向LLM发送的上下文变得越来越长，导致Token使用量增加和延迟增加
2. 没有有效的手段去 保留长期对话的 上下文信息

message summarization 不同于上面的 `filtering` 或者说 `triming`, 则是另外一个手段来保留 上下文信息.

但是成本更高. 后期可以离线设计.
1. 使用 `LLM` 产生对话的消息摘要, (`running summary`) ;
2. 保留压缩版的完整对话, 而不是简单的删除历史消息 ;
3. 新消息来的时候会扩展现有的摘要 ;


**1)-增加摘要字段**

```python
from langgraph.graph import MessagesState
class State(MessagesState):
    summary: str
```


**2)-关键节点: call_model**

```python
from langchain_core.messages import SystemMessage, HumanMessage, RemoveMessage

# Define the logic to call the model
def call_model(state: State):
    
    # Get summary if it exists
    summary = state.get("summary", "")

    # If there is summary, then we add it
    if summary:
        
        # Add summary to system message
        system_message = f"Summary of conversation earlier: {summary}"

        # Append summary to any newer messages
        messages = [SystemMessage(content=system_message)] + state["messages"]
    
    else:
        messages = state["messages"]
    
    response = model.invoke(messages)
    return {"messages": response}
```

- 检查是否存在摘要
- 如果存在摘要， 将其添加到系统消息中
- 调用 LLM 生成回复


**3)-关键节点: summarize_conversation** 

```python
def summarize_conversation(state: State):
    
    # First, we get any existing summary
    summary = state.get("summary", "")

    # Create our summarization prompt 
    if summary:
        
        # A summary already exists
        summary_message = (
            f"This is summary of the conversation to date: {summary}\n\n"
            "Extend the summary by taking into account the new messages above:"
        )
        
    else:
        summary_message = "Create a summary of the conversation above:"

    # Add prompt to our history
    messages = state["messages"] + [HumanMessage(content=summary_message)]
    response = model.invoke(messages)
    
    # Delete all but the 2 most recent messages
    delete_messages = [RemoveMessage(id=m.id) for m in state["messages"][:-2]]
    return {"summary": response.content, "messages": delete_messages}
```

- 检查现在的摘要
- 创建适当的摘要提示，要么扩展现在的摘要, 要么创建新的摘要
- 删除除了最近2条消息 外的所有消息, 只保留摘要和最新的消息


**4)-关键节点: should_continue**

```python
from langgraph.graph import END
# Determine whether to end or summarize the conversation
def should_continue(state: State):
    
    """Return the next node to execute."""
    
    messages = state["messages"]
    
    # If there are more than six messages, then we summarize the conversation
    if len(messages) > 6:
        return "summarize_conversation"
    
    # Otherwise we can just end
    return END
```

- 决定是继续对话还是进行摘要
- 消息超过6条的时候触发摘要功能. 



## 3-UX and Human-in-the-loop.


### 3-1 Streaming

pass

### 3-2 Breakpoints

通过 interupt 可以中断. graph 


### 3-3 Editing State and human Feedback


```python
   # 获取当前状态
   state = graph.get_state(thread)
   
   # 访问最后一条消息
   last_message = current_state['values']['messages'][-1]
   
   # 编辑消息内容
   last_message['content'] = "新的消息内容"
   
   # 更新状态
   await client.threads.update_state(thread['thread_id'], {"messages": last_message})
```


- 如果提供消息的 id，则会覆盖具有相同 ID 的现有消息
- 如果不提供 ID，则会添加新消息到列表中, 依旧会触发 `add_messages`


### 3-4 TimeTravel


时间旅行功能主要包含三个核心能力：


**1)-浏览历史状态 (Browsing History)**

LangGraph会保存代理执行过程中的所有状态。开发者可以使用get_state方法查看当前状态，或使用get_state_history方法获取所有历史状态。每个状态都有一个唯一的checkpoint ID标识，记录了当时的完整信息，包括：
- 状态值(values)：例如消息历史
- 下一步执行节点(next)
- 配置信息(config)：包含thread_id和checkpoint_id
- 元数据(metadata)：包含执行步骤等信息

**2)-重放 (Replaying)**

重放功能允许从任何历史状态重新执行代理流程。通过指定checkpoint_id，开发者可以让代理从特定的历史点重新开始执行。这对于重现问题或理解代理的决策过程非常有用。

重放时，系统会认识到这个checkpoint已经被执行过，它会重新执行从这个点开始的所有流程。

例如，如果你有一个状态包含了用户输入"Multiply 2 and 3"，你可以从这个状态重新执行代理，得到相同的结果。

**3)-分叉 (Forking)**

分叉是时间旅行最强大的特性之一。它允许从任何历史状态创建一个新的执行路径，但可以修改该状态的内容。

例如，你可以从一个包含"Multiply 2 and 3"输入的状态分叉出来，将输入修改为"Multiply 5 and 3"，然后让代理从这个修改后的状态继续执行。这样，你就创建了一个全新的执行路径，但保留了原始状态的其他信息（如下一步要执行哪个节点等）。

分叉时，会创建一个新的checkpoint_id，系统认识到这是一个全新的状态，会从头执行而不是仅重放。

**4)-时间旅行的应用场景**

时间旅行功能在以下场景中特别有用：

1. 调试：当代理出现问题时，可以回到特定状态重新执行，或尝试不同的输入
2. 测试：通过从同一起点创建多个分支，测试不同输入对代理行为的影响
3. 人机协作：允许人类干预代理流程，修改状态后继续执行
4. 优化：分析代理在不同状态下的表现，找出可以改进的地方


