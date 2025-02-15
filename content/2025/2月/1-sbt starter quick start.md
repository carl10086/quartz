
## 1-概述

在封装 `spring boot starter` 的时候经常会碰见一些问题， 记录一下. 核心思路 约定大于配置


**1)-打开日志可以看详细的信息**

```yaml
logging:  
  level:  
    org.springframework.boot.autoconfigure: DEBUG  
    org.springframework.context.annotation: DEBUG
```



**2)-基于 sbt 补充单元测试**

```kotlin
@SpringBootTest(  
    classes = [TosAutoConfiguration::class],  // 指定配置类  
//    properties = ["spring.config.location=classpath:"]  // 防止加载其他配置  
)  
internal class SbtTest {
	...
}
```


## 2-基础

### 2-1 条件控制

类条件注解, 例如:
 - `ConditionalOnClass` : 当指定的类存在于类路径时，配置生效
 - `ConditionalOnMissingClass`: 当指定的类不存在于类路径时，配置生效

Bean 条件注解:
- `ConditionalOnBean` : 当指定的 Bean 存在时，配置生效
- `ConditionalOnMissingBean` : 当指定的 Bean 不存在时，配置生效

属性条件注解: 
- `ConditionalOnProperty`
- `ConditionalOnResource`

```kotlin
// 当 tos.enabled=true 时生效
@ConditionalOnProperty(prefix = "tos", name = ["enabled"], havingValue = "true")
class TosConfiguration {
    // ...
}

// 当属性不存在时也生效
@ConditionalOnProperty(
    prefix = "tos",
    name = ["feature"],
    havingValue = "true",
    matchIfMissing = true
)
class OptionalFeatureConfiguration {
    // ...
}
```

```kotlin
// 当存在配置文件时生效
@ConditionalOnResource(resources = ["classpath:tos-config.yml"])
class TosResourceConfiguration {
    // ...
}
```

Web 应用条件注解:

```kotlin
// 仅在 Web 环境下生效
@ConditionalOnWebApplication
class TosWebConfiguration {
    // ...
}

// 指定 Web 应用类型
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
class TosServletConfiguration {
    // ...
}
```


表达式条件注解:

```kotlin
@ConditionalOnExpression("\${tos.enabled:true} and \${tos.region:null} != null")
class ComplexConfiguration {
    // ...
}
```

自定义条件注解:

```kotlin
class OnTosFeatureCondition : SpringBootCondition() {
    override fun getMatchOutcome(
        context: ConditionContext,
        metadata: AnnotatedTypeMetadata
    ): ConditionOutcome {
        // 自定义条件逻辑
        return ConditionOutcome(
            true,
            "TOS feature is enabled"
        )
    }
}

@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.RUNTIME)
@Conditional(OnTosFeatureCondition::class)
annotation class ConditionalOnTosFeature

@ConditionalOnTosFeature
class CustomFeatureConfiguration {
    // ...
}
```



## 3-测试

配置放到 `META-INF/spring/com.lyy.starters.tos.TosAutoConfiguration` 中.
- 里面写的都是类名

一个 `DEMO` :

```kotlin
package com.lyy.starters.tos  
  
data class TransportProps(  
    /**  
     * 连接超时  
     */  
    var connectionTimeout: Duration = Duration.ofSeconds(10),  
  
    /**  
     * 读取超时  
     */  
    var readTimeout: Duration = Duration.ofSeconds(30),  
  
    /**  
     * 写入超时  
     */  
    var writeTimeout: Duration = Duration.ofSeconds(30)  
)  
  
@ConfigurationProperties(prefix = "tos")  
@Validated  
data class TosProperties(  
    var endpoint: String = "tos-cn-beijing.volces.com",  
    var region: String = "cn-beijing",  
    @field:NotBlank  
    var accessKey: String = "",  
    @field:NotBlank  
    var secretKey: String = "==",  
    var transport: TransportProps = TransportProps()  
)  
  
@Configuration  
@EnableConfigurationProperties(TosProperties::class)  
@ConditionalOnClass(TOSV2::class)  
open class TosAutoConfiguration {  
  
    @ConditionalOnMissingBean  
    @Bean    open fun tosClientBean(tosProperties: TosProperties): TosClientBean {  
        val bean = TosClientBean(tosProperties)  
        return bean  
    }  
}
```


