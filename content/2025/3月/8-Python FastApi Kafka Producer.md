


## 1-Intro

**库的选择:**

根据多个来源的性能测试：

|                        |     |        |      |       |
| ---------------------- | --- | ------ | ---- | ----- |
| 库                      | 吞吐量 | CPU使用率 | 内存使用 | 异步支持  |
| confluent-kafka-python | 高   | 低      | 低    | 需额外封装 |
| kafka-python           | 中   | 高      | 高    | 需额外封装 |
| aiokafka               | 中-高 | 中      | 中    | 原生支持  |


找一个比较好的实践.


```python
# 高性能生产者配置
high_throughput_config = {
    'bootstrap.servers': 'localhost:9092',
    
    # 批处理优化
    'batch.size': 64 * 1024,  # 64KB
    'linger.ms': 10,          # 增加等待时间，提高批处理效率
    
    # 压缩
    'compression.type': 'lz4',  # 高性能压缩算法
    
    # 缓冲区设置
    'queue.buffering.max.messages': 500000,
    'queue.buffering.max.kbytes': 1024 * 1024,  # 1GB
    
    # 减少确认要求以提高吞吐量（注意：降低可靠性）
    'acks': 1,
    
    # 发送缓冲区
    'socket.send.buffer.bytes': 1024 * 1024,  # 1MB
}
```



压缩算法就先不要了把. 
