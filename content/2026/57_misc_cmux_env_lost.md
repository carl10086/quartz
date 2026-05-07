---
title: "cmux env lost"
date: 2026-05-06
tags:
  - misc
---

# cmux 0.64 升级后 Claude alias 环境变量丢失排查记

> 一句话总结：cmux 0.64 在 wrapper 脚本里主动 `unset` 了 `ANTHROPIC_AUTH_TOKEN` 等变量，老版本没有这层逻辑。kill-switch 是 `CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1`。

---

## 现象

升级 cmux 到 0.64 后，平时用的 alias 突然失效：

```zsh
alias cl-kimi='ANTHROPIC_AUTH_TOKEN=sk-xxx ANTHROPIC_BASE_URL=https://api.kimi.com/coding/ claude'
```

在 **ghostty** 里跑 `cl-kimi`，一切正常，claude 正确识别到 Kimi 的 token；
在 **cmux** 里跑同样的命令，claude 能启动，但顶部显示：

```
Not logged in · Run /login
```

这说明 **alias 展开了，但环境变量没传到 claude 进程**。

---

## 第一轮排查：alias vs function

先确认 `cl-kimi` 是什么：

```zsh
type cl-kimi
# cl-kimi is an alias for ANTHROPIC_AUTH_TOKEN=... ANTHROPIC_BASE_URL=... claude
```

再确认 cmux 里的 `claude` 是什么：

```zsh
which claude
# claude () {
#         "$_CMUX_CLAUDE_WRAPPER" "$@"
# }
```

cmux 0.64 把 `claude` 替换成了 **shell function**，内部调用 `$_CMUX_CLAUDE_WRAPPER`。

这就触发了 POSIX shell 的一个陷阱：

```zsh
ANTHROPIC_AUTH_TOKEN=xxx claude
```

当 `claude` 是**外部命令**时，前缀变量会 **auto-export** 给那次 exec ✅
当 `claude` 是 **function** 时，前缀变量只是**当前 shell 的局部变量**，不会自动 export 给 function 内部 fork 的子进程 ❌

cmux wrapper 是外部进程（`exec` 出去的），它继承的是 `environ[]`，看不到这些局部变量。

**第一个结论**：alias 的命令前缀语法在 cmux 的新版 wrapper 下天然失效，不是 token 写错了。

---

## 第二轮排查：wrapper 源码

cmux 在 `/Applications/cmux.app/Contents/Resources/bin/claude` 放了一个 12KB 的 bash wrapper。直接读源码：

```bash
CLAUDE_AUTH_SELECTION_ENV_KEYS=(
    ANTHROPIC_API_KEY
    ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_BASE_URL
    ANTHROPIC_MODEL
    ANTHROPIC_SMALL_FAST_MODEL
    CLAUDE_CODE_USE_BEDROCK
    CLAUDE_CODE_USE_VERTEX
)

clear_inherited_claude_auth_selection_env() {
    if [[ "${IN_CMUX:-0}" == "1" ]]; then
        local key
        for key in "${CLAUDE_AUTH_SELECTION_ENV_KEYS[@]}"; do
            should_preserve_claude_auth_selection_key "$key" && continue
            unset "$key"    # ← 就是这行
        done
    fi
}
```

当 `IN_CMUX==1`（即你在 cmux 终端内），wrapper **主动 unset** 了这些变量。它在多处被调用（pass-through 路径、正常 hook 路径、子命令路径）。

**老版本没有这个函数**，所以老版本没问题。0.64 加了这层"环境隔离"，意图可能是让 token 统一走 cmux UI 配置，而不是靠 shell env 乱传。

---

## 第三轮排查：kill-switch

源码第 84-87 行留了官方开关：

```bash
PRESERVE_CLAUDE_AUTH_SELECTION_ENV=false
case "${CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV:-}" in
    1|true|TRUE|yes|YES) PRESERVE_CLAUDE_AUTH_SELECTION_ENV=true ;;
esac
```

如果 `CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1`，`clear_inherited_claude_auth_selection_env` 就会跳过 unset，保留环境变量。

这是**官方机制**，不是 hack。

---

## 最终修复

把 alias 从命令前缀语法改成 `export` + kill-switch：

```zsh
alias cl-kimi='export CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1; export ANTHROPIC_AUTH_TOKEN=sk-xxx; export ANTHROPIC_BASE_URL=https://api.kimi.com/coding/; claude'
```

关键点：
- `export` 让变量进入 `environ[]`，wrapper fork 时能继承
- `CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1` 让 wrapper 不主动删掉它们
- alias 末尾是 `claude`，参数自然附加在后面（如 `--dangerously-skip-permissions`）

副作用：token 会在当前 shell 进程里残留，但只影响这个 tab，exit 即销毁。若在意隔离，可用 function + 子 shell：

```zsh
cl-kimi() {
  (
    export CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1
    export ANTHROPIC_AUTH_TOKEN=sk-xxx
    export ANTHROPIC_BASE_URL=https://api.kimi.com/coding/
    claude "$@"
  )
}
```

---

## 为什么 ghostty 没事

ghostty 没有 cmux 的 wrapper injection，所以 `claude` 是真正的外部命令，命令前缀语法能 auto-export，老 alias 写法在 ghostty 里一直能 work。

---

## 总结

| 环节 | 老版本 cmux | 新版本 cmux 0.64 |
|---|---|---|
| claude 命令 | 外部命令 | 被替换成 shell function |
| 前缀变量 `VAR=val claude` | auto-export ✅ | function 局部变量，不 export ❌ |
| wrapper 行为 | 透传 | 主动 `unset ANTHROPIC_*` ❌ |
| 修复方式 | 无需修复 | `export` + `CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1` |

如果你也用了类似 `cc-switch-tui` 这种工具自动生成 alias，升级 cmux 0.64 后大概率会踩同一个坑。直接给 alias 加一行 kill-switch 就行，不需要退版本、不需要关 automation 集成。

---

## 参考

- cmux wrapper 路径：`/Applications/cmux.app/Contents/Resources/bin/claude`
- 相关环境变量：`CMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV`
- zsh 文档：Command Execution（POSIX prefix assignment 对 function 的行为）
