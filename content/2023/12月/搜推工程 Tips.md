
## 1-Intro

> 宏观上看搜推, 可以分为 事前，事中，事后.

- 事前阶段主要关注于 数据的收集处理, 例如 事件埋点收集, 用户画像的建立, 内容属性的标签化, 特征工程对数据进行清洗，归一化，特征提取
	- 事件埋点
	- 业务型mq
	- 内容画像
		- 标签
		- 预训练模型
	- 用户画像
	- 数据清洗

- 事中阶段主要关注 推荐的算法, 核心是 召回和排序的策略.
	- 召回的阶段，系统会从大量的物品中 找到一部分感兴趣的物品
	- 排序的阶段，系统会从 这一部分物品去计算 用户特征和 物品特征
	
- 事后阶段主要关注:
	- 对推荐结果的评估和优化，通常就是 线上的 `A|B` 实验.


> 搜推大致的阶段

- 召回: 从百亿内容中提取万级别， 有非常多的通道
- 排序:
	- 粗排: 基于比较粗糙的模型, 例如双塔
	- 精排: 基于比较细致的模型, 例如 `DNN`, 图引擎等等
- 重排: 提升 多样性，留存率等等


> 召回1-协同过滤

- `item2item`: 推荐用户行为相似的 `item`
	- 寻找 `latestN` 
	- 基于 `latestN` 扩散为 行为相似的 `item`

**多样性能力非常弱, 表达能力有限**

> 召回2-embedding

- 离线学习 `item` 的 `embedding`
- 把 `user` 和 `item`  或者搜索词, `embedding` 到同一个向量空间


**活跃的用户有大量的行为**: 降低活跃用户的权重有利于提高模型的整体表现
**丢失用户的行为序列**: 可以改善用户体验, 比如 用户点赞了某个内容，立马推荐相关内容的体验是 **不好的**
搜索的位置偏差: click -> 




> 排序-经典 `DeepCtr`.


