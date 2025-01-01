#ip-adapter 

## 1-Intro

之前 快速搞了 `Ip-Adapter` 的 `demo` 和其他原理: [[17-ip-adapter && ip-adapter-plus basic]]

`Ip-Adapter` 是一个 Image Prompt Adapter, 可以把 `Image Prompt` 适配到任何的扩散模型, 实现图像提示功能, 而无需对底层模型进行任何的更改. 

此外, 这个适配器可以与  *同一基础模型微调的其他模型一起重用* , 注意 是 `BaseModel` 相同的话就可以. 尤其提到了 可以很好的和 `ControlNet` 集成工作.

训练了一个独立的 `cross-Attention` 去学习图片的特征.  而不是使用相同的交叉注意力层来处理文本和图像特征, 这样这个模型可以更多的学习 **专属于图片维度**  的特征.


1. 使用了解耦的交叉注意力机制 ;
2. 图像特征有专门的处理层 ;


**1)-为什么 ControlNet 适合和 IP-Adapter 一起工作?**

`controlNet` 确实是通过 特征融合 的方式在 `U-Net` 的各个层级通过 *Zero Convolution方式* 注入控制信号 ;

- 在 `UNet` 的主干网络中添加条件分支, 这些分支学习从 控制图像 ，例如 `pose`, `edge`, `depth` 中提取的特征 ;
- 直接在特征层面进行 融合 ;

在 `sd` 的领域中， 卷积 `UNet` 是主干架构，适合学习图片的细节，纹理，而 `UNet` 每一层引入的 `transformer blocks` 去学习整体的风格一致 和细节把控 ;

类似的思路:

- 从效果上看: `controlNet` 可以控制生成图像的精确结构, `Ip-Adapter` 可以提供参考图像的风格和细节 ;
- 从代码上看: `controlNet` 工作在 `feature` 层面上引入 `Zero Convolution`, 而 `Ip-Adapter` 工作在 `CrossAttention` 层面 ;


## 2-t2i

下面的例子:

文生图的引导能力:

1. 通过 `ip_adapter_image` 引入了一张图作为风格指导，负责整个餐厅的布局 ;
2. 通过 文本增加了一张图片 增加了额外的内容 ;

```python
from diffusers import AutoPipelineForText2Image
from diffusers.utils import load_image
import torch

pipeline = AutoPipelineForText2Image.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16).to("cuda")
pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl.bin")
pipeline.set_ip_adapter_scale(0.6)


image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_diner.png")
generator = torch.Generator(device="cpu").manual_seed(0)
images = pipeline(
    prompt="a polar bear sitting in a chair drinking a milkshake",
    ip_adapter_image=image,
    negative_prompt="deformed, ugly, wrong proportion, low res, bad anatomy, worst quality, low quality",
    num_inference_steps=100,
    generator=generator,
).images
images[0]
```

原图:

