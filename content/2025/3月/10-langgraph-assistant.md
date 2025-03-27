


## 1-Parallelization

并行化能力.

**1)-构建一个简单的线性图**

```python
from IPython.display import Image, display

from typing import Any
from typing_extensions import TypedDict

from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    # The operator.add reducer fn makes this append-only
    state: str

class ReturnNodeValue:
    def __init__(self, node_secret: str):
        self._value = node_secret

    def __call__(self, state: State) -> Any:
        print(f"Adding {self._value} to {state['state']}")
        return {"state": [self._value]}

# Add nodes
builder = StateGraph(State)

# Initialize each node with node_secret 
builder.add_node("a", ReturnNodeValue("I'm A"))
builder.add_node("b", ReturnNodeValue("I'm B"))
builder.add_node("c", ReturnNodeValue("I'm C"))
builder.add_node("d", ReturnNodeValue("I'm D"))

# Flow
builder.add_edge(START, "a")
builder.add_edge("a", "b")
builder.add_edge("b", "c")
builder.add_edge("c", "d")
builder.add_edge("d", END)
graph = builder.compile()

display(Image(graph.get_graph().draw_mermaid_png()))
```

运行的话， 每一步都会覆盖状态.

```python
Adding I'm A to []
Adding I'm B to ["I'm A"]
Adding I'm C to ["I'm B"]
Adding I'm D to ["I'm C"]
```

**2)-下面让 B 和 C 并行**

改下边就行.

```python
builder = StateGraph(State)

# Initialize each node with node_secret 
builder.add_node("a", ReturnNodeValue("I'm A"))
builder.add_node("b", ReturnNodeValue("I'm B"))
builder.add_node("c", ReturnNodeValue("I'm C"))
builder.add_node("d", ReturnNodeValue("I'm D"))

# Flow
builder.add_edge(START, "a")
builder.add_edge("a", "b")
builder.add_edge("a", "c")
builder.add_edge("b", "d")
builder.add_edge("c", "d")
builder.add_edge("d", END)
graph = builder.compile()

display(Image(graph.get_graph().draw_mermaid_png()))
```

这个时候 `fan-out` 从 a -> b , a - > c , 然后一起 `fan-in` 到 `d` .

但是代码会直接出错, 因为 `B` 和 `C` 都在这一步 需改了同一个 `StateKey` . 必须使用 `Reducer`

报错信息如下:

```
Adding I'm A to [] Adding I'm B to ["I'm A"] Adding I'm C to ["I'm A"] An error occurred: At key 'state': Can receive only one value per step. Use an Annotated key to handle multiple values
```

```python
class State(TypedDict):
    # The operator.add reducer fn makes this append-only
    state: Annotated[list, operator.add]
```

**3)-下面的例子中 2条并行， 但是一条路径并另一条更多**

```python
builder = StateGraph(State)

# Initialize each node with node_secret 
builder.add_node("a", ReturnNodeValue("I'm A"))
builder.add_node("b", ReturnNodeValue("I'm B"))
builder.add_node("b2", ReturnNodeValue("I'm B2"))
builder.add_node("c", ReturnNodeValue("I'm C"))
builder.add_node("d", ReturnNodeValue("I'm D"))

# Flow
builder.add_edge(START, "a")
builder.add_edge("a", "b")
builder.add_edge("a", "c")
builder.add_edge("b", "b2")
builder.add_edge(["b2", "c"], "d")
builder.add_edge("d", END)
graph = builder.compile()

display(Image(graph.get_graph().draw_mermaid_png()))
```

输出如下:

```
Adding I'm A to [] 
Adding I'm B to ["I'm A"] 
Adding I'm C to ["I'm A"] 
Adding I'm B2 to ["I'm A", "I'm B", "I'm C"] 
Adding I'm D to ["I'm A", "I'm B", "I'm C", "I'm B2"]
```

- 发现在 `B2` 执行的时候，已经执行了 `b` 和 `c`


**4)-下面的例子中进一步用 sort_reducer 控制了 merge 的顺序**

