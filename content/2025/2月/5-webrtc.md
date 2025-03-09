

## 1-介绍

```mermaid
sequenceDiagram
    participant Publisher as 发布者
    participant WTN as WTN服务器
    participant Subscriber as 订阅者
    
    Publisher->>WTN: 1. 发送 Offer SDP
    Note over Publisher,WTN: 包含音频和视频描述
    WTN-->>Publisher: 2. 返回 Answer SDP
    Publisher->>WTN: 3. 建立WebRTC连接
    Publisher->>WTN: 4. 发布音视频流
    
    Subscriber->>WTN: 5. 请求订阅流
    WTN-->>Subscriber: 6. 返回流信息
    Subscriber->>WTN: 7. 建立WebRTC连接
    WTN->>Subscriber: 8. 传输音视频流
```

来面来自于 火山引擎 rtc 页面的流程, 用了一个 `WTN 服务器` 做中转, 一样是全双工双向协议的还有 `WebSocket` 和 `WebTransport` ;




> [!NOTE]  WebRTC vs WebSocket vs WebTransport


```mermaid
graph TB
    subgraph WebSocket
        WS1[应用层协议]
        WS2[基于TCP]
        WS3[服务器中转]
    end
    
    subgraph WebRTC
        W1[一套技术标准集合]
        W2[包含多个协议]
        W3[UDP/TCP]
        W4[点对点传输]
        W5[专门的音视频优化]
    end
```


```mermaid
graph TB
    subgraph WebRTC
        A1[点对点通信]
        A2[音视频流传输]
        A3[STUN/TURN/ICE]
        A4[适合视频会议]
    end
    
    subgraph WebTransport
        B1[客户端-服务器通信]
        B2[基于QUIC协议]
        B3[低延迟高吞吐]
        B4[适合游戏/直播]
    end
```

可以看出来 由于直播行业等等的发展 , `WebRTC` 则专门为音视频定制:
- 专门针对音视频 ;
- 内置功能: 音视频采集, 编解码, 网络传输, 回音消除 ;

音视频优化:

1. 自动码率适应: 视频会议自动的调整清晰度 ;
2. 丢包补偿: 即使网络不稳定，声音也不会断断续续 ;
3. 回音消除: 解决串音问题 ;
4. 噪声抑制: 自动过滤背景噪音, 开会对方也听不到周围的嘈杂声 ;
5. 自动增益控制: 声音太大自动降低， 声音太小自动提高 ;

网络传输优化:

1. `NACK`: 丢包重传, 发现数据包丢失后立即要求重发 ;
2. `FEC`: 前向纠错, 丢失了部分数据页能还原完整画面 ;
3. `RTX`: 选择性重传, 优先保证关键画面的传输 ;
4. `PLI`: 关键帧请求, 视频花屏快速的恢复清晰画面 ;



## 2-产品关系

看了一个火山引擎的 音视频集成的姿势.

![](https://portal.volccdn.com/obj/volcfe/cloud-universal-doc/upload_2616714681db53aaabb6b971f3c93792.png)






## refer

- [webrtc vs webtransport](https://www.videosdk.live/developer-hub/webtransport/webrtc-vs-webtransport)
- [火山实时音视频](https://www.volcengine.com/docs/6348/66812)
- [WebRTC 传输网络](https://www.volcengine.com/docs/6752/122560)

