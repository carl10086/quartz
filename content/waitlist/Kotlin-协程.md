

## 1-Quick Start


> 参考了 `Golang` 的设计


1. 轻量级线程(不是操作系统的线程，而是在运行的时候 动态由 `Golang` 的调度器去管理) ;
2. 目标是 并发的执行的函数
3. 没有显示的 暂停 恢复或者停止机制
4. 设计理念是 **通过分享内存来进行通信**

> Kotlin 的协程


1. **一切都是挂起**
2. 简化 **异步和回调** 编程: 类似 js 的 `Promise` 设计
3. 强大在 协程的 异常处理机制 和 父子协程 的管理特性


> Hello World

```kotlin
fun main() = runBlocking { // this: CoroutineScope
    launch { // launch a new coroutine and continue
        delay(1000L) // non-blocking delay for 1 second (default time unit is ms)
        println("World!") // print after delay
    }
    println("Hello") // main coroutine continues while a previous one is delayed
}

```


1. `lanuch` 是一个 协程的构建工具
2. `delay` 挂起函数, 暂停了 协程，而不是 **底层的线程**
3. `runBlocking` 是为了把 `main` 函数 桥接过来, 创建了一个 `CoroutineScope`, 这个代码如果没有了会直接运行报错, `lanuch` 一定要在一个 `CoroutineScope` 中运行， 也是 `Kotlin` 中的 **Structured Concurrency** 原则


> coroutineScope 和 runBlocking


1. 他们都会等待内部的 代码和所有的子协程完成
2. runBlocking 会阻塞当前 的调用方线程来实现, 也就是底层的线程也会阻塞住, 不能用于其他任务, 放弃了  `cpu` , 此时 **内核要主导 调度，有壳函数和内核状态的切换**
3. coroutineScope 则是 挂起，释放底层的线程, 也就是只有当前的 协程会被挂起, 底层的线程还在继续被使用, **此时 内核不用参与，纯用户态的操作，效率更高**

```kotlin
// Sequentially executes doWorld followed by "Done"

fun main() = runBlocking {
    doWorld()
    println("Done")
}

// Concurrently executes both sections
suspend fun doWorld() = coroutineScope { // this: CoroutineScope
    launch {
        delay(2000L)
        println("World 2")
    }

    launch {
        delay(1000L)
        println("World 1")
    }

    println("Hello")
}
```



## Refer

- [Loom And Kotlin Coroutine](https://www.youtube.com/watch?v=zluKcazgkV4)

- Jetty and loom:
	- https://webtide.com/if-virtual-threads-are-the-solution-what-is-the-problem/
	- https://webtide.com/jetty-12-virtual-threads-support/


