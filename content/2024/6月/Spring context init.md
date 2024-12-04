


## 1-Intro


**1. 首先是初始化 BeanFactory**


- `BeanFactoryPostProcessor.postProcessBeanFactory`


> [!NOTE] Tips
> BeanFactory初始化之后，所有的Bean定义已经被加载，但Bean实例还没被创建（不包括`BeanFactoryPostProcessor`类型）。Spring IoC容器允许`BeanFactoryPostProcessor`读取配置元数据，修改bean的定义，Bean的属性值等。







**2. 然后要 调用 bean 构造器, 一般是无参构造器**

**3. Autowired 装配依赖**

- `AutowiredAnnotationBeanPostProcessor`



> [!NOTE] Tips
> Autowired是 借助于`AutowiredAnnotationBeanPostProcessor`解析 Bean 的依赖，装配依赖。如果被依赖的Bean还未初始化，则先初始化 被依赖的Bean。在 Bean实例化完成后，Spring将首先装配Bean依赖的属性




**4. 设置 Aware 逻辑**


- `BeanNameAware.setBeanName`
- `BeanFactoryAware.setBeanFactory`
- `ApplicationContextAware`
- `EnvironmentAware.setEnv..`
- `ResourceLoaderAware.setResoureLoader`



**5. Bean 初始化** 


> [!NOTE] Tips
> 单例 Bean 钩子，如果是 prototype 狗仔的话会在业务调用的时候 初始化.


- `BeanPostProcessor.postProcessBeforeInitlization`
- `PostConstuct`
- `InitializintBean`
- `init-method`
- `BeanPostProcessor.postProcessorAfterInitialization`



> [!NOTE] Tips
> 如果我想在 bean初始化方法前后要添加一些自己逻辑处理。可以提供`BeanPostProcessor`接口实现类, hook 掉 **postProcessBeforeInitialization**，然后注册到Spring IoC容器中。在此接口中，可以创建Bean的代理，甚至替换这个Bean。




**6. Bean 实例化完成 后置的处理逻辑**

- `SmartInitializingSingleton`
- `EventListener`



> [!NOTE] Tips
> 该接口的执行时机在 所有的单例Bean执行完成后。例如Spring 事件订阅机制的`EventListener`注解，所有的订阅者 都是 在这个位置被注册进 Spring的。而在此之前，Spring Event订阅机制还未初始化完成。所以如果有 MQ、Rpc 入口流量在此之前开启，Spring Event就可能出问题！





**7. Spring 启动完成**


- `SmartLifecycle` : 
- `Scheduled` ： 定时任务开始调度
- `ApplicationEvent` : 发布 `ContextRefreshedEvent`




> [!NOTE] Tips
> Http、MQ、Rpc 入口流量适合 在`SmartLifecyle`中开启




> [!NOTE] Tips
> `ContextRefreshEvent` 事件可能会发布多次，只要 调用过 ctx.refresh 方法，就会触发该事件




## 2-流量入口 demo


```kotlin
```kotlin
import org.apache.logging.log4j.LogManager
import org.apache.rocketmq.acl.common.AclClientRPCHook
import org.apache.rocketmq.acl.common.SessionCredentials
import org.apache.rocketmq.client.consumer.AllocateMessageQueueStrategy
import org.apache.rocketmq.client.consumer.DefaultMQPushConsumer
import org.apache.rocketmq.client.consumer.listener.MessageListenerConcurrently
import org.apache.rocketmq.client.consumer.rebalance.AllocateMessageQueueAveragely
import org.apache.rocketmq.common.consumer.ConsumeFromWhere
import org.springframework.beans.factory.DisposableBean
import org.springframework.beans.factory.InitializingBean
import org.springframework.context.SmartLifecycle
import java.util.concurrent.atomic.AtomicBoolean


/**
    * 参考配置:
    * https://rocketmq.apache.org/zh/docs/4.x/parameterConfiguration/01local#defaultmqpushconsumer%E9%85%8D%E7%BD%AE
    */
data class MqConsumerConfig(
                /**
                    * 消费者 group
                    */
                val consumerGroup: String,
                val namesrvAddr: String,

                /**
                    * 从哪里开始启动
                    */
                val consumeFromWhere: ConsumeFromWhere = ConsumeFromWhere.CONSUME_FROM_LAST_OFFSET,

                /**
                    * 负载均衡策略算法
                    *
                    * 默认是: 取模平均分配
                    */
                val allocateMessageQueueStrategy: AllocateMessageQueueStrategy = AllocateMessageQueueAveragely(),

                val topic: String,

                /**
                    * 具体参考 RocketMq 消息过滤语法: https://rocketmq.apache.org/zh/docs/featureBehavior/07messagefilter
                    */
                val tags: String = "*",

                /**
                    * 消费线程池的core size
                    */
                val consumeThreadMin: Int = 20,

                /**
                    * 消费线程池的max size
                    */
                val consumeThreadMax: Int = 64,

                /**
                    * 动态扩线程核数的消费堆积阈值
                    */
                val adjustThreadPoolNumsThreshold: Long = 100000L,

                /**
                    * 	一次最大拉取的批量大小
                    */
                val pullBatchSize: Int = 32,

                /**
                    * 批量消费的最大消息条数
                    */
                val consumeMessageBatchMaxSize: Int = 1,

                /**
                    * 一个消息如果消费失败的话，最多重新消费多少次才投递到死信队列
                    */
                val maxReconsumeTimes: Int = -1,

                /**
                    * 消费的最长超时时间, 单位分钟
                    */
                val consumeTimeout: Long = 15,


                )

open class MqPushConsumerBean(
                private val cfg: MqConsumerConfig,
                private val messageListener: MessageListenerConcurrently,
) : InitializingBean, SmartLifecycle {

                private lateinit var consumer: DefaultMQPushConsumer
                private var running = AtomicBoolean(false)

                override fun afterPropertiesSet() {
                                this.consumer = DefaultMQPushConsumer(
                                                AclClientRPCHook(
                                                                SessionCredentials(
                                                                                "yourKey",
                                                                                "yourSecret"
                                                                )
                                                )
                                ).apply {
                                                namesrvAddr = cfg.namesrvAddr
                                                consumerGroup = cfg.consumerGroup
                                                consumeMessageBatchMaxSize = cfg.consumeMessageBatchMaxSize
                                }

                                this.consumer.subscribe(cfg.topic, cfg.tags)
                                this.consumer.registerMessageListener(messageListener)
                                log.info("consumer init success")
                }

                companion object {
                                private val log = LogManager.getLogger(MqPushConsumerBean::class.java)
                }

                override fun start() {
                                this.consumer.start()
                                this.running.set(true)
                                log.info("consumer start success, cfg:{}", cfg)
                }

                override fun stop() {
                                this.consumer.shutdown()
                                this.running.set(false)
                                log.info("consumer stop success")
                }

                override fun isRunning(): Boolean {
                                return this.running.get()
                }

:
}
```


这里的 demo 是以 `rocketmq4.x` 的消费者作为例子.