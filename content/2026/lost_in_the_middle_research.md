
> **核心论文**：
> - [2510.10276] **Salvatore, N., Wang, H., & Zhang, Q.** (2025). *Lost in the Middle: An Emergent Property from Information Retrieval Demands in LLMs*. Rutgers University. ([arXiv:2510.10276](https://arxiv.org/abs/2510.10276))
>
> **相关论文**：
> - [2511.05850] McKinnon, M. (2025). *Retrieval Quality at Context Limit*. ([arXiv:2511.05850](https://arxiv.org/abs/2511.05850))
> - [2602.14188] Esmi, N., et al. (2026). *GPT-5 vs Other LLMs in Long Short-Context Performance*. ([arXiv:2602.14188](https://arxiv.org/abs/2602.14188))
> - [2511.13900] Gupte, M., et al. (2025). *What Works for 'Lost-in-the-Middle' in LLMs? A Study on GM-Extract and Mitigations*. ([arXiv:2511.13900](https://arxiv.org/abs/2511.13900))
> - [2510.10276] Liu, N.F., et al. (2023). *Lost in the Middle: How Language Models Use Long Contexts*. ([arXiv](https://arxiv.org/abs/2307.10172))

---

## 一、现象定义

### 1.1 原文定义

根据 [2510.10276] 原文：

> "When answering questions over exceedingly long context information, Large Language Models (LLMs) exhibit a 'lost-in-the-middle' phenomenon in which accuracy drops significantly for information near the center of the context window."

即：当 LLM 需要从超长上下文中回答问题时，准确率会显著下降——尤其是当关键信息位于上下文**中间位置**时。

### 1.2 表现形式：U-shaped Curve

[2510.10276] 指出这一现象与人类记忆研究中的 **serial position effect** 完全一致：

> "This phenomenon is strikingly similar to serial position effects found in human memory literature, where people preferentially recall items from the beginning (primacy) and end (recency) of a study list with higher accuracy, producing a characteristic U-shaped curve." (Murdock & Bennet, 1962)

| 位置 | 记忆/检索效果 | 人类记忆术语 |
|-----|-------------|------------|
| 上下文开头 | 高 | **Primacy Effect**（首因效应） |
| 上下文结尾 | 高 | **Recency Effect**（近因效应） |
| 上下文中间 | 低 | "Lost in the Middle" |

### 1.3 数学描述

[2510.10276] 使用 **Serial Position Curve (SPC)** 来量化这一现象：

> "Serial position curves (SPC) tracks recall accuracy as a function of item position in the input list, typically revealing primacy and recency effects."

公式定义：
$$P_{SPC}(i) = \frac{1}{N} \sum_{n=1}^{N} R_{n,i}$$

其中 $R_{n,i}$ 是指示变量——如果第 n 次试验中位置 i 的项目被回忆起则为 1，否则为 0。

---

## 二、历史背景与研究动机

### 2.1 此前研究的不同视角

[2510.10276] 指出此前研究将此现象归因于：

1. **LLMs' intrinsic attention biases** (Hsieh et al., 2024b; Xiao et al., 2023; Gu et al., 2024)
2. **Architectural biases** (Wu et al., 2025)

> "While much of the work on the lost-in-the-middle effect has considered it a model bias and focused on eliminating the effect altogether (Hsieh et al., 2024b; Zhang et al., 2024; Wang et al., 2024)..."

### 2.2 本文的核心假设

[2510.10276] 提出了一个替代性视角：

> "Our current work provides an alternative perspective, considering it as an emergent property under the information retrieval demands during LLM pre-training."

即：U-shape 不是缺陷，而是 LLM 预训练时**信息检索需求**导致的**自适应行为**。

### 2.3 认知心理学的类比

[2510.10276] 借鉴了认知心理学的理论框架：

| 认知心理学概念 | 在 LLM 中的对应 |
|--------------|---------------|
| **Short-term memory demand** | 需要回忆最近的事件 |
| **Long-term memory demand** | 需要回忆较早的事件 |
| **Rational analysis** | 理解行为是"在认知架构约束下完成任务的最佳策略" |
| **Resource-rational analysis** | 许多曾被视为"偏见"的行为实际上是"对环境挑战的理性适应" |

[2510.10276] 原文：

> "From this perspective, many cognitive behaviors once considered biases or flaws are now understood as rational adaptations to environmental challenges (Lieder et al., 2018; Callaway et al., 2024; Huttenlocher et al., 2000)."

---

## 三、实验设计

### 3.1 实验任务定义

[2510.10276] 设计了三类记忆任务：

#### 3.1.1 Free Recall Task（自由回忆任务）

**任务定义**：

> "After the list presentation, the model is expected to output all items from the list in any order... This imposes a uniform long-term information retrieval demand across the list."

**输入格式**：
$$I_{FR} = [\texttt{<SoS>}\;\;W_{presentation}\;\;\texttt{<EoS>}]$$

**特点**：对整个列表施加**均匀的长期记忆需求**。

#### 3.1.2 Running Span Task（运行广度任务）

**任务定义**：

> "The running span task involves recalling the last N items preceding a specified location (i.e., recall token), which places a short-term memory demand on only the most recent information."

**输入格式**：
$$I_{RS} = [\texttt{<SoS>}\;\;W_{presentation}\;\;\texttt{<RECALL\_n>}\;\;\texttt{<EoS>}]$$

**特点**：对列表**末尾**的信息施加**短期记忆需求**。

实验中 n 在 1-7 之间随机采样，靠近 recall token 的项目在更多试验中出现。

#### 3.1.3 Combined Task（组合任务）

**任务定义**：

> "The model is expected to (i) recall the last n items (order-agnostic) and (ii) recall the entire list (order-agnostic). This mixes uniform long-term memory demand with an end-weighted short-term memory demand, yielding a mixed demand condition."

### 3.2 Masked Sequence Completion Task

[2510.10276] 还设计了一个更接近 LLM 预训练的任务：

> "We replicated our results using a masked sequence completion task, which more closely resembles the next-token prediction process in LLM pre-training."

**输入格式**：
$$I_{SCT} = [\texttt{<SoS>}\;\;W_{presentation}\;\;\texttt{<EoS>}\;\;w_s,\dots,w_{s+r-1},\underbrace{\texttt{\_}\;\cdots\;\texttt{\_}}_{b\;blanks}]$$

模型需要填写 blank 后的 b 个项目。

### 3.3 测试的模型

[2510.10276] 测试了以下模型：

| 模型 | 类型 | 参数量 |
|-----|------|-------|
| GPT-2 Small | Decoder-only | ~124M |
| GPT-2 Large | Decoder-only | ~774M |
| Llama 3.2 1B | Decoder-only | ~1B |
| T5 | Encoder-Decoder | - |
| RNN seq2seq | Autoregressive | - |

### 3.4 评估指标

[2510.10276] 使用了认知心理学中的三种分析工具：

1. **Serial Position Curve (SPC)**：回忆准确率作为列表位置的函数
2. **Probability of First Recall (PFR)**：首次回忆从列表哪个位置开始
3. **Conditional Response Probability (CRP)**：回忆转换模式

---

## 四、实验结果

### 4.1 主要发现

#### 4.1.1 Free Recall Task → Primacy Effect

[2510.10276] 原文：

> "When trained from scratch on the free recall task, all models displayed near-perfect recall performance. Their behavior mimicked the classic human primacy effect, characterized by a strong tendency to initiate recall from the beginning of the list."

**结论**：长期记忆需求 → 产生 Primacy Effect（首因效应）

#### 4.1.2 Running Span Task → Recency Effect

[2510.10276] 原文：

> "In contrast, models trained on the running span task demonstrated recency effects... specifically, higher recall probabilities for items relatively closer to the end of the list."

**结论**：短期记忆需求 → 产生 Recency Effect（近因效应）

#### 4.1.3 Combined Task → U-shape

[2510.10276] 原文：

> "The most intriguing recall patterns emerge under the combined training regime. For GPT-2 models, the serial position curve shifts toward a U-shape, exhibiting both primacy and recency effects, which in turn resulted in a lost-in-the-middle behavior."

**结论**：混合训练 → 产生 U-shape（Lost in the Middle）

#### 4.1.4 模型规模的影响

[2510.10276] 原文：

> "This result provides further evidence that, in many instances, increased model complexity leads to a reduction in the lost-in-the-middle behavior (Guo and Vosoughi, 2024; Liu et al., 2023)."

即：更大的模型（如 Llama 3.2 1B）U-shape 现象更轻微。

---

## 五、成因分析

### 5.1 训练任务的信息检索需求

[2510.10276] 的核心论点是：

> "Lost-in-the-middle behavior can be induced in LLMs by manipulating their training objectives."

| 训练任务 | 信息检索需求 | 产生的效应 |
|---------|------------|----------|
| Free Recall | Uniform (长期记忆) | Primacy Effect |
| Running Span | End-weighted (短期记忆) | Recency Effect |
| Combined | Mixed | U-shape |

### 5.2 架构偏见

[2510.10276] 进行了消融实验，比较不同架构：

#### 5.2.1 Autoregressive vs Bidirectional

[2510.10276] 原文：

> "We observe strong primacy in autoregressive models (RNN seq2seq and GPT-2), while a bidirectional encoder-decoder (T5) exhibits a flatter serial position curve and equal preference for initiating recall from anywhere in the sequence."

**结论**：
- **Decoder-only** (GPT)：有明显 U-shape
- **Encoder-Decoder** (T5)：几乎没有 U-shape
- **RNN seq2seq**：有 Primacy Effect（因为也是自回归的）

原因分析：

> "The behavioral differences between these two models suggests that the primacy effects seen in decoder-only LLMs and RNNs may largely stem from their autoregressive design."

#### 5.2.2 Causal Masking 的影响

[2510.10276] 指出：

> "Autoregressive processing encourages concentrating more attention towards early tokens (Xiao et al., 2023; Wu et al., 2025)"

即：因果掩码让模型天然倾向于更关注前面的 token。

### 5.3 Attention Sink（注意力沉降）

#### 5.3.1 什么是 Attention Sink

[2510.10276] 原文定义：

> "Attention sinks describe the phenomenon where the initial tokens of a sequence disproportionately attract most of the attention weight across several attention heads, despite carrying little semantic content (Xiao et al., 2023)."

即：序列开头的 token（通常是 `<SoS>`）吸引了大量注意力，但这些 token 本身语义内容很少。

#### 5.3.2 消融实验

[2510.10276] 进行了消融实验：

> "We performed targeted disruptions by applying dropout to entire attention layers identified as exhibiting attention sink behavior."

**实验设置**：
- 使用阈值 $\epsilon = 0.8$ 识别 Attention Sink
- 对 First token 应用注意力 dropout

**结果**：

| 任务类型 | Attention Sink Dropout 的影响 |
|---------|--------------------------|
| Free Recall (Long-term) | **显著下降**，尤其在 Primacy 区域 |
| Running Span (Short-term) | **无显著影响** |
| Combined | **显著下降**，U-shape 消失 |

[2510.10276] 原文：

> "These results indicate that attention sinks are an important mechanism for supporting tasks that place long-term memory demands."

**关键洞察**：Attention Sink 主要支持长期记忆检索，对短期记忆检索影响不大。

#### 5.3.3 Attention Sink 的数学定义

[2510.10276] 引用了 Gu et al. (2024) 的定义：

对于第 $l$ 层的第 $h$ 个注意力头，第 $k$ 个 token 的重要性分数定义为：

$$\alpha_h^l(k) = \frac{1}{T-k+1} \sum_{i=k}^{T} A_{i,k}^l$$

当 $\alpha_h^l(k)$ 超过阈值 $\epsilon$ 时，该注意力头表现出 Attention Sink 行为。

---

## 六、新模型的解决方案

### 6.1 Gemini 2.5 Flash

根据 [2511.05850]：

> "We find the model Gemini 2.5 Flash can answer needle-in-a-haystack questions with great accuracy regardless of document position including when the document is nearly at the input context limit."

> "Our results suggest that the 'Lost in the Middle' effect is not present for simple factoid Q&A in Gemini 2.5 Flash."

### 6.2 GPT-5 等新模型

根据 [2602.14188]：

> "This research also indicates that the 'lost in the middle' problem has been largely resolved in newer models."

### 6.3 现有缓解方法分类

根据 [2511.13900]，现有方法分为两类：

| 方法类型 | 描述 | 示例 |
|---------|------|------|
| **Black-box Methods** | 不需要了解模型内部结构 | 输入格式重排、上下文压缩 |
| **White-box Methods** | 需要修改模型架构或训练过程 | 位置编码修改、注意力调整 |

**重要警示**：

> "Their efficacy is highly nuanced. Our evaluation highlights scenarios where these strategies successfully improve performance, as well as surprising cases where they lead to a negative impact."

### 6.4 具体缓解技术

[2510.10276] 引用的方法：

| 技术 | 描述 | 引用 |
|-----|------|------|
| **Rotary-embedding rescaling** | 旋转位置编码缩放 | Zhang et al., 2024 |
| **Attention offsetting** | 注意力偏移 | Hsieh et al., 2024b |
| **Context reordering** | 上下文重排 | Peysakhovich & Lerer, 2023 |
| **Position-agnostic training** | 位置无关训练 | Wang et al., 2024 |

[2510.10276] 的评论：

> "Interventions that flatten or re-weight positional attention should have the most impact when tasks impose mixed or long-range information retrieval demands that would otherwise rely on primacy mechanisms."

---

## 七、对 Prompt 设计的实际建议

### 7.1 基于原文的建议

[2510.10276] 的实验证明了 U-shape 现象确实存在，因此在实际应用中：

| 建议 | 原因 |
|-----|------|
| **重要信息放在开头或结尾** | 中间位置检索效果最差 |
| **关键指令不要埋在长上下文中** | 中间位置容易被忽略 |
| **使用明确的结构标记** | 帮助模型定位重要信息 |

### 7.2 模型差异

| 模型 | U-shape 程度 | 建议 |
|-----|------------|------|
| GPT-2, Llama 早期版本 | 明显 | 严格遵循上述建议 |
| Llama 3.2 1B | 轻微 | 基本遵循即可 |
| Gemini 2.5 Flash | 基本解决 | 可更灵活放置信息 |
| GPT-5 | 基本解决 | 可更灵活放置信息 |

---

## 八、总结

### 8.1 核心发现

[2510.10276] 的核心结论：

> "Our findings suggest that the lost-in-the-middle phenomenon arises from information retrieval demands inherent in task data rather than from true information loss over long contexts."

即：**U-shape 不是信息丢失，而是训练任务需求的自适应结果**。

### 8.2 三大成因

| 成因 | 机制 | 影响 |
|-----|------|------|
| **训练任务需求** | Long-term + Short-term demand 混合 | 产生 U-shape |
| **架构偏见** | Autoregressive 因果掩码 | 加强 Primacy Effect |
| **Attention Sink** | 开头 token 吸引大量注意力 | 支持长期记忆检索 |

### 8.3 新模型进展

- **Gemini 2.5 Flash**：简单事实问答中已无 U-shape
- **GPT-5**：已基本解决此问题

### 8.4 实践建议

尽管新模型有所改善，但在**复杂推理**和**超长上下文**场景下，U-shape 仍可能存在。保守建议：

> **重要信息放在开头或结尾，避免放在中间。**

---

## 九、参考文献

1. Anderson, J.R. (1990). *The Adaptive Character of Thought*. Psychology Press.

2. Anderson, J.R. & Milson, R. (1989). Human memory: An adaptive perspective. *Psychological Review*, 96:703-719.

3. Gu, X., et al. (2024). When attention sink emerges in language models: An empirical view. *arXiv:2410.10781*.

4. Guo, T., et al. (2024). Active-dormant attention heads: Mechanistically demystifying extreme-token phenomena in LLMs. *arXiv:2410.13835*.

5. Guo, X. & Vosoughi, S. (2024). Serial position effects of large language models. *arXiv:2406.15981*.

6. Hsieh, C.-Y., et al. (2024). Found in the middle: Calibrating positional attention bias improves long context utilization. *ACL 2024*.

7. Liu, N.F., et al. (2023). Lost in the middle: How language models use long contexts. *TACL*, 12:157-173.

8. McKinnon, M. (2025). Retrieval quality at context limit. *arXiv:2511.05850*.

9. Murdock, B. & Bennet, D. (1962). The serial position effect of free recall. *JEP*, 64:482-488.

10. Salvatore, N., Wang, H., & Zhang, Q. (2025). Lost in the middle: An emergent property from information retrieval demands in LLMs. *arXiv:2510.10276*.

11. Wang, Z., et al. (2024). Eliminating position bias of language models: A mechanistic approach. *arXiv:2407.01100*.

12. Wu, X., et al. (2025). On the emergence of position bias in transformers. *arXiv:2502.01951*.

13. Xiao, G., et al. (2023). Efficient streaming language models with attention sinks. *arXiv:2309.17453*.

14. Zhang, Z.A., et al. (2024). Found in the middle: How language models use long contexts better via plug-and-play positional encoding. *arXiv:2403.04797*.

