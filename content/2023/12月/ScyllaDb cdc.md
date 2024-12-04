

## 1-Intro


> Cdc : A Feature that allows you to not only query the current state of a database's table, but also query the history of all changes made to the table


- `Capture data changes`.
- 我们想要知道对数据的修改(包括删除), 可以在应用程序中 `Trigger` 实现，而  `CDC` 则是从数据的角度来实现这个功能

下面用一个简单的例子来说明 `cdc`


```SQL
CREATE TABLE cdc_t1 (pk int, ck int, v int, PRIMARY KEY (pk, ck, v)) WITH cdc = {'enabled':true};


INSERT INTO cdc_t1(pk, ck, v) VALUES(1, 10, 1);
```


会自动的生成一张表. 先查一下数据.

```sql
cqlsh:test> select * from cdc_t1_scylla_cdc_log limit 1;

 cdc$stream_id                      | cdc$time                             | cdc$batch_seq_no | cdc$end_of_batch | cdc$operation | cdc$ttl | ck | pk | v
------------------------------------+--------------------------------------+------------------+------------------+---------------+---------+----+----+---
 0xc7240000000000007151fd5540000501 | 96469c1c-97ec-11ee-e2d1-d7d7ff8b5672 |                0 |             True |             2 |    null | 10 |  1 | 1

(1 rows)
```


```sql
cqlsh:test> desc table cdc_t1_scylla_cdc_log;

CREATE TABLE test.cdc_t1_scylla_cdc_log (
    "cdc$stream_id" blob,
    "cdc$time" timeuuid,
    "cdc$batch_seq_no" int,
    "cdc$end_of_batch" boolean,
    "cdc$operation" tinyint,
    "cdc$ttl" bigint,
    ck int,
    pk int,
    v int,
    PRIMARY KEY ("cdc$stream_id", "cdc$time", "cdc$batch_seq_no")
) WITH CLUSTERING ORDER BY ("cdc$time" ASC, "cdc$batch_seq_no" ASC)
```


> 我们可以控制 这张自动生成表的 `schema`.

1. `preimage`: 新的列，代表修改之前的状态. 默认 `false`
2. `postimage`: 新的列, 修改后被影响行的状态. 默认 `false`
3. `delete`: 是否包含每个被修改列的信息. 默认 `full`, 可选 `keys` 仅仅包含主键列
4. `ttl`: 默认保留最近 24小时的 修改

> `cdc` 在 `scylladb` 中也是 最终一致的实现



## 2-CDC Stream Generation


> StreamId 是会改变的

对于同一个 `paritionKey` 而言, 今天它使用的 `streamId` 可能明天就会发生改变. 

好消息:

- 仅仅在 新 `node` 加入的时候才有可能改变, 删除不会改变
- 可以很方便的知道.`used stream IDS`


> StreamId 是用来维护一致性的

对于某个 `pk`, 这个数据本身的内容 必须和它对应的所有 `cdc log` 同属于一个 `vnode` (一致性 `hash` 的一段区间)


> `streamId` 组成的集合称为一个  `CDC Stream Generation`


1. 有一个 `timestamp`, 代表了这个 `Generation` 开始的时间点 ;
2. 一组 `streamIds`, 和 他们和 一致性hash 环(`token`) 的映射关系 ;


> 这个是集群的 `cluster` 级别信息


```sql
SELECT time FROM system_distributed.cdc_generation_timestamps WHERE key = 'timestamps';
SELECT time FROM system_distributed.cdc_streams_descriptions;
```


