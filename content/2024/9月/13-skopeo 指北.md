

## Refer

- [skopeo](https://github.com/containers/skopeo)


## 1-QuickStart

`skopeo` 是一个非常好用的 直接基于 `Layer` 做 `image` 和 `imageRegistry` 迁移的工具.


## 2-copy 工具

```sh
## 典型用法: copy 单个 image
skopeo copy  --override-os linux --override-arch amd64 \
    docker://nvcr.io/nvidia/cuda:10.0-devel-ubuntu18.04 \
    docker://YOUR-REGISTRY.baidubce.com/nvidia/cuda:10.0-devel-ubuntu18.04
```


```sh
## 典型用法: copy 文件
skopeo copy dir:./python3.9 docker-daemon:python:3.9-slim-bullseye
```

