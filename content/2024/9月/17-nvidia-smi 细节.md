


## QuickStart

[原文](https://mp.weixin.qq.com/s/Yu4UCprk9HfIMZGsrEOeXA)

可以展示 所有 `GPU` 的信息.

```bash

## 1. 展示 GPU 的基本信息
nvidia-smi

## 2. 展示型号
nvidia-smi -L

## 3. 显示 GPU 的详细信息
nvidia-smi -q

## 4. 指定某一块 GPU
nvidia-smi -i 0

## 5. 监控整体 GPU 的使用情况
nvidia-smi dmon -i 0 -d 2

## 6. 查看 某个 GPU 卡上运行的任务
nvidia-smi pmon -i 0

## 7. 实时刷新 GPU 信息
nvidia-smi -l 5

## 8. 还可以限制 GPU 的功耗
nvidia-smi -i 0 -pl 70

## 9. 清除已发生的错误记录
nvidia-smi --clear-gpu-errors


## 10. 查看驱动的版本
nvidia-smi --query-gpu=driver_version --format=csv

## 11. 显示每个 GPU 的显存总量
nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv

## 12. 设置 GPU 的计算模式
nvidia-smi -i 0 -c 1
```




