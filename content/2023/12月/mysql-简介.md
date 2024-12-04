

## 1-Intro


## 2-InnoDB mvcc


[MVCC](https://dev.mysql.com/doc/refman/8.0/en/innodb-multi-versioning.html) 是 `InnoDB` 的特性. `Mysql` 是面向 `Row` 的设计, 有三个隐藏字段:

• `﻿DB_TRX_ID`：这个字段保存了最后修改该行的事务ID。在处理读请求时，如果发现某行的﻿DB_TRX_ID值大于当前事务的ID，那么表示该行在当前事务开始后被修改过，那么InnoDB就需要通过﻿DB_ROLL_PTR找到对应的undo日志，获取该行在当前事务开始时的版本。
• `DB_ROLL_PTR`：这个字段是一个回滚指针（roll pointer），它指向一个undo日志记录。如果发现行记录在当前事务开始后被修改过，就需要通过这个回滚指针找到记录修改前的版本。这个字段构成了一个链表结构，可以一直回溯到更早的版本。
• `DB_ROW_ID`：该字段保存了一行记录的ID，在InnoDB为表自动创建的聚簇索引(也就是主键索引)中使用。这个字段不涉及到MVCC相关的操作


**个人理解-如何实现 RepeatAble Read:** `Mysql` 有一个递增的 事务 ID, 每次开始事务使用一个新的 `TX_ID`.

- 在查询到一行数据的时候, 会选择一个一个版本, 这个版本的 `DB_TRX_ID` 必须不超过当前的 `TX_ID`, 证明不是事务之后的修改.

- `DB_ROLL_PTR` 指向 `UNDO_LOG` 中的数据，代表修改之前，通过这个 `PREV` 指针组成了一个链表结构, 可以一直往前寻找之前的版本


因此:

- 当前事务中的修改，造成的 `DB_TRX_ID` 是可以被看到的.
- 之前的事务中的修改是看到的
- 之后的事务中的修改是看不到的


## 3-InnoDB 索引

> B+ 树索引

> 聚簇索引


**![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231227151117.png?imageSlim)


- 本质就是 叶子节点同时保留了数据，不需要回表, 如上图, 因此 [[Netflix Dblog - CDC]] 中使用 `MYSQL` 的聚簇索引去做全量 `DUMP` 也是比较高效的;
- 聚簇索引 **不是物理连续的**, 是逻辑连续的. 这里有2点: `Page` 用双向链表的形式组织的, 每个 `Page` 中的记录不同的 `ROW` 也是通过双向链表连接的 ;


> 关于字段的区分度

```sql
mysql> show index from message_message ;
+-----------------+------------+---------------+--------------+--------------+-----------+-------------+----------+--------+------+------------+---------+---------------+
| Table           | Non_unique | Key_name      | Seq_in_index | Column_name  | Collation | Cardinality | Sub_part | Packed | Null | Index_type | Comment | Index_comment |
+-----------------+------------+---------------+--------------+--------------+-----------+-------------+----------+--------+------+------------+---------+---------------+
| message_message |          0 | PRIMARY       |            1 | id           | A         |  你猜猜 |     NULL | NULL   |      | BTREE      |         |               |
| message_message |          1 | idx_photo_id  |            1 | photo_id     | A         |   你猜猜 |     NULL | NULL   | YES  | BTREE


```

- 使用 `show_index` 可以看到索引某个字段的区分度. 上面的 `你猜猜` 是编的
- `cardinality` 的统计算法很有意思:
	- 更新触发有2个条件:
		- 表中 `1/16` 的数据发生了修改
		- `stat_modified_counter > 2 000 000 000` , 这个计数器代表变化的次数
	- 随机抽取 8个叶子节点 抽样反推, 所以是一个 **预估值**



> 联合索引

- 最左前缀: 个人理解，所有走 字段 拼接算法来做 联合索引的 都有这个问题.


下面是 **个人理解**:

- 最大的好处, 是 多个字段都在索引中, 能直接在索引中做 `filter`, `sort`, `range` 这样的工作, 受到 最左前缀的约束 ;
- 其实 联合索引肯定性能不如单个索引的，因为 `key_len` 更大，意味着在 叶子节点不能存储更多的内容, 也是不一定要删除那个单个索引，如果查询的需求特别猛的话 ;


> 覆盖索引: covering index

- 这个是指 `secondary index` 的叶子上存储了 主键，所以如果 返回的字段都在索引中，可以减少一次 **回表** 
- 对 `count(*)` 的帮助, 优化器会认为 其实 `secondary index` 中也有主键信息，而 `secondary index` 可能远远比 聚集索引要小, 所以走 `secondary index` 做统计会减少 `IO` 操作, 这也是 推荐 `COUNT(**)` 而不是 `COUNT(id)` 的一个可能原因, 能更有效的利用索引, 当然要注意 `COUNT(COLUMN)`需要做一个 `NOT NULL` 的工作，所以建议字段能 `NOT NULL` 还是 `NOT NULL` ;


> INDEX HINT


有2种情况可以考虑使用 `INDEX HINT`.


1. 对某条 `SQL` 语句  `Mysql` 选择了错误的索引, 新版本的. `Mysql` 非常的少见, 优化器还是很屌的, 会基于统计信息来优化 ;
2. 对某条 `SQL` 语句，可能的索引太多了，优化器选择的开销可能超过了本身 ;


注意 `USE INDEX` 是建议, `FORCE INDEX` 才是强制, 前者只是建议，不一定生效的.

> MRR : `Multi-Range-Read` .

- 用 `explain` 的话说，有三种情况会用到, `range`, `ref`, `eq_ref` 可能用到
```sql
mysql> SELECT @@optimizer_switch;
```

- 可以看到 `mrr` 的开启状态，一般都是开了的 ;
- `mrr` 可以把 随机IO 转为顺序IO, 所以 `SSD` 上没有机械磁盘明显，但是还是更快 ;


举个例子, `key_part_1` 和 `key_part_2` 组成了联合索引

```SQL
SELECT *  FROM t WHERE key_part_1 >= 1000 AND key_part_1 < 2000 AND key_part_2 = 10000;
```

从最左前缀的角度，上面仅仅能用到 `key_part1` :
- 根据 `key_part_1` 取出来 `[1000,2000)` 的数据, 然后再回表拿 `key_part_2` `filter`

从 `MRR` 的角度的一个选择: 条件拆分为 `in` .
- `(1000, 10000)` `(1001, 10000)` ....


这个角度说明了 `Mysql` 的优化器是非常复杂的.


> ICP: Index Condition Pushdown

- 谓词下推

还是上面的例子. 可以有 第三个谓词下推的选择. 上面是说根据 `key_part_1` 取出来 `[1000,2000)` 的数据, 然后再回表拿 `key_part_2` `filter`.

其实索引中已经有了 `key_part_2`, 可以不用回表, 直接取出索引中的另外一部分数据来帮助 `filter`


个人理解，这其实是为了更 充分的利用联合索引，对最左前缀原则的补充.


> InnoDb 的 hash 引擎: 注意不是自适应 Hash, 主要是引入一下 InnoDb  的 hash 算法

- `Hash` 冲突使用的也是链表法
- 在 `InnoDB Buffer Pool` 中有专门的区域来缓存.
- 假设 `innodb_buffer_pool=10M` 如果没有开启大页，就有 `640` 个 `16KB` 的页, 就有 `> 640 x 2` 的质数也就是 `1399` 个 `slot` 的 `Hash` 表.


这个 `Hash` 表代表了一个 `Page`, 用来加速页的定位.  每个 `Page` 在 `Buffer Pool` 都会有一个 `Hash` 来加速定位.


> InnoDB 的 自适应 Hash 索引


- 使用上面的 hash 表算法实现
- 缓存的是 `SELECT * FROM TABLE WHERE index_col = 'xxx'`


是对 `B+` 树索引的补充, 必须是 索引字段才能使用. 同样存储在 `Buffer Pool` 中. 缓存的是 索引列的值-> `Page Id` , 我们知道 `Buffer Pool` 是多实例的，每个实例都有自己的 自适应 `Hash` 内存, 减少并发冲突 ;




## 4-TokuDB 索引

特点是为了 写入的场景优化了 `B+` 树的问题 引入了它的变种，叫做 `Fractal Tree` .

- `Message Buffering`: 传入的写入请求先缓存起来，然后批处理写
- 内置数据压缩

适合读少写多的场景



## 5. 锁

> 行级锁

- `InnoDB` 支持行级锁. 有2种:
	- `S` : 允许当前读取
	- `X` : 允许当前删除或者修改



上面简单的介绍了一下 `MVCC` 其实就是 事务的无锁读取.

- `READ_UNCOMMITED`: 永远去读取最新的版本
- `READ_COMMITED`: 永远读取最新的版本，如果当前的行被锁定去读取最新的快照
- `REPEATABLE_READ`: 读取 <= 当前的事务ID 的版本

一张图说明原理.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231229122739.png?imageSlim)



> 行锁有三种算法:


1. `Record Lock` : 单个记录上的锁
2. `Gap Lock` : 间隙锁, 仅仅包含了范围
3. `Next-Key`: `Gap` + `Record` ,既包含记录 又包含了 范围


基于 `Next-Key` 锁解决了 幻读的问题.

```sql
SELECT * FROM t where a > 2 FOR UPDATE;
```

- 会锁定记录和区间，这样 就会对这个 记录和区间加锁.