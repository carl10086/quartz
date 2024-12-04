
#tool 



## 1-Intro


> 最近装  `mac` 的次数有点多，备份整体记录一下大致的步骤.


> 抹掉磁盘，然后重装系统

[抹掉并重新安装 `Macos`](https://support.apple.com/zh-cn/guide/mac-help/mh27903/mac)



> [!NOTE] Tips
> 科学上网: 这个最好放到第一步, 科学上网的前提是先科学上网，哈哈


> 安装常见的工具


- `homebrew`
- [iterm](https://iterm2.com/)
- [raycast](https://www.raycast.com/): 把 `mac` 能想到的一切都变为 快键命令
- [zsh + ohmyzsh](https://github.com/ohmyzsh)
- [fishshell](https://fishshell.com/): `fun`, 可以直接使用


> Vim 

- [spacevim](https://spacevim.org/): 有点难用，适合自己特别懒的时候, `vim` 当 `ide` 一堆插件就挺烦的
- [Neovim](https://neovim.io/): 现代化的 vim，内置 `lua`
- [The ultimate vimrc](https://github.com/amix/vimrc): 还不错
	- 基础版本: **不是特别熟练，建议 basic 版本**
	- 进阶版本:  一堆好用的插件, 比较建议

> jdk

- [sdkman](https://sdkman.io/): 统一管理各种基于 `jvm` 的语言 版本.

```sh
# 兼容默认的 env
➜  projects echo $JAVA_HOME
/Users/carlyu/.sdkman/candidates/java/current
```


> Oh-My-Zsh 常见工具


- [Plugin-Wikis](https://github.com/ohmyzsh/ohmyzsh/wiki/plugins) : 常见的都有.
- 目前用的比较多的: `git zsh-autosuggestions kubectl history-search-multi-word zsh-autocomplete)`


> gradle 配置


需要配置2个文件.

一个是代理.

```sh
(base) ➜  .gradle cat gradle.properties
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7890
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=7890
```

一个是 `repo` 

```sh
(base) ➜  .gradle cat init.gradle
buildscript {
    repositories {
        // maven { url 'https://nexus.xxxx.cn/repository/backend-public' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/jcenter' }
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        mavenLocal()
        mavenCentral()
    }
}

allprojects {
    repositories {
        //  maven { url 'https://nexus.xxxx.cn/repository/backend-public' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/jcenter' }
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        mavenLocal()
        mavenCentral()
    }
}
```


