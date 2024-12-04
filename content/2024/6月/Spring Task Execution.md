


## Refer

- [Task Execution And Scheduling](https://docs.spring.io/spring-framework/reference/integration/scheduling.html)



## 1-Intro

> Spring 为 `Task` 抽象了2个基本的接口


- `TaskScheduler`: 调度
- `TaskExecutor`: 异步化

基于这个接口 支持.

- `JavaSE` 和 `Jakarta EE` 的兼容
- 支持 [CommonJ](https://docs.oracle.com/cd/E13222_01/wls/docs92/commonj/commonj.html)
- 支持 [Quartz Scheduler](https://www.quartz-scheduler.org/)





## 2-Task Executor



> executor 这个 `naming` 非常的通用，表明一个能进行. `execute` 的对象.


这意味着他的底层不一定是异步化的，线程池的. 可能是 **串行的**, 可能是 **单线程的** 等等 .


`Spring` 的 `TaskExecutor` 也是这样设计的:

- `SyncTaskExecutor`: 串行化执行，调用线程中执行
- `SimpleAsyncTaskExecutor`: 不会重复使用任何线程，而是每次调用都启动一个新的线程。尽管如此，它支持并发限制，超出限制的调用会被阻塞，直到一个线程空闲。如果你需要真正的线程池，可以参考`ThreadPoolTaskExecutor` 
- `ConcurrentTaskExecutor`: 适配 `Java` 的 `java.util.concurrent.Executor` 实例 , **让 原生的 Java 线程池自动拥有 spring 的部分特性**
- `ThreadPoolTaskExecutor` :这是最常用的实现。它通过Bean属性来配置`java.util.concurrent.ThreadPoolExecutor`，并将其封装在一个TaskExecutor中
- `DefaultManagedTaskExecutor` : 在JSR-236兼容的运行环境（例如Jakarta EE应用服务器）中，该实现使用通过JNDI获取的ManagedExecutorService来替代CommonJ的WorkManager




> [!NOTE] Tips
> 值得注意的是 `Spring 6.x` 的新特性: `ThreadPoolTaskExecutor` 提供了暂停/恢复功能以及通过Spring的生命周期管理进行优雅关闭的能力。另外，`SimpleAsyncTaskExecutor` 新增了对JDK 21虚拟线程（Virtual Threads）的支持，以及优雅关闭的能力



> 队列类型.

看了下源码实现如下:

```java
/**  
 * Create the BlockingQueue to use for the ThreadPoolExecutor. * <p>A LinkedBlockingQueue instance will be created for a positive  
 * capacity value; a SynchronousQueue otherwise. * @param queueCapacity the specified queue capacity  
 * @return the BlockingQueue instance  
 * @see java.util.concurrent.LinkedBlockingQueue  
 * @see java.util.concurrent.SynchronousQueue  
 */protected BlockingQueue<Runnable> createQueue(int queueCapacity) {  
  if (queueCapacity > 0) {  
   return new LinkedBlockingQueue<>(queueCapacity);  
  }  
  else {  
   return new SynchronousQueue<>();  
  }  
}
```

- 非常贴心



> 有一些更灵活的参数，例如:


1. `setAllowCoreThreadTimeOut(boolean allowCoreThreadTimeOut)`
	• **作用**：允许核心线程在空闲时超时退出。这使线程池能够在任务量减少时自动收缩。
	• **默认值**：false（核心线程不会超时退出）。
	• **示例**： `executor.setAllowCoreThreadTimeOut(true);`

2. `setPrestartAllCoreThreads(boolean prestartAllCoreThreads)`
	• **作用**：在初始化线程池时预启动所有核心线程，使它们空闲等待任务。
	• **默认值**：false（按需启动核心线程）。
	• **示例**： `executor.setPrestartAllCoreThreads(true);`

3. `setStrictEarlyShutdown(boolean strictEarlyShutdown)`

	• **作用**：在上下文关闭时立即发出早期关闭信号，清理所有空闲线程并拒绝进一步的任务提交。此设置控制是否在上下文关闭时触发显式的ThreadPoolExecutor.shutdown()调用。
	• **默认值**（截至6.1.4）：false（宽松地允许在上下文关闭后接收迟到的任务，仍参与生命周期停止阶段）。
	• **示例**： `executor.setStrictEarlyShutdown(true);`
	

4. `setTaskDecorator(TaskDecorator taskDecorator)`

	• **作用**：指定一个自定义的TaskDecorator，用于装饰即将执行的任务。主要用途包括在任务执行之前设置执行上下文，或提供一些监控/统计信息。
	• **示例**：
```java
executor.setTaskDecorator(task -> {
    return () -> {
        // 在这里可以添加一些逻辑，例如日志
        task.run();
    };
});
```


5. `createQueue(int queueCapacity)`

	• **作用**：创建用于ThreadPoolExecutor的BlockingQueue。对于正容量值，创建LinkedBlockingQueue；否则，创建SynchronousQueue。

	• **示例**：
```java
protected BlockingQueue<Runnable> createQueue(int queueCapacity) {
    if (queueCapacity > 0) {
        return new LinkedBlockingQueue<>(queueCapacity);
    } else {
        return new SynchronousQueue<>();
    }
}

```


6. `setStrictEarlyShutdown(boolean strictEarlyShutdown)`
	• **作用**：在Spring应用上下文关闭时立即发出关闭信号，清理所有空闲线程并拒绝进一步的任务提交。
	• **默认值**：false（截至6.1.4版本，宽松模式允许在上下文关闭后接收迟到的任务，仍然参与生命周期停止阶段）。
	• **影响**：
		• 当设置为true时，线程池在上下文关闭时将立即调用ThreadPoolExecutor.shutdown()，拒绝新的任务提交，并等待在执行的任务完成。
		• 宽松模式（默认值false）则允许在关闭信号发出后接收迟到的任务，并以参与生命周期停止阶段的方式处理任务，使应用程序有更长的时间来完成任务。


**优雅关闭线程池**

优雅关闭线程池确保在关闭时能够完成所有已提交的任务，并在关闭过程中释放资源。具体步骤和配置如下：

**主要参数**

1. `setWaitForTasksToCompleteOnShutdown(boolean waitForTasksToCompleteOnShutdown)：`
	• **作用**：在关闭线程池时是否等待已提交的任务完成。
	• **默认值**：false
	• **示例**： `executor.setWaitForTasksToCompleteOnShutdown(true);`

2.  `setAwaitTerminationSeconds(int awaitTerminationSeconds)：`
	• **作用**：设定线程池关闭时的最大等待时间（单位：秒），如果超过这个时间，则强制关闭。
	• **默认值**：0（不等待）
	• **示例**： `executor.setAwaitTerminationSeconds(60);`



> 如果想要更高级的定制化，可以通过 继承覆盖掉他的方法. 比如你想换一些更高级的 队列，例如 JuTools 中的一些工具类


```kotlin

class CustomThreadPoolTaskExecutor(
    private val workQueue: BlockingQueue<Runnable>
) : ThreadPoolTaskExecutor() {

    override fun initializeExecutor(
        threadFactory: ThreadFactory,
        rejectedExecutionHandler: RejectedExecutionHandler
    ): ExecutorService {
        return ThreadPoolExecutor(
            corePoolSize,
            maxPoolSize,
            keepAliveSeconds.toLong(),
            TimeUnit.SECONDS,
            workQueue,
            threadFactory,
            rejectedExecutionHandler
        )
    }
}

```


> 工具类简单封装


```kotlin
/**  
 * 构建一个 spring 的 ThreadPoolTaskExecutor. 行为还是和 java 的类似.  
 * 1. 先填充 core * 2. 然后扔到队列  
 * 3. 队列满了再创建，一直到 max * 4. max 达到后就走拒绝策略  
 *  
 * @param threadNamePrefix: 线程名称前缀  
 * @param corePoolSize: 设置核心线程数，即线程池保持的最小线程数量。即使没有任务需要执行，这些线程也会保持存活  
 * @param maxPoolSize: 设置最大线程数。线程池能够容纳的最大线程数量  
 * @param queueCapacity: 设置队列能容纳的最大任务数量  
 * @param rejectPolicy: 拒绝策略  
 */  
fun buildThreadPoolTaskExecutor(  
    threadNamePrefix: String,  
    corePoolSize: Int,  
    maxPoolSize: Int = corePoolSize,  
    queueCapacity: Int,  
    keepAliveTime: Duration = Duration.ofMinutes(30L),  
    rejectPolicy: RejectedExecutionHandler? = null,  
): ThreadPoolTaskExecutor {  
    val rejectedExecutionHandler = rejectPolicy ?: RejectedExecutionHandler { _, executor ->  
        val msg = "Thread Pool is EXHAUSTED ! ThreadNamePrefix : $threadNamePrefix , Detail: $executor"  
        logger.error(msg)  
        throw RejectedExecutionException(msg)  
    }  
    return ThreadPoolTaskExecutor().apply {  
        /*设置核心线程数，即线程池保持的最小线程数量。即使没有任务需要执行，这些线程也会保持存活*/  
        this.corePoolSize = corePoolSize  
        /*设置最大线程数。线程池能够容纳的最大线程数量*/  
        this.maxPoolSize = maxPoolSize  
        /*设置线程的存活时间。当线程数大于核心线程数时，多余的空闲线程在终止之前等待新任务的最长时间*/  
        this.keepAliveSeconds = keepAliveTime.toSeconds().toInt()  
        /*前缀*/  
        this.threadNamePrefix = threadNamePrefix  
        this.queueCapacity = queueCapacity  
        this.setRejectedExecutionHandler(rejectedExecutionHandler)  
        this.setStrictEarlyShutdown()  
    }  
}
```


然后下面是2个例子，分别是虚拟线程和线程池.

```kotlin
    @Bean  
    open fun triggerTaskExecutor(  
        /*todo ， change name*/  
        @Value("\${pool.inferTask.size}") poolSize: Int,  
        @Value("\${pool.inferTask.queue}") queueSize: Int,  
    ): TaskExecutor = SpringJucUtils.buildThreadPoolTaskExecutor(  
        "trigger-Task-Executor-Pool-%d",  
        corePoolSize = poolSize,  
        queueCapacity = queueSize  
    )  
  
    @Bean  
    open fun inferTaskVPool(): TaskExecutor {  
        val executor = SimpleAsyncTaskExecutor()  
        // 启用虚拟线程  
        executor.setVirtualThreads(true)  
        // 设置线程名称前缀  
        executor.threadNamePrefix = "infer-task-v-pool-"  
        return executor  
    }
```