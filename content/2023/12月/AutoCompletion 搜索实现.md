
## 1.Intro


> 大致的功能描述

假设我们现在有一堆文本用于搜索了，这个索引称为 `cb_content_idx`. 

- 其中的被搜索的字段是内容 `content`

功能性需求:

1. 需要一个数据结构，一般是前缀树之类的东西(`Trie`) ;
2. 基于什么样的内容构建这个数据结构，或者说数据来源.
	1. 基于用户最新的搜索文本
	2. 基于内容 `content` 或者 基于内容 中的关键词来构建, 
3. 是 词的补全，还是 句子的补全
4. 是只要  前缀补全，还是 `fuzzy`, 还是要支持 `regex`
5. 是否考虑 使用个性化，对不同的用户实现不同的 推荐搜索词 等等


> deeply

从这个需求的目的来看，是一个 `Search Suggester` 提升搜索的体验. 这样看要配合打点  **去验证体验的效果**. 大致的场景 这里分为:

1. 最近常搜: 基于最近的 搜索行为构建
2. 猜你想搜: 基于 深度学习算法 构建
3. 搜索补全: 基于内容 构建, 减少用户 `type` 的次数，并且辅助准确的分词


需求确认后 还需要看是要词的补全，还是句子的补全


> 这里使用 多种方案来实现.


1. 使用 `PrefixSearch`, 比如各种数据库的前缀查询都能满足索引要求. `RDB` 的 `WHERE like '{prefix}%'`, `ElasticSearch` 的 [PrefixQuery](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-prefix-query.html)
2. 使用 `ElasticSearch` 的 `Suggester` , 可以参考 [[ElasticSearch suggesters 理解]]
3. 使用 `ManiCoreSearch` 支持基于词的补全和句子的补全
4. 使用一个 `Trie` 树的库 来满足需求


> [!NOTE] Tips
> 为了不引入额外的复杂性，我们这里统一用中文, 然后使用 `whitespace` 分词器或者类似的机制来演示.


## 2-Support by Es

> 创建对应索引

PUT cb-sch-completion
```json
{
  "mappings": {
    "properties": {
      "suggest": {
        "type": "completion",
        "analyzer": "whitespace",
        "search_analyzer": "whitespace"
      }
    }
  }
}
```

> 准备数据

POST cb-sch-completion/_bulk
```json lines
{ "index" : { } }
{"suggest":"苹果 耳机"}
{ "index" : { } }
{"suggest":"苹果 电脑"}
{ "index" : { } }
{"suggest":"苹果 手机"}
{ "index" : { } }
{"suggest":"苹果 手表"}
{ "index" : { } }
{"suggest":"苹果 平板电脑"}
{ "index" : { } }
{"suggest":"小米 耳机"}
{ "index" : { } }
{"suggest":"小米 电脑"}
{ "index" : { } }
{"suggest":"小米 手机"}
{ "index" : { } }
{"suggest":"小米 手表"}
{ "index" : { } }
{"suggest":"小米 平板电脑"}
```

> 推荐

GET cb-sch-completion/_search
```json
{
  "_source": ["suggest"],
  "suggest": {
    "tst": {
      "prefix": "小米 电脑",
      "completion": {
        "field": "suggest",
        "size": 3,
        "fuzzy": {
          "fuzziness": "AUTO"
        } 
      }
    }
  }
}
```


## 3-Support by ManicoreSearch


> 启动一个 `manicore-search`

```bash
docker run -e EXTRA=1 --name manticore --rm -d -v ./data:/var/lib/manticore/ manticoresearch/manticore && until docker logs manticore 2>&1 | grep -q "accepting connections"; do sleep 1; done && docker exec -it manticore mysql && docker stop manticore
```

> 准备数据

```sql
-- 1. 删除 blogs 表
drop table blogs;

-- 2. 创建表 blogs
CREATE TABLE blogs ( 
    id INTEGER, 
    title TEXT
) 
min_infix_len='1' charset_table='cjk';

INSERT INTO blogs(id, title) VALUES (1, '苹果 耳机'), (2, '苹果 电脑'), (3, '苹果 手机'), (4, '苹果 手表'), (5, '苹果 平板电脑'), (6, '小米 耳机'), (7, '小米 电脑'), (8, '小米 手机'), (9, '小米 手表'), (10, '小米 平板电脑');
```


> 查询结果如下:

```sql
mysql> select highlight(), id from blogs where match('小米');
+----------------------------+------+
| highlight()                | id   |
+----------------------------+------+
| <b>小米</b> 耳机           |    6 |
| <b>小米</b> 电脑           |    7 |
| <b>小米</b> 手机           |    8 |
| <b>小米</b> 手表           |    9 |
| <b>小米</b> 平板电脑       |   10 |
+----------------------------+------+
```


