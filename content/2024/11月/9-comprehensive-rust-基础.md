

## refer

- [what-is-rust](https://google.github.io/comprehensive-rust/zh-CN/hello-world/what-is-rust.html)

## 1. 介绍

`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

**1)-特点**

1. 定位和 `C++` 类似 ;
2. `rustc` 使用 `LLVM` 作为后端 ;
3. **编译时** 的内存安全机制 ;
4. 一些现代语言 ，例如 `JAVA` 的体验
5. 多范式语言, **面相对象范式** 和 **面相函数范式** 都做的不错

..


## 2-类型, 控制流 ...

```rust
fn main () {
	println!("Hello !");
}
```

- `RUST` 的宏是 **卫生的**, 不会意外的捕获到 它们所在的作用域的标志符, *实际上是部分卫生的* 


```rust
fn main () {
	let x: i32 = 10;
	println!("x: {x}");
	// x = 20;
	// println("x: {x}");
}
```


- 默认都是不可变的, 需要 `mut` 代表可变
- 也能做类型推导, 也就是不用显示的去声明 变量的类型


**1)-2种 循环控制， 也就是 `for` 和 `loop`**

```rust
fn main() {
    for x in 1..5 {
        println!("x: {x}");
    }

    for elem in [1, 2, 3, 4, 5] {
        println!("elem: {elem}");
    }
}
```

```rust
fn main() {
    let mut i = 0;
    loop {
        i += 1;
        println!("{i}");
        if i > 100 {
            break;
        }
    }
}
```

**2)-代码块和作用域**

```rust
fn main () {
	let z = 13;
	let x = {
		let y = 10;
		println!("y: {y}");
		z - y
	}
	println("x : {x}");
}
```

1. 每个作用域 `block` 都是一个 `{}` , 每个 `block` 都有 `value` 和 `type`, 它都是由 *last expression* 决定的.

比较有趣的是 变量遮蔽.

```rust
fn main() {
    let a = 10;
    println!("before: {a}");
    {
        let a = "hello";
        println!("inner scope: {a}");

        let a = true;
        println!("shadowed in inner scope: {a}");
    }

    println!("after: {a}");
}
```


在作用域中反复用了 `let` 关键字，这代表后面的 `a` 都是新的变量. 


**3)-函数**

```rust
fn gcd(a: u32, b: u32) -> u32 {
    if b > 0 {
        gcd(b, a % b)
    } else {
        a
    }
}

fn main() {
    println!("gcd: {}", gcd(143, 52));
}
```


1. `overloading` is not supported - each function has a single implementation ;
2. 一直使用固定数量的参数, 不支持默认的参数, 宏可以用来支持可变的参数 ;


**4)-宏**

宏就是编译的语法糖, 在编译的时候扩展为 `Rust` 代码, **并且接受可变数量的参数** , 标准库有很多这样的东西:

1. `println!(format, ...)` 
2. `format!(format, ..)` 的用法和 `println!` 类似, 以字符串的形式返回结果 ;
3. `dgb!(expression)` 会记录表达式的值并返回该值 ;
4. `todo!()` 用来标记尚未实现的代码段, 如果执行这个代码段, 则会触发 `panic` ;
5. `unreachable!()` 用来标记无法访问的代码段, 如果执行这个代码段, 则会触发 `panic` ;

**5)-数组**

```rust
fn main () {
	let mut a: [i8; 10] = [42; 10];
	a[5] = 0;
	println!("a: {a:?}");
}
```


1. 定义了数组， 初始化 .长度10 都是 42 

**6)-元组**

```rust
fn main() {  
    let t: (i8, bool) = (1, false);  
  
    println!("t.0: {}", t.0);  
    println!("t.1: {}", t.1);  
}
```

- 上面这种写法也可以称为 **解构**, 把 内部的值分配给 2个变量.


## 3-引用, 自定义类型

**1)-共享|只读 引用**

```rust
fn main() {  
    let a = 'A';  
    let b = 'B';  
  
    let mut r: &char = &a;  
    println!("r:{}", *r);  
  
    r = &b;  
    println!("r:{}", *r);  
}
```

- 常见的引用, 这里称为 **借用** ;
- 只读状态: 没有办法通过引用去修改对象的属性 ;

**2)-悬垂引用**

```rust
fn x_axis(x: i32) -> &(i32, i32) {    // 试图返回对局部变量的引用
    let point = (x, 0);               // point 是局部变量
    return &point;                    // 错误：返回了将要被销毁的变量的引用
}                                     // point 在这里被销毁
```

- 编译的时候会 禁止掉 指向已经被释放或者销毁的内存的引用 ;


**3)-可变引用 | 独占引用**

```rust
fn main () {
	let mut point = (1, 2);  
	let x_coord = &mut point.0;  
	*x_coord = 3;
}
```

**4)-slice- 数组的引用**

```rust
fn main() {  
    let mut a: [i32; 6] = [10, 20, 30, 40, 50, 60];  
    println!("a: {a:?}");  
  
    a[3] = -1;  
    let s: &[i32] = &a[2..4];  
    println!("s: {s:?}");  
}
```

**5)-字符串**

```rust
fn main() {  
    let s1: &str = "World";  
    println!("s1, {}!", s1);  
  
    let mut s2 = String::from("Hello ");  
    s2.push_str(s1);  
    println!("s2, {}", s2);  
  
    let s3: &str = &s2[s2.len() - s1.len()..];  
    println!("s3, {}", s3);  
}
```

- 后面的切分 `..` 用来分割 `start` 和 `end`

**6)-结构体也基本一样**

```rust
struct Person {  
    name: String,  
    age: u8,  
}  
  
fn desc(person: &Person) {  
    println!("name: {}, age: {}", person.name, person.age)  
}  
  
fn main() {  
    let mut peter = Person { name: String::from("carl"), age: 10 };  
    desc(&peter);  
  
    peter.age = peter.age + 1;  
    desc(&peter);  
}
```


**7)-元组结构体=不 care 字段名称的结构体**


```rust
struct Point(i32, i32);
struct PoundsOfForce(f64);
struct Newtons(f64);
```


**8)-枚举**

```rust
#[derive(Debug)]  
enum Direction {  
    Left,  
    Right,  
}  
  
#[derive(Debug)]  
enum PlayerMove {  
    Pass,  
    Run(Direction),  
    Teleport { x: u32, y: u32 },  
}  
  
fn main() {  
    let m: PlayerMove = PlayerMove::Run(Direction::Left);  
    println!("On this turn:{:?}", m);  
}
```


1. `#[derive(Debug)]` 是 `rust` 中的属性宏， 允许通过 {:?} 的方式打印出其中的子属性 ;
2. `enum` 允许各种变体的 类型 ;

**9)-static**

