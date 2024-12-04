

## 1-Netflix 基于 DataMesh 的数据管道


Netflix 的内容工程 让许多的服务变为了 `GraphQL` 平台. 

- 每个内容服务都有自己独立的 `DGS: Domain Graph Services`.
- 为所有的 `DGS` 建立一个联合的网关, 统一的抽象层 
- 基于 `DataMesh` 的架构来 构建一个统一的 `Index Pipeline`


> 用如下的业务作为例子


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231126012013.png?imageSlim)




领域模型如下:

1. `Movie` : 代表一个电影 ;
2. `Production` : 代表一个制作, 每个电影都和一个工作室有关联, 一个制作对象跟踪制作电影所需要的一切, 包括拍摄地点，供应商等等 ;
3. `Talent` : 在电影中工作的人被称为 "人才", 包括演员, 导演等等 ;


> GraphQL 如下




![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231126022317.png?imageSlim)








> Netflix 的 DataMesh 架构

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231126012757.png?imageSlim)







1. 每个独立的应用会 负责生成 一个结构化的数据 到 数据中心 `Kafka` 

	- 例如可以用  `Kafka` 原作者 后面开源的 [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/index.html) 作为统一的 事件中心 ;

2. 收集 `Application` 事件的方式有2种, 要符合上面定义的 `Schema Event`, 我个人习惯用 `ProtoBuf` 来定义 

	- `Netflix` 用的自研的统一 `CDC Connector` : 这种技术是 `Event` 中会携带数据. 例如可以用如下开源方案平替:
		- [Maxwell Binlog Producer](https://github.com/zendesk/maxwell) : 收集 `Mysql` `Binlog` 的 `Cdc` 
		- [MongoDb Change Stream](https://www.mongodb.com/docs/manual/changeStreams/) : MongoDb 的 Change Stream
		- 任何如今现在的数据库都会成熟的 `CDC` 方案
		- 甚至是成熟的平台 [Debezium](https://debezium.io/) 
	- 应用当然也可以直接发送 `Schema` 

3. `Data Mesh` 的消费端 `NetFlix` 选择了 [Apache Flink](https://flink.apache.org/)  作为消费手段, 这个是非常不错的选择. 个人观点 , 当前场景下是比 `Spark` 更合适的选择:
	- `Flink` 有成熟的 `Snapshot` 机制 来实现高可用 和 `Exactly Once` 的语义
	- 有成熟的 `Union Processors`  机制来实现多流合并 
	- 有成熟的 `ElasticSearch Sink`, `Es` 的 `Dynamic Template` 还是比较好用的, 个人感觉也比较适合 `GraphQL` 的玩法, `OpenSearch` 作为 `ElaticSearch` 的平替也可以,  不确定 [ManicoreSearcg](https://github.com/manticoresoftware/manticoresearch) 对 `GraphQL` 的友好程度, 看了下很友好... 😄, 甚至包含了部分 `CDC` 的功能, 很卷
	- ...

4. 看上面的图，也就是 `2a` -> `2b` 的地方是 收到了数据的变化之后要 回去 `fetch` 这个 `DataMesh` 配置的字段 反向去走 `Studio EDGE` 中获取到需要的数据, 再把这个数据写入到 一个新的 `Kafka Topic`, 最终索引到 `ElasticSearch` 




> [!NOTE] Tips
> 上面的架构 个人认为有非常的 `Variance`, `CDC Connector` 收集的数据往往是 有序而且 包含了 `Current Data` 的, 因此 最后一个 `Studio Edge` 应该是 `Optional` 的. 
> 
> - 但是如果走 `CDC` 本身的数据，例如 `Production` 最后到 `Es` 就会有一个 `Partial Update` 的问题 , 虽然 `Es` 支持，但是也增加了 `Version Conflict` 的风险.




> [!NOTE] Tips
> 上面的 `DataMesh` 架构不仅仅可以用来构建 图网关的 index，也可以是 任何 Application Service 中的 Index




> Reverse Lookups


- `Netflix` 这里想说的是反向 更新机制, 如果 被关联的子对象中的内容发生了变化
- 例如上面的 `Production` 变化了，需要反向查找包含了 `Production.id` 的 `Movie`, 然后更新这些主实体的索引信息.



> [!NOTE] Tips
> 反向更新策略 消耗是比较大的，假设是 1对1 的关系还好，如果是 多对1, 1的更新意味着多个 `Movie` 都要因为这一次 子更新而全部更新, 这种写压力太大，要在 `DataMesh` 中权衡






> `Netflix` 在向各个业务方推进 自动化的时候碰见了如下 4个主要问题:


1. 需要一种方式 ，我个人认为 `DSL` 语法都比较合适 来让 用户定制 管道的输入配置 
2. `Netflix` 的 Schema 是 `Avro` , `GraphQL` 的响应是多层嵌套的结构字段，手动编写这些复杂的模式非常容易出错 
3. 同样, `ElasticSearch` 的模版窗创建也应该自动化
4. 自动创建 `Data Mesh` 的管理


为了解决上面的问题， `Netflix` 使用了如下的配置文件来抽象一个 `Data Mesh Pipeline` 的配置.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231126022158.png?imageSlim)



- 这个是一个最外层的 `GraphQL` 配置
- 要把这个配置抽象为一个 `json` 可以用 [graphql-java](https://github.com/graphql-java/graphql-java) 然后基于这个进行自动化


> `DataMesh` 中的挑战


1. `Backfill` : 新索引或者老索引添加字段, 会有突发的负载, 尤其高峰期
2. `Reverse LookUp` : 实现比较方便, 但是不友好, 十项一个 `Index` 中如果包含了 8个 `Domain`, 每个子 `Domain` 都会造成 `Reverse Lookup` 的问题
3. `Index Consistency` : 这种自动化的 一致性问题特别难以排查, 因为是老的设计方案, 消息 -> 提取消息的各种 `Id`, 然后回查 `Fetch`, 这个回查的引入 必然会有一致性问题(分布式环境中，例如 缓存，从库延迟等等) 



## 2-Studio Edge Search


这里是如何根据一个 `Index` 的配置, 然后去查询各自的服务.

> 为了从 `ElasticSearch` 复杂的交互中解脱出来了, `Netflix` 封装了一套自己的 `DSL` .


类似 `SQL`. 有如下的语法.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231127140643.png?imageSlim)


使用的库是:

- [antlr4](https://github.com/antlr/antlr4): 一个 文本 `Processor`, 非常适合 `DSL` 这样的构建任务, 他可以解析文本生成一个 `Visitor` 模式的 `Tree`, 只要实现 一个自定义的 `Visitor`, 就可以 使用 `Elasticsearch` 的 `QueryBuilder` 实现一个这样的功能 ;



> [!NOTE] Tips
> ElasticSearch 的 Query DSL 有点复杂，而且他客户端的完全不兼容是很痛苦的, 例如 `Es2->Es5->Es8` , 尤其是 包含了 [Nested Query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-nested-query.html) 的时候更痛苦 .


> 使用这套语法配合 之前的 `GraphQL` 规则


- `Netflix` 做到了从 `GraphQL` 中提取出 需要的 语法是: `actor.role == 'actor'` 



> [!NOTE] Tips
> 会注意到 上面的语法支持的 偏 `Filter` 的功能，没有表达到 `Es` 的 `Text Match` 能力, 这个可以单独做，建议不要和 `Filter` 搞到一起，这2个都挺麻烦的，建议分开.





> 基于规则还直接一套做了通用的 `DGS` `API` .

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/Pasted%20image%2020231127143943.png?imageSlim)



## Refer

- [How Netflix Content Engineering makes a federated graph searchable](https://netflixtechblog.com/how-netflix-content-engineering-makes-a-federated-graph-searchable-5c0c1c7d7eaf)
- [How Netflix Content Engineering makes a federated graph searchable2](https://netflixtechblog.com/how-netflix-content-engineering-makes-a-federated-graph-searchable-part-2-49348511c06c)
- [Domain Graph Service](https://netflixtechblog.com/open-sourcing-the-netflix-domain-graph-service-framework-graphql-for-spring-boot-92b9dcecda18) : 使用 `SpringBoot` 实现的 `GraphQL`
- [Federated gateway](https://netflixtechblog.com/how-netflix-scales-its-api-with-graphql-federation-part-1-ae3557c187e2)  : 联合网关 
- [Data Mesh](https://netflixtechblog.com/data-movement-in-netflix-studio-via-data-mesh-3fddcceb1059) : `Data Mesh Pipeline` 一个完整的数据管线 
- [Netflix DBLog](https://netflixtechblog.com/dblog-a-generic-change-data-capture-framework-69351fb9099b) : `Netflix` 统一的标准的 `CDC Connector` 组件 
- [Netflix DGS spring boot](https://github.com/netflix/dgs-framework) : `Netflix` 的 `DGS` `SpringBoot` 框架


