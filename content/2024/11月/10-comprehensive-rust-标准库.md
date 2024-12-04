
## 1-介绍

标准库是有分层的:

- `core` : 最基础的层， the basic types and functions don't depend on `libc` , `allocator`  ;
- `alloc` : 包括全局堆分配器的类型, 例如 `Vec`, `Box` 和 `Arc` ;


## 2-标准库类型

**1)-Option**

```rust
fn main() {  
    let name = "Löwe 老虎 Léopard Gepardi";  
    let mut position = name.find('é');  
  
    println!("find returned {position:?}");  
    assert_eq!(position.unwrap(), 14);  
  
    // 这个已经不存在了.  
    position = name.find('Z');  
    println!("find returned {position:?}");  
    // 这里应该会有异常，因为 position 应该是 None    assert_eq!(position.expect("Character not found"), 0);  
}
```

- `unwrap` 会返回 `Option` 或者 `panic` 的值, `expect` 方法类似，使用错误消息.


**2)-Result**

`Result` 和 `Option` 类似，用来封装通用的 成功或者失败.

```rust
use std::fs::File;  
use std::io::{Error, Read};  
  
fn main() {  
    let file: Result<File, Error> = File::open("Cargo.toml");  
  
    match file {  
        Ok(mut file) => {  
            let mut contents = String::new();  
  
            if let Ok(bytes) = file.read_to_string(&mut contents) {  
                println!("Dear diary: {contents} ({bytes}) bytes");  
            } else {  
                println!("Couldn't read file");  
            }  
        }  
        Err(err) => {  
            println!("Couldn't open file: {err}");  
        }  
    }  
}
```

建议进行错误检查, 在绝不应该出现错误的情况下， 可以用 `unwrap()` 和 `expect()` 方法, 这也是一种开发者意向信号.


**3)-String**

```rust
fn main() {
    let mut s1 = String::new();
    s1.push_str("Hello");
    println!("s1: len = {}, capacity = {}", s1.len(), s1.capacity());

    let mut s2 = String::with_capacity(s1.len() + 1);
    s2.push_str(&s1);
    s2.push('!');
    println!("s2: len = {}, capacity = {}", s2.len(), s2.capacity());

    let s3 = String::from("🇨🇭");
    println!("s3: len = {}, number of chars = {}", s3.len(), s3.chars().count());
}
```


`String` 会实现 `Deref<Target = str>` , 这意味着可以对 `String` 调用所有的 `str` 方法.

1. `String::new` 会返回一个新的空字符串, 如果您知道自己想要推送到字符串的数据量, 可以使用 `String::with_capacity` ; 
2. `String::len` 会返回 "String" 的大小 (以字节为单位， 可能不同于字符为单位的长度) ;
3. `String::chars` 会针对 实际字符返回一个 迭代器, `char` 可能和 常规的 "字符" 有所不同 ;
4. 口中的字符串，可能是 "&str" 或者 "String" ;
5. "String" 是作为字节矢量的 封装容器实现的， 矢量上支持的许多操作在 "String" 上也受支持，但是有一些额外保证 ;
6. 大多数类型都有 `to_string` 方法
7. 字符串是很大的话题，暂时搁置


**4)-Vec**


类似 `String`  , `HashMap` 都是一个 `collection`, 数据被存储在 `heap` 上, 编译的时候不确定数据的大小，可以在运行期 增长或者缩小. 


1. 动态能力:
	- 动态数组
	- 存储在内存中
	- 大小可以动态的调整
2. 泛型能力
	- 泛型容器
	- 类型 T 可以自动推断
	- 类型推断发生在 第一次使用的时候
3. `vec![...]` 是用来替换 `Vec::new()` 的规范化宏, 支持向矢量添加元素
4. 支持切片操作

