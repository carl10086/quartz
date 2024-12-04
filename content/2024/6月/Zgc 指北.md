

## 1-Intro


`ZGC` 由 `JDK11` 的.[JEP333](https://openjdk.org/jeps/333)  [引入](https://docs.oracle.com/en/java/javase/11/gctuning/z-garbage-collector1.html#GUID-A5A42691-095E-47BA-B6DC-FB4E5FAA43D0), 并在 `JDK15` 的 [JEP377](https://openjdk.org/jeps/377) 中 `RELEASED`. 然后在 `JDK21` 中引入了分代 `ZGC`.

详细历史如下:


**JDK 21**


- Support for generations (-XX:+ZGenerational) ([JEP 439](https://openjdk.org/jeps/439))

**JDK 18**

- Support for String Deduplication (-XX:+UseStringDeduplication)
- Linux/PowerPC support
- Various bug-fixes and optimizations

**JDK 17**

- Dynamic Number of GC threads
- Reduced mark stack memory usage
- macOS/aarch64 support
- GarbageCollectorMXBeans for both pauses and cycles
- Fast JVM termination


**JDK 16**

- Concurrent Thread Stack Scanning ([JEP 376](http://openjdk.java.net/jeps/376))
- Support for in-place relocation
- Performance improvements (allocation/initialization of forwarding tables, etc)

**JDK 15**

- Production ready ([JEP 377](http://openjdk.java.net/jeps/377))
- Improved NUMA awareness
- Improved allocation concurrency
- Support for Class Data Sharing (CDS)
- Support for placing the heap on NVRAM
- Support for compressed class pointers
- Support for incremental uncommit
- Fixed support for transparent huge pages
- Additional JFR events

**JDK 14**

- macOS support ([JEP 364](http://openjdk.java.net/jeps/364))
- Windows support ([JEP 365](http://openjdk.java.net/jeps/365))
- Support for tiny/small heaps (down to 8M)
- Support for JFR leak profiler
- Support for limited and discontiguous address space
- Parallel pre-touch (when using -XX:+AlwaysPreTouch)
- Performance improvements (clone intrinsic, etc)
- Stability improvements

**JDK 13**

- Increased max heap size from 4TB to 16TB
- Support for uncommitting unused memory ([JEP 351](http://openjdk.java.net/jeps/351))
- Support for -XX:SoftMaxHeapSIze
- Support for the Linux/AArch64 platform
- Reduced Time-To-Safepoint

**JDK 12**

- Support for concurrent class unloading
- Further pause time reductions

**JDK 11**

- Initial version of ZGC
- Does not support class unloading (using -XX:+ClassUnloading has no effect)


## 2-GC Concepts

> Memory Management: 快速回滚内存基础


虚拟内存系统由 `OS` 提供:

- 每个进程眼中都是连续的逻辑视图, `MMU`
- 通过缺页异常触发 物理内存的分配
- 硬件加速机制 是从硬件层面上去优化 虚拟内存的管理效率
- `TLB`: `Translation Lookaside Buffer` 是一种 高速的缓存，用来缓存最近使用的 页表条目,  用来提升 地址转换的速度


下面是 `ZGC` 中用到的核心机制.

> 染色指针: `Colored Pointer`

一种可以让指针 保存额外信息的技术。

染色指针（Colored Pointer）是一种技术，使得指针可以保存额外的信息。

在 JVM 中，一个对象的地址不仅仅是内存地址，它也包含额外的信息来表示垃圾回收过程中对象的状态。在 ZGC 中，如下指针布局被使用：

-  地址的前 42 位用于存储对象的实际内存地址。
-  地址的第 43 至第 46 位用来存储额外信息，以指示对象在 GC 中的状态：
  - 第 43 位 (`marked0`): 标记阶段的标志位。
  - 第 44 位 (`marked1`): 另一个标记阶段的标志位。
  - 第 45 位 (`remapped`): 重映射的标志位。
  - 第 46 位 (`finalizable`): 表示对象是否需要执行最终清理操作。

这种设计是因为在 Linux 系统上，当前的物理地址空间支持高达 46 位，即 64TB 的内存。

**所以染色指针的意思是指 linux 给了 46bit 作为指针，但是我们仅仅使用 43bit 作为指针，剩下3个自己用, 优点就是每个指针能包含额外信息，缺点就是 支持的内存上线更小了?**


> read barrier

这种技术就 可以让 `JVM` 直接向 应用代码中插入一小段代码的 钩子技术. 钩子的触发时机是 线程从堆中读取对象的时候.

**主要用来改写每个地址的命名空间, 或者称为非常大RTX3企鹅窝GVa's'z'T'y'T'T'T'T'T'x**

> 多重映射: Multi-Mapping


-  `ZGC` 核心之一就是利用了多重映射技术.
- 多重映射就是 让一个 物理内存地址可以被 一个相同的 虚拟内存地址 映射. 然后 `OS` 可以通过 `page table` 来管理这个关系


> Relocation : 用来减少内存碎片

**运行的时候很容易有碎片**: 让内存变的不连续，有间隙.

- **对象分配和释放**: 一个应用程序在运行过程中，会不断请求内存来创建对象，并在不再需要这些对象时释放内存。这些操作会在内存中形成一个个被使用和空闲的区域
- **间隙的形成**: 当一个对象在内存中被释放时，它占据的内存变为空闲，但这些空闲的空间可能分布在已使用内存的中间。例如，我们释放了内存中间的一个对象 O1，那么这部分内存现在为空闲状态
- **累积效应**: 随着时间的推移，多个对象的分配和释放会在内存中形成多个小的空闲区。这些空闲区和使用区交替排列，造成整个内存看起来像一个棋盘

**第一种减少内存碎片化的策略:**
- 使用 `new object`  来填充间隙
- 这种策略需要 昂贵的内存扫描

`relocation` 是一种策略，解决在 动态分配内存 造成的内存碎片化，不连续的问题.

一般用2种思路来 缓解这个问题:

1. 间隙中填充新对象，这个操作太昂贵，不现实，需要你为这个新对象扫描合适的 `gaps`
2. 复制:
	- 类似于 `G1` 的 `Regions`, `ZGC` 会使用并发的，把碎片化的内存对象移动到新的，更加紧凑的内存区域，为了提高效率，`ZGC` 会把内存划分为 `blocks`, 它们要不完全为空，要不完全的使用.


> GC: 三色标记和 引用链

> GC phases 的 naming

- **parallel phases** : 可以并行的运行多个线程进行 当前阶段
- **serial** : 单线程运行当前阶段
- **stop-the-world**: 应用必须终止，不能并发
- **concurrent**: 可以并发，后台运行当前阶段
- **incremental**: 当前阶段的工作如果这个时候没有做完，可以直接停止，下次增量继续


> ZGC 的目标是为了尽可能的减少 STW 的时间, 哪怕是超大内存.




## 3-G1 回顾

[[JVM gc]]

G1 在 JDK7 的时候开发出来，JDK8 直接称为了默认的回收器, 对比 `CMS`.

- `G1` 可以 解决内存的碎片化
- `G1` 可以提供可以可预测的停顿，`-XX:MaxGCPauseMillis=50`

`G1` 被称为功能最全的 垃圾回收器，到 `JDK11` 时代又再次有了巨大的提升, 可以参考 [[Uber Presto G1 jvm 调优实践]], 可以进一步保证有足够的动态内存去做并发回收 ;


> Region 的内存划分

- `1-32M` 的 region 大小
- 每个 `region` 可以是任何角色，`eden` `survior` `old` `Humongous`
- 这会导致每个代可能 是不连续的，至少物理上是不连续的 

> Humongous

专门用来放大对象的，之前的大对象会直接去 `Old`, `G1` 做的更细致一些，会有专门的标记. 

什么是大对象? 对象的大小超过 **REGION 的一半**.

大对象如果活的长, 容易出事,复制成本高, 而且容易引发 `FullGC`, 个人认为哪怕 `G1` ，去寻找连续的 Humongous 区给大对象，也有可能找不到，从而引发 `FullGC` . 

> Card Table: 卡表


- `Card Table` 是内部的结构划分, 每个 `Region` 内部会划分为若干的内存块, 被称为 `Card`. 这些 `card` 组成的集合被称为 `Cartable` . 

- 例如一个 `region1` 被划分为 9个 `card`, 那么他们加起来就成为 `CardTable`


> 之所以这么细，是因为还有其他的结构, 例如 `RSET`: `RememberSet`


- `RSet` 是一个 `hash` 表: 用来加速 `region` 间的引用关系查找, 甚至是 跨代引用
	- `key` 是 引用了当前 `region` 的其他的 `region` 的其实地址
	- `value` 则是 当前 `region` 被引用的 `card` 的索引位置

**跨代引优化逻辑** :

有这么一种情况，新生代的对象 A 被老年代的对象 B 引用了 , B -> A  .

我们想去扫描所有的新生代对象, 这个时候通过 `GC_Roots` 要先找到这个老年代对象 B，才能找到 这个 A. 

如果有 RSets 存在，GC Root Tracing 在扫描的时候 **如果碰见老年代对象** 就会先放弃这条扫描路径，在整个的 GC Root Tracing 后, 会去遍历新生代 `Region` 的 `RSet`, 如果他的 `key` 也就是说引用它的是 老年代的 `Region` , 就判定它存活. 

很明显上面的不会错杀，但是会漏杀，因为 B 可能是要回收的, **这也就是 G1 的问题： 新生代扫描精度不够，会漏掉一些**.

这部分内容会留给老年代的垃圾回收 `mixed GC` 来回收. 


> G1 的 YoungGC 流程

1. `stop the world`, 控制 `young gc` 开销的办法有2个, 减少 young region 个数 或者 提高 `young gc` 的并行度 ;
2. 扫描 `GcRoots` , 如果 **碰见了老年代对象就中止这个链路**, 然后通过 `RSet` 中的 `key` 指向老年代的卡表中识别出来, **避免了对老年代的整体扫描** ;
3. 排空 `dirty card queue`, 更新 `RSet`, `RSet` 中记录了哪些对象可以被老年代跨代引用, `RSet` 更新跨代引用信息的方式不是立即发生的, 会有线程的并发问题, 为了优化这个并发, 每个 线程自己更新跨代引用信息的时候，会首先写到线程私有的 `dirty card queue` ;
4. 扫描 `Rset`, 扫描所有 `RSet` 中 `Old` 区中到 `young` 区的引用, 这里就确定了 哪些 `young` 对象是存活的 ;
5. 拷贝对象到 `survivor` 区域或者 晋升 `old` 区域 ;
6.  处理引用队列， 软引用，弱引用，虚引用 ;


> 三色标记算法

G1 对老年代的垃圾回收是 `Mixed GC`. 老年代用的是 可达性分析算法 - 三色标记. 

**三色:**

- 白色: 不可达
- 灰色: 当前对象被可达，但是它的 `Field` 还没有检查是否可达
- 黑色: 对象被检查，可达了, 其中的 `Field` 也可达了

**类似层序遍历**

**并发问题**

因为老年代是 并发的，三色标记法也是很适合并发，这个时候用户线程和 gc 线程交替进行, 还是会出现 **漏标** 

- 假设:
	- `D` 被 `B` 引用，还没有被检查到
	- 这个时引用关系 发生了变化,  `D` 被 `A` 引用, `A` 已经检查完了，变成了黑色
	- `B` 检查的时候发现不了 `D` 
	- **D** 会认为不可达, 实际上是可达的，这非常的危险!
- 黑色对象 `B` 新引用 一个 **新创建对象 A**

解决 已经存在的对象被漏标的2种手段:

- 原始快照: `(Snapshot At the Begining)` : 当任意的灰色对象到白色对象的引用被删除的时候，记录下这个被删除的引用, 并默认这个被删除的 引用是存活的， 也可以理解为 **整个的检查过程中的引用关系以检查开始的那一刻为准，防腐有一个快照**
- 增量更新: (`Incremental Update`) : 任何被移除的引用（即某对象的引用被删除或者转移）都会被记录，确保垃圾回收器不会遗漏这些对象. 具体的说，当任何灰色对象被新增一个到白色对象的引用的时候，记录下发生引用变更时候的黑色对象，将他重新改变为灰色对象，重新标记，这个算法也是 `CMS` 采取的算法

写屏障技术:

- 记录引用变更的技术，类似 `AOP`, 只是在 `JVM` 底层， 任何引用变更都会触发这段代码，记录下发生变更的引用, 理解上类似 `binlog` 会发生任何修改的时候记录日志, `JVM` 在引用关系变化的时候也一样 .


解决新产生的对象被漏标如何解决? 增量更新.

> SATB 技术详解:

- `TAMS`: Top-at-mark-start, 在 `region` 中的双指针, `prevTAMS` 和 `nextTAMS` 
- `nextTAMS` 位置以上的，都会被认为是存活的对象.
- todo 


> Mixed GC

整体上理解分为2个大步骤:

- `global concurrent marking`: 全局并发标记
- `evacuation`: 拷贝存活对象.



> Mixed GC 1 - Initial marking

主要工作: 
- `GC Roots` 扫描所有可达的对象
- 伴随着 `youngGC` 去处理跨代引用
	- `youngGC` 也需要 `stw`, 这一步也需要 `stw`, 大家共享一个 `stw`， 多好 ;
	- 之前 `youngGc` 处理跨代引用会使用 `RSet` 所以 精确度不高 ;
	- 这里再次 `youngGC` 不会使用 `RSet` 来处理跨代引用, 所以精确度高 


次要工作:

- 初始化一些参数 ，后面的并发标记需要用到如下的指针, 下面的指针就是用来标记哪些对象存活的，哪些对象是死亡的
	- 将 `bottom` 指针赋值给了 `prevTAMS` 
	- `top` 指针赋值给 `nextTAMS` 指针: `top` 是指向卡表的指针
	- 清空了 `nextBitMap` 指针


下面给个图. todo


> Mixed GC 2 - Root Region Scan


在 `stw` 之后和新生代 `GC` 之后, 这个时候新生代的 `eden` 对象要不死了，要不成功晋升到 `suvrivor` 区域. 

我们为了要解决跨代引用，我们会扫描 `survivor` 区域, **为了知道哪些 老年代对象被 S区域的对象引用**, 这一步的耗时很短


> Mixed GC3 - Concurrent Marking


原理很简单: 并发的从 `GC-Roots` 中开始扫描，三色标记找到 所有要清理的对象 ;
代码很复杂: **因为过程是并发的**， 要保证 `SATB` 的语义下所有与指针的细节 ;

todo 


> Mixed GC4 - Final remark


处理并发标记之中发生引用关系修改的对象.  **需要 STW**.

- `satb mark queue` 中引用发生了更改的对象找出来

> Mixed GC5 - cleanup
 **也是并发**
- `G1` 的 `region` 优势出来了，会对每个 `region` 的回收价值和成本进行评估和排序 
- 根据用户配置的 最大 `pause` 时间 来确定回收计划
- 这里不会 开始清理，而且标记出 选出部分 `old region` 和全部的 `young region`, 组合起来称为 `Collection Set`


- `G1` 是可以根据内存的变化自己调整各个 `Region` 的大小
- 如果某些分区中，比如说 `YOUNG - Region` 增长的比较快，说明这个分区的内存访问更加频繁


> evacuation

标记结束之后剩下的就是 转移 `evacuation`, **拷贝** 存活对象到空的 `region` . 
- 这里的步骤会 `STW` ，使用多线程的方案去复制.


> G1 点评

- 使用大佬的额外结构来存储引用关系, 据说极端的情况会有 `20%` ;
- 非常成熟的算法，这些额外的数据结构可以极大的提高 标记的效率 ;
- 回收算法，尤其是 `jdk11` 之后能明显的降低 `fullGC` 的频率 ;
- 极大的降低了之前 `GC` 算法配置和优化的复杂度，比如说可以自动的调整 `O` 和 `E` 的容量 ;
- 多线程的复制算法，不会有碎片;


## 4-Zgc

> ZGC Intro

`ZGC` 的介绍就看上去很厉害

- `ZGC` 基本全程并发, 造成的最大 `stw` 不会超过 `1ms` .
- 停顿时间 和 堆大小无关，官方认为 百`M` 到 `16TB` 都表现良好


At a glance, ZGC is :

- Concurrent
- Region-based: 跟 `G1` 一样，有 `Page` 的概念，不同的是大小不是固定的, 有小型，中型，和大型
- Compacting: 不会有碎片
- Numa-aware: zgc 在架构上就能会主动去感知 `NUMA`
- Using colored pointers: 使用了染色指针，没有记错的话，是 `jvm`  使用了 `46bits`, `42bits` 用来做指针, 剩下4个用来表示当前的 `GC` 状态 
- Using store barriers: 使用了内存屏障，没记错的话，是 jvm 底层一种像 应用程序植入逻辑的骚操作，在应用程序从堆中获取对象的时候触发.



> 类似 `Region`, zgc 也把内存分为了 `page`, 作为区分.  `page` 有三种, 区分是按照每个 page 的大小，里面存储的单个对象的区间

1. 小型 `page` : `small page`， 容量 `2m`, 对象: `<256k`
2. 中型 `page`: 容量 `32M`, 用来存放对象: `>= 256k && < 4m`
3. 大型 `page`: 动态，但是是 `2M` 的整数倍


> 跟 G1 一样, 找到垃圾的 复杂程度 远远大于 回收垃圾.



## 5-zgc in practise

> Quick Start


```bash
-XX:+UseZGC -XX:+ZGenerational -Xmx<size> -Xlog:gc*
```

ZGC has been designed to be adaptive and to require minimal manual configuration. During the execution of the JAVA program, ZGC dynamically adapts to the workload by resizing generations, scaling the number of GC threads, and adjusting tenuring thresholds. The main tuning knob is to increase the maximum heap size.

ZGC comes in two versions: 

- The new, generational version and the leacy, non-generation version.

The Non-generational ZGC is the older version of ZGC, which doesn't take advantage of generations to optimize its runtime characteristics. 

It is encouraged that users transition to use the newer Generational ZGC.


> Setting Heap size


The most important tuning option for ZGC is setting the maximum heap size, which you can set with -Xmx, Because ZGC is a concurrent collector, you must set a maximum heap size such that the heap can accommodate the live-set of your application and there is enough headroom in the heap to allow allocations to be serviced while the GC is running. How much headroom is needed very much depends on the allocation rate and the live-set size of application. In general, the more memory. you give to ZGC the better. But at the same time, wasting memory is undesirable, so it's all about to finding a balance between memory usage and how often the GC needs to run.


ZGC has another command-line option related to the heap-size named: `-XX:SoftMaxHeapSize` It can be used to set a soft limit on how large the Java heap can grow. ZGC will strive to not grow beyond this limit, but is still allowed to grow beyond this limit up to the maximum heap size. 

ZGC will only use more than the soft limit if that is needed to prevent the Java application from stalling and waiting for the GC to reclaim memory. For example, with the command-line options -`Xmx5g -XX:SoftMaxHeapSize=4g` will use `4GB` as the limit for its heuristics, but if it can't keep the heap size below 4GB it is still allowed to temporarily use up to 5GB. 

> Setting Concurrent GC Threads

**Note**: 这是关于ZGC 非分代版本的调优建议。分代版本的 ZGC 具有更强的自适应能力，因此通常不需要调整 GC 线程数。

ZGC 提供了设置并发 GC 线程数的选项，通过 `-XX:ConcGCThreads=<number>` 可以进行配置。ZGC 有默认的启发式算法来自动选择适当的线程数，这个算法在大部分情况下都能很好地工作，但对于某些特定的应用特性，可能需要手动调整。
设置并发 GC 线程数的考虑因素
	1.	过多的 GC 线程数：
	▪	给 GC 分配过多的线程数会导致它占用太多的 CPU 时间，从而影响应用程序的性能。
	2.	过少的 GC 线程数：
	▪	除非应用程序分配垃圾的速度超快，否则分配过少的线程数可能会导致 GC 无法及时收集垃圾，进而影响应用的内存使用和性能。
	
JDK17 及以后版本的改进
从 JDK17 开始，ZGC 会动态地调整并发 GC 线程数。这意味着在大多数情况下，不需要手动调节并发 GC 线程数。ZGC 会根据实际情况自适应地增加或减少 GC 线程数，从而更高效地利用 CPU 资源。
系统资源利用的最佳实践
	•	保持低延迟：如果应用程序对低延迟（即低响应时间）有严格要求，确保系统不要过度供给资源。理想情况下，CPU 利用率不应超过 70%。这样可确保有足够的资源用于突发工作负载，并减少 GC 线程与应用程序线程之间的资源竞争。

java -XX:+UseZGC -Xmx5g MyApp
总之，对于现代的 ZGC 尤其是从 JDK17 开始，绝大多数情况下不需要手动调整 GC 线程数。ZGC 的自适应能力使得它可以在不同应用负载下动态优化性能，如果应用对低延迟有要求，确保系统有足够的 CPU 资源即可。


> Returning Unused Memory to the Operating System.



释放未使用的内存回操作系统:

- 默认情况下，ZGC 会释放未使用的内存，将其归还给操作系统。这对需要关注内存占用的应用和环境非常有用，但可能会对 Java 线程的延迟产生负面影响。可以使用命令行选项 -XX:-ZUncommit 来禁用此功能。
- 此外，内存不会被释放到低于最小堆大小（-Xms），这意味着如果最小堆大小（-Xms）配置为等于最大堆大小（-Xmx），此功能将隐式地被禁用。
- 可以使用 `-XX:ZUncommitDelay=<seconds>` 配置释放内存的延迟时间（默认是 300 秒）。这个延迟时间指定了内存必须未使用多长时间后才有资格被释放。

**注意事项**:

	•	延迟影响：允许 GC 在应用运行时提交和释放内存可能会对 Java 线程的延迟产生负面影响。如果运行 ZGC 的主要原因是需要极低的延迟，建议将 -Xmx 和 -Xms 设置为相同的值，并使用 -XX:+AlwaysPreTouch 在应用启动前预先分页内存。
	•	Linux 支持：在 Linux 上，释放未使用的内存需要 fallocate(2) 的 FALLOC_FL_PUNCH_HOLE 支持，该支持在内核版本 3.5 (对于 tmpfs) 和 4.3 (对于 hugetlbfs) 中首次引入。

配置示例:

```bash
## 如果希望禁用内存释放功能，可以使用以下配置：
java -XX:+UseZGC -XX:-ZUncommit -Xmx5g -Xms5g -XX:+AlwaysPreTouch MyApp
## 如果希望启用内存释放功能，可以设置内存释放延迟时间：
java -XX:+UseZGC -Xmx5g -XX:ZUncommitDelay=600 MyApp
```

总结:

- `ZGC` 默认会释放未使用的内存回操作系统，这是为了减少内存占用。然而，在低延迟应用中，这可能会影响 Java 线程的响应时间。通过将 -Xmx 和 -Xms 设置为相同值并使用 -XX:+AlwaysPreTouch，可以预先分页内存，优化低延迟性能。注意，在 Linux 系统上，这个功能需要特定内核版本的支持。根据你的应用需求，可以选择启用或禁用 ZGC 的内存释放功能。






## Refer

- [An Introduction to ZGC](https://www.baeldung.com/jvm-zgc-garbage-collector)
- [ZGC Home wiki](https://wiki.openjdk.org/display/zgc/Main)
- [An Introduction to Memory Management In Java](https://www.baeldung.com/java-memory-management-interview-questions)
- [An Introduction to JVM Garbage Collectors](https://www.baeldung.com/jvm-garbage-collectors)



