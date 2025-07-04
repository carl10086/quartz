
## 1-Intro

语音检测任务上一个不错的开源模型.

1. 准确: https://github.com/snakers4/silero-vad/wiki/Quality-Metrics#vs-other-available-solutions
2. 快:
	- 单个 `CPU` 上处理 `30+ms` 的 `chunk` 不到 `1ms`
	- 批处理和`GPU` 可以显著优化性能
	- `ONNX-Runtime` 某些条件下可以优化 `4-5` 倍的性能
3. 小: `JIT` 模型仅仅 `2M`
4. 通用:
	- 在包含 `6000` 种语言的大型语料库上训练
5. `Sampling`: 采样率支持 `8000` 和 `16000`



## 2-Installation

```txt
# requirements.in
torch
torchaudio
onnxruntime
silero-vad
sox
```

注意 如果使用 sox 作为 `torchaudio` 的 `backend`:

```bash
apt install libsox-dev sox
```


```python
import torch
import time
import numpy as np

from silero_vad.utils_vad import OnnxWrapper, read_audio, VADIterator

SAMPLING_RATE = 16000
MODEL_DIR = ""
MODEL_PATH = f"{MODEL_DIR}/silero_vad/silero_vad.onnx"

model = OnnxWrapper(path=MODEL_PATH)

print(f"model: {model} loaded")

wav_path = "yourwav"
wav = read_audio(wav_path,
                 SAMPLING_RATE)
# 打印音频数据信息
print(f"音频形状: {wav.shape}")
print(f"音频类型: {type(wav)}")
print(f"音频设备: {wav.device}")
print(f"音频数据范围: {wav.min().item()} 到 {wav.max().item()}")

# speech_timestamps = get_speech_timestamps(wav, model, SAMPLING_RATE)
# print(f"speech_timestamps: {speech_timestamps}")

# 创建 VAD 迭代器
vad_iterator = VADIterator(model, sampling_rate=SAMPLING_RATE)

# 准备存储结果的列表
speech_probs = []
inference_times = []

# 设置窗口大小
window_size_samples = 512 if SAMPLING_RATE == 16000 else 256

# 处理音频
total_start_time = time.time()

for i in range(0, len(wav), window_size_samples):
    # 提取当前音频块
    chunk = wav[i: i + window_size_samples]

    # 如果块不完整，跳过
    if len(chunk) < window_size_samples:
        break

    # 测量单个块的推理时间
    chunk_start_time = time.time()
    speech_prob = model(chunk, SAMPLING_RATE).item()
    chunk_end_time = time.time()

    # 计算并存储推理时间（毫秒）
    inference_time_ms = (chunk_end_time - chunk_start_time) * 1000
    inference_times.append(inference_time_ms)

    # 存储语音概率
    speech_probs.append(speech_prob)

# 计算总处理时间
total_end_time = time.time()
total_time_ms = (total_end_time - total_start_time) * 1000

# 重置模型状态
vad_iterator.reset_states()

# 打印结果
print(f"语音概率: {speech_probs[:10]}...（共 {len(speech_probs)} 个块）")

# 打印推理时间统计
print("\n推理时间统计（毫秒）:")
print(f"总处理时间: {total_time_ms:.2f} ms")
print(f"平均每块推理时间: {np.mean(inference_times):.2f} ms")
print(f"最小推理时间: {np.min(inference_times):.2f} ms")
print(f"最大推理时间: {np.max(inference_times):.2f} ms")
print(f"中位数推理时间: {np.median(inference_times):.2f} ms")
print(f"标准差: {np.std(inference_times):.2f} ms")

# 打印吞吐量信息
audio_duration_seconds = len(wav) / SAMPLING_RATE
processing_speed = audio_duration_seconds / (total_time_ms / 1000)
print(f"\n音频时长: {audio_duration_seconds:.2f} 秒")
print(f"实时因子: {processing_speed:.2f}x（值 > 1 表示快于实时）")

```


## 3-Model

```python
class VADDecoderRNNJIT(nn.Module):
    """语音活动检测模型，使用LSTM编码器和MLP解码器结构"""

    def __init__(self):
        """初始化模型的各个组件"""
        super(VADDecoderRNNJIT, self).__init__()

        # LSTM单元作为编码器，处理时序信息
        # 输入维度：128，隐藏状态维度：128
        self.rnn = nn.LSTMCell(128, 128)
        
        # 解码器：将LSTM的隐藏状态转换为语音概率
        self.decoder = nn.Sequential(
            nn.Dropout(0.1),      # 随机丢弃10%的神经元输出，防止过拟合
            nn.ReLU(),            # 激活函数，保留正值，将负值置为0
            nn.Conv1d(128, 1, kernel_size=1),  # 1x1卷积，相当于全连接层，将128维压缩为1维
            nn.Sigmoid()          # 将输出压缩到0-1之间，表示语音概率
        )

    def forward(self, x, state=torch.zeros(0)):
        """
        前向传播函数
        
        参数:
            x: 输入特征，预期形状为[批次大小, 特征维度, 1]
            state: 上一时间步的状态，默认为空（首次调用）
            
        返回:
            x: 语音概率，形状为[批次大小, 1, 1]
            state: 更新后的状态，用于下一时间步
        """
        # 移除最后一个维度（如果存在），准备输入LSTM
        x = x.squeeze(-1)
        
        # 根据是否有之前的状态，选择LSTM的调用方式
        if len(state):
            # 使用上一步的状态继续处理（连续音频流的情况）
            h, c = self.rnn(x, (state[0], state[1]))
        else:
            # 首次调用，使用默认初始状态（新音频序列的开始）
            h, c = self.rnn(x)

        # 准备隐藏状态用于解码器
        # 添加最后一个维度并确保是float类型
        x = h.unsqueeze(-1).float()
        
        # 将两个状态（h和c）打包为一个张量，便于返回和后续使用
        state = torch.stack([h, c])
        
        # 将隐藏状态传入解码器，得到语音概率
        x = self.decoder(x)
        
        # 返回语音概率和更新后的状态
        return x, state

```

个人理解 : 这也是一个 编码器-解码器的架构

1. 编码器: `LSTM`, 保留一下 时序特征
2. 解码器: 一个 `Conv1d`, `MLP`
	- `Dropout` : 随机丢掉 10% 的输出特征，防止过度依赖
	- `ReLu`: 非线性能力[保留正, 丢掉负], 梯度更容易传播, 增
	- `1x1` 卷积: 把 128 维压缩为1维， 其实就是一个 `MLP`
	- `Sigmoid`: 最后的输出需要一个 概率

## refer

- [github](https://github.com/snakers4/silero-vad/)