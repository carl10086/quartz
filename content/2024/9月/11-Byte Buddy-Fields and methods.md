
## Refer

- [tutorial](https://bytebuddy.net/#/tutorial)



来自官网, `ByteBuddy` 如何去控制 方法的创建，选择和实现...

## 1-Intro


**1) quick start**

```java
String toString = new ByteBuddy()
  .subclass(Object.class)
  .name("example.Type")
  // 选择并且重定义方法
  .method(named("toString")).intercept(FixedValue.value("Hello World!"))
  .make()
  .load(getClass().getClassLoader())
  .getLoaded()
  .newInstance()
  .toString();
```


**可以更细的 ElementMatcher**

`named("toString").and(returns(String.class)).and(takesArguments(0))`

**可以链式组装多个方法的重写**

```java
new ByteBuddy()
  .subclass(Foo.class)
  .method(isDeclaredBy(Foo.class)).intercept(FixedValue.value("One!"))
  .method(named("foo")).intercept(FixedValue.value("Two!"))
  .method(named("foo").and(takesArguments(1))).intercept(FixedValue.value("Three!"))
```


**可以定义新的方法**

```java
.defineMethod("newMethod", String.class, Modifier.PUBLIC)
.intercept(FixedValue.value("New method!"))
```


**可以定义新的字段**

```java
.defineField("newField", String.class, Modifier.PRIVATE)
```


**2) Usage**

基本的流程:

1. **方法选择**：使用 ElementMatcher 来精确选择要重写或修改的方法。
2. **规则优先级**：后定义的规则优先级更高，更具体的规则应该放在后面。
3. **新方法和字段**：可以使用 defineMethod 和 defineField 添加全新的方法和字段。
4. **实现方式**：使用预定义的 Implementation 实现（如 FixedValue）来定义方法行为。



**3) A Closer look at fixed values**

有2种东西可以存储这个 `fixedValue`.

1. 常量池: `Java` 类格式的一部分, 简单，但是支持的类型有限, 比如说 字符串，基本类型这种 ;
2. 静态字段: 存储在当前类的 `static field` 中, 需要在类加载的时候初始化 ; 

▪ `FixedValue.value(Object)`: Byte Buddy 分析参数类型，决定存储在常量池还是静态字段。
▪ `FixedValue.reference(Object)` : 总是将对象存储在静态字段中。

静态字段 可以使用 `TypeInitializer` 来进行显示的初始化.

- `Byte Buddy` 在类加载的时候会自动触发
- 外部的动态加载的类，需要手动运行



## 2-Delegating a method call


**1)-可以委托给另外的方法, 也是最常见的功能**

```java
class Source {
  public String hello(String name) { return null; }
}

class Target {
  public static String hello(String name) {
    return "Hello " + name + "!";
  }
}

String helloWorld = new ByteBuddy()
  .subclass(Source.class)
  .method(named("hello")).intercept(MethodDelegation.to(Target.class))
  .make()
  .load(getClass().getClassLoader())
  .getLoaded()
  .newInstance()
  .hello("World");
```


**2) 方法选择机制**

```java
class Target {
    public static String intercept(String name) {
        return "Hello " + name + "!";
    }
    
    public static String intercept(int i) {
        return Integer.toString(i);
    }
    
    public static String intercept(Object o) {
        return o.toString();
    }
}
```

在这个例子中，Target 类有三个重载的 intercept 方法。如果我们将 Source 类的 hello 方法改为接受 int 类型的参数，Byte Buddy 会选择 intercept(int i) 方法，因为它可以接受 int 类型的参数


**3) 方法参数注解**

• `@Argument`：将参数绑定到源方法的相应参数。
• `@AllArguments`：将所有参数作为数组传递。
• `@This`：获取当前动态类型的实例。
• `@Origin`：获取原始方法的信息

```java
import net.bytebuddy.implementation.bind.annotation.Argument;
import net.bytebuddy.implementation.bind.annotation.AllArguments;
import net.bytebuddy.implementation.bind.annotation.Origin;
import net.bytebuddy.implementation.bind.annotation.This;

class Target {
    public static String intercept(@Argument(0) String name, @Origin String methodName) {
        return "Method " + methodName + " called with " + name + "!";
    }
}

class Source {
    public String hello(String name) {
        return null;
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        String result = new ByteBuddy()
            .subclass(Source.class)
            .method(ElementMatchers.named("hello"))
            .intercept(MethodDelegation.to(Target.class))
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .newInstance()
            .hello("World");
        System.out.println(result); // 输出 "Method hello called with World!"
    }
}
```


