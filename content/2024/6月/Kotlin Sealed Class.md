

## Refer


- [homepage](https://kotlinlang.org/docs/sealed-classes.html)

## 1-Sealed-Intro

> Intro

密封的.

如何理解:

- 如果是类, 那么是对子类的约束, 所有允许的子类都是要预定义的, **集中放一起，其他地方不可能出现新的子类**
- 如果是接口, 同上，但是约束的是接口
- 由于有了约束，意味着编译的时候就 已经知道了他的所有子类，可以有更多的语法糖.



场景:

- Limited class inheritance is desired
- Type-safe design is required
- Working with closed APIs


```kotlin
// Kotlin 中密封类的示例
sealed class Result {
    object Success : Result()
    data class Error(val message: String) : Result()
}

fun handleResult(result: Result) {
    when (result) {
        is Result.Success -> println("Success")
        is Result.Error -> println("Error: ${result.message}")
    }
}
```


> Interface


```kotlin
// Create a sealed interface
sealed interface Error

// Create a sealed class that implements sealed interface Error
sealed class IOError(): Error

// Define subclasses that extend sealed class 'IOError'
class FileReadError(val file: File): IOError()
class DatabaseError(val source: DataSource): IOError()

// Create a singleton object implementing the 'Error' sealed interface
object RuntimeError : Error
```




> [!NOTE] Tips
> 说实话，没有看出来特别的不同, 目前看起来就是 把继承关系 和 实现关系 约束在同一个文件内




> [!NOTE] Tips
> Sealed class 本身的底层是一个 抽象类，不能直接被实例化, 但是可以有构造器和属性



## 2-Example


```kotlin
@JsonNaming(SnakeCaseStrategy::class)  
sealed class MessageContent(val type: MessageType) {  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class TextMessageContent(val msgContent: String) : MessageContent(MessageType.TEXT)  
  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class ImageMessageContent(val url: String) : MessageContent(MessageType.IMAGE)  
  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class VoiceMessageContent(  
        val title: String, // 文件标题或图文标题  
        val url: String, // 资源连接（图片、视频、音频、文件、图文，或视频号的连接)  
        val duration: Int, //音频时长，单位秒  
    ) : MessageContent(MessageType.VOICE)  
  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class ImageTextAndUrlMessageContent(  
        val thumbUrl: String, // 图文图标连接，  
        val url: String, // 资源连接（图片、视频、音频、文件、图文，或视频号的连接)  
        val title: String, // 文件标题或图文标题  
        val desc: String // 图文描述或视频号的描述  
    ) : MessageContent(MessageType.IMAGE_TEXT_AND_URL)  
  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class FileMessageContent(  
        val url: String,  
        val title: String,  
    ) : MessageContent(MessageType.FILE)  
  
    @JsonNaming(SnakeCaseStrategy::class)  
    data class VideoMessageContent(val url: String, val title: String) : MessageContent(MessageType.VIDEO)  
}
```
