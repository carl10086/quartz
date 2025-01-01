
## 1-Intro

**1)-What's langchain4j**

`java` 圈的 `langchain` 框架. 主要来自于 `langchain` `haystack` 和 `llamaindex` 等等项目

1. 统一的 `API` ;
2. 集成了主流的 `vector` `storage` ;
3. 底层工具: `rag` , `tools` `functional calling` , `memory management`  功能 ;
4. 高层模式: `AI` 服务和 `RAG` 检索增强生成 ;
5. 每个抽象都提高了 接口和多种实现方式 ;
6. ...


## 2-Quick Start

### 2-1 框架集成

每一个模型都是单独的 `package`

```xml
<dependency>  
    <groupId>dev.langchain4j</groupId>  
    <artifactId>langchain4j-bom</artifactId>  
    <version>1.0.0-alpha1</version>  
    <type>pom</type>  
    <scope>import</scope>  
</dependency>
```

如果要使用 `azure-open-ai` . 则要集成对应的模块.

```xml
<dependency>  
    <groupId>dev.langchain4j</groupId>  
    <artifactId>langchain4j-open-ai</artifactId>  
</dependency>  
  
<dependency>  
    <groupId>dev.langchain4j</groupId>  
    <artifactId>langchain4j-azure-open-ai</artifactId>  
</dependency>
```


一般的模型例如  火山方舟大模型都是支持 `OpenAI` 的兼容 `API` .

```kotlin
    /**
     * azure open api
     */
    @Test
    fun azure() {
        val model = AzureOpenAiChatModel.builder()
            .apiKey(System.getenv("AZURE_API_KEY"))
            .endpoint(System.getenv("AZURE_ENDPOINT"))
            .deploymentName("gpt-4o")
            .build()


        val ans = model.generate("Say 'Hello world'")
        println(ans)
    }


    /**
     * 使用 openai 调用豆包
     */
    @Test
    fun doubao() {
        val model = OpenAiChatModel.builder()
            .apiKey(System.getenv("DB_API_KEY"))
            .baseUrl(System.getenv("DB_ENDPOINT"))
            .modelName(System.getenv("DB_MODEL_NAME"))
            .build()

        val ans = model.generate("Say 'hello world'")
        println(ans)
    }
```


### 2-2 Chat And Language Models

**1)- API 类型**

`LLMs` 目前有2种 `API` 类型.

- `LanguageModels` : 简单的字符串输入和字符串输出, *正在逐渐的没用* 
- `ChatLanguageModels`: 主流， 接收多个 `ChatMessage` 作为输入，然后返回单个 `AiMessage`
	- 其中 `ChatMessage` 通常包含文本，但是随着 *多模态技术的演进*, 像 `gpt-4o-mini` 和 `gemini-1.5-pro`  都支持了 多模态的输入，例如 Image 和 Audio ...
	-  `ChatLanaguageModel` 是一个 `low-level` 低级原语 `API`, 也就意味着 是 **最灵活的**.  高级 `API`, 也就是所谓的 `AI-Services`


```java
    ...
    Response<AiMessage> generate(ChatMessage... messages);
    Response<AiMessage> generate(List<ChatMessage> messages);
    ...
```


其他的 `Model` 集成能力还有:

- 嵌入模型 EmbeddingModel - 可以将文本转换为嵌入向量
- 图像模型 ImageModel - 可以生成和编辑图像
- 审核模型 ModerationModel - 可以检查文本是否包含有害内容
- 评分模型 ScoringModel - 可以对多个文本片段相对于查询进行评分（或排名）

**2)- ChatMessage 类型**

一般在 `AI` 中会把消息分为4种.

