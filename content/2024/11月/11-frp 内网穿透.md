
## 1-介绍

为了实现内网穿透. 

1. 如果是临时使用， 直接 SSH 反向隧道就行. 
2. 如果是长期使用:
	- 小规模可以用 `frp`
	- 更好的体验可以用 `ZeroTier` 或者 `Tailscale`


```bash
ssh -fCNR 远程端口:localhost:22 用户名@公网服务器2
```


## 2-ssh 反向隧道

利用本地 `mac` 的代理能力.

**1)-安装本地的代理**

```sh
brew install privoxy
```

开启端口.  `vim /opt/homebrew/etc/privoxy/config` 加入2个配置即可.

```sh
 listen-address 127.0.0.1:8001
 forward / .
```

启动服务:

```sh
brew services start privoxy
brew services info privoxy
```

**2)-建立隧道**

```sh
ssh -R 7890:127.0.0.1:8001 {YOUR-MACHINE}
```


## 3-frp

配置非常简单，而且支持多种协议.

a. 在公网服务器2上部署 frps (服务端)
b. 在本地机器1上部署 frpc (客户端)
c. 配置后即可通过服务器2访问机器1


服务端改下 `Addr` 即可. 客户端一般配置如下.

```toml
serverAddr = "服务器2的IP"
serverPort = 7000

# SSH 转发
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000

# Web 服务转发
[[proxies]]
name = "web"
type = "tcp"
localIP = "127.0.0.1"
localPort = 80
remotePort = 8080

# MySQL 转发
[[proxies]]
name = "mysql"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3306
remotePort = 13306
```


下面用一个例子代表, 客户端开启配置:

```toml
serverAddr = "124.221.218.173"
serverPort = 7000


[[proxies]]
name = "test-tcp"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8000
remotePort = 8888
```

客户端开启一个 http 服务. `python3 -m http.server 8000`

直接公网访问: `http://124.221.218.173:8888` 即可访问服务

## refer

- [frp](https://github.com/fatedier/frp)