静态变量 `static` :

1. 必须在编译的时候初始化 
2. 有固定的内存地址
3. 整个程序运行期都存在
4. 必须实现 `Sync` `trait`

和 `const` 的区别:

1. `const` 会被内联到使用处(也就是在编译的时候被替换), 可以在任何的作用域声明
2. `static` 只能在全局的作用域声明, 有固定的内存地址


```rust
static BANNER: &str = "Welcome to RustOS 3.14";  
  
/*1. 定义摘要大小为3*/  
const DIGEST_SIZE: usize = 3;  
  
/*2.定义一个 Option 类型的常量, 值为 Some(42)*/const ZERO: Option<u8> = Some(42);  
fn compute_digest(text: &str) -> [u8; DIGEST_SIZE] {  
    // 1. 创建固定大小的数组， 初始值为 42 | 0    
    let mut digest = [ZERO.unwrap_or(0); DIGEST_SIZE];  
  
    // 2. 遍历文本的字节  
    for (idx, &b) in text.as_bytes().iter().enumerate() {  
        // 使用取模运算来更新摘要数组  
        digest[idx % DIGEST_SIZE] = digest[idx % DIGEST_SIZE].wrapping_add(b);  
    }  

    digest  
}  
  
fn main() {  
    println!("{BANNER}");  
    let digest_text = compute_digest("Hello");  
    println!("digest: {digest_text:?}");  
}
```

**10)-类型别名**

```rust
enum CarryableConcreteItem {
    Left,
    Right,
}

type Item = CarryableConcreteItem;

// Aliases are more useful with long, complex types:
use std::cell::RefCell;
use std::sync::{Arc, RwLock};
type PlayerInventory = RwLock<Vec<Arc<RefCell<Item>>>>;
```

