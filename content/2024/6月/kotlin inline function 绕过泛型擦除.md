

## Refer

- 以下内容来自于 [Kotlin 官方文档-inline function](https://kotlinlang.org/docs/inline-functions.html#noinline)

## 1-Inline function intro


> 初衷是为了优化 性能


高阶函数（例如闭包等功能）会增加运行时开销，在 ﻿JVM 上的所有看上去纯粹的 ﻿function 都是通过包装一个 ﻿function 对象来实现的。这里的成本有两点：

- 函数对象和动态类的内存分配
- 虚拟调用：例如 ﻿invokevirtual


下面的例子:

```kotlin
lock(l) {
	foo()
}
```

上面是一个闭包. 由于没有其他的参数依赖，完全可以编译为如下的代码, 而不是使用 函数对象生成一个调用.

```kotlin
l.lock()
try {
	foo()
} finally {
	l.unlock()
}
```


默认情况下，为了实现高阶函数功能, 编译器会动态的生一个 匿名类, 类似如下:

```java
class LockBody implements Function0<Void> {
    @Override
    public Void invoke() {
        foo();
        return null;
    }
}
```


完整的代码类似如下:

```java
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

// 函数接口
interface Function0<R> {
    R invoke();
}

// 高阶函数 lock
public static <T> T lock(Lock lock, Function0<T> body) {
    lock.lock();
    try {
        return body.invoke();
    } finally {
        lock.unlock();
    }
}

// foo 函数
public static void foo() {
    System.out.println("Executing foo");
}

// 主函数
public static void main(String[] args) {
    Lock l = new ReentrantLock();

    // 匿名类表示 body
    Function0<Void> body = new Function0<>() {
        @Override
        public Void invoke() {
            foo();
            return null;
        }
    };

    // 调用 lock 函数
    lock(l, body);
}

```


> 为了告诉编译器要优化为上面的结构.

```kotlin
inline fun <T> lock(lock: Lock, body: () -> T): T { ... }
```


- 在 `lock` 函数上 `inline` 而不是在 `foo` 函数上加 `inline`.
- 这样就会把 `lock` 内部的调用在 编译的时候 放到方法体中.



> [!NOTE] Tips
> `inline` 修饰符会影响这个函数本身，和传递给函数的 `lambda` 表达式, 也就是上面的 `body`, 所有的这些都会被 内联到 调用点


> [!NOTE] Tips
> 一个函数被内联，意味着 调用他的地方会直接展开，内联过去，他的参数如果是 lambda ,也会被展开




> [!NOTE] Tips
> 同样的， `inline` 会导致 生成的代码增大, **尤其应该避免大型函数**, 我们合理的使用内联，会在性能上有所提升，尤其在 循环内的 `megamorphic` 调用点, 也是所谓的多态调用点




> 更加细粒度的控制.


```kotlin
inline fun foo(inlined: () -> Unit, noinline notInlined: () -> Unit) { ... }
```

- 我们显示的指明了 `inline`  `foo` 函数，这个时候默认所有的参数，只要是函数就会 **内联**
- 我们显示的 指明了 参数 `notInlined` 不要内联，**如果这个 函数很大**, 还是很细的.


> non-local return 和 inlined, 这里其实解释了一些编码疑惑


有的时候在 `lambda` 中不能写 `return` , 例如:

```kotlin
fun foo() {
    ordinaryFunction {
        return // 错误: 不能在这里使`foo`返回
    }
}
```


- 我们只能用 `return` 来退出 **匿名函数** 或者 **命名函数**， 不能 用来退出 `lambda` . 
- 如果要退出使用 `label`
- **但是，如果 这个 lambda 被内联了，是可以的，因为这个 lambda 在编译的时候会转化为一个 非lambda 的内联调用, 有毒**





## 2-Reified type parameters


我们可以利用内联的 特性来绕过 泛型擦除.


`reified` + `inline` 可以用来 绕过 **泛型擦除** 或者 **反射** 这样的东西. 


> 首先, 泛型 `Generics` 在运行的时候是消失的


- 这种操作被称为 `type erasure`, 类型擦除, **在编译之后的 字节码中**, 关于泛型类型的信息都不会再保留, 这个是无法直接获取到 泛型参数的实际类型. 


例如下面的代码是编译不过去的:

```java
  
List<String> stringList = new ArrayList<>();
if (stringList instanceof ArrayList<String>) { 
    // This check would produce a compile-time error
}
```

我们组合使用2种 技巧来绕过这个问题, 引入具体化类型参数, 也就是 `reified` 修饰的泛型参数, 在内联函数的编译期间，会告诉 `kotlin` 你应该保留这个类型参数，并且在 运行的时候具体化传下去，解决 **泛型擦除问题**


1. **内联函数**: 具体化类型参数只能在内联函数（inline functions）中使用。当你在Kotlin代码中标记一个函数为﻿inline时，编译器会将该函数的调用点用函数体替换，这就是所谓的“内联”。
2. **编译器魔法**: 在标记为具体化的类型参数﻿reified的函数中，编译器会将关于类型的信息保留到替换后的代码中。这在很大程度上是通过编译器的特殊处理来实现的。



下面举个例子:

```kotlin
  
inline fun <reified T> printTypeName() {
    println(T::class.java.name)
}


fun main() {
    printTypeName<String>()  // 这会输出 "java.lang.String"
    printTypeName<Int>()     // 这会输出 "java.lang.Integer"
```


解释一下:

- 这个函数被内联的时候， 在调用点.比如说上面代码中的: `printTypeName<String>` .
- 展开的时候, 发现泛型是具体化泛型, 会将原始的 `println(T::class.java.name)` 替换为 `println(String::class.java)`



**这个操作熟悉 json 反序列化 各种 TypeInformation 参数的时候会特别有用**



下面是一个生产中的例子:

```kotlin
interface HttpResponseCallback<T> {  
    fun extract(respStr: String): T  
  
    companion object {  
        inline fun <reified T> fromJsonTypeClass(): HttpResponseCallback<T> {  
            return object : HttpResponseCallback<T> {  
                override fun extract(respStr: String): T {  
                    return JsonUtils.fromJson(respStr)  
                }  
            }  
        }  
    }  
}
```


下面看 `JsonUtils`.

```kotlin
object JsonUtils {  
  
    val mapper = ObjectMapper()  
        .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)  
        .enable(DeserializationFeature.ACCEPT_SINGLE_VALUE_AS_ARRAY)  
        .registerModules(JavaTimeModule())  
        .registerModules(KotlinModule.Builder().build())  
//        .setPropertyNamingStrategy(PropertyNamingStrategies.LOWER_CAMEL_CASE)  
  
  
    /**  
     * kotlin 会在编译的时候 通过 inline 内联的方式 把泛型传到函数体中.  
     *     * 从而可以在 运行时保留类型信息  
     */  
    inline fun <reified T> fromJson(respStr: String): T {  
        return mapper.readValue(respStr)  
    }  
}
```

我们使用的时候这一行就可以直接类型推导，泛型会内联一路传递了过去:

```kotlin
val callback: HttpResponseCallback<LinkRespDto<List<ChatroomItemDto>>> =  
    HttpResponseCallback.fromJsonTypeClass()
```

