
## 1-Intro

- [Jetbrain k2 原文](https://mp.weixin.qq.com/s/-0nVUMyiIJKgEJy_8kZNRQ)


> Kotlin 2.0 

- 拥有稳定的 `K2` 编译器
- 从根本上支持多平台, `KMP` 支持 `Server` `Web` `Desktop` `IOS` `Andriod` 上共享代码
	- [KMP QuickStart](https://www.jetbrains.com/help/kotlin-multiplatform-dev/get-started.html)
- 编译速度 可能提高了快1倍
- `K2` 模式, 目前处于 `Alpha` 阶段. 
	- 代码高亮显示速度提高了 1.8 倍
	- 代码补全速度提高了 1.5 倍
	- [开启K2 模式](https://mp.weixin.qq.com/s/NpyVgVihD0-HOLtiVox42Q)
	- Kotlin 编译器同时在 `IDE` 中作为代码分析引擎, `K2` 主要用来提升 `IDE` 的一些体验
- 更智能的代码分析: ? 
- 迁移的稳定性， 官方有一些数据.
	- 测试超过了 `1000W` 行的代码
	- 是目前质量最高的版本
	- [迁移指南](https://kotlinlang.org/docs/k2-compiler-migration-guide.html)


> 相关文章


- Kotlin 2.0.0 最新变化：
    https://kotlinlang.org/docs/whatsnew20.html  
- K2 编译器迁移指南：
    https://kotlinlang.org/docs/k2-compiler-migration-guide.html  
- K2 编译器之路：
    https://blog.jetbrains.com/zh-hans/kotlin/2021/10/the-road-to-the-k2-compiler/  
- K2 编译器性能基准以及如何在项目中测量性能：
    https://blog.jetbrains.com/zh-hans/kotlin/2024/05/k2-compiler-performance-benchmarks-and-how-to-measure-them-on-your-projects/  
- Android 支持 Kotlin Multiplatform 以在移动、Web、服务器和桌面平台之间共享业务逻辑：
    https://android-developers.googleblog.com/2024/05/android-support-for-kotlin-multiplatform-to-share-business-logic-across-mobile-web-server-desktop.html  
- Jetpack Compose 编译器迁移到 Kotlin 仓库：
    https://android-developers.googleblog.com/2024/04/jetpack-compose-compiler-moving-to-kotlin-repository.html




## 2-Migration Guide

> 新的架构

![](https://kotlinlang.org/docs/images/k2-compiler-architecture.svg)



**3个组件**

- `Frontend`: 处理源代码的平台，把源代码翻译为中间表示，也就是所谓的 `IR`, Intermediate Representation . 工作的简单描述如下:
	- 词法分析: 把源代码转换为 `tokens`, 编程的基本单位
	- 语法分析：把 `tokens` 组成 `AST`, 也就是 抽象语法树
	- 语义分析: 检查 语义正确性, 比如类型检查, 变量作用域
	- `IR` 生成
- `IR`
- `IR Backend`: 负责把中间表示翻译为 目标平台的机器码或者字节码，例如 `Server backend`, `Js backend` ... 等等，简单来说可能包含如下的内容:
	- 平台相关优化 (`Platform-specific Optimization): 对中间表示 进行特定平台的优化, 例如指令选择， 寄存器分配等等
	- 代码生成 (`Code-Generation`): 将优化后的中间表示 转换为目标平台的代码, 如`JVM` 字节码, `JavaScript` 代码, 或者原生的机器码.
	- 链接 (`Linking`): 把生成的代码和外部模块连接起来, 生成最终的可执行文件或者可以运行的程序



> 新架构目标表现的优点


1. 改进的调用解析和类型推断, 在所有的平台 编译器表现的更加的一致
2. 更容易引入 语法糖，对 `Jetbrain` 团队的帮助
3. 更快的编译时间
4. `IDE` 性能增强
5. ...



 > 在 `MAVEN` 中支持 `K2`.  

[在 maven 中开启k2 的官方文档](https://kotlinlang.org/docs/maven.html#compile-kotlin-and-java-sources)

 
```xml
<properties>
    <kotlin.version>2.0.0</kotlin.version>
</properties>


<plugins>
    <plugin>
        <artifactId>kotlin-maven-plugin</artifactId>
        <groupId>org.jetbrains.kotlin</groupId>
        <version>2.0.0</version>
    </plugin>
</plugins>


<dependencies>
    <dependency>
        <groupId>org.jetbrains.kotlin</groupId>
        <artifactId>kotlin-stdlib</artifactId>
        <version>${kotlin.version}</version>
    </dependency>
</dependencies>
```


> 在 `GRADLE` 中支持 `K2`


[参考文章](https://kotlinlang.org/docs/gradle-configure-project.html)



## 3-K2 Compiler


1. 新的类型推理算法: `1.4.0` 稳定了
2. 新的 `JVM` `IR` 后端: `1.5.0` 稳定了
3. 新的 `JS IR` 后端: `1.6.0` 中稳定了
4. 新的 `Frontend`. 

在下面的视频中详细解释了 原理: [视频地址](https://youtu.be/iTdJJq_LyoY)

