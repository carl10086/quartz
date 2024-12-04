

## 1-Intro

这里列一些 常见的数据结构 和 实现.

每个数据结构分为 `Abstract` 和 `Implementation`. 举个例子, 优先队列其实是个抽象，你可以用 有序数组，双向链表或者 堆这个中具体 的数据结构来实现 .


> 这里的所有内容来自下面的 github 和对应的书


- [AlgorithmsAndDataStructuresInAction](https://github.com/mlarocca/AlgorithmsAndDataStructuresInAction)

## 2-Basic data strutures

### 2-1 Priority Queue


> Binary Heap: 最小堆和最大堆

完全二叉树, 一般用数组实现.

1. 每个节点最多有2个子节点
2. 堆树是 完全二叉树 而且是 左对齐的
	- 如果堆的高度为 `H`, 那么每个叶子节点要不在 `H` 要不是 `H-1`
	- 左对齐, 意味着没有右子树 大于其左边的兄弟
3. 根是最大的


基本所有的语言都自带, 例如 `Java` 的 `java.util.PriorityQueue` ;



> D-Array Heap


基于 堆可以扩展为多路堆, 每个节点不一定只有一棵子树. D 代表每个节点带点最大子节点数目.

- 他们都是相对有序，仅仅要求 父节点一定比子节点大一些(或者小一些)
- 如果 `d=1`, 那么 就是一个有序的数组了


> 典型场景1 -TopK

- 最小堆求 `topK`

> 典型场景2 - Dijkstra 最短路径

- 最短路径算法 `Dijkstra` 的性能往往 取决于其中 优先级队列的实现方式

> 典型场景3 - `Prim` 计算无向连通图 `G` 的 `MST` 最小生成树算法

- 同上

> 典型场景4 -  `Huffman` 压缩算法. 

- 同上, 这个算法太老了. 同样也需要部分有序


> 核心问题: 如何选择 `d-array` 中 `d` 的大小


- 增加 `d` 的时候, 插入会变快，但是会影响删除和修改操作.
- 一个测试表明 `4` 是一个比较好的妥协

通过数学公式的证明:

1. 插入和删除在 `[2,5]` 区间内达到最佳平衡
2. 3元堆 理论上比 二元堆要快
3. 4元堆 和 3元堆性能类似
4. 5元堆会慢一些

但是真正还是要看数据的分布, 常见中, 二元往往不是最快，5元更少最快，一般是 3或者 4, **出于实现简单的话，二元其实就可以了** 


### 2-2 Treaps

> Using randomization to balance binary search trees.






