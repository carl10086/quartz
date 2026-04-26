# LLM Coding Benchmark (2026年4月) — Rails + RubyLLM 实战评测

> **来源**: [AkitaOnRails - LLM Coding Benchmark (April 2026)](https://akitaonrails.com/en/2026/04/24/llm-benchmarks-parte-3-deepseek-kimi-mimo/)
> **评测日期**: 2026年4月24日
> **评测对象**: 23个 LLM 模型

---

## TL;DR

- **并列第一**: Claude Opus 4.7 和 GPT 5.4 xHigh (Codex) 均达 97/100 Tier A
- **第三名**: GPT 5.5 xHigh — 96/100，质量与 5.4 持平，价格低 40%
- **性价比最优**: Kimi K2.6 ($0.30/run) 和 Gemini 3.1 Pro ($0.40/run) 均为 Tier A
- **本地开源**: 尚未达到 Tier A，最佳为 Qwen 3.5 35B (Tier C, 55/100)
- **重要更正**: 作者重新对照 ruby_llm gem 源码核实，发现多个模型被误判为"发明 API"

---

## 1. 评测方法论

### 1.1 任务设定

每个模型接收相同 Prompt，自主构建一个类 ChatGPT 的 Rails 聊天应用，要求包含 15 项交付物：

| 类别 | 交付物 |
|------|--------|
| 框架 | Rails + 最新 Ruby + Hotwire + Stimulus + Turbo Streams |
| 配置 | mise 管理 Ruby/Rails 版本，OPENROUTINER_API_KEY 通过 env var 注入 |
| 无 | 不使用 ActiveRecord、Action Mailer、Active Job |
| 前端 | SPA 界面 + Tailwind CSS，纯 Rails partials（不用单文件 CSS/JS） |
| 库 | 使用 ruby_llm gem，配置 OpenRouter + Claude Sonnet |
| 测试 | Minitest 覆盖每个组件 |
| 质量 | Brakeman、RuboCop、SimpleCov、bundle-audit |
| 容器 | 可用的 Dockerfile + docker-compose |
| 文档 | README 含完整安装说明 |
| 结构 | 所有文件置于 workspace root（无嵌套子目录） |

### 1.2 8维度评分体系

评测从 1 个维度扩展为 8 个维度：

| 维度 | 权重 | 考核内容 |
|------|------|----------|
| 交付物完整性 | 25% | Dockerfile + compose + README + Gemfile + 所有清单项 |
| RubyLLM API 正确性 | 20% | 调用方式对照 gem 1.14.1 源码验证 |
| 测试质量 | 15% | 测试用正确的 signature mock RubyLLM |
| 错误处理 | 10% | chat.ask 周围有 rescue，返回降级 UI |
| 持久化/多轮对话 | 10% | Session cookie / cache 正常；Singleton / class-var 不合格 |
| Hotwire / Turbo / Stimulus | 10% | 真正的 Turbo Streams，分解的 partials，Stimulus 控制器 |
| 架构 | 5% | Service/model 分离，controller 无逻辑堆积 |
| 生产就绪 | 5% | 多 worker 安全，无 XSS，无提交 .env，CSRF 完整 |

**评分等级**:
- **Tier A** (80+): 可直接发布，或 30 分钟内小修补
- **Tier B** (60-79): 1-2 小时可发布，架构合理，有小缺口
- **Tier C** (40-59): 重大返工，核心 bug 或交付物缺失
- **Tier D** (<40): 放弃，仅供架构参考

### 1.3 评测工具

- Cloud 模型：运行两阶段（build + boot/Docker 验证）
- Local 模型：仅运行第一阶段
- Harness: `codex exec --json`（GPT 5.4/5.5），其余用 `opencode run --agent build --format json`

---

## 2. 最终排名（23个模型）

| 排名 | 模型 | 分数 | 等级 | RubyLLM 正确 | 时间 | 成本/次 |
|------|------|------|------|-------------|------|---------|
| 1 | Claude Opus 4.7 | 97 | A | ✅ | 18m | ~$1.10 |
| 1 | GPT 5.4 xHigh (Codex) | 97 | A | ✅ | 22m | ~$163* |
| 3 | GPT 5.5 xHigh (Codex) | 96 | A | ✅ | 18m | ~$10* |
| 4 | Kimi K2.6 | 87 | A | ✅ | 20m | ~$0.30 |
| 5 | Claude Opus 4.6 | 83 | A | ✅ | 16m | ~$1.10 |
| 6 | Gemini 3.1 Pro | 82 | A | ✅ | 14m | ~$0.40 |
| 7 | Claude Sonnet 4.6 | 78 | B | ✅ | 16m | ~$0.63 |
| 8 | DeepSeek V4 Flash | 78 | B | ✅ | 3m | ~$0.01 |
| 9 | Qwen 3.6 Plus | 71 | B | ✅ | 17m | ~$0.15 |
| 10 | DeepSeek V4 Pro | 69 | B | ✅ | 22m (DNF) | ~$0.50 |
| 10 | Kimi K2.5 | 69 | B | ✅ | 29m | ~$0.10 |
| 12 | Xiaomi MiMo V2.5 Pro | 67 | B | ✅ | 11m | ~$0.14 |
| 13 | GLM 5 | 64 | B | ✅ | 17m | ~$0.11 |
| 14 | Step 3.5 Flash | 56 | C | ⚠️ bypass | 38m | ~$0.02 |
| 15 | Qwen 3.5 35B (local) | 55 | C | ✅ | 28m | free |
| 16 | GLM 4.7 Flash bf16 (local) | 52 | C | ✅ | - | free |
| 17 | GLM 5.1 | 46 | C | ❌ | 22m | subscription |
| 18 | DeepSeek V3.2 | 43 | C | ❌ | 60m | ~$0.07 |
| 19 | MiniMax M2.7 | 41 | C | ❌ | 14m | ~$0.30 |
| 20 | Qwen 3.5 122B (local) | 37 | D | ❌ | 43m | free |
| 21 | Qwen 3 Coder Next (local) | 32 | D | ❌ | 17m | free |
| 22 | Grok 4.2025 | 20 | D | ❌ | 8m | ~$0.60 |
| 23 | GPT OSS 20B (local) | 11 | D | ❌ | failed | free |

> *注：GPT 5.4/5.4 via Codex 的成本是 pay-as-you-go 计价。订阅用户（Plus $20/月或 Pro $200/月）不计额外费用。

---

## 3. 评测标准修正：作者的反思

### 3.1 误判：把真实 API 当成"幻觉"

作者承认了两个关键错误：

**错误 1**: `chat.add_message(role: :user, content: "x")` 被标记为幻觉

- 实际情况：RubyLLM 1.14.1 中 `Chat#add_message(message_or_attributes)` 接受 hash 参数
- Ruby 解析器将 `add_message(role: :user, content: "x")` 解析为 `add_message({role: :user, content: "x"})`，完全有效

**错误 2**: `chat.complete(&block)` 被标记为幻觉

- 实际情况：这是 RubyLLM 1.14.1 中的真实公共方法

**影响**: 多个被标记为 Tier 3 的模型实际使用的是合法 API

### 3.2 误判：RubyLLM 正确不等于交付物完整

即使 API 调用正确，如果缺少 docker-compose、README 是模板、或缺少 bundle-audit，项目仍算未完成。

**排名变动**:
- Kimi K2.6: Tier 3 → **Tier A** (84)
- Kimi K2.5: Tier 3 → **Tier B** (66)
- Gemini 3.1 Pro: Tier 3 → **Tier A** (82)
- DeepSeek V4 Pro: Tier 1 → **Tier B** (66) — 交付物简陋
- MiMo V2.5 Pro: "第一非西方 Tier 1" → **Tier B** (64)
- GLM 5.1: 跌至 **Tier C** (46) — 发明 DSL + 历史丢弃

---

## 4. Tier A 模型分析

### 4.1 共同特征

所有 Tier A 模型都具备以下 4 个要素：

1. **测试 mock 正确的 RubyLLM signature**
   - FakeChat 实现 `with_instructions`、`add_message`、`ask`
   - 测试覆盖正常路径和错误路径
   - WebMock 阻止真实 OpenRouter 调用

2. **chat.ask 周围有 rescue**
   - 捕获 `LlmClient::Error` 或类似类型错误
   - 返回降级 UI 给用户

3. **持久化可跨重启和多 worker 工作**
   - Session cookie（Opus, K2.6）或 Rails.cache + TTL（Gemini, GPT 5.4）
   - 非 Singleton/Class-var

4. **通过 with_instructions 设置系统提示词**

### 4.2 各 Tier A 模型特点

#### Claude Opus 4.7 (97/100)

教科书级代码：

```ruby
chat = @client.chat(model:, provider:)
chat.with_instructions(@system_prompt)
previous_messages.each { |msg| chat.add_message({role: msg.role.to_sym, content: msg.content}) }
response = chat.ask(user_message)
response.content
```

- FakeChat 匹配真实签名
- Session cookie (`to_a`/`from_session`) 多 worker 安全
- rescue `RubyLLM::Error` + `StandardError` → 友好错误气泡

**4.7 行为降级**: 新 tokenizer 多消耗 1x~1.35x tokens，资源优化更激进，Max Plan 消耗更快。代码质量仍是 Tier A，但日常使用中 4.6 更直接高效。

#### Claude Opus 4.6 (83/100)

- 代码正确，但 controller 中 `chat_service.ask` 周围无 rescue
- 瞬时 5xx 变成堆栈跟踪页面
- Service 直接通过 attr_reader 访问 `Chat#messages`，违反 Demeter 原则
- 4.6 是作者的日常首选（行为偏好，非代码偏好）

#### GPT 5.4 xHigh (Codex) (97/100, 并列第一)

```ruby
chat = RubyLLM.chat(model:, provider: :openrouter, assume_model_exists: true)
chat.with_instructions(SYSTEM_PROMPT)
history.each { |m| chat.add_message(role: m.role.to_sym, content: m.content) }
response = chat.ask(prompt)
response.content.to_s.strip
```

唯一具备：
- 显式 API key 预检 (`ensure_api_key!` → `MissingConfigurationError`)
- 区分 HTTP 状态码（503 配置错误，502 运行时错误）
- Rails cache 持久化 + TTL + 上限（24条消息 × 12h）
- 专用 form object (`PromptSubmission`) 分离领域模型
- 10 个测试文件，含 partial render 测试

**弱点**: ~$16/次（pay-as-you-go），是 Opus 的 15 倍

#### GPT 5.5 xHigh (Codex) (96/100, 第三)

| 指标 | GPT 5.4 xHigh | GPT 5.5 xHigh | 差异 |
|------|---------------|---------------|------|
| 分数 | 97/100 | 96/100 | 1分噪音 |
| 用时 | 22m | 18m | 20%更快 |
| 总 tokens | 7.6M | 4.9M | 35%更少 |
| 输出 tokens | 63K | 29K | 54%更少 |
| 成本 | ~$16 | ~$10 | 40%更低 |

- RubyLLM 集成结构与 5.4 完全相同
- 同样具备 DI 注入的 client_factory、真实错误类 rescue、session cookie
- 质量无差异，成本显著降低

**订阅用户注意**: Codex 现已纳入 Plus/Pro/Business/Enterprise 订阅配额，Pro 用户配额是 Plus 的 20 倍。

#### Kimi K2.6 (87/100, Tier A, 性价比最高)

```ruby
chat = RubyLLM.chat
chat.with_instructions(SYSTEM_INSTRUCTION)
historical_messages.each do |msg|
  chat.add_message(role: msg[:role], content: msg[:content])
end
response = chat.ask(user_message)
response.content
```

- 唯一进入 Tier A 的非西方模型
- FakeChat 匹配真实 API
- rescue `RubyLLM::Error` + turbo_stream flash
- Session cookie，MAX_MESSAGES = 50 上限
- 完整 Gemfile，多 worker 安全

**唯一扣分点**: 每次 turn 完整重放历史（比 MiMo 的持久化模式用更多 tokens）

**成本**: $0.30/次，是 Opus 的 3.6× 便宜

#### Gemini 3.1 Pro (82/100)

- 真正的 Turbo Streams（非 fetch + innerHTML）
- Rails.cache 持久化 + 2h 过期
- FakeChat mocks 匹配真实 API
- 测试覆盖错误路径

**弱点**: 模型字符串用 `claude-3.7-sonnet` 而非当前 Sonnet 4.x，一字符之差

**成本**: $0.40/次

---

## 5. Tier B 模型分析

### 5.1 Claude Sonnet 4.6 (78/100)

- 整个 benchmark 中 UI 最丰富（多会话侧边栏）
- 致命弱点：`LlmChatService#call` 仅在历史最后一条消息来自用户时才调用 `ask`，否则静默返回 ""
- 测试为此 bug 背书（ rubber-stamp）
- 整个会话塞进 4KB cookie，约 10 轮后溢出

### 5.2 DeepSeek V4 Flash (78/100, $0.01/次)

- 修复了 V3.2 的关键 bug（发明 `RubyLLM::Client` 类）
- API 全部正确（`add_message(role:, content:)` 是合法调用）
- Session-replay 多轮对话 via `session[:messages]`
- WebMock 测试真实 OpenRouter 端点

**坑**: 模型 slug 是 `claude-sonnet-4`，缺少 `anthropic/` 前缀，运行时 OpenRouter 404。单个字符修复，但部署时致命。

### 5.3 DeepSeek V4 Pro (69/100, DNF)

RubyLLM 代码是 Tier A 质量：

```ruby
def initialize
  @chat = RubyLLM.chat
  @messages = []
end
def ask(content)
  result = @chat.ask(content)
  @messages << Message.new(role: "user", content: content)
  @messages << Message.new(role: "assistant", content: result.content)
end
```

- 持久化 `@chat` 实例，委托多轮对话给 RubyLLM，正确模式

**但 DNF**: thinking mode 不兼容。DeepSeek V4 Pro 默认使用 thinking mode，返回 `reasoning_content`。后续 turn 要求客户端回显该 content，Opencode 不支持。尝试 `reasoning: false` 后仍 DNF。

**交付物简陋**: 库存 README 模板，无 docker-compose.yml，缺少 bundle-audit。

**规律**: DeepSeek 每一代 RubyLLM 代码都比上一代好，但工具支持总是滞后。

### 5.4 Kimi K2.5 (69/100)

- 37 个测试（benchmark 最多），但从不 mock RubyLLM
- 只测试 PORO CRUD 和 `respond_to?`
- 覆盖率高但无意义
- 使用 class-var 存储（`Chat.storage = @storage ||= {}`），比 Singleton 更差（无 mutex）

### 5.5 Xiaomi MiMo V2.5 Pro (67/100)

RubyLLM 代码最 idiomatic：

```ruby
@llm_chat = RubyLLM::Chat.new(model: MODEL, provider: PROVIDER)
response = @llm_chat.ask(content, &)
@messages << { role: :assistant, content: response.content }
```

- `Chat.new(model:, provider:)` 是合法公共构造器
- `.ask(content, &)` 转发 streaming block
- 零手动 `add_message` 调用，多轮委托给 RubyLLM 本身

**四个致命缺口**:

| 缺口 | 问题 |
|------|------|
| 测试 | 21 个测试只检查常量和 blank guards，无 LLM 路径测试 |
| 错误处理 | `@chat.ask` 无 rescue，限流变 500 + 堆栈跟踪 |
| 持久化 | ChatStore Singleton，进程本地，Puma 重启后死亡，不支持 WEB_CONCURRENCY > 1 |
| 系统提示 | 无 `with_instructions`，模型不知道自己的角色 |

**评价**: 绿色field 单 worker 原型，代码更少但功能相同。$0.14/次，11分钟，是 Opus 的 8× 便宜。扔掉原型时值得；生产环境需 ~2 小时添加 rescue + Rails.cache + FakeChat + WebMock + 系统提示，此时 Opus 反倒更便宜。

### 5.6 Qwen 3.6 Plus (71/100)

- 正确 RubyLLM API
- 构造良好的 Stimulus 控制器
- 测试对 OpenRouter 发真实请求（无 WebMock）
- 历史仅客户端 JS，刷新后丢失
- 用 fetch + innerHTML 而非 Turbo Streams

### 5.7 GLM 5 (64/100)

- `RubyLLM.chat(model: "anthropic/claude-sonnet-4")` + `chat.ask` + `response.content` 正确
- Mocha stubs 匹配真实 API
- 一个正常路径测试，无错误路径覆盖

**致命弱点**: 零多轮状态。每次 POST 新建 `RubyLLM.chat`，无历史。"我刚才说了什么？" → "我不知道。"

---

## 6. Tier C/D 模型分析

### 6.1 GLM 5.1 (46/100, Tier C)

- `RubyLLM.chat(model:, provider:)` 正确
- 但历史通过 `c.user(msg)` / `c.assistant(msg)` 回放——这 DSL **不存在**于 RubyLLM（grep 确认）
- 更糟：每次 HTTP 请求构造新的 `ChatSession.new`，丢弃历史
- Stimulus 控制器用 fetch + 手动 innerHTML，SSE 但非 Turbo Streams

### 6.2 DeepSeek V3.2 (43/100, Tier C)

- 发明 `RubyLLM::Client.new` 和 `client.chat(messages: [...])`
- 测试 mock 的类根本不存在

### 6.3 MiniMax M2.7 (41/100, Tier C)

- 发明 `RubyLLM.chat(model:, messages: [...])` 批处理签名
- 首次调用即崩溃

### 6.4 Step 3.5 Flash (56/100, Tier C)

- 完全绕过 ruby_llm，用原始 `Net::HTTP`
- 不符合 prompt 要求

### 6.5 Qwen 家族（Tier D）

| 模型 | 问题 |
|------|------|
| Qwen 3.5 122B local | 用 `Openrouter::Client`（错误大小写），调用 gem 未暴露的方法 |
| Qwen 3 Coder Next | 发明 `RubyLLM::Client.new` + `client.chat(messages:)` + OpenAI 风格响应 |

### 6.6 Grok 4.2025 (20/100, Tier D)

- `ruby-openai` 在 `:development, :test` 组，`require: false`
- 生产环境 `NameError`
- Stimulus JS 无法编译

### 6.7 GPT OSS 20B (11/100, Tier D)

- 无 tests 文件夹
- 嵌套 `app/app/` 目录
- 发明 `RubyLLM::Client.new`

---

## 7. 未完成 benchmark 的模型

| 模型 | 问题 | 根因 |
|------|------|------|
| Gemma 4 31B (llama.cpp) | ~11步后无限工具调用循环 | llama.cpp bug #21375，部分修复于 b8665 |
| Gemma 4 31B (Ollama Cloud) | ~20K tokens 时 504 超时 | Cloudflare 100s edge 超时；benchmark 传 50K+ tokens |
| Llama 4 Scout (local) | 工具调用以纯文本发出 | llama.cpp 无 Llama 4 pythonic 格式解析器（vLLM 有） |
| Qwen 3 32B (local) | 太慢（7.3 tok/s） | 硬件瓶颈（VRAM 装得下，但带宽跟不上） |
| Qwen 2.5 Coder 32B (local) | 90分钟超时，零文件 | 无限推理循环，不调用写工具 |
| GPT 5.4 Pro (OpenRouter) | 工具调用后卡住 | OpenRouter 工具调用集成对 GPT 损坏；用 Codex CLI |

**教训**: 2026年运行本地开源模型，一半挑战在工具链。llama.cpp bugs、Ollama 生命周期、工具调用解析器缺失、Ollama Cloud Cloudflare 超时。

---

## 8. 中国 LLM 现状

### 8.1 分布概览

| 等级 | 模型 |
|------|------|
| Tier A (80+) | 仅 Kimi K2.6 (87) |
| Tier B (60-79) | Kimi K2.5 (69), DeepSeek V4 Pro (69), DeepSeek V4 Flash (78), Xiaomi MiMo V2.5 Pro (67), Qwen 3.6 Plus (71), GLM 5 (64) |
| Tier C (40-59) | Step 3.5 Flash (56), GLM 4.7 Flash local (52), GLM 5.1 (46), DeepSeek V3.2 (43), MiniMax M2.7 (41) |
| Tier D (<40) | Qwen 3.5 122B local (37), Qwen 3 Coder Next local (32) |

13个中国模型中仅 1 个达到 Tier A。

### 8.2 各家族模式

| 家族 | 模式 |
|------|------|
| Moonshot (Kimi) | 最有纪律的中国家族。K2.5 Tier B，K2.6 Tier A。在关键维度上真正的代际进化（测试、rescue、持久化）。唯一达到 Tier A 的中国模型。 |
| DeepSeek | 工具支持滞后的模式。每一代 RubyLLM 代码都比上一代好（V3.2 全错 → V4 Flash 正确 → V4 Pro 完美），但开源工具集成总出状况。营销总是强于实际产品。 |
| Xiaomi (MiMo) | 写 benchmark 中最 idiomatic 的 RubyLLM 代码。但缺少真实测试、rescue、健壮持久化。停在原型演示质量，非生产质量。 |
| Alibaba (Qwen) | 高方差。Qwen 3.6 Plus cloud 达 Tier B。Qwen 3.5 35B local Tier C。Qwen 3.5 122B 和"Coder"系列达 Tier D（发明 API 或挂起）。名字带"Coder"不保证 coding agent 能力。 |
| Z.ai (GLM) | GLM 5 合理 Tier B。GLM 5.1 退步到 Tier C（发明 fluent DSL + 历史丢弃）。GLM 4.7 Flash local 很接近但 gem 在错误分组导致生产环境崩溃。 |
| MiniMax / StepFun | 不及格。MiniMax 发明批处理签名，首次调用崩溃。Step 完全绕过 ruby_llm gem。 |

### 8.3 差距量化

**Tier A 对比**:
- Kimi K2.6 vs Opus 4.7: 87 vs 97，差 10 分
- 实际差异：Opus 在次要维度上有额外积累（错误封装测试、model/provider 覆盖、显式系统提示应用），感知差异明显但未分开等级

**成本对比**:
- K2.6 $0.30/次 vs Opus 4.7 $1.10/次，3.6× 更便宜

**中国 Tier B vs Opus 4.6 (83 Tier A)**:
- 差距 5-20 分
- 中国 Tier B 通常 RubyLLM 代码正确或接近正确，但在特定组件失败：
  - 测试质量普遍最弱（写很多测试但不 mock RubyLLM，覆盖率剧场）
  - 持久化常用进程本地 Singleton（MiMo）或 class-var（K2.5）而非 session cookie 或 Rails.cache，重启后死亡，不支持多 worker
  - 错误处理通常缺失，限流变 500 + 堆栈跟踪暴露给用户

---

## 9. 本地开源模型的现实

### 9.1 VRAM + KV Cache：被忽视的数学

以 Qwen3 32B 为例：
- FP16: ~64 GB
- Q4 量化: ~19 GB

看起来能装进 32GB RTX 5090？**错**。这只是模型权重，还缺 KV Cache。

**KV Cache 计算**:
```
KV Memory = 2 × Layers × KV_Heads × Head_Dim × Bytes_per_Element × Context_Tokens
```

对于 Llama 3.1 70B BF16：每 token ~0.31 MB。128K context = **40 GB KV Cache**。

benchmark 运行中模型消耗 39K-156K tokens，<100K context 对 coding agent 不实用。

Google 发表了 TurboQuant (ICLR 2026)，将 KV Cache 压缩到 3 bits 无精度损失，6× 压缩和最高 8× 加速。尚未在 llama.cpp 或 Ollama 中实现。

### 9.2 内存带宽法则

容量不重要，带宽才重要：

| 内存 | 带宽 |
|------|------|
| DDR4 | ~50 GB/s |
| LPDDR5x (AMD Strix) | ~256 GB/s |
| GDDR6 (RTX 3090) | ~936 GB/s |
| GDDR7 (RTX 5090) | ~1,792 GB/s |
| HBM3 (Mac Studio M4 Ultra) | ~800 GB/s |

RTX 5090 带宽是 Minisforum LPDDR5x 的 7×。AMD 上 Qwen3 32B 跑 ~7 tok/s，5090 上会快得多（如果装得下）。

Mac Studio M4 Ultra 512GB 统一内存（~$10k）实用但贵。AMD Ryzen AI Max 256 GB/s 可及但慢。DDR4 桌面不可行。

### 9.3 Ollama vs llama.cpp：各有各的问题

Ollama: 8次本地 benchmark 尝试中失败 6 次（会话中模型卸载、context drift、生命周期不稳定、bf16 损坏）

迁移到 llama-swap (Go wrapper around llama-server)：修复了生命周期但带来其他问题：
- 每个模型需要特定 flag（GLM/Qwen 3.5 需要 `--reasoning-format none` 处理 `<think>` 标签）
- 工具调用解析取决于模型（Llama 4 的 pythonic 格式不解析）
- Gemma 4 需要 build b8665+ 且仍在 ~11 工具调用后进入重复循环

即插即用？不存在的。

### 9.4 Harness 也影响结果

同一 Opus 4.7 模型在 Claude Code 上产出代码比 opencode 差。原因是 harness context 污染：Claude Code 每次运行消耗 6-11M cache-read tokens（vs opencode ~210K），这推动模型倾向于 OpenAI SDK 等通用模式而非 RubyLLM 具体模式。

**结论**: 即使同一模型，调用工具不同，输出也不同。稳定模型测试需在同一 harness 上运行。

---

## 10. 多模型编排：不值得用于 greenfield 编码

### 10.1 测试结果

测试了 7 种组合（跨 3 个 harness），**零次**自愿委托给 subagent。主模型每次都 100% 独立完成，即使 subagent 被声明为"激进语言：PROACTIVELY 使用"和"始终委托给此 agent 实现代码"。

### 10.2 原因

1. **Tier A 模型已在内部 plan-then-execute**
   - Opus 4.7 和 GPT 5.4 xHigh 识别任务需要 planning + implementation，在同一 thought session 内部完成
   - 外部化到两个模型破坏连续 context，无所得

2. **协调成本高**
   - Subagent 收到缩减的 prompt、部分 context，需返回主模型消费的结构化输出
   - 来回添加 tokens、延迟和对齐机会成本
   - 主模型宁愿自己吸收成本

3. **Greenfield 没有清晰的 plan-execute 分界线**
   - Rails 原型从零开始，边做边规划，遇到具体问题修改决策
   - 强行分离不符合工作实际

### 10.3 "Opus plans, Qwen executes" 案例

最差组合：Opus + Qwen 3.6 local。理论（Opus 规划，Qwen 免费执行）失败：
- Opus 没委托，自己干了所有事
- 如果委托了，Qwen 代码会是 Qwen 质量（发明 API，无正确 mocks）
- Opus ↔ Qwen 协调不是免费的

**实用结论**: 如果要付 Opus 规划费，让它做所有事。这是它自然想做的。强制委托给次等模型增加协调成本，结果更差。

### 10.4 多模型有意义的场景

非 cohesive greenfield 任务。适用于 separate pipelines：
- 快分类器过滤输入
- 大模型只处理通过的子集
- 小模型翻译输出

这不是同一 agent session 中"Opus 规划 Qwen 执行"，而是多服务架构不同 API。

**经验法则**: 选一个好的 Tier A 模型，单独用它，优化 prompt 而非编排。

---

## 11. 推荐选择

### 11.1 商业模型

| 类别 | 推荐 | 说明 |
|------|------|------|
| Tier A 高端 | Claude Opus 4.7, GPT 5.4 xHigh (Codex), GPT 5.5 xHigh (Codex), Claude Opus 4.6 | 按行为偏好选择，代码质量都有保障。GPT 5.5 比 5.4 便宜 40% |
| Tier A 性价比 | Kimi K2.6 ($0.30/次), Gemini 3.1 Pro ($0.40/次) | 比 Opus/GPT 便宜 3-4 倍，benchmark 中质量相当 |
| Tier B 可接受 | Claude Sonnet 4.6 ($0.63), DeepSeek V4 Flash ($0.01), Xiaomi MiMo V2.5 Pro ($0.14) | 需 1-2 小时修补才能发布生产 |
| 最低成本有用 | DeepSeek V4 Flash ($0.01/次) | 需修复模型 slug 的 anthropic/ 前缀 |

### 11.2 开源模型（本地）

**无 Tier A**。最佳本地运行是 Qwen 3.5 35B-A3B (Tier C, 55/100)，需 1-2 次纠正 prompt 才能交付可用代码。对于有 RTX 5090 想避免厂商锁定的人，这是要跑的模型，但期望是 hobby/lab 级别，非生产级别。

Qwen 3.6 35B local 最接近可用（差 1 行修复添加 `.content`），但仍无多轮对话。

GLM 4.7 Flash local 最懂 RubyLLM，但 gem 在错误分组导致生产环境 app 崩溃。简单修复，结构性问题。

**2026年本地运行开源模型做 coding agent**：
- 可行但需谨慎
- 需要高端硬件（RTX 5090 或 Mac M4 Ultra）
- 接受每次运行 1-3 次纠正
- 不是 Claude 的替代品

---

## 12. 结论

1. **Opus 4.6 仍是日常首选**：可预测行为、防卫性代码、真实 mocks、合理持久化、错误处理

2. **Opus 4.7 领先 objective benchmark (97/100)**，但有行为降级（更重 tokenizer、激进资源优化）。Benchmark 上表现顶级，日常使用 4.6 更直接

3. **GPT 5.4 xHigh via Codex 并列第一 (97/100)**，GPT 5.5 xHigh 第三 (96/100)：质量与 5.4 持平，40% 更便宜，20% 更快。对于已在 Codex 的用户，5.5 替换 5.4 无回归。价格仍是 Opus 的 10 倍（曾是 15 倍），持续使用仍难合理化

4. **性价比甜区**：Kimi K2.6 ($0.30/次) 或 Gemini 3.1 Pro ($0.40/次)，均为 Tier A，比 Opus 便宜 3-4 倍

5. **本地开源尚未达到 Tier A**：最佳是 Qwen 3.5 35B-A3B (Tier C)，需纠正。实验可用，生产尚不成熟

6. **最大教训**：当开始将模型标记为发现"幻觉"时，直接去库源码核实。作者曾以真实 API 调用丢弃模型。对照 gem 核实后，Kimi、Gemini、DeepSeek V4 Flash 和 GPT 5.4 排名都提升了。且一旦标准包含交付物（docker-compose、实质性 README、bundle-audit），看似干净但交付物不完整的模型（DeepSeek V4 Pro、Step 3.5 Flash）跌到反映情况的等级

7. **Benchmark 是工具，不是真理**：测的是特定 Rails app + 特定库。模型在其他任务上可能表现不同。方法论公开于 `audit_prompt_template.md`，可复现、改编或质疑

---

## 参考资料

- [原文](https://akitaonrails.com/en/2026/04/24/llm-benchmarks-parte-3-deepseek-kimi-mimo/)
- [Claude Opus 4.7 — What's new, Anthropic](https://docs.anthropic.com/)
- [Migration guide Claude 4.6 → 4.7](https://docs.anthropic.com/)
- [GitHub issue #52368 — Opus 4.7 instability](https://github.com/)
- [DEV.to — Why We Switched Back from Opus 4.7 to 4.6](https://dev.to/)
- [OpenAI — Introducing GPT-5.5](https://openai.com/)
- [Simon Willison — GPT-5.5 via Codex](https://simonwillison.net/)
- [GLM 5.1 benchmarks on OpenRouter](https://openrouter.ai/)
- [TurboQuant (Google Research, ICLR 2026)](https://arxiv.org/)
- [Ahmad Osman — GPU Memory Math for LLMs (2026)](https://)
- [llama-swap](https://github.com/)
- [llama.cpp issue #21375 — Gemma 4 tool call loops](https://github.com/)
