

## 1-Intro

 [原文](https://netflixtechblog.com/migrating-netflix-to-graphql-safely-8e1e4d4f1e72)

> 学习一下 `Netflix` 的 `API` 安全迁移，虽然文章内容是关于 传统的 API 迁移为 GraphQL API, 但是看下来是一个 方法论



> 背景


1. `Netflix` 之前开源了一个 客户端侧的框架 [FACLOR](https://netflix.github.io/falcor/) : A JavaScript Lib for efficient data fetching
2. 然后，最近他们的后端是 `Netflix` 的图联邦架构. [Federated GraphQL](https://netflixtechblog.com/how-netflix-scales-its-api-with-graphql-federation-part-1-ae3557c187e2)


因此，要迁移 `API`, 大量的 `API`.


> GraphQL

本质上 跟 `GRPC` 一样， 最核心的理念是 **Schema-First**, 其他的细节都差不多.



> 迁移计划


目前的现状，是一个单体的 `monolithic API SERVER` 作为后端网关.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202181535.png?imageSlim)


## 2-Actions


> 第一阶段, 基于原有的 API 上面加入一个中间层.


这里说一下核心的想法:


- 在原有的 `API` 上层设计一个中间层, 核心目的是为了 **最小成本的改造**. 基于这个改造，可以达到如下目的:
	- 快速
	- 客户端基于这个版本测试不同的 `GraphQL` 客户端， 包含
		- 细节的规范化，统一化，例如缓存模式
		- 研究 各种客户端实现的性能


官方图如下:

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202181907.png?imageSlim)



- 技术中间层 `GraphQL Shim Service`: 把 `GraphQL` 请求翻译为 之前的 server 可以理解的 api
- 测试策略: **AB Testing**, 通过灰度部分的用户或者客户端来测试




> 第二阶段: 废弃掉 之前的项目， 老的后端网关，迁移到新的 GraphQL 联邦网关上.


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202182144.png?imageSlim)


这一阶段的策略主要是:

- **Replay Testing**: 回放测试策略， 基于抓包或者历史数据 回放请求，一定要是 **幂等的** , 看是否有预期的结果，容易自动化.


AB测试 和 Sticky Canary测试 都是对产品或者服务进行实验性改变并比较结果的测试方法，但他们的应用场景和重点有所不同。 

- AB测试 主要关注产品来自用户调整和交互行为变化的反馈。例如，在UI设计，新功能，个性化推荐等变化的评估中常常使用AB测试。AB测试基于用户行为数据，用于理解不同变体对用户体验、用户行为和关键性能指标的影响。 
- Sticky Canary测试 主要关注基础设施或底层系统改变的影响，它更专注于系统性能、稳定性和资源利用率等技术指标的变化。金丝雀测试的主要作用是在实际生产环境中提前发现潜在的问题和风险



> 测试策略概览

任何的功能上线，测试的策略 主要有2个考虑点:

- 功能性 or 非功能性
- `Idempotency`: 是否幂等


举个例子:
- 如果测试一些 功能上的迁移需求，例如数据的准确性, 同时这个是幂等的请求，那么我们可以相信 **Reply Testing**, 我们相同的 request 一定是相同的 results
- 相反, 如果是非幂等的测试，我们则不能 使用 replay
- 同样，如果是 非功能性的测试，例如 缓存系统，日志系统，我们则是需要上面一样的复杂方案, **AB Testing** + **Sticky Canaries**


下图来自于官方:


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202182721.png?imageSlim)





> AB-Testing 策略


`Netflix` 通常就是 `AB` 测试来 评估新的产品功能是否符合用户的需求.  有完整的生态和基础设施.

第一阶段, 假设用户隔离 为2组, 每组 `100W`, 对某一个用户，他的流量一定是用老的 `Factor` 或者 `GraphQL`, 然后进行对比测试.

测试的指标包含 错误率，延迟，渲染时间等等.


- **Wins**: 如果 测试阶段证明实验组 `OK`, 则上线，`Netflix` 6个月的 `AB` 测试，成功的把移动端的流量全部迁移到了 `GraphQL`
- **Gotchas**: 我们仅仅可以看到 潜在问题的粗粒度的 metrics，要深究这些具体的问题是非常困难的



测试的结果证明 `GraphQL` 并不能帮助 指标上取胜，而这些其实是 陷阱，经过几个月的时间定位到了问题是 客户端的代码问题，例如 `TTL` 缓存问题, `falwed assumptions` 错误假设 等等.




> Replay-Testing - Validation At Scale 工具详解

**这一阶段的测试目的 包含了非功能性的测试 和可幂等的正确的问题**.

- 选择一批 幂等的请求
- 进行流量的 **重放, 放大** 

一些开源工具，例如 `go-replay` ,`tcpdump` 等等都可以放大流量，更好的暴漏性能问题. `Netflix` 是自研的.


> How does Replay Testing worked.


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202184009.png?imageSlim)

- 第一阶段的 `Shim Service` 已经改造为 `GraphQL`
- 第二阶段 通过 `override` 的指令 ，代表 把这个局部字段的 解析路由到新的 服务.


重放阶段的流量采集使用 了 netflix 的自研工具 [mantis](https://netflix.github.io/mantis/)

- 把相同的  event 给到 新旧服务，然后自动化的对结果对比就可以发现问题.


架构图如下:

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240202184234.png?imageSlim)


例如2个接口发现了问题.

```
/data/videos/0/tags/3/id: (81496962, null)

/data/videos/0/tags/5/displayName: (Série, value: “S\303\251rie”)
```


- 实验环境中少了 id 字段
- 编码上不同

同样暴漏的问题:

- 日期精度问题
- 浮点精度差异
- ...



这些问题的暴漏给了 技术迁移侧的信心.




**方案优点**:

- **Confidence**: 基本保证了功能上的对等**
- **Enabled tuning** **configs**: 在数据因为超时而丢失部分字段的时候，可以调整配置 
- **Tested** **business logic**: 可以测试未知输入，正确性难以判断的逻辑, 能暴漏一些非常坑爹的问题


**方案注意点**

- 敏感信息不能重放
- 非幂等不能重放
- 人工构建的查询 只能测试 开发人员 关注的特性，有一些点难以预料
- 正确性的东西容易 混乱：例如 数组是 `null` or `emptyArray` 更合理,  还是说字段不存在作为 噪音?


尽管有各种问题，这个阶段的测试能保证我们解决了 大多数的问题




> Sticky Canary 工具详解


- Waiting


