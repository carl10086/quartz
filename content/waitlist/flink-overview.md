

## 1-Intro

## 2-Stateful Stream Processing

> State

Stateful 是指 `Operation` 的状态. `Operation` 是指一些函数运算, 例如 `Map`, `Reduce` , `KeyBy`. 这些运算可能需要 多个事件的信息(**一般**都配合一个时间窗口):

- 时间窗口聚合， 历史数据分析
- 机器学习模型 定时更新 checkpoint
- ..


> Keyed State: 有没有做 keyBy, 状态是不是属于 Key 级别的，对应还有 Operator State, 没有 KeyedState 这么常用


- 某个状态属于 `Key` 级 ;
- 实现上 可以类比为一个 `embedded key/value store` ;


> State Persistence


- 定期的持久化 当前的 `State`, 比如说 `KeyedState` 就是类似 `KV` 的内容到持久化的存储
- 这个是一个纯异步的过程，完全不阻塞的算法
- 但是哪怕是一个 异步的过程, 也是消耗资源的，可以用 `CheckPoint` 的间隔来在 开销和恢复时间上做取舍来取得平衡.
- `SavePoint` 和 `CheckPoint` 本质上都是做一个 `State Snapshot` 的机制, 前者是 手动触发，默认禁止，后者是一个自动的过程，仅仅需要配置间隔.
- 快照的机制 需要 `Source`, 也就是事件源头提供重放的功能，例如 `Kafka`


> [barrier 算法](https://nightlies.apache.org/flink/flink-docs-release-1.18/docs/concepts/stateful-stream-processing/)


1.  数据源里面会周期性的发送一个 `Barrier` , 配合一个全局递增的检查点版本号(`n`) ;
2. `Barrier` 是一个特殊的事件标记, 收到这个标记的 `Operator` 会进行一次快照，然后把这个 状态保存到 `StateBackend`, 所以 `Barrier` 有点像一个全局的时间戳, 类似 `Lamport timestamp`
3. 这个时候就形成了某个版本的 快照, 这个版本就是检查点版本号，这个一致的视图被称为检查点状态，被保存在 `StateBackend` 中
4. 这个 检查点状态会 通过异步的过程 存储到持久化的 `CheckPointStorage` 中


> 大致的流程

![](https://nightlies.apache.org/flink/flink-docs-release-1.18/fig/checkpoints.svg)

## 3-Timely Stream Processing


> 时间


- `Processing Time`: 获取到 `Operator` 所在机器的当前时间. 这个时候不会有准确的时间概念，简单性能好, **如果你不 care 时间**, 可以用 ;
- `Event time`: 业务方定义的 时间，这个时候证明 时间是比较重要的, 能处理 **一定程序的上的无序**, 代码则是一定的 [延迟](https://nightlies.apache.org/flink/flink-docs-release-1.18/docs/concepts/time/#lateness) ;


> 一个 小 `demo`


```java
WatermarkStrategy<DelayEvent> strategy = WatermarkStrategy.<DelayEvent>forBoundedOutOfOrderness(Duration.ofSeconds(  
        10L))  
    .withTimestampAssigner((event, currentTime) -> event.occurAt);
```


- 表示 允许 10L 的乱序，也就是延迟.
- 当 watermark 推进到 t0 的时候, 会选择关闭 (t0-10s) 之前的窗口, 也就是延迟大约是 `10L`