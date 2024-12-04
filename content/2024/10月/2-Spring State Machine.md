


## Refer

- [preface](https://docs.spring.io/spring-statemachine/docs/4.0.0/reference/index.html#preface)


## 1-Intro

**1)-状态机的历史**

- 1943年, `Warren McZCulloch` 和 `Walter Pitts` 首次描述了 有限状态机
- 1955年, `George H.Mealy` 提出了 `Mealy Machine` , 一种状态机的概念
- 1956年, `Edward F.Moore` 提出了另一种状态机的 概念

**状态机** 有能理解为一种设计模式, 解决的是 逻辑复杂性问题, 按照 官方的说法, 当代码变得复杂, `IF-ELSE` 多的时候. 


> [!NOTE] Tips
> Traditionally, state machines are added to an existing project when developers realize that the code base is starting to look like a plate full of spaghetti. Spaghetti code looks like a never ending, hierarchical structure of IF, ELSE, and BREAK clauses, and compilers should probably ask developers to go home when things are starting to look too complex.



**2)-SSM 要解决的场景问题**

- `ONE-LEVEL` 的 `StateMachine` 用来满足简单的场景
- 同时支持 **分层状态机** 的设计用来支持 复杂场景
- 支持 `Region` 设计，用来支持更加复杂的 状态配置
- 支持 `Triggers`, `Transitions`, `Guards` , `Actions`
- 类型安全的 `configuration Adapter` 设计
- `Event Listener` 支持
- `Spring IOC` 集成的基本能力



