

## Intro

> 思考一个问题. 下面的数据结构是什么, 如何组装起来实现各种各样 `Redis` 外层的数据结构

- `sds`
- `adList`
- `zipList`
- `quickList`
- `listPack`
- `Rax`
- `dict`
- ...


## 1-SDS


- 本质上是一个二级制友好的字符串，处理 `\0`
- 根据不同的字符串的长度定义不同的结构体, 核心在在于 **省内存**, 从 `Redis3.x` 版本开始重新设计


> 内存优化, `Redis` 的字符串在数据结构这个角度 浪费的空间是非常少的

一个 `int` 是 4Bytes, 来代表长度有点太浪费空间了.  

一个字节有8bit, 我们用前3个bit 存类型，能有 `2^3 = 8` 种. 后面还有 5bit, 假设用来代表长度，能代表 32内.

所以 `Redis` 的 `sds` 做的很细.

- `sdshdr5`: 使用一个 `Byte` 压缩存储 `Flag` + `len`
- `sdshdr8`: 使用 `uint8_t` 存储长度, 其实是 `1个Byte`
- ...
- `sdshdr64`


> 理解 `RedisObject` 中的字符串

- `Redis` 把一切封装为 `RedisObject`. 因此会包含 一些元信息，例如 type 和 编码. 用字符串举个例子.

```bash
redis:6379> set k1 1
OK
redis:6379> object encoding k1
"int"
redis:6379> set k2 ab
OK
redis:6379> object encoding k2
"embstr"
redis:6379> set k3 abcdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
OK
redis:6379> object encoding k3
"raw"
```


- `int`: 一定范围内的整数，用 int 更省内存
- `embstr`: < 44Bytes 对象的元信息和底层的 `sdshdr5` 放到 **连续的内存**, 这样不用通过 `ptr` 指针去查找了
- `raw`: 字符串了


## 2-SortedSet

> `Redis` 有序列表的底层主要有2种

一种是压缩列表(省内存，效率不高)，一种是跳表(空间换时间).

有2个配置决定了使用哪种数据结构.

- `zset-max-ziplist-entries 128`:  使用压缩列表的 元素最大个数 < 128
- `zset-max-ziplist-value 64`: 压缩列表中每个 元素对应 `value` 长度 < 64


> 跳表


- 有序链表 + 多层的稀疏索引
- 跳表有利于查找: 如果 `next` 节点的值 > `target` 就直接去下一层
- 跳表的增加和删除也不慢: 定位节点 `log(N)`


> 压缩列表

压缩列表 `ziplist` 主要用来优化空间, `Redis` 的有序集合, `Hash` 和列表在元素少的时候 都会退化为 `ziplist` 结构, 从下面的总结能够看到, 类似双向的链表, 每个元素有自己的类型, 处处都是 **可变长度的内存**

- 本质上就是一个字节的数组，其中包含了多个元素, 每个元素是一个字节的数组或者一个整数, 所以非常 **泛用**
- 类似双向链表，在头部和尾部都有指针, 能快速定位到头部或者尾部.而且存储非常高效, 列表的每个 `entry` 包含了
	- `pervious_entry_length` :  前1个元素的长度, **占用内存可变**. **前1个元素 < 254字节 的时候, 长度用1位**, 否则如果 `第一个字节=0xFE`, 那么长度用5位, 1位`Flag` 代表长度超了, 4位代表 真正的长度
	- `encoding`: 编码, **占用内存可变**, 代表元素类型
	- `content`


缺点:

- 连续内存, 对修改不友好

## 3-Dict


> Hash

- 使用 链表法解决 `Hash` 冲突
- 使用 渐进式 `ReHash`, 搞个 `hash[1]` 保留中间状态



## 4-QuickList

> 简介


在 `Redis3.2` 之前, `zipList` 和 `adList`(双向链表来实现),  其中.

- `zipList`: 在 上面的压缩列表，比较省空间
- `adList`: 双向链表

在 `Redis3.2` 之后使用 `QuickList` 实现, 在 时间和空间上 取得了平衡.

- 使用 双向链表的结构来组织 `zipList` .

当元素个数多的时候, 退化为类似 `adList`, 也就是 双向链表, 每个 `zipList` 包含了一个 `entry` 
当元素个数少的时候，退化为 `zipList`, 双向链表仅仅包含了一个元素, 一个双向链表仅仅包含了一个 `zipList`

有2个配置:

- `list-max-ziplist-size`
- `list-max-ziplist-entries`


## 5-Stream


> 简介

- `5.0` 引入
- 生产消息
	- 递增的消息 `ID`
	- 内容是 `k-v` 对



```
xadd mystream1 * name hb age 2
```

- 消费者可以有 组的概念，通过 `ack` 在 `Redis` 端保留进度
- 底层数据结构是 `listpack` , `Rax`


> 首先要解决的问题是消息存储的问题

一个消息分为多个 `field-value`, 一般不会太多的 `field`, 完全不需要 `hash`, 更重要的是内存紧凑. `Redis` 使用 `Listpacks` 来存储 一条消息的多个 `field->value` .

消息的 `Key` 一般是字符串, `Value` 则是多种多样，一般当然也是 `string` . 

`Listpacks` 从名字就知道是一个高度压缩的 List. 跟 `zipList` 一样 有特殊的 `Encode` .

用 `1Byte` 代表类型.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231226142412.png?imageSlim)


> 同样是高效压缩, `Redis`  使用 Listpack 不用 zipList 的原因如下:


