
## 1-介绍

`OOTDiffusion` 没有提供扩散模型，只能用他们提供的人物图片. 这里尝试一下用 `inpainting Diffusion Model` + `IpAdapter` 来引导生成.

**1)-set_ip_adapter_scale**

这个方法用来控制应用于模型的文本或者图像条件的强度.  `1.0` 表示模型仅仅受到图像提示的约束, 降低这个值会鼓励模型生成更加多样化的图像，但是可能和图像提示的对齐程度较低.  这里先试用 `1.0`



## 2-Demo

```python
import torch
from diffusers import AutoPipelineForInpainting
from diffusers.utils import load_image

from base import image_utils
from it.xl.SegBody import segment_body

image = load_image('/home/carl/storage/images/tmp/jpFBKqYB3BtAW26jCGJKL.jpeg').convert("RGB")
ip_image = load_image('/home/carl/storage/images/tmp/NL6mAYJTuylw373ae3g-Z.jpeg').convert("RGB")
seg_image, mask_image = segment_body(image, face=False)

pipeline = AutoPipelineForInpainting.from_pretrained(
    "/home/carl/storage/diffusers/stable-diffusion-xl-1.0-inpainting-0.1",
    torch_dtype=torch.float16, variant="fp16").to("cuda")

pipeline.load_ip_adapter("/home/carl/storage/h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl.bin")

final_image = pipeline(
    prompt="photorealistic, perfect body, beautiful skin, realistic skin, natural skin",
    negative_prompt="ugly, bad quality, bad anatomy, deformed body, deformed hands, deformed feet, deformed face, deformed clothing, deformed skin, bad skin, leggings, tights, stockings",
    image=image,
    mask_image=mask_image,
    ip_adapter_image=ip_image,
    strength=0.99,
    guidance_scale=7.5,
    num_inference_steps=25,
).images[0]

image_utils.show_image(final_image)

```


## refer

- [origin](https://huggingface.co/blog/tonyassi/virtual-try-on-ip-adapter)
- [OOTDiffusion](https://github.com/levihsu/OOTDiffusion)