> manicore 有2种做法

1. 一种打开 [infix_search](https://manual.manticoresearch.com/Creating_a_table/NLP_and_tokenization/Wildcard_searching_settings#min_infix_len) 功能来支持 前缀，通配符搜索
2. 第二种使用 特殊的 [CALL KEYWORDS](https://manual.manticoresearch.com/Searching/Autocomplete#Autocomplete-a-word) 功能, 来实现 词级别的自动推理

```sql
Usual@10.200.64.3:9306 [(none)]SELECT * FROM blogs WHERE MATCH('小*');
+------+---------------------+
| id   | title               |
+------+---------------------+
|    6 | 小米 耳机       |
|    7 | 小米 电脑       |
|    8 | 小米 手机       |
|    9 | 小米 手表       |
|   10 | 小米 平板电脑 |
+------+---------------------+
5 rows in set (0.00 sec)

Usual@10.200.64.3:9306 [(none)]>CALLKEYWORDS('小*', 'blogs');;
+------+-----------+------------+
| qpos | tokenized | normalized |
+------+-----------+------------+
| 1    | 小*      | 小米     |
+------+-----------+------------+
1 row in set (0.01 sec)
```




## 4-Latest Search


> 我们暂时关注在 具体的问题 最近常搜这个需求上.

> 数据收集, 原始的搜索事件，我们可能需要收集如下字段

- `distintId` : 用户或者设备等等，可选的临时 id 标记一个用户 ;
- `sentence` : 用户的搜索语句, 一般会 **比较短**, 可以选择提前分词
- `searchAt` : 搜索时间

> 我们转换数据

| Query | Time        | Frequency |
|-------|-------------|-----------|
| tree  | 2019-10-01  | 12000     |
| tree  | 2019-10-08  | 15000     |
| tree  | 2019-10-15  | 9000      |
| toy   | 2019-10-01  | 8500      |
| toy   | 2019-10-08  | 6256      |
| toy   | 2019-10-15  | 8866      |


> 假设用 `Mysql` 实现


```SQL
SELECT * FROM frequency_table WHERE query LIKE 'prefix%' ORDER BY frequency DESC LIMIT 5;
```


> 考虑使用 `Trie` 树结构的缓存帮我们优化这个性能.


![](https://bytebytego.com/images/courses/system-design-interview/design-a-search-autocomplete-system/figure-13-6-M5EZD5SL.svg)


- 通常遍历子树，得到所有的满足 `tr` 开头的字节点，**然后排序** , 这个过程可能非常消耗时间


> `Trie`  树每个节点上使用  堆缓存 `TopK`


![](https://bytebytego.com/images/courses/system-design-interview/design-a-search-autocomplete-system/figure-13-8-4HDDZCTY.svg)


> 根据密集性原理，最近常搜应该一段时间内是不变的，可以考虑在出口缓存, 下面是 `Google` 的缓存时间可以参考

![](https://bytebytego.com/images/courses/system-design-interview/design-a-search-autocomplete-system/figure-13-12-IKMFWP5J.svg)



> 总结: 我们会把 整个系统分为 `Gathering Service` 和 `Query Service`.

读服务的核心是一个 类似 `Trie` 树结构的缓存层，可以考虑自研或者用 `Es` 等:

- 这个服务有很强的时效性，可以考虑 时间维度的缓存



![](https://bytebytego.com/images/courses/system-design-interview/design-a-search-autocomplete-system/figure-13-9-O7NXHK4L.svg)



- 写服务可以定时分析日志
	- 如果是 **自研**, 可以考虑使用 `Flink` 负责写, `MongoDb` 存储原始数据, `TrieCache` 使用 `Redis`, 参考 [How we build a scalable prefix search service](https://medium.com/@prefixyteam/how-we-built-prefixy-a-scalable-prefix-search-service-for-powering-autocomplete-c20f98e2eff1)
	- 也可以基于 `Es` 的数据滚动，存最近的 30天搜索日志

## Refer

- [NeuralSearch Course](https://academy.algolia.com/collections/0df7d4fa-ce59-11ed-90c9-067360dfb065)
- [ElasticSearch PrefixQuery](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-prefix-query.html)
- [How We build a scalable prefix search service](https://medium.com/@prefixyteam/how-we-built-prefixy-a-scalable-prefix-search-service-for-powering-autocomplete-c20f98e2eff1)
- [System Design Of a Search AutoComplete System](https://bytebytego.com/courses/system-design-interview/design-a-search-autocomplete-system)
