

## 1-介绍

使用社区能力中自带的缓存的能力.


### 1-1 基本使用

**测试非流式输出:**

```python
if __name__ == "__main__":  
    # 定义测试消息  
    messages = [  
        SystemMessage("你是一个诗人，写一个 100 的诗文，以下面的输入为主题"),  
        HumanMessage("春天"),  
    ]  
  
    # 测试不带缓存的版本  
    print("测试不带缓存的版本:")  
    start_time = time.time()  
    llm_model = model_manager.get_model("qwen-max")  
    for _ in range(5):  
        result = llm_model.invoke(messages)  
    end_time = time.time()  
    print(f"无缓存版本 (5次调用) 耗时: {end_time - start_time:.4f} 秒")  
    print(f"最后一次结果: {result}")  
  
    # 启用缓存  
    print("\n设置缓存...")  
    set_llm_cache(InMemoryCache())  
  
    # 测试带缓存的版本  
    print("测试带缓存的版本:")  
    start_time = time.time()  
    llm_model = model_manager.get_model("qwen-max")  
    for _ in range(5):  
        result = llm_model.invoke(messages)  
    end_time = time.time()  
    print(f"有缓存版本 (5次调用) 耗时: {end_time - start_time:.4f} 秒")  
    print(f"最后一次结果: {result}")
```



```
测试不带缓存的版本:
无缓存版本 (5次调用) 耗时: 2.7098 秒
最后一次结果: content='春风轻拂绿柳枝，万物复苏展新姿。\n桃花笑颜迎蜂蝶，樱花纷飞似雪时。\n草长莺飞满眼见，溪水潺潺洗冬疲。\n春色满园关不住，一曲鸣莺报佳期。' additional_kwargs={'refusal': None} response_metadata={'token_usage': {'completion_tokens': 0, 'prompt_tokens': 0, 'total_tokens': 0, 'completion_tokens_details': None, 'prompt_tokens_details': None}, 'model_name': 'from-cache', 'system_fingerprint': None, 'finish_reason': 'stop', 'logprobs': None} id='run-6f2899dd-8772-428b-bd2c-32d91233174f-0' usage_metadata={'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0, 'input_token_details': {}, 'output_token_details': {}}

设置缓存...
测试带缓存的版本:
有缓存版本 (5次调用) 耗时: 0.0385 秒
最后一次结果: content='春风轻拂绿柳枝，万物复苏展新姿。\n桃花笑颜迎蜂蝶，樱花纷飞似雪时。\n草长莺飞满眼见，溪水潺潺洗冬疲。\n春色满园关不住，一曲鸣莺报佳期。' additional_kwargs={'refusal': None} response_metadata={'token_usage': {'completion_tokens': 0, 'prompt_tokens': 0, 'total_tokens': 0, 'completion_tokens_details': None, 'prompt_tokens_details': None}, 'model_name': 'from-cache', 'system_fingerprint': None, 'finish_reason': 'stop', 'logprobs': None} id='run-11886621-9cd3-4f61-acb7-f7263d76fe83-0' usage_metadata={'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0, 'input_token_details': {}, 'output_token_details': {}}
```

**测试流式输出**

```python
def test_streaming(model, messages, test_name="流式输出测试"):  
    """  
    测试流式输出的性能  
  
    Args:        model: LLM模型实例  
        messages: 发送给模型的消息列表  
        test_name: 测试名称  
  
    Returns:        dict: 测试结果指标  
    """    print(f"\n{test_name}:")  
    start_time = time.time()  
    full_response = ""  
    first_chunk_time = None  
  
    for chunk in model.stream(messages):  
        current_time = time.time()  
        if not full_response and chunk.content:  
            first_chunk_time = current_time  
            print(f"首个内容块耗时: {first_chunk_time - start_time:.4f} 秒")  
  
        chunk_content = str(chunk.content) if chunk.content else ""  
        full_response += chunk_content  
  
    end_time = time.time()  
    total_time = end_time - start_time  
    ttfb = first_chunk_time - start_time if first_chunk_time else None  
    post_ttfb = end_time - first_chunk_time if first_chunk_time else None  
  
    print(f"完整流式输出耗时: {total_time:.4f} 秒")  
    if ttfb:  
        print(f"首字延迟 (TTFB): {ttfb:.4f} 秒")  
        print(f"首字后完成耗时: {post_ttfb:.4f} 秒")  
  
    print(f"总字符数: {len(full_response)}")  
    print(f"平均每秒输出字符数: {len(full_response) / total_time:.2f} 字符/秒")  
    print(f"内容前80字符: {full_response[:80]}...")  
  
    return {  
        "total_time": total_time,  
        "ttfb": ttfb,  
        "post_ttfb": post_ttfb,  
        "char_count": len(full_response),  
        "chars_per_second": len(full_response) / total_time,  
    }
```


