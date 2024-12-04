


## 1-Intro


背景:

1. 使用了 三方的 `SDK`, 这个 `SDK` 使用了 `JNI` 集成了 豆包的 `C++` SDK
2. 三方团队封装的通过 `Attach` 线程回调


## 2-Actions



用 `MicroMeter` 同时观察了内存和线程.


**线程** 的状态:

1. `NEW` : 初始的状态 ;
2. `RUNNABLE` : 可被调度的状态, 正在 `CPU` 上运行或者 正在等待 `CPU` 的时间片 (`ready` 状态) ;
3. `BLOCKED` : 线程正在等待 监视器的锁 `monitor lock` , 常见于等待进入 `synchronized` 块/方法 ;
4. `WAITING` : 线程无限等待另一个线程执行操作. 例如:
	1. `Object.wait()`
	2. `Thread.join()`
	3. `LockSupport.park()`
5. `TIMED_WAITING` : 现成等待另一个线程的执行操作, 但是有最大的等待时间.
	1. `Thread.sleep(timeout)`
	2. `Object.wait(timeout)`
	3. `Thread.join(timeout)`
	4. `LockSupport.parkNanos()`
	5. `LockSupport.parkUntil()`
6. `TERMINATED` : 线程已经执行完毕



**1)-Waiting 线程很多, runnable 反而不多**

```sh
thread --state runnable
thread --state waiting
```


**2)-从 ZGC 改为 G1 后. gc 可以释放内存**


```sh
vmtool --action forceGc
```


**3)-同时分析 --live 和 没有 live**

```sh
heapdump --live /home/aitogether/ysz/dump.hprof
```


**4)-分析 heapdump 文件**

- `--live` : 代表存活的对象



## 3-JNI 可能的问题


**1)-JNI 有三种引用类型**

`JNI` 中有三种引用类型:

1. 局部引用(`Local References`) :
	1. 自动释放, `native` 方法返回的时候释放
	2. 只在创建他的线程中有效
	3. 阻止对象被 `GC` 回收
	4. 默认最少支持 16 个局部引用
2. 全局引用 (`Global References`)
	1. 需要手动释放
	2. 可以跨方法和线程使用
	3. 阻止对象被 `GC` 回收
	4. 通过 `NewGlobalRef` 创建
3. 弱全局引用 (`Weak Global Reference`)
	1. 需要手动释放
	2. 可以跨方法和线程使用
	3. 不阻止对象被 `GC` 回收
	4. 通过 `NewWeakGlobalRef` 创建



**2)-资源泄露的 DEMO**


**1. 局部引用的泄露**

```c++
// 错误示例 - 循环中未释放局部引用
for (i = 0; i < len; i++) {
    jstring str = (*env)->GetObjectArrayElement(env, arr, i);
    // 使用str
    // 未调用DeleteLocalRef
}

```



**2. 全局引用的泄露**

```c++
// 错误示例 - 创建全局引用后未释放
static jclass cls = NULL;
if (cls == NULL) {
    jclass localCls = (*env)->FindClass(env, "java/lang/String");
    cls = (*env)->NewGlobalRef(env, localCls);
    // 未在适当时机调用DeleteGlobalRef
}
```


**3)-最佳实践**


**1. 局部引用的管理**

```c++
// 推荐使用PushLocalFrame/PopLocalFrame
if ((*env)->PushLocalFrame(env, 10) < 0) {
    return NULL; // 内存不足
}
// 执行操作
result = (*env)->PopLocalFrame(env, result);
```


**2. 确保引用的容量**


```c++
if ((*env)->EnsureLocalCapacity(env, expectedRefs) < 0) {
    return NULL; // 内存不足
}
```


**3. 及时释放不需要的引用**

```c++
// 使用完立即释放
(*env)->DeleteLocalRef(env, obj);
```