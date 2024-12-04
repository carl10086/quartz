

## 1-Intro


## 2-In Action

> 使用 `Spring-AOP` 注解集成

```kotlin
@Target(AnnotationTarget.FUNCTION)  
@Retention(AnnotationRetention.RUNTIME)  
annotation class Resilience4jAnno(  
    val enableCircuitBreaker: Boolean = false,  
    val circuitBreakName: String = "default",  
  
    val enableRetry: Boolean = false,  
    val retryName: String = "default",  
)  
  
class Resilience4jRegistryBean(  
    defaultCircuitBreakerConfig: CircuitBreakerConfig = CircuitBreakerConfig.ofDefaults(),  
    defaultRetryConfig: RetryConfig = RetryConfig.ofDefaults(),  
) {  
    private val circuitBreakerRegistry = CircuitBreakerRegistry.of(defaultCircuitBreakerConfig)  
    private val retryRegistry = RetryRegistry.of(defaultRetryConfig)  
  
    fun registerCircuitBreaker(name: String, config: CircuitBreakerConfig) {  
        circuitBreakerRegistry.circuitBreaker(name, config)  
    }  
  
    fun circuitBreaker(name: String): CircuitBreaker {  
        return circuitBreakerRegistry.circuitBreaker(name)  
    }  
  
    fun registerRetry(name: String, config: RetryConfig) {  
        retryRegistry.retry(name, config)  
    }  
  
    fun retry(name: String): Retry {  
        return this.retryRegistry.retry(name)  
    }  
  
  
}  
  
  
@Aspect  
open class Resilience4jAspect(private val registryBean: Resilience4jRegistryBean) {  
  
    @Around("@annotation(resilience4jAnno)")  
    fun resilience4jAround(  
        joinPoint: ProceedingJoinPoint,  
        resilience4jAnno: Resilience4jAnno  
    ): Any? {  
        val methodName = joinPoint.signature.name  
        val className = joinPoint.signature.declaringTypeName  
        logger.info("Resilience4jAspect started for class: {}, method: {}", className, methodName)  
  
        var supplier = Supplier { joinPoint.proceed() }  
  
        /*1. 开启熔断*/  
        if (resilience4jAnno.enableCircuitBreaker) {  
            val circuitBreaker = registryBean.circuitBreaker(name = resilience4jAnno.circuitBreakName)  
            supplier = CircuitBreaker.decorateSupplier(circuitBreaker, supplier)  
        }  
  
        /*2. 开启 retry*/        if (resilience4jAnno.enableRetry) {  
            val retry = registryBean.retry(name = resilience4jAnno.retryName)  
            supplier = Retry.decorateSupplier(retry, supplier)  
        }  
  
        return try {  
            supplier.get()  
        } catch (e: Exception) {  
            when (e) {  
                is CallNotPermittedException -> {  
                    logger.error("Circuit breaker open for class: {}, method: {}", className, methodName, e)  
                    throw SystemErrorException("Circuit breaker open for class: $className, method: $methodName", e)  
                }  
  
                else -> throw e  
            }  
        }  
    }  
  
    companion object {  
        private val logger = LogManager.getLogger(Resilience4jAspect::class.java)  
    }  
  
  
}
```

> 熔断 比较简单

```java
@Bean  
open fun resilience4jAspect(): Resilience4jAspect {  
    val resilience4jRegistryBean = Resilience4jRegistryBean()  
    resilience4jRegistryBean.registerCircuitBreaker(  
        "tutorgpt2",  
        CircuitBreakerConfig.custom() /*Configures the failure rate threshold in percentage. When the failure rate is equal or greater than the threshold the CircuitBreaker transitions to open and starts short-circuiting calls.*/  
            .failureRateThreshold(40f) /*Configures a threshold in percentage. The CircuitBreaker considers a call as slow when the call duration is greater than slowCallDurationThreshold When the percentage of slow calls is equal or greater the threshold, the CircuitBreaker transitions to open and starts short-circuiting calls.*/  
            .slowCallRateThreshold(100f) /*Configures the duration threshold above which calls are considered as slow and increase the rate of slow calls.*/  
            .slowCallDurationThreshold(Duration.ofMinutes(10)) /*The time that the CircuitBreaker should wait before transitioning from open to half-open.*/  
            .waitDurationInOpenState(Duration.ofMillis(60000)) /*the permitted number of calls when the CircuitBreaker is half open*/  
            .permittedNumberOfCallsInHalfOpenState(10) /*Configures the type of the sliding window which is used to record the outcome of calls when the CircuitBreaker is closed. Sliding window can either be count-based or time-based. If the sliding window is COUNT_BASED, the last slidingWindowSize calls are recorded and aggregated. If the sliding window is TIME_BASED, the calls of the last slidingWindowSize seconds recorded and aggregated. */  
            .slidingWindowType(SlidingWindowType.COUNT_BASED) /*Configures the size of the sliding window which is used to record the outcome of calls when the CircuitBreaker is closed.*/  
            .slidingWindowSize(50)  
            .minimumNumberOfCalls(50)  
            .build()  
    )  
    return Resilience4jAspect(resilience4jRegistryBean)  
}
```


> 重试


```kotlin
        val retryConfig = RetryConfig.custom<Int>()  
            .maxAttempts(2) /* 最大重试2次 */            .waitDuration(Duration.ofMillis(100)) /* 重试间隔 100毫秒 *///            .retryExceptions(ArgumentInvalidException::class.java) /* 支持基于异常的重试策略 */            .retryOnResult { it < 5 } /* 总是返回 false 的 retryOnResultPredicate */            .failAfterMaxAttempts(true) /* 达到最大重试次数, 如果配置了 retryOnResult 会抛出 MaxExceedException*/            .build()
```


- 需要注意的是，在 基于结果的重试策略中, `failAfterMaxAttempt=true`才会把结果包装为一个 `MaxExceedException`, 如果是 基于异常的重试策略不会生效，依旧是之前的异常.