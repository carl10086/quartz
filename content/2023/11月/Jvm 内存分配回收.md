


## 1-Jvm 分配对象的基本原理


> 源码位于: ./hotspot/src/share/vm/interpreter/bytecodeInterpreter.cpp


```c
	CASE(_new): {
        u2 index = Bytes::get_Java_u2(pc+1);
        ConstantPool* constants = istate->method()->constants();
					// 1. 断言确保是 klassOop 和 instanceKlassOop, 下面2个 assert 
        if (!constants->tag_at(index).is_unresolved_klass()) {
          // Make sure klass is initialized and doesn't have a finalizer
          Klass* entry = constants->slot_at(index).get_klass();
          assert(entry->is_klass(), "Should be resolved klass");
          Klass* k_entry = (Klass*) entry;
          assert(k_entry->oop_is_instance(), "Should be InstanceKlass");
          InstanceKlass* ik = (InstanceKlass*) k_entry;
						
						// 2. 确保当前的类型经过了初始化阶段
          if ( ik->is_initialized() && ik->can_be_fastpath_allocated() ) {
							// 获取对象的长度
            size_t obj_size = ik->size_helper();
            oop result = NULL;
            // If the TLAB isn't pre-zeroed then we'll have to do it
						 // 记录是否将所有的对象的字段初始化为零值
            bool need_zero = !ZeroTLAB;
							// 如果是要在 TLAB 中分配对象
            if (UseTLAB) {
              result = (oop) THREAD->tlab().allocate(obj_size);
            }
            if (result == NULL) {
								// 表明需要去 堆中分配对象 . 
              need_zero = true;
              // Try allocate in shared eden
							// 开始准备进去循环模式
        retry:
              HeapWord* compare_to = *Universe::heap()->top_addr();
              HeapWord* new_top = compare_to + obj_size;
              if (new_top <= *Universe::heap()->end_addr()) {
										// 通过 CAS 指令分配空间. 失败会调到 retry . 
                if (Atomic::cmpxchg_ptr(new_top, Universe::heap()->top_addr(), compare_to) != compare_to) {
                  goto retry;
                }
                result = (oop) compare_to;
              }
            }

							// result 不为空表示分配成功
            if (result != NULL) {
              // Initialize object (if nonzero size and need) and then the header
									// 表示要初始化零值
              if (need_zero ) {
                HeapWord* to_zero = (HeapWord*) result + sizeof(oopDesc) / oopSize;
                obj_size -= sizeof(oopDesc) / oopSize;
                if (obj_size > 0 ) {
                  memset(to_zero, 0, obj_size * HeapWordSize);
                }
              }
								// 如果要使用偏向锁
              if (UseBiasedLocking) {
                result->set_mark(ik->prototype_header());
              } else {
								
                result->set_mark(markOopDesc::prototype());
              }
              result->set_klass_gap(0);
              result->set_klass(k_entry);
								// 将对象引用放入到栈中、继续执行下一条指令
              SET_STACK_OBJECT(result, 0);
              UPDATE_PC_AND_TOS_AND_CONTINUE(3, 1);
            }
          }
        }
        // Slow case allocation
        CALL_VM(InterpreterRuntime::_new(THREAD, METHOD->constants(), index),
                handle_exception);
        SET_STACK_OBJECT(THREAD->vm_result(), 0);
        THREAD->set_vm_result(NULL);
        UPDATE_PC_AND_TOS_AND_CONTINUE(3, 1);
      }
```


1. 要先初始化 `KClass`, 这个信息在常量池中, 一般是双亲委任 类加载机制 ;
2. 对象的长度通过 `size_helper` 这个函数获取, 细节很多 ;
3. 对象的分配大致经过如下的三个路径:
	1. `Fast Allocate with TLAB`: 在 `Thread Local Allocation Buffer` 中优先分配, 这个结构的作用是用来减少 并发冲突的 ;
	2. 如果 `TLAB` 失败则降级为 乐观锁分配内存，不断地通过 `CAS` 操作去尝试 `SWAP` 堆顶的指针, 成功的线程即可成功 分配内存 ;
	3. 上面再失败则是通过 更复杂的机制了, `InterpreterRuntime::_new` ,会涉及到 通用对象的分配path，例如锁机制等等
	
4. 内存分配了，就要给字段设置 0值并设置对象头信息, 其中包含了如下的元数据:
	1. 对象所属类的信息
	2. 如果找到类的元信息
	3. 对象的 `Hashcode`, 实际的计算会后置到真正调用 `Object::hashCode` 的时候计算
	4. 对象的 `GC` 分代年龄
	5. ....

5. 零值分配后通过 `invokespecial` 指令来触发 `init` 方法, 也就是对象的构造器


> 我们用 一个 `demo` 来输出一个类的内存信息.

对象的内存布局分为三个区域:

