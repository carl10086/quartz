---
title: "markdown-reader 使用指南"
date: 2026-05-13
tags:
  - misc
  - tools
---

> markdown-reader v1.34.69 — 终端 Markdown 浏览器与阅读器
> crates.io 包名: `markdown-tui-explorer`

---

## 1. 简介

`markdown-reader` 是一个用 Rust + ratatui 构建的 **TUI Markdown 文件浏览器**，核心定位是"面向整个文档仓库的阅读器，而非单文件预览"。

它区别于 `glow`、`mdcat` 等工具的最大特点：

| 维度 | markdown-reader | glow |
|---|---|---|
| 浏览模式 | 仓库级（文件树 + 多标签） | 单文件或目录列表 |
| Mermaid | **18 种图表类型**，纯 Rust 渲染 | 不支持 |
| LaTeX | Unicode 近似渲染 | 不支持 |
| 实时编辑 | `i` 混合预览模式 | 不支持 |
| 会话恢复 | 自动恢复标签和滚动位置 | 不支持 |

---

## 2. 安装（macOS）

### Homebrew（推荐）

```bash
brew tap leboiko/tap
brew install markdown-reader
brew upgrade markdown-reader    # 后续更新
```

### 预编译二进制

Apple Silicon:

```bash
curl -L https://github.com/leboiko/markdown-reader/releases/latest/download/markdown-reader-aarch64-apple-darwin.tar.gz | tar xz
sudo mv markdown-reader-*/markdown-reader /usr/local/bin/
```

Intel Mac:

```bash
curl -L https://github.com/leboiko/markdown-reader/releases/latest/download/markdown-reader-x86_64-apple-darwin.tar.gz | tar xz
sudo mv markdown-reader-*/markdown-reader /usr/local/bin/
```

**首次运行注意**：macOS 会提示未签名。右键点二进制文件 → 选"打开"一次，后续正常。

---

## 3. 快速开始

```bash
# 浏览当前目录
markdown-reader

# 浏览指定目录
markdown-reader ~/notes

# 浏览单个文件（自动打开父目录树并定位到该文件）
markdown-reader README.md

# 从 stdin 读取（常用于管道）
cat article.md | markdown-reader
curl -s https://example.com/doc.md | markdown-reader
```

从 stdin 读取时，tab 标签显示为 `<stdin>`，不会持久化到会话中。

---

## 4. 命令行选项

```
Usage: markdown-reader [OPTIONS] [PATH]
```

| 选项 | 说明 |
|---|---|
| `[PATH]` | 浏览路径。目录 → 打开文件树；文件 → 打开父目录并定位到该文件。默认当前目录。stdin 输入时忽略此参数。 |
| `--export-html <FILE>` | 将 Markdown 导出为独立 HTML，不启动 TUI。输出到 stdout，除非同时用 `-o` |
| `-o, --output <FILE>` | `--export-html` 的输出文件路径 |
| `--check-links [<DIR>]` | 检查目录下所有 `.md` 的链接有效性。不启动 TUI。退出码 0 = 全部有效，1 = 存在坏链 |
| `--check-external` | 在 `--check-links` 基础上额外检查 `http(s)://` 外链（HEAD 请求，10 并发，最多 5 次重定向） |
| `--external-timeout-secs <SECS>` | 外部链接检查超时（默认 10 秒） |
| `--section <NAME>` | 按 heading 名称提取章节到 stdout，不启动 TUI。支持大小写不敏感的子串匹配 |
| `-h, --help` | 帮助 |
| `-V, --version` | 版本号 |

---

## 5. TUI 快捷键速查

### 文件树

| 快捷键 | 动作 |
|---|---|
| `j` / `↓` | 下移 |
| `k` / `↑` | 上移 |
| `Enter` / `l` / `→` | 打开文件 / 展开目录 |
| `h` / `←` | 折叠目录 |
| `gg` | 跳到第一项 |
| `G` | 跳到最后一项 |
| `t` | 新标签页打开选中文件 |
| `Tab` | 焦点切换到阅读器 |
| `y` | 复制选中文件路径到剪贴板（OSC 52） |

