
## 1-T2i 源码

```python
class ComfyT2iPipeline(BaseComfyPipeline):
    """Text-to-Image (T2I) 生成管线的实现类。
    
    该类继承自BaseComfyPipeline，实现了将文本提示转换为图像的核心功能。整个过程包括：
    1. 生成潜空间初始噪声
    2. 编码正向和负向提示词
    3. 使用采样器生成潜空间图像
    4. 通过VAE解码得到最终图像
    
    Attributes:
        vae: VAE模型实例，用于将潜空间数据解码为RGB图像
        text_encode: 文本编码器，用于将提示词转换为模型可理解的向量表示
    """
    
    @torch.no_grad()
    def __call__(self, params: T2iParams):
        """执行文本到图像的生成过程。
        
        Args:
            params (T2iParams): 包含生成参数的数据类，包括：
                - width: 目标图像宽度
                - height: 目标图像高度
                - prompt: 正向提示词
                - negative_prompt: 负向提示词
                - 其他采样相关参数
        
        Returns:
            tuple: 包含两个元素：
                - list[Image]: 生成的PIL图像列表
                - int: 使用的随机种子值
        
        Note:
            整个过程在torch.no_grad()上下文中执行，以提高推理效率
        """
        # 生成空白的潜空间图像作为初始状态
        latent = EmptyLatentImage().generate(params.width, params.height, 1)[0]
        
        # 编码正向和负向提示词
        positive = self.text_encode(params.prompt)[0]
        negative = self.text_encode(params.negative_prompt)[0]
        
        # 使用采样器在潜空间生成图像
        samples, seed = self.common_ksampler(params, positive, negative, latent)
        
        # 使用VAE将潜空间数据解码为RGB图像
        images = VAEDecode().decode(self.vae, {"samples": samples})[0]

        # 将tensor格式的图像转换为PIL格式
        pil_images = []
        for image in images:
            # 将像素值范围从[-1,1]转换到[0,255]
            i = 255. * image.cpu().numpy()
            # 裁剪像素值并转换为uint8类型
            img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))
            pil_images.append(img)
            
        return images, seed
```


**1)-EmptyLatentImage**

```python
class EmptyLatentImage:
    def __init__(self):
        self.device = comfy.model_management.intermediate_device()

    def generate(self, width, height, batch_size=1):
        latent = torch.zeros([batch_size, 4, height // 8, width // 8], device=self.device)
        return ({"samples":latent}, )
```
- 生成空白的潜空间图像

**2)-CLIP 用来编码文本**

```python
    def text_encode(self, prompt: str):
        return CLIPTextEncode().encode(self.clip, prompt)
```

**3)-基本参数**

```python
@dataclasses.dataclass
class BaseT2iParams:
    """文本到图像(Text-to-Image)生成的基础参数配置类。
    
    这个数据类定义了在ComfyUI中进行图像生成所需的核心参数。每个参数都对生成结果有重要影响。
    
    Attributes:
        prompt (str): 正向提示词，描述你想要生成的图像内容
        
        steps (int): 推理步数，默认20步。步数越多生成质量越高，但耗时也越长。
            建议范围：15-50，取决于采样器类型
            
        negative_prompt (str): 负向提示词，描述你不希望在图像中出现的内容。
            默认为空字符串
            
        pipeline (str): 使用的生成策略算法名称。
            不同的pipeline可能会导致不同的生成效果
            
        width (int): 生成图像的宽度，默认1024像素
            建议使用64的倍数以获得最佳性能
            
        height (int): 生成图像的高度，默认1024像素
            建议使用64的倍数以获得最佳性能
            
        batch_size (int): 批处理大小，即一次生成多少张图片，默认1
            TODO: 后续可能支持更大的batch size
            
        sampler_name (str): 采样器名称，决定了如何从噪声生成图像
            常用选项包括：
            - euler_a: 快速且质量不错的通用采样器
            - dpm++: 高质量但较慢的采样器
            - ddim: 确定性采样器，适合动画生成
            
        scheduler (str): 调度器名称，控制采样过程中的噪声调度策略
            常用选项包括：
            - karras: 适合大多数场景的通用调度器
            - exponential: 在某些场景下可能产生更好的细节
            - normal: 基础调度器
            
        cfg (float): Classifier Free Guidance Scale，默认7.5
            控制生成图像对提示词的遵循程度：
            - 值越大，生成图像越严格遵循提示词，但可能过度僵化
            - 值越小，生成更有创意但可能偏离提示词
            建议范围：5-15
            
        seed (int): 随机种子，默认-1（随机）
            - 设置具体数值可以复现相同的生成结果
            - 设置为-1则每次生成随机结果
    """
```



## refer

- [comfy-flux](https://comfyanonymous.github.io/ComfyUI_examples/flux/)
- [build a simple application with chat models and prompt templates](https://python.langchain.com/docs/tutorials/llm_chain/)