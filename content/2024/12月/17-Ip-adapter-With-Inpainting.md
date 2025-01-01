

## 1-介绍

原始的 `inpainting` 能力一般都是 一张图片 + 一张掩码 + 一些文本来控制 图片的生成.  这些文本会引导 掩码覆盖的重绘区域. 

而 `Ip-Adapter` 是一个独立的模块，`Image Prompt Adapter` , 也就是说我们希望使用 **第三张图片而不是上面的文本** 去引导最后图片内容的生成.

## 2-基本的 inpainting

```python
import torch
from diffusers import AutoPipelineForInpainting
from diffusers.utils import load_image

from base import image_utils

pipe = AutoPipelineForInpainting.from_pretrained("/home/carl/storage/diffusers/stable-diffusion-xl-1.0-inpainting-0.1",
                                                 torch_dtype=torch.float16, variant="fp16").to("cuda")

img_url = "/home/carl/storage/images/tmp/overture-creations-5sI6fQgYIuo.png"
mask_url = "/home/carl/storage/images/tmp/overture-creations-5sI6fQgYIuo_mask.png"

image = load_image(img_url).resize((1024, 1024))
mask_image = load_image(mask_url).resize((1024, 1024))

image_utils.show_images([image, mask_image])

prompt = "a tiger sitting on a park bench"
generator = torch.Generator(device="cuda").manual_seed(0)

image = pipe(
    prompt=prompt,
    image=image,
    mask_image=mask_image,
    guidance_scale=8.0,
    num_inference_steps=20,  # steps between 15 and 30 work well for us
    strength=0.99,  # make sure to use `strength` below 1.0
    generator=generator,
).images[0]

image_utils.show_image(image)
```


## 3-实现

模型准备:

1. [madebyollin/sdxl-vae-fp16-fix](https://huggingface.co/madebyollin/sdxl-vae-fp16-fix) : fp16 的 vae 可以减少一些成本
2. 一个 `ip-adapter` 模型
```python
pipeline.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl.bin", low_cpu_mem_usage=True)
```
3. 可选: 自动化 `segmentBody`  的能力





## refer

- [blogs](https://huggingface.co/blog/tonyassi/virtual-try-on-ip-adapter)
