


## Refer

- [homepage](https://github.com/kubeflow/kubeflow/blob/master/components/proposals/20220121-jupyter-notebook-idleness.md)


## 1-Intro



在 `Juypter-Notebook Server` 是指 `Notebook Server` 最后一次执行计算或者处理任务的时间.  具体来说, 这个是 `Notebook-kernel` 最后一次处理代码的时间. 


**1) 这个机制的核心是 根据 Notebook 的 api 会上报当前的状态和最后活跃时间**

这个的思路是基于 `Notebook` 本身提供的一个 `kernel` 状态机来做的.  `Notebook` 本身提供了一个 `api` 来报告当前的 `kernel` 状态.

```json
curl http://10.41.0.2:18888/api/kernels

[
    {
        "id": "b1c48325-4638-4b58-8ee9-135d3530b1dd",
        "name": "python3",
        "last_activity": "2024-08-14T03:25:26.278627Z",
        "execution_state": "idle",
        "connections": 1
    }
]
```


其中 `state` 代表状态

- `starting` : 正在启动
- `busy`: 正在执行计算任务
- `idle`: 没有任何操作

`last_activity` 代表最后的执行时间.



**2) Cull Controller 会根据这个 状态去更新当前 Pod 的元信息**

`CullController` 会定时检查 状态，根据这个状态去更新 `Pod` 的元信息, 有3个 `Annoation`.


```go
// When a Resource should be stopped/culled, then the controller should add this  
// annotation in the Resource's Metadata. Then, inside the reconcile loop,  
// the controller must check if this annotation is set and then apply the  
// respective culling logic for that Resource. The value of the annotation will  
// be a timestamp of when the Resource was stopped/culled.  
//  
// In case of Notebooks, the controller will reduce the replicas to 0 if  
// this annotation is set. If it's not set, then it will make the replicas 1.  
const STOP_ANNOTATION = "kubeflow-resource-stopped"  
const LAST_ACTIVITY_ANNOTATION = "notebooks.kubeflow.org/last-activity"  
const LAST_ACTIVITY_CHECK_TIMESTAMP_ANNOTATION = "notebooks.kubeflow.org/last_activity_check_timestamp"
```


注释表达的蛮清楚, 其他的控制器会去判断 `STOP_ANNOTATION` 是否有, 有的话，当前的 `pod` `replica` 会设置为 0 


**3) Notebook Controller 会根据这个 Stop Annotation 去回收资源** 


```go
func generateStatefulSet(instance *v1beta1.Notebook) *appsv1.StatefulSet {  
    replicas := int32(1)  
    if metav1.HasAnnotation(instance.ObjectMeta, "kubeflow-resource-stopped") {  
       replicas = 0  
    }
    // ...
    }
```

设置 `replica = 0` 回收 `Pod` 资源. 



## 2-Details


**1) 初始化的时候设置为 创建 Notebook 时间**

```go
func initializeAnnotations(meta *metav1.ObjectMeta) {
    if len(meta.GetAnnotations()) == 0 {
        meta.SetAnnotations(map[string]string{})
    }
    t := createTimestamp()
    meta.Annotations[LAST_ACTIVITY_ANNOTATION] = t
    meta.Annotations[LAST_ACTIVITY_CHECK_TIMESTAMP_ANNOTATION] = t
}
```


**2) 检查 Notebook 是否是活跃状态**


```go
kernels := getNotebookApiKernels(nm, ns, log)
if kernels == nil || len(kernels) == 0 {
    // 如果无法获取内核状态或内核不存在，则不更新活跃状态
    return
}

updateTimestampFromKernelsActivity(meta, kernels, log)
```



**3) 更新活跃的时间戳**

```go
func updateTimestampFromKernelsActivity(meta *metav1.ObjectMeta, kernels []KernelStatus, log logr.Logger) {
    if !allKernelsAreIdle(kernels, log) {
        t := createTimestamp()
        meta.Annotations[LAST_ACTIVITY_ANNOTATION] = t
    } else {
        recentTime, _ := findRecentKernelActivity(kernels)
        t := recentTime.Format(time.RFC3339)
        meta.Annotations[LAST_ACTIVITY_ANNOTATION] = t
    }
}

```

- 如果至少有一个内核处于忙碌状态，更新 `LAST_ACTIVITY_ANNOTATION` 为当前时间。
- 如果所有内核都处于空闲状态，更新 `LAST_ACTIVITY_ANNOTATION` 为最近一个内核活动的时间


**4) 设置 Stop Annotation**\

```go
func checkAndCullNotebook(nm *v1beta1.Notebook, log logr.Logger, m *metrics.Metrics) {
    meta := nm.ObjectMeta
    lastActivityStr, ok := meta.Annotations[LAST_ACTIVITY_ANNOTATION]
    if !ok {
        log.Info("No last activity annotation found. Cannot determine idle time.")
        return
    }

    lastActivity, err := time.Parse(time.RFC3339, lastActivityStr)
    if err != nil {
        log.Error(err, "Failed to parse last activity time.")
        return
    }

    idleDuration := time.Since(lastActivity)
    if idleDuration > time.Duration(CULL_IDLE_TIME)*time.Minute {
        setStopAnnotation(meta, m, log)
    }
}

func setStopAnnotation(meta *metav1.ObjectMeta, m *metrics.Metrics, log logr.Logger) {
    t := time.Now()
    meta.Annotations[STOP_ANNOTATION] = t.Format(time.RFC3339)
}

```


- 如果当前的空闲时间 > `CULL_IDLE_TIME` 的时候，设置 `STOP_ANNOTATION`


**5) IDLENESS_CHECK_PERIOD 如何生效**


```go
func (r *CullingReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // ...
	return ctrl.Result{RequeueAfter: getRequeueTime()}, nil
}


func getRequeueTime() time.Duration {  
    // The frequency in which we check if the Pod needs culling  
    // Uses ENV var: IDLENESS_CHECK_PERIOD    return time.Duration(IDLENESS_CHECK_PERIOD) * time.Minute  
}
```

- 这个 `Operator` 的逻辑, `Operator` 会根据 `Reconcile` 的返回值来决定下一次调度的时机. 
- 可以看出来是 `Minites` 



## 3-What's more


**目前的方案中存在很多问题**. 比如说 `Notebook-Style` 有很多, `Vscode`, `Rstudio`, `JupyterNotebook` 这个机制是通杀的，但是只有 `JuypyterNotebook` 的能有效上报.


- https://github.com/kubeflow/kubeflow/issues/6920
- [https://github.com/kubeflow/kubeflow/issues/7186](https://github.com/kubeflow/kubeflow/issues/7186)


所以上线需要改造. `cull_controller.go`. 

一个思路是基于 `istio-sidecar-proxy` 的方案去收集. `liveness-metric-api`. 然后 `cull-controller` 从 `juypternotebook-api` 改造为从这里获取信息去判断是否要回收，回收复用之前的逻辑，打一个 `tag` 说可以回收即可. 