- 类型别名为另一种类型创建名称, 这2种类型可以互换使用


**11)-模式匹配**

`match` 关键字让你可以将一个值与一个或者多个模式进行匹配, 比较是从上到下进行的, 第一个匹配成功的会被采用. 

类似 `kotlin` 中的 `when` ..

```rust
#[rustfmt::skip]  
fn main() {  
    let input = 'x';  
    match input {  
	    // 1. 精确匹配模式
        'q'                       => println!("Quitting"),  
        // 2. | 匹配多个值
        'a' | 's' | 'w' | 'd'     => println!("Moving around"),  
        // 3. 使用范围匹配
        '0'..='9'                 => println!("Number input"),  
        // 4. 模式绑定 + 守卫条件
        key if key.is_lowercase() => println!("Lowercase: {key}"),  
		// 5. 通配符
        _                         => println!("Something else"),  
    }  
}
```


**12)-解构**

解构 + 模式匹配感觉有点提升理解的复杂度了. 

```rust
struct Foo {
    x: (u32, u32),
    y: u32,
}

#[rustfmt::skip]
fn main() {
    let foo = Foo { x: (1, 2), y: 2 };

    match  foo{
        // 模式1: 解构  x 元组的第一个元素必须是 1
        Foo {x:(1, b), y} => println!("x.0 = 1, b = {b}, y = {y}"),
        // 模式2: y 必须是 2
        Foo {y: 2, x:i} => println!("y = 2, x = {i:?}"),
        // 模式3:  捕获 y， 其他的 一概不 care
        Foo {y, ..} => println!("y = {y}, other fields were ignored " ),
    }
}
```


## 4-方法 ， 特征， 泛型

**1)-方法 就是 函数 + `impl | receiver` 的概念.**

```rust
#[derive(Debug)]  
struct Race { // 让结构体可以使用 {:?} 打印调试信息  
    name: String,  
    laps: Vec<i32>,  
}  
  
impl Race {  
    // 1. 静态方法（构造函数）  
    fn new(name: &str) -> Self {  
        Self { name: String::from(name), laps: Vec::new() }  
    }  
  
  
    // 2. 可变的引用方法 &mut self    fn add_lap(&mut self, lap: i32) {  
        self.laps.push(lap);  
    }  
  
    // 3. 不可变引用方法 &self    fn print_laps(&self) {  
        println!("Recorded {} laps for {}:", self.laps.len(), &self.name);  
        for (idx, lap) in self.laps.iter().enumerate() {  
            println!("Lap {idx}, {lap} sec")  
        }  
    }  
  
    // 4. 所有权转移方法  
    fn finish(self) {  
        let total: i32 = self.laps.iter().sum();  
        println!("Race {} is finished, total lap time: {}", self.name, total)  
    }  
}  
  
fn main() {  
    let mut race = Race::new("Monaco Grand Prix");  
    race.add_lap(70);  
    race.add_lap(68);  
    race.print_laps();  
    race.add_lap(71);  
    race.print_laps();  
    race.finish();  
}
```

1. 通过 `Impl` 实现了方法的 接收者
2. `&mut self` , `&self` 不一样
3. 构造器一般是静态方法
4. `finish` 方法之后， `race` 这个对象就会被销毁, 

**2)-trait 抽象出了特征, 也就是方法**

```rust
trait Pet {  
    fn talk(&self) -> String;  
    fn greet(&self) {  
        println!("Oh you're a cutie! What's your name? {}", self.talk())  
    }  
}  
struct Dog {  
    name: String,  
    age: i8,  
}  
  
impl Pet for Dog {  
    fn talk(&self) -> String {  
        /*没有; 代表返回值?*/  
        format!("Woof, my name is {}, my age is {}!", self.name, self.age)  
    }  
}  
  
fn main() {  
    let fido = Dog { name: String::from("Fido"), age: 5 };  
    fido.greet();  
}
```


- 类似接口，抽象类，独特的写法
- 没有 `;` 代表是一个作为 `return` 的 `expression`
- 一个 `struct` 可以实现多个 `trait`


**3)-associated types** 

是一个占位符类型，根据实现决定真正的类型是什么!

