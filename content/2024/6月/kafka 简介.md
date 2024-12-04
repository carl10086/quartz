
## 1-Intro


> 什么是 Controller ?


- 每个 `Broker` 会利用 `zooKeeper` 做主从选举，从中选择出来一个 `Controller`

这个 `Controller` 会负责处理 **元数据的管理**.

1. `Topic` 和 `Partition` 的分配, 这些 `MetaInfo` 同时存储在 `Zk` 中
2. `Broker` 监听并缓存在内存中.
3. `Controller` 会 监听 `Broker` 的 健康状态，做 `Rebalance` 操作


>  Broker 如何处理 data


1. 一个 `Parition` 就是一个物理上的文件夹 ;
2. 每个文件夹中的文件切分策略是 大小, 默认是 `1G`, 像所有的日志一样, 到了 `1G` 就滚动生成一个新的文件
3. 使用 稀疏索引和 `MMap` 虚拟映射来管理
4. `Offset` 的生成由 `Primary Partition` 决定, `Replica Partition` 仅仅作为数据的备份，是一种 **经典的单主模型策略**, 其原子性是由内核的 `O_APPEND`  同时实现追加文件写操作，并返回最新的 `Offset`

> Consumer Group

1. 每个 `Consumer Group` 都会有自己的 `Coordinator` 来管理 `Consumer Group` 的元数据 ;
2. 这个元信息比较大，不会存储在 `ZK` 中，而是用一个专门的 `topic` 来管理, `__consume_offsets` 来存储 ;
3. 消费的并行度由 `Parition`数量决定的, 一个 `Parition` 只能被一个 `Consume Group` 中的一个 `Consumer` 消费 ;
4. 在消费者去读取数据的时候，用的 `Sendfile` 系统调用实现零拷贝的顺序读, 从而极大的提高性能


## 2-KRaft


`KRaft` 是 `Kafka` 的新的元数据管理机制, 用来彻底替换掉 `Zk`， 也就是上面的这些功能被直接取代了:

1. 基于 `Raft` 算法来选择 `Controller`
2. 存储 `Topic` 和 `Parition` 的元信息
3. `Consume Group` 的 `Coordinator` 选举

## 3-Usage

`Kafka` 权威指南讲的不错.
