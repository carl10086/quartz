


## 1-Tcp Intro
> 原文


- [酷壳-TCP 的那些事](https://coolshell.cn/articles/11564.html)


> sk_buff


全称是 `socket buffer`, 是一个元数据结构，其中的指针字段指向了 各层协议中的头部数据和 payload, 例如:

1. `sk_buff.data` 指向了数据包的有效载荷
2. `sk_buffer.network_header` 指向了 网络层的头部，其中包含了 `IP`
3. `sk_buffer.transport_header` 指向了传输协议层的头部, 例如 `TCP` 的源端口和目标端口


> tcp 头格式

![](https://nmap.org/book/images/hdr/MJB-IP-Header-800x576.png)


- tcp 中包含了4元组 来代表一个连接, `(src_ip, src_port, dst_ip, dst_port）`, 准确的描述是 5元，其中一个是 协议(`tcp` or `udp`)
- 上图中的核心字段:
	- **Sequence Number**是包的序号，解决 **乱序**
	- **Acknowledgement Number**就是ACK——用于确认收到，解决 **丢包**
	- **Window又叫Advertised-Window**，也就是著名的滑动窗口（Sliding Window）, 用来解决 **流控**
	- **TCP Flag** ，也就是包的类型，**主要是用于操控TCP的状态机**



具体的含义见下图.

![](https://nmap.org/book/images/hdr/MJB-TCP-Header-800x564.png)



> tcp 状态机.

![](https://coolshell.cn/wp-content/uploads/2014/05/tcp_open_close.jpg)


- 3次握手为了双方确认对方的初始序号, `ISN`, 后面使用偏移量就能 唯一代表一个包的序号, 它是连续的，所以可以解决乱序的问题
- 4次挥手是全双工，`shutdown` 关一方, `close` 才是关2方. 用 `close` 为例子. . 


> 建立连接的时候 `SYN` 可能会超时

`server` 侧在三次握手的时候收到了 `SYN`, 返回一个 `SYN-ACK`, 这个时候, `client` 卡了, `server` 收不到这个 `ACK`. 

这个时候会重试, 重试的策略是 `1s->2s->4s->8s->16s->32s`, 连续5次超时也就是 `63s` 会断掉这个连接

> 基于上面的策略 有一个攻击叫做 `SYN-Flood` .

上面的情况 会让 `server` 侧占据资源 `63s`, 攻击者通过 连续的这种攻击, 耗尽了 `syn` 的队列. 为了解决这个问题，引入了 `tcp_syncookies` . 

我们理解这个问题, 本质原因是:

- 这个 半连接可以给服务端压力，本质上因为服务端有重试机制.
- 造成的结果是 服务端的资源被消耗在了 攻击请求上，队列中没有资源给正常的请求了.


`tcp_syncookies` 机制 是缓解结果，治标不治本.

- 如果 半连接队列已经满了, `tcp` 会通过类似 `cookie` 的机制生成一个 特别的东西用来做临时鉴权, 算法来自于 *原地址端口* **目标地址端口** *时间戳* 3个参数.

纠正一个关于 `tcp_syncookies` 的误解, 如果我们都是正常的请求，但是压力太大，不能使用这个参数来缓解. 我们应该关闭, 比如内网中 发现半连接压力太大. 不要期待这个参数能解决压力问题，这个参数可能 *进一步扩大问题*.

`Linux` 提供了其他的机制用来抗正常的压力:

1. `tcp_synack_retries` : 减少重试的次数
2. `tcp_max_syn_backlog` : 允许更大的 半连接队列
3. `tcp_abort_on_overflow` : 快速失败机制，半连接队列满了直接拒绝


> ISN 的初始化机制

- 对每个 tcp 连接由于 有重连机制，所以不能 `hard code`, `ISN` 和会一个假的时钟绑在一起，每4微妙+1, 直接 `Int.MAX`, 然后循环重来.

**核心问题是为了 唯一而且有序**, 防止重复的数据包 被误解为 当前的数据包.


> `MSL` 和 `TIME_WAIT`


1. 谁先关闭，谁 `TIME_WAIT`
2. 从 `TIME_WAIT`  到 `CLOSED` 的间隔是 `2 x MSL` . (规范中是 2分钟， `Linux` 是 30s)

为什么要 `TIME_WAIT`, 详细内容可以学习 [TIME_WAIT and its design implications for protocols and scalable client server systems](http://www.serverframework.com/asynchronousevents/2011/01/time-wait-and-its-design-implications-for-protocols-and-scalable-servers.html)

1. `TIME_WAIT` 是为了给对端一个最后的 `ACK` , 确保对端能关，其实到这里 `SERVER` 已经可以结束了. 但是对端 **如果没有收到这个最后的 ACK**, 会重试发送 `FIN`
2. 为了防止 这个连接的包和后面的连接混合在一起, 这是个很坑爹的问题， **有些不和规范的路由器会缓存 IP 层的数据包**, 如果连接被重用了，那么延迟包会混在一起, **如果这个时候 TCP 4元组申请的临时端口刚好一样**


> TIME_WAIT 数目太多的问题


如果 **高并发** **大量短连接** , 容易出现大量的 `TIME_WAIT`. 


> [!NOTE] Tips
> 网上有大量的参数是 说 tcp_tw_use 和 tcp_tw_cycle, 这个是错误的,  容易出现一些 NAT 环境例如 nginx 跟客户端 奇怪断掉的问题


下面是关于这三个参数的解释:

- **关于tcp_tw_reuse**。官方文档上说tcp_tw_reuse 加上tcp_timestamps（又叫PAWS, for Protection Against Wrapped Sequence Numbers）可以保证协议的角度上的安全，但是你需要tcp_timestamps在两边都被打开（你可以读一下[tcp_twsk_unique](http://lxr.free-electrons.com/ident?i=tcp_twsk_unique)的源码 ）。我个人估计还是有一些场景会有问题。

- **关于tcp_tw_recycle**。如果是tcp_tw_recycle被打开了话，会假设对端开启了tcp_timestamps，然后会去比较时间戳，如果时间戳变大了，就可以重用。但是，如果对端是一个NAT网络的话（如：一个公司只用一个IP出公网）或是对端的IP被另一台重用了，这个事就复杂了。建链接的SYN可能就被直接丢掉了（你可能会看到connection time out的错误）（如果你想观摩一下Linux的内核代码，请参看源码 [tcp_timewait_state_process](http://lxr.free-electrons.com/ident?i=tcp_timewait_state_process)）。

- **关于tcp_max_tw_buckets**。这个是控制并发的TIME_WAIT的数量，默认值是180000，如果超限，那么，系统会把多的给destory掉，然后在日志里打一个警告（如：time wait bucket table overflow），官网文档说这个参数是用来对抗DDoS攻击的。也说的默认值180000并不小。这个还是需要根据实际情况考虑





## 2-Congestion Control


> RTT-Round Trip time

我们按照如下的思路整理:

1. `TCP` 发送每个包，需要有个 `timeout` 控制, 如何在动态的环境中设置这个值 `RTO` 呢 ;
2. 需要知道 对端大概有多远，因此引入了 *RTT: 每个包从发送到接收的时间* ;



基于这个 `RTT` 设置 `RTO` 的算法有:

1. 经典算法: 采样然后使用 加权平均
2. `Karn/Partridge`: *使用 第一次发数据的时间和ack 回来的时间做样本, 还是用重传的?*, 这个算法会忽略重传的采样 ;
3. `Jacobson/Karels`: 不使用加权算平均，而是使用 *算法引入了最新的RTT的采样和平滑过的SRTT的差距做因子来计算*

> 滑动窗口用来做流控


- `TCP` 不仅仅能针对 单个连接层面做流控, 还能对动态的反馈到  整体的网络环境, 这就是 *拥塞控制的核心意义*

我们简单的推理一下:

1. 我们先假设没有这个东西，在网络卡的时 是不是只能简单的重传，重传这个时候 *只会增加压力* ;
2. `TCP` 能做的更多，他知道自己卡了，可以 *自我牺牲*, 就像高速公路的拥塞一样，每个车都应该去降低速率而不应该是去抢速度 ;
3. [原始论文](http://ee.lbl.gov/papers/congavoid.pdf)


核心有4个算法机制:

1. 慢启动
2. 拥塞避免
3. 拥塞发生
4. 快速恢复

> 快速启动


慢启动的算法如下(cwnd全称Congestion Window)：

1）连接建好的开始先初始化cwnd = 1，表明可以传一个MSS大小的数据。

2）每当收到一个ACK，cwnd++; 呈线性上升

3）每当过了一个RTT，cwnd = cwnd*2; 呈指数让升

所以，我们可以看到，如果网速很快的话，ACK也会返回得快，RTT也会短，那么，这个慢启动就一点也不慢



> 拥塞避免

一个ssthresh（slow start threshold），是一个上限，当cwnd >= ssthresh时，就会进入“拥塞避免算法”（后面会说这个算法）.

*达到这个阈值的时候就 线性上升*.

1）收到一个ACK时，cwnd = cwnd + 1/cwnd

2）当每过一个RTT时，cwnd = cwnd + 1


> 当丢包的时候, 会有2种情况

1. 第一种情况是超时, 算法认为这个时候非常的严重, 基本包就完全发不出去了
	- `sshthresh` =  `cwnd` /2, *上限砍为一半*
	- `cwnd = 1`, *直接从1开始，不要发任何包来增加网络压力了*
	- *从1开始，同时也意味着进入了慢启动的状态*

2. 3个 duplicate ack, 认为这个时候有点卡，还能发出去，只是收到了相同的包
	- `cwnd = cwnd /2` , *之前的速度是按照指数上来的，就按照指数下去*
	- `sshthresh = cwnd`
	- *进入快速恢复算法* , 没有那么严重，可以快速恢复


> 快速恢复算法


- `cwnd = sshthresh  + 3 * MSS （3的意思是确认有3个数据包被收到了）`, *这里 sshthresh 已经更新过了*, 基于这个 新值 *斗胆+3个MSS* 
- 这个时候看一下，如果还收到了相同的 `ACK`, 就 `cwnd = cwnd + 1`
- 如果是新的，证明流畅的, `cwnd = sshthresh`, 直接进入到拥塞避免的阶段了，*所以快速恢复到拥塞避免的阶段*



## Refer

- [tcpip-ref](https://nmap.org/book/tcpip-ref.html)

