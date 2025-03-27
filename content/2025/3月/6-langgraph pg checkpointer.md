
## 1-介绍

```bash
docker run --name postgres-db --rm -p 5432:5432 -e POSTGRES_USER=ysz -e POSTGRES_PASSWORD=123456 -e POSTGRES_DB=testdb postgres:15-alpine
```


## 2-实现
生产环境我们肯定仅仅关注 `async`, `sync` 在 现代化 `FastApi` 这种范式下肯定不行的.

```python
import asyncio
from typing import Optional
import logging

from psycopg_pool import AsyncConnectionPool
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
from app.core.config import settings

# 设置日志
logger = logging.getLogger(__name__)

# 全局变量 - 保存连接池和checkpointer
_pool: Optional[AsyncConnectionPool] = None
async_postgres_saver: Optional[AsyncPostgresSaver] = None


async def get_postgres_pool() -> AsyncConnectionPool:
    """获取PostgreSQL连接池，如果不存在则创建"""
    global _pool

    if _pool is None:
        # 构建PostgreSQL连接URI
        pg_config = settings.postgres
        connection_uri = pg_config.get_connection_uri()

        logger.info("创建PostgreSQL连接池")
        # 创建连接池，设置 autocommit=True 解决 CREATE INDEX CONCURRENTLY 问题
        # 注意：不在构造函数中打开连接池，而是使用 await pool.open()
        _pool = AsyncConnectionPool(
            conninfo=connection_uri,
            max_size=pg_config.max_size,
            kwargs={
                "application_name": "ai_english_phonics",
                "autocommit": True,  # 关键参数：设置自动提交模式
                # search_path 已经在连接字符串中设置
            },
        )
        # 连接池已经在构造函数中打开，不需要再次调用 open()
        await _pool.open()
        logger.info(f"PostgreSQL连接池创建成功，使用 schema: {pg_config.pg_schema}")

    return _pool


async def get_postgres_checkpointer() -> Optional[AsyncPostgresSaver]:
    """获取PostgreSQL检查点保存器"""
    global async_postgres_saver

    if async_postgres_saver is None:
        try:
            # 获取连接池
            pool = await get_postgres_pool()

            # 创建检查点保存器
            async_postgres_saver = AsyncPostgresSaver(pool)

            # 初始化表结构 - 使用 autocommit=True 解决 CREATE INDEX CONCURRENTLY 问题
            await async_postgres_saver.setup()
            logger.info("PostgreSQL检查点保存器初始化完成")

        except Exception as e:
            logger.error(f"初始化PostgreSQL检查点保存器时出错: {e}")
            return None

    return async_postgres_saver


async def close_postgres_pool():
    """关闭PostgreSQL连接池"""
    global _pool

    if _pool is not None:
        logger.info("关闭PostgreSQL连接池")
        await _pool.close()
        _pool = None
        logger.info("PostgreSQL连接池已关闭")


async def main():
    """测试 checkpointer 功能的主函数"""
    # 配置日志
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    try:
        # 获取 checkpointer
        logger.info("开始测试 checkpointer 功能")
        checkpointer = await get_postgres_checkpointer()

        if checkpointer is None:
            logger.error("获取 checkpointer 失败")
            return

        logger.info("PostgreSQL检查点保存器初始化成功")

    except Exception as e:
        logger.error(f"测试过程中发生错误: {e}")
        import traceback

        logger.error(traceback.format_exc())

    finally:
        # 关闭连接池
        await close_postgres_pool()
        logger.info("测试完成")


# 如果直接运行此文件，则执行 main 函数
if __name__ == "__main__":
    asyncio.run(main())

```


**问题1: Pg Schema 权限问题**

`PgCheckPointer` 需要使用自动化的去创建 `Table`, 因此最好在单独的 `Schema` 下, `public` 下默认不会给这权限

```python
    def get_connection_uri(self) -> str:
        """构建PostgreSQL连接URI"""
        password_part = f":{self.password}" if self.password else ""
        auth_part = f"{self.username}{password_part}@" if self.username else ""

        # 使用 libpq 连接参数格式设置 search_path
        # 参考: https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
        return (
            f"postgresql://{auth_part}{self.host}:{self.port}/{self.database}"
            f"?application_name=ai_english_phonics"
            f"&options=-c%20search_path%3D{self.pg_schema}"
        )
```

## refer

- [原始文章](https://langchain-ai.github.io/langgraph/how-tos/persistence_postgres/#with-a-connection-pool_1)