```python
def sorting_reducer(left, right):
    """ Combines and sorts the values in a list"""
    if not isinstance(left, list):
        left = [left]

    if not isinstance(right, list):
        right = [right]
    
    return sorted(left + right, reverse=False)

class State(TypedDict):
    # sorting_reducer will sort the values in state
    state: Annotated[list, sorting_reducer]

# Add nodes
builder = StateGraph(State)

# Initialize each node with node_secret 
builder.add_node("a", ReturnNodeValue("I'm A"))
builder.add_node("b", ReturnNodeValue("I'm B"))
builder.add_node("b2", ReturnNodeValue("I'm B2"))
builder.add_node("c", ReturnNodeValue("I'm C"))
builder.add_node("d", ReturnNodeValue("I'm D"))

# Flow
builder.add_edge(START, "a")
builder.add_edge("a", "b")
builder.add_edge("a", "c")
builder.add_edge("b", "b2")
builder.add_edge(["b2", "c"], "d")
builder.add_edge("d", END)
graph = builder.compile()

display(Image(graph.get_graph().draw_mermaid_png()))
```

- 这里会直接对所有的状态值进行全局的排序

**5)-下面的例子中给了 sink 节点的方法，给全局进行排序**

```python
class State(TypedDict):
    main_output: list  # 主要输出字段
    temp_b: Optional[str]  # B节点的临时输出
    temp_c: Optional[str]  # C节点的临时输出
    temp_b2: Optional[str]  # B2节点的临时输出

def node_b(state):
    # B节点的处理逻辑
    return {"temp_b": "I'm B"}

def node_c(state):
    # C节点的处理逻辑
    return {"temp_c": "I'm C"}

def node_b2(state):
    # B2节点的处理逻辑
    return {"temp_b2": "I'm B2"}

def sink_node(state):
    # 按照我们指定的顺序收集临时字段
    collected_values = []
    
    # 指定收集顺序
    if state.get("temp_b") is not None:
        collected_values.append(state["temp_b"])
    
    if state.get("temp_b2") is not None:
        collected_values.append(state["temp_b2"])
        
    if state.get("temp_c") is not None:
        collected_values.append(state["temp_c"])
    
    # 将收集的值添加到主输出字段
    return {
        "main_output": state.get("main_output", []) + collected_values,
        # 清除临时字段
        "temp_b": None,
        "temp_c": None,
        "temp_b2": None
    }
```

- 使用了临时字段，然后统一处理


**6)-实际中的类例子， 维基百科搜索 + web 搜索**

```python
from langchain_core.messages import HumanMessage, SystemMessage

from langchain_community.document_loaders import WikipediaLoader
from langchain_community.tools import TavilySearchResults

def search_web(state):
    
    """ Retrieve docs from web search """

    # Search
    tavily_search = TavilySearchResults(max_results=3)
    search_docs = tavily_search.invoke(state['question'])

     # Format
    formatted_search_docs = "\n\n---\n\n".join(
        [
            f'<Document href="{doc["url"]}">\n{doc["content"]}\n</Document>'
            for doc in search_docs
        ]
    )

    return {"context": [formatted_search_docs]} 

def search_wikipedia(state):
    
    """ Retrieve docs from wikipedia """

    # Search
    search_docs = WikipediaLoader(query=state['question'], 
                                  load_max_docs=2).load()

     # Format
    formatted_search_docs = "\n\n---\n\n".join(
        [
            f'<Document source="{doc.metadata["source"]}" page="{doc.metadata.get("page", "")}">\n{doc.page_content}\n</Document>'
            for doc in search_docs
        ]
    )

    return {"context": [formatted_search_docs]} 

def generate_answer(state):
    
    """ Node to answer a question """

    # Get state
    context = state["context"]
    question = state["question"]

    # Template
    answer_template = """Answer the question {question} using this context: {context}"""
    answer_instructions = answer_template.format(question=question, 
                                                       context=context)    
    
    # Answer
    answer = llm.invoke([SystemMessage(content=answer_instructions)]+[HumanMessage(content=f"Answer the question.")])
      
    # Append it to state
    return {"answer": answer}

# Add nodes
builder = StateGraph(State)

# Initialize each node with node_secret 
builder.add_node("search_web",search_web)
builder.add_node("search_wikipedia", search_wikipedia)
builder.add_node("generate_answer", generate_answer)

# Flow
builder.add_edge(START, "search_wikipedia")
builder.add_edge(START, "search_web")
builder.add_edge("search_wikipedia", "generate_answer")
builder.add_edge("search_web", "generate_answer")
builder.add_edge("generate_answer", END)
graph = builder.compile()

display(Image(graph.get_graph().draw_mermaid_png()))
```

## 2-Sub graphs

例子描述:

