## Refer

- [Kubenetes Cluster Architecture](https://kubernetes.io/docs/concepts/architecture/)


![](https://kubernetes.io/images/docs/kubernetes-cluster-architecture.svg)


## Communication Between Nodes and the Control Plane


> 有如下的特点:

1. 集中式的通信:  所有的通信都通过 `API-Server`
2. 多种机制混合: `Https`, 客户端认证，授权机制一并上
3. 自动化的安全配置: 例如 `kubelet TLS` 引导和 `Pod` 的 `Service Account` 会自动的注入


> **Hub-and-spoke** 的设计

- `Hub`（轮毂）是中心点: 所有的通信都围绕这个 中心点
- `Spokes` （辐条: 则是 连接到中心的各个端点


这种是一种典型的设计模式, **集中式通信** , `Hub` 就是 这个 `kube-api-server`. 

而 `Spokes` 则是图中的 `scheduler`, `Controller Manager`, `kubelet`, `kubeproxy` 等等组件, 核心就是各个组件之间的 通信都不是直接的，都是通过 这个中心化的 `Api-server` 转发的. 


### Control plane to Node

从控制平面到 `Node` 的通信 , 从功能上上 有2种 通信路径

1. 内部系统: API 服务器 -> kubelet -> Pod/节点资源
2. 外部请求: 外部请求 -> API 服务器 -> 内部路由 -> kubelet -> Pod/节点资源


> **Api Server to Kubelet**

1. 这条连接 链路被用在多种功能上， 例如: `Pod` 的日志, `Attach` 到正在运行的 `Pod`, 端口转发等等 ;
2. 这条连接 链路 在 `API-Server` 这一侧默认没有做 `Server` 侧的 `tls` 校验，可以开启，不开的原因可能是 **不想要无所谓的性能损失, 毕竟一般这条链路是内网?**
3. 

...


> ......


## Controllers Design Pattern

官网文档中用 空调来说明 这种设计模式, 假设空调期待的温度是 20度, 他会就会去启动一个循环，不断地去对比当前的温度和 20度，高了就降低，低了就升高, 这个循环对比调整的设计模式 就是 `Controller` 的设计核心. 这种工作机制可以抽象为:

- 控制循环: 持续监控集群的状态
- 状态对比: 对比当前的 状态和期望的 状态
- 调整行为: 如果发现了差异, 控制器都会采取行动来调整当前的状态, 让他接近期望的状态


而. `k8s` 则是 通过资源的类型来区分 多种不同的 `Controller`.  下面简要的描述一下，上面介绍过了 `Node Controller`. 

• `Deployment`  控制器：管理应用的部署和更新。
• `ReplicaSet` 控制器：确保指定数量的 Pod 副本在运行。
• `StatefulSet` 控制器：管理有状态应用。
• `Job` 控制器：管理批处理任务。
• `CronJob` 控制器：管理定时任务。
• `Node` 控制器：监控节点的健康状态。
• `Service` 控制器：管理服务和负载均衡


## Leases


`K8s` 用 `lease` 机制协同分布式系统中的一致性问题, 例如 节点健康检查 , leader election, `API` 服务器的身份管理.

> **Node heartbeats**

- 每个 `Node` 在 `kube-node-release` 命名空间，有一个对应的 `Lease` 对象 
- `kubelet` 通过更新 `Lease` 对象的 `spec.renewTime` 字段来发送心跳
- 控制平面用这个字段来判断节点的可用性


> **Leader election**

- 用来确保高可用 (`HA`) 配置中只有一个组件来运行
- `kube-scheduler` 和 `kube-controller-manager`

> **Api 服务器身份**

- 从 `v1.26` 开始, 



```sh
kubectl -n kube-system get lease apiserver-07a5ea9b9b072c4a5f3d1c3702 -o yaml
```


```yaml
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  creationTimestamp: "2023-07-02T13:16:48Z"
  labels:
    apiserver.kubernetes.io/identity: kube-apiserver
    kubernetes.io/hostname: master-1
  name: apiserver-07a5ea9b9b072c4a5f3d1c3702
  namespace: kube-system
  resourceVersion: "334899"
  uid: 90870ab5-1ba9-4523-b215-e4d4e662acb1
spec:
  holderIdentity: apiserver-07a5ea9b9b072c4a5f3d1c3702_0c8914f7-0f35-440e-8676-7844977d3a05
  leaseDurationSeconds: 3600
  renewTime: "2023-07-04T21:58:48.065888Z"
```


- `holderIdentity`:
- `leaseDurationSeconds`: `3600s` 
- `renewTime`: 最后一次更新 `Lease` 的有效期


## Cloud controller Manager


![](https://kubernetes.io/images/docs/components-of-kubernetes.svg)


`CCM` 中有三个主要的 `Controller`


- Node Controller: updating Node objects when new servers are created in your cloud infrastructure
- Route controller: 配置 云上的路由，负责节点上的 容器可以通信
- Service controller: [Services](https://kubernetes.io/docs/concepts/services-networking/service/) integrate with cloud infrastructure components such as managed load balancers, IP addresses, network packet filtering, and target health checking.


## cgroup v2

> What

1. `cgroups` 是 `k8s` 中资源管理和隔离的核心机制
2. `v2` 版本提供了明显的改进, 特别是在资源管理和 隔离方面, `k8s` 能从中获取到 更好的性能和更强的安全
3. `k8s` 正在迁移的过程中


> How


`kubelet` 会自动检查当前的操作系统是否支持 `cgroupv2` , 而且不用任何配置.

有一些组件需要更新:

1. 一些 三方的监控和安全代理
2. `bAdvisor`: 如果作为独立的  `DaemonSet` 运行，需要更新到 `v0.43.0` 以上的版本
3. `Java` 应用: 推荐完全支持 `cgroup v2` 的版本:
	- [OpenJDK / HotSpot](https://bugs.openjdk.org/browse/JDK-8230305): jdk8u372, 11.0.16, 15 and later
	- [IBM Semeru Runtimes](https://www.ibm.com/support/pages/apar/IJ46681): 8.0.382.0, 11.0.20.0, 17.0.8.0, and later
	- [IBM Java](https://www.ibm.com/support/pages/apar/IJ46681): 8.0.8.6 and later
   

> Linux 检查


```sh
stat -fc %T /sys/fs/cgroup/
```

- 如果是 `v2` 是 `cgroup2fs`
- 如果是 `v1` 是 `tmpfs`






