## 核心概念

**Hooks** 是用户定义的 shell 命令，在 Claude Code 生命周期的特定节点执行。它们提供确定性控制，确保某些操作总是发生，而不是依赖 LLM 选择执行。

### 三种 Hook 类型

1. **Command Hooks** (`type: "command"`): 执行 shell 命令
2. **Prompt-based Hooks** (`type: "prompt"`): 使用 Claude 模型进行单轮判断
3. **Agent-based Hooks** (`type: "agent"`): 使用子代理进行多轮验证，可访问工具

## 主要事件类型

| 事件 | 触发时机 | 典型用途 |
|:---|:---|:---|
| `SessionStart` | 会话启动时 | 注入上下文、设置环境变量 |
| `UserPromptSubmit` | 用户提交提示词后 | 修改或增强用户输入 |
| `PreToolUse` | 工具执行前 | 阻止危险操作、权限控制 |
| `PostToolUse` | 工具执行后 | 自动格式化、运行测试 |
| `PermissionRequest` | 请求权限时 | 自动批准/拒绝特定操作 |
| `Stop` | Claude 完成响应时 | 验证任务完成度 |
| `Notification` | Claude 等待输入时 | 发送桌面通知 |

## 实用示例

### 1. 桌面通知（macOS）

```json
{
  "hooks": [
    {
      "event": "Notification",
      "command": "osascript -e 'display notification \"Claude needs your input\" with title \"Claude Code\"'"
    }
  ]
}
```

### 2. 自动格式化代码

```json
{
  "hooks": [
    {
      "event": "PostToolUse",
      "matcher": "Edit|Write",
      "command": "jq -r '.tool_input.path' | xargs prettier --write"
    }
  ]
}
```

### 3. 保护敏感文件

创建脚本 `.claude/hooks/protect-files.sh`:

```bash
#!/bin/bash
set -e

# 从 stdin 读取 JSON 输入
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.path // .tool_input.file_path // ""')

# 保护的文件模式
protected_patterns=(
  ".env"
  "package-lock.json"
  ".git/"
  "node_modules/"
)

for pattern in "${protected_patterns[@]}"; do
  if [[ "$file_path" == *"$pattern"* ]]; then
    echo "Cannot modify protected file: $file_path" >&2
    exit 2  # 阻止操作
  fi
done

exit 0  # 允许操作
```

配置：

```json
{
  "hooks": [
    {
      "event": "PreToolUse",
      "matcher": "Edit|Write",
      "command": ".claude/hooks/protect-files.sh"
    }
  ]
}
```

### 4. 压缩后重新注入上下文

```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "matcher": "compact",
      "command": "echo 'Project conventions: Use TypeScript strict mode, prefer functional patterns. Recent work: Refactored auth module.'"
    }
  ]
}
```

## Hook 输入输出机制

### 输入格式

Hook 通过 stdin 接收 JSON 格式的事件数据。例如 `PreToolUse` 事件：

```json
{
  "session_id": "abc123",
  "cwd": "/path/to/project",
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /"
  }
}
```

### 输出控制

**通过退出码：**
- `exit 0`: 允许操作继续，stdout 内容会添加到 Claude 上下文
- `exit 2`: 阻止操作，stderr 内容作为反馈发送给 Claude
- 其他退出码: 操作继续，stderr 仅记录日志

**通过 JSON 输出（更精细控制）：**

```bash
#!/bin/bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

if [[ "$command" == *"rm -rf"* ]]; then
  echo '{
    "permissionDecision": "deny",
    "permissionDecisionReason": "Dangerous command detected"
  }'
  exit 0
fi

echo '{"permissionDecision": "allow"}'
exit 0
```

## Matchers（过滤器）

使用正则表达式过滤 Hook 触发条件：

```json
{
  "event": "PostToolUse",
  "matcher": "Edit|Write",  // 仅匹配 Edit 或 Write 工具
  "command": "prettier --write"
}
```

不同事件匹配不同字段：
- `PreToolUse` / `PostToolUse`: 匹配 `tool_name`
- `UserPromptSubmit`: 匹配 `prompt` 文本
- `SessionStart`: 匹配 `source` (startup/resume/compact)

## Prompt-based Hooks

使用 Claude 模型进行判断决策：

```json
{
  "hooks": [
    {
      "event": "Stop",
      "type": "prompt",
      "model": "claude-3-5-haiku-20241022",
      "prompt": "Review the conversation. Are all requested tasks complete? Return {\"ok\": true} if complete, or {\"ok\": false, \"reason\": \"<what's missing>\"} if not."
    }
  ]
}
```

模型返回格式：
- `{"ok": true}`: 允许操作
- `{"ok": false, "reason": "..."}`: 阻止操作，reason 发送给 Claude

## Agent-based Hooks

需要检查文件或执行命令时使用：

```json
{
  "hooks": [
    {
      "event": "Stop",
      "type": "agent",
      "prompt": "Run the test suite. Return {\"ok\": true} if all tests pass, or {\"ok\": false, \"reason\": \"<failure details>\"} if any fail."
    }
  ]
}
```

Agent hooks 可以：
- 读取文件
- 搜索代码
- 执行命令
- 最多 50 轮工具调用
- 默认超时 60 秒

## 配置位置

| 位置 | 作用域 |
|:---|:---|
| `~/.claude/settings.json` | 全局 hooks，所有项目生效 |
| `.claude/settings.json` | 项目级 hooks，仅当前项目 |
| `/hooks` 菜单 | 交互式添加/删除/查看 hooks |

## 常见问题排查

### Hook 未触发
- 检查 matcher 是否匹配工具名称（区分大小写）
- 确认事件类型正确（PreToolUse vs PostToolUse）
- 使用 `/hooks` 菜单确认配置已加载

### JSON 解析失败
检查 `~/.zshrc` 或 `~/.bashrc` 中的 echo 语句：

```bash
# 错误：无条件输出
echo "Welcome!"

# 正确：仅在交互式 shell 输出
[[ $- == *i* ]] && echo "Welcome!"
```

### Stop Hook 无限循环
检查 `stop_hook_active` 标志：

```bash
#!/bin/bash
input=$(cat)
if [[ $(echo "$input" | jq -r '.stop_hook_active') == "true" ]]; then
  exit 0  # 避免重复触发
fi

# 你的验证逻辑...
```

### 调试技巧
- `Ctrl+O`: 切换详细模式，查看 hook 输出
- `claude --debug`: 完整执行细节
- 手动测试：`echo '{"tool_name":"Bash"}' | ./your-hook.sh`

## 限制

- `Hooks` 只能通过 stdout/stderr/exit code 通信，不能直接触发斜杠命令或工具调用
- 默认超时 10 分钟（可通过 `timeout` 字段配置）
- `PostToolUse` hooks 无法撤销已执行的操作
- `PermissionRequest` hooks 在非交互模式 (`-p`) 下不触发

## 相关功能

- **Skills**: 给 Claude 额外指令和可执行命令
- **Subagents**: 在隔离上下文中运行任务
- **Plugins**: 打包扩展以跨项目共享
- **CLAUDE.md**: 在每次会话启动时注入上下文

## 参考资源

- [Hooks 完整参考文档](https://code.claude.com/docs/en/hooks)
- [Bash 命令验证器示例](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py)
- [安全考虑事项](https://code.claude.com/docs/en/hooks#security-considerations)

