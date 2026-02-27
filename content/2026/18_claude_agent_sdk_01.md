
# 第一部分:基础概念

## 1. 什么是 Agent SDK?

想象你在和一个很聪明的助手 (Claude) 对话,但这个助手不只能聊天,还能:
- 📝 读写文件
- 💻 运行命令
- 🔧 使用你自定义的工具

**Agent SDK 就是连接你的 Python 程序和 Claude 的桥梁**。

### 类比理解:
```
你的 Python 代码  →  Agent SDK  →  Claude AI  →  执行工具  →  返回结果
    (老板)          (翻译官)      (聪明员工)    (干活)     (汇报)
```

---

## 2. 两种使用模式

### 模式一:`query()` - 快餐模式 🍔
适合:快速提问,一次性任务

```python
# 就像点外卖:说一句话,等结果
async for message in query(prompt="2+2等于多少?"):
    print(message)
```

### 模式二:`ClaudeSDKClient` - 自助餐模式 🍽️
适合:多轮对话,自定义工具,复杂控制

```python
# 就像进餐厅:可以多次点菜,加配料,定制服务
async with ClaudeSDKClient(options=options) as client:
    await client.query("第一个问题")
    # 获取回复...
    await client.query("继续问第二个问题")
    # 可以一直对话下去
```

---

## 3. 消息类型

Claude 的对话有不同类型的消息:

| 消息类型               | 谁发送    | 用途     | 例子              |
| :----------------- | :----- | :----- | :-------------- |
| `AssistantMessage` | Claude | AI 的回复 | "好的,我帮你创建文件"    |
| `UserMessage`      | 你      | 你的提问   | "创建一个 hello.py" |
| `ResultMessage`    | 系统     | 工具执行结果 | "文件创建成功"        |
|                    |        |        |                 |

每个消息里有**内容块**:

```python
# 文本块
TextBlock(text="我理解了你的需求")

# 工具使用块
ToolUseBlock(name="Write", input={"path": "hello.py", ...})

# 工具结果块
ToolResultBlock(content="文件已创建")
```

---

# 第二部分:快速上手

## 4. 安装

```bash
pip install claude-agent-sdk
```

**重要**: SDK 已经内置了 Claude CLI,不需要额外安装!

---

## 5. 第一个例子

```python
import anyio
from claude_agent_sdk import query

async def main():
    # 问 Claude 一个问题
    async for message in query(prompt="Python 中如何读取文件?"):
        print(message)

# 运行异步函数
anyio.run(main)
```

### 输出解析:
```python
AssistantMessage(
    content=[
        TextBlock(text="在 Python 中读取文件有几种方法:\n1. 使用 open()...")
    ]
)
```

---

## 6. 理解异步迭代器

### 为什么用 `async for`?

Claude 的回复是**流式**的,就像微信语音转文字一样,边说边显示:

```python
# ❌ 错误:会等很久才拿到完整结果
result = await query(prompt="写一个长故事")

# ✅ 正确:边生成边显示
async for message in query(prompt="写一个长故事"):
    # 每次拿到一部分内容
    if isinstance(message, AssistantMessage):
        for block in message.content:
            if isinstance(block, TextBlock):
                print(block.text, end='', flush=True)  # 实时显示
```

### 完整示例:提取文本内容

```python
from claude_agent_sdk import query, AssistantMessage, TextBlock

async def ask_claude(question: str):
    """向 Claude 提问并提取文本回复"""
    full_response = ""
    
    async for message in query(prompt=question):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    full_response += block.text
    
    return full_response

# 使用
answer = await ask_claude("什么是递归?")
print(answer)
```

---

# 第三部分:工具系统

## 7. 内置工具

Claude 可以使用这些工具:

| 工具名 | 功能 | 危险性 |
|:---|:---|:---|
| `Read` | 读取文件 | 🟢 安全 |
| `Write` | 写入/编辑文件 | 🟡 中等 |
| `Bash` | 运行命令 | 🔴 危险 |
| `ListDirectory` | 列出目录 | 🟢 安全 |
| `ComputerUse` | 控制鼠标键盘 | 🔴 非常危险 |

