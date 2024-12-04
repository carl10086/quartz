


## 1-Intro

> What is shortUrl


1. `shortUrl` 会被重定向到 `originUrl` ;
2. 唯一的特点就是 更短:
	1. 利于 分享, 三方微信，短信，平台一般都有字符限制 ;
	2. 印刷成本
	3. ...


例如 有个专门的网站 [tinyUrl](https://tinyurl.com/app) 为帮你自动做这件事情.


> Features: 如果我们希望这个能卖成服务，应该有哪些功能.

1. 永久保存，不过期 ;
2. 用户 可以自己选择或者定义 ? 只要不超过最大字符 ;
3. 这个服务 同样需要汇总每天的 `URL` 重定向数量和针对广告定位的分析指标等等 ;
4. 这个服务没有降级，而且应该快速 ;


> Traffic: 原文计算的时候大量使用了 8:2 开规律.


假设:

1. 100年
2. 读写比率 200:1
3. 每月 新生成1亿, 读取 200亿, 好低的量啊
4. 一条数据主要是原始的长链接 `varchar(255)` + 时间等 , 500`Bytes` 左右

这个时候:

1. 存储: `60TB` ;
2. 读取 qps: 假设按天来过期，读取 `QPS = 8000`, 那就是基本是 每天 7亿读 ;
3. 缓存 7亿的 `20%` 就需要 70GB 内存


这是简单的 演化, 不一定科学


## 2-Algorithm

> 生成 短链的思路一般有3种， 假设 7个

1. 随机尝试
2. `counter` 自增然后转 进制
3. `Hash` 算法然后重试找下一个

其中第二个做的好的基本无冲突，只要这个 `counter` 不重复.
第一个和第三个都会重复，直接要利用  数据库 去 做去重


```java
private static final int NUM_CHARS_SHORT_LINK = 7;
private static final String ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
private Random random = new Random();
public String generateRandomShortUrl() {
    char[] result = new char[NUM_CHARS_SHORT_LINK];
while (true) {
   for (int i = 0; i < NUM_CHARS_SHORT_LINK; i++) {
        int randomIndex = random.nextInt(ALPHABET.length() - 1);
        result[i] = ALPHABET.charAt(randomIndex);
    }
     String shortLink = new String(result);
      // make sure the short link isn't already used
      if (!DB.checkShortLinkExists(shortLink)) {
            return shortLink;;
        }
    }
}
```


使用一个 `counter`, 62机制不断前进.

```java
public class URLService {
    HashMap<String, Integer> ltos;
    HashMap<Integer, String> stol;
    static int COUNTER=100000000000;
    String elements;
    URLService() {
        ltos = new HashMap<String, Integer>();
        stol = new HashMap<Integer, String>();
        COUNTER = 100000000000;
        elements = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";    }
    public String longToShort(String url) {
        String shorturl = base10ToBase62(COUNTER);
        ltos.put(url, COUNTER);
        stol.put(COUNTER, url);
        COUNTER++;
        return "http://tiny.url/" + shorturl;
    }
    public String shortToLong(String url) {
        url = url.substring("http://tiny.url/".length());
        int n = base62ToBase10(url);
        return stol.get(n);
    }
    
    public int base62ToBase10(String s) {
        int n = 0;
        for (int i = 0; i < s.length(); i++) {
            n = n * 62 + convert(s.charAt(i));
        }
        return n;
        
    }
    public int convert(char c) {
        if (c >= '0' && c <= '9')
            return c - '0';
        if (c >= 'a' && c <= 'z') {
            return c - 'a' + 10;
        }
        if (c >= 'A' && c <= 'Z') {
            return c - 'A' + 36;
        }
        return -1;
    }
    public String base10ToBase62(int n) {
        StringBuilder sb = new StringBuilder();
        while (n != 0) {
            sb.insert(0, elements.charAt(n % 62));
            n /= 62;
        }
        while (sb.length() != 7) {
            sb.insert(0, '0');
        }
        return sb.toString();
    }
```



`Hash` 的可以生成1个 `128` 位或者 `32` 位的数. 利用这个信息去扣7 次出来

```java
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class MD5Utils {
    private static int SHORT_URL_CHAR_SIZE=7;
    public static String convert(String longURL) {
        try {
            // Create MD5 Hash
            MessageDigest digest = MessageDigest.getInstance("MD5");
            digest.update(longURL.getBytes());
            byte messageDigest[] = digest.digest();

            // Create Hex String
            StringBuilder hexString = new StringBuilder();
            for (byte b : messageDigest) {
                hexString.append(Integer.toHexString(0xFF & b));
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    public static String generateRandomShortUrl(String longURL) {
        String hash=MD5Utils.convert(longURL);
        int numberOfCharsInHash=hash.length();
        int counter=0;
        while(counter < numberOfCharsInHash-SHORT_URL_CHAR_SIZE){
          if(!DB.exists(hash.substring(counter, counter+SHORT_URL_CHAR_SIZE))){
                return hash.substring(counter, counter+SHORT_URL_CHAR_SIZE);
            }
            counter++;
        }
     }
}

```


> 生成的时机


这个的出发点就是时间换空间. 比如 存储1000亿个提前生成的短链需要的空间大概是 几十TB, 还好.

- 提前 生成的可以不用考虑 短链的冲突问题.
- 上面的算法都可以用来提前生成 短链


## 3-Implementation


> 假设是 Counter 的思路，而且实时生成

- 最粗暴的可以使 `snowFake`
- 也就是一个高性能的 并发计数器的选择了. `incrAndGet(steps)`
- 大多数的存储引擎应该都支持， 可以看看自己有什么
	- 例如 `Redis` , `mysql` , `postgresql` , `cassandra` , `hbase`
- 如果偏传统，需要自己实现分片的话
	- 一个简单的思路 ，按照 `counter` 来分. 假设要 `mod % 64`, `steps` 都选 `64`
		- 第一台机器 0 + 64 + ...
		- 第二台机器 1 + 64 + ..
		- ...
	- 还有的思路是:
		- 第一台 mysql 机器负责 0 -> 100000000
		- 第二台 mysql 机器负责 100000000 -> 200000000
		- ...


> 假设是 `hash` 或者 `random number` 的思路，需要快速帮助判断 数据库是否存在


从数据结构看:

1. `BloomFilter` **可能** 省内存一些, 例如 `redis`, `postGresql` 这种都支持的
2. `Hash` 更容易一些
	- 很多 `Nosql` 的分片是 一致性 `Hash`
	- `Mysql` 的主键其实也能是 一个 自适应 `Hash`

大多数数据库也都能做


> 读性能优化，也就是缓存


- 我们思考这个数据的特征
	- 拥有很强的 密集性特征
	- 拥有很强的数据不变性，基本可以认为 **永远不变**， 所以特别好 **缓存**

查询的姿势也比较单一, `shortUrl` -> `originUrl`, 然后 `302` 的需求. 

可以使用一些常见的缓存手段来优化，例如 `Redis`, 由于数据高度不变，不会对 `LSM` 的数据结构有太大 `Compaction` 压力，个人认为 `ScyllaDb` 可以充当缓存层，甚至是存储层.

What't more?

- 可以考虑直接使用 `Aws Lambda` + `Aws ElasticSearch` 加速，考虑到不同地区访问的 链接可能有 很强的 **数据密集性**

> 提前生成的问题


提前生成虽然重复率低，也有自己尴尬的问题，假设 我生成了 1000亿个，存起来，每次用一个，需要标记为用过.

大致的逻辑如下

```sql
-- 1. 查询可用的 short_url
SELECT short_url FROM  short_urls WHERE status = 0 LIMIT 1;

-- 2. 修改状态
UPDATE shorl_urls SET status = 1, origin_url = ? WHERE short_url = ? AND status = 0;
```

上面的方案基本没有 可行性:

1. 第一个语句中 `status` 毫无区分度.

有一些想法, 这里只是引用, 没有实践过，不太好评价, 但是本质都有 优化 `findNext` 的操作

1. 维护2张表(不一定是 `Mysql`), 用过和没有用过的分开，通过 **移动数据** 来实现 状态管理，**本质上是通过复杂的写操作来规避 查询的压力** , 但是如果了解 `Mysql` 的话，会发现他的删除也是逻辑删除，这种范式不一定适合 数据库引擎 
2. 维护一个其他的数据结构, 例如 计数器(不一定是 `Mysql`) , 只是用 `Mysql 举例`

```sql
begin

-- 1. 假设只有1条
SELECT counter from shorl_url_counter ;

-- 2. 基于 counter 查找下一个, 返回的 id 可以作为下一次的 start， 不用每次都更新 counter, 因为这里还有 status = 0 的判断
SELECT id, short_url FROM short_urls WHERE id > counter AND status = 0 LIMIT 1;

-- 3. 仅仅是 辅助作用

UPDATE shorl_url_counter set counter = ? ;

commit
```

- 仅仅是辅助作用，可以更细一些, 例如直接把 `Mysql` 换掉

- 这里没有实践, 但是有一些猜测，这种场景下 `TiDb` 和 `HBase` 分片方式分片 比 `Cassandra` `Hash` 分片更合适一些，可能在 落地的时候更方便去找 `FindNext` .




还有一些通用的 优化思路，例如 应用层实现 生产者-消费者，消费者每次多拿几个提前存到内存里, 都标记为已用过



> Hash 或者类似的想法多种多样


- 例如 [nano-id](https://github.com/ai/nanoid)
- 例如 [murmurHash3](https://github.com/aappleby/smhasher/blob/master/src/MurmurHash3.cpp)
- 例如 `youtube` 使用的 [hashids](https://github.com/vinkla/hashids)



## Refer

- [Scalable URL shortener service like TinyURL](https://medium.com/@sandeep4.verma/system-design-scalable-url-shortener-service-like-tinyurl-106f30f23a82)

