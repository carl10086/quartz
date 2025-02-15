
## 1-Intro

**1)-Chat Memory 也是对消息能力管理的封装**

手动维护和管理 `ChatMessages` 能力 是比较复杂的, `ChatMemory` 则是对这个能力的抽象, 可以直接作为 低级组件来使用， 一般都作为 `AI-Services` 的高级组件的一部分.

`ChatMemory` 作为消息管理的容器 (由 `List` 支持), 具有如下的特性:

1. 淘汰策略 ;
2. 持久化能力 ;
3. 对工具消息的特殊处理 , 例如 `SystemMessage` 和 `ToolMessage` ;

**2)-Memory vs History**

`Memory` 和 `History` 是2个类似，但是本质不同的概念.

- `History`:  用户和 `AI` 之间的所有消息
	- `UI` 中，例如 `ChatGpt` 应用中我们看见的内容, 真实的对话 
- `Memory` : 则是 `LLM` 模型对上面对话的记忆, 根据使用的 记忆算法, 记忆是可以被修改的.
	- 可以忘记某些消息
	- 可以是对多条消息的总结
	- 总结单独的消息
	- 从消息中删除掉一些不重要的细节
	- 可以注入额外的信息 information , 例如 `RAG` 能力
	- 可以注入额外的指令 instructions , 例如 结构化输出的 能力

> [!NOTE] Notes
> 
> 框架目前 提供的能力是 **记忆** 而不是 **历史消息**


## 2-Eviction policy


**1)-Why?**

> [!NOTE] Tips
> 有 Token 上限， token 越少，越便宜，延迟越低.

- 适应 `LLM-Model` 的 `context-window` : 
	- `LLM` 能处理的 `token` 是有上限的 
	- 通常都是 淘汰最旧的消息, 但是也可以实现更复杂的算法 
- 控制成本: 
	- 每个 `token` 都是有成本的
- 控制延迟


**2)-How?**

默认有2种实现. 

- `MessageWindowChatMemory`: 
	- 简单, 适合快速的原型开发
	- 基于最近消息的滑动窗口
	- 保留了 `N` 条最近的消息

- `TokenWindowChatMemory`:
	- 基于 `token` 的数量控制
	- 保留最新的 `N` 个 `token`
	- 消息是不可分割的
	- 需要 `Tokenizer` 支持

## 3-Persistence

### 3-1 官方介绍


```java
class PersistentChatMemoryStore implements ChatMemoryStore {

        @Override
        public List<ChatMessage> getMessages(Object memoryId) {
          // TODO: Implement getting all messages from the persistent store by memory ID.
          // ChatMessageDeserializer.messageFromJson(String) and 
          // ChatMessageDeserializer.messagesFromJson(String) helper methods can be used to
          // easily deserialize chat messages from JSON.
        }

        @Override
        public void updateMessages(Object memoryId, List<ChatMessage> messages) {
            // TODO: Implement updating all messages in the persistent store by memory ID.
            // ChatMessageSerializer.messageToJson(ChatMessage) and 
            // ChatMessageSerializer.messagesToJson(List<ChatMessage>) helper methods can be used to
            // easily serialize chat messages into JSON.
        }

        @Override
        public void deleteMessages(Object memoryId) {
          // TODO: Implement deleting all messages in the persistent store by memory ID.
        }
    }

ChatMemory chatMemory = MessageWindowChatMemory.builder()
        .id("12345")
        .maxMessages(10)
        .chatMemoryStore(new PersistentChatMemoryStore())
        .build();
```


**1)-MemoryId** 

- **作用** :唯一去标记一个聊天的上下文**
- **例子** : 可以是 用户`ID`, 会话`ID` 或者组合.

```java
ChatMemory chatMemory = MessageWindowChatMemory.builder()  
	.id("12345")  
	.maxMessages(10)  
	.chatMemoryStore(new PersistentChatMemoryStore())  
	.build();
```

**2)-getMessages**

- 调用时机:  每次需要获取对话历史的时候调用. *通常每次和 `LLM` 系统交互的时候调用*
- 通过 `memoryId` 要区分不同的用户和对话

**3)-deleteMessages** 

- 调用时机: 在调用 `ChatMemory.clear()` 的时候触发
- 用于删除 某个 `memoryId` 对应的所有记忆

**4)-updateMessages**

最重要的方法.

- 调用时机: 每次添加新消息的时候都会使用, 例如添加用户消息 或者 AI响应的时候都会调用
- 每次收到的都是完整的 `Messages`, 需要更新所有
- 消息被淘汰的时候，会收到不包含 淘汰消息的全部.


### 3-2 源码分析

默认的实现非常简单. 

```java
public class InMemoryChatMemoryStore implements ChatMemoryStore {  
    private final Map<Object, List<ChatMessage>> messagesByMemoryId = new ConcurrentHashMap<>();  
  
    /**  
     * Constructs a new {@link InMemoryChatMemoryStore}.  
     */    public InMemoryChatMemoryStore() {}  
  
    @Override  
    public List<ChatMessage> getMessages(Object memoryId) {  
        return messagesByMemoryId.computeIfAbsent(memoryId, ignored -> new ArrayList<>());  
    }  
  
    @Override  
    public void updateMessages(Object memoryId, List<ChatMessage> messages) {  
        messagesByMemoryId.put(memoryId, messages);  
    }  
  
    @Override  
    public void deleteMessages(Object memoryId) {  
        messagesByMemoryId.remove(memoryId);  
    }  
}
```


## refer

- [chat-memory](https://docs.langchain4j.dev/tutorials/chat-memory)