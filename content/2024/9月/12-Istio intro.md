

## refer

- [Istio Intro](https://istio.io/latest/zh/docs/overview/what-is-istio/)



## 1-Quick Start


**1)-什么是 Istio**

`Istio` 是一种开源的服务网格. 

- 双向的 `TLS`
- `HTTP`、`gRPC`、`WebSocket` 和 `TCP` 流量的自动负载均衡
- 使用丰富的路由规则、重试、故障转移和故障注入对流量行为进行细粒度控制
- 集群内所有流量（包括集群入口和出口）的自动指标、日志和链路追踪



> [!NOTE] Tips
> Sidecar vs Sidecar-less 的 service-Mesh 模式依旧是 比较有争议的地方, `Istio` 目前同时支持2种模式， 这里先用 `Sidecar` 模式来熟悉 `Istio` 的功能集


**2)-Sidecar 架构**


![](https://istio.io/latest/zh/docs/ops/deployment/architecture/arch.svg)



- 数据平面: [Envovy](https://www.envoyproxy.io/) 实现的 `sidecar` 组成, 他们会负责 所有 服务之间的通信, 网络层面上的逻辑功能基本都能支持
- 控制平面: 管理并配置 代理来进行路由

**`Envovy` 能干什么?** 

- 动态的服务发现
- 负载均衡
- `TLS` 终止
- `HTTP2` 和 `GRPC` 的代理
- 熔断器
- 健康探测
- 基于百分比流量分割的 分阶段发布
- 故障的注入
- 监控指标
- ...

## 2-Concepts

### 2-1 Traffic Management

**1)-流量管理是什么**

基于 `Service discovery`, 把流量 根据 **规则** 定向到相关服务的能力. 

- 规则是 目标规则: `Detination Rule`
- 服务是 虚拟服务: `Virtual Service`

**2)-虚拟服务是什么**

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v3

```


从 `demo` 上看， 一个虚拟服务有如下的内容:

- `hosts` : 可以是 `ip` 地址， 可以是 `DNS` 名称,  ....
- `http`
	- `match`
		- `headers`
	- `route`: 必须有符合流量的实际目标地址
- `route`


所以我们总结一下上面的 虚拟服务是什么?

虚拟服务主机名是 `reviews` 的 `http` 流量, 如果满足了 `headers` 中包含字段 `end-user`, 而且值等于 `jason` 的条件, 那么这个 `http` 流量会路由到 `v2` 这个 `subset`, 否则会路由到 `v3` 这个 `subset`, 这样 **就通过 一个 http-header 实现了染色功能** .  初看下来有点类似 `nginx`的 `virtualHost` .

**3)-路由规则**

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
    - bookinfo.com
  http:
  - match:
    - uri:
        prefix: /reviews
    route:
    - destination:
        host: reviews
  - match:
    - uri:
        prefix: /ratings
    route:
    - destination:
        host: ratings

```

核心 `match` ,更多的包含在 [HTTPMatchRequest](https://istio.io/latest/zh/docs/reference/config/networking/virtual-service/#HTTPMatchRequest) 这个结构体中

**4)-目标规则**

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: my-destination-rule
spec:
  host: my-svc
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
  - name: v3
    labels:
      version: v3
```


- 每个 `subset` 都是基于 一个或者多个 `labels` 定义的, 在 `k8s` 上是附加到 `Pod` 这种对象的键/值对, 这些标签应用于 `k8s` 服务的 `Deployment` 并作为 `metadata` 来识别不同的版本 ;



### 2-2 Gateway

网关主要用来管理 流入和流出的流量. , 出口网关可以为离开 网格的流量配置一个专门的出口节点, **限制哪些服务可以或者应该访问外部网络** . 

**这是一个 HTTPS 的入口流量的网关配置:**

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: ext-host-gwy
spec:
  selector:
    app: my-gateway-controller
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - ext-host.example.com
    tls:
      mode: SIMPLE
      credentialName: ext-host-cert
```

...

## 3-Examples


```sh
curl -L http://istio.io/downloadIstio | sh -
```


## 4-