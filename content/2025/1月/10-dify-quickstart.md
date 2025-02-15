
## 1-Intro


> [!NOTE] What's Dify?
> 一个融合了 `Backend as Service` 和 `LLMops` 的理念

- Backend as Service: 也就是所谓的 Baas
- LLmOps: llm 模型的自动管理



**Features:**

- 内置了 `LLM` 的关键技术栈
- 数百个模型的支持
- 直观的 `Prompt` 编排界面
- 高质量的 `RAG` 引擎
- 稳健的 `Agent` 框架
- 灵活的流程编排


**Mac Docker 服务崩溃**

执行如下的命令然后重装即可

```shell
# 停掉 Docker 服务
sudo pkill '[dD]ocker'

# 停掉  vmnetd 服务
sudo launchctl bootout system /Library/LaunchDaemons/com.docker.vmnetd.plist

# 停掉 socket 服务
sudo launchctl bootout system /Library/LaunchDaemons/com.docker.socket.plist

# 删除 vmnetd 文件
sudo rm -f /Library/PrivilegedHelperTools/com.docker.vmnetd

# 删除 socket 文件
sudo rm -f /Library/PrivilegedHelperTools/com.docker.socket

```


**基于 docker-compose 的启动**

**如果要更新 dify 版本**

```shell
cd dify/docker
docker compose down
git pull origin main
docker compose pull
docker compose up -d
```

## 2-QuickStart

### 2-1 Sd 图片生成应用

`Dify` 中有 所谓的模型和工具.  
	- 模型是各种大语言模型， 例如 `GPT-4`, `Claude`, 文心一言等等， 是 `Agent`的大脑 
	- 工具: 是指模型可以调用的外部功能和服务


**Steps:**

1. 工具中配置 `SD` ;
2. 模型中配置 供应商 ;


### 2-2 ChatFlow

- `Flow` 的能力 ;
- `langchain` 的能力 ;
- `Agent` 的能力
- 快速迭代的能力 ;

通过设计状态机，可以快速实现复杂的交互 .



## refer

- [dify](https://docs.dify.ai/zh-hans/getting-started/install-self-hosted/docker-compose)