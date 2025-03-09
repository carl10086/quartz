
## 1-Intro


> [!NOTE] Agent vs workflows
> Agent 靠 agent 动态决定 `next action` , 而 `workflow` 则是定死的


```mermaid
graph TD
    subgraph "Workflow (工作流程)"
        A[输入] --> B[预定义步骤1]
        B --> C[预定义步骤2]
        C --> D[预定义步骤3]
        D --> E[输出]
    end

    subgraph "Agent (智能代理)"
        F[输入] --> G[LLM决策中心]
        G -->|决定使用工具1| H[工具1]
        G -->|决定使用工具2| I[工具2]
        G -->|决定使用工具3| J[工具3]
        H --> G
        I --> G
        J --> G
        G --> K[输出]
    end
```


LLM 拥有 [augmentations](https://www.anthropic.com/engineering/building-effective-agents) , 通过下面工具增强 `Agents` 和 `workflows` 的能力.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20250309151525.png)

例如通过如下的代码:

```python
# Schema for structured output
from pydantic import BaseModel, Field

class SearchQuery(BaseModel):
    search_query: str = Field(None, description="Query that is optimized web search.")
    justification: str = Field(
        None, description="Why this query is relevant to the user's request."
    )


# Augment the LLM with schema for structured output
structured_llm = llm.with_structured_output(SearchQuery)

# Invoke the augmented LLM
output = structured_llm.invoke("How does Calcium CT score relate to high cholesterol?")

# Define a tool
def multiply(a: int, b: int) -> int:
    return a * b

# Augment the LLM with tools
llm_with_tools = llm.bind_tools([multiply])

# Invoke the LLM with input that triggers the tool call
msg = llm_with_tools.invoke("What is 2 times 3?")

# Get the tool call
msg.tool_calls
```


## 2-Prompt chaining

把一个问题拆解的基本 `demo` , 其中每个 `node` 基于前面的 `output` 进行下一步

```python
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END
from IPython.display import Image, display


# Graph state
class State(TypedDict):
    topic: str
    joke: str
    improved_joke: str
    final_joke: str


# Nodes
def generate_joke(state: State):
    """First LLM call to generate initial joke"""

    msg = llm.invoke(f"Write a short joke about {state['topic']}")
    return {"joke": msg.content}


def check_punchline(state: State):
    """Gate function to check if the joke has a punchline"""

    # Simple check - does the joke contain "?" or "!"
    if "?" in state["joke"] or "!" in state["joke"]:
        return "Fail"
    return "Pass"


def improve_joke(state: State):
    """Second LLM call to improve the joke"""

    msg = llm.invoke(f"Make this joke funnier by adding wordplay: {state['joke']}")
    return {"improved_joke": msg.content}


def polish_joke(state: State):
    """Third LLM call for final polish"""

    msg = llm.invoke(f"Add a surprising twist to this joke: {state['improved_joke']}")
    return {"final_joke": msg.content}


# Build workflow
workflow = StateGraph(State)

# Add nodes
workflow.add_node("generate_joke", generate_joke)
workflow.add_node("improve_joke", improve_joke)
workflow.add_node("polish_joke", polish_joke)

# Add edges to connect nodes
workflow.add_edge(START, "generate_joke")
workflow.add_conditional_edges(
    "generate_joke", check_punchline, {"Fail": "improve_joke", "Pass": END}
)
workflow.add_edge("improve_joke", "polish_joke")
workflow.add_edge("polish_joke", END)

# Compile
chain = workflow.compile()

# Show workflow
display(Image(chain.get_graph().draw_mermaid_png()))

# Invoke
state = chain.invoke({"topic": "cats"})
print("Initial joke:")
print(state["joke"])
print("\n--- --- ---\n")
if "improved_joke" in state:
    print("Improved joke:")
    print(state["improved_joke"])
    print("\n--- --- ---\n")

    print("Final joke:")
    print(state["final_joke"])
else:
    print("Joke failed quality gate - no punchline detected!")
```

```mermaid
graph TD
    START --> generate_joke
    generate_joke --> check_punchline{检查笑点}
    check_punchline -->|Pass| END
    check_punchline -->|Fail| improve_joke
    improve_joke --> polish_joke
    polish_joke --> END
```

基于 `state` 在不同的 `node` 之间传递.


## 3-Parallelization

```mermaid
graph TD
    START --> call_llm_1["LLM调用1<br>(生成笑话)"]
    START --> call_llm_2["LLM调用2<br>(生成故事)"]
    START --> call_llm_3["LLM调用3<br>(生成诗歌)"]
    call_llm_1 --> aggregator["聚合器<br>(合并结果)"]
    call_llm_2 --> aggregator
    call_llm_3 --> aggregator
    aggregator --> END
```

```python
# Graph state
class State(TypedDict):
    topic: str
    joke: str
    story: str
    poem: str
    combined_output: str


# Nodes
def call_llm_1(state: State):
    """First LLM call to generate initial joke"""

    msg = llm.invoke(f"Write a joke about {state['topic']}")
    return {"joke": msg.content}


def call_llm_2(state: State):
    """Second LLM call to generate story"""

    msg = llm.invoke(f"Write a story about {state['topic']}")
    return {"story": msg.content}


def call_llm_3(state: State):
    """Third LLM call to generate poem"""

    msg = llm.invoke(f"Write a poem about {state['topic']}")
    return {"poem": msg.content}


def aggregator(state: State):
    """Combine the joke and story into a single output"""

    combined = f"Here's a story, joke, and poem about {state['topic']}!\n\n"
    combined += f"STORY:\n{state['story']}\n\n"
    combined += f"JOKE:\n{state['joke']}\n\n"
    combined += f"POEM:\n{state['poem']}"
    return {"combined_output": combined}


# Build workflow
parallel_builder = StateGraph(State)

# Add nodes
parallel_builder.add_node("call_llm_1", call_llm_1)
parallel_builder.add_node("call_llm_2", call_llm_2)
parallel_builder.add_node("call_llm_3", call_llm_3)
parallel_builder.add_node("aggregator", aggregator)

# Add edges to connect nodes
parallel_builder.add_edge(START, "call_llm_1")
parallel_builder.add_edge(START, "call_llm_2")
parallel_builder.add_edge(START, "call_llm_3")
parallel_builder.add_edge("call_llm_1", "aggregator")
parallel_builder.add_edge("call_llm_2", "aggregator")
parallel_builder.add_edge("call_llm_3", "aggregator")
parallel_builder.add_edge("aggregator", END)
parallel_workflow = parallel_builder.compile()

# Show workflow
display(Image(parallel_workflow.get_graph().draw_mermaid_png()))

# Invoke
state = parallel_workflow.invoke({"topic": "cats"})
print(state["combined_output"])
```


通过和条件分支配合可以实现更复杂的逻辑. 默认情况下 `aggregator` 会等待所有条件都满足了才会执行 `NEXT` .


## 4-Router

```python
from typing_extensions import Literal
from langchain_core.messages import HumanMessage, SystemMessage


# Schema for structured output to use as routing logic
class Route(BaseModel):
    step: Literal["poem", "story", "joke"] = Field(
        None, description="The next step in the routing process"
    )


# Augment the LLM with schema for structured output
router = llm.with_structured_output(Route)


# State
class State(TypedDict):
    input: str
    decision: str
    output: str


# Nodes
def llm_call_1(state: State):
    """Write a story"""

    result = llm.invoke(state["input"])
    return {"output": result.content}


def llm_call_2(state: State):
    """Write a joke"""

    result = llm.invoke(state["input"])
    return {"output": result.content}


def llm_call_3(state: State):
    """Write a poem"""

    result = llm.invoke(state["input"])
    return {"output": result.content}


def llm_call_router(state: State):
    """Route the input to the appropriate node"""

    # Run the augmented LLM with structured output to serve as routing logic
    decision = router.invoke(
        [
            SystemMessage(
                content="Route the input to story, joke, or poem based on the user's request."
            ),
            HumanMessage(content=state["input"]),
        ]
    )

    return {"decision": decision.step}


# Conditional edge function to route to the appropriate node
def route_decision(state: State):
    # Return the node name you want to visit next
    if state["decision"] == "story":
        return "llm_call_1"
    elif state["decision"] == "joke":
        return "llm_call_2"
    elif state["decision"] == "poem":
        return "llm_call_3"


# Build workflow
router_builder = StateGraph(State)

# Add nodes
router_builder.add_node("llm_call_1", llm_call_1)
router_builder.add_node("llm_call_2", llm_call_2)
router_builder.add_node("llm_call_3", llm_call_3)
router_builder.add_node("llm_call_router", llm_call_router)

# Add edges to connect nodes
router_builder.add_edge(START, "llm_call_router")
router_builder.add_conditional_edges(
    "llm_call_router",
    route_decision,
    {  # Name returned by route_decision : Name of next node to visit
        "llm_call_1": "llm_call_1",
        "llm_call_2": "llm_call_2",
        "llm_call_3": "llm_call_3",
    },
)
router_builder.add_edge("llm_call_1", END)
router_builder.add_edge("llm_call_2", END)
router_builder.add_edge("llm_call_3", END)

# Compile workflow
router_workflow = router_builder.compile()

# Show the workflow
display(Image(router_workflow.get_graph().draw_mermaid_png()))

# Invoke
state = router_workflow.invoke({"input": "Write me a joke about cats"})
print(state["output"])
```

`Routing`  是 `Workflow` 中的一种设计模式， 通过分类输入并且导向专门的处理路径, 解决了 所谓的 *单一提示困境*.

```mermaid
graph TD
    A[通用提示/模型] -->|处理所有输入| B[性能不均衡]
    
    C[输入] --> D[路由器]
    D -->|类型A| E[专门处理A<br>优化提示]
    D -->|类型B| F[专门处理B<br>优化提示]
    D -->|类型C| G[专门处理C<br>优化提示]
    E --> H[高质量输出]
    F --> H
    G --> H
```


而分类机制的选择，则可以是多种方式:

1. `LLM` 分类: 利用 `LLM` 的理解能力来进行分类
	- 优势: 处理模糊的边界， 理解复杂的意图 ;
	- 适用: 类别定义不严格, 需要理解上下文 ;
2. 传统分类算法: 使用传统的机器分类算法
3. 基于 规则的基础分类: `embedding` 召回之类的 ;


## 5-Orchestrator Worker

```mermaid
graph TD
    A[编排器 Orchestrator] --> B[分析任务]
    B --> C[动态分解为子任务]
    C --> D[分配给工作者]
    D --> E[工作者1]
    D --> F[工作者2]
    D --> G[工作者n]
    E --> H[收集结果]
    F --> H
    G --> H
    H --> I[合成最终输出]
```
```python
from langgraph.constants import Send


# Graph state
class State(TypedDict):
    topic: str  # Report topic
    sections: list[Section]  # List of report sections
    completed_sections: Annotated[
        list, operator.add
    ]  # All workers write to this key in parallel
    final_report: str  # Final report


# Worker state
class WorkerState(TypedDict):
    section: Section
    completed_sections: Annotated[list, operator.add]


# Nodes
def orchestrator(state: State):
    """Orchestrator that generates a plan for the report"""

    # Generate queries
    report_sections = planner.invoke(
        [
            SystemMessage(content="Generate a plan for the report."),
            HumanMessage(content=f"Here is the report topic: {state['topic']}"),
        ]
    )

    return {"sections": report_sections.sections}


def llm_call(state: WorkerState):
    """Worker writes a section of the report"""

    # Generate section
    section = llm.invoke(
        [
            SystemMessage(
                content="Write a report section following the provided name and description. Include no preamble for each section. Use markdown formatting."
            ),
            HumanMessage(
                content=f"Here is the section name: {state['section'].name} and description: {state['section'].description}"
            ),
        ]
    )

    # Write the updated section to completed sections
    return {"completed_sections": [section.content]}


def synthesizer(state: State):
    """Synthesize full report from sections"""

    # List of completed sections
    completed_sections = state["completed_sections"]

    # Format completed section to str to use as context for final sections
    completed_report_sections = "\n\n---\n\n".join(completed_sections)

    return {"final_report": completed_report_sections}


# Conditional edge function to create llm_call workers that each write a section of the report
def assign_workers(state: State):
    """Assign a worker to each section in the plan"""

    # Kick off section writing in parallel via Send() API
    return [Send("llm_call", {"section": s}) for s in state["sections"]]


# Build workflow
orchestrator_worker_builder = StateGraph(State)

# Add the nodes
orchestrator_worker_builder.add_node("orchestrator", orchestrator)
orchestrator_worker_builder.add_node("llm_call", llm_call)
orchestrator_worker_builder.add_node("synthesizer", synthesizer)

# Add edges to connect nodes
orchestrator_worker_builder.add_edge(START, "orchestrator")
orchestrator_worker_builder.add_conditional_edges(
    "orchestrator", assign_workers, ["llm_call"]
)
orchestrator_worker_builder.add_edge("llm_call", "synthesizer")
orchestrator_worker_builder.add_edge("synthesizer", END)

# Compile the workflow
orchestrator_worker = orchestrator_worker_builder.compile()

# Show the workflow
display(Image(orchestrator_worker.get_graph().draw_mermaid_png()))

# Invoke
state = orchestrator_worker.invoke({"topic": "Create a report on LLM scaling laws"})

from IPython.display import Markdown
Markdown(state["final_report"])
```

```mermaid
sequenceDiagram
    participant User as 用户
    participant O as 编排器(Orchestrator)
    participant W1 as 工作者1(医疗诊断)
    participant W2 as 工作者2(药物研发)
    participant W3 as 工作者3(远程医疗)
    participant S as 合成器(Synthesizer)
    
    User->>O: 主题:"AI在医疗领域的应用"
    Note over O: 分析主题,制定报告结构
    O->>O: 规划报告结构(3个部分)
    O-->>W1: Send("医疗诊断部分")
    O-->>W2: Send("药物研发部分")
    O-->>W3: Send("远程医疗部分")
    Note over W1,W3: 并行工作
    W1->>W1: 撰写医疗诊断相关内容
    W2->>W2: 撰写药物研发相关内容
    W3->>W3: 撰写远程医疗相关内容
    W1-->>S: 添加到completed_sections
    W2-->>S: 添加到completed_sections
    W3-->>S: 添加到completed_sections
    S->>S: 合并所有部分
    S-->>User: 返回完整报告
```

核心是2个函数: `add_conditional_edges` 和 `Send` `Api` .

```python
orchestrator_worker_builder.add_conditional_edges(
    "orchestrator", assign_workers, ["llm_call"]
)
```

- 参数1: `orchestrator` 作用是字符串, 指定源节点的名称 ;
- 参数2: `assign_workers` 指定条件函数, 这个函数会决定如何执行流, 返回值必须是一个 `Send` 指令对象 ;
- 参数3: 字符串列表, 就是可能的目标节点集合.

所以总结起来完整的含义就是:

- 这行代码的完整含义是：当"orchestrator"节点执行完成后，调用⁠assign_workers函数，该函数会返回一系列⁠Send指令，每个指令都会创建一个到"llm_call"节点的边，并且每个边可以携带不同的参数。


`Send` 类详解.

```python
Send("llm_call", {"section": s})
```

- 参数1: `llm_call` 字符串
	- 作用: 指定目标节点的名称 ;
	- 含义: 表示将要执行流 路由到名为 `llm_call` 的节点 ;
	- 约束: 必须是 `add_conditional_edges` 第三个参数列表中的一个节点 ;
- 参数2: `{"section": s}`
	- 传递给目标节点的参数
	- 这个字典会被合并到目标节点的状态中.


## 6-Evaluator-optimizer

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/202503100027699.png)

