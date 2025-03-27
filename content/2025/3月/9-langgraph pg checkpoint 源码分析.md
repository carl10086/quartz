
#langgraph


## 1-介绍

核心是 `AsyncPostgresSaver` 的类，它是langgraph库中用于在PostgreSQL数据库中存储和检索检查点(checkpoint)数据的异步实现。它继承自BasePostgresSaver，并提供了异步和同步接口来操作检查点数据。

其中:

- 导入了asyncio库处理异步操作
- 引入了psycopg工具来处理PostgreSQL连接
- 导入了langgraph中的检查点相关基础工具


## 2-分析

用了一些 `python` 的 `tips` .

**1)-asynccontextmanager**

简单解释：
上下文管理器就像是一个自动开关门的管理员。普通的上下文管理器使用with语句，而异步上下文管理器使用async with语句。

代码中的应用：
```python
@asynccontextmanager
async def from_conn_string(cls, conn_string: str, ...):
    # 开门：初始化数据库连接
    async with await AsyncConnection.connect(...) as conn:
        # 让用户进入并做事
        yield cls(conn=conn, serde=serde)
    # 用户完成后自动关闭连接（锁门）
```


**2)-线程和协程交互**

`asyncio.to_thread`： 简单解释：让耗时的普通函数在后台线程运行，不阻塞主要的异步代码。

`run_coroutine_threadsafe`：
- 简单解释：从普通线程中调用异步函数。
- 生活例子：您在办公室（普通线程）通过电话指挥家里的智能家居系统（异步系统）做事情。

```python
# asyncio.to_thread - 在异步代码中运行同步函数
await asyncio.to_thread(self._load_checkpoint, value["checkpoint"], ...)

  
# run_coroutine_threadsafe - 在同步代码中运行异步函数
return asyncio.run_coroutine_threadsafe(self.aget_tuple(config), self.loop).result()
```

基于这个可以做到:

- 让耗时操作不阻塞主程序
- 允许传统代码和新的异步代码共存和交互


使用 `asyncio.to_thread` 一个读取大文件的例子.

```python
def read_large_file(filename):
    with open(filename, 'r') as f:
        return f.read()  # 这可能需要很长时间

# 方式1：直接在异步函数中调用(会阻塞)
async def process_file_blocking():
    print("开始读取文件")
    content = read_large_file("huge_file.txt")  # 在这里，整个事件循环会被阻塞！
    print("文件读取完成")
    return content

# 方式2：使用 asyncio.to_thread（不会阻塞）
async def process_file_nonblocking():
    print("开始读取文件")
    content = await asyncio.to_thread(read_large_file, "huge_file.txt")  # 文件读取在另一个线程进行，不阻塞事件循环
    print("文件读取完成")
    return content
```


使用 同步函数，调用 异步函数的例子.

异步函数需要在事件循环中运行，但普通同步代码没有事件循环。

问题情景：
- 我们有一个正在运行的异步程序（有事件循环）
- 现在，从一个普通同步函数（比如在另一个线程中）需要调用异步函数

```python
def get_tuple(self, config: RunnableConfig):
    # 检查是否在主线程，如果是则建议使用异步接口
    try:
        if asyncio.get_running_loop() is self.loop:
            raise asyncio.InvalidStateError("应该使用异步接口...")
    except RuntimeError:
        pass  # 不在事件循环中，可以继续
        
    # 在已存在的事件循环中运行异步函数，并等待结果
    return asyncio.run_coroutine_threadsafe(
        self.aget_tuple(config), self.loop
    ).result()
```


## 3-time travel 和 记忆管理 


有的时候我希望根据 `thread_id` 清空当前的记忆. 我瞬间有3种想法.

1. 直接删除 `thread_id` 相关的数据: 彻底删除, **这个操作非常危险**， 适合在 `dev` 环境做 ;
2. 使用 `time_travel` 修改最后一个 `checkpoint` 把的数据都改为 空: 感觉不太靠谱而且危险, 没必要 ;
3. 使用 `time_travel` 再追加一个 空的 `checkpoint` 感觉安全一些 ;


**1)-异步删除的套路**

```python
async def delete_thread_data(postgres_saver, thread_id):
    """
    完全删除与特定 thread_id 相关的所有数据
    
    参数:
        postgres_saver: AsyncPostgresSaver 或 PostgresSaver 实例
        thread_id: 要删除的线程ID
    """
    async with postgres_saver._cursor() as cur:
        # 1. 首先删除 channel_values 表中的相关数据（如果存在）
        await cur.execute(
            "DELETE FROM checkpoint_blobs WHERE thread_id = %s",
            (thread_id,)
        )
        
        # 2. 删除 checkpoint_writes 表中的相关数据（如果存在）
        await cur.execute(
            "DELETE FROM checkpoint_writes WHERE thread_id = %s",
            (thread_id,)
        )
        
        # 3. 最后删除 checkpoints 表中的所有检查点
        await cur.execute(
            "DELETE FROM checkpoints WHERE thread_id = %s",
            (thread_id,)
        )
        
        # 获取被删除的行数（可选）
        deleted_count = cur.rowcount
        
    return f"已删除 thread_id={thread_id} 的所有数据，影响了 {deleted_count} 条检查点记录"
```


**2)-同步删除的套路**

```python
def delete_thread_data_sync(postgres_saver, thread_id):
    """
    同步版本：完全删除与特定 thread_id 相关的所有数据
    """
    # 对于 AsyncPostgresSaver，需要通过事件循环执行异步函数
    if hasattr(postgres_saver, 'loop'):
        return asyncio.run_coroutine_threadsafe(
            delete_thread_data(postgres_saver, thread_id),
            postgres_saver.loop
        ).result()
    
    # 对于同步的 PostgresSaver
    with postgres_saver._cursor() as cur:
        # 删除相关表中的数据
        cur.execute("DELETE FROM checkpoint_blobs WHERE thread_id = %s", (thread_id,))
        cur.execute("DELETE FROM checkpoint_writes WHERE thread_id = %s", (thread_id,))
        cur.execute("DELETE FROM checkpoints WHERE thread_id = %s", (thread_id,))
        deleted_count = cur.rowcount
        
    return f"已删除 thread_id={thread_id} 的所有数据，影响了 {deleted_count} 条检查点记录"
```


**3)-新添加一个 checkpoint**


```python
   # 添加一个带特殊标记的空检查点
   metadata = {"memory_cleared": True, "timestamp": time.time()}
   await checkpoint_saver.aput(config, empty_checkpoint, metadata, {})
```


```python
   # 查询时可以通过metadata过滤找到最近的memory_cleared检查点
   checkpoints = checkpoint_saver.alist(
       config, 
       filter={"memory_cleared": True},
       limit=1
   )
```


这个套路可以先用 MemorySaver 测试一下.