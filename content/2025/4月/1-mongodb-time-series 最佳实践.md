
## 1-介绍

**1. 简介**

- `Mongodb` 专门为 时间序列数据, 例如日志 设计的优化集合类型
- 工作原理:
	- 内部用列式存储数据, 大幅度减少了 存储空间的占用, 并提高了时间范围查询的性能
- 优点:
	- 列存: 高压缩，适合分析，参考 `Clickhouse`
	- 支持 `Wildcard Indexes`: 允许为文档中 未知或者变化的字段 创建索引
	- 自动的 `TTL` 索引过期掉历史数据
	- 自动在 时间字段和 `metaField` 上有联合索引
	- 支持 **物化视图**
- 缺点:
	- 不能手动删除，自动根据时间过期(到 `8.x` 版本支持)


**2. demo**

```javascript
db.createCollection(
   "stocks",
   {
      timeseries: {
         timeField: "timestamp", // 假设时间字段叫 timestamp
         metaField: "metadata",   // 指定包含所有元数据的字段名
         granularity: "minutes"
      }
   }
)
```

- 指定了 分桶策略是 `minutes`

**3. 属性**

1. 文档按照顺序到达, 需要频繁的插入操作来追加他们
2. 更新操作很少见, 因为每个文档都代表一个时间点
3. 基本没有 **删除操作**
4. 数据使用按 时间和标识符

## 2-分桶

**1.分桶是什么**

`Mongodb` 会使用专门的 **列式存储**, 把一定规则的 文档归拢到一起, 这个功能会有如下的优点:

1. 减少存储和索引的大小
2. 提高查询的效率
3. 减少读取操作的 `I/O` 量
4. 增加了 `WiredTiger` 内存缓存的使用量, 提高查询的速度
5. 降低处理  时间序列数据的复杂性

分桶规则: `metaField` + 时间粒度

**2. 时间粒度如何影响分桶**

**granularity** 是一个 `hint` ，而不是强制规则, 目的是为了告诉 `MongoDb` ， 对某一个 `metaField`, 预期的数据有多密集. 

- `⁠granularity`: "seconds" 的意思是：“嘿，MongoDB，对于 ⁠sensorA，我很可能会在一秒内或者几秒内就记录好几个数据点，数据是很密的。”
- ⁠`granularity`: "minutes" 的意思是：“对于 ⁠sensorA，数据点大概每隔几分钟会出现一次。”
- ⁠`granularity`: "hours" 的意思是：“对于 ⁠sensorA，数据点可能一小时才出现一两个。”

桶的时间跨度由内部算法决定，受 ⁠granularity 影响： MongoDB 需要在“桶不能太大以至于加载缓慢”和“桶不能太小以至于数量过多、元数据开销大”之间找到平衡。它会综合考虑 ⁠granularity 的提示以及其他参数（如 ⁠bucketMaxSpanSeconds 和 ⁠bucketRoundingSeconds，如果用户设置了的话）和内部的优化策略，来决定一个桶实际覆盖多长的时间.

参考:

| `granularity` | `granularity` 存储桶限额 |
| ------------- | ------------------- |
| `seconds`     | 1 小时                |
| `minutes`     | 24 小时               |
| `hours`       | 30天                 |


> [!NOTE] Tips
> 你可以把时间集合的粒度, 从 精细 -> 粗糙, 但是不能缩小

**3. MetaField 如何影响分桶**

```javascript
{
   timestamp: ISODate("2021-05-18T00:00:00.000Z"),
   metadata: { sensorId: 5578, type: 'temperature' },
   temp: 12,
   _id: ObjectId("62f11bbf1e52f124b84479ad")
}
```


由于 `metaField` 的值必须和分组文档 完全匹配, 有如下的最佳实践:

