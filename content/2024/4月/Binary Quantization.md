
#blog 


[Binary-Quantization](https://qdrant.tech/articles/binary-quantization/)

## 1-Intro


> 理解 二值量化 


1. 高维的 矢量是非常消耗资源的, 通过减少精确度去量化是常见的方法 ;
2. 二维量化是 比较极端的量化到 `Bool` 类型 ;
3. 高维的时候 量化比较有效, 低维的性能提升不明显，但是精度下降会比较明显 ;

下图来自于 `Qdrant` 官网

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240403133610.png?imageSlim)




> [!NOTE] Tips
> **This binarization function is how we convert a range to binary values. All numbers greater than zero are marked as 1. If it’s zero or less, they become 0.**



> Binary Quantization 是后来的工作 ?

前置的工作是 [scala quantization](https://qdrant.tech/articles/scalar-quantization/), 这个工作是把. `float32` 转为 `uint8` , `CPU` 的 `SIMD` 对 `uint8` 可以更快的进行 `vector comparison`


> 什么是 `Over-parameterized` ?

