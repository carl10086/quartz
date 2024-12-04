

## 1-Intro


微服务体系中 `Application` 和 `Application` 间会用 `MQ`, 例如 `RocketMQ` , `Kafka`, `Pular` 来 **解耦** ;

应用体系中 比如 `layer-based-style` 风格中，同层之间 也会用 事件机制来进行 **解耦** , 典型的技术方案比如:

- `Spring Application Event`
- `EventBus`




## 2-Spring Event 

> QuickStart


```kotlin
  
class SpringEventListenerTest {  
    @Test  
    fun `test publish`() {  
        val ctx = AnnotationConfigApplicationContext(SpringEventListenerTestConfig::class.java)  
        val bean = ctx.getBean(SpringEventListenerTestPublisher::class.java)  
        bean.publishEvent("我是一个小消息")  
    }  
}  
  
@Configuration  
open class SpringEventListenerTestConfig {  
  
    /**  
     * 开启这个配置会 实现 异步化消费消息, 是一个全局配置  
     */  
    @Bean(name = ["applicationEventMulticaster"])  
    open fun simpleApplicationEventMulticaster(): ApplicationEventMulticaster {  
        val eventMulticaster =  
            SimpleApplicationEventMulticaster()  
  
        eventMulticaster.setTaskExecutor(SimpleAsyncTaskExecutor())  
        return eventMulticaster  
    }  
}  
  
data class CustomSpringEvent(  
    val message: String,  
    val source: SpringEventListenerTestPublisher  
) : ApplicationEvent(source)  
  
  
@Component  
class SpringEventListenerTestPublisher(  
    private val applicationEventPublisher: ApplicationEventPublisher  
) {  
    fun publishEvent(message: String) {  
        applicationEventPublisher.publishEvent(CustomSpringEvent(message, this))  
        logger.info("生产者发送了消息:{}", message)  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(SpringEventListenerTestPublisher::class.java)  
    }  
}  
  
  
@Component  
class SpringEventListenerTestListener : ApplicationListener<CustomSpringEvent> {  
    override fun onApplicationEvent(event: CustomSpringEvent) {  
        logger.info("接收到了消息: ${event.message}")  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(SpringEventListenerTestPublisher::class.java)  
    }  
}  
  
@Component  
class SpringEventListenerTestAnnoListener {  
    @EventListener  
    fun onApplicationEvent(event: CustomSpringEvent) {  
        logger.info("Annotation Event 接收到了消息: ${event.message}")  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(SpringEventListenerTestAnnoListener::class.java)  
    }  
}
```


输出结果:

```
2024-06-13 16:16:19.896  INFO
      [TraceId: , SpanId: ] --- [Executor-1]
      ringEventListenerTestPublisher : 接收到了消息: 我是一个小消息
2024-06-13 16:16:19.896  INFO
      [TraceId: , SpanId: ] --- [Executor-2]
      gEventListenerTestAnnoListener : Annotation Event 接收到了消息: 我是一个小消息
2024-06-13 16:16:19.901  INFO
      [TraceId: , SpanId: ] --- [      main]
      ringEventListenerTestPublisher : 生产者发送了消息:我是一个小消息
```

- 注意到 消费者使用的是 异步的线程池
- 使用 `simpleApplicationEventMulticaster` 开启了全局异步化


> [!NOTE] Tips
> 如果配置了一个 ﻿applicationEventMulticaster Bean，那么所有通过 Spring 的事件机制发布的事件，包括 Spring 自身使用的内部事件（如上下文刷新、自定义应用事件等），默认都会使用您配置的这个 ﻿applicationEventMulticaster 和对应的线程池。这是因为 ﻿applicationEventMulticaster 是 Spring 的全局事件广播器。



> [!NOTE] Tips
> 一种简单的方案是在 listener 中显示使用异步调度方案




> 高阶用法


- `GenericSpringEvent`: 支持泛型 事件, Spring 根据监听器声明的泛型类型匹配事件，以确保每个监听器只接收其关心的具体泛型类型的事件 ;
- 支持条件 `EL` 表达式, 例如: `@EventListener(condition = "#event.success")` 这样的条件引擎



## 3-EventBus