### 基础示例:让 Claude 读文件

```python
from claude_agent_sdk import query, ClaudeAgentOptions

options = ClaudeAgentOptions(
    allowed_tools=["Read"]  # 只允许读文件
)

async for message in query(
    prompt="读取 README.md 的内容",
    options=options
):
    print(message)
```

### Claude 的工作流程:
1. Claude 看到你的请求
2. Claude 决定:"我需要用 Read 工具"
3. SDK 检查:"`Read` 在允许列表里吗?" ✅
4. 执行:`读取 README.md`
5. 结果返回给 Claude
6. Claude 总结:"文件内容是..."

---

## 8. 权限模式

当 Claude 想修改文件时,谁来批准?

```python
from claude_agent_sdk import ClaudeAgentOptions

# 模式 1:每次都问你 (默认)
options = ClaudeAgentOptions(
    allowed_tools=["Write"],
    permission_mode='ask'  # 每次写文件都会暂停等你确认
)

# 模式 2:自动批准编辑
options = ClaudeAgentOptions(
    allowed_tools=["Write"],
    permission_mode='acceptEdits'  # 自动批准,但你要信任 Claude!
)

# 模式 3:自动批准所有操作 (危险!)
options = ClaudeAgentOptions(
    allowed_tools=["Write", "Bash"],
    permission_mode='acceptAll'  # Claude 可以随意执行命令!
)
```

### 实战建议:
- 🧪 测试环境 → `acceptAll` (方便快速)
- 🏢 生产环境 → `ask` (安全第一)
- 📝 文档生成 → `acceptEdits` (只改文件,相对安全)

---

## 9. 工作目录

```python
from pathlib import Path
from claude_agent_sdk import ClaudeAgentOptions

# 方式 1:字符串路径
options = ClaudeAgentOptions(
    cwd="/Users/you/project",
    allowed_tools=["Read", "Write"]
)

# 方式 2:Path 对象
options = ClaudeAgentOptions(
    cwd=Path.home() / "projects" / "my_app",
    allowed_tools=["Read", "Write"]
)

# 使用
async for msg in query(
    prompt="在当前目录创建 config.json",
    options=options
):
    print(msg)
```

### 类比理解:
```
cwd="/Users/you/project"
↓
相当于先执行:cd /Users/you/project
↓
然后 Claude 的所有文件操作都在这个目录下
```

---

# 第四部分:高级功能

## 10. 多轮对话

使用 `ClaudeSDKClient` 可以保持上下文:

```python
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions

async def multi_turn_chat():
    options = ClaudeAgentOptions(
        allowed_tools=["Write", "Bash"]
    )
    
    async with ClaudeSDKClient(options=options) as client:
        # 第一轮:创建文件
        await client.query("创建一个 Python 脚本 hello.py,打印 Hello World")
        async for msg in client.receive_response():
            print("回复1:", msg)
        
        print("\n--- 继续对话 ---\n")
        
        # 第二轮:Claude 记得刚才创建了 hello.py
        await client.query("运行刚才创建的脚本")
        async for msg in client.receive_response():
            print("回复2:", msg)

anyio.run(multi_turn_chat)
```

### 关键点:
- `async with` 确保会话保持
- 每次 `query()` 后要用 `receive_response()` 获取回复
- Claude 会记住之前的对话内容

---

## 11. 创建自定义工具

这是最强大的功能!让 Claude 可以调用你的 Python 函数。

### 示例:计算器工具

