

## 1-概述



> [!NOTE] Tips
> 下面的代码大多数拷贝自 `Linux 4.x` 的内核源码. 你懒的去找，可以从 [my_linux4](https://github.com/carl10086/my_linux4) `CLONE`


> 并发: 并发是 `CPU` 的问题. 多个 `CPU` 共享资源的问题.


以 `i++` 为例子: 他分解为三个操作

1. 多个 `CPU` 可能执行了一个原子操作的不同部分
2. 多个 `CPU` 之间的缓存是独立的, `CPU` 中共享资源的数据  视图不是全局一致的
	-  所有 `CPU` 共享的在 `RAM`, 称为 `L3`
	-  一个物理核有2个逻辑核 共享 `L2`
	- 每个逻辑核自己的 `L1`

一个有趣的问题. 单核会造成不一致吗, **个人不是很确定**.

单核也可以多支持并发这是肯定的. 

1. 线程A 进行 `i++` , 最后一步的 写入 i 到内存的时候，假设触发了中断，操作系统的 `scheduler` 挂起了这个操作 ;
2. 线程B 进行 `i++` 正常操作
3. 线程A 恢复了 寄存器，栈桢，进行最后一步  i 写入指令，**会有问题吗?**


> 从 Linux 操作系统的角度，为了解决并发, 提供了 如下的东西


1. `CPU` 硬件一般支持的原子变量 `Atomic`: **保证操作的不可中断性**
2. 自旋锁, `Spin_lock`, 这个是通过 **忙等** `busy-wait` 的技巧去阻塞线程的低开销锁, **适合锁的非常短**
3. 代码临界区控制, 不能进入区域的线程进入 **睡眠状态**, 而不是忙等:
	- 信号量, `Semaphore` , 计数器, 可以精确的控制并发
	- 互斥锁, `Mutex`
	- 读写锁, `Rw-lock`
	- 抢占, `Preempt`


4. `CPU` 缓存的角度有, `per-cpu` 变量, 类似 `ThreadLocal` (不过 `Java` 应该是在堆内存中模拟的吧?), **也许最好的方案就是没有 共享资源**


5. 从内存的角度:
	-  为了多个 `CPU` 访问内存的 效率，提供了 `RCU` **机制**，类似 `CopyOnWrite`  机制 让写操作和读操作在无锁的情况下同时发生, **适合 读操作远远多于写操作**
	-  为了多个 `CPU` 访问内存的有序性，提供了 `Memory Barrier` **机制**, `JVM` 在 `Happen Before` 和 `GC` 三色标记都用了内存屏障



> [!NOTE] Tips
> 当然，最有效的手段还是 能不并发就不并发，尽可能的减少 共享的边界，比如说 `Netty` 基于的封闭模型设计




## 2-原理
### 2-1 Atomic


> 原子变量的实现 是 硬件级别的


- `i++` 从单个操作，变为了一个指令，同时注意在 多核环境下，操作系统会自动的 锁主总线


由于是硬件级别的我们 看一下 `Intel 开发手册`, 如下的指令都支持 原子操作:


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240104153802.png?imageSlim)


> 我们一路 `Debug` Linux 内核的源码.


可以在 `linux/arch/x86/include/asm/atomic64_64.h` 中找到:

```c
/**
 * arch_atomic64_add - add integer to atomic64 variable
 * @i: integer value to add
 * @v: pointer to type atomic64_t
 *
 * Atomically adds @i to @v.
 */
static __always_inline void arch_atomic64_add(long i, atomic64_t *v)
{
	asm volatile(LOCK_PREFIX "addq %1,%0"
		     : "=m" (v->counter)
		     : "er" (i), "m" (v->counter));
}

/**
 * arch_atomic64_sub - subtract the atomic64 variable
 * @i: integer value to subtract
 * @v: pointer to type atomic64_t
 *
 * Atomically subtracts @i from @v.
 */
static inline void arch_atomic64_sub(long i, atomic64_t *v)
{
	asm volatile(LOCK_PREFIX "subq %1,%0"
		     : "=m" (v->counter)
		     : "er" (i), "m" (v->counter));
}

```

- `LOCK_PREFIX` 就是 `lock` 指令的前缀, 所有这个指令的命令会 主动的去锁总线, 防止 其他的核(物理CPU or 逻辑CPU) 去访问相应的内存位置