```python
from langgraph.graph import MessagesState
from langchain_core.messages import SystemMessage, HumanMessage, ToolMessage


# Nodes
def llm_call(state: MessagesState):
    """LLM decides whether to call a tool or not"""

    return {
        "messages": [
            llm_with_tools.invoke(
                [
                    SystemMessage(
                        content="You are a helpful assistant tasked with performing arithmetic on a set of inputs."
                    )
                ]
                + state["messages"]
            )
        ]
    }


def tool_node(state: dict):
    """Performs the tool call"""

    result = []
    for tool_call in state["messages"][-1].tool_calls:
        tool = tools_by_name[tool_call["name"]]
        observation = tool.invoke(tool_call["args"])
        result.append(ToolMessage(content=observation, tool_call_id=tool_call["id"]))
    return {"messages": result}


# Conditional edge function to route to the tool node or end based upon whether the LLM made a tool call
def should_continue(state: MessagesState) -> Literal["environment", END]:
    """Decide if we should continue the loop or stop based upon whether the LLM made a tool call"""

    messages = state["messages"]
    last_message = messages[-1]
    # If the LLM makes a tool call, then perform an action
    if last_message.tool_calls:
        return "Action"
    # Otherwise, we stop (reply to the user)
    return END


# Build workflow
agent_builder = StateGraph(MessagesState)

# Add nodes
agent_builder.add_node("llm_call", llm_call)
agent_builder.add_node("environment", tool_node)

# Add edges to connect nodes
agent_builder.add_edge(START, "llm_call")
agent_builder.add_conditional_edges(
    "llm_call",
    should_continue,
    {
        # Name returned by should_continue : Name of next node to visit
        "Action": "environment",
        END: END,
    },
)
agent_builder.add_edge("environment", "llm_call")

# Compile the agent
agent = agent_builder.compile()

# Show the agent
display(Image(agent.get_graph(xray=True).draw_mermaid_png()))

# Invoke
messages = [HumanMessage(content="Add 3 and 4.")]
messages = agent.invoke({"messages": messages})
for m in messages["messages"]:
    m.pretty_print()
```

