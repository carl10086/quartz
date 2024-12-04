
## Refer

- [start](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Farm64%2Fstable%2Fbinary+download)


## 1-QuickStart


- `pods`: 核心是提供了一组用来给 容器共享的 基础环境
- `service`: 给一组 `pods` 一个稳定的内部 `ip` 
- `ingress`: 打通 `k8s` 内外部，作为 `http` 网关

### 1-1 docker image

基本思路:

1. 一个 `kotlin` 的 `web`  应用 ;
2. 日志写到 `stdout.log` , 也就是 `stdout` , 这是 `k8s` 推荐的姿势，`k8s` 本身会优雅的处理 `stdout` ;
3. 然后使用 `vector` 作为 `daeomonSet` 在 `node` 级别上收集日志 收集到 `graylog` 或者就收集到 `es` 吧 ;


> 关于镜像是否应该 打包代码进去.

可能有一些最佳实践.

1. 生产环境中，要把 代码打包进入镜像.
2. 使用 `multiple-stage builds` 来优化镜像最后的大小
3. 对于配置文件, 使用 `k8s` 的 `ConfigMaps` 和 `Secrets`
4. 开发环境中，可以考虑  仅仅使用 `Volume` 挂载的方式来加快开发周期
5. 无法使用哪种方法，都要有 良好的版本控制和回滚机制


> 使用 spring boot gradle 插件: 同时 build 和 deploy


```kotlin
import org.springframework.boot.gradle.tasks.bundling.BootBuildImage  
  
plugins {  
    id("cb-kotlin-app")  
}  
  
tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {  
    mainClass.set("com.cb.example.web.ExampleAppKt")  
//    archiveFileName.set("")  
}  
  
tasks.named<BootBuildImage>("bootBuildImage") {  
    builder.set("paketobuildpacks/builder-jammy-tiny:latest")  
    imageName.set("cb/examples-web:${project.version}")  
  
    environment.set(  
        mapOf(  
            "BP_JVM_VERSION" to "21.*",  
            "BP_JAVA_RUNTIME" to "bellsoft-liberica"  
        )  
    )  
  
    // 使用 liberica-openjdk-alpine:21 作为基础镜像  
    runImage.set("bellsoft/liberica-openjdk-alpine:21")  
  
}  
  
dependencies {  
    implementation("org.springframework.boot:spring-boot-starter-web:")  
    implementation("org.springframework.boot:spring-boot-starter-aop:")  
}
```



1. 上面的 插件同时负责了 `build` 和 `buildDockerImage` ;
2. 其中 build 使用的基础镜像是 `paketobuildpacks/builder-jammy-tiny` 项目, 最小化分层构建器 ;
3. runtime 的基础镜像使用的是 `bellsoft/liberica-openjdk-alpine:21` , 非常适合运行时 ;


> 使用 jib 去构建 image


```kotlin
jib {  
    from {  
        image = "bellsoft/liberica-openjdk-alpine:21"  
    }  
    to {  
        image = "cb/examples-web"  
        tags = setOf("latest", project.version.toString())  
    }  
    container {  
        mainClass = "com.cb.example.web.ExampleAppKt"  
        jvmFlags = listOf("-Xms512m", "-Xmx512m")  
        ports = listOf("8080")  
        environment = mapOf("BP_JVM_VERSION" to "21")  
    }  
}
```



### 1-2 vector log collector


