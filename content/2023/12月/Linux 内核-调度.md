

## 1-Intro

> 先简单的介绍一下 `Linux` 内核的基本结构.


下图来自 [Linux 内核设计的艺术](https://www.amazon.com/-/zh_TW/%E6%96%B0%E8%AE%BE%E8%AE%A1%E5%9B%A2%E9%98%9F-ebook/dp/B00ETOV4B2)


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231214184200.png?imageSlim)


Linux 是宏内核设计，具体参考 [[架构风格]] 中的 微内核 vs 宏内核 部分:

上图中把 `Linux` 分为了 4层:

1. 驱动管理层: 驱动管理外部的硬件设备, 例如磁盘和网卡 ;
2. 工具层: 内核抽象了一些通用的组件 让自己使用, 例如:
	- 并发中的 锁
	- `per-cpu` 变量
	- 中断库
3. 系统组件, 例如:
	- 进程管理
	- 内存管理
	- 文件系统
	- I/O 管理
	- 网络管理
4. `syscall`, 内核接口, 给 开发人员提供的接口层，会包装为 壳函数, 即使包装了一层，也要开发人员对操作系统的原理有比较深的认识，所以 一般都是使用一些 库，例如大名鼎鼎的 [glibc](https://www.gnu.org/software/libc/sources.html)


> 进程的大致历史

1. 程序和文件都是存在 磁盘里的 ;
2. 运行的程序 会用一部分内存，`CPU` 通过读写内存进行计算 ;
3. 内存大大小有限，远远小于磁盘，所以一般会按需加载 ;
4. 进程没有能力一直占据 `CPU`, 例如在执行 磁盘 `IO` 或者 网络 `IO` , 为了提供利用率，所以引入了多进程 ;
5. 多个进程之间的通信比较复杂，所以引入 线程(共享地址空间) ;
6. 如果是 `IO` 密集型的应用, 就算是引入大量线程， 也不一定可以真正的提高 `CPU` 的利用率，反而浪费了内存资源 和 增加线程的切换开销. 所以 引入了 轻量级的 协程, 一个线程对应多个 协程(或者虚拟线程) 就能提高这 `CPU` 的利用率 . 但是操作系统对 协程是无感知的，需要手动在用户空间调度 ;

## 2-coroutine

> 随着 Loom , coroutine 近些年兴起


> 协程的工作类似如下的 生产者-消费者

```Python
import time

def consumer():        # 消费者
    r = ''             # 初始化返回值
    while True:
        n = yield r    # 在此处暂停，返回r给生产者，等待下一次send来恢复执行
        if not n:
            return
        print(f'[CONSUMER] Consuming {n}...')
        time.sleep(1)
        r = '200 OK'   # 此处决定了下一次yield时的返回值

def produce(c):        # 生产者
    next(c)            # Python3中使用next(c)启动生成器
    n = 0
    while n < 5:
        n = n + 1
        print(f'[PRODUCER] Producing {n}...')
        r = c.send(n)  # 此处向消费者yield的位置发送数据，并接收yield的返回值
        print(f'[PRODUCER] Consumer return: {r}')
    c.close()          # 关闭生成器

if __name__=='__main__':
    c = consumer()
    produce(c)

```

- `Producer` 和 `Consumer` 是同一个线程上2个协程，他们通过合作的方式来生成数据
- `yield` 和 `next`:
	- `yield` 会放弃掉当前线程的使用权, 直到 `producer` 使用 `send`

> C 本身不支持协程，需要 基于一些库实现


- [libaco](https://github.com/hnes/libaco): 参考 `Golang` 的实现
- [libdill](https://github.com/sustrik/libdill): 更进一步，多了 `structured concurrency` 的能力
- ... 


下面用一个例子说明协程.

```c
#include "aco.h"    
#include <stdio.h>

// this header would override the default C `assert`;
// you may refer the "API : MACROS" part for more details.
#include "aco_assert_override.h"

void foo(int ct) {
    printf("co: %p: yield to main_co: %d\n", aco_get_co(), *((int*)(aco_get_arg())));
    aco_yield();
    *((int*)(aco_get_arg())) = ct + 1;
}

void co_fp0() {
    printf("co: %p: entry: %d\n", aco_get_co(), *((int*)(aco_get_arg())));
    int ct = 0;
    while(ct < 6){
        foo(ct);
        ct++;
    }
    printf("co: %p:  exit to main_co: %d\n", aco_get_co(), *((int*)(aco_get_arg())));
    aco_exit();
}

int main() {
	// 1. 初始化线程，并创建关联的 主协程
    aco_thread_init(NULL);

    aco_t* main_co = aco_create(NULL, NULL, 0, NULL, NULL);
    aco_share_stack_t* sstk = aco_share_stack_new(0); // 共享堆栈

    int co_ct_arg_point_to_me = 0;
    aco_t* co = aco_create(main_co, sstk, 0, co_fp0, &co_ct_arg_point_to_me); // 子协程

    int ct = 0;
    while(ct < 6){
        assert(co->is_end == 0);
        printf("main_co: yield to co: %p: %d\n", co, ct);
        aco_resume(co);
        assert(co_ct_arg_point_to_me == ct);
        ct++;
    }
    printf("main_co: yield to co: %p: %d\n", co, ct);
    aco_resume(co);
    assert(co_ct_arg_point_to_me == ct);
    assert(co->is_end);

    printf("main_co: destroy and exit\n");
    aco_destroy(co);
    co = NULL;
    aco_share_stack_destroy(sstk);
    sstk = NULL;
    aco_destroy(main_co);
    main_co = NULL;

    return 0;
}
```

- 协程: 这里 把协程看成 用户态的线程，有自己的 栈空间, 执行上下文, 他们的切换在纯粹的内核态 ;
- 协程的上下文切换成本是很低的: 通过保存 和恢复 程序的执行环境，`PC 寄存器`, `SP 寄存器` , 库中使用了 汇编，性能是不错的 ;
- 这个库特殊的地方 是每个线程会有一个 特殊的 **主协程**, 他的作用 就是 **在子协程退出的时候保存线程的上下文**, 在协程切换的时候 恢复上下文 ;
- `libaco` 的 内存成本非常低，这因为 **共享的栈**, 多个协程可以共享一个栈空间, 但是运行的时候只有一个协程会使用这个栈, 这个可以大大节省内存, 我们可以创建大量的 协程 ;


## 3-schedule


> 调度核心源码位于函数. `__sched notrace __schedule(bool preempt)`

核心逻辑: 非常简单，查找 `next`  要执行的进程, 然后切换上下文

1. 关闭内核的抢占，初始化变量.
	- `rq` 关联到 当前 `CPU` 的运行队列
	- `RCU` 更新
	- 获取到 队列的 自旋锁, `spinlock`, 为查找可运行进程做准备
2. 检查 `prev` 的状态
3. `task_on_rq_queued(prev)` , 把 prev 的进程插入到 队列尾部
4. `pick_next_task`: 选择下一个要执行的进程
5. `context_switch(rq. prev, next)` 进行进程的上下文切换


> [!NOTE] Tips
> 系统会使用  中断机制来周期性的触发调度算法，来完成进程的切换. 比如 250 HZ 就是代表 1s 中断 250次，一次4ms 左右. 同时 你的应用代码 sleep(1毫秒) 则是另外的机制, 叫做 `hrtimer` 高精度定时器来实现，在 1毫秒之后唤醒 应用.



> 调度


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231215144823.png?imageSlim)


1. `rq`:  每个 `CPU` 有一个, 代表了 可运行的队列, 其中包含了 自旋锁, 进程数量，正在运行的进程描述符, 虽然是个队列，但是 结构是 红黑树 ;
2. `cfs_rq`:  封装了 cfs 红黑树的根节点, 正在运行的进程指针，负载均衡的叶子节点 ;
3. `sched_entity`: `kenel schedule entity`， 对调度实体的封装, 可以是 进程, 进程组, 线程等一切可以被调度单位，所以从调度上是没有区别 ;
4. `sched_class`: 调度算法的封装 ;


>  需要切换的场景: 不是所有的 schedule 都需要切换，大多数不切换

1. 进程分配的 `CPU` 用完 ;
2. 进程主动 放弃 `CPU` , `IO` 操作结束 ;
3. 其他进程抢占了 `CPU`



Linux 的没有直接使用 `CPU` 自带的切换, 自己用汇编写了个. 这里我们加了注释


```c
#define switch_to(prev, next, last) \
do { \
    unsigned long ebx, ecx, edx, esi, edi; \
    asm volatile( \
        "pushfl\n\t"                /* 将 flags 寄存器的值压入 prev 进程的栈 */ \
        "pushl %%ebp\n\t"           /* 将 ebp 寄存器的值压入 prev 进程的栈 */ \
        "movl %%esp,%[prev_sp]\n\t" /* 将 esp 寄存器的值保存到 prev 进程的 thread.sp 字段 */ \
        "movl %[next_sp],%%esp\n\t" /* 载入 next 进程的 thread.sp 字段到 esp 寄存器， 切换到 next 进程的栈 */ \
        "movl $1f,%[prev_ip]\n\t"   /* 将下一条指令的地址保存到 prev 进程的 thread.ip 字段 */ \
        "pushl %[next_ip]\n\t"      /* 将 next 进程的 thread.ip 字段值压入栈，这是下一条要执行的指令 */ \
        __switch_canary \
        "jmp __switch_to\n"   /* 跳转到 __switch_to 函数。接下来在 next 进程的上下文中执行 */ \
        "1:\t" \
        "popl %%ebp\n\t"             /* 从栈中恢复 ebp 寄存器的值 */ \
        "popfl\n"                    /* 从栈中恢复 flags 寄存器的值 */ \
\
        /* 输出参数 */ \
        [prev_sp] "=m" (prev->thread.sp), \
        [prev_ip] "=m" (prev->thread.ip), \
        "=a" (last), \
        "=b" (ebx), "=c" (ecx), "=d" (edx), \
        "=S" (esi), "=D" (edi) \
        __switch_canary_oparam \
        /* 输入参数 */ \
        [next_sp]  "m" (next->thread.sp), \
        [next_ip]  "m" (next->thread.ip), \
        [prev]     "a" (prev), \
        [next]     "d" (next) \
        __switch_canary_iparam \
        : "memory"); \
} while (0)

```


关于栈:

- 一个 **栈桢** 代表了一个函数调用，调用开始在栈上分配一桢，结束则移除一帧
- user stack 包含如下信息:
	- 函数实参和局部变量: 局部变量和全局变量的区别就是 它的生命周期跟 函数调用相关
	- 函数调用的链接信息, 每个函数都会用到 `CPU` 寄存器，例如 **程序计数器**, 指向了下一条将要执行的机器语言指令

## 4-Design


常见的中间件:

- `Memcached` 用的是线程池 ;
- `Redis` 用的是单线程 ;
- `Nginx` 认为只要工作进程数量 = `CPU` 个数，就能实现最大的高并发 ;


常见的 **业务代码**:

- `Request Per Thread`: `Java`  的 `Loom`  就是为了这种模式而打造的
- `Go Routine` 或者 `Kotlin Routine`: 这种 是为了 异步 `IO` 的 `Style` 而设计的， `Golang`  使用的模模型是 基于共享内存通信, Communicate by shared memory, 其中 Channel 是基本的同步原语, 而 `Kotlin` 的实现则更复杂，配合 [struct concurrent](https://en.wikipedia.org/wiki/Structured_concurrency) 的范式




## Refer


- [Linux 内核设计的艺术](https://www.amazon.com/-/zh_TW/%E6%96%B0%E8%AE%BE%E8%AE%A1%E5%9B%A2%E9%98%9F-ebook/dp/B00ETOV4B2)
- [Linux 内核分析和应用](https://www.amazon.com/Linux%E5%86%85%E6%A0%B8%E5%88%86%E6%9E%90%E5%8F%8A%E5%BA%94%E7%94%A8-Linux-Unix%E6%8A%80%E6%9C%AF%E4%B8%9B%E4%B9%A6-Chinese-%E9%99%88%E7%A7%91-ebook/dp/B07FVL2T8Q)
- [Linux 内核深度解析](https://www.amazon.ca/Linux%E5%86%85%E6%A0%B8%E6%B7%B1%E5%BA%A6%E8%A7%A3%E6%9E%90/dp/7115504113)
- [Linux-examples](https://github.com/lingqi1818/analysis_linux)
