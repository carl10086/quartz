
## 1-Basic

6.x 是一个大版本的演进，可以极大的优化性能.


**1)-Tablets 算法已经 releases**

之前是基于 `Cassandra` 的 `vnode` 一致性 hash， `tokenRing` 的机制去做分布式， 这个设计依赖良好的 `partitionKey` 的设计, 一般推荐 `partiionKey` *粒度更细一些* ;

上面的算法是静态的, 而. `Tabelts` 则是一个动态算法的尝试, 目前考虑点是 表大小, 后续会把 `cpu`, `qps` 等等都考虑进去优化数据的分布.

新的动态算法在如下的场景下有明显的优势:

1. 更快的扩展， 新节点在第一个 `Tablet` 迁移后就能直接提供读写服务, 在 *满足一致性的要求下，能支持动态的增加多个节点*, 这个是 了不起的，一般 `Raft` 增加节点都是 *建议一台一台加*
2. 对混合集群更加友好, 比如说 其中的节点 `cpu core` 的数量不一致
3. 对小表的操作会更加高效，因为这些表会 负载到 较小的节点和分片子集中


使用 `Tablets`:

- 新的集群中会默认开启
- 创建新的 `KEYSPACE` 也会默认开启

```cql
# 设置表的初始 Tablets 数量
CREATE KEYSPACE ... WITH TABLETS = { 'initial': 1 }
# 关闭
CREATE KEYSPACE ... WITH TABLETS = { 'enabled': false }
```


> [!NOTE] Notes
> 当前的版本中有如下的特性是不允许使用的:
> 1. `CDC` : Change Data Capture
> 2. `LWT` : Light Weight Transactions
> 3. `Counters` : 计数器能力

此外，还有 `RF` 数量等等的约束.



**2)-强 Raft 算法支持**

- 拓扑更新：
	- 支持并发操作
	- 操作更安全可靠
	- 适合大规模集群管理
- 认证系统：
	- 并行操作更安全
	- 减少了与其他元数据操作的同步问题
	- 简化了多数据中心部署
- 服务级别：
	- 工作负载管理更精确
- 配置更新更可靠
	- 新增DESC SCHEMA WITH INTERNALS命令
	- 提供更完整的schema信息
	- 改进了备份恢复能力



**3)-Deployment 支持**

- 支持了 `Ubuntu24` 废弃了对 `Centos7` 的支持
- 对虚拟机环境更加友好， 兼容了 没有 `UUID` 的磁盘
- 对内核的改进, `scylladb-kernel-conf` 会通过 `sysfs` 去调整 `Linux` 内核的调度器来改善延迟, 这个调整 在 `Linux 5.13+` 版本上因为内核不支持而失效， 现在又重新恢复支持
- ...


## 2-Improvements

### 2-1 BloomFilter 优化

1. 改进了分区键主导磁盘大小的数据模型中的分区数量估算。[#15726](https://github.com/scylladb/scylladb/issues/15726)
2. 修复了时间窗口压缩策略中SSTable分区数量估算的若干bug。[#15704](https://github.com/scylladb/scylladb/issues/15704)
3. 为了稳定性，当总内存消耗超过配置限制时，会从内存中删除Bloom过滤器。[#17747](https://github.com/scylladb/scylladb/issues/17747)
4. 同样为了稳定性，当SSTable被删除时，已回收的Bloom过滤器会保留在磁盘上。[#18398](https://github.com/scylladb/scylladb/issues/18398)
5. 当Bloom过滤器占用过多空间时，ScyllaDB会删除它们。现在当空间重新可用时（例如由于压缩），会重新加载它们。[#18186](https://github.com/scylladb/scylladb/issues/18186)
6. ScyllaDB估算压缩操作的分区数量以正确调整Bloom过滤器大小。现在将改进垃圾收集SSTable的估算。[#18283](https://github.com/scylladb/scylladb/issues/18283)


### 2-2 Compaction 优化

1. 通过使常规压缩任务内部化来节省内存 (#16735)
2. 修复了在停止keyspace压缩时REST API可能崩溃的问题 (#16975)
3. 关闭时，现在会等待系统表的压缩完成，以避免system.compaction_history的更新与其关闭发生竞争 (#15721)
4. 修复了在常规压缩的副作用下执行清理时可能出现的数据重现问题 (#17501 #17452)
5. 在压缩墓碑垃圾回收期间，现在只有在内存表包含键时才考虑内存表。这防止了内存表中的旧数据阻止墓碑垃圾回收 (#17599)


## 2-3 Perf 优化

1. 节点启动时减少了schema摘要的重新计算次数，加快了启动速度。(#16112)
2. 修复功能增加了针对小表的新模式，显著提高了修复速度。(#16011)
3. ScyllaDB使用停顿检测器检测内部停顿，可以使用定时器或硬件性能计数器，现在为自己设置了使用性能计数器的权限。(#15743)
4. 在一致性schema模式下，不再计算整个schema的哈希，而是使用timeuuid生成schema版本，加快了多表集群的操作。(#7620)
5. rewritesstables命令现在在流式/维护组中执行，减少了对系统其他部分的影响。(#16699)
6. 系统现在在启动时以防止内核inode和dentry缓存碎片化的方式扫描sstable文件。(#14506)
7. 对于包含多个小分区的表，sstable索引页面可能包含许多条目，现在会温和地销毁它们以避免停顿。(#17605)
8. 修复了读取大型schema时的反应器停顿问题。(#17841)
9. 解决了scylla启动很慢，花费大量时间加载修复历史的问题。(#16774 #17993)


## refer

- [origin](https://forum.scylladb.com/t/release-scylladb-6-0/2143)