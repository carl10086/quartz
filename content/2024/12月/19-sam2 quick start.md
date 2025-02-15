
## 1-intro

`SAM2` 是一个基础模型, 用来解决视觉分割任务. 直接支持 图像和 **视频**, 并且把 图像理解为单帧视频来处理.

模型本身采取了 `transformer` 架构，并且配置了 流式内存 来实现实时视频的处理.


> [!NOTE] Tips
> 最新的版本支持了 `torch.compile` 提前编译的能力, 可以通过 `vos_optimized=True` 参数设置, 可以极大的提高 推理性能


## 2-Install

最新的版本一般都需要手动 安装.

```shell
git clone https://github.com/facebookresearch/sam2.git && cd sam2
pip install -e .
```

## 3-auto mask


```python
import numpy as np
import torch

from sam2.automatic_mask_generator import SAM2AutomaticMaskGenerator
from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor

from base import image_utils


import matplotlib.pyplot as plt


def show_anns(anns, borders=True):
    if len(anns) == 0:
        return
    sorted_anns = sorted(anns, key=(lambda x: x['area']), reverse=True)
    ax = plt.gca()
    ax.set_autoscale_on(False)

    img = np.ones((sorted_anns[0]['segmentation'].shape[0], sorted_anns[0]['segmentation'].shape[1], 4))
    img[:, :, 3] = 0
    for ann in sorted_anns:
        m = ann['segmentation']
        color_mask = np.concatenate([np.random.random(3), [0.5]])
        img[m] = color_mask
        if borders:
            import cv2
            contours, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            contours = [cv2.approxPolyDP(contour, epsilon=0.01, closed=True) for contour in contours]
            cv2.drawContours(img, contours, -1, (0, 0, 1, 0.4), thickness=1)

    ax.imshow(img)  # 确保调用 imshow
    plt.draw()  # 强制绘制


checkpoint = "/home/carl/storage/sam2/sam2.1_hiera_large.pt"
model_cfg = "configs/sam2.1/sam2.1_hiera_l.yaml"
predictor = SAM2ImagePredictor(build_sam2(model_cfg, checkpoint))

i1 = image_utils.load_image("/home/carl/storage/images/cat01.jpg")
image_utils.show_image(i1)

sam2 = build_sam2(model_cfg, checkpoint, device='cuda', apply_postprocessing=False)
# mask_generator = SAM2AutomaticMaskGenerator(sam2)
mask_generator = SAM2AutomaticMaskGenerator(
    model=sam2,
    points_per_side=64,
    points_per_batch=128,
    pred_iou_thresh=0.7,
    stability_score_thresh=0.92,
    stability_score_offset=0.7,
    crop_n_layers=1,
    box_nms_thresh=0.7,
    crop_n_points_downscale_factor=2,
    min_mask_region_area=25.0,
    use_m2m=True,
)
image = np.array(i1.convert("RGB"))
masks = mask_generator.generate(image)

# 显示部分
plt.figure(figsize=(20, 20))
plt.imshow(image)
show_anns(masks)
plt.axis('off')
plt.draw()    # 添加强制绘制
plt.show(block=True)  # 添加 block=True
```

提取全部掩码的 `demo`

## refer

- [read-me](https://github.com/facebookresearch/sam2?tab=readme-ov-file)
- [demo](https://github.com/facebookresearch/sam2/blob/main/notebooks/image_predictor_example.ipynb)
- [SA-V Dataset](https://ai.meta.com/datasets/segment-anything-video/)