```python
from claude_agent_sdk import (
    tool, 
    create_sdk_mcp_server, 
    ClaudeAgentOptions, 
    ClaudeSDKClient
)

# 步骤 1:定义工具函数
@tool(
    name="add",  # 工具名称
    description="将两个数字相加",  # 告诉 Claude 这个工具做什么
    input_schema={"a": float, "b": float}  # 参数类型
)
async def add_numbers(args):
    """Claude 会把参数传到这里"""
    result = args["a"] + args["b"]
    return {
        "content": [
            {"type": "text", "text": f"结果是 {result}"}
        ]
    }

@tool(
    name="multiply",
    description="将两个数字相乘",
    input_schema={"a": float, "b": float}
)
async def multiply_numbers(args):
    result = args["a"] * args["b"]
    return {
        "content": [
            {"type": "text", "text": f"结果是 {result}"}
        ]
    }

# 步骤 2:创建 MCP 服务器
calculator_server = create_sdk_mcp_server(
    name="calculator",
    version="1.0.0",
    tools=[add_numbers, multiply_numbers]  # 注册工具
)

# 步骤 3:配置 SDK
options = ClaudeAgentOptions(
    mcp_servers={"calc": calculator_server},
    # 工具名称格式:mcp__<服务器名>__<工具名>
    allowed_tools=["mcp__calc__add", "mcp__calc__multiply"]
)

# 步骤 4:使用
async def main():
    async with ClaudeSDKClient(options=options) as client:
        await client.query("计算 123 + 456")
        async for msg in client.receive_response():
            print(msg)

anyio.run(main)
```

### 工作流程:
```
1. 你:"计算 123 + 456"
   ↓
2. Claude 分析:"需要用 add 工具"
   ↓
3. SDK 调用你的 add_numbers({"a": 123, "b": 456})
   ↓
4. 你的函数返回:{"content": [{"type": "text", "text": "结果是 579"}]}
   ↓
5. Claude 看到结果:"好的,123 + 456 = 579"
```

---

## 12. 钩子 (Hooks)

钩子让你在 Claude 执行工具**之前**或**之后**插入自己的逻辑。

### 使用场景:
- ✅ 安全检查:阻止危险命令
- 📝 日志记录:记录所有工具调用
- 🔄 自动重试:工具失败时自动重试
- 📊 统计分析:收集使用数据

### 示例:阻止危险命令

```python
from claude_agent_sdk import ClaudeAgentOptions, ClaudeSDKClient, HookMatcher

# 定义钩子函数
async def check_bash_safety(input_data, tool_use_id, context):
    """在 Claude 执行 Bash 命令前检查"""
    tool_name = input_data["tool_name"]
    tool_input = input_data["tool_input"]
    
    # 只检查 Bash 工具
    if tool_name != "Bash":
        return {}  # 放行
    
    command = tool_input.get("command", "")
    
    # 危险命令列表
    dangerous = ["rm -rf", "sudo", "dd if=", "mkfs"]
    
    for pattern in dangerous:
        if pattern in command:
            # 阻止执行!
            return {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",  # 拒绝
                    "permissionDecisionReason": f"危险命令:{pattern}",
                }
            }
    
    return {}  # 安全,放行

# 配置钩子
options = ClaudeAgentOptions(
    allowed_tools=["Bash"],
    hooks={
        "PreToolUse": [  # 工具使用前触发
            HookMatcher(
                matcher="Bash",  # 只匹配 Bash 工具
                hooks=[check_bash_safety]
            )
        ]
    }
)

# 测试
async with ClaudeSDKClient(options=options) as client:
    # ❌ 这个会被阻止
    await client.query("运行命令:rm -rf /")
    
    # ✅ 这个可以通过
    await client.query("运行命令:echo 'Hello'")
```

### 钩子类型:

| 钩子名称          | 触发时机  | 用途        |
| :------------ | :---- | :-------- |
| `PreToolUse`  | 工具执行前 | 安全检查、参数验证 |
| `PostToolUse` | 工具执行后 | 结果处理、日志记录 |
| `PreTurn`     | 每轮对话前 | 上下文注入     |
| `PostTurn`    | 每轮对话后 | 状态更新      |

---

# 第五部分:实战演练

## 13. 完整示例:自动化代码审查