![](https://cdn-lfs.hf.co/datasets/huggingface/documentation-images/891a02ca66dcfc88654537841a51ef9eb11dcf4c44184acf5afba1735b1f3738?response-content-disposition=inline%3B+filename*%3DUTF-8%27%27ip_adapter_diner.png%3B+filename%3D%22ip_adapter_diner.png%22%3B&response-content-type=image%2Fpng&Expires=1734331978&Policy=eyJTdGF0ZW1lbnQiOlt7IkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTczNDMzMTk3OH19LCJSZXNvdXJjZSI6Imh0dHBzOi8vY2RuLWxmcy5oZi5jby9kYXRhc2V0cy9odWdnaW5nZmFjZS9kb2N1bWVudGF0aW9uLWltYWdlcy84OTFhMDJjYTY2ZGNmYzg4NjU0NTM3ODQxYTUxZWY5ZWIxMWRjZjRjNDQxODRhY2Y1YWZiYTE3MzViMWYzNzM4P3Jlc3BvbnNlLWNvbnRlbnQtZGlzcG9zaXRpb249KiZyZXNwb25zZS1jb250ZW50LXR5cGU9KiJ9XX0_&Signature=XXg%7EIlnOJme1-lxnSjJJGO8eVwYzdi8YHbCkHmqj1B8GYNRqIQyQTe8dtWXDkTj5cqV7rMeshgctBnLesy%7ELtjAx2r0bncPLiz1Llj88mpyGcm5wwtkc1JCPQ0fkxgeCPxzUHmUIi5JOcwF2Kj7JsM7Bshr8lbSW-f4Ldcq82T-MTjBbwup-eLvzEU%7EPXSj4HAujB5TbYnNM2LUoBfdWdcpOxe%7EYcQs7Xfq%7E3oIjmwfvV8hHr3GuItOg7rP%7E3KBecV84gZPRdo34AquHK-yrkupuymYCx8ulRp2yPOwLwPpYTmMznAMxkjVEyt9Hdfq33NciMfrb2tRCw3%7EEi7R-zw__&Key-Pair-Id=K3RPWS32NSSJCE)


![](https://camo.githubusercontent.com/6f26c9c2dea7142108d1aefe0c46daad5ce6604bca427fa94520617ec1df4b4f/68747470733a2f2f68756767696e67666163652e636f2f64617461736574732f68756767696e67666163652f646f63756d656e746174696f6e2d696d616765732f7265736f6c76652f6d61696e2f6469666675736572732f69705f616461707465725f64696e65725f322e706e67)


## 3-i2i

`Ip-Adapter` 也可以用来作为图片引导, 生成一个同时类似于原始图像和图像提示的新图像.


```python
from diffusers import AutoPipelineForImage2Image
from diffusers.utils import load_image
import torch

pipeline = AutoPipelineForImage2Image.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16).to("cuda")
pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl.bin")
pipeline.set_ip_adapter_scale(0.6)

image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_bear_1.png")
ip_image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_bear_2.png")

generator = torch.Generator(device="cpu").manual_seed(4)
images = pipeline(
    prompt="best quality, high quality",
    image=image,
    ip_adapter_image=ip_image,
    generator=generator,
    strength=0.6,
).images
images[0]
```

## 4-inpainting

局部重绘的能力, `Ip-Adapter` 也非常适合重绘的工作， 因为可以让你更明确 需要重绘成什么样子的东西.

```python
from diffusers import AutoPipelineForInpainting
from diffusers.utils import load_image
import torch

pipeline = AutoPipelineForInpainting.from_pretrained("diffusers/stable-diffusion-xl-1.0-inpainting-0.1", torch_dtype=torch.float16).to("cuda")
pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl.bin")
pipeline.set_ip_adapter_scale(0.6)
```


```python
mask_image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_mask.png")
image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_bear_1.png")
ip_image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_gummy.png")

generator = torch.Generator(device="cpu").manual_seed(4)
images = pipeline(
    prompt="a cute gummy bear waving",
    image=image,
    mask_image=mask_image,
    ip_adapter_image=ip_image,
    generator=generator,
    num_inference_steps=100,
).images
images[0]
```

- `mask_image` : 指定需要修复的区域 ;
- `image` : 原始需要修复的图像 ;
- `ip_image` : 提供参考样式的图像.

```python
images = pipeline(
    prompt="a cute gummy bear waving",
    image=image,
    mask_image=mask_image,
    ip_adapter_image=ip_image,
    generator=generator,
    num_inference_steps=100,
)
```

- `prompt` : 文本描述 目标生成内容 ;
- `generator`: 固定随机种子以保证可重复性 ;
- `num_inference_steps`: 100步推理以确保质量 ;


## 5-generated image

`IP-Adapter` 在视频生成的作用:

1. 提供更精确的视觉引导
2. 增强文本提示的效果
3. 实现风格和内容的精确控制

下面的代码使用视频生成模型, `AnimatedDiff` 来实现.

```python
import torch
from diffusers import AnimateDiffPipeline, DDIMScheduler, MotionAdapter
from diffusers.utils import export_to_gif
from diffusers.utils import load_image

adapter = MotionAdapter.from_pretrained("guoyww/animatediff-motion-adapter-v1-5-2", torch_dtype=torch.float16)
pipeline = AnimateDiffPipeline.from_pretrained("emilianJR/epiCRealism", motion_adapter=adapter, torch_dtype=torch.float16)
scheduler = DDIMScheduler.from_pretrained(
    "emilianJR/epiCRealism",
    subfolder="scheduler",
    clip_sample=False,
    timestep_spacing="linspace",
    beta_schedule="linear",
    steps_offset=1,
)
pipeline.scheduler = scheduler
pipeline.enable_vae_slicing()

pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="models", weight_name="ip-adapter_sd15.bin")
pipeline.enable_model_cpu_offload()
```

```python
ip_adapter_image = load_image("https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/ip_adapter_inpaint.png")

output = pipeline(
    prompt="A cute gummy bear waving",
    negative_prompt="bad quality, worse quality, low resolution",
    ip_adapter_image=ip_adapter_image,
    num_frames=16,
    guidance_scale=7.5,
    num_inference_steps=50,
    generator=torch.Generator(device="cpu").manual_seed(0),
)
frames = output.frames[0]
export_to_gif(frames, "gummy_bear.gif")
```



## refer

- [diffusers ip-adapter](https://github.com/huggingface/diffusers/blob/main/docs/source/en/using-diffusers/ip_adapter.md)