```rust
fn main() {  
    // 创建一个空的可变向量 v1    let mut v1 = Vec::new();  
  
    // 向 v1 中添加一个元素 42    v1.push(42);  
  
    // 打印 v1 的长度和容量  
    println!("v1: len = {}, cap ={}", v1.len(), v1.capacity());  
    // 打印 v1 的内容  
    println!("v1 :{:?}", v1);  
  
    // 创建一个容量为 v1 长度加 1 的可变向量 v2    let mut v2 = Vec::with_capacity(v1.len() + 1);  
  
    // 将 v1 中的元素扩展到 v2 中  
    v2.extend(v1.iter());  
  
    // 向 v2 中添加一个元素 9999    v2.push(9999);  
  
    // 打印 v2 的长度和容量  
    println!("v2: len = {}, cap = {}", v2.len(), v2.capacity());  
    // 打印 v2 的内容  
    println!("v2 :{:?}", v2);  
  
    // 创建一个初始向量 v3，其中包含 [0, 0, 1, 2, 3, 4]    let mut v3 = vec![0, 0, 1, 2, 3, 4];  
  
    // 保留 v3 中的所有偶数元素  
    v3.retain(|&x| x % 2 == 0);  
  
    // 打印 v3 的内容  
    println!("v3 :{:?}", v3);  
  
    // 去除 v3 中的相邻重复元素  
    v3.dedup();  
  
    // 打印 v3 的内容  
    println!("v3 :{:?}", v3);  
}
```


**5)-HashMap**

```rust
fn main() {  
    // 定义一个可变的HashMap，用于存储书名和对应的页数  
    let mut page_counts = HashMap::new();  
  
    // 向HashMap中插入几本书的信息  
    page_counts.insert("Adventures of Huckleberry Finn", 207);  
    page_counts.insert("Grimms' Fairy Tales", 751);  
    page_counts.insert("Pride and Prejudice", 303);  
  
    // 检查HashMap中是否包含"Les Misérables"  
    if !page_counts.contains_key("Les Misérables") {  
        // 打印HashMap中已知的书籍数量，但表示不包含"Les Misérables"  
        println!(  
            "We know about {} books, but not Les Misérables.",  
            page_counts.len()  
        );  
    }  
  
    // 遍历两个书名，打印对应页数或表示书籍未知  
    for book in ["Pride and Prejudice", "Alice's Adventure in Wonderland"] {  
        match page_counts.get(book) {  
            Some(count) => println!("{book}: {count} pages"), // 打印已知书籍的页数  
            None => println!("{book} is unknown."),           // 表示书籍未知  
        }  
    }  
  
    // 使用.entry()方法，如果书籍不存在则插入0，并将页数增加1  
    for book in ["Pride and Prejudice", "Alice's Adventure in Wonderland"] {  
        let page_count: &mut i32 = page_counts.entry(book).or_insert(0);  
        *page_count += 1;  // 对该书的页数增加1  
    }  
  
    // 打印最终的HashMap，查看所有书籍及其页数  
    println!("{page_counts:#?}");  
}
```


## 3-标准库特征

**1)-PartialEq 和 Eq** 

过于严谨了. 

1. 定义了部分等价关系, 要求自反性 和 对称性 , 不要求 **传递性**
2. 典型例子: `f32` `f64`, 浮点数因为有 `NaN` 的可能性，极端情况允许无法比较

`Eq` 则要求能传递. 大多数的基本类型 都是 `Eq`, 要求所有的值都能比较


同样的还有: `PartialOrd` 和 `Ord`


**2)-自定义运算符**

```rust
#[derive(Debug, Copy, Clone)]  
struct Point {  
    x: i32, // 坐标 x    y: i32, // 坐标 y}  
  
/* 实现标准库中的 Add trait 以支持 Point 结构体的加法运算  
 * 使用泛型类型参数 Self 表示返回值类型  
 */impl std::ops::Add for Point {  
    type Output = Self; // 定义加法运算的返回类型为 Self 类型  
  
    /* 实现加法运算方法  
     * 参数：  
     *     - self: 当前 Point 实例  
     *     - other: 要与之相加的另一个 Point 实例  
     * 返回：  
     *     - 返回一个新的 Point 实例，其 x 和 y 坐标分别为两个 Point 实例对应坐标的和  
     */    fn add(self, other: Self) -> Self {  
        Self {  
            x: self.x + other.x, // x 坐标相加  
            y: self.y + other.y  // y 坐标相加  
        }  
    }  
}  
  
fn main() {  
    let p1 = Point { x: 10, y: 20 };  // 创建第一个 Point 实例  
    let p2 = Point { x: 100, y: 200 }; // 创建第二个 Point 实例  
    // 输出两个 Point 实例及其相加的结果，格式为: {p1} + {p2} = {p1 + p2}  
    println!("{:?} + {:?} = {:?}", p1, p2, p1 + p2);  
}
```

**3)-From 和 Into**

1. 只要实现了 `From` , 就会自动实现 `Into`


**4)-闭包**

