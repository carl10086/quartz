
## 1-intro

`cf` 基于 `rust` 开发用于 取代 `nginx` 的工具, 以库的方式提供.


**1)-What is pingora**

`Cloudflare` 一个使用 `RUST` 构建的 `HTTP` 代理. 每天处理超过万亿级别的请求, 落地从能力上已经超越了 `Pingora` . `Cloudflare` 基于 `Pingora` 构建他们出众的全球网络能力: `CDN`, `Workers fetch` , `Tunnel`, `R2` ....


**2)-Pingora in production**

在 `Cf` 的实践中:

1. `TTFB` 的中位数减少了 `5ms` , `p95` 减少了 `80ms` ,  并不是因为代码更快, 而是来自于新架构，`CF` 基于 `NGINX` 本身的代理代码就非常的快 ;
2. 复用能力提升, 每 `Second` 新创建的连接数目直接减少到了 `1/3`, 连接的 重用率直接提升到了 `99.92%` !
3. 同样的流量负载下, `PINGORA` 比 `NGINX` 相比, `CPU` 减少 70%, 内存减少 67%
4. 共享数据更加的高效,  `NGINX` 的共享内存由于跨进程需要使用互斥锁, 而 `Pingora` 则是通过 `Atomic` 的计数器 ...




## 2-Nginx Maybe have some problems

**1)-Nginx 的架构**

```
主进程 (Master Process)
    ├── Worker Process 1
    ├── Worker Process 2
    ├── Worker Process 3
    └── Worker Process n
```

- NGINX 采用多进程模型，通常会启动与 CPU 核心数量相等的 worker 进程
- 一旦请求被分配给特定 worker，整个请求的生命周期都将在该 worker 中完成
- worker 进程之间是相互独立的，不共享资源

这种模型的问题 是 负载均衡是按照请求的维度，这个在 实践中发现会导致 某些 `worker` 很忙, 某些 `worker` 很闲的状态, `Nginx` 大多数的负载均衡算法考虑的维度是 连接 和静态分配， 客观的说绝大多数场景是 `OK` 的, 进程的设计模式导致 `Worker` 之间无法很好的共享资源， 很难轻易的把一个请求 转移到另一个.

`cloudfare` 需要更加细粒度的控制能力, 比如实时负载感知机制 和 动态的资源调度 等等.

比如说:

- [The problem with thread^W event loops](https://blog.cloudflare.com/the-problem-with-event-loops/) : `CPU` 角度的问题
- [How we scaled nginx and saved the world 54 years every day](https://blog.cloudflare.com/how-we-scaled-nginx-and-saved-the-world-54-years-every-day/) : `IO` 角度的问题


**2)-Nginx 连接的重用**

`Cf` 的入口，必然要和 企业客户的 `REAL-SERVER` 保持连接.

但是 `Nginx` 的连接池模型也是 `worker` 维度的.

```
NGINX Master
├── Worker1 
│   └── Connection Pool 1
├── Worker2
│   └── Connection Pool 2
├── Worker3
│   └── Connection Pool 3
└── Worker4
    └── Connection Pool 4
```

```
客户端请求 → NGINX Worker → 目标服务器
                    ↓
             检查连接池是否有可用连接
                    ↓
        有 → 复用连接   没有 → 建立新连接
                            │
                            └→ TCP握手
                               TLS握手（如果需要）
```


连接池这个东西应该是按照 `REAL-SERVER` 的级别来设计的，但是由于 `WORKER` 之间的隔离. 导致.

`Worker1` 的连接池之间已经建立好了，有 5个空闲连接， 但是由于请求被分配到了 `Worker2`, 需要重新建立连接.

也就是 `NGINX` 虽然是可以通过 增加 `Worker`的核心数量来 垂直提升处理能力，但是没有做到线性提升， 属于 **扩展悖论!** 


```
初始状态（2个worker）：
- Worker1：50个连接，使用率80%
- Worker2：50个连接，使用率80%
总计：100个连接，较好的复用率

扩展后（4个worker）：
- Worker1：25个连接，使用率40%
- Worker2：25个连接，使用率40%
- Worker3：25个连接，使用率40%
- Worker4：25个连接，使用率40%
总计：100个连接，但复用率降低
```


**3)-其他问题**

- 功能上的限制: 重试请求或者请求失败的时候, 需要把请求发送到具有不同的 `HEADER` 的 `RS` , 这个用 `NGINX` 比较麻烦
- 语言问题: `Nginx` 是纯 `C`, 扩展起来很麻烦, `Lua` 的性能又比较差, 而且代码和逻辑复杂的时候会发现， `LUA` 又缺少静态类型. 
- `NGINX` 的社区很不活跃



## 3-Cloudfare Pingro Design

`Cf` 的第一个设计决策是完全自研, 这对于他们的规模和重要程度 很好理解.

