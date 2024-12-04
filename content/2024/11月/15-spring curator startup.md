
## refer

- [Application Startup Tracking](https://docs.spring.io/spring-framework/docs/5.3.x/reference/html/core.html#context-functionality-startup)
- [Spring boot Startup Endpoint](https://www.baeldung.com/spring-boot-actuator-startup)
- [sofaBoot 的异步化启动 demo](https://help.aliyun.com/document_detail/133162.html)
- [baeldung-startUp](https://www.baeldung.com/spring-boot-actuator-startup)

## 1-intro

这个一般分为问题的定位 和 问题的解决，这里专注于问题的解决.

## 2-ApplicationStartup

这个工具是 `Spring` 官方提供的, 子类 用于收集各个启动阶段的 `StartupStep` 数据, 例如如下的阶段:

- 应用上下文生命周期 (基础包的扫描, 配置类管理)
- `bean` 的生命周期 (实例化, 智能初始化, 后处理)
- 应用事件处理


默认的实现 `DefaultApplicationStartup` 是一个空实现, 没有性能损失.  `SpringBoot`  原生还支持2种. 一种 `Buffered` 的，一种 `JFR` 的 .



## 3-Custom Log StartUp Implementation

一个最简单的实现，用于测试其原理.

```kotlin
import org.slf4j.LoggerFactory  
import org.springframework.core.metrics.ApplicationStartup  
import org.springframework.core.metrics.StartupStep  
import java.util.concurrent.ConcurrentHashMap  
import java.util.concurrent.atomic.AtomicInteger  
import java.util.function.Supplier  
  
class CustomApplicationStartup : ApplicationStartup {  
  
    val inProgressSteps = ConcurrentHashMap<Long, StartupStep>()  
    val stepDurations = ConcurrentHashMap<String, Long>()  
    val counter = AtomicInteger()  
  
  
    override fun start(name: String): StartupStep {  
        val step = CustomStartupStep(name, System.nanoTime(), counter.incrementAndGet().toLong())  
        inProgressSteps.put(Thread.currentThread().threadId(), step)  
        return step  
    }  
  
    companion object {  
        private val log = LoggerFactory.getLogger(CustomApplicationStartup::class.java)  
    }  
  
    inner class CustomStartupStep(  
        val _name: String,  
        val startTime: Long,  
        val _id: Long,  
        val tags: MutableList<StartupStep.Tag> = ArrayList<StartupStep.Tag>(),  
    ) : StartupStep {  
        override fun getName(): String = _name  
  
        override fun getId(): Long = _id  
  
        override fun getParentId(): Long? = null  
  
        override fun tag(key: String, value: String): StartupStep {  
            this.tags.add(DefaultTag(key, value))  
            return this  
        }  
  
        override fun tag(  
            key: String,  
            value: Supplier<String>  
        ): StartupStep = tag(key, value.get())  
  
        override fun getTags(): StartupStep.Tags = StartupStep.Tags {  
            tags.iterator()  
        }  
  
        override fun end() {  
            val duration = (System.nanoTime() - startTime) / 1_000_000L  
            stepDurations.put(_name, duration)  
            inProgressSteps.remove(Thread.currentThread().threadId())  
            log.info("step end: $_name, duration: $duration, tags: ${tags.joinToString(", ")}")  
        }  
  
    }  
  
  
    data class DefaultTag(  
        private val _key: String,  
        private val _value: String  
    ) : StartupStep.Tag {  
        override fun getKey(): String = _key  
        override fun getValue(): String = _value  
    }  
}
```


## 4-Spring acutator startup endpoint

**1)-开启 startup 端点**

```yaml
management:  
  endpoints:  
    web:  
      exposure:  
        include: startup
```

**2)-使用 BufferedStartUp 记录**


```kotlin
    val app = SpringApplication(ExampleApp::class.java)  
//    app.applicationStartup = CustomApplicationStartup()  
    app.applicationStartup = BufferingApplicationStartup(10240)
    app.run(*args)
```

- 注意， `10240` 是内存中的 cap, 超过了，新的 `step` 不会记录

如果要加过滤, 使用如下配置:

```java
BufferingApplicationStartup startup = new BufferingApplicationStartup(2048);
startup.addFilter(startupStep -> startupStep.getName().matches("spring.beans.instantiate");
```


- 一键发现.

```bash
> curl 'http://localhost:8080/actuator/startup' -X POST \
| jq '[.timeline.events
 | sort_by(.duration) | reverse[]
 | select(.startupStep.name | match("spring.beans.instantiate"))
 | {beanName: .startupStep.tags[0].value, duration: .duration}]'
```


