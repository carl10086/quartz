

## 1-Intro

`Flux` 是一个使用了 `diffusion transformers` 的 模型， 由 `Black Forest Labs` 开发. 具有 120亿参数， 是目前最大的开源文本到图像模型.


有三个大版本:

1. `FLUX.1 [pro]` : 闭源， 细节和多样性非常的好
2. `FLUX.1 [dev]` : `pro` 模型的指导蒸馏变体, 适合研发
3. `FLUX.1 [schnell]` : `schnell` 为速度优化的变体， 单纯的快


> [!NOTE] Tips
> 由于是 `transformers` 会导致非常的消耗资源，对于一个消费级的显卡来说压力非常的大.  
> 这里会使用 一些量化的技巧来提高内存的效率. 



这里介绍2个变体:

1. 基于时间步长timestep-distilled 的变体:  `black-forest-labs/FLUX.1-schnell`
2. 基于引导蒸馏版本的变体: `black-forest-labs/FLUX.1-dev`


## 2-quick start

### 2-1 Timestep-distilled

```python
import torch
from diffusers import FluxPipeline

pipe = FluxPipeline.from_pretrained("black-forest-labs/FLUX.1-schnell", torch_dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()

prompt = "A cat holding a sign that says hello world"
out = pipe(
    prompt=prompt,
    guidance_scale=0.,
    height=768,
    width=1360,
    num_inference_steps=4,
    max_sequence_length=256,
).images[0]
out.save("image.png")
```

 有一些要点:

- `max_sequence_length` 不能超过 256
- `guidance_scale` 必须是 0 
- 采样步骤比较少，只有4步


### 2-2 Guidance-distilled

```python
import torch
from diffusers import FluxPipeline

pipe = FluxPipeline.from_pretrained("black-forest-labs/FLUX.1-dev", torch_dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()

prompt = "a tiny astronaut hatching from an egg on the moon"
out = pipe(
    prompt=prompt,
    guidance_scale=3.5,
    height=768,
    width=1360,
    num_inference_steps=50,
).images[0]
out.save("image.png")

```


- 没有 `max_sequence_length` 的限制
- 引导比例: 可以使用非零的 guidance_scale（示例中是 3.5）
- 需要更多步骤（示例中是 50 步）以获得高质量生成

## refer

- [origin blog.post](https://blackforestlabs.ai/announcing-black-forest-labs/)
- [diffusers-flux](https://huggingface.co/docs/diffusers/v0.31.0/en/api/pipelines/flux#flux)

