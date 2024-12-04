
> 内容太辣鸡了，自己有点看不下去


## 1-Http


> http-url 的1个例子

`https://username:password@domain.com/path?q1=a#flagment`

> 什么东西应该走 urlEncode

1. 不在 `ASCII` 码范围内
2. `ASCII` 不可以显示
3. `URI` 规定中的保留字符
4. 不安全字符, 空格, 引号，尖括号


编码方式叫做 `pct-encoded` 就是 `%` + 2个16进制的数字.

> 响应码

- `1xx` : 请求已经收到, 需要进一步处理, `HTTP1.0` 不支持
	- `100 Continue`: 上传大文件前使用
	- `101 Switch Protocols` : 协议升级, 例如 `Websocket` 或者 `http2.0`
	- ...
- `2xx`: 成功处理请求
	- `200 OK`: 成功
	- `201 Created` : 有新资源在服务器端 被成功创建
	- `202 Accepted`: 服务器接收并开始处理 请求，但是请求没有处理完成, 非常模糊, 用来做 异步或者需要长时间处理的任务
	- ...
- `3xx`: 重定向使用 `Location` 指向的资源或者缓存中的资源, `RFC2068` 中规定不得连续重定向 5次
	- `301`: 永久
	- `302`: 临时
	- `304 Not Modified` :  客户端可以复用缓存
	- `307 Temprorary Redirect`: 类似302， 但是明确重定向后请求方法和原请求方法相同，不得改变
	- `308 Permanent Redirect`: 类似 301，但是明确重定向后请求方法和原请求方法相同，不得改变

- `4xx`  : 客户端错误
	- `400 Bad Request`: 请求有问题，但是不知道是什么问题, 例如可能格式错了
	- `401 Unauthorized`: 没有认证
	- `403 Forbidden`: 经过认证了，但是没有权限
	- `404 Not found`: 服务器没有找到对应的资源
	- `405 Method Not Allowed`
	- `408 Request Timeout`: 服务器接收请求超时
	- ...

- `5xx` : 服务端出现错误
	- `500 Internal Server Error`: 服务器内部错误, 且不属于以下错误类型
	- `502 Bad Gateway`: 代理服务器无法获取到合法响应
	- `503 Service Unavailable`: 服务侧 `Timeout`



> Cookie: RFC 规定用来管理 Http State 的机制

客户端使用磁盘或者内存存储.

请求服务端 使用 **多个 Set-Cookie** 头部的 **键值对**, 客户端承诺后续的请求使用 **1个Cookie** 头部全部带过来. 

- 为什么 `Set-Cookie` 一个? 为了给这个键值对具体的规则.

`Cookie` 设计有点问题，要避免:

1. 一定要用 `HTTPS` 加密，否则不安全，是纯纯的明文
2. 不能超过 `4KB`, 复杂的东西别来



> http1.1


- 基于文本, 请求和响应都是纯文本
- 有个缓存
- 基于 `tcp`，有连接的概念
- 默认支持 `Keep-Alived` , 也就是一个连接上可以有多个请求和响应



> http2


- 走的是 二进制协议,, 保持了语法不变，不是文本了
- 有个 `HPACK` 压缩头部
- 支持多路复用
	- 追求低延迟，不是高带宽吞吐
	- 不会像 `HTTP1.1` 一个连接慢了影响其他的, 
	- `TCP` 是慢启动的, 热了起来再重新启动会有点慢




> http3: 基于 `QUIC` 改造

参考 [Pinterst Is ON Http3](https://medium.com/pinterest-engineering/pinterest-is-now-on-http-3-608fb5581094)

- HTTP/3 基于 QUIC 协议，该协议使用 UDP 替代了 TCP，解决了 HTTP/2 中的 **队头阻塞问题**。在 TCP 网络传输中，如果一个数据包丢失，那么后面的数据包会被阻塞，即使他们所属不同的HTTP请求。然而在 HTTP/3 中，通过 QUIC 协议的多路复用，这些数据包都被独立处理，一个丢失的数据包不会影响其他数据包的传输。
- HTTP/3 支持连接在 IP 地址之间进行迁移，这对于移动设备的使用场景具有很大的优势。比如当一个用户正在使用 Wi-Fi 浏览网页时，然后切换到移动网络，HTTP/3 会保持连接状态，而不需要重新建立。
- HTTP/3 允许在协议层面进行丢包检测和拥塞控制的调整和优化。
- 由于 QUIC 的特性，HTTP/3 可以通过 0-RTT (Round-Trip Time) 连接建立，在不减少安全性的前提下，极大地减少了连接建立的时间。
- HTTP/3 更适合处理大数据载荷的场景，比如图片下载、视频流传输等。通过上述各种技术的优势，HTTP/3 可以更有效地处理这些大数据载荷，提高传输效率和用户体验。


``


	