- [官方文档](https://github.com/google/guava/wiki/EventBusExplained)


官方文档 非常 **不推荐现在的 eventBus** 方案. 考虑到如下的因素, 也没有维护下去了感觉.

1. 交叉引用难以追踪
2. 内部使用了反射机制
3. 缺乏对多个事件的等待机制
4. 不支持 `backpressure` 的精确控制
5. 对线程的控制 支持很少
6. 缺乏监控能力
7. 异常处理不足，不支持 传播异常事件
8. 对 `RxJava` 协程等机制的支持不足
9. 性能差，尤其在 安卓上
10. 不支持泛型
11. 设计的时候在 `java8` 之前



> quick Start


```kotlin
  
internal class GuavaEventBusTst {  
  
    @Test  
    fun `test publish`() {  
        val ctx = AnnotationConfigApplicationContext(GuavaEventBusTstCfg::class.java)  
        val bean = ctx.getBean(EventBus::class.java)  
        println(bean)  
        bean.post(GuavaEventBusTstEvent("1"))  
        Thread.sleep(10L) /*junit sleep 等待异步处理*/  
    }  
}  
  
data class GuavaEventBusTstEvent(  
    val messageId: String  
)  
  
  
@Component  
class GuavaEventBusTstListener(private val asyncEventBus: EventBus) : InitializingBean {  
  
    @Subscribe  
    fun onEvent(event: GuavaEventBusTstEvent) {  
        logger.info("event:{}", event)  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(GuavaEventBusTstListener::class.java)  
    }  
  
    override fun afterPropertiesSet() {  
        asyncEventBus.register(this)  
    }  
}  
  
@Configuration  
open class GuavaEventBusTstCfg {  
  
    @Bean  
    open fun asyncEventBus(): EventBus = AsyncEventBus(Executors.newFixedThreadPool(2))  
}
```


## 4-Kotlin routinex


协程的实现中的 `Channel` 天然就适合作为事件的发布管道.

1. 使用 `CorutineScope` 来管理协程的生命周期, 来 `Spring Bean` 启动后启动一个协程来消费事件
2. `Channel`: 使用协程的 `Channel` 来作为 事件的中间管道

```kotlin
  
import jakarta.annotation.PostConstruct  
import kotlinx.coroutines.CoroutineScope  
import kotlinx.coroutines.Dispatchers  
import kotlinx.coroutines.channels.Channel  
import kotlinx.coroutines.channels.consumeEach  
import org.apache.logging.log4j.LogManager  
import org.junit.jupiter.api.Test  
import org.springframework.context.annotation.Configuration  
import kotlinx.coroutines.*  
import org.springframework.context.annotation.AnnotationConfigApplicationContext  
import org.springframework.context.annotation.Bean  
import org.springframework.context.annotation.ComponentScan  
import org.springframework.stereotype.Component  
  
internal class KRoutineTest {  
    @Test  
    fun `test publish`() = runBlocking {  
        val ctx = AnnotationConfigApplicationContext(KRoutineTestCfg::class.java)  
        val publisher = ctx.getBean(EventPublisher::class.java)  
//        val listener = ctx.getBean(KRoutineTestListener::class.java)  
  
        publisher.publish(KRoutineTestEvent("1"))  
  
        // 等待一下，确保异步处理完成  
        delay(10L)  
    }  
}  
  
@Configuration  
open class KRoutineTestCfg {  
    @Bean  
    open fun eventChannel(): Channel<KRoutineTestEvent> = Channel(Channel.BUFFERED)  
  
    @Bean  
    open fun eventPublisher(channel: Channel<KRoutineTestEvent>): EventPublisher {  
        return EventPublisher(channel)  
    }  
}  
  
data class KRoutineTestEvent(  
    val msgId: String  
)  
  
  
class EventPublisher(private val channel: Channel<KRoutineTestEvent>) {  
    suspend fun publish(event: KRoutineTestEvent) {  
        channel.send(event)  
    }  
}  
  
  
@Component  
open class KRoutineTestListener(  
    private val channel: Channel<KRoutineTestEvent>  
) : CoroutineScope by CoroutineScope(Dispatchers.Default) {  
  
    @PostConstruct  
    fun init() {  
        launch {  
            try {  
                channel.consumeEach { event ->  
                    onEvent(event)  
                }  
            } catch (e: CancellationException) {  
                logger.info("Coroutine cancelled")  
            } catch (t: Throwable) {  
                logger.error("Error in consuming channel", t)  
            }  
        }  
    }  
  
  
    private fun onEvent(event: KRoutineTestEvent) {  
        logger.info("event:{}", event)  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(KRoutineTestListener::class.java)  
    }  
}
```