```rust
fn apply_with_log(func: impl FnOnce(i32) -> i32, input: i32) -> i32 {
    println!("Calling function on {input}");
    func(input)
}

fn main() {
    let add_3 = |x| x + 3;
    println!("add_3: {}", apply_with_log(add_3, 10));
    println!("add_3: {}", apply_with_log(add_3, 20));

    let mut v = Vec::new();
    let mut accumulate = |x: i32| {
        v.push(x);
        v.iter().sum::<i32>()
    };
    println!("accumulate: {}", apply_with_log(&mut accumulate, 4));
    println!("accumulate: {}", apply_with_log(&mut accumulate, 5));

    let multiply_sum = |x| x * v.into_iter().sum::<i32>();
    println!("multiply_sum: {}", apply_with_log(multiply_sum, 3));
}
```


## 4-内存管理

**1)-栈和堆的区别**

- 栈: 局部变量和连续的内存区域
	- 值在编译的时候 具有已知的固定大小
	- 速度极快: 只需要移动一个指针
	- 易于管理: 遵循函数调用规则
	- 优秀的内存局部性
- 堆: 函数调用之外的值的存储
	- 值具有动态大小，具体大小需在运行的时候确定
	- 比栈稍慢: 需要向系统申请空间
	- 不保存内存局部性

**2)-内存管理方法**

传统上， 语言分为2大类:

- 通过手动内存管理实现完全的控制: `C`, `C++`, `Pascal` ..
	- 程序员决定什么时候 分配或者释放内存
	- 程序员必须确定指针是否 仍然指向有效内存
	- *人总是会犯错的*
- 运行的时候通过自行的内存管理实现完全的安全: `Java` `Python` `Go` `Haskell` ..
	- 运行的时候系统可以确保在内存无法被引用之前, 不会释放内存
	- 通常通过引用计数， 垃圾回收或者 `RAII` 实现

`Rust` 则是组合起来:

- 通过在编译的时候 强制执行正确的内存管理 来实现完全的控制和安全
- 在大多数的情况下, `Rust` 的所有权和借用模型可以实现 `C` 语言的性能,  能够准确的在所需要的位置执行分配和释放操作, 为 零成本. 
- 提供了类似 `C++` 智能指针的工具, 必要的时候，提供了引用计数的其他选项

**3)-所有权**

所有的变量绑定都有一个有效的作用域, 使用超出作用域的变量是错误的.


```rust
// 定义一个Point结构体，包含两个字段(x, y)  
struct Point(i32, i32);  
  
/*   
* 主函数：程序执行的入口点  
 * 目的：演示结构体的使用以及作用域的影响  
 */fn main() {  
    {  
        // 创建一个Point实例，字段值为(x: 3, y: 4)  
        let p = Point(3, 4);  
        // 输出Point实例的第一个字段(x)的值  
        println!("x: {}", p.0);  
        // 因为变量p超出作用域，该块结束后无法访问p  
    }  
  
    // 尝试访问变量p的第二个字段(y)，这会导致编译错误  
    // 因为p变量已经在第一个作用域结束时被销毁  
    println!("y: {}", p.1);  // 编译错误：无法找到p变量  
}
```


**4)-移动语义**

转移所有权. 

```rust
fn main() {  
    let s1: String = String::from("Hello!");  
    let s2: String = s1;  
    println!("s2: {s2}");  
    // println!("s1: {s1}");  
}
```

- 值传递会导致, 上面的 `s1` 变量没有所有权了. 

函数的调用也会转移所有权.

```rust
fn say_hello(name: String) {  
    println!("Hello {name}")  
}  
  
fn main() {  
    let name = String::from("Alice");  
    say_hello(name);  
    // say_hello(name);  
}
```


- `say_hello` 函数结束的时候，会自动的释放了 为 `name` 分配的堆内存.
- 如果 把 `name` 的引用传递过去, 引用传递不会转移所有权.


```rust
fn say_hello(name: &String) {  
    println!("Hello {name}")  
}  
  
fn main() {  
    let name = String::from("Alice");  
    say_hello(&name);  
    say_hello(&name);  
}
```

- 引用传递不会释放 所有权

**5)-clone 和 Copy**

`Clone trait`:
- `Clone` 需要显示的视线 `clone` 方法
- 实现上可以是浅拷贝，也可以是深拷贝
- 会涉及到 堆的内存分配
- 适用于任何一个 需要复制的类型
- 例子:
	- 所有的 `Copy` 类型
	- `String`
	- `Vec<T>`
	- `HashMap<K,V>`
	- 大多数标准库中的集合类型


`Copy trait`:

