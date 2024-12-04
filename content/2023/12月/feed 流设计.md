
## 1-Intro

> 什么是 feed 流问题

最初提出的都是 用户发布了内容，如何 类似 `rss` 通知到关注了 `owner` 的其他用户 . 

现代的架构其实要考虑更多:

1. 假设找到了所有的新内容，最终的 `rank` 是走 `timeline` 时间，还是走其他的, 例如推荐，例如热榜.
2. 一般的实现中无论是 热榜，还是推荐都会考虑 有一个 时间的区间，为了减轻问题的复杂度，我们集中在 `timeline` 的问题设计上


> `push` vs `pull`

假设用户 发布的内容到 `outbox`, 用户关注的人内容进入 `inbox` ;

首先用户发布一定会把自己发布的内容写入到自己的 `FEEDS_OUTBOX` ;

**拉模式:**

在查询的时候查询当前用户关注了多少人.

```SQL
SELECT toId FROM RELEATIONS where fromId = ${userId} AND releation = 'follow' ;
```

然后查询. 

```sql
SELECT feed_id FROM FEEDS_OUTBOX WHERE user_id in ${toIdList} AND  feed_create_at > ${timeLowWaterMark} ORDER BY feed_create_at DESC limit ${size}
```


**推模式:** 空间换时间, 写扩散缓解读扩散

先查询 `feed` `author` 的 `followers` , 然后执行下面的逻辑

```SQL
INSERT INTO FEEDS_INBOX (user_id, author_id, feed_id, feed_create_at);
```

查询的时候:

```SQL
SELECT feed_id FROM FEEDS_INBOX WHERE user_id = ${userId} AND feed_create_at > ${timeLowWaterMark} ORDER BY feed_create_at DESC limit ${size}
```

- 其中 `timeLowWaterMark` 代表某个这个 低水位时间 之前的 数据就不要查了. 



**推拉结合的模式:** 时间换回空间? 以推为主 vs 以拉为主.

- 动态聚合如何保证响应时间: 拉取量可能很大，并行获取
- 如何设置选择推拉的边界?
	- 在线的状态?
	- 粉丝数?
	- 好友数?
	- ....

> 新浪微博是 推拉结合，以拉为主， `Facebook` 是纯拉优化的方案.



## 2-Analysis


我们可以从多个角度来分析这个问题.

**宏观上**

- 强读需求，读压力 `>>` 写压力 ;
- 时序事件，基本不变，需要支持删除(物理 or 逻辑 ) 和过滤，**时间在优化上会非常有用**
- 用户的查询不管排序是什么，基本是 **较新的数据 优先返回** 
- 从 `CAP` 的角度，追求的是 `AP`, 不需要特别强的一致性

**推的话，有写扩散的问题**

- 粉丝多的话，写压力和延迟会非常的大
- 不利于数据变更，用户删除 某个 feed **可能** 也需要扩散, 一般都是回源的时候过滤
- 对数据读取非常有利，因为第一个条件是 `WHERE user_id = ${userId}` 这个可太香了
- 正因为读数据的 复杂度降低了，后续迭代 为 推荐排序，热度排序 也会相应的更简单

**拉的话, 有读扩散的问题**

- 好友多的话，拉取的量会非常的大
- 需要高效的 `Merge`, 并行化 + 堆排序 


**写性能优化**

