
#mq #dev


## Intro

- 内容均来自 官网, 无太大价值

## 1-Producer



> 关于 tag

一个应用尽可能的使用一个 `Topic`, 消息子类则 建议用 `tags` 来过滤.

- `tags` 更灵活
- 但是生产者好像发送消息的时候仅仅只能支持设置 `tag`


[如何规划 topic 和 tag](https://help.aliyun.com/zh/apsaramq-for-rocketmq/cloud-message-queue-rocketmq-4-x-series/use-cases/best-practices-of-topics-and-tags)


> 关于 key


应该使用 业务上的唯一标志 `keys` 来标志，可以方便定位 后续的 **消息丢失问题**. 

- 服务侧会为 每个消息创建一个 `Hash` 索引, 应用可以使用 `topic` + `key` 组合起来查询消息内容.


> 关于日志

- **消息发送成功或者失败都要打印日志**.   排查问题? 
- `send` 方法没有异常则代表成功



> 消息发送失败了如何处理 ?

- 内部支持 [RocketMq 重试策略](https://rocketmq.apache.org/zh/docs/featureBehavior/05sendretrypolicy)
- 业务侧可以用 `DB` 兜底, 二阶段发送什么的.



> [!NOTE] Warn
> RocketMq 客户端这一侧是 **异步的**, **非持久化的**, 非正常重启容易造成数据丢失, 例如 `kill -9`



## 2-Consumer

> 消费者的幂等


- `RocketMQ` 无法做到 端到端的幂等, 业务如果对重复消费 非常敏感，需要自己做去重处理 ;
- 幂等最好用 **业务方自己的字段，而不是 RocketMQ 这一侧生成的 id**


> 提高消费的并行度

- 多进程，属于同一个 `ConsumerGroup` 即可.
- 多线程, 使用 `PushConsumerBuilder.setConsumptionThreadCount()` 设置


> 批量消费


使用 `SimpleConsumer`, 其中支持批量消费


> 重点位置跳过非重要消息

- 可以使用 重置位点的功能，重置到指定位置


> 消费者日志

- 如果消息少，打印日志


> 消费重试 

- [rocketMq 消费重试机制](https://rocketmq.apache.org/zh/docs/featureBehavior/10consumerretrypolicy/)

中间件自己提供的重试机制 **不应该用来做流程控制，是为业务兜底的**.  不应该用来限流 和 逻辑分流 ;

- 服务端会根据 重试策略重新消费该消息, 超过一定的次数没有成功，会 **停止尝试**,  然后进入 **死信队列** ;


触发条件:

- 消费失败, 非预期异常, 直接返回失败
- 处理超时, 没有在 一定时间内 返回 `ConsumeResult.SUCCESS`

重试策略行为 **可配置项**:

- 重试过程状态机: 消息本身是一个状态机
- 重试间隔: 上一次消费失败或者超时后, 下次重新尝试消费的间隔时间
- 最大重试次数: 消息可悲重试消费的最大次数


| 消费者类型          | 重试过程状态机                 | 重试间隔                                   | 最大重试次数          |
| -------------- | ----------------------- | -------------------------------------- | --------------- |
| PushConsumer   | _已就绪_ 处理中 _待重试_ 提交 * 死信 | 消费者分组创建时元数据控制。 _无序消息：阶梯间隔_ 顺序消息：固定间隔时间 | 消费者分组创建时的元数据控制。 |
| SimpleConsumer | _已就绪_ 处理中 _提交_ 死信       | 通过API修改获取消息时的不可见时间。                    | 消费者分组创建时的元数据控制。 |


这里用 `PushConsumer` 的重试状态机为例子.

![](https://rocketmq.apache.org/zh/assets/images/retrymachinestatus-37ddbd0a20b8736e34bb88f565945d16.png)



1. `Ready` : 已就绪状态, 消息在 `RocketMQ` 服务端就绪, 可以被消费者消费 ;
2. `Inflight` : 处理中, 消息被消费者客户端获取, 处于消费中还未返回消费结果的状态 ;
3. `WaitingRetry`: 待重试状态, `PushConsumer` 才拥有这种状态,  如果 **失败** 或者 **超时**, 没有达到次数未达到最大次数, 消息会变为 **等待重试** 的状态 . 多次重试之间，会刻意延长重试间隔，防止高频无效 ;
4. `Commit`: 提交状态, 消费成功的状态, 消费者返回成功响应即可 结束消息的状态机 ;
5. `DLQ`: 死信状态, 消费逻辑的最终兜底机制, 可以通过消费死信队列的 消息进行业务恢复;



