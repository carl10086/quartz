
## Refer

- [bytebuddy](https://bytebuddy.net/#/tutorial)

## 1-Intro


**1)-Why**


- `Java` 是一个强类型语言，编译期检查
- 强类型意味着强限制, 这些限制让 一个通用库的设计的时候，无法引用用户应用程序中定义的任何类型, `Java` 官方提供了 反射来解决问题.


**反射的2个缺点**

- 性能一般.
	- 首先，需要执行一个相对昂贵的方法查找，以获取描述特定方法的对象
	- 调用方法时，JVM需要运行本地代码，这与直接调用相比需要更长的运行时间
	- 现代JVM引入了一个称为**膨胀（inflation** 的概念，其中基于JNI的方法调用被替换为生成的字节码，这些字节码被注入到动态创建的类中
- 类型不安全

**Byte-buddy** 代表的是 运行期代码生成的思路，更灵活，甚至某些方面更 类型安全一些.


**2)-通用库**


- `Java` 代理: 适用于接口，很方便
- `Cglib`: 没有跟上发展，基本没有人维护
- `Javasist`: 带有一个编译器, 可以将包含 `Java` 源代码的字符串 在程序运行的时候编译为 `Java` 的字节码, 野心勃勃但是很难，要跟上 `java`  的发展难度系数比较高

**3)-性能参考**

下面都是 `JIT` 优化过的性能.

| baseline                 |       | Byte Buddy |                          | cglib                   |           | Javassist |           | Java proxy |           |          |
| ------------------------ | ----- | ---------- | ------------------------ | ----------------------- | --------- | --------- | --------- | ---------- | --------- | -------- |
| trivial class creation   | 0.003 | (0.001)    | 142.772                  | (1.390)                 | 515.174   | (26.753)  | 193.733   | (4.430)    | 70.712    | (0.645)  |
| interface implementation | 0.004 | (0.001)    | 1'126.364                | (10.328)                | 960.527   | (11.788)  | 1'070.766 | (59.865)   | 1'060.766 | (12.231) |
| stub method invocation   | 0.002 | (0.001)    | 0.002                    | (0.001)                 | 0.003     | (0.001)   | 0.011     | (0.001)    | 0.008     | (0.001)  |
| class extension          | 0.004 | (0.001)    | 885.983  <br>_5'408.329_ | (7.901)  <br>_(52.437)_ | 1'632.730 | (52.737)  | 683.478   | (6.735)    | –         |          |
| super method invocation  | 0.004 | (0.001)    | 0.004  <br>_0.004_       | (0.001)  <br>_(0.001)_  | 0.021     | (0.001)   | 0.025     | (0.001)    | –         |          |


## 2-Creating a class

**1)-默认的命名策略**

```java
1. DynamicType.Unloaded<?> dynamicType = new ByteBuddy()
2. .subclass(Object.class)
3. .name("example.Type")
4. .make();
```

- 默认的命名策略: 名称被定义为与超类位于同一包中，以便直接超类的包私有方法始终对动态类型可见. example.Foo 的类型，生成的名称将类似于 `example.Foo$$ByteBuddy$$1376491271` ，其中的数字序列是随机的。对于从 java.lang 包中子类化的类型（如 Object），则例外, 因为Java 的安全模型不允许自定义类型存在于此命名空间中。因此，此类类型名称的前缀为 `net.bytebuddy.renamed` 

**2)-自定义命名策略**

```java
DynamicType.Unloaded<?> dynamicType = new ByteBuddy()
  .with(new NamingStrategy.AbstractBase() {
    @Override
    protected String name(TypeDescription superClass) {
        return "i.love.ByteBuddy." + superClass.getSimpleName();
    }
  })
  .subclass(Object.class)
  .make();
```

- 可以使用 `NamingStrategy.SuffixingRandom` 可以自定义前缀


**3)-不可变设计**

```java
ByteBuddy byteBuddy = new ByteBuddy();
byteBuddy.withNamingStrategy(new NamingStrategy.SuffixingRandom("suffix"));
DynamicType.Unloaded<?> dynamicType = byteBuddy.subclass(Object.class).make();
```


- 这个代码有 **有明显的 bug**, 因为是不可变对象，每次的修改都是不同的对象, 要修改为


```java
ByteBuddy byteBuddy = new ByteBuddy()
  .withNamingStrategy(new NamingStrategy.SuffixingRandom("suffix"));
DynamicType.Unloaded<?> dynamicType = byteBuddy.subclass(Object.class).make();
```

**4)-Type Redefinition vs Rebasing**

**重新定义类** 这种增强方法会让原有的方法完全丢失, 会替换掉

`Rebase` 则会保留之前的方法. 通过 `$original` 作为后缀.

```java
class Foo {
  String bar() { return "foo" + bar$original(); }
  private String bar$original() { return "bar"; }
}
```


使用姿势.

```java
new ByteBuddy().subclass(Foo.class)
new ByteBuddy().redefine(Foo.class)
new ByteBuddy().rebase(Foo.class)
```