```python
if __name__ == "__main__":  
    # 定义测试消息 - 使用固定的随机种子和温度为0，以确保一致的输出  
    # 这样我们可以确保缓存能够命中  
    model_name = "doubao"  # 使用您的模型名称  
  
    stream_messages = [  
        SystemMessage(  
            "你是一个故事作家，写一个详细的短篇故事，以下面的输入为主题。"  
            "要求：\n"  
            "1. 包含生动的场景描述\n"  
            "2. 有丰富的感官细节\n"  
            "3. 有人物对话\n"  
            "4. 有情感变化\n"  
            "5. 有明确的起承转合"  
        ),  
        HumanMessage("夏日的海滩和一次意外相遇"),  
    ]  
  
    # 1. 禁用缓存的测试  
    print("\n============= 无缓存测试 =============")  
    # 确保缓存被禁用  
    set_llm_cache(None)  
  
    # 获取模型并设置参数  
    llm_model = model_manager.get_model(model_name)  
  
    # 第一次运行 - 无缓存  
    no_cache_results = test_streaming(llm_model, stream_messages, "无缓存流式输出测试")  
  
    # 2. 启用缓存测试  
    print("\n============= 有缓存测试 =============")  
    # 启用缓存  
    print("设置 LLM 缓存...")  
    set_llm_cache(InMemoryCache())  
  
    # 第一次运行 - 填充缓存  
    print("\n首次运行 (填充缓存):")  
    cache_filling_results = test_streaming(  
        llm_model, stream_messages, "缓存填充流式输出测试"  
    )  
  
    # 第二次运行 - 应该使用缓存  
    print("\n第二次运行 (应命中缓存):")  
    cached_results = test_streaming(llm_model, stream_messages, "缓存命中流式输出测试")  
  
    # 3. 结果对比  
    print("\n============= 性能对比 =============")  
    print(f"无缓存首字延迟 (TTFB): {no_cache_results['ttfb']:.4f} 秒")  
    print(f"填充缓存首字延迟 (TTFB): {cache_filling_results['ttfb']:.4f} 秒")  
    print(f"缓存命中首字延迟 (TTFB): {cached_results['ttfb']:.4f} 秒")  
  
    if cached_results["ttfb"] > 0 and no_cache_results["ttfb"] > 0:  
        print(  
            f"首字延迟加速比 (无缓存 vs 有缓存): {no_cache_results['ttfb'] / cached_results['ttfb']:.2f}x"  
        )  
  
    print(f"\n无缓存总耗时: {no_cache_results['total_time']:.4f} 秒")  
    print(f"填充缓存总耗时: {cache_filling_results['total_time']:.4f} 秒")  
    print(f"缓存命中总耗时: {cached_results['total_time']:.4f} 秒")  
  
    if cached_results["total_time"] > 0 and no_cache_results["total_time"] > 0:  
        print(  
            f"总耗时加速比 (无缓存 vs 有缓存): {no_cache_results['total_time'] / cached_results['total_time']:.2f}x"  
        )
```


### 1-2 流式的基本原理

```python
# 这段代码不在您分享的源文件中，而是 LangChain 内部实现的一部分
async def _astream_with_cache(
    self, input: dict, cache: BaseCache, llm_string: str
) -> AsyncIterator[ChatGenerationChunk]:
    # 检查缓存
    prompt = self._convert_input_to_cache_key(input)
    cached_generations = await cache.alookup(prompt, llm_string)
    
    if cached_generations is not None:
        # 如果找到缓存，以块的形式返回缓存的结果
        # 模拟流式输出的行为
        for generation in cached_generations:
            yield ChatGenerationChunk(message=generation.message)
    else:
        # 如果未找到缓存，执行实际的流式调用
        generations: List[Generation] = []
        async for chunk in self._astream(input):
            generations.append(chunk)  # 收集所有块
            yield chunk
        
        # 更新缓存
        await cache.aupdate(prompt, llm_string, generations)
```

流式输出的关键区别:
- 缓存命中时：模拟流式输出，将缓存的完整响应拆分成块依次返回
- 缓存未命中时：执行实际的流式调用，同时收集生成的块，最后更新缓存
- 这就解释了为什么即使在缓存命中的情况下，流式输出的总时间仍可能较长 - `LangChain` 会模拟流式行为，而不是立即返回完整结果。


## 2-基本源码分析

**1)-`langChain` 定义了一个核心缓存接口，放在 `langchain_core/caches.py` 文件中.**

