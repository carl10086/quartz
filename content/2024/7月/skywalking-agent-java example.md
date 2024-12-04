


## Refer

- [homepage](https://skywalking.apache.org/docs/skywalking-java/next/en/setup/service-agent/java-agent/readme/)
## 1-Intro

> 记录一下本地环境安装流程

```bash
git clone --recurse-submodules git@git.yuaiweiwu.com:team/skywalking-java.git
```

```bash
# optionally, 感觉不一定需要
brew install protobuf
```

```bash
# mac m1 必须在 rosetta 模式下才能支持
softwareupdate --install-rosetta
```


```bash
./mvnw clean package -DskipTests=true -Dmaven.javadoc.skip=true  -Pall
```



> 先修改一下 Spring Scheduled 的 Agent 源码.

```java
/**  
 * Intercept method of {@code org.springframework.scheduling.support.ScheduledMethodRunnable#ScheduledMethodRunnable(java.lang.Object, java.lang.reflect.Method)}.  
 * record the execute method full name */public class ScheduledMethodConstructorWithMethodInterceptor implements InstanceConstructorInterceptor {  
  
    private static final ILog LOGGER = LogManager.getLogger(ScheduledMethodConstructorWithMethodInterceptor.class);  
  
    @Override  
    public void onConstruct(EnhancedInstance objInst, Object[] allArguments) throws Throwable {  
        LOGGER.warn("ScheduledMethodConstructorWithMethodInterceptor started: {}", allArguments);  
        LOGGER.warn("ScheduledMethodConstructorWithMethodInterceptor allArguments length: {}", allArguments.length);  
        Method method = (Method) allArguments[1];  
        LOGGER.warn("ScheduledMethodConstructorWithMethodInterceptor Method: {}", method);  
        String fullMethodName = buildFullMethodName(method);  
        LOGGER.warn("ScheduledMethodConstructorWithMethodInterceptor fullMethodName: {}", fullMethodName);  
  
        objInst.setSkyWalkingDynamicField(fullMethodName);  
    }  
  
    protected String buildFullMethodName(Method method) {  
        String className = method.getDeclaringClass().getName();  
        String methodName = method.getName();  
        LOGGER.warn("ScheduledMethodConstructorWithMethodInterceptor className: {}, methodName: {}", className, methodName);  
  
        return className + "." + methodName;  
    }  
}
```


> 集成


```
-javaagent:/path/to/skywalking-agent.jar
```

- 配置可以在 `agent.config` 中按需修改.



## 2-Problem

> 问题描述:

在使用 `Skywalking` 的时候，发现 `Spring-Scheduled` 获取到的内容:


```bash
- 端点: `SpringScheduled/null`
- ..
```

- 我们发现 监控的埋点是: `SpringScheduled/null`.
- 这个 `null` 为什么会有?

> 源码分析.

- 我们手动加了点日志: 

```java
@Override  
public void beforeMethod(EnhancedInstance objInst, Method method, Object[] allArguments, Class<?>[] argumentsTypes, MethodInterceptResult result) throws Throwable {  
    LOGGER.info("ScheduledMethodInterceptor started, allArguments:{}, objInst:{}", Arrays.toString(allArguments), objInst.getClass().getName());  
    String fullMethodName = (String) objInst.getSkyWalkingDynamicField();  
    LOGGER.info("ScheduledMethodInterceptor ,fullMethodName:{}", fullMethodName);  
    String operationName = ComponentsDefine.SPRING_SCHEDULED.getName() + "/" + fullMethodName;  
  
    AbstractSpan span = ContextManager.createLocalSpan(operationName);  
    Tags.LOGIC_ENDPOINT.set(span, Tags.VAL_LOCAL_SPAN_AS_LOGIC_ENDPOINT);  
    span.setComponent(ComponentsDefine.SPRING_SCHEDULED);  
}
```

**日志输出:**

```
INFO 2024-07-04 21:13:29.667 InferTaskScheduler-4 ScheduledMethodInterceptor : ScheduledMethodInterceptor started, allArguments:[], objInst:com....InferTaskScheduler.infer
INFO 2024-07-04 21:13:29.667 triggerTaskScheduler-4 ScheduledMethodInterceptor : ScheduledMethodInterceptor ,fullMethodName:null
```


问题定位到是这个 `EnhancedInstance` 的机制.

**EnhancedInstance 机制分析**

`EnhancedInstance` 是 `Skywalking` 的一个接口, 用来增强现有的类 做到可以动态的增加字段. 通常, `Skywalking` 的 `Agent` 会在加载目标的时候, 自动为目标类生成一个实现了 `EnhancedInstance` 的代理对象. 方便注入方法.


> 首先看是怎么注入的. 


```java
public class ScheduledMethodInterceptorInstrumentation extends ClassInstanceMethodsEnhancePluginDefine {  
  
    public static final String CONSTRUCTOR_WITH_METHOD_INTERCEPTOR_CLASS = "org.apache.skywalking.apm.plugin.spring.scheduled.ScheduledMethodConstructorWithMethodInterceptor";  
    public static final String CONSTRUCTOR_WITH_STRING_INTERCEPTOR_CLASS = "org.apache.skywalking.apm.plugin.spring.scheduled.ScheduledMethodConstructorWithStringInterceptor";  
    public static final String METHOD_INTERCEPTOR_CLASS = "org.apache.skywalking.apm.plugin.spring.scheduled.ScheduledMethodInterceptor";  
    public static final String ENHANC_CLASS = "org.springframework.scheduling.support.ScheduledMethodRunnable";  
  
    @Override  
    public ClassMatch enhanceClass() {  
        return byName(ENHANC_CLASS);  
    }  
  
    @Override  
    public ConstructorInterceptPoint[] getConstructorsInterceptPoints() {  
        return new ConstructorInterceptPoint[] {  
            new ConstructorInterceptPoint() {  
                @Override  
                public ElementMatcher<MethodDescription> getConstructorMatcher() {  
                    return takesArguments(2)  
                            .and(takesArgument(0, Object.class))  
                            .and(takesArgument(1, Method.class));  
                }  
  
                @Override  
                public String getConstructorInterceptor() {  
                    return CONSTRUCTOR_WITH_METHOD_INTERCEPTOR_CLASS;  
                }  
            },  
            new ConstructorInterceptPoint() {  
                @Override  
                public ElementMatcher<MethodDescription> getConstructorMatcher() {  
                    return takesArguments(2)  
                            .and(takesArgument(0, Object.class))  
                            .and(takesArgument(1, String.class));  
                }  
  
                @Override  
                public String getConstructorInterceptor() {  
                    return CONSTRUCTOR_WITH_STRING_INTERCEPTOR_CLASS;  
                }  
            }  
        };  
    }  
  
    @Override  
    public InstanceMethodsInterceptPoint[] getInstanceMethodsInterceptPoints() {  
        return new InstanceMethodsInterceptPoint[] {  
                new InstanceMethodsInterceptPoint() {  
                    @Override  
                    public ElementMatcher<MethodDescription> getMethodsMatcher() {  
                        return named("run")  
                                .and(isPublic())  
                                .and(takesArguments(0));  
                    }  
  
                    @Override  
                    public String getMethodsInterceptor() {  
                        return METHOD_INTERCEPTOR_CLASS;  
                    }  
  
                    @Override  
                    public boolean isOverrideArgs() {  
                        return false;  
                    }  
                }  
        };  
    }  
}
```


`Skywalking` 会拦截 `ENHANC_CLASS` 也就是这个类: `org.springframework.scheduling.support.ScheduledMethodRunnable` . 

- 有2类拦截点:
	- **构造器拦截点**: 一次性的捕获 `OperationName`
	- **方法执行拦截点**: 基于上面的 `OpreationName` 生成  `TraceEvent`


构造器拦截点，大同小异.


上面的有 `bug`. 因为 `Spring6.x` 新增了 `Scheduler` 的构造器.

```java
	/**
	 * Create a {@code ScheduledMethodRunnable} for the given target instance,
	 * calling the specified method.
	 * @param target the target instance to call the method on
	 * @param method the target method to call
	 * @param qualifier a qualifier associated with this Runnable,
	 * e.g. for determining a scheduler to run this scheduled method on
	 * @param observationRegistrySupplier a supplier for the observation registry to use
	 * @since 6.1
	 */
	public ScheduledMethodRunnable(Object target, Method method, @Nullable String qualifier,
			Supplier<ObservationRegistry> observationRegistrySupplier) {

		this.target = target;
		this.method = method;
		this.qualifier = qualifier;
		this.observationRegistrySupplier = observationRegistrySupplier;
	}


```


> [!NOTE] Tips
> 上面的代码没有办法捕获 4个参数的构造器



```java

            new ConstructorInterceptPoint() {
              @Override
              public ElementMatcher<MethodDescription> getConstructorMatcher() {
                return takesArguments(4)
                    .and(takesArgument(0, Object.class))
                    .and(takesArgument(1, Method.class));
              }

              @Override
              public String getConstructorInterceptor() {
                return CONSTRUCTOR_WITH_METHOD_INTERCEPTOR_CLASS;
              }
```


通常这个代码新增一个 4个参数的 拦截点. `DONE`


## 3-Manual API


### 3-1 Create Span

**首先, Skywalking  的 Span 分为三种类型:**

- `Entry Span` 和 `ExitSpan`: 这2种，一个代表系统的入口，一个代表系统的出口. 
	- 前者代表 接收请求的入口，例如 MqConsumer, Http Endpoint
	- 后者 代表对其他的系统 发出远程请求，例如调用三方的服务
- `Local Span`: 本地方法体内部的调用.

下面是一个 `Demo` :

```java
import org.apache.skywalking.apm.toolkit.trace.Tracer;
import org.apache.skywalking.apm.toolkit.trace.SpanRef;

public void handleRequest() {
    SpanRef entrySpan = Tracer.createEntrySpan("handleRequest", null);
    try {
        processTask();
        sendRequest();
    } finally {
        Tracer.stopSpan();
    }
}

public void processTask() {
    SpanRef localSpan = Tracer.createLocalSpan("processTask");
    try {
        // 处理任务的代码
    } finally {
        Tracer.stopSpan();
    }
}

public void sendRequest() {
    SpanRef exitSpan = Tracer.createExitSpan("sendRequest", "remote-service-address");
    try {
        // 发送请求的代码
    } finally {
        Tracer.stopSpan();
    }
}
```


### 3-2 Context Carrier

**Context Carrier** 是用来在分布式系统的 不同服务中传递上下文信息.
- 他包含了当前追踪的相关信息，例如 `TraceID`, `SpanID` 等等. 跨进程.


用一个 `HTTP` 调用作为例子.

> 首先，请求调用方先注入

```java
public void sendRequest() {
    ContextCarrierRef contextCarrierRef = new ContextCarrierRef();
    SpanRef spanRef = Tracer.createExitSpan("sendRequest", contextCarrierRef, "remote-service-address");
    try {
        // 注入上下文信息到载体
        Tracer.inject(contextCarrierRef);
        Map<String, String> map = new HashMap<>();
        CarrierItemRef next = contextCarrierRef.items();
        while (next.hasNext()) {
            next = next.next();
            map.put(next.getHeadKey(), next.getHeadValue());
        }
        
        // 发送请求，并将 map 作为请求头或消息头传递
        sendHttpRequest(map);

    } finally {
        Tracer.stopSpan();
    }
}

private void sendHttpRequest(Map<String, String> headers) {
    // 发送 HTTP 请求的代码，将 headers 作为请求头传递
}

```

> 其次，服务提供方 `Extract` 就能提出之前的 traceId , 然后串起来

```java
public void handleRequest(Map<String, String> headers) {
    ContextCarrierRef contextCarrierRef = new ContextCarrierRef();
    CarrierItemRef next = contextCarrierRef.items();
    while (next.hasNext()) {
        next = next.next();
        String value = headers.get(next.getHeadKey());
        if (value != null) {
            next.setHeadValue(value);
        }
    }

    // 提取上下文信息
    Tracer.extract(contextCarrierRef);
    SpanRef spanRef = Tracer.createEntrySpan("handleRequest", contextCarrierRef);
    try {
        // 处理请求的代码
    } finally {
        Tracer.stopSpan();
    }
}
```



### 3-3 Capture/Continue Context Snapshot

类似前面的问题，这个用来解决跨进程，跨线程问题的.


> [!NOTE] Tips
> 估计也是使用 `ThreadLocal`, 所以需要把参数 在跨线程的时候复制并且传递


> 1. 首先是要在原始的线程中捕获一个上下文快照

```java
import org.apache.skywalking.apm.toolkit.trace.Tracer;
import org.apache.skywalking.apm.toolkit.trace.ContextSnapshotRef;

public void captureContext() {
    // 捕获当前上下文快照
    ContextSnapshotRef contextSnapshotRef = Tracer.capture();
    // 传递给新线程
    startNewThread(contextSnapshotRef);
}

private void startNewThread(ContextSnapshotRef contextSnapshotRef) {
    Thread thread = new Thread(() -> {
        // 在新线程中继续上下文快照
        Tracer.continued(contextSnapshotRef);
        SpanRef spanRef = Tracer.createLocalSpan("newThreadOperation");
        try {
            // 新线程中的操作代码
        } finally {
            Tracer.stopSpan();
        }
    });
    thread.start();
}
```

> 2. 然后在新的线程中 继续加载上下文快照

```java
public class NewThreadOperation implements Runnable {
    private final ContextSnapshotRef contextSnapshotRef;

    public NewThreadOperation(ContextSnapshotRef contextSnapshotRef) {
        this.contextSnapshotRef = contextSnapshotRef;
    }

    @Override
    public void run() {
        // 继续上下文快照
        Tracer.continued(contextSnapshotRef);
        SpanRef spanRef = Tracer.createLocalSpan("newThreadOperation");
        try {
            // 新线程中的操作代码
        } finally {
            Tracer.stopSpan();
        }
    }
}
```


### 3-4 Span tag


> Span 是 Skywalking 中的最小单元，类似 Cat 中的 Transaction


- `Tag` 和 `Log` 都是 `Span` 的属性，用来增强部分监控能力


> 可以使用 `Log` 来记录 异常信息.

```java
public void exampleMethod() {
    SpanRef spanRef = Tracer.createLocalSpan("exampleMethod");
    try {
        // 业务逻辑代码
    } catch (Exception e) {
        // 记录异常信息
        spanRef.log(e);
    } finally {
        Tracer.stopSpan();
    }
}

```


> 可以使用 `log` 来记录额外的动态字段，允许的入参是 `Map`

```java
public void exampleMethod() {
    SpanRef spanRef = Tracer.createLocalSpan("exampleMethod");
    try {
        // 业务逻辑代码
    } finally {
        // 记录自定义日志
        Map<String, String> logMap = new HashMap<>();
        logMap.put("event", "custom_event");
        logMap.put("message", "This is a custom log message");
        spanRef.log(logMap);

        Tracer.stopSpan();
    }
}

```

> 可以使用 `Tag` 来添加标签.


```java
spanRef.tag("key1", "value1");
spanRef.tag("key2", "value2");
```



### 3-5 Async Prepare Finish


Use `prepareForAsync` of `SpanRef` instance to make the span still alive until `asyncFinised` called, and then in specific time use `asyncFinish` of this `SpanRef` instance to notify this span that it could be finished.

```java
import org.apache.skywalking.apm.toolkit.trace.SpanRef;
...
  
SpanRef spanRef = Tracer.createLocalSpan("${operationName}");
spanRef.prepareForAsync();
// the span does not finish because of the prepareForAsync() operation
Tracer.stopSpan();
Thread thread = new Thread(() -> {
    ...
      
    spanRef.asyncFinish();
});
thread.start();
thread.join();
```


### 3-6 ActiveSpan 

You can use ActiveSpan to get the current span and do some operations.

- Add custom tag in the context of traced method, `ActivSpan.tag("key", "val")` .
- `ActiveSpan.error()` Mark the current span as error status .
- `ActiveSpan.error(String errorMsg)` Mark the current span as error status with a message.
- `ActiveSpan.debug(String debugMsg)` Add a debug level log message in the current span .
- `ActiveSpan.info(String infoMsg)` Add an info level log message in the current span.
- `ActiveSpan.setOperationName(String operationName)` Customize an operation name.



### 3-7 ReadOnly API

`TraceContext.traceId()`: 
• **作用**：获取当前 Trace 的唯一标识符。
• **意义**：traceId 用于标识一次完整的分布式请求链路，可以跨越多个服务。

`TraceContext.segmentId()`: 
• **作用**：获取当前 Segment 的唯一标识符。
• **意义**：segmentId 用于标识一个服务实例中的一个部分追踪数据。每个 Segment 对应于一个服务实例中的一系列操作。

`TraceContext.spanId()`:
• **作用**：获取当前 Span 的唯一标识符。
• **意义**：spanId 用于标识一个具体的操作，例如一次 HTTP 请求或数据库查询。每个 Span 都有一个唯一的标识符。


### 3-8 Annotation


```java
@Trace
@Tag(key = "tag1", value = "arg[0]")
@Tag(key = "tag2", value = "arg[1]")
@Tag(key = "username", value = "returnedObj.username")
@Tag(key = "age", value = "returnedObj.age")
public User methodYouWantToTrace(String param1, String param2) {
    // ...
}
```


### 3-9 Trace Cross Thread API


- **Case 1**

```java
    @TraceCrossThread
    public static class MyCallable<String> implements Callable<String> {
        @Override
        public String call() throws Exception {
            return null;
        }
    }
...
    ExecutorService executorService = Executors.newFixedThreadPool(1);
    executorService.submit(new MyCallable());
```

有一个注解.  这个注解应该会包装这个 MyCallable 为下面的特定的 CallableWrapper. 本质上是一样的.

```java
    ExecutorService executorService = Executors.newFixedThreadPool(1);
    executorService.submit(CallableWrapper.of(new Callable<String>() {
        @Override public String call() throws Exception {
            return null;
        }
    }));
```

或者 `RunnableWrapper` .

```java
    ExecutorService executorService = Executors.newFixedThreadPool(1);
    executorService.execute(RunnableWrapper.of(new Runnable() {
        @Override public void run() {
            //your code
        }
    }));
```



详细见 : [Cross-Thread-API](https://skywalking.apache.org/docs/skywalking-java/next/en/setup/service-agent/java-agent/application-toolkit-trace-cross-thread/)




## 4-Meter APIS

详见 [文档](https://skywalking.apache.org/docs/skywalking-java/next/en/setup/service-agent/java-agent/application-toolkit-meter/)

```xml
   <dependency>
      <groupId>org.apache.skywalking</groupId>
      <artifactId>apm-toolkit-meter</artifactId>
      <version>${skywalking.version}</version>
   </dependency>
```


支持 `MicroMeter` 但是好像没有看见页面. `UI`  太弱.