**5)-Loading a class**

由 `ByteBuddy` 加载的类是一个 **没有加载的类**, 由 `DynamicType.Unloaded` 封装.  他代表的是一个二进制表示, 采用的是 `Java` 类文件格式, 你甚至 **可以把类注入到现有的 `JAR` 文件中**.


`JVM` 的类加载机制比 创建类更加的复杂. `ByteBuddy` 有三种姿势:

1. 创建新的 `ClassLoader` : 把新的 `ClassLoader` 定义为运行 `Java` 程序中某个现有类的加载器的子类, 这个新的子类 就能知道运行期的所有子类, **比较适合无缝集成到当前的类结构中** ;
2. 子类优先的 `ClassLoader` , **反双亲加载模型**, 这种会 **子类优先**, 适合 **隔离和覆盖** 这样的场景，如果我们想要 覆盖掉 父类的功能场景, 比如说插件系统;
3. 使用反射注入类型, 使用反射把类型注入到现有的 `ClassLoader` 中, 直接用反射绕过限制直接注入到老的类加载器中，无需类加载器知道如何定位这个类 ;

**缺点:**

- 新创建的 `ClassLoader` 有自己新的 `namespace` , 不同的 `namespace` 中的类不能方法调用. 
- 类加载依赖: 循环依赖问题, 一般都建议创建新的 `classLoader` .


```java
Class<?> type = new ByteBuddy()
  .subclass(Object.class)
  .make()
  .load(getClass().getClassLoader(), ClassLoadingStrategy.Default.WRAPPER)
  .getLoaded();
```


**6)-Reloading a class**

```kotlin
import net.bytebuddy.ByteBuddy  
import net.bytebuddy.agent.ByteBuddyAgent  
import net.bytebuddy.dynamic.loading.ClassReloadingStrategy  
  
  
class Foo {  
    fun m() = "foo"  
}  
  
class Bar {  
    fun m(): String = "bar"  
}  
  
fun main(args: Array<String>) {  
    ByteBuddyAgent.install()  
  
    val foo = Foo()  
  
    println(foo.m())  
  
    ByteBuddy()  
        .redefine(Bar::class.java)  
        .name(Foo::class.java.name)  
        .make()  
        .load(Foo::class.java.classLoader, ClassReloadingStrategy.fromInstalledAgent())  
  
    println(foo.m())  
}
```


- 这个 `demo` 是利用 `jdk` 本身 `Java Agent` 的 `Instrumentation API` 来重新 替换掉 `class` 字节码 ;
- 类的定义在 `JVM` 层面被更新， 不会有新的 `ClassLoader` 也不会有新的 `Class`, **是替换** ;
- `JVM` 本身有一些限制, 例如不能添加新的方法或者新的字段, 正因为这个原因不能使用 **rebase** 这样的行为， 只能是 **redefine**



**7)-Working with unloaded class**

`ByteBuddy` 有能力处理没有加载的类. 

- Byte Buddy 使用 TypeDescription 接口来抽象表示类，而不是直接使用 Java 的 Class 对象, 否则就会直接加载了
- TypePool 是获取类的 TypeDescription 的标准方式

```java
class MyApplication {
  public static void main(String[] args) {
    // 1. 创建一个 TypePool，用于描述系统类加载器可以访问的类。
    TypePool typePool = TypePool.Default.ofSystemLoader();

	// 2. 使用 TypePool 获取 foo.Bar 类的描述，而不是直接使用 Bar.class。
    Class bar = new ByteBuddy()
      .redefine(typePool.describe("foo.Bar").resolve(),
                ClassFileLocator.ForClassLoader.ofSystemLoader())
		// 3. 添加一个名为 "qux" 的 String 类型字段
      .defineField("qux", String.class)
      .make()
      .load(ClassLoader.getSystemClassLoader(), ClassLoadingStrategy.Default.INJECTION)
      .getLoaded();
    assertThat(bar.getDeclaredField("qux"), notNullValue());
  }
}
```


**8)-Creating Java Agents**


- `JavaAgent` 是一种特殊的 `JAR` 文件, 可以拦截和修改 `Java` 应用程序中的类加载活动 ;
- 通过在 `JAR` 文件中的 `manifest` 来指定入口点来实现 ;
- `ByteBuddy` 通过提供 `AgentBuilder` 来简化 `JavaAgent` 的实现 ;


```java
class ToStringAgent {
// 1. premain , 在 main 方法之前执行
  public static void premain(String arguments, Instrumentation instrumentation) {
    new AgentBuilder.Default()
         // 2. 必须有 `ToString` 注解
        .type(isAnnotatedWith(ToString.class))
        .transform(new AgentBuilder.Transformer() {
      @Override
      public DynamicType.Builder transform(DynamicType.Builder builder,
                                              TypeDescription typeDescription,
                                              ClassLoader classloader) {
        return builder.method(named("toString"))
                      .intercept(FixedValue.value("transformed"));
      }
    }).installOn(instrumentation);
  }
}
```

