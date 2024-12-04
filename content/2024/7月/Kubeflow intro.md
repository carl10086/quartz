


## Refer

- [Getting Started](https://www.kubeflow.org/docs/started/)


## 1-Intro

> Ecosystem


![](https://www.kubeflow.org/docs/started/images/kubeflow-architecture.drawio.svg)



1. 最底层的是 `Hardware`:  `NVIDIA CUDA`, `AMD`, `INTEL x86 cpu` 等等具体的硬件, 目前 好像对 **mps** 的支持还比较弱.
2. 硬件之上则是 `Infrastucture` : 核心还是 **Kubenetes**, 其中 `Istio` , `dex` 等等都是 `k8s` 生态圈中的常见组件, 一个用来做流量控制，一个用来做 oauth2 , 还有 `certmanager` 用来管理 `tls` 证书等等.  *下面则是 kubenetes 的运行时环境，可以是 self-hosted, 也可以是各种公有云* 
3. `Kubeflow`  在 `k8s` 上提供了非常多的组件, 包括 `kcp`, `notesbooks` 等等, **这里才是 kubeflow 最核心的地方**
4. `Integrations` 则是对机器学习中常见常见框架，甚至是 远端开发环境的支持和集成，属于 应用层了.





[INSTALL](https://github.com/kubeflow/manifests/tree/v1.8.1)

> 	Machine Learning Lifecycle


![](https://www.kubeflow.org/docs/started/images/ml-lifecycle.drawio.svg)


## 2-Pipeline

我们从一个 `mnist_pipeline` 直接入手.

看上去更像是一种 对 `AI` 产品 `CI` 和 `CD` 的概念，类似 `Mlops` ?

我看下面的代码很像，核心就是容器化即可. 

```python
  
  
import kfp.dsl as dsl  
import kfp.gcp as gcp  
import kfp.onprem as onprem  
  
platform = 'GCP'  
  
@dsl.pipeline(  
  name='MNIST',  
  description='A pipeline to train and serve the MNIST example.'  
)  
def mnist_pipeline(model_export_dir='gs://your-bucket/export',  
                   train_steps='200',  
                   learning_rate='0.01',  
                   batch_size='100',  
                   pvc_name=''):  
  """  
  Pipeline with three stages:    1. train an MNIST classifier    2. deploy a tf-serving instance to the cluster    3. deploy a web-ui to interact with it  """  train = dsl.ContainerOp(  
      name='train',  
      image='gcr.io/kubeflow-examples/mnist/model:v20190304-v0.2-176-g15d997b',  
      arguments=[  
          "/opt/model.py",  
          "--tf-export-dir", model_export_dir,  
          "--tf-train-steps", train_steps,  
          "--tf-batch-size", batch_size,  
          "--tf-learning-rate", learning_rate  
          ]  
  )  
  
  
  serve_args = [  
      '--model-export-path', model_export_dir,  
      '--server-name', "mnist-service"  
  ]  
  if platform != 'GCP':  
    serve_args.extend([  
        '--cluster-name', "mnist-pipeline",  
        '--pvc-name', pvc_name  
    ])  
  
  serve = dsl.ContainerOp(  
      name='serve',  
      image='gcr.io/ml-pipeline/ml-pipeline-kubeflow-deployer:'  
            '7775692adf28d6f79098e76e839986c9ee55dd61',  
      arguments=serve_args  
  )  
  serve.after(train)  
  
  
  webui_args = [  
          '--image', 'gcr.io/kubeflow-examples/mnist/web-ui:'  
                     'v20190304-v0.2-176-g15d997b-pipelines',  
          '--name', 'web-ui',  
          '--container-port', '5000',  
          '--service-port', '80',  
          '--service-type', "LoadBalancer"  
  ]  
  if platform != 'GCP':  
    webui_args.extend([  
      '--cluster-name', "mnist-pipeline"  
    ])  
  
  web_ui = dsl.ContainerOp(  
      name='web-ui',  
      image='gcr.io/kubeflow-examples/mnist/deploy-service:latest',  
      arguments=webui_args  
  )  
  web_ui.after(serve)  
  
  steps = [train, serve, web_ui]  
  for step in steps:  
    if platform == 'GCP':  
      step.apply(gcp.use_gcp_secret('user-gcp-sa'))  
    else:  
      step.apply(onprem.mount_pvc(pvc_name, 'local-storage', '/mnt'))  
  
if __name__ == '__main__':  
  import kfp.compiler as compiler  
  compiler.Compiler().compile(mnist_pipeline, __file__ + '.tar.gz')
```