```yaml
apiVersion: v1  
kind: ConfigMap  
metadata:  
  name: vector-config  
  namespace: kube-system  
data:  
  vector.toml: |  
    [sources.kubernetes_logs]  
    type = "kubernetes_logs"  
    self_node_name = "${VECTOR_SELF_NODE_NAME}"  
  
    [transforms.log_transform]  
    type = "remap"  
    inputs = ["kubernetes_logs"]  
    source = '''  
    .log = .message  
    '''  
  
    [sinks.file]  
    type = "file"  
    inputs = ["log_transform"]  
    path = "/var/log/vector/output.log"  
    encoding.codec = "ndjson"  
  
---  
apiVersion: apps/v1  
kind: DaemonSet  
metadata:  
  name: vector  # DaemonSet 的名称  
  namespace: kube-system  # DaemonSet 所在的命名空间  
  labels:  
    app: vector  # 标签，用于标识这个 DaemonSetspec:  
  selector:  
    matchLabels:  
      app: vector  # 选择器，用于匹配 Pod 的标签  
  template:  
    metadata:  
      labels:  
        app: vector  # Pod 的标签，必须与选择器匹配  
    spec:  
      containers:  
        - name: vector  # 容器名称  
          image: timberio/vector:0.20.0-debian  # 使用的容器镜像  
          env:  
            - name: VECTOR_SELF_NODE_NAME  # 环境变量，用于设置节点名称  
              valueFrom:  
                fieldRef:  
                  fieldPath: spec.nodeName  # 从节点规范中获取节点名称  
          volumeMounts:  # 挂载卷配置  
            - name: varlog  
              mountPath: /var/log  # 将主机的 /var/log 目录挂载到容器的 /var/log 目录  
            - name: varlibdockercontainers  
              mountPath: /var/lib/docker/containers  # 将主机的 /var/lib/docker/containers 目录挂载到容器的 /var/lib/docker/containers 目录  
              readOnly: true  # 只读挂载  
            - name: vector-config  
              mountPath: /etc/vector  # 将 ConfigMap 挂载到容器的 /etc/vector 目录  
              readOnly: true  # 只读挂载  
      volumes:  # 定义挂载卷  
        - name: varlog  
          hostPath:  
            path: /var/log  # 主机上的 /var/log 目录  
        - name: varlibdockercontainers  
          hostPath:  
            path: /var/lib/docker/containers  # 主机上的 /var/lib/docker/containers 目录  
        - name: vector-config  
          configMap:  
            name: vector-config  # 使用名为 vector-config 的 ConfigMap
```


上面有详细的注释，使用了 `vector` 去收集宿主机上的日志.


### 1-3 deployment


```yaml
apiVersion: apps/v1  
kind: Deployment  
metadata:  
  name: examples-web  # Deployment 的名称  
  namespace: default  # Deployment 所在的命名空间  
spec:  
  replicas: 5  # 副本数量，表示运行的容器实例数量  
  selector:  
    matchLabels:  
      app: examples-web  # 选择器，用于匹配 Pod 的标签  
  strategy:  
    type: RollingUpdate  
    rollingUpdate:  
      maxUnavailable: 2 # 更新过程中最多有1个Pod不可用  
      maxSurge: 2 # 更新过程中最多创建1个额外的Pod  
  template:  
    metadata:  
      labels:  
        app: examples-web  # Pod 的标签，必须与选择器匹配  
    spec:  
      containers:  
        - name: examples-web  # 容器名称  
          image: cb/examples-web:1.0.1  # 使用的容器镜像  
          ports:  
            - containerPort: 8080  # 容器暴露的端口  
  
---  
apiVersion: v1  
kind: Service  
metadata:  
  name: examples-web  # Service 的名称  
  namespace: default  # Service 所在的命名空间  
spec:  
  selector:  
    app: examples-web  # 选择器，用于匹配 Pod 的标签  
  ports:  
    - protocol: TCP  
      port: 80  # Service 暴露的端口  
      targetPort: 8080  # Pod 中容器的端口  
  type: NodePort  # Service 类型，可以是 ClusterIP, NodePort, LoadBalancer 等
```

我们创建了一个 `Service` 和一个 `Deployment`. 

策略上使用的是:

- **滚动更新策略**
- 还可以使用 `ReCreate` 策略, 瞬间全部重新创建



### 1-4 Ingress


下面就是开始管理外部的访问了. 我们使用 `Ingress`.

`minikube` 自带的 `Ingress` 是 `nginx` . 


```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: examples-web-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: examples-web.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: examples-web
            port:
              number: 80
```


我们直接本地验证把 `/etc/hosts` 上面的域名路由到 `minikube ip` 即可.



### 1-5 Rollout 


测试了一下回滚

```sh
(base) ➜  ~ kubectl rollout history deployment/examples-web

deployment.apps/examples-web
REVISION  CHANGE-CAUSE
4         <none>
5         就想发布 一下 1.0.0 版本

(base) ➜  ~ kubectl rollout history deployment/examples-web

deployment.apps/examples-web
REVISION  CHANGE-CAUSE
5         就想发布 一下 1.0.0 版本
6         就想发布 一下 1.0.1 版本

(base) ➜  ~ kubectl rollout undo deployment/examples-web
deployment.apps/examples-web rolled back
(base) ➜  ~ kubectl rollout history deployment/examples-web

deployment.apps/examples-web
REVISION  CHANGE-CAUSE
6         就想发布 一下 1.0.1 版本
7         就想发布 一下 1.0.0 版本

(base) ➜  ~ kubectl rollout undo deployment/examples-web --to-revision=6
deployment.apps/examples-web rolled back
```