| 中文名称     | LangChain4j                | LangChain Python | OpenAI API    | 详情说明                                                                      | 示例                                                                                 |
| -------- | -------------------------- | ---------------- | ------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 用户消息     | UserMessage                | HumanMessage     | user          | - 来自最终用户或应用程序的输入<br>- 支持文本和多模态输入<br>- 是对话的主要输入形式<br>- 可以包含问题、指令或陈述        | - "帮我分析这段代码的性能问题"<br>- "翻译下面这段文字"<br>- "生成一个Java类的单元测试"                            |
| AI响应消息   | AiMessage                  | AIMessage        | assistant     | - AI模型生成的响应<br>- 通常作为UserMessage的回复<br>- 可以包含文本或工具调用请求<br>- 被Response对象包装 | - "根据代码分析，主要性能瓶颈在于..."<br>- "这段文字的翻译是..."<br>- "以下是生成的单元测试代码..."                   |
| 系统消息     | SystemMessage              | SystemMessage    | system        | - 定义AI助手的角色和行为<br>- 通常位于对话开始<br>- 影响力最大，需要严格控制<br>- 不应允许用户修改              | - "你是一个Java专家，专注于代码优化"<br>- "你是一个翻译助手，精通中英互译"<br>- "回答要简洁，使用中文，保持专业性"              |
| 工具执行结果消息 | ToolExecutionResultMessage | FunctionMessage  | function/tool | - 工具/函数执行的结果<br>- 用于集成外部功能<br>- 可以包含执行状态和返回值<br>- 支持复杂的工具链调用              | - "数据库查询结果：共找到5条记录"<br>- "API调用结果：{"status": "success"}"<br>- "文件读取完成，内容长度：1024字节" |

上面对 `Message` 的类型分类基本上已经在 各种框架中中达成了共识. 

1. `UserMessage` : 来源一般是 `Human`, 一般是纯文本，也可以是多模态, **代表用户输入**
2. `AiMessage` : 来源一般是 `AI` , 通常是作为 `UserMessage` 的响应
3. `ToolExecutionResultMessage`: 一般来自于 工具系统 `Tool | Func` , 特点是对应于 相对的 工具
4. `SystemMessage`: 一般 由 *开发者 developer* 定义，`LLM` 会对 这个更重要, 例如用来 设置行为规则或者指定回答风格等等


一个非常简单的例子去复现如下对话:

```
- User: Hello, my name is Klaus
- AI: Hi Klaus, how can I help you?
- User: What is my name?
- AI: Klaus
```


```kotlin
@Test  
fun `doubao multple chat`() {  
    val model = OpenAiChatModel.builder()  
        .apiKey(System.getenv("DB_API_KEY"))  
        .baseUrl(System.getenv("DB_ENDPOINT"))  
        .modelName(System.getenv("DB_MODEL_NAME"))  
        .build()  
  
    val firstUserMessage = UserMessage.from("Hello, my name is Klaus")  
    val firstAiMessage = model.generate(firstUserMessage).content()  
    val secondUserMessage = UserMessage.from("What is my name?")  
    val secondAiMessage = model.generate(firstUserMessage, firstAiMessage, secondUserMessage).content()  
    println(secondAiMessage.text())  
}
```


**3)-多模态能力**

```kotlin
@Test  
fun `azure multimodality`() {  
    val model = AzureOpenAiChatModel.builder()  
        .apiKey(System.getenv("AZURE_API_KEY"))  
        .endpoint(System.getenv("AZURE_ENDPOINT"))  
        .deploymentName("gpt-4o")  
        .build()  
  
    val httpUrl = "https://cdn.pixabay.com/photo/2023/07/05/04/45/european-shorthair-8107433_1280.jpg"  
    val resp = model.generate(  
        UserMessage.from("Tell me all you know about image"),  
        UserMessage.from(ImageContent.from(httpUrl))  
    )  
    println(resp.content())  
}
```


## refer

- [intro](https://docs.langchain4j.dev/intro)
- [building a Streaming Chat Bot with Spring Boot And Spring AI](https://www.danvega.dev/blog/spring-ai-streaming-chatbot)