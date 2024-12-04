


## 1-Intro

- [原文链接](https://www.uber.com/en-SG/blog/uber-gc-tuning-for-improved-presto-reliability/?uclick_id=f5db6e20-52a8-4adf-9e7e-03de56f73b67)
- [jdk源码-13-ga](https://github.com/openjdk/jdk/tree/jdk-13-ga)



> Uber 的 Presto, 下图来自 `Uber` 官方blog


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202153150.png?imageSlim)


- 有2个数据中心, 20个集群, 10K个节点，平均一下每个 `Cluster` 是 500 个节点的规模.
- 查询是典型的 `OLAP`, `500K/day` 在 `OLAP` 也不算低.


> 什么是 `Presto`

`Presto` 查询平台, 基于 `MPP` 的架构, 用来聚合多个数据源, 目前开源产品是 [trino](https://trino.io/) . 简单列一下 features:

- 面向 `SQL`
- 解耦 并支持了多种 `Datasource`
- 他的所有处理都在内存中, 包括 数据源的数据会直接 `load` 到内存中, 然后执行 `sort` 和 `aggregation` 等操作 ;
- 可以和 `Alluxio` 配合操作


`Uber` 用来支持的 数据源包括: `Hive`, `Pinot`, `AresDB`, `Mysql`, `Es`, `Kafka`


>  Uber 把 Presto 的集群按照工作类型分为了2类

- 第一类面向 `BI` 系统的 `AdHoc`, 直接为业务方生成 报表
- 第二类面向 `Batch` 处理任务.


> Jvm Heap


- 大多数集群中的 `node` 机器中 `heap > 300G`
- 少数集群的 `node` 中 `heap < 200GB`

 问题:
 
 - 主要是 长时间的 `FullGc` 
 - 次要是 偶尔的 `OOM`



## 2-Practise


> G1 理解

[[Jvm 内存分配回收]]


- `G1` 是分代的算法, 跟 `CMS` 比主要是 `Garbage First`, 把内存按照大小 分为多个 `Region`, 然后在 清理的阶段通过一些 统计的算法标记出 垃圾最多的. `Region`, 优先清理
- `G1` 依旧用的是三色标记, 从 `root objects: thread stacks, global vars, etc` 开始进行图遍历
- `G1` 使用的 `STAB: Snapshot at the begining`, 开始时候的快照进行遍历，也就是说 **并发过程中的浮动垃圾会认为是存活的**, 留到后面的 `mixed collection` 再去处理, 之所以叫 **混合**, 是指老年代区域中会包含了 新生代的gc 过程, 新生代的gc 和以前一样是 `eden` 和 `survivor` 的复制
- `G1` 使用的是 `Concurrent mark and sweep`, 标记清除，也就是说和默认的 `cms` 比会做内存整理的工作, 内存整理的工作在 `mixed collection` 中， 这个阶段会把存活的老年代对象复制到 另外的区域，类似新生代的思想, 这个思路对减少 **内存的碎片化也非常重要**.
- `G1` 会 **自动调整** 每代在 `heap` 中的 `region` 数目来实现内存的划分, 这个过程是自动调整来适应当前的任务，但是会有一些 硬限制, 例如 `Young` 只能占据 `5% 到 60%`;



有2种常见的内存 进入 `old` 情况:

1. 新生代对象的年龄到了, 会移动到 `old` 中;
2. 如果一个对象大于 `regionSize` 的 `50%`, 是 `humongous` 对象, 直接进入老年代. 这个东西很头疼，首先，它可能是个不配进入老年代的对象，因为它的生命周期可能很短，而且老年代的回收成本非常的高, 而 `jdk` 源码中是会特殊标记大对象的.


4种 `G1` 的 `RegionType`, 源码位于 `src/hotspot/share/gc/g1/heapRegionType.hpp`

```c
  static const HeapRegionType Eden;
  static const HeapRegionType Survivor;
  static const HeapRegionType Old;
  static const HeapRegionType Humongous;
```


我们看到源码中新生代分为 `Eden` 和 `Survivor`, 这很好理解.
老年代中分为 `Old` 和 `Humongous`. 个人猜想至少有2个好处:

1. 首先，不让 `humongous` 对象污染 `old region`, 大对象需要大量的连续内存，也容易造成 **大量的内存碎片**, 区别开来，可以减少 **内存的碎片** ;
2. 其次, 提高 `humongous` 的回收效率, 因为它们不是通过正常的晋升来的，而是空降的，所以回收频率会比较高



> Jdk 版本


`jdk G1` 在 `11` 左右的版本有比较大的提升.  而 `Uber` 内存还存在 `jdk8` 版本的老集群. 所以优化也要分为2个大版本.

- `< jdk11`: 最关键的是 `InitiatingHeapOccupancyPercent`, 默认是 `45%`, 是指开启 老年代的内存达到 `45%` 的时候，开启并发标记. 为什么如此关键，因为 **避免兜底 FullGC-全局的 STW** 是主要目标，我们要确保 并发标记回收的阶段有足够多的空闲内存用于 **新对象的分配和GC 中使用的临时空间**.
- `>= jdk11` :  `JDK11` 引入了 `IHOP` 机制来动态调整， 你仅仅只能在 `GC` 日志中观察到.



> 如何为 jdk8 的 G1 设置 InitiatingHeapOccupancyPercent


这个值低了，会频繁的浪费 `CPU` 去做并发 `GC` ;
这个值高了, 并发太晚，可能会导致 `FullGC` ;

首先是开启 `GC` 日志

```bash
GC_LOG_OPTS="-Xlog:gc*=debug,stringdedup*=debug,gc+ergo*=trace,gc+age=trace,gc+phases=trace,gc+humongous=trace,safepoint=debug:${LOGS}/gc.log:level,tags,time,uptime,pid:filecount=5,filesize=100M"
```


在 GC 日志中你至少要观察:

1. `FullGC` 的频率，出现意味着兜底
2. 在并发标记清理中在 `mix-collection` 混合收集阶段之后的老年代的 `peak-heap-utilization` 

这个 `peak-heap-utilization` + `5% - 10%` 的值就是 合适作为 `InitiatingHeapOccupancyPercent` 的值



> jdk11 之后的 IHOP

这个算法 略微复杂，无限简化之后的就是下面的参数考虑

- `current size of the young generation` + `a free threshold`


这个思路也很简单, 第一确保有 `free threshold`, 默认是 `10%` 的内存来做 `GC` .

老年代的内存达到这个阈值的时候=`x`, 如果此时新生代的大小=`y` , 想要预留. `10%`.

那么 `x + y + 10%= total`


> `Uber` 的测试过程


，增加更多的 gc 监控，例如各个阶段 新生代和老年代的大小


> 测试1:  减少新生代比例


`G1MaxNewSizePercent` 从默认的 `60` 降低到 `20`, 新生代减少，因为新生代的 `GC` 复制算法是 `STW` 的，这个 **出发点是减少 stw 的总时间**, 确实做到了.
	- **但是，新生代小了，意味着 晋升更快，并发 GC 的次数多了，cpu 消耗就大了**


> 测试2: 提高 `Free space 10->35`, 减少 `heap waster, 5->1`


基本的理解:
- `G1` 优先选择垃圾最多的 `Region` 去清理. 
- `G1` 优先把存储对象 复制到垃圾最少的 `Region` 中去, 这样复制效率最高

所以 `G1` 会根据老年代所有的 `Region` 去统计, 每个 `Region` 中有多少的垃圾进行排序. 


然后理解一下, 减少 `heap waste`, `G1HeapWastePercent`.

主要原因: 这个值决定了要不要开启 `GC`., 默认是 `5`, 意味着当堆中的垃圾超过 `%5` 的时候, `G1` 去释放这些垃圾, 减少这个值是 用来优化 `mixed-collection` 阶段, 值小一点，这个阶段不会有长时间的暂停. 因为混合阶段涉及到 新生代的 `gc`, 如果垃圾太多，这个阶段的 `stw` 时间会更长. 这个是主要理由. 

次要原因: 在大内存场景 ，例如 `300G`, 也就是说，如果 `<15G` 的垃圾会永远不会回收. 这个浪费其实很大. `1` 是 `Uber` 自己的实践.


下面来看 `Free space`， 也就是 `G1ReservePercent`.

实践中通过观察 `Gc` 日志得到，在 `mixed collection` 之后, 堆内存的利用率是 `20-35` , 

然后 选择了 如下的配置 :

- `G1MaxNewSizePercent=20`, 新生代最大不超过 `heap` 的 `20`
- `G1ReservePercent=35` 作为 `free thresold`
- `G1HeapWastePercent=1`

这配置意味着 触发并发标记的阈值是 `100 -20 -35 = 45`.

观察到了结果如下:

1. 由于 `G1ReservePercent` 提升了很多，减少了 `80%` 的 `FullGC` 出现次数
2. 出现了更多的 `stw` 现象，观察到 这个 长停顿是由于 `mix-collection` 阶段要把垃圾从 `2%` 降低为 `1%`, 这个说明 **G1HeapWastePercent=1** 下降了太多



> 测试3基于测试2: 

- `G1HeapWastePercent 1->2`: 会有更多的空间浪费，更大的延迟，大概延迟多了 50ms->100ms, 但是没有上面的 `>1s` 的长停顿了
- `G1ReservePercent 35->40`: 基本消失了 `FullGC`

基于上面的观察，将优点扩大，将缺点降低, 最终的效果, `FullGC` 消失了


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202172051.png?imageSlim)



## 3-Conclusion


`UBer` 的所有优化面向的是内部的设施, 调优的过程 价值大于 调优的结果.  我们都知道 `G1` 的优化配置非常的少，对于 小内存应用基本不会有什么问题，但是当内存是 `300G` 这个级别，一点微小的改动价值还是很可观的.

最后的结果如下:


```
-XX:+UnlockExperimentalVMOptions

-XX:G1MaxNewSizePercent=20

-XX:G1ReservePercent=40

-XX:G1HeapWastePercent=2
```


