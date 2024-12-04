
## refer

- [flowable open source doc](https://www.flowable.com/open-source/docs/)

## 1-Intro

分为开源版本 和 企业版本.

开源版本 (`OSS`):
	- `BPMN` 引擎
	- `DMN` 引擎
	- `CMMN` 引擎
	- `Form` 引擎
	- 基础 `UI` 界面

商业版本的额外功能:
	- 工作空间
	- 企业级支持
	- 性能优化工具
	- 高级监控
	- 集群管理


## 2-Flowable quickstart

`Flowable` 是一个轻量级的业务流程引擎. 可以:

1. 轻量级：核心是一个 `Java` 库
2. 灵活性：多种部署和使用方式
3. 标准化：支持 `BPMN` 2.0 版本
4. 完整性：提供全套流程管理功能
5. 可扩展：支持自定义和集成

**1)-引入基础的库**

```kotlin
dependencies {  
    implementation("org.flowable:flowable-engine:7.1.0")  
    implementation("com.h2database:h2:2.3.232")  
}
```

**2)-创建一个 Flow engine**

```kotlin
val cfg = StandaloneProcessEngineConfiguration().apply {  
    setJdbcUrl("jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1")  
    setJdbcUsername("sa")  
    setJdbcPassword("")  
    setJdbcDriver("org.h2.Driver")  
    setDatabaseSchemaUpdate(ProcessEngineConfiguration.DB_SCHEMA_UPDATE_TRUE)  
}  
  
val processEngine = cfg.buildProcessEngine()
```

- 是一个线程安全的引擎.
- 依赖 `JDBC`


**3)-一个简单的流程

![](https://www.flowable.com/open-source/docs/assets/bpmn/getting.started.bpmn.process.png)


有如下要点:

1. 这个请假的流程的启动 需要一些输入信息: *员工姓名* , *请假的天数* , *描述*
2. 只有在 实际的提交请求的时候才会 创建流程实例

上面是一个非常简单的流程引擎:

1. 第一个矩形是用户任务， 要人工输入批准或者拒绝请求，我们假设是上级 ;
2. `exclusiveGateway` 是一个带❎ 的菱形, 根据 上级的决定走到 批准或者 拒绝路径 ;
3. 如果批准， 需要在外部系统中注册请求， 然后通知员工决定的 用户任务 ;
4. 如果拒绝，则发送邮件通知员工

**4)-用 BPMN2.0 的协议代表描述上面的流程**

`BPMN2.0` 是一个工业上被标准化的协议, 是一个 `XML` 标准.

下面是上图的 `BPMN2.0` 标准:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
  xmlns:omgdc="http://www.omg.org/spec/DD/20100524/DC"
  xmlns:omgdi="http://www.omg.org/spec/DD/20100524/DI"
  xmlns:flowable="http://flowable.org/bpmn"
  typeLanguage="http://www.w3.org/2001/XMLSchema"
  expressionLanguage="http://www.w3.org/1999/XPath"
  targetNamespace="http://www.flowable.org/processdef">

  <process id="holidayRequest" name="Holiday Request" isExecutable="true">

    <startEvent id="startEvent"/>
    <sequenceFlow sourceRef="startEvent" targetRef="approveTask"/>

    <userTask id="approveTask" name="Approve or reject request"/>
    <sequenceFlow sourceRef="approveTask" targetRef="decision"/>

    <exclusiveGateway id="decision"/>
    <sequenceFlow sourceRef="decision" targetRef="externalSystemCall">
      <conditionExpression xsi:type="tFormalExpression">
        <![CDATA[
          ${approved}
        ]]>
      </conditionExpression>
    </sequenceFlow>
    <sequenceFlow  sourceRef="decision" targetRef="sendRejectionMail">
      <conditionExpression xsi:type="tFormalExpression">
        <![CDATA[
          ${!approved}
        ]]>
      </conditionExpression>
    </sequenceFlow>

    <serviceTask id="externalSystemCall" name="Enter holidays in external system"
        flowable:class="org.flowable.CallExternalSystemDelegate"/>
    <sequenceFlow sourceRef="externalSystemCall" targetRef="holidayApprovedTask"/>

    <userTask id="holidayApprovedTask" name="Holiday approved"/>
    <sequenceFlow sourceRef="holidayApprovedTask" targetRef="approveEnd"/>

    <serviceTask id="sendRejectionMail" name="Send out rejection email"
        flowable:class="org.flowable.SendRejectionMail"/>
    <sequenceFlow sourceRef="sendRejectionMail" targetRef="rejectEnd"/>

    <endEvent id="approveEnd"/>

    <endEvent id="rejectEnd"/>

  </process>