> [!NOTE] 个人理解
> 看上去是一个操作， 从源码看还是三个操作, 通过 LOCK 锁总线的玩法 把三个指令一起执行， **彷佛是原子性的一个操作**


- 上面的 `volatile` 就是 `Java` 的那个 `volatile` , 这里用来防止 脏读，去掉了编译器优化， 修改后的值确保 `RAM`  中的 内存可见性



### 2-2 SpinLock

> 自旋锁技术


自旋锁 会在当前的线程中 不停地执行循环体, 而不改变线程的运行状态, 所以响应的速度更快.

这个锁能看出来，可以不用进行上下文切换的内核流程，是用忙等来模拟，属于浪费 `CPU` 资源. 所以他保护的临界区一定要小，锁的时间一定要特别短，有 `IO`, 网络这种操作一定不要用. 单位最好是毫秒.

这个技术好像 `Java` 的偏向锁 升级为 轻量锁的时候也是忙等, 最后再是自动的升级为 重量级锁.



> 源码

- `include/asm-generic/qspinlock.h`

```c
/*
 * Remapping spinlock architecture specific functions to the corresponding
 * queued spinlock functions.
 */
#define arch_spin_is_locked(l)		queued_spin_is_locked(l)
#define arch_spin_is_contended(l)	queued_spin_is_contended(l)
#define arch_spin_value_unlocked(l)	queued_spin_value_unlocked(l)
#define arch_spin_lock(l)		queued_spin_lock(l)
#define arch_spin_trylock(l)		queued_spin_trylock(l)
#define arch_spin_unlock(l)		queued_spin_unlock(l)

/**
 * queued_spin_trylock - try to acquire the queued spinlock
 * @lock : Pointer to queued spinlock structure
 * Return: 1 if lock acquired, 0 if failed
 */
static __always_inline int queued_spin_trylock(struct qspinlock *lock)
{
	if (!atomic_read(&lock->val) &&
	   (atomic_cmpxchg_acquire(&lock->val, 0, _Q_LOCKED_VAL) == 0))
		return 1;
	return 0;
}

extern void queued_spin_lock_slowpath(struct qspinlock *lock, u32 val);

```


思路: 

1. 获取锁大概率成功，不会真的一开始就是自旋, 自旋是 `queued_spin_lock_slowpath` 慢速路径，由 `arch` 下的硬件决定是什么，比如说可能是 `sched_yield` 放弃 `CPU` 也是有可能的. 
2. 通过 `CAS` 原子操作和 内存屏障 的一次尝试，是快速路径，获取锁成功了就返回 1 ;



> [!NOTE] Tips
> 实现取决于 `CPU-ARCH`, 不一定真的要忙等占据 `cpu`, 是慢速路径. 
> `Linux` 源码中只要有 `slowpath`, `unlikely` 等等就代表这个代码大部分情况不会走这里



再深入下去，可以看下图的原理.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240104162139.png?imageSlim)




> [!NOTE] Tips
> 自旋锁很重要，因为 linux 源码中出现最多的就是他，一般其他的锁实现 也都会先尝试使用 自旋锁做一下，不行再走.



### 2-3 Semaphore

源码位于 

```bash
 my_linux4 git:(main) vim include/linux/semaphore.h
```


```c
/* Please don't access any members of this structure directly */
struct semaphore {
	raw_spinlock_t		lock;     /* 自旋锁，用于保护信号量的计数器和等待队列 */
	unsigned int		count;    /* 计数器，信号量的值，当大于0时，down操作不会被阻塞 */
	struct list_head	wait_list;  /* 等待队列，存储等待信号量的任务（task） */
};

```


下面是2个计数器的简化伪代码.