- `Copy` 是一个标记的. `trait` , 没有要实现的方法
- 必须同时实现 `Clone`
- 适用于 简单的，固定大小的数据类型
- 在栈上进行简单的内存复制，速度快, 但是栈的大小不打，这个也都知道.
- 例子: 
	- 基本类型，`i32` `u64` `bool` `f32` `f64` 
	- 元组: 要求元组中所有字段都是 实现了 `Copy`
	- 数组: 同元组
	- 共享引用: `&T`
	

**6)-Drop trait**

在对象消耗时候的钩子函数.

```rust
struct Droppable {  
    name: &'static str,  
}  
  
impl Drop for Droppable {  
    /*  
     * 实现Drop trait，以便在对象被销毁时输出信息  
     *     * 特殊逻辑：  
     * 当对象离开作用域或被显式调用drop时，drop()方法会被调用  
     */    fn drop(&mut self) {  
        // 打印对象被销毁的信息  
        println!("Dropping {}", self.name);  
    }  
}  
  
fn main() {  
    // 创建Droppable对象a  
    let a = Droppable { name: "a" };  
    {  
        // 进入作用域B，创建Droppable对象b  
        let b = Droppable { name: "b" };  
        {  
            // 进入作用域C，创建Droppable对象c和d  
            let c = Droppable { name: "c" };  
            let d = Droppable { name: "d" };  
            println!("Exiting block C"); // 离开作用域C前输出信息  
        } // 离开作用域C，此时c和d被销毁  
  
        println!("Exiting block B"); // 离开作用域B前输出信息  
    } // 离开作用域B，此时b被销毁  
  
    drop(a); // 显式调用drop方法，销毁对象a  
    println!("Exiting main"); // 离开main函数前输出信息  
} // 离开main函数，此时a已被显式销毁，不会再调用drop
```


## 5-智能指针

**1)-struct 内存分配**

```rust
// 示例1：完全在栈上的结构体
struct Point {
    x: i32,  // 栈上
    y: i32   // 栈上
}

let p = Point { x: 1, y: 2 }; // 整个结构体都在栈上

// 示例2：部分数据在堆上的结构体
struct Person {
    name: String,     // String 内部的数据在堆上，但 String 结构体本身在栈上
    age: i32,         // 栈上
    scores: Vec<i32>  // Vec 结构体在栈上，但其管理的数据在堆上
}

// 示例3：强制将结构体放在堆上
let heap_point = Box::new(Point { x: 1, y: 2 }); // 现在 Point 被放到堆上

```

只有某些时候才需要堆. 

1. 数据大小在运行的时候才知道，例如 `Vec` `String`
2. 数据太大，不适合放到栈上
3. 需要数据比当前函数获得更久
4. 实现特定的数据结构
5. ...

```rust
fn main() {
    // 在栈上
    let point = Point { x: 1, y: 2 };
    
    // String 的结构在栈上，但字符数据在堆上
    let person = Person {
        name: String::from("Alice"),  // 堆上
        age: 30,                      // 栈上
        scores: vec![95, 87, 91]      // Vec结构在栈上，数据在堆上
    };
    
    // 强制放在堆上
    let box_point = Box::new(Point { x: 1, y: 2 });
} // 作用域结束，栈上数据自动清理，堆上数据也会被清理（因为智能指针的 Drop 特征）

```


**2)-知道数据结构大小对 rust 很重要**

有三点原因:

- 栈内存分配:  `Rust` 在编译的时候就要知道每个变量在栈上占用多少空间, 如果大小不固定就没有办法正确分配栈空间 ;
- 性能优化: 编译器 提前知道内存大小 可以更 高效的分配和管理内存 ;
- 内存安全: `Rust` 的数据安全保证 依赖于 **在编译的时候知道类型的大小**, 有助于防止内存泄漏和访问越界


**3)-Box 包装一下，可以知道具体的大小**

```rust
// 错误示例：无法计算大小
struct BadList {
    value: i32,
    next: BadList  // 编译器无法确定大小！
    // 因为：
    // BadList = 4字节 + BadList的大小
    // BadList = 4字节 + (4字节 + BadList的大小)
    // BadList = 4字节 + (4字节 + (4字节 + BadList的大小))
    // ... 无限递归
}

// 正确示例：可以计算大小
struct GoodList {
    value: i32,     // 4字节
    next: Box<GoodList>  // 8字节（64位系统上的指针大小）
    // 总大小 = 12字节（固定！）
}
```