• **稳定性优先:** 再次强调，选择**很少或从不更改**的字段。
• **常用过滤条件:** 选择那些你**经常用在查询条件 (****⁠****WHER****E****/****⁠****fin****d** **的** **⁠****filte****r****)** 中的稳定标识符。如果你总是按 ⁠sensorId 查，那它就是好选择。
• **避免不用作过滤的字段:** 如果某个字段你**从来不会**用它来过滤数据，就**不要**把它放进 ⁠metaField。把它当作普通的“测量值”字段即可。这能保持 ⁠metaField 简洁高效。


## 3-物化视图

```javascript
db.weather.aggregate([
  {
     $project: {
        date: {
           $dateToParts: { date: "$timestamp" }
        },
        temp: 1
     }
  },
  {
     $group: {
        _id: {
           date: {
              year: "$date.year",
              month: "$date.month",
              day: "$date.day"
           }
        },
        avgTmp: { $avg: "$temp" }
     }
  }, {
     $merge: { into: "dailytemperatureaverages", whenMatched: "replace" }
  }
])
```

基于时间序列的物化视图.

- 这个管道会根据 `weather` 集合创建或者更新包含所有每日温度平均值的 `dailytemperatureaverages` 集合.

## 4-索引

- 使用 metaField 索引进行过滤和相等操作。
- 使用 timeField 和其他索引字段进行范围查询。
- 一般索引策略也适用于时间序列集合。有关更多信息，请参阅[索引策略](https://www.mongodb.com/zh-cn/docs/manual/applications/indexes/#std-label-indexing-strategies)

1. 默认的 复合索引是 metaField 等值或者 `IN` 查询 然后 时间区间查询吗?
2. 普通的 二级索引是 在 bucket 级别还是全局级别， 使用普通的 二级索引也必须带上 时间条件吗？ 或者说带上时间区间会更好吗 ？ 

## 5-最佳实践

**1. 压缩最佳实践**

如果数据中包含了空对象， 数组或者字符串, 请从文档中省略空字段来优化压缩性能.

```javascript
{
   timestamp: ISODate("2020-01-23T00:00:00.441Z"),
   coordinates: [1.0, 2.0]
},
{
   timestamp: ISODate("2020-01-23T00:00:10.441Z"),
   coordinates: []
},
{
   timestamp: ISODate("2020-01-23T00:00:20.441Z"),
   coordinates: [3.0, 5.0]
}
```

上面的有 空数组, 会影响到 压缩的 **性能范式**, 直接就不要传递这样的东西.

```javascript
{
   timestamp: ISODate("2020-01-23T00:00:00.441Z"),
   coordinates: [1.0, 2.0]
},
{
   timestamp: ISODate("2020-01-23T00:00:10.441Z")
},
{
   timestamp: ISODate("2020-01-23T00:00:20.441Z"),
   coordinates: [3.0, 5.0]
}
```

**2. 四舍五入到小数点 最后几位**

- 控制精度的意思了


**3. 批量写**

**4. 写入的时候保持固定的字段顺序**

```javascript
{
   range: 1,
   _id: ObjectId("6250a0ef02a1877734a9df57"),
   name: "sensor1",
   timestamp: ISODate("2020-01-23T00:00:00.441Z")
},
{
   _id: ObjectId("6560a0ef02a1877734a9df66"),
   name: "sensor1",
   timestamp: ISODate("2020-01-23T01:00:00.441Z"),
   range: 5
}
```


**5. 二级索引要在 timeField 和. metaField 上创建**

如果是更高的版本 (大于 `6.3` )， 只要是创建二级索引， 就一定是自动在上面

**6. 如果 metadata 是 复合对象, 使用 所有的 子属性查询， 而不是 直接在 metadata 上进行查询**

```javascript
db.weather.findOne( {
   "metaField.sensorId": 5578,
   "metaField.type": "temperature"
} )
```


## refer

- [介绍](https://www.mongodb.com/zh-cn/docs/manual/core/timeseries/timeseries-quick-start/)