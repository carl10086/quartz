

## Refer

- [Tidb Adoption At Pinterest](https://medium.com/pinterest-engineering/tidb-adoption-at-pinterest-1130ab787a10)

## 1-Intro


**1)-History**


`Pinterest` 从 2013 年开始大规模 使用 `HBase` . 大概是2年前 , `2022` 年的时候 `Pinterest` 开始寻找下一代的存储引擎, 来满足未来的业务需求.


**2)-Requirements**


针对 之前使用 `HBase` 的痛点, `Pinterest` 开启了数据存储的新标准.



- **Reliability** : 
	- 对  `node` `down` 容错， 不管是单数据中心 还是 跨数据中心, `AZ`.
	- 对 集群的升级 **友好** :
		- 扩容
		- 集群升级
	- 天然支持多数据中心的架构,  `multi-region` `deployment` 友好
	- 灾难恢复能力 (数据要能够完整的备份, 时间点级别的恢复)


- **Performance**
	- 持续而又稳定的性能，尾部延迟(`p99`) 和 吞吐量 (`qps`)


- **Functionality**
	- 全局的二级索引
	- 分布式事务
	- 在线的 `DML`
	- 客户侧可调整的 `Consistency` 级别
	- 多数据中心
	- 多租户
	- 快照，和逻辑的 `dump` 
	- `CDC` 能力
	- 数据压缩
	- `Row` 级别的 `TTL`
	- 安全的特性
	- 完全开源



**3)-How**

`Pinterest` 做了如下的工作: 

a) 识别相关的数据存储技术
b) 进行矩阵分析，基于公开信息初步筛选
c) 选择三个最有前景的技术，使用公共基准和合成工作负载进行评估
d) 在Pinterest内部使用影子流量进行测试，模拟生产工作负载


最终选择了 `TIDB` 



## 2-Adoption Journey


**1)-技术选型**


`Pinterest` 最初考虑了10多种数据存储技术，包括：

• 内部开发的技术：`Rockstore`, `ShardDB`
• 开源技术：`Vitess`, `VoltDB`, `Phoenix`, `TiDB`, `YugabyteDB`
• 商业解决方案：`Spanner`, `CosmosDB`, `Aurora`, `DB-X`（化名）


**2)-矩阵分析的结果**

• `Rockstore`：缺乏内置的二级索引和分布式事务支持
• `ShardDB`：缺乏全局二级索引和分布式事务支持，水平扩展困难
• `Vitess`：跨分片查询可能未优化，维护成本较高
• `VoltDB`：不提供持久化存储
• `Phoenix`：基于 `HBase`，存在类似的问题
• `Spanner` 和 `CosmosDB`：虽然功能强大，但不开源，从AWS迁移到GCP的成本过高
• `Aurora`：写入扩展性有限，可能无法满足某些关键业务需求

**3)-基准测试**

剩下的使用 `YCSB` 做了统一的基准测试.

a) 初步性能评估：
• 使用 `YCSB` 基准测试
• 结果：三个数据库都提供了可接受的性能

b) 影子流量评估：
• 在 `Pinterest` 基础设施内构建每个系统的概念验证(`POC`)
• 使用来自 `Ixia`（`Pinterest`的近实时索引服务）的影子流量
• 选择了具有大数据量（TB级）、高QPS（100k+）和多个索引的用例

c) 评估结果：
• `YugabyteDB` 和 `DB-X` 在 `Pinterest` 的工作负载下存在一些性能问题：
	▪ 个别节点偶尔出现高CPU使用率，导致延迟增加和集群不可用
	▪ 随着索引数量增加，写入性能显著下降
	▪ 查询优化器在分析查询时未选择最优索引
• `TiDB` 经过多轮调优后能够稳定承受负载，并提供良好的性能


**4)-可靠性测试**

- 节点重启
- 集群扩展
- 优雅/强制节点终止
- 可用区关闭
- 在线DML操作
- 集群重新部署和轮换

`Pinterst` 没有出现致命问题, 有一些可以接受的小问题. (`TiKV` 节点在下线的时候的数据传输很慢)


## 3-Tidb in production


**1)-Deployment**

使用了他们内部的 [teletraan](https://github.com/pinterest/teletraan), 而不是 `k8s` 或者 `aws` 的 `deploy` 服务 `eks`

**2)-Compute Infra**

- 使用 `Intel` 的处理器和 `local-ssd` 的云实例类型
- 性价比不高

**3)-Online Data access**

- 使用代理层 `Thrift` 服务代理，不是直接暴漏 `Tidb` 接口给应用方. 
- 使用了 内部的设计，被 称为 `SDS`, `Structured Datastore` 的设计来处理

**4)-Offline Analystics**

- 不使用 `TiFlash` , 使用 `TiSpark` 进行全表快照然后导出到 `S3`
- 快照作为 `Hive` 表的分区用来做 离线分析
- 挑战:
	- 客户端请求过于频繁的全量快照: 使用 `CDC` + `IceBerg` 进行增量导出
	- `TiSpark` 过载集群:
		- `PD` 压力太多，使用只读节点分担压力
		- `TiKV` 压力太大, 离线处理的节点 隔离开来


**5)-CDC**

- 使用 `Ti-CDC` 框架 ;
- 用途: 流量数据库变更, 集群复制, 增量导出 ;
- 挑战: `Ti-CDC` 存在吞吐量的限制 (`700MB/s`) ;
- 迭代: 考虑迁移到 `Debezium`  来简化上游的应用开发 , `Flink-cdc` 的生态也是不错的 ; 



**6)-Disaster Recovery** 

- 每日/每小时 的全集群备份到 `S3` ;
- 启用时间点恢复 (`PITR`) 功能, 实现 `Second/Minutes` 级别的 `RPO` ;
- 备份速度的限制 要避免影响集群的性能
- 问题:
	- **这是全量备份的策略**, 恢复快，但是成本太大, 考虑优化掉 `PITR` 增量备份慢的问题 再继续


## 4-Conclusion


**个人认为:**

**1) 整体是非常好的数据库选型**

- `Tidb` 是非常 非常好的场景, 现在的版本不确定，但是当初 `4.0` 左右的时候是读写默认集中在 `Master` , 要开启 `Replica` 承受读就要 牺牲尾部延迟
- 默认的 `Tidb` 是追求的全局的 强分布式一致性 , 有一定事务要求的场景， `Tidb` 是非常匹配的技术栈.
- 跟 `Mysql` 的兼容极大的减轻了 迁移的负担
- 跟 传统的 `Mysql` 集群方案比，能非常大的减少 维护成本，而且天生支持 各种 现代数据库的特性例如 `TTL` 非常友好


**2)-大规模运营TiDB 依旧有问题**

- `TiCDC` 不能真正水平扩展，存在吞吐量限制
- 备份和主机退役期间的数据移动相对缓慢，系统资源未充分利用
- 大型数据集的并行Lightning数据摄取可能繁琐且容易出错
- TiSpark作业可能使PD过载并导致性能下降
- **锁竞争** 是主要性能问题之一:
	- 在最开始 进行 `SCHEMA` 设计的时候需要 **最小化竞争**, 而这在 `HBase` 这种 `Schema-free` 的系统中则不存在这些问题

- 这个时候 [Scyalladb](https://www.scylladb.com/) 或许是一个非常不错的选择. 