```c
void down(struct semaphore *sem) {
    /* 获取信号量的自旋锁，用于保护信号量的操作 */
    spin_lock(&sem->lock);

    while (sem->count == 0) {  /* 如果计数器为0，需要等待 */
        /* 将当前任务（task）加入到信号量的等待队列 */
        list_add(&current->wait_list, &sem->wait_list);

        /* 释放自旋锁，使其他任务可以获取信号量 */
        spin_unlock(&sem->lock);

        /* 调度函数，让出处理器，等待被唤醒 */
        schedule();

        /* 当被唤醒后重新获取自旋锁，以便安全地操作信号量 */
        spin_lock(&sem->lock);
    }

    /* 当计数器大于0时，减1并释放自旋锁 */
    sem->count--;
    spin_unlock(&sem->lock);
}


void up(struct semaphore *sem) {
    /* 获取信号量的自旋锁，以便安全地操作信号量 */
    spin_lock(&sem->lock);

    /* 将计数器增加1，表示信号量可用 */
    sem->count++;

    if (!list_empty(&sem->wait_list)) { /* 如果等待队列非空，表示有任务等待这个信号量 */
        /* 从等待队列中选择第一个任务 */
        struct task *task = list_first_entry(&sem->wait_list, struct task, wait_list);

        /* 把选中的任务从等待队列中移除，因为它即将获得这个信号量 */
        list_del(&task->wait_list);

        /* 唤醒选中的任务，让其继续运行 */
        wake_up_process(task);
    }

    /* 释放自旋锁 */
    spin_unlock(&sem->lock);
}

```


原理非常简单，我们简单模拟一下信号量=2， 然后来3个线程的场景:

- 线程1 过来，
	- 先拿自旋锁
	- 拿到之后， 因为 `sem->count == 2` 不满足条件
	- 直接减，然后释放锁

拿到锁之后的操作只有一个 `sem->count--` 所以非常快，自旋锁保护就很合适.


- 同理线程2 过来也就成功了

- 线程3来的时候:
	- 满足条件导致进入 `while` 循环.
		- 先把当前的任务放到 等待队列
		- 释放锁, **一定要快**, 
		- 然后 `schedule` 放弃 `cpu`
		- 这里是 `up` 那里 `wake_up_process`, 继续获取锁



> [!NOTE] Tips
> 真正的实现很复杂的，要考虑 超时，信号打断等等等等的情况


### 2-4 Mutex

> 互斥锁： 理解可以是，信号量的简化版本. 但是 `Linux` 的基本原语，是非常严格的.


mutex是Linux内核中的一个基本同步原语，它用于保护临界区，确保一次只有一个线程可以执行它。﻿mutex的语义比较严格，以下是其主要的特性和限制：
	•	同一时间只有一个任务能持有互斥锁
	•	只有互斥锁的持有者才能解锁
	•	不允许多次解锁
	•	不允许递归锁定
	•	必须通过API初始化互斥锁对象
	•	不能通过memset或复制来初始化互斥锁对象
	•	任务不能在持有互斥锁时退出
	•	存储持有的锁的内存区域不能被释放
	•	持有的互斥锁不能被重新初始化
	•	不能在硬件或软件中断上下文（如tasklets和timers）中使用互斥锁
	
当﻿ `DEBUG_MUTEXES` 启用时，以上所有语义都会被严格执行。下面是内核中﻿mutex结构的定义：

```c
struct mutex {
    atomic_long_t       owner;        /* 保存持有该锁的任务的信息 */
    spinlock_t          wait_lock;    /* 用于保护等待队列的自旋锁 */
    #ifdef CONFIG_MUTEX_SPIN_ON_OWNER
    struct optimistic_spin_queue osq; /* MCS自旋锁队列 */
    #endif
    struct list_head    wait_list;    /* 保存等待该互斥锁的任务的队列 */
    #ifdef CONFIG_DEBUG_MUTEXES
    void                *magic;       /* 用于调试 */
    #endif
    #ifdef CONFIG_DEBUG_LOCK_ALLOC
    struct lockdep_map  dep_map;      /* 锁的依赖映射，用于检查死锁 */
    #endif
};
```




> [!NOTE] Tips
> 一个可能有用的东西, `Java` 的 `synchornized` 和 `AQS` 原理上都是基于 `atomic`, 而不是 `mutex`


> Java 的 `sychonized`  语法简述


在对象头中有4种状态，所以刚好 **2个bit**. 藏在对象头里的 `markword` 里.

- `01`: 无锁
- `00`: 轻量锁, `CAS` 失败就 忙等
- `10`: 重量级锁,  `CAS` 失败就 释放 `CPU`
- `11`: 偏向锁: 一个线程无 竞争，无锁

> Java 的 `AQS`, 也就是是一个基于 原子变量 int 状态机，修改失败的扔到一个 `FIFO` 队列

基于这个机制实现了 `ReentrantLock` , `Semaphore`, `CountDownLatch` 等等, 还真的不是 对 `Linux` 内核这些机制的直接封装. 

### 2-5 Read-Write Lock


- **读和读不互斥**
- 写和写互斥
- 写和读互斥

