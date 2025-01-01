


## 1-介绍

记录一些常见的 `loki` 页面展示能力.



> [!NOTE] Tips
> 格式先做一搬的 `java` 应用， 一般都推荐使用 `json` 或者其他有 `schema` 的数据结构，能简化日志的解析.  sbt 3.3.4 之后有特别的优化

## 2-实现

**1)-时间窗口统计**

```
sum(count_over_time({filename="/opt/data/logs/athena-link-default/app.log"} |= "ERROR" [5m]))
```

解释为下面的结构.

```
sum(                                                           # 第1层：求和函数
    count_over_time(                                          # 第2层：在时间窗口内计数
        {filename="/opt/data/logs/athena-link-default/app.log"}  # 第3层：日志源选择
        |= "ERROR"                                            # 第4层：过滤条件
        [5m]                                                  # 第5层：时间窗口
    )
)
```


- `{filename="/opt/data/logs/athena-link-default/app.log"}` : 是最基础的标签选择器


**2)-速率统计**

```
rate({filename="/opt/data/logs/athena-link-default/app.log"}[5m])
```

1.	计算方式：
	- 统计 5 分钟内的日志总行数
	- 将总数除以时间窗口的总秒数 (5 * 60 = 300秒)
	- 得到每秒平均值
2.	举例说明：
	- 如果 5 分钟内有 3000 条日志
	- rate 计算：3000 / 300 = 10
	- 结果表示：平均每秒 10 条日志


下面再给一些例子.

```shell
# 分钟级统计,  估计值
60 * rate({filename="/opt/data/logs/athena-link-default/app.log"}[5m])

# 不同时间窗口对比
# 15分钟速率
rate({filename="/opt/data/logs/athena-link-default/app.log"}[15m])
```


**3)-内容过滤**

```shell
# 精确匹配
{filename="$filename", agent_hostname="$agent_hostname"} |= "$content"
# 不区分大小写
{filename="$filename", agent_hostname="$agent_hostname"} |~ "(?i)$content"
# 模糊匹配
{filename="$filename", agent_hostname="$agent_hostname"} |~ "$content"
# 多条件组合
{filename="$filename", agent_hostname="$agent_hostname"} |= "$content" |= "另一个关键词"
```
