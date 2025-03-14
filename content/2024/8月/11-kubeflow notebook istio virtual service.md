

## 1-Intro

> **1) 什么是 Istio**

`Istio` 是 `servicemesh` 的典型作品.  他会代理 `SERVICE` 之间通信的所有流量. 因此通信和流控相关的事情都可以做掉, 例如 `TLS` 的安全通信, 自动的负载均衡, 细粒度的流量控制 等等 .


> **2) 控制平面和数据平面**


`Data plane` 和 `Control plane` 是 `servicemesh` 模式中的典型概念. 


控制平面:

- 控制平面负责 处理整个 `serviceMesh` 体系中的管理和配置任务 ; 用机场作为例子，他就是中控塔, 飞机什么时候起飞，降落，安全的在跑道间移动都由他控制 
- 数据平面: 由一组智能代理 `Envovy` 组成, 这些代理会被部署为 `sidecars`, 和应用程序的容器一起运行 ; 他类似 机场的飞机本身，数据也就是乘客，机场就是 `service` , 把一个乘客(数据) 安全的从一个 机场运输到另一个 机场, 就是他的任务. 



## 2-Consideration


来自 [Why choose istio](https://istio.io/latest/docs/overview/why-choose-istio/) , 讨论了一些决策点. 


**1) Why not "use ebpf"**

这里代表 istio 官方观点，cilum 中就对 ebpf 使用的更加彻底。

1) `eBPF` 的优点
	1. 性能: 运行在内核空间, 可以不用在用户空间就 直接处理数据包, **所以非常快**
	2. 灵活: 组件可以动态的 加载和卸载，不用重启系统或者更改内核代码, **所以非常灵活**
	3. 安全: 所有的组件 都需要经过严格的 验证器, 确保不会崩溃或者无限循环等等, **所以非常安全**
2)  `eBPF` 的局限性
	1. 不能处理复杂任务: 一般用来做确定的，简单的任务, 例如网络包的过滤，性能的监控 等等
	2. 编程模型的限制



`istio` 认为 `ebpf` 技术还不能完全的代替 `envovy` 的方案，所以目前会结合二者使用 .


