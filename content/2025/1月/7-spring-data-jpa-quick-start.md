
## 1-QuickStart

**1)-2个依赖**

```xml
<dependency>  
    <groupId>org.springframework.boot</groupId>  
    <artifactId>spring-boot-starter-data-jpa</artifactId>  
</dependency>  
  
<dependency>  
    <groupId>com.mysql</groupId>  
    <artifactId>mysql-connector-j</artifactId>  
</dependency>
```

**2)-配置默认的数据源**

```yaml
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    username: YOUR_USERNAME
    password: YOUR_PWD
    url: YOUR_URL
    hikari:
      maximum-pool-size: 8
      minimum-idle: 1
      data-source-properties:
        cachePrepStmts: true
        prepStmtCacheSize: 250
        prepStmtCacheSqlLimit: 2048
        useServerPrepStmts: true
        useLocalSessionState: true
        rewriteBatchedStatements: true
        cacheResultSetMetadata: true
        cacheServerConfiguration: true
        elideSetAutoCommits: true
        maintainTimeStats: false
```


**3)-展示sql**

```yaml
jpa:  
  hibernate:  
    naming:  
      physical-strategy: org.hibernate.boot.model.naming.CamelCaseToUnderscoresNamingStrategy  
    ddl-auto: none  
  #    show-sql: true  
  properties:  
    hibernate:  
      show_sql: true  
      format_sql: true  
      use_sql_comments: true
```


**4)-kotlin 开启无参构造器支持**

```xml
            <plugin>
                <groupId>org.jetbrains.kotlin</groupId>
                <artifactId>kotlin-maven-plugin</artifactId>
                <version>${kotlin.version}</version>
                <executions>
                    <execution>
                        <id>compile</id>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>test-compile</id>
                        <goals>
                            <goal>test-compile</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <jvmTarget>21</jvmTarget>
                    <compilerPlugins>
                        <plugin>all-open</plugin>
                        <plugin>jpa</plugin>
                    </compilerPlugins>
                </configuration>

                <dependencies>
                    <dependency>
                        <groupId>org.jetbrains.kotlin</groupId>
                        <artifactId>kotlin-maven-noarg</artifactId>
                        <version>${kotlin.version}</version>
                    </dependency>
                    <dependency>
                        <groupId>org.jetbrains.kotlin</groupId>
                        <artifactId>kotlin-maven-allopen</artifactId>
                        <version>${kotlin.version}</version>
                    </dependency>
                </dependencies>
            </plugin>

```


## refer

- [Introduction to spring data jpa](https://www.baeldung.com/the-persistence-layer-with-spring-data-jpa)
- [A Guide to JPA with spring](https://www.baeldung.com/the-persistence-layer-with-spring-and-jpa)