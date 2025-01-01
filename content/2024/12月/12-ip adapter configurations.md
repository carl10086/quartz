#ip-adapter 

## 1-Intro

`Ip-Adapter` 图片引导的参数 相对比较难以控制.

- 合适的参数配置 可以提高工作流效率
- 参数调整可以提供更好的 生成控制
- 了解这些参数对于优化生成任务很重要


## 2-Image embedding

图像嵌入的优势:

- 预计算和重用能力
- 节省存储空间
- 提高处理效率
- 支持多图像样式的融合

```python
# 步骤1：生成嵌入
image_embeds = pipeline.prepare_ip_adapter_image_embeds(
    ip_adapter_image=image,
    ip_adapter_image_embeds=None,
    device="cuda",
    num_images_per_prompt=1,
    do_classifier_free_guidance=True,
)

# 步骤2：保存嵌入
torch.save(image_embeds, "image_embeds.ipadpt")

# 步骤3：加载和使用嵌入
image_embeds = torch.load("image_embeds.ipadpt")
images = pipeline(
    prompt="...",
    ip_adapter_image_embeds=image_embeds,
    ...
)
```

这个 `embedding` 后续可以直接复用， 直接减少推理的成本.

```python
image_embeds = torch.load("image_embeds.ipadpt")
images = pipeline(
    prompt="a polar bear sitting in a chair drinking a milkshake",
    ip_adapter_image_embeds=image_embeds,
    negative_prompt="deformed, ugly, wrong proportion, low res, bad anatomy, worst quality, low quality",
    num_inference_steps=100,
    generator=generator,
).images
```


## 3-Ip adapter masking

IP-Adapter masking 允许通过二进制遮罩指定输出图像中 哪些部分应该使用 特定的 `IP-Adapter` 图像。 这对于组合多个 `IP-Adapter` 图像特别有用

1. 遮罩的作用:
	- 精确控制 图像区域
	- 支持多个图像的组合
	- 实现区域特定的样式转换
2. 预处理要求:
	- 使用 `IPAdapterMaskProcessor.preprocess()` 处理输入图像
	- 需要为每个输入图像提供遮罩
	- 建议指定输出尺寸获得最佳效果

**遮罩预处理:**

```python
from diffusers.image_processor import IPAdapterMaskProcessor

mask1 = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_mask_mask1.png")
mask2 = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_mask_mask2.png")

output_height = 1024
output_width = 1024

processor = IPAdapterMaskProcessor()
masks = processor.preprocess([mask1, mask2], height=output_height, width=output_width)
```

**IP-Adapter 配置:**

```python
pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name=["ip-adapter-plus-face_sdxl_vit-h.safetensors"])
pipeline.set_ip_adapter_scale([[0.7, 0.7]])  # one scale for each image-mask pair

face_image1 = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_mask_girl1.png")
face_image2 = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_mask_girl2.png")

ip_images = [[face_image1, face_image2]]

masks = [masks.reshape(1, masks.shape[0], masks.shape[2], masks.shape[3])]

generator = torch.Generator(device="cpu").manual_seed(0)
num_images = 1

image = pipeline(
    prompt="2 girls",
    ip_adapter_image=ip_images,
    negative_prompt="monochrome, lowres, bad anatomy, worst quality, low quality",
    num_inference_steps=20,
    num_images_per_prompt=num_images,
    generator=generator,
    cross_attention_kwargs={"ip_adapter_masks": masks}
).images[0]
image
```






## refer
- [diffusers ip adapter](https://github.com/huggingface/diffusers/blob/main/docs/source/en/using-diffusers/ip_adapter.md)