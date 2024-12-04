
## 1-Intro

> 一个调度任务的 `Model`


- `taskId`: 唯一的任务 `Id`
- `userInfo`: `Id`, `role` 等等
- `taskType`: 任务类型，例如 `t2i`, `i2i`, 超分, `tts` 等等
- `pipeline`: 一个任务可以有多种策略，这个 `pipeline` 定义出了具体的算法实现和  输入输出

> 思路

- 基本的思路借鉴, `Yarn`, `K8s-Scheduler`, 和 `Mesos`, 也就是 `Scheduler` + `Agent`

- `Scheduler` 是一个无状态的 `Proxy`, 负责接收 `Client` 请求,很容易做负载均衡，支持 `MultipleDc-Model` 也就是异地多活
- `Meta`: 用来管理 `Agent` 元数据的组件
- `Agent` 会注册到当前的 元信息到 `Meta` 中, 包括如下的信息:
	- `healthInfo`: 是否健康
	- 支持哪些 `Task`, `Pipeline`
	- 支持哪些 `Model`


基本的流程, 一个数据中心的某个 `Scheduler` 接收一个 `Task`，按照配置的策略，优先给相对空闲的 `agent` , 当前数据中心的 `agent`, 没有的时候根据拓扑配置考虑是否支持异地的数据中心

## 2-Meta Storage Design


`K8s` 使用 `Etcd`, 是 `Raft` 协议
`Yarn` 和 `Mesos` 一般使用 `Zk`, 是 `ZAB` 协议

他们的特点 是强一致性，偏向 `CP` .

当前系统一个偏 `C` 侧的系统，需要比较好的扩展性和吞吐量. 偏向 `PA`.

可能一些传统的选型更合适, 例如:

- `Mysql`
- `MongoDb`
- `Redis`
- `ScyllaDB`

在当前的场景中都要实现 异地多活，也就是 `MultipleDataCenter`, 这个难度系数相对比较高，所以我们选择一个最容易实现的, `ScyllaDB` , 参考 [ScyllaDB Multiple Data Center](https://opensource.docs.scylladb.com/stable/operating-scylla/procedures/cluster-management/create-cluster-multidc.html)

- 为什么异地多活的设计这里如此重要? 受制于某些非主观因素，`GPU` 机器不仅仅成本昂贵，强如某些云厂商的资源也要提前申请，甚至是没有.


## 3-Agent Design

> Agent 的核心是 任务的实现，本身信息的注册比较简单.

有如下的 **关键点**:

- 调度的粒度可以是 `GPU` 设备, 也可以是单台机器. 不同 `Agent` 的处理能力一定是有很大差别的，比如说 `A100` 就是比 `A40` 强, 所以要有 **权重**, **这里的复杂点是可能 对不同任务的能力不同，建议简化，不考虑这么细**
- 这里的 调度模型偏向 `Pull`, 功能上比较强大, 比如说很容易实现 `Multiple Weighted Queue`. 例如:
	- 有2个队列:
		- `Vip Queue`: 权重 8 
		- `Normal QUeue`: 权重 2
	- 实现的时候一次轮询10个，优先从 `Vip` 取最多8个, 然后再从 `Normal` 中取最多 2个
- 健康探测，可以定时 更新 `Meta` 的信息.
		- `UPDATE t_health_check SET last_heart_beat_at = NOW() where agent_id = ?`
- 要统计任务的计数, 一个 `counter`, `scheduler` 基于 当前 `agent_id` 等待队列的数量进行选择



## 4-Scheduler Design

> 这里的实现偏向 `Push` 的模式.

一个伪代码:

```python

def push_task_2_dc(task: TaskInfo, dc_id: str, strategy: ScheduleStragety ) {
	# 1. 找到 健康的, 支持 pipeline 的，有这些 model 的 agents
	agents = find_available_agents(task.models, task.pipeline)
	# 2. 查找对应的 stats
	agent_stats = find_stats(agents)
	# 3. 算法是可以 weighted_robin, robin, hash, ...
	top1(agent_stats, strategy)
}
```


上面的问题:

- 一致性比较弱，等于没有做. 会造成任务的不均匀，也就是 算力之间平衡的不是很好, 单纯的从调度的角度来看, 是比较普通的

> 一致性 vs 性能


- 方案1: 同步 + 分布式锁. 强行串行化, 
- 方案2: 同步 + `SingleMaster`, 缺点是只有1个，也就是 `MasterProxy` 在跑, 其他的都是 备，没有充分利用性能, **因为其他的都要转发给 `Master` **
- 方案3: 异步 + `SingleMaster`, 参考 `Tcp` 的半连接队列和全连接队列
	- 每个 `Proxy` 收到请求，放到半连接队列中, `wait_list`
	- 主从选举出来的 `Master` 轮询这个半连接队列, 调用 `push_task_2_dc` 的办法



> [!NOTE] Tips
> 可以看出来，如果要做 一致性，方案3 是综合了 性能和一致性的选择，那么问题是 分布式锁了



> 分布式锁

- 如果 `Meta` 是 `Zk`, `Etcd`, 甚至是 `Redis`, 都可以直接用, 是非常通用的功能. 下面都是 生产级的库:
	- `Zk` 的 `Aapche Curator Recipe`
	- `Redis` 的 `Reddison`



> [!NOTE] Tips
> 分布式锁和主从选举的作用范围最好局限在一个 `Dc` 独立一个，否则性能很吃力，还容易脑裂


如果是 `ScyllaDB` 要实现主从选择.  参考上面的原理实现也不难, 核心就下面2点:

- `Zk` 是 `createZNodeIfNotExisted` , `redis` 是 `setEx` 这样去做的 ;
- 要有 `Watch` 机制, `Zk` 是自动的, `redis` 可以搞个定时任务去不断尝试 `setEx`, 成功了就抢到了 ;
