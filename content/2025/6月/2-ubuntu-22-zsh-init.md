## refer

```shell
#!/bin/bash
# oh-my-zsh-setup-root.sh - 适用于 root 用户的 Oh My Zsh 安装脚本

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    // TODO 检查 github 和 ...
    log_success "网络连接正常"
}

# 安装必要的依赖
install_dependencies() {
    log_info "安装必要的依赖包..."

    # 更新包列表
    apt update

    # 安装基础工具
    apt install -y \
        zsh \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3-pip \
        nodejs \
        npm \
        tree \
        htop \
        neofetch \
        bat \
        exa \
        fd-find \
        ripgrep \
        fzf \
        autojump \
        thefuck

    log_success "依赖包安装完成"
}

# 安装 Oh My Zsh
install_oh_my_zsh() {
    log_info "安装 Oh My Zsh..."

    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_warning "Oh My Zsh 已经安装，跳过安装步骤"
        return
    fi

    # 下载并安装 Oh My Zsh (root 用户需要特殊处理)
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    log_success "Oh My Zsh 安装完成"
}

# 安装 Powerlevel10k 主题
install_powerlevel10k() {
    log_info "安装 Powerlevel10k 主题..."

    # 克隆 Powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    log_success "Powerlevel10k 主题安装完成"
}

# 安装插件
install_plugins() {
    log_info "安装 Oh My Zsh 插件..."

    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    # zsh-autosuggestions (自动建议)
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
    fi

    # zsh-syntax-highlighting (语法高亮)
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
    fi

    # zsh-completions (自动补全增强)
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
    fi

    # fast-syntax-highlighting (更快的语法高亮)
    if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
    fi

    # zsh-history-substring-search (历史搜索)
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]; then
        git clone https://github.com/zsh-users/zsh-history-substring-search $ZSH_CUSTOM/plugins/zsh-history-substring-search
    fi

    # you-should-use (别名提醒)
    if [ ! -d "$ZSH_CUSTOM/plugins/you-should-use" ]; then
        git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
    fi

    log_success "插件安装完成"
}

# 安装额外工具
install_extra_tools() {
    log_info "安装额外的编程工具..."

    # 安装 lazygit
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    install lazygit /usr/local/bin
    rm lazygit lazygit.tar.gz

    # 安装 delta (git diff 增强)
    wget https://github.com/dandavison/delta/releases/download/0.16.5/git-delta_0.16.5_amd64.deb
    dpkg -i git-delta_0.16.5_amd64.deb || apt-get install -f -y
    rm git-delta_0.16.5_amd64.deb

    # 安装 lsd (ls 增强版)
    wget https://github.com/Peltoche/lsd/releases/download/0.23.1/lsd_0.23.1_amd64.deb
    dpkg -i lsd_0.23.1_amd64.deb || apt-get install -f -y
    rm lsd_0.23.1_amd64.deb

    log_success "额外工具安装完成"
}

# 配置 .zshrc
configure_zshrc() {
    log_info "配置 .zshrc 文件..."

    # 备份原始配置
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # 创建新的 .zshrc 配置
    cat > "$HOME/.zshrc" << 'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    docker
    docker-compose
    kubectl
    python
    pip
    node
    npm
    yarn
    vscode
    extract
    z
    colored-man-pages
    command-not-found
    copyfile
    copypath
    dirhistory
    history
    jsontools
    web-search
    autojump
    thefuck
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    fast-syntax-highlighting
    zsh-history-substring-search
    you-should-use
)

source $ZSH/oh-my-zsh.sh

# User configuration

# Export
export EDITOR='vim'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Conda 环境支持
if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source "/opt/conda/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# Aliases
alias ll='lsd -alF'
alias la='lsd -A'
alias l='lsd -CF'
alias ls='lsd'
alias tree='lsd --tree'
alias cat='batcat'
alias find='fd'
alias grep='rg'
alias top='htop'
alias lg='lazygit'
alias vim='nvim'
alias python='python3'
alias pip='pip3'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git rebase'
alias glog='git log --oneline --graph --decorate'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dexec='docker exec -it'

# Python aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# Conda aliases
alias ca='conda activate'
alias cda='conda deactivate'
alias cenv='conda env list'
alias cinfo='conda info'

# Node.js aliases
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'

# System aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias h='history'
alias c='clear'
alias e='exit'
alias reload='source ~/.zshrc'

# Root 用户特定别名
alias reboot='systemctl reboot'
alias shutdown='systemctl poweroff'
alias services='systemctl list-units --type=service'
alias logs='journalctl -f'

# Functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

# Auto completion
autoload -U compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load additional configurations
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Root 用户提示
if [[ $EUID -eq 0 ]]; then
    echo "⚠️  当前为 root 用户，请谨慎操作"
fi
EOF

    log_success ".zshrc 配置完成"
}

# 配置 Git
configure_git() {
    log_info "配置 Git..."

    # 配置 delta 作为 git diff 工具
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default

    # Root 用户 Git 安全配置
    git config --global --add safe.directory '*'

    log_success "Git 配置完成"
}

# 设置 Zsh 为默认 Shell
set_default_shell() {
    log_info "设置 Zsh 为默认 Shell..."

    # 检查 /etc/shells 中是否包含 zsh
    if ! grep -q "$(which zsh)" /etc/shells; then
        echo "$(which zsh)" >> /etc/shells
    fi

    # 设置 root 用户的默认 shell
    chsh -s $(which zsh) root

    log_success "Zsh 已设置为默认 Shell"
}

# 显示安装完成信息
show_completion_info() {
    log_success "=========================================="
    log_success "Oh My Zsh 和插件安装完成！"
    log_success "=========================================="
    echo
    log_info "安装的插件："
    echo "  • zsh-autosuggestions (自动建议)"
    echo "  • zsh-syntax-highlighting (语法高亮)"
    echo "  • zsh-completions (自动补全增强)"
    echo "  • fast-syntax-highlighting (快速语法高亮)"
    echo "  • zsh-history-substring-search (历史搜索)"
    echo "  • you-should-use (别名提醒)"
    echo
    log_info "安装的工具："
    echo "  • Powerlevel10k 主题"
    echo "  • lazygit (Git GUI)"
    echo "  • delta (Git diff 增强)"
    echo "  • lsd (ls 增强版)"
    echo "  • bat (cat 增强版)"
    echo "  • exa (ls 替代品)"
    echo "  • fd (find 替代品)"
    echo "  • ripgrep (grep 替代品)"
    echo "  • fzf (模糊搜索)"
    echo
    log_info "Root 用户特殊配置："
    echo "  • 已添加系统管理别名"
    echo "  • 已配置 Git 安全目录"
    echo "  • 已支持 Conda 环境"
    echo
    log_info "使用说明："
    echo "  1. 重启终端或运行: exec zsh"
    echo "  2. 首次启动会提示配置 Powerlevel10k 主题"
    echo "  3. 运行 'p10k configure' 可重新配置主题"
    echo "  4. 查看所有别名: alias"
    echo
    log_warning "如果遇到问题，请查看备份文件: ~/.zshrc.backup.*"
}

# 主函数
main() {
    echo "=========================================="
    echo "Oh My Zsh 一键安装脚本 (Root 版本)"
    echo "=========================================="
    echo

    log_warning "检测到 root 用户，继续安装..."

    check_network
    install_dependencies
    install_oh_my_zsh
    install_powerlevel10k
    install_plugins
    install_extra_tools
    configure_zshrc
    configure_git
    set_default_shell
    show_completion_info
}

# 运行主函数
main "$@"
```