
## Refer

- [Oracle-javase-21-Virtual-Threads](https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html#GUID-2BCFC2DD-7D84-4B0C-9222-97F9C7C6C521)
- [Bell-Soft-how-to-use-virtual-threads-with-spring-boot](https://bell-sw.com/blog/a-guide-to-using-virtual-threads-with-spring-boot/)
- [Java 21-A Deep dive into Virtual Threads](https://mjovanc.com/java/java-21-a-deep-dive-into-virtual-threads/)

## 1-Intro

> History


[JEP_425](https://openjdk.org/jeps/425): Preview 版本 , `jdk19`
[JEP_436](https://openjdk.org/jeps/436): Second Preview ,  `jdk20`
[JEP_444](https://openjdk.org/jeps/444): Closed , `jdk21`



注意到:

- 之前的 `virtual-threads` 实现是可以不支持 `Thread-Local` 变量的 .  在 `jdk21` 之后就不可能了，这是为了更好的兼容性. 



> [!NOTE] Tips
> 这并不是代表 `ThreadLocal` 和 `Virtual-Thread` 一起使用就是合理的, 只是 `ScopeValue` 这个特性还没有 release 



> Goals: **兼容性**

- 一般的 协程实现，例如 `golang` `kotlin` 都是引入了新的 并发编程范式, 例如响应式编程 异步式函数. 
- 目前 `Java` 的 虚拟线程目标 仅仅是针对 **Thread-Per-Request** 这种范式.  所以我们目前也应该仅仅在这种范式下使用 `Virtual-Thread`, 其他的范式，继续 `wait` .
- 在 **Thread-Per-Request** 这种范式下 尽可能去减少 线程切换的成本就是  虚拟线程的目标


> 并发编程范式的小历史


- 对于内核而言, `KSE` 和线程的关系是 `1:1` 的,  `Java` 的 `Thread` 则是对 内核中 thread 的封装，也是个 `1:1` .  
- 线程本身的成本虽然没有那么昂贵，但还是有上限的
- **所以，oracle 的人得到了一个结论, Thread-per-request 的这种并发编程范式和 1:1 的线程实现 组合在一起是不合适的**, 虽然编程模型简单，但是 `scalability` 不行


所以，第一个解决方法 是换一个 编程范式, 例如 `Netty` 等等 其他的异步框架. 他们的思路是 **Improving Scalability with the asynchronous style** .

- 对某一个 `Request` 而言，不是从头到尾都是一个线程在处理.
- 在一个 `Request` 处理的过程中，如果要等待 `IO`, 直接把线程返回 线程池, 比如 `Netty` 把 `EventLoop` 还给 `EventLoopGroup` 
- **这种编程范式会增加复杂度，需要非常细粒度的操作**


> [!NOTE] Tips
> `Netty` 设计更加精妙，`IO` 结束的时候，重新去申请 `EventLoop` 的时候一定是 `Request` 注册的那一个，这种 无锁并发设计 被称为 **封闭模型**


第2个方法则是, `Jdk21` 的 虚拟线程则是希望在 不修改范式的同时增加性能和可伸缩性.


> Implications of Virtual threads


- 虚拟线程非常的便宜，往往不需要池化.



> Example


```kotlin
@Bean(destroyMethod = "shutdown")  
open fun inferTaskVPool(): ExecutorService {  
    val factory = Thread.ofVirtual().name("infer-task-v-pool-", 1).factory()  
    return Executors.newThreadPerTaskExecutor(factory)  
}
```