```python
class BaseCache(ABC):
    """缓存接口，包含以下方法：
    - lookup: 根据提示和llm_string查找值
    - update: 根据提示和llm_string更新缓存
    - clear: 清除缓存
    """
    
    @abstractmethod
    def lookup(self, prompt: str, llm_string: str) -> Optional[RETURN_VAL_TYPE]:
        """根据prompt和llm_string查找缓存"""
        
    @abstractmethod
    def update(self, prompt: str, llm_string: str, return_val: RETURN_VAL_TYPE) -> None:
        """根据prompt和llm_string更新缓存"""
        
    @abstractmethod
    def clear(self, **kwargs: Any) -> None:
        """清除缓存"""
```

**2)-最常用的实现是 `InMemoryCache`**

```python
class InMemoryCache(BaseCache):
    """存储在内存中的缓存"""
    
    def __init__(self) -> None:
        """初始化空缓存"""
        self._cache: Dict[Tuple[str, str], RETURN_VAL_TYPE] = {}
        
    def lookup(self, prompt: str, llm_string: str) -> Optional[RETURN_VAL_TYPE]:
        """查找缓存"""
        return self._cache.get((prompt, llm_string), None)
        
    def update(self, prompt: str, llm_string: str, return_val: RETURN_VAL_TYPE) -> None:
        """更新缓存"""
        self._cache[(prompt, llm_string)] = return_val
        
    def clear(self, **kwargs: Any) -> None:
        """清除缓存"""
        self._cache = {}
```

**3)-缓存键的构造**

- 缓存的键是一个二元组: (`prompt`, `llm_string`) ;
- `llm_string`: 模型配置的字符串表示, 包含模型名称和所有参数, 例如: `temperature`, `top_p` 等 ;

`llm_string` 是通过将模型参数转换为有序的参数字符串来生成的.

```python
llm_string = str(sorted(params.items())
```

这确保了相同的模型配置总是产生相同的字符串表示


**4)-生成的过程中如何使用缓存**

在 _generate_with_cache 方法中（位于 language_models/chat_models.py），缓存的使用流程如下：

```python
def _generate_with_cache(self, messages, stop=None, run_manager=None, **kwargs):
    # 1. 获取缓存实例
    llm_cache = self.cache if isinstance(self.cache, BaseCache) else get_llm_cache()
    check_cache = self.cache or self.cache is None
    
    # 2. 如果启用了缓存，尝试查找缓存
    if check_cache and llm_cache:
        llm_string = self._get_llm_string(stop=stop, **kwargs)
        prompt = dumps(messages)  # 序列化消息为字符串
        cache_val = llm_cache.lookup(prompt, llm_string)
        if isinstance(cache_val, list):
            # 缓存命中，直接返回缓存的结果
            return ChatResult(generations=cache_val)
    
    # 3. 缓存未命中，执行实际的生成
    result = self._generate(messages, stop=stop, **kwargs)
    
    # 4. 更新缓存
    if check_cache and llm_cache:
        llm_cache.update(prompt, llm_string, result.generations)
    
    return result
```

**5)-缓存的设置和获取**

```python
def set_llm_cache(value: Optional["BaseCache"]) -> None:
    """设置全局LLM缓存"""
    global _llm_cache
    _llm_cache = value

def get_llm_cache() -> "BaseCache":
    """获取全局LLM缓存"""
    global _llm_cache
    return _llm_cache
```

**6)-缓存解析逻辑**

- `_resolve_cache` 函数用于解析缓存参数.

```python
def _resolve_cache(cache: Union[BaseCache, bool, None]) -> Optional[BaseCache]:
    """解析缓存参数"""
    if isinstance(cache, BaseCache):
        # 直接使用传入的缓存对象
        llm_cache = cache
    elif cache is None:
        # 使用全局缓存
        llm_cache = get_llm_cache()
    elif cache is True:
        # 使用全局缓存，如果全局缓存未设置则报错
        llm_cache = get_llm_cache()
        if llm_cache is None:
            raise ValueError("未配置全局缓存")
    elif cache is False:
        # 显式禁用缓存
        llm_cache = None
    else:
        raise ValueError(f"不支持的缓存值 {cache}")
    return llm_cache
```

1. 缓存命中流程：
	- 构造 prompt (序列化的消息) 和 llm_string (序列化的参数)
	- 查找缓存 llm_cache.lookup(prompt, llm_string)
	- 如果找到，直接返回缓存结果
	- 如果未找到，执行API调用，然后更新缓存
2. 缓存内容：
	- 缓存存储的是生成结果 (`generations`)，通常是 List[Generation] 类型
	- 每个 `Generation` 包含生成的消息和元数据

## Refer

- [homepage](https://python.langchain.com/docs/integrations/llm_caching/)