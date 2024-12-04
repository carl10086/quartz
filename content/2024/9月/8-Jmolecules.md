
## Intro

- [jmolecules](https://github.com/xmolecules/jmolecules)


> **Goals**


1. 利用注解和接口的方式 去 **清晰的** 表示某个类，包，或者方法的 职责和角色, 去 **帮助成员理解代码**
2. 标准化 命名和注解
3. 支持各种工具的集成. 
	- 例如 Augmentation of the code, 通过 `ByteBuddy` 的自动化的支持 `Spring`, `Jpa` 这种
	- Check for architecture rules, 例如通过 `jQAssistant` 或者 `ArchUnit` 工具, 验证代码是否遵循预定义的架构规则


## 1-Advancing Enterprise DDD

- [原文](https://scabl.blogspot.com/p/advancing-enterprise-ddd.html) : 比较古老的文章，大概是 2015 年左右 `DDD` 起来的时候, 放在当时还是不错的. 

**1)-Pojo Myth**

1. `POJO` 的核心能力就是 可以定义领域模型中的实体, 并且同时进行持久化到 `DB`
2. 但是 `POJO` 会混合一些和业务无关的关注点. **非业务功能的字段**
	1. `ID` : 数据库的主键
	2. `createdBy` `createdDate` `lastModifiedBy`  ... : 用来诊断的 列
	3. `version`: 乐观锁


3. 数据库 `ID` 的误用: 在设计用户交互功能的时候, 开发的人员不应该提到数据库 `ID` , 甚至直接暴漏给前端, 定位一个用户应该用 **姓名|手机** 这样 拥有业务语义的东西.


**2)-Rethinking POJO**


这些字段其实就是非功能的字段, 文章中建议要不就别暴漏这些字段的访问方法, `getter | setter`,  要不抽一个专门的对象叫做 `PersistceState`, 分离关注点.

**3)-Aggreate Root**

聚合根和领域边界. 一个非常简单的例子.

## 2-Libs

通过这些库，我们可以更好的 梳理 作者对领域驱动设计的 理解.

### 2-1 Express DDD concepts

**基本思路** 是用 注解或者接口的方式 来表达 当前的 类或者字段来 领域驱动设计中的 意义.

- `AggregateRoot`: 聚合根
- `ValueObject`: 值对象
- `Factory` : 用来创建 聚合和实体对象的 工厂
- `Identity` : 
- `Repository`
- `Service`
- `ValueObject`
- `Entity`
- `Association` : 基于 [原文](https://scabl.blogspot.com/2015/04/aeddd-9.html) 实现的关联设计.

要注意选择合适的类库.

- [jmolecules-ddd](https://github.com/xmolecules/jmolecules/tree/main/jmolecules-ddd) 和 [kmolecules-ddd](https://github.com/xmolecules/jmolecules/tree/main/kmolecules-ddd)
- [jmolecules-events](https://github.com/xmolecules/jmolecules/tree/main/jmolecules-events) : 事件驱动的相关接口

### 2-2 Expressing architectural concepts


表达架构的概念，这里就非常的有意思，引入了几个没有怎么玩的架构风格.

- [`jmolecules-architecture`](https://github.com/xmolecules/jmolecules/blob/main/jmolecules-architecture) — annotations to express architectural styles in code.
    - [`jmolecules-cqrs-architecture`](https://github.com/xmolecules/jmolecules/blob/main/jmolecules-architecture/jmolecules-cqrs-architecture) — CQRS architecture
        - `@Command`
        - `@CommandDispatcher`
        - `@CommandHandler`
        - `@QueryModel`
        
    - [`jmolecules-layered-architecture`](https://github.com/xmolecules/jmolecules/blob/main/jmolecules-architecture/jmolecules-layered-architecture) — Layered architecture
        - `@DomainLayer`
        - `@ApplicationLayer`
        - `@InfrastructureLayer`
        - `@InterfaceLayer`
        
    - [`jmolecules-onion-architecture`](https://github.com/xmolecules/jmolecules/blob/main/jmolecules-architecture/jmolecules-onion-architecture) — Onion architecture
        - **Classic**
            - `@DomainModelRing`
            - `@DomainServiceRing`
            - `@ApplicationServiceRing`
            - `@InfrastructureRing`
            
        - **Simplified** (does not separate domain model and services)
            - `@DomainRing`
            - `@ApplicationRing`
            - `@InfrastructureRing`
        
    - [`jmolecules-hexagonal-architecture`](https://github.com/xmolecules/jmolecules/blob/main/jmolecules-architecture/jmolecules-hexagonal-architecture) — Hexagonal architecture
        - `@Application`
        - `@(Primary|Secondary)Adapter`
        - `@(Primary|Secondary)Port`

都是比较经典的架构方式
## 3-Integration


使用 `bytebuddy` 的插件机制来集成.


## 4-quickstart

// 感觉一般，思路值得借鉴，库可以不用. 至少不用集成，一般一个公司内部要用 spring，基本就定下来全部 spring 了.
// todo 