- 异步化，同时考虑做出一些一致性的取舍, 出于性能，选型推荐 [redpanda](https://redpanda.com/)
- 批处理 + 压缩: 压缩小数据其实成本不高, 甚至序列化可以用一些更紧凑的方式，例如 `Protobuf` 等
- 持久化落库选择，使用更好的数据引擎.
	- 例如 `Mysql` 的 `TokuDB` 更适合写入
	- 例如 `LSM` 的， `HBase`, `Cassandra` 这种，推荐 [scylladb](https://www.scylladb.com/)

**读性能优化**

- [[关系图谱图引擎设计]] : 参考这个实现一个高性能的 关系图谱
- 时序明显，最近的数据往往比较热，**意味老数据直接归档收益很高** 
- 关系图谱查询这里，不是 **要查询用户关注的所有用户**.
	- 比如说: 一定要 查询的 时间段有发布 行为的 用户, 关系图谱里 往往对于时间有 跳表索引，或者其他的索引，**这个过滤效率非常高**
	- 如果能接受 更弱的一致性，在好友特别多，而且都发的情况，可以 按照粉丝数之类选择 topK 个好友. **所谓的 推优化部分拉，也是这里 可以过滤掉粉丝数少的好友，因为他们的内容已经主动推送到你 INBOX 了**
- 并行化 `Merge`, 个人推荐 **堆排序 > 败者树**, 堆排序更容易并行化. 例如一个 `PriorityQueue`, 各自的读线程往里面塞数据,  超时的就不要了, 能保证一个好的延迟体验
- 推荐和关注feed 流中可能都会有 已读过滤，可以在使用 `BloomFilter` 来过滤出新数据
	- [pg-bloom-index](https://www.postgresql.org/docs/current/bloom.html) : 基于 `pg` 的 这个可能比 `redis` 成本要低很多
	- 也可以不使用 `BloomFilter` 使用 一致性 `Hash` 来做已读过滤


- 内容缓存体系: 另一个通用的技术体系，有趣的是 微博的 `L1-Main-BackUp` 模式.
## 3-Implementation

### 3-1 Design

> 这里使用 伪代码 说明整体的代码设计

> 我们考虑实现一套 重拉取，然后用 推取优化的设计，类似微博

伪代码设计地址: [FeedService](https://github.com/carl10086/carl-blogs/blob/main/cb-feeds/src/main/kotlin/com/cb/feeds/biz/FeedBizService.kt)

首先定义一个简单的 线程安全的最小堆，做 `Merge` . 返回 `TopK`, 这样不管 `Pull` 出来的用户有多少，至少内存是可控的.

```kotlin
data class FeedItem(  
    val feedId: Long,  
    val feedCreateAt: Long /*这里暂定用时间*/  
)  
  
/**  
 * 用来同步的数据结构  
 */  
data class FeedMergeHeap(private val size: Int) {  
  
    private val queue = PriorityQueue<FeedItem>(size) { o1, o2 ->  
        if (o1.feedCreateAt > o2.feedCreateAt) 1 else -1  
    }  
  
    private val lock = ReentrantLock()  
  
    fun push(items: List<FeedItem>) {  
        lock.withLock {  
            items.forEach {  
                if (queue.size < size) {  
                    queue.offer(it)  
                } else if (it.feedCreateAt > queue.peek().feedCreateAt) {  
                    queue.poll()  
                    queue.offer(it)  
                }  
            }  
        }  
    }  
  
    fun getAll(): List<FeedItem> {  
        lock.withLock {  
            return ArrayList(queue)  
        }  
    }  
}
```

> 发布 feed 的伪代码.

```kotlin
/**  
 * 假设:  
 * 1. 按照粉丝数来作为 push & pull 的条件  
 */  
fun onFeedPublish(  
    events: List<FeedPublishedDto>  
) {  
    val authorIds = events.map { it.userId }  
  
    /*1. 这些用户使用 push 策略, 基于 粉丝数或者当前上线状态计算*/  
    val pushedUsers = grpcAdapter.filterUserNeedToPush(authorIds).toSet()  
  
    /*2. 不管是推还是拉提前写入到 outBox, 并用这个作为最终一致性的兜底, 批处理*/  
    val outboxList = events.map { FeedOutboxDO(it.userId, it.feedId, it.feedCreateAt) }  
    feedOutboxDao.batchSave(outboxList)  
  
    /*3. optional, 对于粉丝数 < 多少阈值的用户, 使用 push 来减少 pull 的压力*/  
    val pushedEvents = events.filter { pushedUsers.contains(it.userId) }  
    mqSender.batchSend(pushedEvents, "push")  
}
```

1. 方法的入口是 异步化的 `mq` **批处理** 消费者, 基于 `grpc` 序列化，然后把 元信息写入 消息的 `HEADER` 中 进一步压缩内存 .
2. 对于粉丝数的比较少用户使用 `push` , 这里关系系统可以 用类似 `hash` 缓存 (`scylladb` 或者 `redis`) , 特别注重内存空间，可以考虑 `BloomFilter` ;
3. 这里做了 批处理写入, `OutBox` 是 `Batch` 写入，担心数据量太大，可以 分组一步步来 ;
4. `push` 这里选择继续发事件, 进一步提升吞吐，这里也可以直接 批处理写入 `Inbox`  ;


> 读取 关注流的伪代码如下

```kotlin
fun followingActivity(userId: Long, timeWindow: LongRange): List<FeedItem> {  
    val limit = 48  
    val heap = FeedMergeHeap(limit)  
  
    // 1. 先异步开启查询 index    
    val inboxTask = CompletableFuture.supplyAsync({  
        val inboxList = feedInboxDao.query(userId, timeWindow, limit)  
        heap.push(inboxList)  
    }, feedQueryPool)  
  
  
    // 2. 然后看下关注的高粉丝用户中，有多少这段时间内发布了内容  
    // 返回的是最好是不在 inBox 中，inBox 可以用来优化, 给 inBox 的用户打个 tag    
    val friends = grpcAdapter.queryFriendsHasPublished(userId, timeWindow)  
    val pushedUsers = grpcAdapter.filterUserNeedToPush(friends).toSet()  
  
    // 3. 我们以拉为主，所以这里底层查询优化很关键  
    // 为什么要分窗口 异步化，因为 分布式数据库会命中多个分区，小分区量的性能是最好的，这个规则也适合 mysql 分库分表  
    val outBoxTasks = friends.asSequence().filter { !pushedUsers.contains(it) }.windowed(10).map { userIds ->  
        CompletableFuture.supplyAsync({  
            val outBoxList = feedOutboxDao.query(userIds, timeWindow, limit)  
            heap.push(outBoxList)  
        }, feedQueryPool)  
    }.toList()  
  
    val allTasks = ArrayList(outBoxTasks)  
    allTasks.add(inboxTask)  
  
    // 4. 对异步任务统一超时  
    try {  
        CompletableFuture.allOf(*allTasks.toTypedArray()).get(500, TimeUnit.MILLISECONDS)  
    } catch (e: Exception) {  
        allTasks.filter { !it.isDone }.forEach { it.cancel(true) }  
        // fixme log  
    }  
  
    // TOdo ,here need to filter by exposed feed or blacklist  
    return heap.getAll()  
}
```

- 整个过程是使用 `CompletableFuture`  异步化的
- 还是那句话，严重依赖之前[[关系图谱图引擎设计]]的高性能支持
- 会对 friends 做二次过滤，**一个是时间区间内有内容发布**, 一个是已经 `push` 的，push 的阈值是自己控制的
- 最后的 黑名单，或者已读过滤，可以 考虑使用 `redis` 或者 `scylladb` 的 `key` 直接过滤掉，或者考虑 `postGreSql` 的 `bloomIndex` 都可以


### 3-2 Storage

> 也就是上面的 `Dao` 的具体实现

```kotlin
data class FeedOutboxDO(  
    /*此时 userId 就是 authorId*/    
    val userId: Int,  
    val feedId: String,  
    val feedCreateAt: Long  
)  
  
  
data class FeedInboxDO(  
    val userId: Int,  
    val authorId: Int,  
    val feedId: String,  
    val feedCreateAt: Long  
)
```

> 如果使用 `Mysql` 和 `Redis` `Memcached` 的传统方案

- `FeedOutboxDO` 的 建议如下
	- 可以按照 `userId` 分库分表
	- 表中可以进一步按照 `feedCreateAt` 进行分区，方便后续的 归档, 直接删除一个分区是很高效的
	- 索引:
		- 联合索引必须有 `userId` + `feedCreateAt` 
		- 联合索引如果 + `feedId` ， 可能会走覆盖索引，有点用
	- 对于粉丝数多的用户，可以多来几级缓存
		- `Redis` 使用 `Zset`, `key` 是 `userId`, `score` 是 `feedCreateAt`, 保留 最新的 1024 条
		- 堆内存使用 [caffeine](https://github.com/ben-manes/caffeine)


- `FeedInboxDO` 的建议如下:
	- 因为这个数据 可以用 `FeedOutboxDO` 随时保证最终一致性，可以考虑一致性没有那么强
	- 这里直接选择使用 缓存, 同上 `ZSet`, 压力再大使用 堆内存


> 如果有更先进的设施，例如 `HBase`, 云上服务 `TableStore`, 出于性能，我们这里使用 `ScyllaDb`


```sql
CREATE TABLE feeds_outbox
(  
    user_id   int,  
    feed_id text,  
    feed_create_at bigint,  
    PRIMARY KEY (user_id, feed_create_at, feed_id) ,
    WITH CLUSTERING ORDER BY (feed_create_at DESC);  
); 


CREATE TABLE feeds_inbox 
(
    user_id   int,  
    feed_id text,  
    feed_create_at bigint,  
    author_id int,
    PRIMARY KEY (user_id, feed_create_at, feed_id) ,
    WITH CLUSTERING ORDER BY (feed_create_at DESC); 
)
```

## Refer


- [2013年的新浪微博](https://www.slideshare.net/XiaoJunHong/feed-26666858) : 时间太早了，但是 `feed` 流的读扩散和写扩散这么多年没有变 ;
- [阿里云 TableStore 实现 feed流](https://developer.aliyun.com/article/706808?spm=5176.54465.J_3626598450.3.3b5d53a9VoIs0i) : 主要是 吹云产品对比开源中的 `Mysql` + `Redis` 作为存储设施的优点, 没太大特别;
- [如何为feed 场景设计缓存体系](https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/300%e5%88%86%e9%92%9f%e5%90%83%e9%80%8f%e5%88%86%e5%b8%83%e5%bc%8f%e7%bc%93%e5%ad%98-%e5%ae%8c/35%20%e5%a6%82%e4%bd%95%e4%b8%ba%e7%a4%be%e4%ba%a4feed%e5%9c%ba%e6%99%af%e8%ae%be%e8%ae%a1%e7%bc%93%e5%ad%98%e4%bd%93%e7%b3%bb%ef%bc%9f.md) : 这个文章其实不错，很中肯