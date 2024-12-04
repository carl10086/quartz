

## Refer

- [AutoScaling](https://kserve.github.io/website/master/modelserving/autoscaling/autoscaling/)


## 1-Intro


```yaml
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "bert-t1"
  namespace: "example"
  annotations:
    "sidecar.istio.io/inject": "false"
spec:
  predictor:
    minReplicas: 0
    maxReplicas: 2
    scaleTarget: 1
    scaleMetric: concurrency
    model:
      modelFormat:
        name: huggingface
      args:
        - "--model_dir=/mnt/models/distilbert/distilbert-base-uncased-finetuned-sst-2-english"
        - "--model_name=bert"
      storageUri: "pvc://global-shared/models"
      resources:
        limits:
          cpu: "6"
          memory: 24Gi
        requests:
          cpu: "6"
          memory: 24Gi
```


```bash
(base) ➜  ~ curl -X POST "http://10.40.0.110:8081/v1/models/bert:predict" \
    -H "Content-Type: application/json" \
    -H "Host: bert-t1-predictor.yaww-ai-platform.svc.cluster.local" \
    -d '{"inputs": "I love using KServe!"}'

{"predictions":[1]}%
```


使用 `hey` 压测.

```sh
hey -z 30s -c 5 -m POST -H "Content-Type: application/json" -H "Host: bert-t1-predictor.yaww-ai-platform.svc.cluster.local" -d '{"inputs": "I love using KServe!"}' "http://10.40.0.110:8081/v1/models/bert:predict"
```


## 2-扩容指标

上面的扩容指标是比较推荐的, 同时还支持基于 [gpu-resource](https://kserve.github.io/website/master/modelserving/autoscaling/autoscaling/#create-the-inferenceservice-with-gpu-resource) 等等 . 默认就是 `concurrency`. 可选的值:

- `concurrency` : 并行度，按照并发
- `rps` : `request per second`, 如果你期待 50 的 rps ，0.5s 的 latency，直接拉100个, 当然可以设置上限
- `cpu`
- `memory`