
## 1-Intro

`Ubuntu need a simple proxy`

**1)-apt installation**

```sh
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt-get update
sudo apt-get install sing-box # or sing-box-beta
```


**2)-config transfer**

使用这个 `python` 脚本配合自己的 `template` 去修改. https://github.com/Toperlock/sing-box-subscribe

****

## 2-History

一直以来， 客户端的代理的技术有3类:

- System proxy: 系统原生支持的代理
- Firewall redirection: 网络的流量和拦截, 例如 Windows 的 `WFP`, `Linux` 的 `Redirect`, `eBpf`, `macos` 的 `pf`
- Virtual interface: 所有的 `L2` 和 `L3` 各种 `vpn` 都是基于虚拟网络接口, `single-box` 基于 `clash-premium` 的 `TUN` 入站 (`l3` 到 `l4` ) 的转换功能. 提供了透明的代理.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/202411261120580.png)






## refer

- [https://github.com/SagerNet/sing-box](https://github.com/SagerNet/sing-box)