


## Intro


原文来自于 [Origin Blog](https://netflixtechblog.com/bending-pause-times-to-your-will-with-generational-zgc-256629c9386b)

> 	分代 ZGC

是 [jdk21](https://openjdk.org/projects/jdk/21/) 中已经 released 的关键技术, [JEP439-Generational ZGC](https://openjdk.org/jeps/439)



> Netflix 在一些业务上已经落地了 `Generational ZGC` 和 `Jdk 21`


- 最重要的一些 streaming. video services.  对于 `Netflix` 这种主要 流媒体公司而言确实是命脉
- 其中的一半已经落地了 `jdk21`



> 减少了 tail latencies



-  `tail latencies` 一般是指尾部延迟，其实就是 `95%`, `99%` 这样的业务指标, 用来作为 **高压情况下对性能响应体验的指标**
- `Netflix` 认为 `GC` 导致的 `stw` 会造成 `p99.99` 这种 尾部指标 飙高的情况，个人理解如下:
	- *尾部指标其实就是特别少的异常情况*, `GC ` 确实是每隔一段时间搞一次 ;
	- `GC` 造成的 `stw` 很难在 链路追踪系统中反应出来, 历史上经常碰见 链路追路部分卡了，但是不知道为啥，这个时候 **也许查询下 GC 日志否是 stw 是个好习惯** ;
	- 简单来说, `GC` 造成的流量，重试，延迟 都属于 **Nosie**, 噪音, 不能反应出系统真实的压力


> `Netflix` 的 `GC` 监控指标, 理解指标

- Allocation Rating: 对象的分配速率, 内存需求方
- CodeCache_GC_Threshold: `CodeCache 区域` GC的阈值.
- G1_Evacuation_Pause: 新生代GC 或者 MixedGC 使用复制算法把 存活的对象复制到新的 `Regioin`, 这个阶段是需要 `STW` 的，也是 `STW` 的主要原因
- `G1_Humongonuse_Allocation`:  需要为大对象找到连续的内存，需要短暂的 `STW` 来完成
- `GCLocker_Initited_GC`: 这种垃圾收集可能在处理了大量的Humongous对象或触发了GC Locker后启动, 比较特殊的机制
- `Metadata_GC` : 元数据的加载也会引发 GC
- ...

> Efficiency


最初的时候，`Netflix` 的工程师认为使用 分代 ZGC , 需要在 应用吞吐量（application throughput）和 `STW` 之间做出权衡 . 由于 `jvm` 的如下机制:

- `store and load barriers`
- `thread local handshakes`
- `gc completing with the application resources`
- ...


实际中，发现不需要做出太多的 `trade-off`, 因为在 `cpu` 利用率相等的前提下, 分代 `zgc` **在各种指标上都是完全的胜利**



> Operational Simplicity


- *这个表现是非常香的，也就是说在默认配置上，已经表现比之前都好了，基本不需要调优 就好的*.
- 之前没有分代的 `ZGC` 基本上全程并发，但是显然会增加 `CPU` 的使用率, 分代的 `ZGC` 个人理解是 集合了前面 大多数算法的优点


> Memory Overhead