```mermaid
graph TD
    A[开始] --> B[生成器LLM]
    B --> |生成内容| C[评估器LLM]
    C --> D{评估结果}
    D --> |接受| E[结束]
    D --> |拒绝+反馈| B
    B --> |改进内容| C
```

## 7-Agent

代理通常被实现为 `lLM` 在循环中基于环境反馈执行动作(通过工具调用), 正在 `Anthropic` 博客中所指出的:

- 代理可以处理复杂任务, 但它们的实现通常很直接
- 它们通常只是 `LLM` 在循环中基于环境反馈使用工具. 
- 代理可用于难以或无法预测所需步骤数量的开放性问题，以及无法硬编码固定路径的情况。LLM可能会运行多轮，您必须对其决策过程有一定程度的信任。代理的自主性使其成为在可信环境中扩展任务的理想选择


```python
from langchain_core.tools import tool


# Define tools
@tool
def multiply(a: int, b: int) -> int:
    """Multiply a and b.

    Args:
        a: first int
        b: second int
    """
    return a * b


@tool
def add(a: int, b: int) -> int:
    """Adds a and b.

    Args:
        a: first int
        b: second int
    """
    return a + b


@tool
def divide(a: int, b: int) -> float:
    """Divide a and b.

    Args:
        a: first int
        b: second int
    """
    return a / b


# Augment the LLM with tools
tools = [add, multiply, divide]
tools_by_name = {tool.name: tool for tool in tools}
llm_with_tools = llm.bind_tools(tools)
```