1. 一个系统在接收日志 ;
2. 然后执行2个 独立的 `sub-tasks`: 一个负责总结 `logs`, 另一个负责查询 `failure modes` ;
3. 然后希望用2个 sub-graph 执行2个独立的任务

这里主要是为了理解 `graphs` 之间如何进行通信. 利用了 `over-lapping keys` 这种技术.

1. 子图可以访问 父图中的 `docs`
2. 父图可以访问 子图的 summary 和 failure_report 


**1)-Log 的结构如下**

```python
from operator import add
from typing_extensions import TypedDict
from typing import List, Optional, Annotated

# The structure of the logs
class Log(TypedDict):
    id: str
    question: str
    docs: Optional[List]
    answer: str
    grade: Optional[int]
    grader: Optional[str]
    feedback: Optional[str]
```


**2)-故障分析子图 设计**

```python
from IPython.display import Image, display
from langgraph.graph import StateGraph, START, END

# Failure Analysis Sub-graph
class FailureAnalysisState(TypedDict):
    cleaned_logs: List[Log]
    failures: List[Log]
    fa_summary: str
    processed_logs: List[str]

class FailureAnalysisOutputState(TypedDict):
    fa_summary: str
    processed_logs: List[str]

def get_failures(state):
    """ Get logs that contain a failure """
    cleaned_logs = state["cleaned_logs"]
    failures = [log for log in cleaned_logs if "grade" in log]
    return {"failures": failures}

def generate_summary(state):
    """ Generate summary of failures """
    failures = state["failures"]
    # Add fxn: fa_summary = summarize(failures)
    fa_summary = "Poor quality retrieval of Chroma documentation."
    return {"fa_summary": fa_summary, "processed_logs": [f"failure-analysis-on-log-{failure['id']}" for failure in failures]}

fa_builder = StateGraph(FailureAnalysisState,output=FailureAnalysisOutputState)
fa_builder.add_node("get_failures", get_failures)
fa_builder.add_node("generate_summary", generate_summary)
fa_builder.add_edge(START, "get_failures")
fa_builder.add_edge("get_failures", "generate_summary")
fa_builder.add_edge("generate_summary", END)

graph = fa_builder.compile()
display(Image(graph.get_graph().draw_mermaid_png()))
```


这个子图包含两个节点：
1. get_failures: 从清洗过的日志中获取包含失败的日志
2. generate_summary: 生成失败分析的摘要

子图的流程是：START → get_failures → generate_summary → END


**3)-问题摘要子图(Question Summarization Sub-graph)**

```python
# Summarization subgraph
class QuestionSummarizationState(TypedDict):
    cleaned_logs: List[Log]
    qs_summary: str
    report: str
    processed_logs: List[str]

class QuestionSummarizationOutputState(TypedDict):
    report: str
    processed_logs: List[str]

def generate_summary(state):
    cleaned_logs = state["cleaned_logs"]
    # Add fxn: summary = summarize(generate_summary)
    summary = "Questions focused on usage of ChatOllama and Chroma vector store."
    return {"qs_summary": summary, "processed_logs": [f"summary-on-log-{log['id']}" for log in cleaned_logs]}

def send_to_slack(state):
    qs_summary = state["qs_summary"]
    # Add fxn: report = report_generation(qs_summary)
    report = "foo bar baz"
    return {"report": report}

qs_builder = StateGraph(QuestionSummarizationState,output=QuestionSummarizationOutputState)
qs_builder.add_node("generate_summary", generate_summary)
qs_builder.add_node("send_to_slack", send_to_slack)
qs_builder.add_edge(START, "generate_summary")
qs_builder.add_edge("generate_summary", "send_to_slack")
qs_builder.add_edge("send_to_slack", END)

graph = qs_builder.compile()
display(Image(graph.get_graph().draw_mermaid_png()))
```

这个子图包含两个节点：
1. generate_summary: 生成问题摘要
2. send_to_slack: 将摘要发送到Slack

子图的流程是：START → generate_summary → send_to_slack → END


**4)-入口图节点设计: Entry Graph**

```python
class EntryGraphState(TypedDict):
    raw_logs: List[Log]
    cleaned_logs: List[Log]
    fa_summary: str  # 只在故障分析子图中生成
    report: str  # 只在问题摘要子图中生成
    processed_logs: Annotated[List[int], add]  # 在两个子图中都会生成
```



## 3-Map-Reduce


## 4-Research Assistant


