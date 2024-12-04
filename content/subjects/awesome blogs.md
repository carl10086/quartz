

> Intro

这个项目是记录,  看到一些 好的文章，`MARK` 一下后续学习.  

- 没有优先级和推荐，可能会加粗表示推荐，顺序就是阅读的顺序，按时间倒序




### 2024-10

- [ ] [traceloop](https://github.com/traceloop/openllmetry) : 专注于 `LLM` 应用 的监控能力, 基于 `OTel`
- [ ] [kruise](https://github.com/openkruise/kruise):  提供了基于 `k8s` 核心能力扩展的能力 
- [ ] [Writing an OS in RUST](https://os.phil-opp.com/zh-CN/) : 基于 `RUST` 手写操作系统内核
- [x] `cortine vs vthread`: 编程范式的区别, `routine` vs 虚拟线程 ✅ 2024-11-13
- [x] [jMolecules](https://github.com/xmolecules/jmolecules) : 架构的抽象框架 ✅ 2024-11-13


### 2024-09

- [x] [Advancing Enterprise DDD](https://scabl.blogspot.com/p/advancing-enterprise-ddd.html) : 企业级别的 `DDD` ✅ 2024-09-24
- [x] [sidecar vs sidecar-less](https://mp.weixin.qq.com/s/tjBYoWyoU8P1AEBoapgP4w) ✅ 2024-09-24
- [ ] [国内云原生社区](https://cloudnative.to/)
- [x] [kafka 拐点已至](https://mp.weixin.qq.com/s/LD4W7Vt1QS5QXHC8Us80zw): 便宜的替代品 ✅ 2024-09-29
- [x] [systemd-reload 导致 显卡符号链接断开](https://github.com/NVIDIA/nvidia-docker/issues/1730) ✅ 2024-09-30 : 经典又常见
- [x] [Gpu 经典问题](https://www.alibabacloud.com/help/zh/ack/ack-managed-and-ack-dedicated/user-guide/common-fault-types-and-solutions) ✅ 2024-09-30


## 2024-07

- [x] [NvLink 入门](https://mp.weixin.qq.com/s?__biz=MzI0OTIzOTMzMA==&mid=2247486607&idx=1&sn=79582c44941f4a5021e9fbd086f5f3df&chksm=e995cec2dee247d49e11845017830eecea4e44375f51b9d1e6633ea6faca3ee6dd38c422dfb3&cur_album_id=3492184534886629384&scene=189#wechat_redirect)
- [x] [Nvidia DGX SuperPOD](https://mp.weixin.qq.com/s/a64Qb6DuAAZnCTBy8g1p2Q): `Nvidia` 万卡集群技术


## 2024-02

- [orchestrator](https://github.com/openark/orchestrator): `mysql` 的拓扑管理工具，支持高可用
- [Uber docStore Arch](https://www.uber.com/en-SG/blog/how-uber-serves-over-40-million-reads-per-second-using-an-integrated-cache/?id=514&uclick_id=33586f46-d81e-488d-973f-024bb12d713f): `Uber` 的 `DocStore` 支持千万 `qps` 的数据库引擎, 底层是基于 `Raft` 的  `Mysql` 引擎, **闭源**
- [Facebook mysql raft](https://engineering.fb.com/2023/05/16/data-infrastructure/mysql-raft-meta/) : `Facebook` 的  `mysql` 的 `Raft` 插件
- [Netflix To GraphQL Safely](https://netflixtechblog.com/migrating-netflix-to-graphql-safely-8e1e4d4f1e72): `Netflix` 的 `Api` 迁移实践, 是个不错的测试方法论

## 2024-01


- [Uber: Gc Tunning For Improved Presto Reliability](https://www.uber.com/en-SG/blog/uber-gc-tuning-for-improved-presto-reliability/?uclick_id=f5db6e20-52a8-4adf-9e7e-03de56f73b67): `Uber` 基建 `Presto`, `G1` 生产级调优
- [DuckDB](https://duckdb.org/docs/guides/index): `OLAP` 界的 `SQLite`, `Library` 的使用
	- [PRQL](https://github.com/PRQL/prql?tab=readme-ov-file): 这个团队认为 `SQL` 不太适合表达为 `ETL` 的数据管道 `Transform`, 因此设计了一种新的语言，目前可以作为 `DuckDB` 的 `Extension` 使用
- [Wide-Column-With-RocksDB](https://medium.com/pinterest-engineering/building-pinterests-new-wide-column-database-using-rocksdb-f5277ee4e3d2): `Pinterest` 基于 `RocksDB` 的宽表的设计
- [K8s-limits](https://mp.weixin.qq.com/s/hqjx-PgHEkUEoOnRbdiXTA): 都是 `CGroup`, 什么东西导致 `k8s` 上的性能会不如 `vm`
- [Models-AB-Test](https://engineering.atspotify.com/2023/09/how-to-accurately-test-significance-with-difference-in-difference-models/): `Spotify` 使用 `AB` 测试关于准确性的心得
- [cadenceworkflow](https://cadenceworkflow.io/docs/use-cases/orchestration/): `Uber` 的一个有趣的 流处理系统,野心很大
- [Innovative Recommendation Applications Using Two Tower Embeddings at Uber](https://www.uber.com/en-HK/blog/innovative-recommendation-applications-using-two-tower-embeddings/?uclick_id=5f2ff7ef-d1a2-4d1b-821e-141457f13d40): `UBER` 的推荐双塔, 其中有趣的提到了训练双塔的一些负样本技巧, [LogQ In Negative Batches](https://research.google/pubs/sampling-bias-corrected-neural-modeling-for-large-corpus-item-recommendations/) 
- [Peronal Pushing](https://www.uber.com/en-HK/blog/how-uber-optimizes-push-notifications-using-ml/?uclick_id=5f2ff7ef-d1a2-4d1b-821e-141457f13d40): 个性化 `Push` 系统 
- [cloudflare-stablediffusion-worker](https://blog.cloudflare.com/workers-ai-update-stable-diffusion-code-llama-workers-ai-in-100-cities/) : cf 的 sd 在线推理 , `Oh My God`