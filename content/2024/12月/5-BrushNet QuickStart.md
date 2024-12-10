
## 1-Intro

`BrushNet` 是一个图像的修复模型. 

1. 基于扩散模型
2. 支持文本引导
3. 即插即用

**分离掩码的特征和噪音的空间, 伪代码如下:**

```python
    def feature_separation(self, masked_image, mask):
        """
        特征分离机制：将掩码图像特征和噪声潜在空间分离
        """
        # 1. 提取掩码区域的图像特征
        masked_features = self.feature_extractor(masked_image)
        
        # 2. 分离特征
        valid_region = masked_features * (1 - mask)  # 保留非掩码区域
        masked_region = masked_features * mask       # 掩码区域
        
        # 3. 独立处理两个区域的特征
        processed_features = {
            'valid': self.process_valid_features(valid_region),
            'masked': self.process_masked_features(masked_region)
        }
        
        return processed_features
```


**通过像素级别的精细控制来提升效果**

## refer

- [BrushNet](https://github.com/TencentARC/BrushNet)
- [Model Downloads](https://drive.google.com/drive/folders/1fqmS1CEOvXCxNWFrsSYd_jHYXxrydh1n)
- [BrushNet-ComfyUi](https://github.com/nullquant/ComfyUI-BrushNet)