### 阅读器

| 快捷键 | 动作 |
|---|---|
| `j` / `↓` | 光标下移一行 |
| `k` / `↑` | 光标上移一行 |
| `d` / `u` | 半页下/上 |
| `PageDown` / `PageUp` | 整页下/上 |
| `gg` | 跳到顶部 |
| `G` | 跳到底部 |
| `:` | 跳转到指定行（如 `:5`） |
| `Ctrl+f` | 文档内搜索 |
| `n` / `N` | 下一个/上一个匹配 |
| `o` | 大纲导航（heading picker） |
| `f` | 锚点链接选择器 |
| `V` | 进入可视行选择模式 |
| `yy` | 复制当前行 |
| `y`（可视模式下） | 复制选区并退出可视模式 |
| `Enter` | 展开可见表格到全屏模态 |
| `i` | **混合实时预览编辑模式** |
| `I` | 全屏编辑模式 |
| `Tab` | 焦点切换回文件树 |

#### 混合编辑模式（按 `i` 进入）

光标所在 block 显示原始 Markdown 源码，其余 block 保持渲染。

| 快捷键 | 动作 |
|---|---|
| `Option+←/→` / `Ctrl+←/→` | 按单词移动 |
| `Cmd+←/→` / `Ctrl+A/E` | 行首/行尾 |
| `Cmd+↑/↓` | 文档首/尾 |
| `Option+Backspace` / `Ctrl+W` | 删除前一个单词 |
| `Option+Delete` | 删除后一个单词 |
| `Cmd+Backspace` / `Ctrl+U` | 删除到行首 |
| `Ctrl+K` | 删除到行尾 |
| `:w` | 保存 |
| `:wq` | 保存并退出编辑模式 |
| `:q` | 退出编辑模式 |
| `:q!` | 强制放弃修改 |

表格在混合模式下会自动打开专用表格编辑器；Mermaid 块在光标离开后自动重渲染。

### 表格模态（`Enter` 打开）

| 快捷键 | 动作 |
|---|---|
| `h` / `←` | 左移一列 |
| `l` / `→` | 右移一列 |
| `H` / `Shift+←` | 左移十列 |
| `L` / `Shift+→` | 右移十列 |
| `0` | 跳到第一列 |
| `$` | 跳到最后一列 |
| `j` / `↓` | 下行 |
| `k` / `↑` | 上行 |
| `d` / `u` | 半页下/上 |
| `gg` | 跳到左上角 |
| `G` | 跳到最后一行 |
| `q` / `Esc` / `Enter` | 关闭模态 |

### 标签页

| 快捷键 | 动作 |
|---|---|
| `gt` | 下一个标签 |
| `gT` | 上一个标签 |
| `1`–`9` | 跳到第 N 个标签 |
| `0` | 跳到最后一个标签 |
| `` ` `` | 跳回上次活跃的标签 |
| `x` | 关闭当前标签 |
| `T` | 打开标签选择器浮层 |

最多 32 个标签。

### 面板/全局

| 快捷键 | 动作 |
|---|---|
| `[` / `]` | 缩小/放大文件树 |
| `H` | 显示/隐藏文件树 |
| `c` | 打开设置（主题、行号、树位置、搜索预览） |
| `?` | 帮助浮层 |
| `q` | 退出（自动保存会话） |

### 搜索（`/` 打开）

| 快捷键 | 动作 |
|---|---|
| `Tab` | 切换文件名搜索 / 内容搜索 |
| `↓` / `Ctrl+n` | 下一个结果 |
| `↑` / `Ctrl+p` | 上一个结果 |
| `Enter` | 在新标签打开选中结果 |
| `Esc` | 关闭搜索 |

---

## 6. Mermaid 图表渲染

支持 18 种图表类型：flowchart / sequence / state / class / ER / pie / Gantt / timeline / git graph / mindmap / quadrant / requirement / xychart-beta / sankey-beta / block-beta / packet-beta。

### 渲染管线

```
mermaid 源码 → mermaid-rs-renderer → SVG → resvg 栅格化 (3x 分辨率)
    → ratatui-image → 按终端能力显示
