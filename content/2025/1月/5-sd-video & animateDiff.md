

## Intro

有哪些 基于 扩散到视频的算法.

- `SVD` : Stable Video Diffusion, 官方的图像到视频的方案
- `Animate Diff`: 社区主导的动画生成方案
- `I2V-Adapter`:
- `Anim-Director`

混合的思路:

- SVD + AnimateDiff 组合：利用SVD做精炼(Refiner)
- AnimateDiff + ToonCrafter：针对动漫风格优化
- Viggle：一种新的动画增强技术
- SD.Next：包含了最新的动画生成功能
- IPA (Image Prompt Animation)：简化2D动画精炼过程
- Prompt Travel：通过动态改变提示词实现更好的动画效果

## svd

**Limit:**

1. 视频时长限制(≤4秒)
2. 可能无法达到完美的照片级真实感
3. 可能生成静止或极慢镜头视频
4. 不支持文本控制
5. 无法渲染可读文本
6. 人脸和人物生成可能存在问题
7. 模型的自动编码部分存在损耗



## refer

- [huggingface-svd](https://huggingface.co/docs/diffusers/en/using-diffusers/svd)
- [i2vgenxl-diffusers](i2vgenxl)


