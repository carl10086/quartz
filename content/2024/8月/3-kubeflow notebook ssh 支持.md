

## 1-概述


经常会有 直接通过 `vscode` `ssh` 插件远程连接服务端的需求.



> **背景:**


这个 feature 从 19提到24年，官方3周前，大约是 2024年7月中旬的时候纳入了 discussion.

历史 issue:

- [https://github.com/kubeflow/kubeflow/issues/7614](https://github.com/kubeflow/kubeflow/issues/7614)
- [https://github.com/kubeflow/kubeflow/issues/6828](https://github.com/kubeflow/kubeflow/issues/6828)
- [https://github.com/kubeflow/kubeflow/issues/5604](https://github.com/kubeflow/kubeflow/issues/5604)
- [https://github.com/kubeflow/kubeflow/issues/6791](https://github.com/kubeflow/kubeflow/issues/6791)
- [https://github.com/kubeflow/kubeflow/issues/4080](https://github.com/kubeflow/kubeflow/issues/4080)


当前的 discussion : [https://github.com/kubeflow/notebooks/issues/23](https://github.com/kubeflow/notebooks/issues/23)



> **思路:**


1. 首先镜像里 要把 `sshd-server` 打进去.
2. 然后网络要能通过去， 官方有2种思路:
	1. 基于 `ssh` 的路由网关, `ssh` 协议非常的简陋，要通过一些 [tricks](http://quark.humbug.org.au/publications/ssh/ssh-tricks.html) 实现
	2. 基于 `vpn` 的思路, 例如 `SD-WAN`, `tailscale` ... , **是推荐的办法，这种相当于直连 pod, 没有中间商，稳定性能好**

3. 最后，一些自动化的工作，考虑用 `k8s-operator` 来做，监听 `Notebook` 类型的 `Pod`, 然后做出自动化的反应，比如说
	1. 获取到 动态的 `PodIp`
	2. 自动把当前 `Notebook` `Owner` 的公钥打进去
	3. 数据存储到数据库，再基于这个数据库来一个 交互友好的页面等等


> **约束**

参考官方文档，有如下的约束.

https://www.kubeflow.org/docs/components/notebooks/container-images/


For a container image to work with Kubeflow Notebooks, it must:

- expose an HTTP interface on port `8888`:
    - kubeflow sets an environment variable `NB_PREFIX` at runtime with the URL path we expect the container be listening under
    - kubeflow uses IFrames, so ensure your application sets `Access-Control-Allow-Origin: *` in HTTP response headers
- run as a user called `jovyan`:
    - the home directory of `jovyan` should be `/home/jovyan`
    - the UID of `jovyan` should be `1000`
- start successfully with an empty PVC mounted at `/home/jovyan`:
    - kubeflow mounts a PVC at `/home/jovyan` to keep state across Pod restarts





## 2-实现


### 2-1 科学上网


1) curl 有一些硬编码 `curl` 的提前下载下来，使用 `COPY` 指令就行.

2) `pip` 改为源.来个 `pip.conf`

```toml
[global]
index-url=http://mirrors.baidubce.com/pypi/simple/
extra-index-url =
  http://mirrors.aliyun.com/pypi/simple/
  https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host =
  mirrors.baidubce.com
  pypi.tuna.tsinghua.edu.cn
  mirrors.aliyun.com
```


3) conda 配置 `condarc`

```yaml
channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/msys2
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/menpo
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch
show_channel_urls: true
```

4) ubuntu 22 的修改 `apt` . 例如

```dockerfile
RUN mkdir -p /etc/apt/ \
 && sed -e "s/security.ubuntu.com/mirrors.xxx.com/g" -i /etc/apt/sources.list \
 && sed -e "s/archive.ubuntu.com/mirrors.xxx.com/g" -i /etc/apt/sources.list \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get -yq update \
 && apt-get -yq install --no-install-recommends \
```


### 2-2 sshd docker image


`Kubeflow-Notebook` 写死了 `jovyan` 用户，而且仅仅只开放 `8888` 端口，写死在源码中. 


```go

func generateStatefulSet(instance *v1beta1.Notebook) *appsv1.StatefulSet {
	replicas := int32(1)
	// ...
	podSpec := &ss.Spec.Template.Spec
	container := &podSpec.Containers[0]
	if container.WorkingDir == "" {
		container.WorkingDir = "/home/jovyan"
	}
	if container.Ports == nil {
		container.Ports = []corev1.ContainerPort{
			{
				ContainerPort: DefaultContainerPort,
				Name:          "notebook-port",
				Protocol:      "TCP",
			},
		}
	}

```


**所以我们要使用 非 root 用户-jovyan 启动 sshd**

```conf
# 使用非特权端口
Port 2209

# 指定 Pid 文件路径
PidFile /ssh_conf/sshd.pid

# 指定主机密钥文件路径
HostKey /ssh_conf/ssh_host_rsa_key
HostKey /ssh_conf/ssh_host_ecdsa_key
HostKey /ssh_conf/ssh_host_ed25519_key
# 指定 authorized_keys 文件
AuthorizedKeysFile /ssh_conf/authorized_keys

# 其他必要的配置
PermitRootLogin no
PasswordAuthentication yes

# 日志级别
LogLevel INFO

# 允许的认证方式
AuthenticationMethods publickey

# 允许 TCP 转发
AllowTcpForwarding yes

# 允许代理转发
AllowAgentForwarding yes

# 允许 X11 转发
X11Forwarding yes

# 保持连接
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3

# 最大认证尝试次数
MaxAuthTries 3

# 最大会话数
MaxSessions 10

# 最大启动连接数
MaxStartups 10:30:60

# 禁用 GSSAPI 认证（如果不需要）
GSSAPIAuthentication no

# 使用 PAM
UsePAM yes
PrintMotd no
PrintLastLog no

# 允许用户
AllowUsers jovyan

UseDNS no

```


制作为 `s6-overlay` 的 `service` 文件.


```bash
#!/command/with-contenv bash

# Set home directory
cd "${HOME}"

# Set SSH config directory
# SSH_CONFIG_DIR=${HOME}/.ssh
SSH_CONFIG_DIR=/ssh_conf
if [ ! -f "${SSH_CONFIG_DIR}/ssh_host_rsa_key" ]; then
  ssh-keygen -t rsa -f ${SSH_CONFIG_DIR}/ssh_host_rsa_key -N ""
fi
if [ ! -f "${SSH_CONFIG_DIR}/ssh_host_ecdsa_key" ]; then
  ssh-keygen -t ecdsa -f ${SSH_CONFIG_DIR}/ssh_host_ecdsa_key -N ""
fi
if [ ! -f "${SSH_CONFIG_DIR}/ssh_host_ed25519_key" ]; then
  ssh-keygen -t ed25519 -f ${SSH_CONFIG_DIR}/ssh_host_ed25519_key -N ""
fi

# Ensure correct permissions for host keys
chmod 600 ${SSH_CONFIG_DIR}/ssh_host_*_key
chmod 644 ${SSH_CONFIG_DIR}/ssh_host_*_key.pub

# Create authorized_keys file if it doesn't exist
touch ${SSH_CONFIG_DIR}/authorized_keys
chmod 600 ${SSH_CONFIG_DIR}/authorized_keys
chown ${USER}:${USER} ${SSH_CONFIG_DIR}/authorized_keys

# Start SSHD
echo "INFO: starting sshd..."
exec 2>&1
exec /usr/sbin/sshd -D -e -f /ssh_conf/sshd_config

```



> [!NOTE] Tips
> 为什么不使用默认的 `~/.ssh/` 目录，因为 `HOME` 目录会在运行的时候动态挂载到 `PVC` 上去，他的 `owner` 会变为 `root:root`, 权限会是 `777` , 用来启动 `sshd` 会有权限错误. 



`dockerfile` 中核心内容如下:


```dockerfile
#
# NOTE: Use the Makefiles to build this image correctly.
#

ARG BASE_IMG=<base>
FROM $BASE_IMG

ARG TARGETARCH
USER root

# Copy sshd_config to the container
COPY --chown=${NB_USER}:${NB_GID} sshd_config.conf /home/${NB_USER}/ssh_conf/sshd_config

# s6 - copy scripts
COPY --chown=${NB_USER}:${NB_GID} --chmod=755 s6/ /etc

RUN mkdir -pv /ssh_conf && chown -R ${NB_USER}:${NB_GID} /ssh_conf && chmod 700 /ssh_conf

USER $NB_UID

RUN cp -p -r -T "${HOME}" "${HOME_TMP}" \
    # give group same access as user (needed for OpenShift)
 && chmod -R g=u "${HOME_TMP}"
```



### 2-3 打通网络


我们使用方案2， 让 `POD` 的网段和 `VPN` 网段打通，配置路由环境，这个取决于 `k8s` 的环境和 `vpn` 的选型，不是特别难. 这里使用 `jump_server` 实测可以通.


**默认 kubeflow-notebook 的 sidecar-proxy**  会禁止掉除了 `8888` 端口的能力.


```sh
kubectl logs notebook-pod-name -c istio-proxy -n namespace01 -f
```

日志发现:

```
2024-08-12T09:54:05.374Z] "- - -" 0 - - rbac_access_denied_matched_policy[none] "-" 21 0 1 - "-" "-" "-" "-" " xxxx 2209
```


我们通过需要配置额外的 安全策略。


```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ssh-access
  namespace: YOUR-NAMESPACE
spec:
  action: ALLOW
  rules:
  - to:
    - operation:
        ports: ["2209"]

```





### 2-4 Operator 

// TODO, 选择一个合适的 `ServiceAccounts` 来执行. 而且是 监听已知的 `CRD`, 比较简单.