- [DeepCtr](https://github.com/shenweichen/DeepCTR)

从召回的内容中，进行排序.

- `Position Bias`: 用户喜欢点击位置 靠前的 `doc`, 就算相关度不高.
- `Deep Interest Network`:
	- 用户对多样性感兴趣，就是多种不同类型的组合推荐起来效果更好
	- `Location Activation` : 用户会是否会 点击 `item`, 有用的是 历史行为数据中的 **一小部分**， 而不是全部

## 2-Engineering Overview


> 这里主要的关注点 

- 主要是 业务层 service 提供服务的 工程化, 也就是更多的偏向 `OLTP` , 但是要知道 `OLAP` 的数据分析在 搜推系统中 非常的重要, [大家都知道数据是上限，一个正负样本就麻烦](https://www.zhihu.com/question/324986054) ;
- 上面主要是描述 大致的 场景, 大多数的 搜推都是 召回和排序, 算法的实现也多种多样 ;


> 涉及的常见数据库

- 例如 `latestN` 一般是用户最近感兴趣的行为序列，一般是一个时序数据库，考虑使用 `MongoDb` 的 `TimeSeries` 这种是不错的 ;
- 搜索如过用到文本排序, `ElasticSearch` 肯定是不错的 ;
- 要存储 偏全量的内容 `Vector`, 例如 大模型提前 提取出 `item` 的文本特征，图片特征，这个时候仅仅是存储，方便 `findVectorById`, 这个时候使用 分布式的 `Nosql` 做 `KV` 是很合适的，**如果存储到 矢量数据库做 ANN**, 可能会构建出 `HNSW` 这种索引，性价比不高
- 基于 [[数据结构-HNSW]] 的索引的话，就需要专业的 矢量数据库了，例如 `Es8` , `Qdrant` 等等


> 矢量库

除了 大名鼎鼎的 [Facebook faiss](https://github.com/facebookresearch/faiss)， 还可以考虑一下 [Spotify voyager](https://github.com/spotify/voyager) .

> 场景

- 先小一点，假设10亿 `item`, 日活 `100W` 用户. 
- 搜推 `qps` 各 1W 左右


> 召回缓存


1. 召回层，可能涉及到离线的任务，一般都是可以缓存. 用 `item2item` 为例,   要 根据 `itemId` 寻找 `itemList`
	- 每次全量任务只涉及到有行为的 `item`, 但是这个量级也很高，估计有百万甚至千万，这个的结果应该考虑低成本的方案, 例如 `HBase` ;
	- 要支持 `qps` 的话比较高，可以再用 `Redis` + 应用内缓存 搞个 双层 `lru` ;

2. 召回层，可能需要 `latestN`, 时序数据库一般有很明显的 时间索引，`qps` `1W` 个人不需要特别的缓存, 而且有明显 最近数据是热数据倾向，也比较容易扩展

3. 召回层，可能用到 `search`, 一万左右的 `qps` 的话， `Es` 是个分布式的引擎，可以支持，但是由于是 `Java` 类型的中间件 成本会更高, 数据量有一亿的话不大. 假设是 基于文本召回的话，要优化性能和成本的话:
	- 从全量召回效果不好，可以基于 热榜 减少数量
	- 使用 `ManticoreSearch` 替换 `Es`, **不推荐为了一个召回改存储引擎** 
	- 使用 `Elasticsearch` 本身的优化，东西很多. 例如 `Filter` 都是有 `Bloom` 缓存的

4. 召回层 和 排序层, 都可能用到 实时的 `Embedding` 矢量引擎, 比如双塔
	- 想要效果好，维度可能高, 高维度使用 点积而不是内积 能明显优化性能, 绝对别用 欧式距离，维度地狱
	- 牺牲效果, 量化等等 或者降维, `qdrant` 自带量化，推


5. 精排层，可能用到矢量库. 实时构建小规模的 搜索.
	- 可能用到 `scylladb` 这种 `kv` 去获取对应的 `Vector`, 这里可以不缓存，因为 `kv` `findByKey` 性能都很顶, 才区区 1W qps, 再翻 100倍 `100W` `qps` 也不慌
	- 如果要用缓存, 这里考虑使用 `userId` 级别的缓存, 因为你这里肯定排序了几百个，一次请求肯定消耗不完, 而且 主要是高维度向量取出来的 时间成本就很高, 可以考虑这里的 缓存使用滑动窗口算法, 当低水位过的时候 再重新构建
	- 推荐 [Spotify voyager](https://github.com/spotify/voyager) 


6. 召回层, `lastestN` 例如用户最近非常感兴趣 的 100张图片
	- 可以提前做 `lasestN` 的 矢量画像, 下面举个简单的例子.
		- 计算这 100 张图片的 `vector`, 假设是 `1024` 维
		- 用 `mq` 消费用户的兴趣行为. 
		- 假设算法是 `maxPooling`. 我们就实时的更新这个用户 最新 100 个 `vector` 每个维度上的 `max`, 然后做标准化.



> [!NOTE] Tips
> 原本的数据内容，计数啊，排序啊，这种都属于内容系统和计数系统本身的 性能问题，搜推暂不考虑

## 3-Implementation

> 比较关系的事件打点


- `ios`: https://opensource.sensorsdata.cn/wp-content/uploads/%E7%A5%9E%E7%AD%96%E6%95%B0%E6%8D%AEiOS%E5%85%A8%E5%9F%8B%E7%82%B9%E6%8A%80%E6%9C%AF%E7%99%BD%E7%9A%AE%E4%B9%A6.pdf
- `安卓`: https://opensource.sensorsdata.cn/wp-content/uploads/%E7%A5%9E%E7%AD%96%E6%95%B0%E6%8D%AE-Android_%E5%85%A8%E5%9F%8B%E7%82%B9%E6%8A%80%E6%9C%AF%E7%99%BD%E7%9A%AE%E4%B9%A6.pdf


## Refer


- [ctr模型中-构造正负样本的 `trick`](https://www.zhihu.com/question/324986054)
- [如何理解归一化](https://zhuanlan.zhihu.com/p/424518359)
- [Twitter Recommend Algorithm](https://blog.twitter.com/engineering/en_us/topics/open-source/2023/twitter-recommendation-algorithm)
- [TorchRec](https://pytorch.org/blog/introducing-torchrec/): `Pytorch` domain library for Recommendation Systems.
- [小红书大佬的工业化推荐系统](https://github.com/wangshusen/RecommenderSystem)
- `Pinterest`:
	- [如何利用用户行为](https://medium.com/pinterest-engineering/how-pinterest-leverages-realtime-user-actions-in-recommendation-to-boost-homefeed-engagement-volume-165ae2e8cde8)
	- [首页的机器学习](https://medium.com/pinterest-engineering/pinnability-machine-learning-in-the-home-feed-64be2074bf60)
	- [SearchSage](https://medium.com/pinterest-engineering/searchsage-learning-search-query-representations-at-pinterest-654f2bb887fc)