1. 对象头
2. 实例数据
3. `padding` 信息


```java
public static class B {
    Object o;
    int e;
    //    @sun.misc.Contended("first")
    int f;
    //    @sun.misc.Contended("first")
    int g;
    //    @sun.misc.Contended("last")
//    int i;
    //    @sun.misc.Contended("last")
//    int k;
  }


public static void main(String[] args) {
    System.out.println(VM.current().details());
    System.out.println(ClassLayout.parseClass(B.class).toPrintable());

    B b1 = new B();
    B b2 = new B();
    System.err.println(VM.current().sizeOf(b1));
    System.err.println(VM.current().addressOf(b1));

    System.err.println(VM.current().sizeOf(b2));
    System.err.println(VM.current().addressOf(b2) - VM.current().addressOf(b1));

  }
```

```
com.ysz.dm.fast.basic.jol.Jol_Dm_001$B object internals:
OFFSET  SIZE               TYPE DESCRIPTION                               VALUE
0    12                    (object header)                           N/A
12     4                int B.e                                       N/A
16     4                int B.f                                       N/A
20     4                int B.g                                       N/A
24     4   java.lang.Object B.o                                       N/A
28     4                    (loss due to the next object alignment)
Instance size: 32 bytes
Space losses: 0 bytes internal + 4 bytes external = 4 bytes total

32 // 对象 A 的大小
31877408928
32 // 对象 B 的大小
32 // 对象 B 和 对象 A 的偏移
```


通过分析输出有如下结论:

- 对象头占据了 `12Bytes`, 非常的占内存，这从侧面说明了 `fastutil` 这种原生类型库的作用 ;
- `Object` 占据了 `4Bytes`, 这个是使用了 **对象头压缩技术**, 如果分配的 `JVM` 超过 `32G`, `4Bytes` 无法代表这么多内存，会变为 `8Bytes`  ;
- 字段的布局被重新排序了, `o` 分配了最下面. 一般重排序的规则是 大的在前面，然后按照类型 ;
- 因为 `padding` 占据了 `4Bytes`, `Hotspot` 要保证是 `8Bytes` 的整数倍 ;


## 2-三色标记法 和 CMS GC


> 前置

你需要知道  `GC` 的基本理论，分代，`sweep`, `compact` , 引用计数和可达性分析 ;

以下是个人理解.

> 三色是哪三色

- 白色: 收集器没有访问过的对象
- 灰色: 收集器访问的中间状态，假设一个对象有3个引用，只要这3个引用有一个没有被访问，就是灰色状态
- 黑色：收集器访问过 它和它的所有引用

> 三色标记法的理论，类似 `bfs`

1. 所有对象都没有访问，因此都是 **白色**
2. 根据规则定义出 `GC Roots`,  作为 `bfs` 的第一层 ; 
3. 层序遍历，取出这一层, 对某个对象 :
	1. 标记为 灰色
	2. 然后取出他们的所有的引用作为子节点，标记为灰色
	3. 所有的子节点标记为灰色后，自己标记为 **黑色**, 代表全部扫描了
4. 当没有 灰色节点的时候，只有 **黑和白**, 白色的就可以干掉了


> 三色标记法并发场景的2个问题

由于在 并发标记的时候，线上应用不会暂停, 所以有2大类问题


第一类:
1. 浮动垃圾: 新生成的垃圾，这个不是特别重要，可以选择下一次再回收 ;
2. 漏扫: 一个对象在并发的过程中从 不是垃圾 -> 垃圾 ;

第二类: 一个对象从 垃圾 ->. 不是垃圾, 这个 **比较严重**, 一定要处理, 下面举个场景:
1. 有一个对象 `A`，一开始是白色的 ;
2. 线程1, 删除了这个引用, (删除引用) ;
3. 线程2 并发的 有一个黑色对象 B, 引用了 A, (增加引用) ;

`CMS` 解决这个问题的思路被称为 `Write Barrier` 技术, 也就是在 对象做引用更新的时候, 会记录下这个数据需要被重新标记 (`ReMark`), 然后再 `Remark` 的时候通过 `STW` 来解决这些增量的问题;



## Refer


- [美团-Java中9种常见的 CMS GC 问题分析和解决](https://mp.weixin.qq.com/s/RFwXYdzeRkTG5uaebVoLQw)
- [知乎-三色标记法](https://zhuanlan.zhihu.com/p/431406707)
- [JDK8在mac-mojo 上编译](https://blog.0xff000000.com/2019/04/26/compile-debug-openjdk8-on-osx/)
- [Mac-Catalina编译 JDK13](https://segmentfault.com/a/1190000020736814)
- [美团-JVM 案例](https://tech.meituan.com/2017/12/29/jvm-optimize.html)
- [唯品会的 JAVA8 调优建议](https://blog.51cto.com/u_15057823/2566170)