

## refer

- [kotlin lombok compiler plugin](https://kotlinlang.org/docs/lombok.html)


## 1-概述


**原理:**

`lombok` 在 `javac` 中作为注解处理器, `javac` 支持加载 `classpath` 中所有的 `META-INF/services/javax.annotation.processing.Processor` 文件.


```mermaid
flowchart TB
    A[编译开始] --> B[扫描classpath]
    B --> C[发现Lombok处理器]
    C --> D[加载AnnotationProcessorHider$AnnotationProcessor]
    D --> E[初始化ShadowClassLoader]
    E --> F[加载.SCL.lombok文件]
    F --> G{判断编译环境}
    G -->|javac| H[使用LombokProcessor]
    G -->|ecj| I[注入警告信息]
    H --> J[开始分层处理注解]
    J --> K[处理当前层级注解]
    K --> L[生成对应代码]
    L --> M[强制新的处理轮次]
    M --> N{还有待处理的注解层级?}
    N -->|是| K
    N -->|否| O[完成所有转换]
    O --> P[生成最终字节码]

    %% 注解处理示例，使用虚线连接表示并行关系
    K -.-> Q1[处理@Getter]
    K -.-> Q2[处理@Setter]
    K -.-> Q3[处理@ToString]
    K -.-> Q4[处理其他注解]

    %% 设置节点样式
    style A fill:#f9f
    style P fill:#9f9

```




核心设计就是 从 `ClassLoader` 那里就要隐藏掉 `lombok` 本身的类.


这种编译期 完成代码生成的能力， 不会影响运行时的性能. 但是缺点:

- 通过影响 `javac` 的 `AST` 机制，跨版本一般都有问题.
- 调试比较麻烦
- 代码实际的内容和源码看到的可能完全不一致


## 2-Kotlin 混合编译


`kotlin` 完全不需要 `lombok` 的所有功能. 但是 混合编译的场景是这样的.

`kotlin` 和 `java` 在同一个模块，他们之间会相互依赖. `java` 类可能会依赖 `lombok` ,  而且会很不标准的姿势, 因为 `kotlin` 的编译比 `java` 可能更加严格，都是支持 `lombok` 的插件.

但是 `java` 的代码，假设有比较深的继承树，然后重复的注解，例如:

`@Data` `ToString` `SuperBuilder` ... 各种一起上，`JAVA` 可能处理是 `WARNING`, `kotlin`  可能是直接报错，认为递归有问题.


我们需要一个 `kotlin` 的 `lombok` 的编译插件.

1. 让 `Kotlin`  代码能够正确理解 `Lombok` 生成的代码
2. 处理 `Java` 和 `Kotlin` 之间的互操作性
3. 确保编译时的类型安全





```xml
            <!-- kotlin compile-->
            <plugin>
                <groupId>org.jetbrains.kotlin</groupId>
                <artifactId>kotlin-maven-plugin</artifactId>
                <version>${kotlin.version}</version>
                <configuration>
                    <compilerPlugins>
                        <plugin>lombok</plugin>
                    </compilerPlugins>
                </configuration>
                <extensions>true</extensions> <!-- You can set this option
            to automatically take information about lifecycles -->
                <executions>
                    <execution>
                        <id>compile</id>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                        <configuration>
                            <sourceDirs>
                                <sourceDir>src/main/kotlin</sourceDir>
                                <sourceDir>src/main/java</sourceDir>
                            </sourceDirs>
                        </configuration>
                    </execution>
                    <execution>
                        <id>test-compile</id>
                        <goals>
                            <goal>test-compile</goal>
                        </goals>
                        <configuration>
                            <sourceDirs>
                                <sourceDir>${project.basedir}/src/test/kotlin</sourceDir>
                                <sourceDir>${project.basedir}/src/test/java</sourceDir>
                            </sourceDirs>
                        </configuration>
                    </execution>
                </executions>
                <dependencies>
                    <dependency>
                        <groupId>org.jetbrains.kotlin</groupId>
                        <artifactId>kotlin-maven-lombok</artifactId>
                        <version>${kotlin.version}</version>
                    </dependency>
                </dependencies>
            </plugin>
                <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <executions>
                    <!-- A. 禁用默认编译 -->
                    <execution>
                        <id>default-compile</id>
                        <phase>none</phase>
                    </execution>
                    <!-- B. 禁用默认测试编译 -->
                    <execution>
                        <id>default-testCompile</id>
                        <phase>none</phase>
                    </execution>
                    <execution>
                        <id>java-compile</id>
                        <phase>compile</phase>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>java-test-compile</id>
                        <phase>test-compile</phase>
                        <goals>
                            <goal>testCompile</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <source>21</source>
                    <target>21</target>
                </configuration>
            </plugin>
```





但是要注意的是, 即时是 `lombok` 插件 `kotlin` 本身支持的也不多.  比如说 `SuperBuilder` `Tolerate` .  

一个简单的取巧办法是 断开 `kotlin` 对这些 `java` 类的依赖. 例如.

```java
public class LombokUtils {  
    public static VisibleActionData ofVisibleActionData(  
            String roleId,  
            Point point  
    ) {  
        return VisibleActionData.builder().roleId(roleId)  
                .point(point).build();  
    }  
}
```



让 `kotlin` 的代码仅仅依赖这些类, 不要直接和 `lombok` 的类有关系，因为需要 `kotlin` 去理解当前的 `javac` 的 `annotationProcessor` 机制是非常麻烦，二者的严格程度是不一样的.


