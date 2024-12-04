

## refer

- [How to remove Images, containers, and volumens](https://middleware.io/blog/docker-cleanup/)


## quick-start


**1) 资源积累**


在使用 `docker` 的时候会 积累大量的没有使用的镜像, 容器和数据集, 这些会导致输出杂乱并且乱占磁盘空间. 

**2) system prune**

```sh
docker system prune
```

这个命令非常简单，可以清理掉所有 没有被使用的资源. 包括: 没有标记的镜像，容器，数据卷和网络.


- `-a` : 显示所有的资源，包括没有使用的镜像
- `-q`: 仅仅显示资源的 `id`, 在需要处理大量镜像的时候比较快
- `-f` : 跳过确认对话框



**3) 首先，要自己去找到所有要清理的资源**


```bash
docker  container ls
docker  image ls
docker  volume ls
docker  network ls
docker  info
```

这些要肉眼识别 , `delete one by one`, 自己做决策

```sh
# 1. remote all images
docker rmi $(docker images -q) 

# 2. 找到悬空镜像
docker images -f dangling=true
# 3. 删除悬空镜像
docker image prune
```


一些工具例如 `Middleware` `Agent` 可以帮助我们监控定位问题.


**4) find and remove stopped dockers**


```sh
## 1. 列出 stopped containers
docker container ls -aq

## 2. 删除掉 stooped containers
docker rm $(docker container ls -aq)

## 3. remove all docker containers.
docker container stop $(docker container ls -aq) && docker system prune -af --volumes  
```


**5) remove docker volumes**


```sh
# 1. 列出可用的 卷
docker volume ls

# 2. 列出悬空的 volume
docker volume ls -f dangling=true

# 3. 清理悬空卷
docker volume prune
```