**4) SuperCall 注解**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.SuperCall;
import net.bytebuddy.matcher.ElementMatchers;

import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Callable;

class MemoryDatabase {
    public List<String> load(String info) {
        return Arrays.asList(info + ": foo", info + ": bar");
    }
}

class LoggerInterceptor {
    public static List<String> log(@SuperCall Callable<List<String>> zuper) throws Exception {
        System.out.println("Calling database");
        try {
            return zuper.call(); // 调用原始方法
        } finally {
            System.out.println("Returned from database");
        }
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        MemoryDatabase loggingDatabase = new ByteBuddy()
            .subclass(MemoryDatabase.class) // 创建 MemoryDatabase 的子类
            .method(ElementMatchers.named("load")) // 匹配 load 方法
            .intercept(MethodDelegation.to(LoggerInterceptor.class)) // 使用 LoggerInterceptor
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .newInstance();

        List<String> result = loggingDatabase.load("Test");
        System.out.println(result); // 输出 "Calling database", "Returned from database", ["Test: foo", "Test: bar"]
    }
}

```


- 类似 `AOP` 的机制, 可以直接调用原始的方法, 做额外的逻辑



**7) Super 注解: 传递不同的参数去调用父类的方法. 更灵活一些**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.Super;
import net.bytebuddy.matcher.ElementMatchers;

import java.util.Arrays;
import java.util.List;

class MemoryDatabase {
    public List<String> load(String info) {
        return Arrays.asList(info + ": foo", info + ": bar");
    }
}

class ChangingLoggerInterceptor {
    public static List<String> log(String info, @Super MemoryDatabase zuper) {
        System.out.println("Calling database with info: " + info);
        try {
            return zuper.load(info + " (logged access)"); // 调用父类方法并修改参数
        } finally {
            System.out.println("Returned from database");
        }
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        MemoryDatabase loggingDatabase = new ByteBuddy()
            .subclass(MemoryDatabase.class)
            .method(ElementMatchers.named("load"))
            .intercept(MethodDelegation.to(ChangingLoggerInterceptor.class))
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .newInstance();

        List<String> result = loggingDatabase.load("Test");
        System.out.println(result); // 输出 "Calling database with info: Test", "Returned from database", ["Test (logged access): foo", "Test (logged access): bar"]
    }
}

```

**8) 使用构造函数的参数**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.Super;
import net.bytebuddy.matcher.ElementMatchers;

class BaseDatabase {
    public BaseDatabase(String config) {
        // 初始化数据库
    }

    public List<String> load(String info) {
        return Arrays.asList(info + ": foo", info + ": bar");
    }
}

class CustomDatabase extends BaseDatabase {
    public CustomDatabase(String config) {
        super(config);
    }
}

class CustomLoggerInterceptor {
    public static List<String> log(String info, @Super(constructorParameters = String.class) BaseDatabase zuper) {
        System.out.println("Calling database with info: " + info);
        return zuper.load(info + " (logged access)");
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        CustomDatabase loggingDatabase = new ByteBuddy()
            .subclass(CustomDatabase.class)
            .method(ElementMatchers.named("load"))
            .intercept(MethodDelegation.to(CustomLoggerInterceptor.class))
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .getDeclaredConstructor(String.class)
            .newInstance("config");

        List<String> result = loggingDatabase.load("Test");
        System.out.println(result); // 输出 "Calling database with info: Test", ["Test (logged access): foo", "Test (logged access): bar"]
    }
}
```


**9) `Exception handler`**

小心 `checked exceptions`, 因为代码是在运行期会跳过 编译期原本对 `checked exceptions` 的检查


**10) `@RuntimeType`**

```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.RuntimeType;
import net.bytebuddy.matcher.ElementMatchers;

class Loop {
    public String loop(String value) { return value; }
    public int loop(int value) { return value; }
}

