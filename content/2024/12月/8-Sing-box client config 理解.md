

## 1-Quick Start




```json5
{
  "dns": {
    "servers": [
	  // 1. google 的 dns 服务器
      {
        "tag": "google",
        "address": "tls://8.8.8.8"
      },
	  // 2. 阿里的 dns 服务器
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
	// DNS 解析优先走 local-tag ,也就是阿里
    "rules": [
      {
        "outbound": "any",
        "server": "local"
      }
    ],
	// 仅仅使用 ipv4
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun", // 使用 TUN 模式
      "inet4_address": "172.19.0.1/30", // TUN 接口的. IPV4 地址和子网掩码
      "auto_route": true, // 自动配置路由
      "strict_route": false // 禁止严格路由模式
    }
  ],
  "outbounds": [
    // ...
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geoip": [
          "private"
        ],
        "outbound": "direct"
      }
    ],
    "auto_detect_interface": true // 自动检测网络接口
  }
}
```


1. 

## refer

- [cli-examples](https://sing-box.sagernet.org/manual/proxy/client/#virtual-interface)