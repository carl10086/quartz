
## 1-Quick Start


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240814202342.png)


## 2-Memcached-Operator

[refer](https://book.kubebuilder.io/getting-started)


```sh
kubebuilder init --domain my.domain --repo my.domain/memcached-operator
```

**Create a api**

```sh
kubebuilder create api --group cache --version v1alpha1 --kind Memcached --image=memcached:1.4.36-alpine --image-container-command="memcached,-m=64,-o,modern,-v" --image-container-port="11211" --run-as-user="1001" --plugins="deploy-image/v1-alpha" --make=false

```

命令有点长:


- `--group cache --version v1alpha1 --kind Memcached`:
	- 这个 `API` 的完全限定名称是: `cache.my.domain/v1alpha1` ?
- `--image=memcached:1.4.36-alpine`: 指定要限定的容器
- `--image-container-command="memcached,-m=64,-o,modern,-v"` : 容器的启动命令.
- `--image-container-port="11211"` : 端口
- `--run-as-user="1001"`
- `--make=false`: 禁止使用 `make` 命令，这样可以在生成代码之后手动检查和修改

这里用了 插件 `--plugins="deploy-image/v1-alpha"`, 会帮我们根据上面的配置自动生成:

- `controller` 代码
- `manage.yaml` 中还会包含对应的 `Deployment`


### 2-1 API Scehma


下面就是理解这些代码.

FROM: `api/v1alpha1/memcached_types.go`

```go
// MemcachedSpec defines the desired state of Memcached
type MemcachedSpec struct {
    // INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
    // Important: Run "make" to regenerate code after modifying this file

    // Size defines the number of Memcached instances
    // The following markers will use OpenAPI v3 schema to validate the value
    // More info: https://book.kubebuilder.io/reference/markers/crd-validation.html
    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=3
    // +kubebuilder:validation:ExclusiveMaximum=false
    Size int32 `json:"size,omitempty"`

    // Port defines the port that will be used to init the container with the image
    ContainerPort int32 `json:"containerPort,omitempty"`
}

// MemcachedStatus defines the observed state of Memcached
type MemcachedStatus struct {
    // Represents the observations of a Memcached's current state.
    // Memcached.status.conditions.type are: "Available", "Progressing", and "Degraded"
    // Memcached.status.conditions.status are one of True, False, Unknown.
    // Memcached.status.conditions.reason the value should be a CamelCase string and producers of specific
    // condition types may define expected values and meanings for this field, and whether the values
    // are considered a guaranteed API.
    // Memcached.status.conditions.Message is a human readable message indicating details about the transition.
    // For further information see: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties

    Conditions []metav1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type" protobuf:"bytes,1,rep,name=conditions"`
}

```

1. `MemacchedSpec`: **我们需要管的部分, 告诉 k8s我们期待的状态**
	- 自定义资源的 `CR` 部分, Custom Resource
	- 定义了用户所有可以设置的选项
	- 简单来说， 这里是我们告诉 `k8s`, 我们的 `memcached` 需要长成什么样子

2. `Status Condition` : 
	- 标准化的 `API`, 表达当前集群中的 状态
	- 每当资源的 状态发生变化的时候, (创建，更新，或者出错), `Controller` 就会更新这些条件

3. 而 `Memcached` 同时包含这2个 结构体，就是计算出 当前的状态和 期望状态的 `Delta`



有一些比较 `trick` 的东西, `markers`, 上面的注释:  `+kubebuilder:validation:Minimum=1`

- 一种 声明式的约束手段, 这个时候会在 `apply` 之前校验这个值必须 `>=1`
- 生成的修改会在中 `config/crd/bases` 中


每次修改 `Api-Spec` 后，需要 `make generate`: 来同步更新 `CRD` 中的内容.



**一般平时的demo会放在 `config/samples 下面, 例如**


```yaml
apiVersion: cache.example.com/v1alpha1
kind: Memcached
metadata:
  name: memcached-sample
spec:
  # TODO(user): edit the following value to ensure the number
  # of Pods/Instances your Operand must have on cluster
  size: 1

  # TODO(user): edit the following value to ensure the container has the right port to be initialized
  containerPort: 11211
```


### 2-2 Controller


`Reconciliation` : 是 `k8s` `controller-loop` 模式中的核心概念.

**目的:**
- 确保资源的实际状态与期望状态的同步
- 基于嵌入的业务逻辑处理资源状态

**循环特性:**
- `Reconciliation` 函数会不断执行，直到所有的条件都符合预期


下面看伪代码:

```go
reconcile App {

  // Check if a Deployment for the app exists, if not, create one
  // If there's an error, then restart from the beginning of the reconcile
  if err != nil {
    return reconcile.Result{}, err
  }

  // Check if a Service for the app exists, if not, create one
  // If there's an error, then restart from the beginning of the reconcile
  if err != nil {
    return reconcile.Result{}, err
  }

  // Look for Database CR/CRD
  // Check the Database Deployment's replicas size
  // If deployment.replicas size doesn't match cr.size, then update it
  // Then, restart from the beginning of the reconcile. For example, by returning `reconcile.Result{Requeue: true}, nil`.
  if err != nil {
    return reconcile.Result{Requeue: true}, nil
  }
  ...

  // If at the end of the loop:
  // Everything was executed successfully, and the reconcile can stop
  return reconcile.Result{}, nil

}

```


一个标准的流程:

1. 检查 `Development` 是否存在 ;
2. 检查 `Service` 是否存在 ;
3. `...` 直到所有的事情都检查完毕 ;

### 2-3 Return Options

```go
return ctrl.Result{}, err
```

- 用途: 当遇到错误的时候，需要立刻重试，返回这个 
- 行为: 控制器会记录当前的错误, 在短暂的延迟后，自动重新触发 `reconciliation`
- 场景: 临时性的错误, 网络问题或者资源暂时不可用

```go
return ctrl.Result{Requeue: true}, nil
```

- 用途: 当需要立即重新执行 `reconciliation`, 但是没有错误立即发生时候
- 场景: 适合连续多次调整或者检查，比如说我们要等待某个条件满足的时候使用

```go
return ctrl.Result{}, nil
```

- 用途: 当 `reconciliation` 成功完成, 而且暂时不需要 `further action` 的时候使用
- 场景: 资源达到期望状态，无需进一步操作

```go
return ctrl.Result{RequeueAfter: nextRun.Sub(r.Now())}, nil
```

- 用途: 延迟重新 `Reconcile` , 在指定的时候之后重新执行 `reconciliation`
- 场景: 需要定期的检查或者执行, 例如轮询外部的资源状态


