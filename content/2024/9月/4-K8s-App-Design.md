
## 1-Intro


**1) 基础设施**

- 存储方案: `StorageClass` .
	- 隔离. 
	- 应用一般是日志，顺序 `io`, 可能机械磁盘就 `ok` 了. 

**2) 日志收集方案**


**3) 存储体系**

- 本地存储
- 高速分布式存储: `minio` or `ceph` ..
- 共享的 `nfs` 

**4) 网络体系**

**5) 监控体系**

- `promehuts`
- `ebpf`

**6) 网关**

**7) 应用demo**

- `gateway`: `rust` +  `pingora`
- 用户系统: `golang`
- 业务1 电商 - `vshop` : `kotlin`  (隔离的资源)
- 业务2 ..
- 业务3 前段: `js` + `vue3`


## 2-roadmap

### 2-1 v1

- [x] 基础的 k8s 环境: [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Farm64%2Fstable%2Fhomebrew#Ingress) ✅ 2024-09-11


v1: k8s 内部 dns 的服务发现测试
1. 创建2个服务
2. 能够打通
3. cb-devops-prov
4. cd-devops-cons
5. 引入 `grpc` 和 `armeria`
6. 支持 `loki` 的日志收集




