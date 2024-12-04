


## refer

- [stackoverflow](https://stackoverflow.com/questions/78638699/bootjar-task-fails-with-gradle-8-5-and-spring-boot-3-3-0-caused-by-spring-boot)



## 1-quick start


基本就是 `compress` 依赖版本冲突导致出事. 


```sh
./gradlew buildEnvironment  
```

利用上面的代码，或者去子模块执行，定位到冲突. 

比如说 `google` 的 `jib` 造成的.

然后想法强行执行 `1.25.0` 之上的即可.




``