

## 1-Intro

在 [[redis简介]] 中理解了 redis stream 的原理是 `listPack` 和 `ratrix`  . 这里学习一下使用


- 我们已经 知道了底层 `id` 是 `timeuuid` 的版本 , 能确定的是一定是递增的，`redis` 自己会解决 原子性生成递增的 `offset` 问题 ;
- `redis stream` 中的 `eventId` 同样也是 `offset` ;



> 常见命令.


- `XADD`: 增加新的 `ENTRY`, `XADD key ID field string [field string ...]` ;
- `XREAD`: 读取数据，阻塞读?
- `XRANGE`: 范围查询，按照 `KEY`
- `XLEN`: 返回留的长度

> Stream basics

- `STREAM`  是一个 `APPEND-ONLY` 的结构，类似时序，只能删除 

关于 `ID` :
- 毫秒时间戳部分实际上是生成 ID 的 Redis 节点的本地时间。如果当前毫秒时间戳恰好小于上一条目的时间，则使用上一条目的时间，所以，如果时钟回拨了，ID 的单调递增属性仍然保持不变。

- 序列号是在同一毫秒内创建的条目使用的。由于序列号在64位宽的范围内，所以在实践中在同一毫秒内可以生成的条目数量没有限制

> Redis Stream


1. 实时监听: `tail -f` ;
2. 时间序列查询 : 从消费者的视角来看，可能用另外的方式来访问流 ;
3. 消费者组: 类似 `kafka` ;


下面模拟3种场景.

**1) 实时监听**

服务端生产数据:
```shell
127.0.0.1:6379> XADD mystream * sensor-id 1234 temperature 19.8
"1518951480106-0"
```

阻塞消费:
```shell
127.0.0.1:6379> XREAD BLOCK 0 STREAMS mystream
```

**2) 时间序列查询**

`mystream` 数据, 使用 `XRANGE` 进行时间序列查询:

```bash
127.0.0.1:6379> XRANGE mystream - + COUNT 2
1) 1) 1518951480106-0
   2) 1) "sensor-id"
      2) "1234"
      3) "temperature"
      4) "19.8"
```

**3) 消费者组**

```shell
  
127.0.0.1:6379> XGROUP CREATE mystream mygroup $
OK

127.0.0.1:6379> XREADGROUP GROUP mygroup Alice BLOCK 0 STREAMS mystream >

```


## 2-Detail


### 2-1 Range Query


`XRange key start end [COUNT count]` :

- 如果使用 `-` 作为 `start`, 表示最早的条目
- 如果使用 `+` 作为 `end`, 作为最新的条目


```shell

# 查询全部的数据
XRANGE race:france - +

# 查询 `Unix` 时间内的数据.
XRANGE race:france 1692632086369 1692632086371

# 逆序查询 并且使用 COUNT 限制数目
XREVRANGE race:france + - COUNT 1
```

### 2-2 X-READ

> 语法细节

```
XREAD [COUNT count] [BLOCK milliseconds] STREAMS key [key ...] ID [ID ...]
```

- `COUNT count`:  设置返回的最大数目
- `BLOCK milliseconds`: 如果没有更多的数据, 这将等待一段时间。 会阻止连接 一段 `MS`.
- `STREAMS key[key ...]`: 要读取的流的键, 可以同时指定多个键去监听多个流
- `ID [ID ....]` : 用来控制 能看到的最小 `ID`


```shell
XREAD COUNT 2 STREAMS race:france 0

  
# 阻塞的方式读取数据
XREAD BLOCK 0 STREAMS race:france $
```


## 2-3 Consumer Group



类似. `Kafka` 的 `Consumer Group` :

- 同一个消息只会给一个消费者
- 消费者必须能够唯一的标记自己
- 有 `START_OFFSET` 的需求，从这里开始订阅
- 有 `ACK` 操作, 必须 `ACK` 这个消息被消费过


基本的命令:

- `XGROUP`: 创建
- `XREADGROUP`: 通过消费者组从流中读取数据
- `XACK`: 允许消费者把 等待处理的消息标记为已经正确处理





```shell
> XGROUP CREATE race:france france_riders $
OK
```

- 比较关键的是 `$`, 这里应该是 开始消费的 `OFFSET`, `$` 表示最新的消息.


```shell
XGROUP CREATE race:italy italy_riders $ MKSTREAM
```

- 这个会自动创建 `STREAM` 