```python
from langgraph.graph import MessagesState
from langchain_core.messages import SystemMessage, HumanMessage, ToolMessage


# Nodes
def llm_call(state: MessagesState):
    """LLM decides whether to call a tool or not"""

    return {
        "messages": [
            llm_with_tools.invoke(
                [
                    SystemMessage(
                        content="You are a helpful assistant tasked with performing arithmetic on a set of inputs."
                    )
                ]
                + state["messages"]
            )
        ]
    }


def tool_node(state: dict):
    """Performs the tool call"""

    result = []
    for tool_call in state["messages"][-1].tool_calls:
        tool = tools_by_name[tool_call["name"]]
        observation = tool.invoke(tool_call["args"])
        result.append(ToolMessage(content=observation, tool_call_id=tool_call["id"]))
    return {"messages": result}


# Conditional edge function to route to the tool node or end based upon whether the LLM made a tool call
def should_continue(state: MessagesState) -> Literal["environment", END]:
    """Decide if we should continue the loop or stop based upon whether the LLM made a tool call"""

    messages = state["messages"]
    last_message = messages[-1]
    # If the LLM makes a tool call, then perform an action
    if last_message.tool_calls:
        return "Action"
    # Otherwise, we stop (reply to the user)
    return END


# Build workflow
agent_builder = StateGraph(MessagesState)

# Add nodes
agent_builder.add_node("llm_call", llm_call)
agent_builder.add_node("environment", tool_node)

# Add edges to connect nodes
agent_builder.add_edge(START, "llm_call")
agent_builder.add_conditional_edges(
    "llm_call",
    should_continue,
    {
        # Name returned by should_continue : Name of next node to visit
        "Action": "environment",
        END: END,
    },
)
agent_builder.add_edge("environment", "llm_call")

# Compile the agent
agent = agent_builder.compile()

# Show the agent
display(Image(agent.get_graph(xray=True).draw_mermaid_png()))

# Invoke
messages = [HumanMessage(content="Add 3 and 4.")]
messages = agent.invoke({"messages": messages})
for m in messages["messages"]:
    m.pretty_print()
```

## Refer

- [https://langchain-ai.github.io/langgraph/tutorials/workflows/#building-blocks-the-augmented-llm](https://langchain-ai.github.io/langgraph/tutorials/workflows/#building-blocks-the-augmented-llm)
- [building-effective-agents](https://www.anthropic.com/engineering/building-effective-agents)