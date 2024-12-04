


## refer

- [Druid-介绍](https://github.com/alibaba/druid/wiki/Druid%E8%BF%9E%E6%8E%A5%E6%B1%A0%E4%BB%8B%E7%BB%8D#1-%E4%BB%80%E4%B9%88%E6%98%AFdruid%E8%BF%9E%E6%8E%A5%E6%B1%A0)

## 1-Intro


目前一般都不用这个，但是在某些环境缺少专业监控的时候，打算临时用一下.

- 长期来看，建议别用. 居然每个页面都有广告



> 关于性能的理解

连接池本身的性能在整个调用链路中消耗通常不大. 关键点如下:

1. 是否真的让 连接重用的，缓存策略是什么, `lRU` ?
2. 是否支持 `PreparedStatementCache`?
	- 指的是在客户端（通常是在数据库连接池中）缓存 PreparedStatement 对象
	- 通过重用 PreparedStatement，减少了编译过程的开销，从而提升了数据库访问性能


```java
DruidDataSource dataSource = new DruidDataSource();
dataSource.setUrl("jdbc:mysql://localhost:3306/test");
dataSource.setUsername("root");
dataSource.setPassword("password");
dataSource.setMaxActive(100);
dataSource.setInitialSize(10);
dataSource.setMaxWait(60000);
dataSource.setMinIdle(10);
dataSource.setPoolPreparedStatements(true);
dataSource.setMaxPoolPreparedStatementPerConnectionSize(20);
```



> Exception Sorter

当网络断开或者数据库服务 `Crash` 的时候，连接池中会存在 "不可用连接",  要一些主动的机制去 踢出这些连接. 一般的策略是:
- 根据异常类型/Code/Reason/Message来识别“不可用连接”

源码在 `com.alibaba.druid.pool.vendor.MySqlExceptionSorter`


> 核心还是 监控: `StatFilter` 的实现 . 支持的场景:

- `Sql Merge` .
- 并发
- 慢查询
- 执行时间区间分布


个人理解是对 `testOnBrrow` 和 `testOnIdle` 这种机制的一种补充.


> 防止 `SQL` 注入.


`WallFilter` 功能实现: 

- `WallFilter` 配置: [参考](https://github.com/alibaba/druid/wiki/%E7%AE%80%E4%BB%8B_WallFilter)


## 2-Monitor

> 代码配置


- `StatFilter` 配置: [参考](https://github.com/alibaba/druid/wiki/%E9%85%8D%E7%BD%AE_StatFilter)
- `filter` 和 `proxyFilter` 是组合的关系.


> 页面说明

SQL监控项上，执行时间、读取行数、更新行数都有区间分布，将耗时分布成8个区间：

- 0 - 1 耗时0到1毫秒的次数
- 1 - 10 耗时1到10毫秒的次数
- 10 - 100 耗时10到100毫秒的次数
- 100 - 1,000 耗时100到1000毫秒的次数
- 1,000 - 10,000 耗时1到10秒的次数
- 10,000 - 100,000 耗时10到100秒的次数
- 100,000 - 1,000,000 耗时100到1000秒的次数
- 1,000,000 - 耗时1000秒以上的次数

记录耗时区间的发生次数，通过区分分布，可以很方便看出SQL运行的极好、普通和极差的分布。 耗时区分分布提供了“执行+RS时分布”，是将执行时间+ResultSet持有时间合并监控，这个能方便诊断返回行数过多的查询。



## 3-Practise



- 一个运行多年项目的 `demo`: [demo](https://github.com/alibaba/druid/wiki/DruidDataSource%E9%85%8D%E7%BD%AE%E5%B1%9E%E6%80%A7%E5%88%97%E8%A1%A8)
- [参考配置](https://github.com/alibaba/druid/wiki/DruidDataSource%E9%85%8D%E7%BD%AE)
- [配置列表](https://github.com/alibaba/druid/wiki/DruidDataSource%E9%85%8D%E7%BD%AE%E5%B1%9E%E6%80%A7%E5%88%97%E8%A1%A8)
 - [log4j2](https://github.com/alibaba/druid/wiki/Druid%E4%B8%AD%E4%BD%BF%E7%94%A8log4j2%E8%BF%9B%E8%A1%8C%E6%97%A5%E5%BF%97%E8%BE%93%E5%87%BA) 对应配置

- [keepAlive的效果](https://github.com/alibaba/druid/wiki/KeepAlive_cn)


```kotlin
    fun buildDruidDs(cfg: DatasourceConfig): DruidDataSource {  
        return DruidDataSource().apply {  
            /*基础配置*/  
            driverClassName = cfg.driverClass  
            isDefaultAutoCommit = cfg.defaultAutoCommit  
            url = cfg.jdbcUrl  
            username = cfg.username  
            password = cfg.password  
  
            /*池大小基本配置*/  
            initialSize = cfg.initialSize  
            minIdle = cfg.minIdle  
            maxActive = cfg.maxActive  
  
            /*连接的等待超时*/  
            maxWait = cfg.maxWait.toLong()  
            isAsyncInit = true  
//            createScheduler = ScheduledThreadPoolExecutor(3)  
//            destroyScheduler = ScheduledThreadPoolExecutor(3)  
  
            /*配置间隔多久才进行一次检测，检测需要关闭的空闲连接，单位是毫秒 */            timeBetweenEvictionRunsMillis = 60000  
  
            /*配置一个连接在池中最小生存的时间，单位是毫秒*/  
            minEvictableIdleTimeMillis = 300000  
  
            /**  
             * 空闲连接保活, 这个参数默认关闭, 打开这个参数后的效果如下:  
             * 初始化连接池时会填充到minIdle数量。  
             * 连接池中的minIdle数量以内的连接，空闲时间超过minEvictableIdleTimeMillis，则会执行keepAlive操作。  
             * 当网络断开等原因产生的由ExceptionSorter检测出来的死连接被清除后，自动补充连接到minIdle数量  
             */  
            isKeepAlive = true  
  
  
            /*检测语句强制用执行SQL（规避网关的假连接，参考启动属性：-Ddruid.mysql.usePingMethod=false）*/  
            isUsePingMethod = false  
            validationQuery = "SELECT 1"  
            isTestWhileIdle = true  
            isTestOnBorrow = false  
            isTestOnReturn = false  
  
            /*开启 PS-Cache*/            isPoolPreparedStatements = true  
            maxOpenPreparedStatements = 20  
  
            /*配置监控统计拦截的 filter*/  
  
            proxyFilters = listOf(  
                StatFilter().apply {  
//                    dbType = MYSQL  
                    slowSqlMillis = 200  
                    isLogSlowSql = true  
                    isMergeSql = true  
                }  
            )  
  
            setFilters("log4j2")  
  
        }  
  
    }
```


开启页面:

```kotlin
@Configuration  
open class DruidWebConfig {  
  
  
    @Bean  
    open fun statViewServlet(): ServletRegistrationBean<StatViewServlet> {  
        val servletRegistrationBean = ServletRegistrationBean(StatViewServlet(), "/druid/*")  
        // 添加初始化参数：initParams  
        // 登录查看信息的账号密码.  
        servletRegistrationBean.addInitParameter("loginUsername", "admin")  
        servletRegistrationBean.addInitParameter("loginPassword", "admin")  
        // 是否能够重置数据.  
        servletRegistrationBean.addInitParameter("resetEnable", "false")  
        return servletRegistrationBean  
    }  
  
    @Bean  
    open fun webStatFilter(): FilterRegistrationBean<WebStatFilter> {  
        val filterRegistrationBean = FilterRegistrationBean(WebStatFilter())  
        // 添加过滤规则.  
        filterRegistrationBean.addUrlPatterns("/*")  
        // 添加不需要忽略的格式信息.  
        filterRegistrationBean.addInitParameter("exclusions", "*.js,*.gif,*.jpg,*.bmp,*.png,*.css,*.ico,/druid/*")  
        return filterRegistrationBean  
    }  
  
}
```