class Interceptor {
    @RuntimeType
    public static Object intercept(@RuntimeType Object value) {
        System.out.println("Invoked method with: " + value);
        return value; // 返回传入的值
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        Loop loop = new ByteBuddy()
            .subclass(Loop.class)
            .method(ElementMatchers.named("loop"))
            .intercept(MethodDelegation.to(Interceptor.class))
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .newInstance();

        System.out.println(loop.loop("Hello")); // 输出 "Invoked method with: Hello" 和 "Hello"
        System.out.println(loop.loop(42)); // 输出 "Invoked method with: 42" 和 42
    }
}
```


**11) SuperMethodCall**

可以调用超类方法.

```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.SuperMethod;
import net.bytebuddy.matcher.ElementMatchers;

class BaseClass {
    public String greet() {
        return "Hello from BaseClass";
    }
}

class DerivedClass {
    public String greet() {
        return "Hello from DerivedClass";
    }

    public String callSuperGreet(@SuperMethod String method) {
        return method; // 这里调用了父类的方法
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        DerivedClass derived = new ByteBuddy()
            .subclass(DerivedClass.class)
            .method(ElementMatchers.named("greet"))
            .intercept(MethodDelegation.to(BaseClass.class))
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded()
            .newInstance();

        String result = derived.callSuperGreet(derived.greet());
        System.out.println(result); // 输出 "Hello from BaseClass"
    }
}

```

- 就有个 `ConstructorStrategy` 需要注意一下
- 其他的类似, 默认方法，sepefic 方法等等


## 3-Fields

类似反射，有一个 `FieldAccessor` , 有 `set` 和 `get` 的能力.

```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.FieldAccessor;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.implementation.FieldAccessor;

class UserType {
    public String doSomething() {
        return "Doing something!";
    }
}

interface Interceptor {
    String doSomethingElse();
}

interface InterceptionAccessor {
    Interceptor getInterceptor();
    void setInterceptor(Interceptor interceptor);
}

public class Main {
    public static void main(String[] args) throws Exception {
        // 创建动态 UserType
        Class<? extends UserType> dynamicUserType = new ByteBuddy()
            .subclass(UserType.class)
            .defineField("interceptor", Interceptor.class, net.bytebuddy.implementation.Visibility.PRIVATE)
            .implement(InterceptionAccessor.class)
            .intercept(FieldAccessor.ofBeanProperty()) // 使用字段访问器
            .method(ElementMatchers.not(ElementMatchers.isDeclaredBy(Object.class)))
            .intercept(MethodDelegation.toField("interceptor")) // 委托到 interceptor 字段
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded();

        // 创建动态 UserType 的实例
        UserType userTypeInstance = dynamicUserType.getDeclaredConstructor().newInstance();

        // 设置拦截器
        Interceptor interceptor = new Interceptor() {
            @Override
            public String doSomethingElse() {
                return "Hello from Interceptor!";
            }
        };
        ((InterceptionAccessor) userTypeInstance).setInterceptor(interceptor);

        // 使用拦截器
        System.out.println(((InterceptionAccessor) userTypeInstance).getInterceptor().doSomethingElse()); // 输出 "Hello from Interceptor!"
        System.out.println(userTypeInstance.doSomething()); // 输出 "Doing something!"
    }
}

```

- 在 `UserType` 中增加了字段 `interceptor`
- 使用 `set` 和 `get` 方法验证


## 4-Miscellaneous


其他的玩法

**1)-StubMethod: 仅仅返回默认值，不执行任何操作**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.StubMethod;
import net.bytebuddy.matcher.ElementMatchers;

class MockService {
    public String fetchData() {
        return "Real data"; // 实际方法
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        Class<? extends MockService> mockService = new ByteBuddy()
            .subclass(MockService.class)
            .method(ElementMatchers.named("fetchData"))
            .intercept(StubMethod.INSTANCE) // 使用 StubMethod
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded();

        MockService instance = mockService.getDeclaredConstructor().newInstance();
        System.out.println(instance.fetchData()); // 输出 null，因为使用了 StubMethod
    }
}

```

- 在 mock 场景下有点用. 


**2)-ExceptionMethod: 只抛出异常**

```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.ExceptionMethod;
import net.bytebuddy.matcher.ElementMatchers;

class Service {
    public void performAction() {
        // 实际方法
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        Class<? extends Service> serviceWithException = new ByteBuddy()
            .subclass(Service.class)
            .method(ElementMatchers.named("performAction"))
            .intercept(ExceptionMethod.withException(new RuntimeException("An error occurred"))) // 使用 ExceptionMethod
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded();

        Service instance = serviceWithException.getDeclaredConstructor().newInstance();
        try {
            instance.performAction(); // 调用将抛出异常
        } catch (RuntimeException e) {
            System.out.println(e.getMessage()); // 输出 "An error occurred"
        }
    }
}

```


