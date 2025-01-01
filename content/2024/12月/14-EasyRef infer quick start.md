
## 1-Intro

**1)-什么是 EasyRef **

1. 这是一个对齐模型. 主要的目的是为了让 多模态的大语言模型 (`MLLM`) 的视觉理解能力和扩散模型对接 ;
2. 确保视觉信号能够被 扩散模型正确解读 ;

是一个渐进式的训练方案:

1. alignment pre-training stage : 促进 `MLLM` 的视觉信号和扩散模型的适配 ;
2. single-reference finetune stage : 单参考微调，目的是为了 增强 `MLLM` 在细粒度视觉感知和身份识别方面的能力 ;
3. multiple-reference finetune stage : 多个参考图片上的微调, 理解多个图像之间的共同元素 ;

**2)-Tips**

1. 使用2张以上的参考图像: 有助于模型更好的理解图片之间的 **共同特征**, 所以最好是一个 主体多种角度的 图片, 这样可以更好的保证结果的稳定性和准确性 ;
2. 最好是 **正方形图像**, 如果想要保证人脸的特征， 最好让人脸在图片的中间，比例大一些，不要复杂的背景 ;
3. 使用多模态的组合提示， 也就是 最好 用图片提供 *视觉参考*, 用文本补充 *细节信息*, 双向引导 ;
4. 核心参数: `scale` 默认是 `1.0` , 降低这个值 会让生成结果更加的多样化, 但是一致性降低 ;

**3)-3个训练阶段**

- 对齐预训练:  这个阶段仅仅训练 `MLLM` 也就是 `QWen-VL` 的 `final-Layer` .  `projection layer` 和 `cross-attention` `adapters` . [训练脚本](https://github.com/TempleX98/EasyRef/blob/main/scripts/alignment_pretraining.sh)
- 单张参考图片的微调: 训练  *整个MLLM 模型*, *MLLM 最终层* *投影层* *新增的 LoRA层* *cross-attention adapters* 
- 多张参考图片的微调: 使用不同的训练数据 去训练单图片 中相同的 `Layer`

这是一种渐进式的训练手段，从最基础的对齐能力逐渐开始，然后训练任务逐渐的复杂，从单张图片到多张图片 .

## refer

- [huggingface](https://huggingface.co/zongzhuofan/EasyRef)
- [github](https://github.com/TempleX98/EasyRef)