第二个设计决策是 使用 多线程而不是多进程, 尤其是和 源服务器的连接池，而且还要做 [Work steal](https://en.wikipedia.org/wiki/Work_stealing) 来避免极端情况下的性能问题， 所谓的工作窃取就是主动去 偷窃任务.

```
线程1队列: [Task A, Task B, Task C]
线程2队列: []  // 空闲

工作窃取后：
线程1队列: [Task A, Task B]
线程2队列: [Task C]  // 从线程1窃取任务
```

而 `rust` 生态中的 [tokio](https://github.com/tokio-rs/tokio) 跟上面的需求度是 *非常匹配*

第三个核心的设计决策是要对 开发者友好，之前 网络基础设施或者网关代理 的开发者比较熟悉的都是 `OpenResty`  这样的技术， 他们的设计是 围绕 `Request` 设计生命周期，围绕这些生命周期提供 `Filter` 机制.  其他语言比如 `golang` 的 `Echo` 的 `Plugin`, `java` 中 `SpringMvc` 的 `Inteceptor` 机制都是这样处理的.



## 4-Pingora as proxy example

首先加入 `cargo` 的依赖 .

```toml
[dependencies]  
async-trait="0.1"  
pingora = { version = "0.4.0", features = [ "lb" , "proxy"] }  
env_logger = "0.11.5"  
log = "0.4.22"
```


```rust
use log::info;  
use pingora::http::RequestHeader;  
use pingora::lb::{health_check, LoadBalancer, selection::RoundRobin};  
use pingora::prelude::HttpPeer;  
use pingora::proxy::{http_proxy_service, ProxyHttp, Session};  
use pingora::server::configuration::Opt;  
use pingora::server::Server;  
use std::sync::Arc;  
use std::time::Duration;  
  
pub struct LB(Arc<LoadBalancer<RoundRobin>>);  
  
#[async_trait::async_trait]  
impl ProxyHttp for LB {  
    // 定义上下文的类型， 这里是空元组  
    type CTX = ();  
  
    // 创建新的上下文  
    fn new_ctx(&self) -> Self::CTX {}  
  
    // 选择上游服务器的函数  
    async fn upstream_peer(  
        &self,  
        session: &mut Session,  
        ctx: &mut Self::CTX,  
    ) -> pingora::Result<Box<HttpPeer>> {  
        //  使用轮询的方式选择一个上游服务器  
        let upstream = self.0.select(b"", 256).unwrap();  
  
        // 记录选中的上游服务器信息  
        info!("上游服务器是 : {:?}", upstream);  
  
        // 创建一个新的 HTTP 对等点，设置为 one.one.one.one        let peer = Box::new(HttpPeer::new(upstream, true, "one.one.one.one".to_string()));  
        Ok(peer)  
    }  
  
    // 处理发送到上游的请求  
    async fn upstream_request_filter(  
        &self,  
        _session: &mut Session,  
        _upstream_request: &mut RequestHeader,  
        _ctx: &mut Self::CTX,  
    ) -> pingora::Result<()>  
// where  
    //     Self::CTX: Send + Sync,    {  
        // 设置 Host 头为 one.one.one.one        _upstream_request  
            .insert_header("Host", "one.one.one.one")  
            .unwrap();  
        Ok(())  
    }  
}  
  
fn main() {  
    // 初始化日志系统  
    env_logger::init();  
  
    // 解析命令行参数  
    let opt = Opt::parse_args();  
  
    // 创建一个服务器实例  
    let mut my_server = Server::new(Some(opt)).unwrap();  
    my_server.bootstrap();  
  
    // 配置上游服务器列表  
    let mut upstreams =  
        LoadBalancer::try_from_iter(["1.1.1.1:443", "1.0.0.1:443", "127.0.0.1:343"]).unwrap();  
  
    let hc = health_check::TcpHealthCheck::new();  
    upstreams.set_health_check(hc);  
  
    // 设置健康检查的频率为 1s    upstreams.health_check_frequency = Some(Duration::from_secs(1));  
  
    // 创建后台的健康检查服务  
    let background = pingora::services::background::background_service("health_check", upstreams);  
    let upstreams = background.task();  
  
    // 创建代理服务  
    let mut lb = http_proxy_service(&my_server.configuration, LB(upstreams));  
  
    // 配置 TLS 证书路径  
    let cert_path = format!("{}/tests/keys/server.crt", env!("CARGO_MANIFEST_DIR"));  
    let key_path = format!("{}/tests/keys/key.pem", env!("CARGO_MANIFEST_DIR"));  
  
    // 配置 TLS 设置  
    let mut tls_settings =  
        pingora::listeners::tls::TlsSettings::intermediate(&cert_path, &key_path).unwrap();  
    // 启用 HTTP/2 支持  
    tls_settings.enable_h2();  
  
    // 添加 HTTP 监听端口  
    lb.add_tcp("0.0.0.0:6188");  
  
    // 将服务添加到服务器  
    my_server.add_service(lb);  
    my_server.add_service(background);  
    // 永久运行服务器  
    my_server.run_forever();  
}
```


非常少的代码就基本实现了一个 `nginx` `upstream` 的大部分功能 包括:

- 后台的健康检查
- upstream 路由
- 负载均衡算法
- `tls` 配置

## refer

- [pingora github](https://github.com/cloudflare/pingora)
- [intro pingro](https://blog.cloudflare.com/zh-cn/pingora-open-source/)
- [user_guide](https://github.com/cloudflare/pingora/blob/main/docs/user_guide/index.md)
- [pingora_blogs_01](https://blog.cloudflare.com/zh-cn/how-we-built-pingora-the-proxy-that-connects-cloudflare-to-the-internet/)
- [pingora_blogs_02](https://blog.cloudflare.com/zh-cn/pingora-open-source/)