跟上面的实现类似，非常有趣.

```c
typedef struct qrwlock {
	atomic_t cnts;
	arch_spinlock_t wait_lock;
} arch_rwlock_t;
```

- 16 `bit`,  高8表示写计数. 可以看出来原子性变量的核心要点就是 把临界条件搞成1个 

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240104180750.png?imageSlim)


### 2-6 Preempt

这里只介绍概念了

我们知道内核的调度函数是 `schedule`, 你用它代表你要放弃当前的 `CPU`, 从红黑树选择 `vruntime` 最小的 `KSE` 来执行.

有如下情况会触发:

- 时间片用完了
- `IO`
- 抢占, 当前进程直接换掉, 原因是有更紧急的事情要处理，比如说处理键盘输入.

### 2-7 Per-Cpu

使用 `per-cpu` 的变量仅仅在 一个核中可用，属于无锁的玩法
### 2-8 RCU


> RCU: Read copy Update. ; 使用的 `API` 类似读写锁，但是底层是 `CopyOnWrite`. `rcu_read_lock`
等等

1. 读: 无锁，直接读即可(需要不可抢占，保证读的原子性, 现代 `CPU` 直接保证)
2. 写: 原来的老数据需要做一次 `copy`, 然后更新, 底层封装了一个宏包括 内存屏障
3. 回收: 写会造成多个版本的数据, 然后有后台线程回收


> [!NOTE] Tips
> 是不是 mvcc 多版本无锁的味道, 核心就是 不可变数据, 要改就 + 个版本



### 2-9 Memory Barrier

现代编译器的优化很复杂: 可能会改变代码的顺序.

> 使用 barrier() 可以消除 编译器的优化

```c
#define barrier() __asm__ __volatile__("" ::: "memory") 
x = 100;
barrier();
condition = 1;
```

> 使用 volatile 也可以干掉 编译器的优化


## 3- 实战


> Nginx 大量使用原子操作

- `nginx` 本身是多进程架构, 不是常见的多线程.
- `nginx` 通过汇编实现了 `ngx_atomic_cmp_set` , 也就是 `lock` 指令，一样会锁住内存总线.

然后基于自己底层的原子实现， 实现了 自己的信号量，互斥锁. `Nginx` 大佬是真的卷

> Memcached 使用互斥锁


- 主要是 `mutex`， 但是粒度很细，针对每个缓存最小对象级别

> Redis 单线程无锁

- 因为单线程，所以什么都不需要

> Linux-cpu 网络惊群问题

在多线程或者多进程的场景下， 多个线程或者进程在同一个 condition 下休眠，当 notify 唤醒的时候 会同时唤醒他们，但是只有一个 能执行，这个时候会浪费 其他的 `cpu`, 其他的东西处理不好，可能会出现 **提前唤醒的bug, java 的notifyAll 和 wait 就要小心，每次醒来要重新判断一次条件 **


有一些思路:

- `Linux` 通用玩法, 使用队列，每次去唤醒 优先级最高那哥们，比如说 `wake_up_process`
- `linux` 网络中的解决方案, `epoll` 已经解决了，同样保证仅仅唤醒一个

上面说了 `epoll` 已经搞定了，为什么 `nginx` 还是有惊群问题呢?

- 因为 `nginx` 多个 `worker`, 每个都有自己的 `epoll`

`nginx` 解决的方案是用锁, `accept_mutex on;` 默认关闭，因为默认 `worker = cpu 个数`, 就那么几个， 开锁本身导致的性能损失 > 惊群问题.

同样的, `netty` 中 `worker_thread` 中 `NioEventLoop` 数目不能太多了, 默认也是跟 `cpu * 2- 1`, 一样的, `Netty` 实现也是一个 `worker` 一个 `epoll` 实例，会惊群的. 


> Netty-封闭模型

- 额，比较简单，不说了

> Disruptor-CPU false-sharing 伪共享

- `Java8` , `Nginx` 等等都解决了
- `Disruptr` 核心 是 内存使用的时候仅可能的占据 `128Bytes` (看硬件，64Bytes 等等都可能， 128Bytes 比较妥一些)， 也就是 `cache  Line 的单位`, 使用内存填充的方法，让多个线程共享的这个单元尽可能的占据整个 `CacheLine`


具体参考: [酷壳-和程序员有关的缓存知识](https://coolshell.cn/articles/20793.html)






