
## 1-Intro

```
project_root/
├── app/                      # 主应用目录
│   ├── __init__.py
│   ├── main.py               # FastAPI应用入口
│   ├── api/                  # API路由
│   │   ├── __init__.py
│   │   ├── endpoints/        # 各个端点
│   │   └── dependencies.py   # 依赖项
│   ├── core/                 # 核心模块
│   │   ├── __init__.py
│   │   ├── config.py         # 配置管理
│   │   └── logging.py        # 日志配置
│   ├── agents/               # LangChain agents
│   │   ├── __init__.py
│   │   └── custom_agent.py
│   ├── models/               # 数据模型
│   │   ├── __init__.py
│   │   └── schemas.py        # Pydantic模型
│   ├── services/             # 业务逻辑
│   │   ├── __init__.py
│   │   └── some_service.py
│   └── utils/                # 工具函数
│       ├── __init__.py
│       └── helpers.py
├── tests/                    # 测试目录
│   ├── __init__.py
│   ├── conftest.py
│   └── test_*.py
├── .env                      # 环境变量(不提交到git)
├── .env.example              # 环境变量示例
├── .gitignore
├── pyproject.toml            # 项目依赖(Poetry)
├── README.md
└── docker-compose.yml        # Docker配置
```


**1)-Python 版本考虑**

当前 2025年3月前的选择:

```
Python 3.12（最新稳定版）
	•	发布于2023年10月
	•	优点：
	▪	性能显著提升
	▪	更好的错误提示和调试体验
	▪	改进的类型注解支持
	▪	优化的启动时间
	•	考虑因素：
	▪	一些第三方库可能尚未完全支持
Python 3.11
	•	优点：
	▪	比Python 3.10快10-60%
	▪	更详细的错误追踪
	▪	良好的库兼容性
	•	非常适合大多数新项目
Python 3.10
	•	优点：
	▪	稳定且成熟
	▪	几乎所有主流库都支持
	▪	引入了模式匹配等实用功能
```


**2)-依赖兼容性问题考虑**

```sh
pip install pip-tools
```

使用 `pip-compile`, 创建一个简单的 `requirements.in` 文件.

```
# requirements.in
fastapi
langchain
uvicorn
```


使用如下的命令生成带有精确版本.

```sh
pip-compile requirements.in

# 或者不需要注解
pip-compile --no-annotate requirements.in
```

注意， 他会生成很多的间接依赖, 

**3)-unicorn 的 IO 模型**

```
负载均衡器
  │
  ├── Gunicorn/Uvicorn主进程
  │     │
  │     ├── 工作进程 1
  │     │     │
  │     │     └── 主线程 (运行事件循环)
  │     │           │
  │     │           ├── 协程 1 (处理请求 1)
  │     │           ├── 协程 2 (处理请求 2)
  │     │           └── ...
  │     │
  │     ├── 工作进程 2
  │     │     │
  │     │     └── 主线程 (运行事件循环)
  │     │           │
  │     │           ├── 协程 1 (处理请求 3)
  │     │           ├── 协程 2 (处理请求 4)
  │     │           └── ...
  │     │
  │     └── ...
  │
  └── 可能的线程池 (用于CPU密集型任务)
        │
        ├── 工作线程 1
        ├── 工作线程 2
        └── ...
```





## refer

- [https://github.com/BCG-X-Official/agentkit](https://github.com/BCG-X-Official/agentkit)