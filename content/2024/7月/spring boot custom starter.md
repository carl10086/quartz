

## Refer

- [Creating a Custom Starter with Spring Boot](https://www.baeldung.com/spring-boot-custom-starter)


## QuickStart


Spring boot 会在启动的时候去 `classpath` 中寻找一个叫做 `spring.factories` 的文件. 其中要包含 自动配置类的列表.


取而代之的是:


`META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports



> 常用的注解.


◦ @Configuration 标记这是一个配置类。
◦ @ConditionalOnClass(MongoClient.class) 表示只有在 MongoClient 类存在时才启用此配置。
◦ @EnableConfigurationProperties(MongoProperties.class) 启用配置属性绑定。
◦ @ConditionalOnMissingBean 确保不会覆盖已存在的 bean。


> 下面是一个 DEMO

需求是，重新定制一个健康探测功能，如果是 UP, 返回要是状态码等于 `200` 以及字符串 `OK` .

我们依赖于 `spring-boot-actuator`. 


```kotlin
import org.springframework.boot.actuate.autoconfigure.health.HealthEndpointAutoConfiguration  
import org.springframework.boot.actuate.health.HealthComponent  
import org.springframework.boot.actuate.health.HealthEndpoint  
import org.springframework.boot.actuate.health.Status  
import org.springframework.boot.autoconfigure.AutoConfiguration  
import org.springframework.boot.autoconfigure.AutoConfigureAfter  
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass  
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean  
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication  
import org.springframework.context.annotation.Bean  
import org.springframework.http.MediaType  
import org.springframework.web.servlet.function.RouterFunction  
import org.springframework.web.servlet.function.ServerResponse  
import org.springframework.web.servlet.function.router  
  
@AutoConfiguration  
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)  
@ConditionalOnClass(HealthEndpoint::class)  
@AutoConfigureAfter(HealthEndpointAutoConfiguration::class)  
class HealthCheckAutoConfiguration {  
  
    @Bean  
    @ConditionalOnMissingBean    fun healthCheckRoute(healthEndpoint: HealthEndpoint): RouterFunction<ServerResponse> = router {  
        GET("/check") {  
            val health = healthEndpoint.health()  
            when (health.status) {  
                Status.UP -> ServerResponse.ok().body("OK")  
                else -> {  
                    val details = formatHealthDetails(health)  
                    ServerResponse.status(503).contentType(MediaType.TEXT_PLAIN).body("FAILED\n$details")  
                }  
            }  
        }  
    }  
    private fun formatHealthDetails(health: HealthComponent): String {  
        return buildString {  
            appendLine("Status: ${health.status}")  
            when (health) {  
                is org.springframework.boot.actuate.health.Health -> {  
                    health.details.forEach { (key, value) ->  
                        appendLine("$key: $value")  
                    }  
                }  
  
                is org.springframework.boot.actuate.health.CompositeHealth -> {  
                    health.components.forEach { (key, component) ->  
                        appendLine("$key:")  
                        appendLine(formatHealthDetails(component).prependIndent("  "))  
                    }  
                }  
  
                else -> appendLine("Unexpected health type: ${health.javaClass.simpleName}")  
            }  
        }  
    }  
}
```


- `DONE`