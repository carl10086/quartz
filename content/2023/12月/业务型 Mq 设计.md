
## 1-QuickStart


> 为什么 `Kafka` 不是特别适合做  业务型 `Mq`

- `Kafka` 做数据管道非常合适, **高吞吐的** 顺序IO, `sendFile`
- 业务型的 `Mq` 有一些特点:
	- `Topic` 特别多, `Kafka` 的顺序 IO 在  `Topic` 特别多的时候没有优点 ;
	- 查询功能上会期待更丰富一些: `Kafka` 本身的设计 顺序读 顺序写设计 仅仅支持 `offset` 的查询 ;
	- 一些业务场景可能需在 `mq`  这一侧配合实现:
		- 顺序消息
		- 延迟消息/定时消息
		- 事务消息
		- ...


> 有一些技术选型


- [Apache RocketMq](https://rocketmq.apache.org/zh/docs/)
- [Apache Pulsar](https://pulsar.apache.org/)
- 基于 `Rdb` 的二次封装
- 基于 `kafka` 类似 `mq` [redpanda](https://github.com/redpanda-data/redpanda) 的二次封装, 他可以很好支持 `Topic` 的 `Scale`
- 云产品,  例如 [Sqs](https://aws.amazon.com/sqs/features/) 
- 基于 `Nosql` 的封装，例如 paloalto 基于 `Sylladb` 的二次封装, [Stream Processing with Scylla](https://www.scylladb.com/tech-talk/stream-processing-with-scylladb-no-message-queue-involved/)



> [!NOTE] Tips
> 大多数时候的 mq 都不是特别建议自研, 尤其是 协议的定制化，如果是定制化的协议，你将无法 直接复用 整个 `dataMesh` 技术的生态, 基于 `Kafka` `RocketMq` 等开源技术的生态是非常完善的，各种 `Connector` 都提供了对应 `Sink`, 例如 `Logstash`, `vector`, `flink` 等等


## 2-Implement By Scylla


> 消息 id 和 offset


`Producer` 生成一个 `Event` , 每条消息至少有2个关键属性:

- 唯一的 `Id`: 唯一标记了这条消息
- 唯一的 `Offset`: 唯一的顺序标记，消费者要按照这个 顺序消费，因此, 他要保证 
	- **有序生成:** 新生成的消息 持久化的 `Offset` 要比之前的都大, 否则消息防丢 需要更复杂的设计
	- **唯一**


基于 `Mysql` 的设计可以考虑自增 `Id` 同时作为 `Id` 和 `Offset` ;
`Kafka` 用的是在 文件的 `Offset` 位置, 每次文件追加的位置就是 `Offset`;

`ScyllaDB` 中没有自增 `Id` 这个东西. 我们看上 `ScyllaDB` 的优点主要是 **高吞吐, 低延迟** 和 **容易异地多活** .


> 关于 `timeuuid`: `Version 1 UUID`, generally used as a conflict-free timestamp .

- `Scylladb` 的 `timeuuid` 是 自带的 `SnowFake` 算法, 可以保证 一个时间级别有序的唯一 id.
- 他用 48 位代表时间精度， 也就是到 毫秒这个级别.


对 `timeuuid` 的函数有:

- `dateOf` : 从 `timeuuid` 中提取时间
- `now()` : 使用 `now` 函数生成的 `timeuuid` 可以保证全局唯一
- `minTimeuuid()` 和 `maxTimeuuid()` : 对于查询非常有用 . `SELECT * FROM myTable WHERE t > maxTimeuuid('2013-01-01 00:05+0000') AND t < minTimeuuid('2013-02-02 10:00+0000')` , 可以直接使用 这个语法查询 某一个时间区间内的所有数据.
- `unixTimestampOf()` : 提取时间戳
- 然后就是一些列和时间转换的 格式化函数了.


> 如何生成 `Offset` 这个字段那是一个难题

- 使用 `LWT` 会影响性能和吞吐 ;
- 使用时间方案会受到 服务端时间的影响,  **处理起来要特别小心** ;
- 不同于 `Mysql` 有自增 `Id` , `ScyllaDb` 中估计没有这个东西 ;

假设用 `timeuuid` 的话, 服务器做好 `ntp`

我每次拉取的时候先从服务端获取 `now()` 假设是 `2021-01-01 10:00:01`, 我允许最大延迟时间是 `1s`

- 使用 `timeuuid` 作为 `cluster key` 可以按排序读取 
- 上一次的最大 `timeuuid` 作为 `offset`.
- 然后查询 `t > ${offSet} AND t <= minTimeuuid('2021-01-01 10:00:00') limit 1000` 去获取这一批的数据.
	-  **使用一定的延迟时间 可以缓解 时间不同步的问题**, 但是依旧受制于 服务端的 时钟误差



> [!NOTE] Tips
> 也不用太担心 上面的时间问题, 我们只要 让 `timeuuid` 仅仅是 `ClusterKey`, 不参与到 `PartitionKey`, 也就是说同一个 `ParitionKey` 下基本上是相同的 `node` , 不会有分布式的 时钟问题


> 关于 `eventId` 的问题


`ScyllaDb` 使用 `Now()` 生成的东西是不会 直接返回的, 通过 `INSERT into t_xxx ... NOW()`

因此, 这个时候如果用 `offset` 直接作为 `eventId` 会无法返回, 如果 相对复杂的功能希望在这一层做掉可能不是特别方便.

一个思路是在客户端生成一个 `UUID`, 然后服务端 使用他做唯一的 `Id`, 同时建立一个 对应的物化视图方便各种功能.


> 关于延迟 定时消息


**需求说明:**
- 定时消息：例如，当前系统时间为2022-06-09 17:30:00，您希望消息在下午19:20:00定时投递，则定时时间为2022-06-09 19:20:00，转换成时间戳格式为1654773600000。
- 延时消息：例如，当前系统时间为2022-06-09 17:30:00，您希望延时1个小时后投递消息，则您需要根据当前时间和延时时长换算成定时时刻，即消息投递时间为2022-06-09 18:30:00，转换为时间戳格式为1654770600000。

**实现:**
- 收到延迟消息放到 专门的表中, 是一个比较简单的业务功能, 需要提供一个 基本的 `Job` , 定时扫就行
- 默认 `RocketMq` 支持 24小时后废弃, 都有 最大时限的


> 关于顺序消息. 


**需求:**

- 生产的顺序性: 由 生产者的 `SDK` 控制，因此受制于所谓的 "单一生产者". 
	- 而且最好是 在同一个线程中, 至少发送的时候串行

- 消费的顺序性:
	- `mq` 组件能做的是 保证串行发送的生成的 `eventList` 去同一个分区. 

**实现:**

- 保证这批的消息生成的 `timeuuid` 在同一个分区中 是递增的. 这个有2个思路:
	- 在 `timeuuid` 的 `offset` 字段后 新增一个字段 `seqNo`, 这种复杂性会比较高.
	- 使用 `timeuuid`, 由于受制于 `uuid_v1` 的设计，精度在 毫秒, 这样同一个毫秒内是无序的, 可以 `sleep(10毫秒)` 这种牺牲一点实时性来实现



> 关于事务消息 - `Kafka` 的事务消息


**需求:**

- `Kafka` 的事务是一批消息要不一起成功，一起失败. 这个好像只能借助于 `LWT`, 轻量的事务了

> 关于事务消息 - `RocketMq` 的事务消息


**需求:**

- `RocketMq` 的事务消息 是基于 `Mq` 实现业务上的分布式事务的实现方案.
- **这里的分布式事务** 是 最终一致性, 需要客户端做 **幂等处理**


**实现:** 端到端的 `At Least Once`

- `mq`: `mq` 中事务消息 先进入一个 队列，这个队列会定时补偿
- 生产者实现: 
	- 生产者 发送一个 半事务消息 ;
	- `mq` 放到一个 半事务队列 ;
	- **业务侧实现 业务逻辑** 根据成功或者失败之后调用:
		- `Commit` : 确认可以发送
		- `Rollback` : 回滚

- 生产者补偿实现, 方案太多, 基本上是对 `Timeout` 消息的处理
	- 可以给业务侧一个 `Topic` 的轮询的接口自己去做
	- 也可以通过 `callBack` 的方式去定时去 回调业务侧确定这个消息是 `Rollback` 还是 `Commit`


> 关于死信队列


- In the wait


## Refer

- [Patterns-Of-Distributed-System](https://github.com/dreamhead/patterns-of-distributed-systems/blob/master/content/version-vector.md)
- [Stream Processing with Scylla](https://www.scylladb.com/tech-talk/stream-processing-with-scylladb-no-message-queue-involved/)
