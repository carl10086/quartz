


## refer

- [原文](https://mp.weixin.qq.com/s/DsyYaCxEpLpdJkitBqWDLQ)


## 1-总结

### 1-1 实验

- `xxl-job` : 版本 `2.4.1`
- `quartz`:  版本 `v2.3.2`
- [devops-scheduler](https://github.com/bkdevops-projects/devops-framework)

![](https://mmbiz.qpic.cn/mmbiz_png/jCyzkfYibsibuqRr429717PG81PDa6oCMLib42t74d3borzUfPPDiaPuvJPWVKoPxJiaa4q6vV977m9YfVwz15iaRTQg/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)


**测试方法:** 通过创建 `5000` 个相同的 `cron` 表达式任务, 在框架下执行.

- **任务:** `(*/30 * * * * ?)`  任务会在 0s 和 30s 的同时运行.
- **延迟计算方法:** 如果在第 16s 执行，延迟 = `16-0=16s` , 如果在第 `31s` 的时候执行，则认为 延迟 = `31-30=1s` .
- **任务书计算方法:** 仅仅统计延迟在 `5s` 内的任务

**图标说明:**

- **蓝色：** 任务数
- **灰色**: 延迟


### 1-2 实验分析


**1)-xxlJob 源码 `msifire` 分析**

```java
if (nowTime > jobInfo.getTriggerNextTime() + PRE_READ_MS /*5000毫秒*/) {
	// 2.1 trigger -> expire -> 5s: pass & make next-trigger-time
	logger.warn(">>>>>>>>>>> xxl-job, schedule misfire, jobId = " + jobInfo.getId());
}
```


- **结论:** 一轮调度的任务重耗时超过 `5s` .

**2)-xxlJob 原文作者进行了埋点, 发现如下的方法，耗时多达 40多秒**

```java
for (XxlJobInfo jobInfo: scheduleeList) {
	XxlJobAdminConfig.getAdminConfig().getXxlJobInfoDao().scheduleUpdate(jobInfo);
}
```

- 这个 `for 循环` 没有批处理, 直接 `for` 循环内内部调用 `Dao` , 任务越多，更新就越慢, 自然就会发生错过任务的情况. 属于 **设计不合理**

**3)-Quartz 在查询等待触发任务的时候，加了限制**


```java
clearSignalSchedulingChange();

try {
	triggers = qsRsrcs.getJobStore().accquireNextTrigger(
		now + idleWaitTime, 
		Math.min(availThreadCount, qsRsrcs.getMaxBatchSize()), 
		qsRsrcs.getBatchTimeWindow()
	);

	acquiresFailed = 0;
	if (log.isDebugEnabled()) ...
}
```

- 同时使用了 时间窗口和 数量限制

**4)-XxlJob 也有限制，但是一个预估的固定值，在调度任务多的时候非常不合理**

```java
// tx start

// 1. pre read
long nowTime = System.currentTimeMillis();

List<XxlJobInfo> scheduleList = XxlJobAdminConfig.getAdminConfig().getXxlJobInfoDao().scheduleJobuery(preReadCount...);

if (scheduleList != null && scheduleList.size() > 0) {
 // 2. push time-ring
}
```


其中的任务数量 .

```java
// pre-read count: threadpool-size + trigger-qps (each trigger cost 50ms, qps = 1000/ 50 = 20)
int preReadCount = (XxlJobAdminConfig.getAdminConfig().getTriggerPoolFastMax() + XxlJobAdminConfig().getTriggerPoolSlowMax()) * 20;
```

**5)-devops scheduler 性能高?**


上面的核心问题是, 如何保证 调度任务数量的 可控, 来保证避免 系统的负载过高.  三者都有时间窗口的限制.

- `xxl-job`: 预估一个数量，和 实际中的能力等等 有很大的差异，随机性太大
- `quartz`: 根据 **活跃线程数** 和 **人工设置批处理数量** 中二者的最小值, 这里有当前活跃的线程数作为参数，所以能 更好的反应当前系统的压力
- `devops-schedule`: `tcp` 拥塞控制 **yyds** , 根据任务延迟大小的，动态的去调整任务的数量, 当任务的延迟高于 阈值的时候，降低任务数量，反之则加大任务的数量，算法是 `tcp reno` , 以快速让系统达到预期的稳定值. 

**技术选型:** `devops-schedule` 采用 `mongodb` 而不是 `mysql` , 在更新 5000条任务记录的情况下 , `mongodb` 要 10s， 而 `mysql` 要 `40` 多s , 这个 **个人保留意见，这个跟硬件， 版本关系都很大，新版本的 mysql 修改也很快，虽然 个人更喜欢 mongodb**



## 2-实测

// TODO