```rust
#[derive(Debug)]  
struct Meters(i32);  
#[derive(Debug)]  
struct MetersSquared(i32);  
  
trait Multiply {  
    type Output;  
    fn multiply(&self, other: &Self) -> Self::Output;  
}  
  
impl Multiply for Meters {  
    type Output = MetersSquared;  
    fn multiply(&self, other: &Self) -> Self::Output {  
        MetersSquared(self.0 * other.0)  
    }  
}  
  
fn main() {  
    println!("{:?}", Meters(10).multiply(&Meters(20)));  
}
```



实现类中定义了 , `Output` 的类型是 `MetersSquared`

**4)-派生特征**

可以通过宏 来实现所谓的派生功能, 例如:

- `debug` 可以打印出具体的属性
- `clone` : 可以实现 clone 对象
- `default` : 可以为结构体提供默认值
- `serde`: 可以为结构体提供 序列化的支持

```rust
#[derive(Debug, Clone, Default)]  
struct Player {  
    name: String,  
    strength: u8,  
    hit_points: u8,  
}  
  
fn main() {  
    let p1 = Player::default();  
    let mut p2 = p1.clone();  
  
    p2.name = String::from("EldurScrollz");  
    // Debug trait adds support for printing with `{:?}`.  
    println!("{:?} vs . {:?}", p1, p2)  
}
```


**5)-泛型函数**

`rust` 的泛型是 所谓的 零成本抽象. 在编译的时候自动生成如下的代码， 这个过程被称为 "单态化", 也就是 `Monomorphization` ,下面用一个例子说明为什么是零成本


```rust
fn pick<T>(n: i32, even: T, odd: T) -> T {  
    if n % 2 == 0 {  
        even  
    } else {  
        odd  
    }  
}  
fn main() {  
    println!("picked a number: {:?}", pick(92, 222, 333));  
    println!("picked a tuple: {:?}", pick(28, ("dog", 1), ("cat", 2)));  
}
```


编译器会自动生成代码:

```rust
// 编译器自动生成这些具体类型的函数
fn pick_i32(n: i32, even: i32, odd: i32) -> i32 {
    if n % 2 == 0 { even } else { odd }
}

fn pick_str(n: i32, even: &str, odd: &str) -> &str {
    if n % 2 == 0 { even } else { odd }
}

fn pick_f64(n: i32, even: f64, odd: f64) -> f64 {
    if n % 2 == 0 { even } else { odd }
}

fn main() {
    let a = pick_i32(1, 10, 20);
    let b = pick_str(2, "hello", "world");
    let c = pick_f64(3, 1.0, 2.0);
}
```


**6)-泛型类型**

```rust
#[derive(Debug)]  
struct Point<T> {  
    x: T,  
    y: T,  
}  
  
impl<T> Point<T> {  
    fn coords(&self) -> (&T, &T) {  
        (&self.x, &self.y)  
    }  
  
    fn set_x(&mut self, x: T) {  
        self.x = x;  
    }  
}  
  
  
fn main() {  
    let integer = Point { x: 5, y: 10 };  
    let float = Point { x: 1.0, y: 4.0 };  
    println!("{integer:?} and {float:?}");  
    println!("coords: {:?}", integer.coords());  
}
```


> [!NOTE] Tips
> 为什么 `T` 在 `impl<T> Point<T>`  指定了2次? 有点绕
> - 因为它是泛型类型的实现部分，前者声明是一个泛型实现，后者指定了为哪个类型实现
> - 也就意味着你可以写一个 `impl Point<u32>` , 但是确是用 `Point<f64>`, 但是这里的方法必须用 兼容 `Point<u32>` 的方法


**7)-泛型 trait**

泛型也可以用在接口上.

```rust
#[derive(Debug)]  
struct Foo(String);  
  
impl From<u32> for Foo {  
    fn from(value: u32) -> Self {  
        Foo(format!("Converted from integer {}", value))  
    }  
}  
  
  
impl From<bool> for Foo {  
    fn from(value: bool) -> Self {  
        Foo(format!("Converted from bool {}", value))  
    }  
}  
  
fn main() {  
    let from_int = Foo::from(123);  
    let from_bool = Foo::from(true);  
  
    println!("from_int: {:?}", from_int);  
    println!("from_bool: {:?}", from_bool);  
}
```


- `Some(xxx)` || `Yet(yyy)` ;
