

## Refer

- [Distributed Locks with Redis](https://redis.io/docs/latest/develop/use/patterns/distributed-locks/)
- [redisson](https://github.com/redisson/redisson): 一个 `Java` 的企业级库

## 1-Redisson 可重入锁 源码分析

> 比较坑

- 强依赖 `Kryo5` : 这个序列化有点恶心了 ..
- 强依赖 `Netty`: 这个很正常

> 看 `redisson` 源码中的分布式锁实现核心代码也是一个 `lua`


```java
  
<T> RFuture<T> tryLockInnerAsync(long waitTime, long leaseTime, TimeUnit unit, long threadId, RedisStrictCommand<T> command) {  
    return evalWriteSyncedAsync(getRawName(), LongCodec.INSTANCE, command,  
            "if ((redis.call('exists', KEYS[1]) == 0) " +  
                        "or (redis.call('hexists', KEYS[1], ARGV[2]) == 1)) then " +  
                    "redis.call('hincrby', KEYS[1], ARGV[2], 1); " +  
                    "redis.call('pexpire', KEYS[1], ARGV[1]); " +  
                    "return nil; " +  
                "end; " +  
                "return redis.call('pttl', KEYS[1]);",  
            Collections.singletonList(getRawName()), unit.toMillis(leaseTime), getLockName(threadId));  
}


protected RFuture<Boolean> unlockInnerAsync(long threadId, String requestId, int timeout) {  
    return evalWriteSyncedAsync(getRawName(), LongCodec.INSTANCE, RedisCommands.EVAL_BOOLEAN,  
                          "local val = redis.call('get', KEYS[3]); " +  
                                "if val ~= false then " +  
                                    "return tonumber(val);" +  
                                "end; " +  
  
                                "if (redis.call('hexists', KEYS[1], ARGV[3]) == 0) then " +  
                                    "return nil;" +  
                                "end; " +  
                                "local counter = redis.call('hincrby', KEYS[1], ARGV[3], -1); " +  
                                "if (counter > 0) then " +  
                                    "redis.call('pexpire', KEYS[1], ARGV[2]); " +  
                                    "redis.call('set', KEYS[3], 0, 'px', ARGV[5]); " +  
                                    "return 0; " +  
                                "else " +  
                                    "redis.call('del', KEYS[1]); " +  
                                    "redis.call(ARGV[4], KEYS[2], ARGV[1]); " +  
                                    "redis.call('set', KEYS[3], 1, 'px', ARGV[5]); " +  
                                    "return 1; " +  
                                "end; ",  
                            Arrays.asList(getRawName(), getChannelName(), getUnlockLatchName(requestId)),  
                            LockPubSub.UNLOCK_MESSAGE, internalLockLeaseTime,  
                            getLockName(threadId), getSubscribeService().getPublishCommand(), timeout);  
}

protected final RFuture<Boolean> unlockInnerAsync(long threadId) {  
    String id = getServiceManager().generateId();  
    MasterSlaveServersConfig config = getServiceManager().getConfig();  
    int timeout = (config.getTimeout() + config.getRetryInterval()) * config.getRetryAttempts();  
    timeout = Math.max(timeout, 1);  
    RFuture<Boolean> r = unlockInnerAsync(threadId, id, timeout);  
    CompletionStage<Boolean> ff = r.thenApply(v -> {  
        CommandAsyncExecutor ce = commandExecutor;  
        if (ce instanceof CommandBatchService) {  
            ce = new CommandBatchService(commandExecutor);  
        }  
        ce.writeAsync(getRawName(), LongCodec.INSTANCE, RedisCommands.DEL, getUnlockLatchName(id));  
        if (ce instanceof CommandBatchService) {  
            ((CommandBatchService) ce).executeAsync();  
        }  
        return v;  
    });  
    return new CompletableFutureWrapper<>(ff);  
}
```


来分析这个 源代码的逻辑. 


### 1-1 Lock


```lua
if ((redis.call('exists', KEYS[1]) == 0) or (redis.call('hexists', KEYS[1], ARGV[2]) == 1)) then 
    redis.call('hincrby', KEYS[1], ARGV[2], 1); 
    redis.call('pexpire', KEYS[1], ARGV[1]); 
    return nil; 
end; 
return redis.call('pttl', KEYS[1]);
```

我们先说一下参数:

1. `KEYS[1]`: 锁的名称
2. `ARGV[1]`: 锁的过期时间 (单位是毫秒)
3. `ARGV[2]`: `requestId`, 基于一个提前生成的 `uuid` + `threadId` 生成的字符串


核心的数据结构是 `HASH` .



### 1-2 Unlock


```lua
local val = redis.call('get', KEYS[3]);
if val ~= false then 
    return tonumber(val);
end;

if (redis.call('hexists', KEYS[1], ARGV[3]) == 0) then 
    return nil; 
end;

local counter = redis.call('hincrby', KEYS[1], ARGV[3], -1);
if (counter > 0) then 
    redis.call('pexpire', KEYS[1], ARGV[2]); 
    redis.call('set', KEYS[3], 0, 'px', ARGV[5]); 
    return 0; 
else 
    redis.call('del', KEYS[1]); 
    redis.call(ARGV[4], KEYS[2], ARGV[1]); 
    redis.call('set', KEYS[3], 1, 'px', ARGV[5]); 
    return 1; 
end;
```


> 首先参数非常多.

**参数解释:**

- `KEYS` :
	- `KEYS[1]`: 锁的键名
	- `KEYS[2]`: 发布解锁消息的通道名
	- `KEYS[3]`: 解锁标识键 (﻿requestId 对应的标识键)
- `ARGV`:
	- `ARGV[1]`: 解锁消息内容（通常为 ﻿`LockPubSub.UNLOCK_MESSAGE`）
	- `ARGV[2]`: 锁的过期时间（﻿`internalLockLeaseTime`）
	- `ARGV[3]`: 当前线程的标识（锁名由 ﻿`getLockName(threadId)` 生成）
	- `ARGV[4]`: 发布命令（通常为 ﻿`PUBLISH`）
	- `ARGV[5]`: 标识键值的过期时间（﻿`timeout`）

> 核心步骤

通过 `debug` 得到 `demo` 的 `keys` 和 `params` :

```
keys = {Arrays$ArrayList@7862}  size = 3
 1 = "myLock"
 2 = "redisson_lock__channel:{myLock}"
 3 = "redisson_unlock_latch:{myLock}:4ca507bfdebe29c3aa51492fef1595c8"
```

```
params = {Object[5]@7863} 
 1 = {Long@7860} 0
 2 = {Long@8875} 30000
 3 = "620a2a39-0425-483c-afa0-a384b56605f9:1"
 4 = "PUBLISH"
 5 = {Integer@8878} 13500
```

1. 如果 `lockName` 不存在，直接返回 `nil`
2. 执行 `counter` 减少 1
3. 如果减少后还是 `> 0`
	- 处理一下 `expire` ,  `pexpire myLock 30000`
	- 设置了一个标志位, `set redisson_unlock_latch:{myLock}:4ca507bfdebe29c3aa51492fef1595c8 0 px 13500` : 设置 `unlock` 标志位为 0 
4. 如果减少后 `=0` 了 
	- `del myLock` : 删除 key
	- `PUBLISH redisson_lock__channel:{myLock} 0` : 发送通知 删除了 这个 `key`
	- `set redisson_unlock_latch:{myLock}:4ca507bfdebe29c3aa51492fef1595c8 1 px 13500` : 设置 `unlock` 标志位 为 1


## 2-Redis 官方文档


> Safety and Liveness Guarantees


1. **Safety Property** : Mutual exclusion. At any given moment, only one client can hold a lock ;
	- 在任意时刻, 只有一个客户端可以持久锁
	- 一般会 用一个 `UUID` 去标记一个客户端

2. **Deadlock Free** : 就算 **占有锁的客户端发生崩溃** 或者 **集群发生网络分区**, 客户端也能 获取和释放锁 ;
	- 一般使用 `TTL` 来实现锁的最终获取

3. **Fault Tolerance** : 只要 `Redis` 节点中大多数在运行，就能让 客户端正确的 获取和释放锁
	- 典型的方案是获取到 `Redis` 的 `Redlock` 算法.



`RedLock` 的实现算法:
1. 客户端获取一个当前时间, 用来计算获取锁的超时时间 ;
2. 客户端 依次向多个 实例 `Redis` 请求获取锁, 每个锁的有效期设置为 一段时间 (例如 `10s` ) ;
3. 客户端尝试在最短时间内获取多数实例的锁 (3个或者更多);
4. 如果获取多数锁的时间 小于 锁的有效期, 那么获取锁成功 ;
5. 如果锁失败 (如果超时或者获取不到多数锁), 则释放已获得的所有锁，并且重试 ;
6. 释放锁是 通过向实例发送带有唯一键 标志的 `UUID` 的解锁请求来实现的 ;



下面是基于官方文档的  **单实例简单分布式锁实现**


```kotlin
import com.aitogether.ai.chat.core.utils.io.ClassResourceUtils  
import io.lettuce.core.ScriptOutputType  
import io.lettuce.core.SetArgs  
import io.lettuce.core.api.sync.RedisCommands  
import org.apache.logging.log4j.LogManager  
import java.time.Duration  
import java.util.*  
  
interface RedisLock {  
    /**  
     * @param resource: 要锁的资源粒度  
     * @param ttl: 锁的超时时间  
     * @param  
     */  
    fun tryLock(resource: String, ttl: Duration): Boolean  
    fun unlock(resource: String)  
}  
  
/**  
 * 单实例的 安全分布式锁, 基于 redis 官方文档实现  
 * https://redis.io/docs/latest/develop/use/patterns/distributed-locks/#implementations 中的 单实例算法  
 */  
class SimpleRedisLock(private val sync: RedisCommands<String, String>) : RedisLock {  
  
    companion object {  
        val id = UUID.randomUUID().toString()  
        fun clientId(): String {  
            return "$id:${Thread.currentThread().threadId()}"  
        }  
  
        private val logger = LogManager.getLogger(SimpleRedisLock::class.java)  
  
        private val unlockLua: RedisLuaScript =  
            RedisLuaScript(ClassResourceUtils.readAsString("lua/single_redis_lock_unlock.lua"))  
    }  
  
    override fun tryLock(resource: String, ttl: Duration): Boolean {  
        val clientId = clientId()  
        val result = sync.set(resource, clientId, SetArgs.Builder.nx().px(ttl))  
        logger.info("lock finish, clientId:{}, resource:{}, result:{}", clientId, resource, result)  
        return result == "OK"  
    }  
  
    override fun unlock(resource: String) {  
        val clientId = clientId()  
        val result: Int = LettuceEvalTools.evalLuaScript(  
            unlockLua,  
            sync,  
            ScriptOutputType.INTEGER,  
            arrayOf(resource),  
            clientId  
        )  
  
        logger.info("unlock finish, clientId:{}, resource:{}, result:{}", clientId, resource, result)  
    }  
  
  
}
```


`lua` 脚本:

```lua
if redis.call("get",KEYS[1]) == ARGV[1] then  
    return redis.call("del",KEYS[1])  
else  
    return 0  
end
```