```

### 终端适配

| 终端 | 协议 | 质量 |
|---|---|---|
| Kitty, Ghostty, WezTerm, Konsole | Kitty graphics protocol | 最佳 |
| iTerm2 | iTerm2 inline images | 最佳 |
| Foot, xterm, mintty, Contour | Sixel | 良好 |
| Alacritty 等无图形协议终端 | Unicode halfblock | 低分辨率可读 |
| tmux | **禁用图形**，回退到文本源码 | 需退出 tmux 看图形 |

tmux 用户会看到 `[mermaid — disable tmux for graphics]` 提示。

渲染在后台线程执行，首次显示 `rendering…` 占位符，结果缓存。

---

## 7. 主题与配置

### 8 种内置主题

Default / Dracula / Solarized Dark / Solarized Light / Nord / Gruvbox Dark / Gruvbox Light / GitHub Light

按 `c` 打开设置模态，实时切换，所有打开文档即时重绘。

### 配置文件 `config.toml`

| 平台 | 路径 |
|---|---|
| Linux | `~/.config/markdown-reader/config.toml` |
| macOS | `~/Library/Application Support/markdown-reader/config.toml` |

示例：

```toml
theme = "dracula"
show_line_numbers = true
tree_position = "left"   # left | right

[updates]
check_for_updates = false   # 禁用启动时检查更新
```

### 会话状态 `state.toml`

每项目自动保存标签、活跃标签、滚动位置。

| 平台 | 路径 |
|---|---|
| Linux | `~/.local/state/markdown-reader/state.toml` |
| macOS | `~/Library/Application Support/markdown-reader/state.toml` |

删除此文件即可重置某个项目的会话。

---

## 8. CLI 工具模式（不启动 TUI）

### HTML 导出

```bash
markdown-reader --export-html input.md > output.html
markdown-reader --export-html input.md --output rendered.html
```

输出独立 HTML，含语法高亮、LaTeX Unicode、mermaid 文本图。无需 Mermaid.js 或网络。

### 链接检查

```bash
markdown-reader --check-links docs/                    # 检查内部链接
markdown-reader --check-links docs/ --check-external   # 额外检查外部链接
markdown-reader --check-links docs/ --check-external --external-timeout-secs 15
```

检查范围：同文件锚点、跨文件链接、跨文件锚点。外部链接用 HEAD 请求验证（10 并发，最多 5 次重定向）。

退出码：0 = 全部有效，1 = 存在坏链。

### 章节提取

```bash
markdown-reader --section "Installation" guide.md
cat guide.md | markdown-reader --section "Usage"
```

大小写不敏感的子串匹配，提取从匹配 heading 到下一个同级/更高级 heading 之间的内容。

---

## 9. 与 read 项目的工作流整合

```bash
# 浏览 raw/ 素材
markdown-reader ~/soft/projects/read/raw

# 浏览 wiki/ 知识库
markdown-reader ~/soft/projects/read/wiki

# 快速预览单个 raw 文件
cat raw/2026-05-08_llm_system_prompt_essence.md | markdown-reader

# 检查 carl-blogs/ 中的链接
markdown-reader --check-links carl-blogs/ --check-external

# 导出单篇博客为 HTML
markdown-reader --export-html carl-blogs/001_test_post.md --output /tmp/preview.html
```

---

## 10. 已知限制

- tmux 内 mermaid 降级为 ASCII 源码（tmux 对图形协议 passthrough 支持不足）
- 最多 32 个标签页
- Mermaid diamond 节点 `{text}` 部分渲染器暂不支持，可用 `[]` 替代
- 未签名 macOS 二进制，首次运行需右键"打开"

---

参考：
- [GitHub: leboiko/markdown-reader](https://github.com/leboiko/markdown-reader)
- [crates.io: markdown-tui-explorer](https://crates.io/crates/markdown-tui-explorer)
