

> 1. **概述**
-   从精益、敏捷到 DevOps
-   SRE、AIOps 概述
-   大模型和 AIOps 的关系
-   DevOps、SRE、AIOps 的关系
-   Docker、Containerd、CRI-O、runc
-   Dockerfile 最佳实践
-   本地集群配置
-   工作负载、网络、配置和存储
-   应用定义：YAML Manifest、Helm 和 Kustomize

> 2. **IaC（基础设施即代码）**
-   Terraform 架构和核心概念
-   Terraform Provider、Module
-   Terraform 入门实战（以腾讯云为例）
-   Terraform 多环境管理进阶实战
-   实战：借助 Crossplane 自建 PaaS 平台

> 3. **AIOps 入门**
-   AIOps 和 LLMOps 概念和使用场景
-   ChatGPT 和 AIOps
-   AIOps Prompt engineering
-   LLM AIOps RAG 增强检索入门
-   LLM AIOps Fine-tuning 入门
-   实战一：ChatGPT API 接入实战
-   实战二：ChatGPT JSON Mode 实战

> 4. **Agent 入门**
-   什么是 Agent
-   四种 AI Agent 设计模式
-   Translation Agent 源码和架构分析
-   LangChain 入门和实战
-   实战一：从零开发个人运维知识库 Agent
-   实战二：借助 Langfuse 实现 LLM 开发追踪

> 5. **Client-go 入门**
-   Client-go 架构和使用场景
-   核心技术：Clientset、DynamicClient、RESTClient、DiscoveryClient
-   实战一：创建第一个 Client-go 工具（持续监听 Pod 状态）
-   实战二：实现一个简单的 Kubectl（创建工作负载）
-   进阶：Informers、Workqueue、Listers、Shared Informers

> 6. **Client-go AIOps 实战**
-   ChatGPT API
-   ChatGPT JSON Mode 入门
-   Golang CLI 实战：Cobra SDK
-   实战一：从零开发 K8sGPT 命令行工具
  - 接入 ChatGPT 自动生成 K8s Manifest，部署到集群
-   实战二：从零开发基于 LLM K8s 故障诊断工具
  - 获取集群状态和事件，给出解决方案建议

> 7. **Kubernetes Operator 入门**
-   Operator 架构和使用场景
-   Controller vs Operator
-   开发工具：Operator SDK vs Kubebuilder
-   实战一：创建你的第一个 Operator
-   Operator 核心技术：Reconcil Loop、Informer、Workqueue

> 8. **Operator AIOps 实战**
-   实战一：开发 Operator 调度 GPU 实例资源池
  - 自动维持 GPU 资源池竞价实例数量
  - 可用于机器学习、推理和大模型训练
  - AI 基础设施 + Operator 实战
-   实战二：开发基于 LLM 的日志流监测 Operator
  - 基于 Loki + LLM
  - 日志实时监测，并结合 LLM 给出修复建议
-   实战三：开发基于内部知识库的 LLM RAG 增强检索 Operator
  - 对内部知识库 Embedding 向量化
  - 通过增强检索查询知识库的解决方案

> 9. **训练流量预测模型实现自动扩容**
-   流量预测模型训练
  - 准备数据集
  - 数据预处理
  - Sklearn 模型训练
  - 生成模型并提供推理服务
-   Operator 开发
  - 使用模型进行流量预测
  - 根据推理结果自动扩容工作负载

> 10. **基于多 Agent 协同的 Kubernetes 故障自动修复**
-   行动决策 Agent
-   自主修复 Agent
  - OOM 修复
  - 镜像异常修复
-   通知人类介入 Agent
  - 容器启动命令异常
-   Agent 进阶：决策链

> 11. **OpenTelemetry 概述**
-   OpenTelemetry 可观测原理
-   OpenTelemetry 两种集成方式
-   OpenTelemetry 数据流

> 12. **OpenTelemetry 开发实战**
-   实战一：集成 OTel SDK
-   实战二：0 代码集成 OpenTelemetry
-   实战三：打造日志、指标和分布式追踪三合一查询面板

> 13. **eBPF 概述**
-   eBPF 工作原理
-   kprobes 和 uprobes 探针
-   eBPF 与可观测性

> 14. **eBPF 零侵入可观测性开发实战**
-   实战一：借助 BCC 开发第一个 eBPF 程序
-   实战二：通过 eBPF、Beyla 实现零侵入 Metrics 和 Tracing（Golang 为例）