</definitions>
```

我们能看出来这里有各种各样的标签.  这就是 `BPMN2.0` 的标准协议.

1) `startEvent` -> `approveTask(ref to decision)` ,而. `decision` 这里被定义为 一个 `exclusiveGateway` 一个排他网关，代表是 `True | False` 去2个 不同的流，传入的是用 `el` 表达式语言的表达式引擎， 根据这个 `expression` 去 `sendRejectionMail` 或者 `externalSystemCall` ;
2) `userTask` 代表是一个用户交互任务 ;
3) `serviceTask` 则需要定义一个对应的 `class` 去实现 ;
4) ...

**5)-如下，把上面的 流程定义注册到 engine 中**

```kotlin
fun main(args: Array<String>) {  
    val cfg = StandaloneProcessEngineConfiguration().apply {  
        setJdbcUrl("jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1")  
        setJdbcUsername("sa")  
        setJdbcPassword("")  
        setJdbcDriver("org.h2.Driver")  
        setDatabaseSchemaUpdate(ProcessEngineConfiguration.DB_SCHEMA_UPDATE_TRUE)  
    }  
  
    /*1. 构建流程引擎*/  
    val processEngine = cfg.buildProcessEngine()  
    /*2. 服务接口: 负责流程定义的部署，查询等等操作*/  
    val repositoryService = processEngine.repositoryService  
  
    /*3. 使用 repositoryService 部署这个 def*/    val deployment = repositoryService.createDeployment().addClasspathResource("holiday-request.bpmn20.xml").deploy()  
    /*4. 通过查询, 也就是 getName 来验证我们的这个 def*/    repositoryService.createProcessDefinitionQuery().deploymentId(deployment.id).singleResult()  
        .apply { println("Found process definition : $name") }  
  
}
```

**6)-Starting a process instance**

现在我们已经把流程定义部署到流程引擎中, 因此可以使用这个流程定义作为 "蓝图" 来启动流程实例. 我们需要一些流程启动的变量, 获取变量的方式可以是 *用户表单*, *REST API* 等等姿势，比如下面使用命令行最简单的方式输入. 

```java
// 1. 收集用户输入
Scanner scanner= new Scanner(System.in);

System.out.println("Who are you?");
String employee = scanner.nextLine();

System.out.println("How many holidays do you want to request?");
Integer nrOfHolidays = Integer.valueOf(scanner.nextLine());

System.out.println("Why do you need them?");
String description = scanner.nextLine();
```


把上面的变量构建为一个 `HashMap<String, Object>` 就可以获取到 `ProcessInstance` 

```kotlin
val runtimeService = processEngine.runtimeService  
/*5. 直接硬编码一个输入, 小张要请5天的年假*/  
val process = runtimeService.startProcessInstanceByKey("holidayRequest", mapOf(  
    "employee" to "小张",  
    "nrOfHolidays" to 5,  
    "processInstance" to "Annual leave"  
))
```

当一个 `process` 成功 `started` 了:

1. 就会创建一个执行实例, `execution` ;
2. 从开始事件开始,按照序列流向用户任务 ;
3. 在数据库中创建 任务记录 ;
4. 引擎停止执行并返回 `API` 调用 ;


## 3-Details about quick start

### 3-1 Sidetrack : 事务边界

`Flowable engine` 强依赖于事务边界, 当 `make a flowable api call` 的时候，所有的操作都 **sync:同步的**, **同一个事务** . 这意味着, 当方法的调用返回的时候, 一个事务会被自动的提交. 

举个例子,  当一个 `process started`, 在当前的状态到下一个 next wait state 会属于同一个事务.

```
// 完整的请假流程事务边界
class 请假流程 {
    // 第一个事务: 发起请假
    事务开始: 发起请假申请(请假数据) {
        验证请假数据();
        保存请假记录();
        创建经理审批任务();
        事务提交();
    }
    
    // 等待状态: 经理审批中
    // 这期间不占用事务和系统资源
    
    // 第二个事务: 经理审批
    事务开始: 经理审批(审批结果) {
        更新审批状态();
        if (审批通过) {
            创建人事审核任务();
        } else {
            记录拒绝原因();
            发送拒绝通知();
        }
        事务提交();
    }
    
    // 等待状态: 人事审核中
    
    // 第三个事务: 人事审核
    事务开始: 人事审核(审核结果) {
        更新人事记录();
        更新考勤系统();
        发送最终通知();
        事务提交();
    }
}
```


在所有的 `WaitStates` 和 `Async Execution Points` 都会自动的中断事务. 我们要利用这个去控制事务的边界.

### 3-2 Querying And Completing Tasks

在真实场景中，肯定会需要一个用户界面 让员工和管理者去查询他们的任务列表. 通过这些列表, 他们可以检查存储为 流程变量的流程实例数据， 并决定如何处理任务。 

上面的流程定义不完整， 因为我们还没有分为 `userTask` 分配执行人. 

**把 approveTask 分配给管理者** 
```xml
<userTask id="approveTask" name="Approve or reject request" flowable:candidateGroups="managers"/>
```

- 使用的 `candidateGroups` 是一种组的方式, 后续也可以根据这个去查询
**把  holidayApprovedTask 分配给 employee**
```xml
<userTask id="holidayApprovedTask" name="Holiday approved" flowable:assignee="${employee}"/>
```

- 使用的是 动态的属性
**查询 candidateGroups = managers** 的任务.

```kotlin
/*6. 查询 candidateGroups = managers*/val taskService = processEngine.taskService  
taskService.createTaskQuery().taskCandidateGroup("managers").list().forEach {  
    println("Manage have task: ${it.name}")  
}
```




