
## 1-Intro


> 基本的数据结构


- 倒排索引使用 `MMAP` 
- 对于 `Keyword`, `long` 等非 `text` 在磁盘上有 列存，也就是 `docValues` 对 排序和聚合很友好，也可以在 关闭了倒排索引(`index=false`) 的时候进行查询，性能不如原始的倒排索引
- `fielddata` 强行给 `text` 开启 列存分析，成本太高，官方非常不建议
- 高级数据结构，针对一些特殊的类型会使用 会在内存上开辟新的数据结构
	- [completion](https://www.elastic.co/guide/en/elasticsearch/reference/current/completion.html): 类似 Trie 树
	- [vector](https://www.elastic.co/guide/en/elasticsearch/reference/current/dense-vector.html): 使用了 `HNSW`
	- [Node query cache](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-cache.html): 会使用 `LRU` 为 `filter` 查询进行缓存.
	 

## 2-Write 原理


> [!NOTE] Tips
> `Es` 的 `refreshApi` 会调用 `Lucene` 的 `flushAllThreads` 方法，而 `Es` 的 `flushApi` 调用了 `lucene` 的 `commit` 方法，可能会混淆



> 为什么写入 es 之后没有 refresh 的时候很可能看不见这个数据?


- `Es` 有一个`IndexBuffer` , 其实就是 `Lucene` 的 `IndexBuffer` ;
- `Es` 的 `Shard` 对应一个 `Lucene` 实例, 这个实例有多个 `Segment` ;
- `Es` 的 `index` `document` 仅仅是调用了 `Lucene` 的 `Api-AddDocument`, 写入到了 `IndexBuffer`， 此时一般不可见，需要触发 `refresh` 机制, `es` 的 `refresh` 触发了 `lucene` 源码中的 `flush`
	- 可能的原因:
		- `doc` 数目达到阈值
		- `DWPT`的 `buffer` 达到一个配置的阈值, 默认是堆内存的 `10%`, 达到上限了就会 `flush`
		- 当前写入的 `DWPT` 内存达到 `RAMPerThreadHardLimitMB` 限制，也很难发生
	- 所以 要 `es` 周期性或者手动调用 `refresh` 才能保证触发
	- `Lucene` 当前的 `flush` 的操作不会阻塞当前的写入 


**lucene 写入数据原理图如下:**


![](https://file.notion.so/f/f/503e0985-4448-4daf-816d-826e0a0d26e0/1ea24024-266c-40f4-84cd-941563fd00f3/Untitled.png?id=91d7e38e-97ef-47f9-830f-1f28ef07bcc3&table=block&spaceId=503e0985-4448-4daf-816d-826e0a0d26e0&expirationTimestamp=1703757600000&signature=nxvAqMX2rmwQ83oOO9fnRF6w4nhabT6FGNk53ZFwH2I&downloadName=Untitled.png)





> 哪怕是 refresh 依旧是 仅仅把 数据从 堆内存写入到 pageBuffer


![](https://file.notion.so/f/f/503e0985-4448-4daf-816d-826e0a0d26e0/c32afb62-c9ba-44ef-8b99-c7bbb9530de5/Untitled.png?id=212368c7-4ed9-4ba4-a187-68410b6491fe&table=block&spaceId=503e0985-4448-4daf-816d-826e0a0d26e0&expirationTimestamp=1703764800000&signature=_DGMVJhxKjruJlHfDGDk8uI_ceKdXRScQpa5wP83v6Y&downloadName=Untitled.png)



> refresh 之后会触发 mayBeMerge 尝试去触发 多个 `segment` 的合并.


- `lucene` 的 `segment` `merge` 机制是 `size-based` 的, 把相同大小的合并到一起
- `merge` 的操作是纯异步的
- 太大的 `segment` 将永远留着, 这也是不要轻易 `forceMerge` 的一个原因.
- 算法:
	1. segments按size降序排列
	2. 计算 `total segments size` 和 `minimum segment size`
	3. `total segments size` 过滤掉 `tooBigSegment` (大于max_merged_segment/2.0)的segment，并记录 `tooBigCount`；`minSegmentBytes` 如果小于 `floor_segment`（默认2mb)，取2mb
	4. 计算allowedSegCountInt，当segments（不包含tooBigSegment）数量大于此数，将触发merge
	5. 从大到小遍历段，以每个段为起点，使用贪心算法找出不大于 ﻿maxMergeAtOnce 且总大小不超过 ﻿maxMergedSegmentBytes 的段作为待合并对象。选择合并得分（﻿mergeScore）最低的来进行合并




> Lucene. 的 commit 太慢了，所以 `Es` 设计了 `TransLog`


- 要想彻底的持久化，需要调用 `commit`, 对性能影响太大.
- 为了保证一致性, `Es` 做了特别的工作，就是 `TransLog` 来保证一致性，原理类似 `Mysql` 的 `RedoLog`, 使用顺序 IO, [Translog](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-translog.html)
- 而 `Es` 的 `flushApi` 则是调用 `lucene` 的 `commit` 并且生成一个新的 `TransLog`




## 3-分布式算法