**3)-Forwarding: 转发给同一种类型的另一个实例**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.Forwarding;
import net.bytebuddy.matcher.ElementMatchers;

class OriginalService {
    public String greet() {
        return "Hello!";
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        OriginalService originalInstance = new OriginalService();

        Class<? extends OriginalService> forwardingService = new ByteBuddy()
            .subclass(OriginalService.class)
            .method(ElementMatchers.named("greet"))
            .intercept(MethodDelegation.to(originalInstance)) // 使用 Forwarding
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded();

        OriginalService instance = forwardingService.getDeclaredConstructor().newInstance();
        System.out.println(instance.greet()); // 输出 "Hello!"
    }
}
```


**4)-InvocationHandlerAdapter**


```java
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.InvocationHandlerAdapter;
import net.bytebuddy.matcher.ElementMatchers;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Proxy;

interface MyInterface {
    String sayHello();
}

class MyInvocationHandler implements InvocationHandler {
    @Override
    public Object invoke(Object proxy, java.lang.reflect.Method method, Object[] args) {
        return "Hello from InvocationHandler!";
    }
}

public class Main {
    public static void main(String[] args) throws Exception {
        MyInvocationHandler handler = new MyInvocationHandler();

        MyInterface proxyInstance = (MyInterface) Proxy.newProxyInstance(
            MyInterface.class.getClassLoader(),
            new Class<?>[]{MyInterface.class},
            handler
        );

        Class<? extends MyInterface> dynamicProxy = new ByteBuddy()
            .subclass(MyInterface.class)
            .method(ElementMatchers.named("sayHello"))
            .intercept(InvocationHandlerAdapter.of(handler)) // 使用 InvocationHandlerAdapter
            .make()
            .load(Main.class.getClassLoader())
            .getLoaded();

        MyInterface instance = dynamicProxy.getDeclaredConstructor().newInstance();
        System.out.println(instance.sayHello()); // 输出 "Hello from InvocationHandler!"
    }
}
```


- 和 `jdk` 自身的代理功能配合使用



**5)-InvokeDynamic: 直接在 运行时候动态绑定**


```java
import net.bytebuddy.ByteBuddy;  
import net.bytebuddy.implementation.MethodDelegation;  
import net.bytebuddy.implementation.bind.annotation.RuntimeType;  
import net.bytebuddy.matcher.ElementMatchers;  
  
import java.lang.invoke.CallSite;  
import java.lang.invoke.ConstantCallSite;  
import java.lang.invoke.MethodHandles;  
import java.lang.invoke.MethodType;  
  
public class Invoke_Dynamic_003 {  
  
    public static void main(String[] args) throws Exception {  
        Class<?> dynamicType = new ByteBuddy()  
                .subclass(Object.class)  
                .method(ElementMatchers.named("toString"))  
                .intercept(MethodDelegation.to(Invoke_Dynamic_003.class))  
                .make()  
                .load(Invoke_Dynamic_003.class.getClassLoader())  
                .getLoaded();  
  
        Object instance = dynamicType.getDeclaredConstructor().newInstance();  
        System.out.println(instance);  
    }  
  
    @RuntimeType  
    public static CallSite bootstrap(MethodHandles.Lookup lookup, String methodName, MethodType methodType) throws NoSuchMethodException, IllegalAccessException {  
        return new ConstantCallSite(  
                lookup.findStatic(Invoke_Dynamic_003.class, "dynamicToString", MethodType.methodType(String.class))  
        );  
    }  
  
    public static String dynamicToString() {  
        return "Hello from dynamic toString!";  
    }  
}
```


- `InvokeDynamic` 是 `Java7` 引入的机制，允许使用更灵活的方式来使用 **多态**, 尤其是在动态语言和方法调用的场景中， **我们可以在 运行的时候选择调用的方法，而不是多编译的时候确定**
- [理解 invokeDynamic](https://blogs.oracle.com/javamagazine/post/understanding-java-method-invocation-with-invokedynamic)



## 5-Plugin


用 `JMoleculesSpringPlugin` 来说明一下 `Plugin` 的使用姿势.

```java
public class JMoleculesSpringPlugin implements LoggingPlugin {  
  