1. `zipList` 中添加内容很低效, 但是 `Listpack` 总是在尾部预留了一些多余空间, 基本是 `O(1)`, `Listpack` 会通过空间换时间，预留一些空间来做, **这里能发现, Listpacks 能存储多条消息** ;
2. 每个 `listpack` 能存储的最大消息总量由内存和个数来控制, `stream-node-max-bytes` 和 `stream-node-max-entries` 来 控制 ;
3. 抽出一个 `masterEntry` 存储**公共的 `field`**, 后续的元素不用管 `field`, 只需要存储 `value` ;


> Rax: 前缀压缩树, 可以把有公共前缀的压缩到一个节点

为什么 `Redis` 使用前缀压缩树来作为 `Id` 索引，实现 `Range Search` ? 下面是 **个人理解**

- 首先，因为 `Redis` 中的 `StreamId` 使用的是 类似 `timeuuid` 也就是 `uuid:v1`  的类似算法, 生成的是一个 48位精确到毫秒的时间戳 + 随机数字 等等来实现 唯一的 `id` 算法.

- 他是一个定长的，而且在高并发下，由于是时间，会导致有大量的公共前缀(时间天-小时-分-秒) 就是公共前缀，因此使用 `RAX` 确实是非常完美的数据结构

- 使用 `RAX` 可以很快通过前缀定位到某一个, 但是由于 `listpack` 中包含了多个 `streamId`, 所以 在 `RAX` 上的 `Key` 是一个开始的 `Id`,查询是类似 `SELECT streamId FROM RAX where streamId > #{targetStreamId} limit 1`, 当然 语法类似: `XRANGE key start end [COUNT count]` 



## 6-IO

`Redis` 单线程 + `Epoll` 网上都是吹嘘, 个人认为不客观, `Redis` 的设计就是一般的.

- 内存的处理确实会比较快，所以单线程应该是够的，简单的无锁更容易，**但是软件的世界不可能有 银弹** ;
- 但是 单线程设计本身是有风险，作为缓存，在 理想的内网情况下, 单线程用来做 内存操作 + `IO` 读写 是可以的， 但是 真实的网络是复杂的，网络可能会抖动，假设内网 抖动一下，由于拥塞控制什么都好，导致 `IO` 慢了, 整个 `REDIS server` 的表现就是 剧烈抖动，甚至出现故障蔓延导致缓存雪崩 . 所以 `REDIS 6.0` 引入多线程把 `IO` 的处理比如说读取网络数据流和写入网络数据流改为多线程实现 ;
- 同样，由于单线程的设计，导致了 运维的复杂性，一个线程 能处理的内存和请求是有限的，也就是 哪怕硬件再好，`REDIS` 在单台服务器也应该高多个实例, 直接限制了 `REDIS` 性能的**垂直伸缩**, 而 `DragonFly` 出现也就是针对这点才诞生的 ;



## 7-RDB & AOF


- `RDB` 是快照，`bgSave` 启动一个 `RDB`, 注意 `Redis` 本身没有 `MVCC` 就是一个个数据从内存扣出来, `RDB` 好像还有一个 LRF 压缩算法, 注重的是 空间，恢复也比较快 ;
- `AOF` 事件溯源, 就是一个个命令回放 ;

`Redis` 作为缓存的话，建议走预热组件重新构建, 不是为了 `Slave`, 个人一般连 `RDB` 都懒的开 ;


## 8-Slave

> 全量

`Slave` 依赖 `RDB`, 开一个 `bgSave` , 然后之后的写入到 内存缓冲区中(`backlog buffer`)，用于增量恢复

> 增量

后续的同步都是基于 异步写的方式同步给 `slave`


> 异常: 由于内网的抖动，导致 master-slave 短暂失联

部分重同步机制, 不想重头走一遍 全量. 怎么办, `Partial Rescynchronization`. 这个有一些关键点:

1. 所有的命令要有一个全局唯一的  `replication offset`  ;
2. `repl_backlog_buffer` 控制了复制缓冲区的大小，要求是 `slave` 断点续传的时候要在 缓冲中还有对应的 `offset` 才能断点续传， 如果中断时间太长不行
3. 还有一种可能性会断开连接，从库作为一个 `client`,来从 `primary` 中同步数据，有一个 `client buffer`, 这个 `buffer` 如果因为网络原因爆掉了，`primary` 会主动断开这个连接, 也会造成失联，当然本质上还是由于 弱网，或者从库太卡，同步的太慢



## 9-Redis5 中断

> redis 5 还是单线程架构，受制于网络io, 在压力非常大的时候, 使用 `promethus` 会发现 中断特别多. 导致的 `context switch` 也特别多

暴力思路: 通过使用 网卡多队列或者 `cpu` 亲和性 提升处理中断的能力

1. 通过绑 cpu 核心, 让处理 中断的(一般云厂商处理网络软中断的) `CPU` 
2. 注意要让 redis 进程的 cpu 绑定到其他的 `cpu` 上去


**个人理解:**

其实操作系统的 网络内核栈宏观上还是很清晰的.

- `NIC` 读取到新的包 扔到 `RingBuffer`, 然后 通过 `DMA` 同步到内核空间的 `sk_buffer` , 到用户空间的程序之类
	- **关于中断**: 收到包， 硬件的中断肯定是硬中断，一般是 `CPU0` 处理，然后后续的 异步过程由 `NAPI` 来处理, `NAPI` 就是批量的软中断, 减少中断次数 ;
		- 硬中断一定是串行的, 处理的时候会禁用, 直到 `NAPI` 和 `DMA` 结束 ;
	- 硬中断都很快，对 `CPU` 压力不大，所以 网络压力一般来自于 软中断  ;
	- 软中断可以通过配置 中断 亲和性让多个 `CPU` 处理 ;
	- 还可以更暴力的使用 网卡多队列 来使用 多个 `CPU` 处理，从硬中断开始就是独立的 ;
 

## Refer

- [Redis体系](https://pdai.tech/md/db/nosql-redis/db-redis-overview.html)
