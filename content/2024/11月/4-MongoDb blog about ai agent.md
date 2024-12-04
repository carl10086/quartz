

## REFER

- [原文](https://www.mongodb.com/resources/basics/artificial-intelligence/ai-agents)
-  [MongoDb 关于 RAG 的理解](https://www.mongodb.com/resources/basics/artificial-intelligence/retrieval-augmented-generation)
- [RAG-RESEARCH](https://www.promptingguide.ai/research/rag)

虽然是一个介绍 `MongoDB-Atlas` 对矢量引擎的支持，但是不失为一个比较全面的 `AI-Agent` 文章.

## 1-What is an agent ?

![](https://images.contentstack.io/v3/assets/blt7151619cb9560896/bltde68262c14d4abca/67190bd00d92e45b880b1bd5/image1.png)
从图上来看. 

`Ai Agent` = `Cs Agent` + `Human Agent`


**1)-首先，要理解 CS 领域中的 agent**

 在 `CS` 的领域中,  `AGENT` 是一个拥有如下能力的 计算引擎:

1. Has *autonomy* to make decisions and take actions ;
2. Can *interact* with its env ;
3. Can *pursue goals* or carry out tasks ;
4. May *learn* or *use knowledge* to achieve its objectives ;

**2)-其次，要理解 human 领域中的 agent**

1. 一般是什么公司的代表之类 去代表一整个团队 去  Making decisions.或者 take actions 
2. 在 交易场景中，要能全权代表团队
3. 多方 团队中的 中介


**3)-Ai agents 则是融合了 机器部分 和 人类部分 下一个综合概念**


> [!NOTE] Tips
> An Ai agent is a computational entity with an awareness of its env that's equipped with faculties that enable perception through input, action through tool use, and cognitive abilities through foundation models backed by long-term and short-term memory

`Ai-Agent` 结合 cs 和 human 中 agent ,  基于 长短记忆

![](https://images.contentstack.io/v3/assets/blt7151619cb9560896/blt1efc12216945fb20/67190c616d35b0391430b1ae/image2.png)



## 2-Phases


### 2-1 Traditional chatbots  to lLM-powered chatbots


![](https://images.contentstack.io/v3/assets/blt7151619cb9560896/blt7dcdd865c089dddc/67190ebb12ec83da4b2fa23b/image3.png)

1. 以前的 `Chatbot` 是一个 规则引擎, `if-then` 这种假设你问这个，我回答这个的套路, 不行就转入工接管
2. 技术发展很快，尤其是 `ChatGpt` , `transformers` , 里程碑的变革， 真正拥有了理解能力
3. `Gpt` 引入了新的技术挑战，模型幻觉带来的 准确性问题, 成功解决幻觉问题 成为了挑战的重点, `RAG` 技术作为一个重要的改进方向

[MongoDb 关于 RAG 的理解](https://www.mongodb.com/resources/basics/artificial-intelligence/retrieval-augmented-generation)


### 2-2 LLM-powered chatbots to RAG chatbots

**1)-RAG 的本质**

`RAG` 本质上一个信息检索和语言生成的 混合系统，通过结合外部的知识来增强 `LLM` 的能力.

这种知识来源分为2种:

1. `Non-parametric Knowledge` : 从外部的数据中检索的实时信息
2. `Parametric Knowledge` : 模型训练过程中 嵌入的知识 

这种双重知识架构给了 `RAG` 系统更准确的回答:

1. 通过外部的检索获取最新信息知识的能力 
2. 通过模型的参数 去利用已有的知识

**2)-提示工程**

提示工程是 指通过 手动构建的方式 去 引导输出朝向期望的特征 .

有一些技术分别代表了 提示工程位于的 不同 layer

- 上下文的学习: `In-context Learning`, 最基础的层
- 思维链: `Chain of thought, CoT` , 推理层
- `ReAct` : Reason and Act , `Action` 层

`In-context learning` 这个思路是 不需要去 fine-tune 模型，而是通过 模型本身的泛化能力去 指导模型. 一般有2种:

1. One-Shot Learning: Providing a single input-output pair as an example
2. Few-Shot Learning: Providing multiple input-output pairs as examples

而后面发展出的 `COT` 和 `ReAct` 则利用了 `LLM` 模型本身的推理和规划能力, 其中:

- `CoT` : 通过分解复杂问题来提高解决问题的能力
- `ReAct` : 通过把 `Action` 和 `Infer` 的能力结合起来的综合方法


**3)-上面的方法都不需要刻意的去 fine-tuning model**

成本低 意味着可以 快速的 去试错，去落地、去适配新的场景 .


`RAG` 的技术演进:

1. 更复杂的检索策略
2. 多模态数据的整合
3. 更智能的上下文理解能力, [参考](https://www.promptingguide.ai/research/rag)

提示工程的演进:

1. 从传统的 `Prompt` 转向 `Flow Engineering` 的发展
2. 自动化的提示优化
3. 更强大的任务分解能力, [参考](https://www.qodo.ai/blog/from-prompt-engineering-to-flow-engineering-6-more-ai-breakthroughs-to-expect-in-2024/)


### 2-3 RAG chatbot to AI agents


随着 `LLM` 大模型扩充到千亿参数, 他们表现出来了越来越复杂的能力, 这些能力包括: 高级推理, 多步规划, 工具使用[Tool Use] | 函数调用 ...

其中 `Tool use`, sometimes canned "function calling" , refers to an LLM's ability to generate a structured output or schema that specifies the selection of one or more functions from a predefined set and the assignment of appropriate parameter values for these functions.

理解一下 函数调用的能力的 核心特征就是:

1. 生成结构化的输出
2. 选择合适的函数
3. 分配正确的参数


那什么是 tool? 这个定义非常的宽泛，只要是 *任何可以用编程方式定义, 可以被调用* 的东西都可以是工具. 比如 `RAG` 的能力， 比如 `API` 的直接调用.


正是 高级推理，多步规划 和 工具使用能力的组合 促进了. `AI` 代理的出现. `Ai Agent`  需要:

1. tool use  capabilities ;
2. advanced reasoning ;
3. multi-step planning ;



### 2-4 AI Agents

![](https://images.contentstack.io/v3/assets/blt7151619cb9560896/bltd173e58f6af83512/671917f18aeed561fa4933fc/image7.png)



`Ai-Agent` 有3个模块:

1. `Brain`: 认知处理能力, 负责 进行 推理，规划和决策.
	- 一般有3个关键模块:
		- `Memory Module` : 存储 `agent` 和 外部的交互 `context`
		- `Profiler Module` : 基于角色的描述 来调整行为
		- `Knowledge Module`: 存储和检索领域特定的信息
	- 最核心的模块: 提供了 认识能力，记忆的存储，角色的适应，知识管理系统
2. `Action` : 执行能力. 对环境和新的信息作为反应. 这部分组件要能够快速响应以及调用其他的系统
3. `Perception` : 信息获取能力, 也就是 感知组件. 处理各种 结构化数据和非结构化数据的输入，例如文本，视觉和听觉


## 3-Conclusion


目前 没有任何 行业标准或者其他的东西 来说一个 `Ai Agent`

有一些衡量标准去评价一个. `AI Agent` 的水平:

- 决策的自主性水平
- 和环境交互和操作的能力
- 目标导向行为的能力
- 适应新情况的能力
- 主动行为的程度

