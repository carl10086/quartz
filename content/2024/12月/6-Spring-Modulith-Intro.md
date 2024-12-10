

## 1-Intro


**1)-What**

`Modular` `Monolith` 是一个架构风格, 基于模块化的想法, 为单体服务 -> 微服务的风格提供了一个比较好的 过渡.

- `Spring  Modulith` 则是 `Spring` 官方退出的模块化项目 ;
- 业务为导向的 项目一般都 遵循领域驱动的 指导论 ;

**2)-The main concept of Spring Modulith is the Application Module**

- 核心是用 `package` 作为 模块的粒度
- 然后针对 `internal` 的包， 使用一些 方法可以自动校验这些模块不会 外部的模块访问， **实现模块间的安全隔离**


> [!NOTE] Tips
> 个人感觉有用，但是不大.



## 2-Quick Start

```pom
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-bom</artifactId>
            <version>1.2.2</version>
            <scope>import</scope>
            <type>pom</type>
        </dependency>
    </dependencies>
</dependencyManagement>
```


```pom
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-api</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

```
// 假设这是我们的主应用包路径
com.example.myapp
    └── MyApplication.java  (@SpringBootApplication)
    └── product            // 产品模块
    │   ├── ProductService.java
    │   ├── ProductRepository.java
    │   ├── domain
    │   │   └── Product.java
    │   └── internal      // 模块内部实现
    │       └── ProductValidator.java
    │
    └── notification      // 通知模块
        ├── NotificationService.java
        ├── EmailSender.java
        └── internal
            └── EmailTemplate.java
```


```java
// 在测试类中可以验证模块结构
@Test
void verifyModularStructure() {
    ApplicationModules.of(MyApplication.class).verify();
}
```



## refer

- [home_page](https://docs.spring.io/spring-modulith/reference/index.html)
- [introduction](https://www.baeldung.com/spring-modulith)