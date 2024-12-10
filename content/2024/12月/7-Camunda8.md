
## 1-Jbpm history

`java` 的圈子里 比较有名的开源流程引擎有: `osworkflow` , `jbpm` , `activiti`, `flowable`, `camunda`  . 

其中 `Jbpm4`, `Activiti` , `Flowable` , `Camunda` 这4个都来自于项目 `jbpm4` , 使用方式非常的类似.

而 [osworkflow](https://github.com/ailohq/osworkflow)  实在太不活跃，直接 `pass` .

1. `jbpm4` 非常早, 由 `Tom Baeyens` 在 `JBoss` 开源, 离职之后, `JBoss` 另外开了一条线，叫做 `Drolls Flow`  ;
2. `Tome Baeyens` 离开 `JBoss` 后, 加入了 `Alfresco` 并且退出了新的 开源工作流系统 `Activiti` ;
3. `Activiti` 由 `Alfresco` 开发, 他的版本管理非常混乱，这里简单说3个版本:
	- `Activiti5` 和 `Activiti6` 的核心 `Leader` 是 `Tijs Rademakers` ;
	- 由于团队分歧, `Tijs Rademakers` 离职后， 5 和 6 的版本直接停止维护, 并且 `Tijs Rademakers` 直接创立了 `flowable` ;
	- 原作者离职走后， 新的 `Activiti7` 交给了 `Salaboy` 团队, 这团队开发了 7 ，7 的内核就是 6， 没有什么新东西

4. `Flowable` 是基于 `activiti6` 的版本，作者就是 `Tijs Rademakers` , *2016加入*,  修复了一堆 `Bug` , 提供了 `DMN` 支持, `BPEL` 支持 .
	- *6.4.1* 版本作为 分水岭, 后续他们团队的重心迁移到 商业版本,  **开源版本** 基本已经废弃， 商业能力包括表单生成器， 历史数据同步到各种数据源 等等 ! 对应的 *开源版本* 基本没有什么更新
	- `Flowable` 的子项目非常多， 包括 `BPMN`, `CMMN`, `DMN` , 表单引擎

5. `Camunda` 则是基于 `activi5` 的衍生, 保留了 `PVM`, 发展轨迹也基本类似， 主要重心在慢慢迁移到 商业版本



> [!NOTE] Tips
> jbpm 直接放弃,  activiti 直接放弃, flowable 可以选，但是在 一些三方压测中， `Camunda` 性能和稳定性上都是上面中最好的



> [!NOTE] Tips
> BPMN 是流程引擎的能力, CMMN 是案例管理的能力， DMN 是决策自动化的能力


## 2-Introduction to Camunda8

**1)-What is camunda8**

是一个提供了 **scalable**, *on demand process automation* 的一体化工具.

- 提供了 `as-a-service` 模式的服务, 一个 `cluster` 组成的 `saas` 服务
- `BPMN` 流程和 `DMN` 决策执行引擎
- 提供完整的工具链（建模、运维、分析）






## refer

- [guide](https://docs.camunda.io/docs/guides/)
- [blog-开源流程引擎三巨头](https://mp.weixin.qq.com/s/jW_7CAvUGgbi1mCLwGlgog)