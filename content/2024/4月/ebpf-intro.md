

## 1-Intro



> 什么是 ebpf


- 全称: Extended Berkeley Packet Filter
- 名字上是一种 **数据包的过滤技术**


其核心是提供了一种仔 内核事件和用户程序事件发生时候 安全注入代码的机制, **基于这种机制** 从而形成了一种 生态，这种生态包含了 内核的方方面面，例如 **网络**, **内核**, **安全**, **tracing**. 而这种扩展 `extending` 之后的 `epf` 就叫做 `ebpf` .



> ebpf 的原理

- 通过 `JIT` 技术，在内核中运行了一个虚拟机, 保证了只有被验证了的 `ebpf` 指令才会被内核执行, *比之前 通过注入hack 内核的方案更加的安全*
- 他的指令依旧在内核中执行，因此不需要通过 壳函数在 用户态和内核态复制数据，所以效率也比较高



> 基于 ebpf 的典型作品


- `Facebook` 开源的 [katran](https://github.com/facebookincubator/katran)
- `Isovalent` 开源的容器网络方案 [cilium](https://cilium.io/)
- 内核排错工具更是有一堆, `bcc`, `bpftrace`

![](https://static001.geekbang.org/resource/image/7d/53/7de332b0fd6dc10b757a660305a90153.png?wh=1500x769)



> [!NOTE] Tips
> 跟历史上 介入内核的方式不同, ebpf 突出一个简单，它本身提供了丰富的接口和工具


## 2-History


- 1992 年, [bpf](https://www.tcpdump.org/papers/bpf-usenix93.pdf) 革命性出现，比当时最快的 包过滤机制还要快20倍.
	- 通过在内核中引入了一个新的虚拟机，所有的指令都在 虚拟机中运行
	- 用户态使用了 `BPF`字节码表达式，*一种声明式的语言*, 然后传递给内核, 由内核虚拟机解释执行



