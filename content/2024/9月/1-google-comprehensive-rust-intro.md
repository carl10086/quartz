

## refer


- [comprehensive-rust](https://github.com/google/comprehensive-rust?tab=readme-ov-file) : 这个教程有点酷



## 1-Intro


> Rustc

- 使用 `LLVM` 作为后端, `rustc` 生成的是 `LLVM` 的中间表示，然后由 `llvm` 转化为可执行的目标代码. 
- `rustc` 用来编译 `rust` 源码的，实现了 `bootstrapping`, `rustc` 也是由 `rust` 写的


> Rust 的独特

`rust` 的定位类似于  `C++` ,有运行时和垃圾收集

编译时的内存安全: 在编译的时候

- 不存在未初始化的变量
- 不存在 "双重释放"
- 不存在 "释放后使用"
- 不存在 `NULL` 指针
- 不存在被遗忘的互斥锁
- 不存在线程之间的数据竞争
- 不存在迭代器失效

没有未定义的运行时行为: 每个 `Rust` 语句都有明确的定义


现代语言的功能:

- 枚举和模式匹配
- 泛型
- 无额外开销的外部函数接口
- 零成本抽象
- 强大的编译器错误提示
- 内置依赖管理器
- 对测试的内置支持
- ....