    private static final Map<Class<?>, Class<? extends Annotation>> MAPPINGS;  
    private static final Set<Class<?>> TRIGGERS;  
    private static final Map<Class<? extends Annotation>, Class<? extends Annotation>> METHOD_ANNOTATIONS;  
  
    static {  
  
       // jMolecules -> Spring  
       Map<Class<?>, Class<? extends Annotation>> types = new HashMap<>();  
       types.put(Service.class, org.springframework.stereotype.Service.class);  
       types.put(Repository.class, org.springframework.stereotype.Repository.class);  
       types.put(org.jmolecules.ddd.annotation.Factory.class, Component.class);  
  
       // Spring -> jMolecules  
       types.put(org.springframework.stereotype.Service.class, Service.class);  
       types.put(org.springframework.stereotype.Repository.class, Repository.class);  
  
       MAPPINGS = Collections.unmodifiableMap(types);  
  
       /*  
        * Which annotations trigger the processing?        */       Set<Class<?>> triggers = new HashSet<>(MAPPINGS.keySet());  
       triggers.add(Component.class);  
  
       TRIGGERS = Collections.unmodifiableSet(triggers);  
  
       Map<Class<? extends Annotation>, Class<? extends Annotation>> methods = new HashMap<>();  
  
       if (Types.DOMAIN_EVENT_HANDLER != null) {  
          methods.put(Types.DOMAIN_EVENT_HANDLER, EventListener.class);  
          methods.put(EventListener.class, Types.DOMAIN_EVENT_HANDLER);  
       }  
  
       METHOD_ANNOTATIONS = Collections.unmodifiableMap(methods);  
    }  
  
    /*  
     * (non-Javadoc)     * @see net.bytebuddy.matcher.ElementMatcher#matches(java.lang.Object)     */    @Override  
    public boolean matches(TypeDescription type) {  
  
       if (residesInPlatformPackage(type)) {  
          return false;  
       }  
  
       return TRIGGERS.stream().anyMatch(it -> it.isAnnotation() //  
             ? isAnnotatedWith(type, it) //  
             : type.isAssignableTo(it));  
    }  
  
    /*  
     * (non-Javadoc)     * @see net.bytebuddy.build.Plugin#apply(net.bytebuddy.dynamic.DynamicType.Builder, net.bytebuddy.description.type.TypeDescription, net.bytebuddy.dynamic.ClassFileLocator)     */    @Override  
    public Builder<?> apply(Builder<?> builder, TypeDescription type, ClassFileLocator classFileLocator) {  
  
       Log log = PluginLogger.INSTANCE.getLog(type, "Spring");  
       Builder<?> result = mapAnnotationOrInterfaces(builder, type, MAPPINGS, log);  
  
       for (Entry<Class<? extends Annotation>, Class<? extends Annotation>> entry : METHOD_ANNOTATIONS.entrySet()) {  
  
          Class<? extends Annotation> target = entry.getValue();  
  
          result = result.method(hasAnnotatedMethod(type, entry.getKey(), target, log)) //  
                .intercept(SuperMethodCall.INSTANCE) //  
                .annotateMethod(getAnnotation(target));  
       }  
  
       return result;  
    }  
  
    /*  
     * (non-Javadoc)     * @see java.io.Closeable#close()     */    @Override  
    public void close() throws IOException {}  
}
```


代码的目的是为了去检测 `JMolecules` 的注解， 然后自动加上 `Spring` 的一些注解. 有一个 `Map` 去维护这样的一个映射关系.

上面是实现了 `Plugin` 接口, 会根据 `match` 来判断是否要 `apply` 字节码转换.

还有一些更定制化的接口:

1.	Plugin 接口
-	这是基本接口，定义了 matches 和 apply 方法。
-	如果只实现这个接口，插件将只能进行基本的类转换。
2.	Plugin.WithPreprocessor
-	添加了 onPreprocess 方法。
-	允许插件在实际转换之前预处理类型。
-	用于初始化或收集转换前的信息。
3.	Plugin.WithInit
-	添加了 init 方法。
-	在插件开始处理任何类之前被调用。
-	用于插件的一次性初始化。
4.	Plugin.Factory
-	用于创建插件实例。
-	允许动态配置插件。
5.	Plugin.Engine
-	提供了更细粒度的控制，如处理异常和资源管理。
6.	Plugin.Engine.Listener
-	允许监听转换过程中的事件。
7.	Plugin.Engine.Dispatcher


...