```python
import anyio
from claude_agent_sdk import (
    ClaudeSDKClient,
    ClaudeAgentOptions,
    tool,
    create_sdk_mcp_server,
    HookMatcher,
    AssistantMessage,
    TextBlock
)
from pathlib import Path

# 1. 自定义工具:代码质量检查
@tool(
    name="check_code_quality",
    description="检查 Python 代码的质量问题",
    input_schema={"code": str}
)
async def check_code_quality(args):
    code = args["code"]
    issues = []
    
    # 简单的静态检查
    if "print(" in code:
        issues.append("⚠️ 使用了 print,考虑用 logging")
    if "except:" in code:
        issues.append("⚠️ 捕获了所有异常,应该指定异常类型")
    if len(code.split("\n")) > 50:
        issues.append("⚠️ 函数太长,考虑拆分")
    
    result = "✅ 代码质量良好" if not issues else "\n".join(issues)
    
    return {
        "content": [{"type": "text", "text": result}]
    }

# 2. 创建工具服务器
review_server = create_sdk_mcp_server(
    name="code_review",
    version="1.0.0",
    tools=[check_code_quality]
)

# 3. 钩子:记录所有文件读取
log_file = Path("audit.log")

async def log_file_reads(input_data, tool_use_id, context):
    """记录所有文件读取操作"""
    if input_data["tool_name"] == "Read":
        file_path = input_data["tool_input"].get("path", "unknown")
        with open(log_file, "a") as f:
            f.write(f"[READ] {file_path}\n")
    return {}

# 4. 配置选项
options = ClaudeAgentOptions(
    cwd=Path.cwd(),
    allowed_tools=["Read", "mcp__code_review__check_code_quality"],
    mcp_servers={"code_review": review_server},
    hooks={
        "PreToolUse": [
            HookMatcher(matcher="Read", hooks=[log_file_reads])
        ]
    },
    system_prompt="你是一个代码审查助手,严格遵循 PEP 8 规范"
)

# 5. 主程序
async def main():
    async with ClaudeSDKClient(options=options) as client:
        # 第一轮:读取文件
        await client.query("读取 example.py 的内容")
        
        full_text = ""
        async for msg in client.receive_response():
            if isinstance(msg, AssistantMessage):
                for block in msg.content:
                    if isinstance(block, TextBlock):
                        full_text += block.text
        
        print("Claude 回复:", full_text)
        print("\n" + "="*50 + "\n")
        
        # 第二轮:审查代码
        await client.query("用 check_code_quality 工具审查刚才读取的代码")
        
        async for msg in client.receive_response():
            if isinstance(msg, AssistantMessage):
                for block in msg.content:
                    if isinstance(block, TextBlock):
                        print("审查结果:", block.text)

if __name__ == "__main__":
    anyio.run(main)
```

---

## 14. 错误处理最佳实践

```python
from claude_agent_sdk import (
    query,
    ClaudeSDKError,
    CLINotFoundError,
    CLIConnectionError,
    ProcessError,
    CLIJSONDecodeError,
)
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def safe_query(prompt: str, max_retries: int = 3):
    """带重试和完善错误处理的查询函数"""
    
    for attempt in range(max_retries):
        try:
            results = []
            async for message in query(prompt=prompt):
                results.append(message)
            return results
            
        except CLINotFoundError:
            logger.error("❌ Claude CLI 未安装")
            logger.info("运行:curl -fsSL https://claude.ai/install.sh | bash")
            return None
            
        except CLIConnectionError as e:
            logger.warning(f"⚠️ 连接失败 (尝试 {attempt + 1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                await anyio.sleep(2 ** attempt)  # 指数退避
                continue
            logger.error("❌ 连接持续失败,放弃")
            return None
            
        except ProcessError as e:
            logger.error(f"❌ 进程错误 (退出码 {e.exit_code})")
            logger.debug(f"标准错误:{e.stderr}")
            return None
            
        except CLIJSONDecodeError as e:
            logger.error(f"❌ JSON 解析失败:{e}")
            logger.debug(f"原始数据:{e.raw_data}")
            return None
            
        except ClaudeSDKError as e:
            logger.error(f"❌ SDK 错误:{e}")
            return None
            
        except Exception as e:
            logger.error(f"❌ 未知错误:{type(e).__name__}: {e}")
            return None
    
    return None

# 使用
async def main():
    result = await safe_query("写一个快速排序算法")
    
    if result:
        print("✅ 成功获取回复")
        for msg in result:
            print(msg)
    else:
        print("❌ 查询失败")

anyio.run(main)
```

---