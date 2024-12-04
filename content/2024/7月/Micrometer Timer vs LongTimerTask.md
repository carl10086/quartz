

## Refer

- [micrometer](https://micrometer.io/)
- [Spring3-with-Observability](https://spring.io/blog/2022/10/12/observability-with-spring-boot-3)


## 1-Quickstart


> Spring Boot actuator starter 会自动配置一个 MeterRegistry.


我们可以做一些定制化.

```java
@Bean
public MeterRegistryCustomizer<MeterRegistry> custom() {
	return registry -> registry.config().commonsTags("region", "us-east-1");
}
```


> 核心还是 Meter 这个统计本身的一些概念.


Micrometer supports a set of `Meter` primitives, including `Timer`, `Counter` , `Gauge`, `DistributedSummary` , `LongTaskTimer`, `FunctionCounter`, `FunctionTimer`, and `TimeGauge` .

Different meter types result in a different number of time series metrics. For example, while there is a single metrics that represent a `Guage`, a `Timer` measures both the count of timed events and the total time of all timed events.

> Rate Aggregation


有2类做聚合的大思路:


1. 客户端聚合: 客户端提前计算好速率，直接把值发送给 监控系统, **为了减少监控系统本身的负担**
2. 服务端聚合: 客户端发送原始数据，监控系统进行 **实时的聚合计算**, 例如 `promethus` 这方面就比较成熟


## 2-Timed Example


我们用一个简单的例子来说明他的工作原理.

> 代码集成.

- 使用 `SpringBoot Actuator`  + `Promethues`
- 使用 `TimedAspect` 注解.

```kotlin
@Bean  
open fun timedAspect(registry: MeterRegistry) = TimedAspect(registry)
```

- 开启切面集成

```kotlin
@Timed("sync_scheduler", extraTags = ["fun", "syncRobots"])  
fun syncRobots() {  
    this.syncRobotHandler.syncAllRobot()  
}
```


- 观察指标
```
# HELP sync_scheduler_seconds  
# TYPE sync_scheduler_seconds summary
sync_scheduler_seconds_count{application="ai-chat-job",class="com.aitogether.ai.chat.job.infra.scheduler.SyncScheduler",exception="none",fun="syncRobots",method="syncRobots",} 1.0
sync_scheduler_seconds_sum{application="ai-chat-job",class="com.aitogether.ai.chat.job.infra.scheduler.SyncScheduler",exception="none",fun="syncRobots",method="syncRobots",} 5.394783584
# HELP sync_scheduler_seconds_max  
# TYPE sync_scheduler_seconds_max gauge
sync_scheduler_seconds_max{application="ai-chat-job",class="com.aitogether.ai.chat.job.infra.scheduler.SyncScheduler",exception="none",fun="syncRobots",method="syncRobots",} 5.394783584
```


有3个指标:
1. `sync_scheduler_seconds_count`: 代表运行的次数
2. `sync_scheduler_seconds_max`: 最大值
3. `sync_scheduler_seconds_sum`: 代表的是运行的总时长


注意到这里指标是有时间窗口的，否则你只能看见你的 `max` 统计永远在上升.

为了搞清楚这个问题，我们去看 [官方文档](https://docs.micrometer.io/micrometer/reference/concepts/timers.html)


> Timers doc

聚合了一堆 `repsoneseTime` 和 `qps` 相关的指标.

其中, `count` 和 `sum`,  可以配合 `promethus` 的 `rate` 或者 `irate` 函数统计出 `qps`, 平均调用时间等等.

而 `max`  的实现中则考虑了 **时间窗口**. 例如 `StepTimer` 和 `CumulativeTimer` . 否则 **监控会受到老的统计指标的干扰, 根本反应不了线上的实时性能**. 

注意 `percentile` 和 `histogram` 也是一样的设计.



> [!NOTE] Tips
> 如何计算时间窗口的大小呢，跟具体的实现有关，比如 `Promethus`, `1min` 还是 `3min`, 我们去分析源码


`Promethus` 修改了默认配置. `steps` 为 `1min`. 

```java
/**  
 * @return The step size to use in computing windowed statistics like max. The default  
 * is 1 minute. To get the most out of these statistics, align the step interval to be * close to your scrape interval. */default Duration step() {  
    return getDuration(this, "step").orElse(Duration.ofMinutes(1));  
}
```


继续看 `StepTimer` 源码.

```java
public TimeWindowMax(Clock clock, long rotateFrequencyMillis, int bufferLength) {  
    this.clock = clock;  
    this.durationBetweenRotatesMillis = checkPositive(rotateFrequencyMillis);  
    this.lastRotateTimestampMillis = clock.wallTime();  
    this.currentBucket = 0;  
  
    this.ringBuffer = new AtomicLong[bufferLength];  
    for (int i = 0; i < bufferLength; i++) {  
        this.ringBuffer[i] = new AtomicLong();  
    }  
}
```

- `ringBuffer` 是一个 `AtomicLong[]` 数组，每个都是按照上面配置的时间窗口来的 `1min`.
- `bufferLength=3`
- 为什么采用多个窗口的设计?
	- 更加的平滑? 存储是 `1min`


虽然有3个, 但是延迟，和上报的最近的那 `1min`. 


```java

private void record(long sample) {  
    rotate();  
    for (AtomicLong max : ringBuffer) {  
        updateMax(max, sample);  
    }  
}

private void updateMax(AtomicLong max, long sample) {  
    long curMax;  
    do {  
        curMax = max.get();  
    }  
    while (curMax < sample && !max.compareAndSet(curMax, sample));  
}
```


- 记录的时候会 `for 循环全部的3个 ringBuffer`, 所以是3个时间窗口中的最大值. 这种设计 **个人理解 非常的细.**
	- 新窗口的值会影响前2个老窗口的值. 如果更大的话.
	- 老窗口的值不会影响新窗口的值，最终上报的还是 最近 `1min` 的最大值.
	- 这种设计可能是有意的， 用来平滑过渡短期波动，保留最大的峰值一段时间，一共是3个窗口.

所以回到问题，记录的是最新 1min 的最大值.



## 3-Other metrics

> [LongTimerTask](https://docs.micrometer.io/micrometer/reference/concepts/long-task-timers.html)

**主要用途**：
▪ LongTaskTimer 专门用于测量长时间运行的任务。
▪ 适用于那些可能需要几秒、几分钟甚至更长时间才能完成的任务。


**原理**
- 之前的 `Timer` 在完成的时候才会更新时间，而 `LongTimerTask` 会在运行的时候就更新时间.
- 他是实时的，之前的任务如果完成了，会继续停留，`LongTimerTask` 仅仅关注当前正在运行的任务



如果要 `LongTaskTimer` 要生效，代码要异步化.


```kotlin
/**  
 * 配置一个单独的 调度器  
 */  
@Scheduled(fixedRate = 5, timeUnit = TimeUnit.MINUTES, initialDelay = 0L)  
fun syncRobots(): CompletableFuture<Void> {  
    return CompletableFuture.runAsync {  
        this.syncRobotHandler.syncAllRobot()  
    }  
}
```