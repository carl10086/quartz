
## 1-概述

理解  `comfyui` 加载源码的思路，实现能显示控制 `model` `device` 


## 2-模型加载

```python
def load_checkpoint_guess_config(ckpt_path, output_vae=True, output_clip=True, 
                               output_clipvision=False, embedding_directory=None, 
                               output_model=True, model_options={}, te_model_options={}):
    """从检查点文件加载模型并自动推测配置。

    该函数通过加载检查点文件，自动检测模型类型并返回相应的模型组件。

    Args:
        ckpt_path (str): 检查点文件的路径
        output_vae (bool, optional): 是否输出VAE模型。默认为True
        output_clip (bool, optional): 是否输出CLIP模型。默认为True
        output_clipvision (bool, optional): 是否输出CLIPVision模型。默认为False
        embedding_directory (str, optional): embedding文件目录路径。默认为None
        output_model (bool, optional): 是否输出主模型。默认为True
        model_options (dict, optional): 模型配置选项。默认为空字典
        te_model_options (dict, optional): 文本编码器模型配置选项。默认为空字典

    Returns:
        tuple: 包含以下组件的元组 (model_patcher, clip, vae, clipvision)

    Raises:
        RuntimeError: 当无法检测模型类型时抛出异常
    """
    sd = comfy.utils.load_torch_file(ckpt_path)
    out = load_state_dict_guess_config(sd, output_vae, output_clip, output_clipvision, 
                                     embedding_directory, output_model, model_options, 
                                     te_model_options=te_model_options)
    if out is None:
        raise RuntimeError("ERROR: Could not detect model type of: {}".format(ckpt_path))
    return out


def load_state_dict_guess_config(sd, output_vae=True, output_clip=True, 
                                output_clipvision=False, embedding_directory=None, 
                                output_model=True, model_options={}, te_model_options={}):
    """从状态字典加载模型并推测配置。

    该函数处理模型的状态字典，根据配置加载不同的模型组件（如VAE、CLIP等）。

    Args:
        sd (dict): 模型的状态字典
        output_vae (bool, optional): 是否输出VAE模型。默认为True
        output_clip (bool, optional): 是否输出CLIP模型。默认为True
        output_clipvision (bool, optional): 是否输出CLIPVision模型。默认为False
        embedding_directory (str, optional): embedding文件目录路径。默认为None
        output_model (bool, optional): 是否输出主模型。默认为True
        model_options (dict, optional): 模型配置选项。默认为空字典
        te_model_options (dict, optional): 文本编码器模型配置选项。默认为空字典

    Returns:
        tuple or None: 如果成功则返回包含 (model_patcher, clip, vae, clipvision) 的元组，
                      如果模型配置检测失败则返回None

    Notes:
        - 函数会自动检测和设置模型的数据类型(dtype)
        - 支持模型直接加载到GPU
        - 对于CLIP模型缺失的权重会进行警告提示
        - 会记录未使用的状态字典键值
    """
    # 初始化返回值
    clip = None
    clipvision = None
    vae = None
    model = None
    model_patcher = None

    # 检测模型配置和参数
    diffusion_model_prefix = model_detection.unet_prefix_from_state_dict(sd)
    parameters = comfy.utils.calculate_parameters(sd, diffusion_model_prefix)
    weight_dtype = comfy.utils.weight_dtype(sd, diffusion_model_prefix)
    load_device = model_management.get_torch_device()

    # 获取模型配置
    model_config = model_detection.model_config_from_unet(sd, diffusion_model_prefix)
    if model_config is None:
        return None

    # 设置模型数据类型
    unet_weight_dtype = list(model_config.supported_inference_dtypes)
    if weight_dtype is not None and model_config.scaled_fp8 is None:
        unet_weight_dtype.append(weight_dtype)

    model_config.custom_operations = model_options.get("custom_operations", None)
    unet_dtype = model_options.get("dtype", model_options.get("weight_dtype", None))

    if unet_dtype is None:
        unet_dtype = model_management.unet_dtype(model_params=parameters, 
                                               supported_dtypes=unet_weight_dtype)

    manual_cast_dtype = model_management.unet_manual_cast(unet_dtype, load_device, 
                                                        model_config.supported_inference_dtypes)
    model_config.set_inference_dtype(unet_dtype, manual_cast_dtype)

    # 加载CLIPVision模型
    if model_config.clip_vision_prefix is not None and output_clipvision:
        clipvision = clip_vision.load_clipvision_from_sd(sd, model_config.clip_vision_prefix, True)

    # 加载主模型
    if output_model:
        inital_load_device = model_management.unet_inital_load_device(parameters, unet_dtype)
        model = model_config.get_model(sd, diffusion_model_prefix, device=inital_load_device)
        model.load_model_weights(sd, diffusion_model_prefix)

    # 加载VAE模型
    if output_vae:
        vae_sd = comfy.utils.state_dict_prefix_replace(sd, 
                    {k: "" for k in model_config.vae_key_prefix}, filter_keys=True)
        vae_sd = model_config.process_vae_state_dict(vae_sd)
        vae = VAE(sd=vae_sd)

    # 加载CLIP模型
    if output_clip:
        clip_target = model_config.clip_target(state_dict=sd)
        if clip_target is not None:
            clip_sd = model_config.process_clip_state_dict(sd)
            if len(clip_sd) > 0:
                parameters = comfy.utils.calculate_parameters(clip_sd)
                clip = CLIP(clip_target, embedding_directory=embedding_directory, 
                          tokenizer_data=clip_sd, parameters=parameters, 
                          model_options=te_model_options)
                m, u = clip.load_sd(clip_sd, full_model=True)
                # 检查并记录缺失的权重
                if len(m) > 0:
                    m_filter = list(filter(lambda a: ".logit_scale" not in a and 
                                  ".transformer.text_projection.weight" not in a, m))
                    if len(m_filter) > 0:
                        logging.warning("clip missing: {}".format(m))
                    else:
                        logging.debug("clip missing: {}".format(m))

                if len(u) > 0:
                    logging.debug("clip unexpected {}:".format(u))
            else:
                logging.warning("no CLIP/text encoder weights in checkpoint, "
                              "the text encoder model will not be loaded.")

    # 记录未使用的状态字典键
    left_over = sd.keys()
    if len(left_over) > 0:
        logging.debug("left over keys: {}".format(left_over))

    # 处理模型加载到GPU
    if output_model:
        model_patcher = comfy.model_patcher.ModelPatcher(model, load_device=load_device, 
                                    offload_device=model_management.unet_offload_device())
        if inital_load_device != torch.device("cpu"):
            logging.info("loaded straight to GPU")
            model_management.load_models_gpu([model_patcher], force_full_load=True)

    return (model_patcher, clip, vae, clipvision)

```


