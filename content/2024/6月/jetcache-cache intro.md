


## 1-spring cache

[Refer](https://docs.spring.io/spring-boot/reference/io/caching.html)


> spring-cache 的基本姿势

- 使用 `@EnableCaching` 开启缓存的基础设施
- 同时支持 `JSR-107` 提供的 `JCache` 注解和 `Spring-Cache` 的原生注解, **不要混用**
- 他期望的姿势是通过注解 透明的控制缓存.

```java
  
    @Cacheable("piDecimals")
    public int computePiDecimal(int precision) {
        // ... 实现计算逻辑
    }
```


- 同时可以使用方法:  `update` 和 `evict` 来显性的控制缓存行为

> 他的目的是为了解耦 `Cache Providers` .

通过 `org.springframework.cache.Cache` 和 `org.springframework.cache.CacheManager` 相关接口可以解耦如下的 缓存控制方案.



> Impl

`Spring Cache` 解耦了如下的 `Provider`:

- [General](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.generic) : 通用的缓存
- [JCache (JSR-107](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.jcache): 符合 `JSR` 规范的缓存设施
- [hazelcast](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.hazelcast) 
- [couchbase](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.couchbase)
- [redis](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.redis)
- [caffeine](https://docs.spring.io/spring-boot/reference/io/caching.html#io.caching.provider.caffeine)


感觉确实没有 [JetCache](https://github.com/alibaba/jetcache/tree/master) 做的好.  但是比较简单，依赖也比较简单. 不会有什么冲突.


## 2-JetCache Intro


> 核心 API 


```java
V get(K key)
void put(K key, V value);
boolean putIfAbsent(K key, V value); //多级缓存MultiLevelCache不支持此方法
boolean remove(K key);
<T> T unwrap(Class<T> clazz);//2.2版本前，多级缓存MultiLevelCache不支持此方法
Map<K,V> getAll(Set<? extends K> keys);
void putAll(Map<? extends K,? extends V> map);
void removeAll(Set<? extends K> keys);
```


- 这个是 `JSR-107` 的简化版本,处于  **效率性能** 和 **复杂程度**
- 同时提供了特有的系列 `API`, `CompuiteIfAbsent(K key, Function<K,V> loader)` 
- 大写 `API`: 这套 `API` 是为了解决原生 `API` 的功能缺陷, 返回值封装为一个对象, 暴漏更多的错误信息. 例如:
	- 当get返回null的时候，无法断定是对应的key不存在，还是访问缓存发生了异常




**大写 API 的使用 demo**

```java
CacheGetResult<OrderDO> r = cache.GET(orderId);
if( r.isSuccess() ){
    OrderDO order = r.getValue();
} else if (r.getResultCode() == CacheResultCode.NOT_EXISTS) {
    System.out.println("cache miss:" + orderId);
} else if(r.getResultCode() == CacheResultCode.EXPIRED) {
    System.out.println("cache expired:" + orderId));
} else {
    System.out.println("cache get error:" + orderId);
}
```


**高级 API: 需要大写 API 支持**

- 异步
- 自动 `load` : 也就是 `read throught` 策略
- 自动刷新缓存. 

下面是三个例子.


```java
// 异步 API 例子
CacheGetResult<UserDO> r = cache.GET(userId);
CompletionStage<ResultData> future = r.future();
future.thenRun(() -> {
    if(r.isSuccess()){
        System.out.println(r.getValue());
    }
});

```


```java
// loading cache 例子
Cache<Long,UserDO> userCache = LinkedHashMapCacheBuilder.createLinkedHashMapCacheBuilder()
                .loader(key -> loadUserFromDatabase(key))
                .buildCache();
```


```java
// 自动 refresh 需要配合 loading cache
RefreshPolicy policy = RefreshPolicy.newPolicy(1, TimeUnit.MINUTES)
                .stopRefreshAfterLastAccess(30, TimeUnit.MINUTES);
Cache<String, Long> orderSumCache = LinkedHashMapCacheBuilder
                .createLinkedHashMapCacheBuilder()
                .loader(key -> loadOrderSumFromDatabase(key))
                .refreshPolicy(policy)
                .buildCache();
```


> 相关 `jar` 包


- `jetcache-anno-api`：定义 `jetcache` 的注解和常量，不传递依赖。如果你想把Cached注解加到接口上，又不希望你的接口jar传递太多依赖，可以让接口jar依赖jetcache-anno-api。
- `jetcache-core`：核心api，完全通过编程来配置操作`Cache`，不依赖Spring。两个内存中的缓存实现`LinkedHashMapCache`和`CaffeineCache`也由它提供。
- `jetcache-anno`：基于Spring提供@Cached和@CreateCache注解支持。
- `jetcache-redis`：使用jedis提供Redis支持。
- `jetcache-redis-lettuce`（需要JetCache2.3以上版本）：使用lettuce提供Redis支持，实现了JetCache异步访问缓存的的接口。
- `jetcache-starter-redis`：Spring Boot方式的Starter，基于Jedis。
- `jetcache-starter-redis-lettuce`（需要JetCache2.3以上版本）：`Spring Boot` 方式的 `Starter`，基于 `Lettuce`。




## 3-Value Coder



**使用自定义 JacksonCoder 的例子**


```kotlin
package com.aitogether.ai.chat.core.utils.jetcache  
  
import com.aitogether.ai.chat.core.utils.json.JsonUtils  
import com.alicp.jetcache.support.AbstractJsonDecoder  
import com.alicp.jetcache.support.AbstractJsonEncoder  
import java.nio.charset.StandardCharsets  
  
class JacksonValueEncoder(useIdentityNumber: Boolean) : AbstractJsonEncoder(useIdentityNumber) {  
    override fun encodeSingleValue(value: Any): ByteArray {  
        return JsonUtils.mapper.writeValueAsString(value).toByteArray(StandardCharsets.UTF_8)  
    }  
  
    companion object {  
        val INSTANCE = JacksonValueEncoder(false)  
    }  
}  
  
class JacksonValueDecoder(useIdentityNumber: Boolean) : AbstractJsonDecoder(useIdentityNumber) {  
    override fun parseObject(buffer: ByteArray, index: Int, len: Int, clazz: Class<*>): Any {  
        val jsonString = String(  
            buffer,  
            index,  
            len,  
            StandardCharsets.UTF_8  
        )  
  
        return JsonUtils.mapper.readValue(jsonString, clazz)  
    }  
  
    companion object {  
        val INSTANCE = JacksonValueDecoder(false)  
    }  
}
```


**关于 useIdentityNumber 的说明**


```java
if (useIdentityNumber) {  
    writeInt(output, SerialPolicy.IDENTITY_NUMBER_KRYO4);  
}
```


**使用 kryo 的例子**


```kotlin
val orderCache = RedisLettuceCacheBuilder.createRedisLettuceCacheBuilder()  
    .keyConvertor(JacksonKeyConvertor.INSTANCE)  
    .valueEncoder(KryoValueEncoder.INSTANCE)  
    .valueDecoder(KryoValueDecoder.INSTANCE)  
    .redisClient(client)  
    .keyPrefix("orderCache")  
    .refreshPolicy(policy)  
    /*写入之后自动 ttl*/    .expireAfterWrite(60, TimeUnit.SECONDS)  
    .loader(CacheLoader<String, JetCacheTestItem> { slowFetch(it, Duration.ofSeconds(1L)) })  
    .buildCache<String, JetCacheTestItem>()  
  
println(orderCache.get("order1"))  
println(orderCache.get("order1"))  
  
client.shutdown()
```

看了下源码:

- 使用自定义的对象池缓存了 `Kryo` 对象，一般默认其实喜欢用 `ThreadLocal` 来缓存的，这里做的不是很好
- 没有支持 `registerClass` 策略来优化 `Kryo` 的性能


> 最后看一下序列化的结果


```
使用 json 的结果: 
 #com.alicp.jetcache.CacheValueHolder   D{"value":null,"expireTime":1718078257331,"accessTime":1718078197331} 3com.aitogether.ai.chat.it.jetcache.JetCacheTestItem   H{"orderId":"order1","gmtCreate":1718078197330,"gmtUpdate":1718078197330}


使用 kryo 的结果:
J�:� com.alicp.jetcache.CacheValueHolde�accessTim�expireTim�valu����߀d ���߀d hcom.aitogether.ai.chat.it.jetcache.JetCacheTestIte�gmtCreat�gmtUpdat�orderI�java.util.Dat���ᯀ2 	��ᯀ2	 order�  
```


## 4-Use with Annotation



感觉配合 `Spring-Around-Aop` 实现应该是比较简单的. 先看他们的原始用法.

**官方用法: @EnableCreateCacheAnnotation 开启注解**

- `CreateCache` 的详细使用说明可以看[这里](https://github.com/alibaba/jetcache/blob/2.6/docs/CN/CreateCache.md)
- 使用@CacheCache创建的Cache接口实例，它的API使用可以看[这里](https://github.com/alibaba/jetcache/blob/2.6/docs/CN/CacheAPI.md)
- 关于方法缓存(@Cached, @CacheUpdate, @CacheInvalidate)的详细使用看[这里](https://github.com/alibaba/jetcache/blob/2.6/docs/CN/MethodCache.md)
- 详细的配置说明看[这里](https://github.com/alibaba/jetcache/blob/2.6/docs/CN/Config.md)。