具体可以参考 [Cdc Stream Generations](https://opensource.docs.scylladb.com/stable/using-scylla/cdc/cdc-stream-generations.html)


## 3-Query CDC Streams

由于在 集群新节点增加的时候, `Generation` 会变化, 所以需要 主动去发现这个 变更.

- 通过查询 `cdc_generation_timestamps` 和 `﻿cdc_streams_descriptions_v2` 表 可以知道这个变更

`streamIdSet` 的数量远远小于分区数量，是 `ScyllaDb` 打造的多线程并发同步数据库，能极大的增加数据吹里的并行度，降低延迟.


通过使用官方的库，**应该** 可以不用 `CARE` 这个问题. 目前官方提供了 3种语言的实现:

1. `Java`
2. `Golang`
3. `Rust`


这里推荐用 `Docker` 封装 `Golang` 能简单快速的扩展


如果是自己实现的话，可以参考 [Query Cdc Streams](https://opensource.docs.scylladb.com/stable/using-scylla/cdc/cdc-querying-streams.html) 中的 `Reacting to topology changes` 例子.


## 4-Log Table In Deep


> 基本的规则


1. 通过上面的信息，能知道 `cdc` 表的行和 源表的行 一定在同一个 `vnode` ;
2. 根据 是否为 `Primary Key` 的一部分决定是否 有 `cdc$deleted_` 的 `boolean` 列表, 所有的列都会这里有对应 .
3. `meta` 元信息列:
	- `cdc$stream_id` : `blob` 类型
	- `cdc$time` 和 `cdc$batch_seq_no` : 一个是 `timeuuid` 一个是 `int`, 有序而且组成了一 唯一的事件标志
	- `cdc$ttl`: 保留时间
	- `cdc$operation`: 事件类型, 有个 `row_delete` 和 `parition_delete` 要区分一下

> 关于时间

- `time_uuid`: 是一个包含了事件 时间和随机字节的字段 ;

每个 `cdc` 的时间戳, 或者说每个 `write` 的发生时间 一般用来解决写 冲突，在 `scylladb` 的生态中有三种策略:

- `sql` 语句中显示指定
- 由客户端时间指定，`cql` 驱动指定
- 有服务端自动生成

`use_client_timestamp=True` 就会使用客户端驱动生成的时间，有一定的风险, 问题不大.

下面是一个例子:

```sql
CREATE TABLE ks.t (pk int, ck int, a int, b int, PRIMARY KEY (pk, ck));
UPDATE ks.t USING TIMESTAMP 123 SET a = 0, b = 0 WHERE pk = 0 AND ck = 0;

SELECT writetime(a), writetime(b) FROM ks.t WHERE pk = 0 AND ck = 0;

 writetime(a) | writetime(b)
--------------+--------------
          123 |          123

(1 rows)


UPDATE ks.t SET a = 0 WHERE pk = 0 AND ck = 0;
SELECT writetime(a), writetime(b) FROM ks.t WHERE pk = 0 AND ck = 0;

 writetime(a)     | writetime(b)
------------------+--------------
 1584966784195982 |          123

(1 rows)
```


从 `cdc` 表中解析时间的例子. 这个时间精确到 微秒!

```sql
CREATE TABLE ks.t (pk int, ck int, a int, b int, PRIMARY KEY (pk, ck)) WITH cdc = {'enabled': true};
UPDATE ks.t SET a = 0 WHERE pk = 0 AND ck = 0;
SELECT "cdc$time" FROM ks.t_scylla_cdc_log;

SELECT tounixtimestamp("cdc$time") FROM ks.t_scylla_cdc_log;
```


> 关于 `batch_seq_no` 

- `cdc$time` 和 `cdc$batch_seq_no`
	- 前者定义了一个唯一的 写事件 ;
	- 而后者一个唯一写 事件的不同状态,  如果开启了 `pre-image` 就会有2条记录，第一条代表之前的值 ;


## 5-Pre-Image



> PreImage 仅仅支持 `Row` 级别的 `Insert` , `Update` 和 `Delete` ;

```sql
CREATE TABLE ks.t (pk int, ck int, v1 int, v2 map<int, int>, PRIMARY KEY (pk, ck)) WITH cdc = {'enabled': true, 'preimage': 'full'};
UPDATE ks.t SET v1 = 0 WHERE pk = 0 AND ck = 0;
UPDATE ks.t SET v2 = v2 + {1:1, 2:2} WHERE pk = 0 AND ck = 0;
UPDATE ks.t SET v2 = v2 + {2:3, 3:4} WHERE pk = 0 AND ck = 0;
SELECT "cdc$time", "cdc$batch_seq_no", "cdc$operation", pk, ck, v1, v2 FROM ks.t_scylla_cdc_log;
```


```
 cdc$time                             | cdc$batch_seq_no | cdc$operation | pk | ck | v1   | v2
--------------------------------------+------------------+---------------+----+----+------+--------------
 2d5df268-3eee-11eb-7927-87ffdbd439b6 |                0 |             1 |  0 |  0 |    0 |         null
 2d5e3002-3eee-11eb-148e-77c7cfe215fc |                0 |             0 |  0 |  0 |    0 |         null
 2d5e3002-3eee-11eb-148e-77c7cfe215fc |                1 |             1 |  0 |  0 | null | {1: 1, 2: 2}
 2d5e71a2-3eee-11eb-218e-3a6f0b631141 |                0 |             0 |  0 |  0 |    0 | {1: 1, 2: 2}
 2d5e71a2-3eee-11eb-218e-3a6f0b631141 |                1 |             1 |  0 |  0 | null | {2: 3, 3: 4}
```


我们来逐步分析这个情况:


1. 第一个写事件 `2d5df268-3eee-11eb-7927-87ffdbd439b6` .,
	- 对应 `sql` 是 `UPDATE ks.t SET v1 = 0 WHERE pk = 0 AND ck = 0` ;
	- 此时的 `opreation` 是 1 代表是 `UPDATE`, 每个字段都代表了修改之后的值 ;
2. 第二个写事件是: `2d5e3002-3eee-11eb-148e-77c7cfe215fc`, 有2个序列:
	1. 对应的 `SQL` 是 `UPDATE ks.t SET v2 = v2 + {1:1, 2:2} WHERE pk = 0 AND ck = 0` ;
	2. 序列1 是0， 代表是 `PRE-IMAGE` , 记录修改之前的值, **包括了这次没有修改的值** ;
	3. 序列2 是1, 代表是 `UPDATE`, 记录了 这次的修改, 有趣的是 `v1` 是 `null`, 代表仅仅修改了 `v2`  字段 ;
4. 第三个写事件是  `2d5e71a2-3eee-11eb-218e-3a6f0b631141` , 有2个序列:
	1. 对应的 `SQL` 是 `UPDATE ks.t SET v2 = v2 + {2:3, 3:4} WHERE pk = 0 AND ck = 0` ;
	2. 序列1 是0, 代表 `PRE-IMAGE`, 同上
	3. 序列2 是1, 代表 `UPDATE`




> [!NOTE] Tips
> 因为 `pre-image` 是 full, 才会在 `pre-image` 事件中记录 没有修改的字段的值



> [!NOTE] Tips
> 注意: `Pre-Image` 对并发写的保证有限. 假设有2个并发写操作 . `S1` 和 `S2` . 可能有3种情况:
> 1. `S2` 的预镜像读取在 `S1` 的写入之后完成， `S2`的预镜像会观察到 `S1` 的影响
> 2. `S2` 的预镜像读取在 `S1` 的写入之前完成, `S2` 的预镜像无法观察到 `S1`的影响
> 3. `S2` 的写入在 `S1` 的预镜像读取之前完成, 这个时候 `S1` 会显示为 `S2` 的更新值，和预期是不符的


## 6-Sample Applications


- [printer](https://github.com/scylladb/scylla-cdc-java/tree/master/scylla-cdc-printer): 打印事件，可以学习基本的 `api` ;
- [scylla-cdc-replicator](https://github.com/scylladb/scylla-cdc-java/tree/master/scylla-cdc-replicator): 数据复制组件，可以用于在不同的 `scylla` 集群中同步数据 ;
- [scylla-cdc-source-connector](https://github.com/scylladb/scylla-cdc-source-connector/tree/master): 生产级的 应用，把 `ScyllaCdc` 转换为 `Kafka` ;


## Refer


- [ScyllaDb cdc](https://opensource.docs.scylladb.com/stable/using-scylla/cdc/cdc-intro.html)
- [Consuming CDC with Java and Go](https://www.scylladb.com/2021/02/09/consuming-cdc-with-java-and-go/)
- [Using cdc in scylla](https://www.scylladb.com/2020/07/23/using-change-data-capture-cdc-in-scylla/)
- [Cdc Stream Generations](https://opensource.docs.scylladb.com/stable/using-scylla/cdc/cdc-stream-generations.html)
- [Query Cdc Streams](https://opensource.docs.scylladb.com/stable/using-scylla/cdc/cdc-querying-streams.html)


