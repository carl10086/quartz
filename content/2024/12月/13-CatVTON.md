
## 1-Intro

*简单*, *高效* 的扩散模型, 他做了如下的选择:

1. 轻量级网络 (总共 `899.06M` 参数)
	- 总参数量是 `899.06M` ， 相比其他虚拟试穿模型要小的多
	- 这种 轻量级设计有助于模型的部署和实际应用
2.  参数高效训练 (`49.57M`  可训练参数)
	- 只有 `49.57M` 参数需要训练， 约占总参数量的 `5.5%` 
	- 这种设计 大大减少了训练时间和计算资源需求
3. 简化推理过程 `1024 x 768` 分辨率下只需 `<8G` 显存
	- 处理 `1024 x 768` 这种较高分辨率图片
	- 只需要不到 `8G` 的显存

比较有特点的选择:

1. 2024年7月的最新研究成果, `concatenation` is all you need .
2. 相比传统的基于 `GAN` 的方法, 提供了更好的性能和更简单的视线 ;



## 2-ComfyUi with CatVTON

 安装遇到了一些版本问题，首先:

```bash
pip install Ninja
```

```bash
# 安装基本编译工具, 推荐使用 
conda install -c conda-forge gcc gxx=13.3.0
```

```sh
# 手动安装 facebook 的 detectron2
pip install 'git+https://github.com/facebookresearch/detectron2.git'
```


## refer


- [CatVTON](https://huggingface.co/zhengchong/CatVTON)
- [github](https://github.com/Zheng-Chong/CatVTON)
