


## refer

- [loki](https://github.com/grafana/loki)
- [Install Loki](https://grafana.com/docs/loki/latest/setup/install/)
- [使用 Promtail 收集 logback 日志](https://blog.frognew.com/2023/05/loki-06-promtail-java-logs.html)

## 1-Intro



`Loki` 是一个受到 `Prometheus` 启发的日志聚合系统 . 

1. 他天然支持分布式，水平扩展
2. `HA` 
3. 存储比较有特色
	1. 索引的内容高度压缩，不是 `Es`  那种全文索引
	2. 直接存储压缩的非结构化日志
	3. 仅仅索引 元数据 (`Label`)

## 2-Local Installation


- [helm-install-grafna](https://grafana.com/docs/grafana/latest/setup-grafana/installation/helm/#enable-persistent-storage-recommended)
- [helm-install-loki](https://grafana.com/docs/loki/latest/setup/install/helm/install-monolithic/)
- [explore-loki-logs](https://grafana.com/docs/loki/latest/visualize/grafana/)


**tips:**

- 本地测试的时候，可以降低 `memcached-pod` 的内存大小.
- 默认的 `loki` 安装是多租户, 需要携带一个自定义的 http 头, `X-Scope-OrgID` 


我们使用 `monitoring` `namespace` 安装这里所有东西.


**有多种的可视化方法:**

1.	Explore Logs（探索日志）:
     -	这是一个新功能，目前处于公开预览阶段。
     -	允许用户在不编写 LogQL 查询的情况下探索 Loki 数据源中的日志。
     -	特点：用户友好，适合快速浏览和初步分析日志。
     -	适用场景：快速故障排查，初步日志分析。
2.	Grafana Explore（Grafana 探索）:
     -	这是 Grafana 的一个内置功能。
     -	允许用户构建和迭代 LogQL 查询。
     -	特点：交互式查询构建，实时结果预览。
     -	适用场景：深入分析，复杂查询构建，查询调试。
     -	用途：一旦你找到了有用的查询，可以将其用于创建仪表板。
3.	Loki Mixins（Loki 混合）:
     -	这是一套预构建的仪表板、记录规则和警报。
     -	专门用于监控 Loki 本身的性能和健康状况。
     -	特点：开箱即用，专注于 Loki 系统监控。
     -	适用场景：Loki 管理员和运维人员使用，用于监控 Loki 的运行状况。
4.	Grafana Dashboards（Grafana 仪表板）:
     -	这是 Grafana 的核心功能之一。
     -	允许用户创建自定义仪表板，展示多种可视化效果。
     -	特点：高度可定制，可以组合多种数据源和查询。
     -	适用场景：长期监控，团队共享，复杂数据展示。
     -	优势：可以导入和修改社区共享的公共仪表板


## 3-Log collection


- [Send-data](https://grafana.com/docs/loki/latest/send-data/)

第一步肯定是日志的收集.. 目前的方法有如下几种:

- `Promtail`
- `Granfna Alloy`
- `OTel Collector`
- ...

### 3-1 Promtail

`Promtail` 是一个代理，用来把本地的日志内容发送到私有的 `Granfa` `Loki` , 他可以:

1. 发现目标 (日志源)
2.  为日志流附加标签
3. 将日志推送到 loki 实例.


这是一个基于 `damonset` 方式安装 `promtail` .

```yaml
--- # Daemonset.yaml  
apiVersion: apps/v1  
kind: DaemonSet  
metadata:  
  name: promtail-daemonset  
  namespace: monitoring  
spec:  
  selector:  
    matchLabels:  
      name: promtail  
  template:  
    metadata:  
      labels:  
        name: promtail  
    spec:  
      serviceAccount: promtail-serviceaccount  
      containers:  
        - name: promtail-container  
          image: grafana/promtail  
          args:  
            - -config.file=/etc/promtail/promtail.yaml  
          env:  
            - name: 'HOSTNAME' # needed when using kubernetes_sd_configs  
              valueFrom:  
                fieldRef:  
                  fieldPath: 'spec.nodeName'  
          volumeMounts:  
            - name: logs  
              mountPath: /var/log  
            - name: promtail-config  
              mountPath: /etc/promtail  
            - mountPath: /var/lib/docker/containers  
              name: varlibdockercontainers  
              readOnly: true  
      volumes:  
        - name: logs  
          hostPath:  
            path: /var/log  
        - name: varlibdockercontainers  
          hostPath:  
            path: /var/lib/docker/containers  
        - name: promtail-config  
          configMap:  
            name: promtail-config  
--- # configmap.yaml  
apiVersion: v1  
kind: ConfigMap  
metadata:  
  name: promtail-config  
  namespace: monitoring  
data:  
  promtail.yaml: |  
    server:  
      http_listen_port: 9080  
      grpc_listen_port: 0  
  
    clients:  
    #  - url: https://{YOUR_LOKI_ENDPOINT}/loki/api/v1/push  
      - url: http://loki.monitoring:3100/loki/api/v1/push  
        tenant_id: cb  
  
    positions:  
      filename: /tmp/positions.yaml  
    target_config:  
      sync_period: 10s  
    scrape_configs:  
      - job_name: pod-logs  
        kubernetes_sd_configs:  
          - role: pod  
        pipeline_stages:  
          - docker: { }  
        relabel_configs:  
          - source_labels:  
              - __meta_kubernetes_pod_node_name  
            target_label: __host__  
          - action: labelmap  
            regex: __meta_kubernetes_pod_label_(.+)  
          - action: replace  
            replacement: $1  
            separator: /  
            source_labels:  
              - __meta_kubernetes_namespace  
              - __meta_kubernetes_pod_name  
            target_label: job  
          - action: replace  
            source_labels:  
              - __meta_kubernetes_namespace  
            target_label: namespace  
          - action: replace  
            source_labels:  
              - __meta_kubernetes_pod_name  
            target_label: pod  
          - action: replace  
            source_labels:  
              - __meta_kubernetes_pod_container_name  
            target_label: container  
          - replacement: /var/log/pods/*$1/*.log  
            separator: /  
            source_labels:  
              - __meta_kubernetes_pod_uid  
              - __meta_kubernetes_pod_container_name  
            target_label: __path__  
  
--- # Clusterrole.yaml  
apiVersion: rbac.authorization.k8s.io/v1  
kind: ClusterRole  
metadata:  
  name: promtail-clusterrole  
  
rules:  
  - apiGroups: [ "" ]  
    resources:  
      - nodes  
      - services  
      - pods  
    verbs:  
      - get  
      - watch  
      - list  
  
--- # ServiceAccount.yaml  
apiVersion: v1  
kind: ServiceAccount  
metadata:  
  name: promtail-serviceaccount  
  namespace: monitoring  
  
--- # Rolebinding.yaml  
apiVersion: rbac.authorization.k8s.io/v1  
kind: ClusterRoleBinding  
metadata:  
  name: promtail-clusterrolebinding  
subjects:  
  - kind: ServiceAccount  
    name: promtail-serviceaccount  
    namespace: monitoring  
roleRef:  
  kind: ClusterRole  
  name: promtail-clusterrole  
  apiGroup: rbac.authorization.k8s.io
```


### 3-2 logback 

现在只要是 `json` 格式的日志会被 `promtail` 自动解析不用太复杂的操作，就能识别出 其中的字段. 

可以使用 [logstash-logback](https://github.com/logfellow/logstash-logback-encoder) 或者 `log4j2` 内置的 `json` 格式进行收集.

```kotlin
implementation("net.logstash.logback:logstash-logback-encoder:8.0")
```


```xml
    <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <providers>
                <timestamp>
                    <timeZone>UTC</timeZone>
                </timestamp>
                <logLevel/>
                <threadName/>
                <loggerName/>
                <message/>
                <mdc/>
                <stackTrace/>
                <arguments/>
                <pattern>
                    <pattern>
                        {
                        "custom_field": "custom_value"
                        }
                    </pattern>
                </pattern>
            </providers>
        </encoder>
    </appender>

```

## 4-Logs virtualize

### 4-1 explore logs

使用 `Plugin` 的方式安装即可. 


上面的配置会自动收集 所有的 `pod` 本地的日志，也就是说应用只要写到 `console` 就自动会被 `promTail` 收集，也算是不错的.



## 4-2 grafana explore


能整合多种数据源.  一个页面查看.

- `loki`
- `es`
- `cloudwatch`
- `influxDb`
- `clickhouse`



类似 `Promethus` 有自己的 `PQL`,  `LOKI` 也有自己的 `LQL` .  基于这个语法可以用来绘制报表. 

一个 `granfana` 上的 `dashboard`  , [logs-app](https://grafana.com/grafana/dashboards/13639-logs-app/)