## 3-设备切换

`comfyui` 提供了一个 模型加载的类.

```python
"""
LoadedModel类 - 模型加载管理器

该类负责管理模型在不同设备（CPU/GPU）间的加载、卸载和内存管理。
主要用于实现动态显存管理，支持模型在CPU和GPU之间的灵活切换。

关键功能：
1. 模型加载到GPU
2. 模型卸载到CPU
3. 部分加载/卸载支持
4. 内存使用跟踪
"""

class LoadedModel:
    def __init__(self, model):
        """
        初始化模型加载管理器
        
        Args:
            model: 要管理的模型实例
        """
        self._set_model(model)
        self.device = model.load_device  # 目标设备（通常是GPU）
        self.real_model = None          # 实际加载的模型引用
        self.currently_used = True      # 模型使用状态标志
        # 使用弱引用来管理模型生命周期
        self.model_finalizer = None     # 模型清理器
        self._patcher_finalizer = None  # 补丁清理器

    def model_unload(self, memory_to_free=None, unpatch_weights=True):
        """
        将模型从GPU卸载到CPU
        
        Args:
            memory_to_free: 需要释放的显存大小，如果为None则完全卸载
            unpatch_weights: 是否需要解除权重补丁
            
        Returns:
            bool: 是否完全卸载
        """
        # 部分卸载：如果指定了memory_to_free且小于当前加载的大小
        if memory_to_free is not None:
            if memory_to_free < self.model.loaded_size():
                # 尝试部分卸载到offload_device（通常是CPU）
                freed = self.model.partially_unload(self.model.offload_device, 
                                                  memory_to_free)
                if freed >= memory_to_free:
                    return False  # 部分卸载成功

        # 完全卸载
        self.model.detach(unpatch_weights)  # 解除模型与当前设备的绑定
        self.model_finalizer.detach()       # 解除终结器
        self.model_finalizer = None
        self.real_model = None
        return True

    def model_load(self, lowvram_model_memory=0, force_patch_weights=False):
        """
        将模型加载到GPU
        
        Args:
            lowvram_model_memory: 低显存模式下的内存限制
            force_patch_weights: 是否强制使用权重补丁
            
        Returns:
            模型实例
        """
        # 将模型补丁移动到目标设备
        self.model.model_patches_to(self.device)
        self.model.model_patches_to(self.model.model_dtype())

        # 处理显存使用
        use_more_vram = lowvram_model_memory if lowvram_model_memory > 0 else 1e32
        self.model_use_more_vram(use_more_vram, force_patch_weights=force_patch_weights)
        
        real_model = self.model.model
        self.real_model = weakref.ref(real_model)
        # 设置模型清理器
        self.model_finalizer = weakref.finalize(real_model, cleanup_models)
        return real_model

    def model_use_more_vram(self, extra_memory, force_patch_weights=False):
        """
        增加模型在GPU上使用的显存
        
        Args:
            extra_memory: 额外需要的显存大小
            force_patch_weights: 是否强制使用权重补丁
        """
        return self.model.partially_load(self.device, extra_memory, 
                                       force_patch_weights=force_patch_weights)

```


我们基于这个源码封装了工具类.

```python
from base import gpu_utils
from comfy import model_management
import torch

from comfy.model_management import LoadedModel
def model_unload(lm: LoadedModel):
    lm.model_unload(memory_to_free=None, unpatch_weights=True)


def model_load_gpu(model) -> LoadedModel:
    lm = LoadedModel(model)
    lm.model_load()
    return lm
```


测试模型可以成功装载，卸载.

```python
import torch

from base import agent_comfy_utils, gpu_utils
from base.agent_comfy_utils import gpu_free_bytes
from comfy.sd import load_checkpoint_guess_config

CHECKPOINT_PATH = "/home/carl/models/checkpoints/sd_xl_base_1.0.safetensors"

if __name__ == '__main__':
    agent_comfy_utils.hack_comfy()
    model_patcher, clip, vae, clipvision = load_checkpoint_guess_config(ckpt_path=CHECKPOINT_PATH)
    print(f"models load to cpu ok:{gpu_free_bytes()}")
    load_unet = agent_comfy_utils.model_load_gpu(model_patcher)
    print(f"models load to gpu ok: {gpu_free_bytes()}")
    agent_comfy_utils.model_unload(load_unet)
    gpu_utils.force_empty_cache_for_gpu("cuda")
    print(f"models offload to cpu ok: {gpu_free_bytes()}")
    # 5. 清空CUDA缓存
```

输出结果如下:

```
models load to cpu ok:23695.94 MB
models load to gpu ok: 18519.94 MB
models offload to cpu ok: 23695.94 MB
```

- 成功的装载和卸载了 `gpu`

而 `vae` 比较小，切换也不适合上面的逻辑.