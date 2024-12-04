
## 1. Intro

> 我们下面的所有概念以 `OTel` 的概念定位为准

> 系统的可观测性 往往包含了三个组件

- [logs](https://opentelemetry.io/docs/concepts/signals/logs/): 一个 有 `timestamp` 的信息流. `OTel` 的想法使用用 `traceId` , `spanId` 这些上下文去关联其中的部分日志, 就能把日志串联起来提供 `Trace` 的能力 ;
	- 广义的日志: 有 `timestamp` 的信息流
	- `OTel` 中狭义的日志:
- [metrics](https://opentelemetry.io/docs/concepts/signals/metrics/): 度量功能, 用来提供页面报表, 比如  [prometheus](https://prometheus.io/) 和 [micrometer](https://github.com/micrometer-metrics/micrometer)
- [traces](https://opentelemetry.io/docs/concepts/signals/traces/): 链路追踪，最开始来自 google 的 [Dapper论文](https://research.google/pubs/pub36356/)

> What is Open Telemetry?

- 同时搞定3个东西, `traces`, `metrics`, `logs` ;
- 是一个工具库，支持各种各样的 `Backend`, 例如 `Jager`, `Prometheus` ，这里统称为 [Vectors](https://opentelemetry.io/ecosystem/vendors/);

> 

> 既然不是一个产品，是一个工具，有哪些工具呢?

- [Java 的打桩库支持非常全面](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/supported-libraries.md#libraries--frameworks)
- [拥有健全而空铺的生态](https://opentelemetry.io/ecosystem/)

>

## Refer

- [Open-Telemetry](https://opentelemetry.io/docs/what-is-opentelemetry/)
- [signoz](https://signoz.io/docs/userguide/write-a-metrics-clickhouse-query/)
- [CheckEnv](https://www.uber.com/en-HK/blog/checkenv/?uclick_id=5f2ff7ef-d1a2-4d1b-821e-141457f13d40) : uber 使用 `CHeckEnv` 来分析跨环境的 `RPC` 调用


