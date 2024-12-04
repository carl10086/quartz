

## 1-Intro


全称: Hierarchical nearest small world

作为用来做 `ANN` 的一种近似结构.

> 什么是 ANN


`Deep Learning` 算到的结果需要用一个特殊的东西存储起来, 最合适的就是 支持 `Filterable ANN` 的矢量引擎;

- `ANN` 的 `A` : **近似? 为什么要近似**
    - 高维的计算成本太高: 称为 "**维度诅咒**";
    - 牺牲精度 追求成本优化 就是 `A` ;


> 什么是 HNSW ?


1. 功能上 是用来做 `ann` 矢量的近似搜索算法;
2. 实现上 是 `NSW`: 小世界图算法;
3. + 额 个 **Hierarchical: 就是 + 了个****跳表****, 由 linear ->** **log** **的优化;**


## 2-Theory


> small world 理论


- 哪怕把这个数据集扩大到 **全世界. 你的社交圈和任何一个陌生人的社交圈 只需要 5.5 个人中转下;**
- 这个算法非常的适合 **大规模数据集 高维数据集合** , 因为哪怕数据量很大，我也可以很快找到2个节点之间的连线，从而计算他们的距离长度;

> nsw 图构建和搜索是2个独立的过程，虽然参数名称相同，作用类似

> nsw 图构建


1. 先构造一个空的，可以随便选择一个 数据点作为 `Start`, 也可以后面逐渐增加
2. 插入节点 `x`:
	1. 从 `NSW` 随机一个节点开始，找到 `x` 最近的节点 ;
	2. 计算 `x` 和 已有节点的距离 从而选择 `ef_construct` 个节点作为候选集, 所以这个值增加了 构建的开销 ;
	3. 通过 策略把 `x` 和这些节点连接，策略可以是距离大小，连接数量,  选择 `m` 个节点, 所以 :
		1. `m` 越大，不一定约精确，但是存储的东西一定增多
		2.  必须 `m <= ef_construct`


3. 优化: 构建的时候会优化，提高搜索效率
4. 重复 2和3 ，所有节点插入到 图中


> `nfw` 图构建的过程中解决了3个主要问题


1. 信息孤岛: 任何节点都必然有 `m` 个 邻居 ;
2. `neighbors` 之间的距离是最近的 ;
3. 每个 `node` 旁边都是 `m` 个左右，意味着 生产上是内存可控的 ;


> nfw 构建完.


![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231207015051.png?imageSlim)


- 红色的是 高速公路， 本质是 **指连接相对较远距离的数据点**
- 绿色的是 局部连接
  

1. 开始的时候， `nodes` 数量比较少， 这个时候 搜不到那么近的， 更容易构建 **远一点的;**
2. `M` 越大, 注意到这个 超参数， 是我们唯一控制 全局连接的概率, 越大， **全局连接的概率越高,** 也是 **官方算法说 高 dim 的 collection 更适合 大一点的 M ;**
3. 随机算法, 就是构建时候的第3步， 优化， 留 `M` 的时候增加一些 随机性, 这个 **我们无法****控制****，暂时无法介入 ;**


> 先看如何使用这个 `NSW` 图, 高层上看，相邻的都是最近的节点, 用来快速筛选候选集

  
1. **选择一个起始节点**：从 NSW 图中选择一个起始节点，可以是随机选择的，也可以是基于某种策略的。将该节点作为当前节点
2. **计算距离**：计算当前节点与查询点之间的距离。此外，维护一个变量以存储目前找到的距离最近的节点（初始时为起始节点）及其距离
3. **遍历邻居**: 遍历当前节点的所有邻居，计算邻居节点与查询点之间的距离。
    1. 如果找到一个距离比目前找到的最近节点还要近的邻居节点，将其设置为新的最近节点, 然后跳回2
    2. 如果当前节点的所有邻居都比已找到的最近节点距离要远，那么搜索过程结束
4. **结果**：搜索结束后，最后找到的最近节点即为查询点的近似最近邻节点


- 同样有一个参数 `ef` 控制候选集的大小, 搜索具有 **随机性**
- 一个参数 `k` : `topK`
- `ef >= k` : 必须满足, `ef` 一样是效率和精度的取舍


> HNSW

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20231207112146.png?imageSlim)


1. 上面的高层空间非常稀疏， 构建的时候随机上去， 他们互相距离相对远
2. - 从上跳到下， 最后一层保存全量


  

> HNSW 算法的主要思想是将数据点按照一定规则分层，并在不同层次之间建立连接。
> 
> 这种分层结构使得搜索过程可以从高层次（相当于高速公路）快速跳跃到目标点附近的低层次区域，然后在低层次区域进行精确搜索。
> 
> 这种从高层到低层的搜索策略大大提高了搜索效率，降低了计算成本

  
1. 加速搜索：通过在高层次建立连接，使得搜索过程可以更快地从一个区域跳跃到另一个区域，从而加速最近邻搜索。
2. 降低计算复杂度：高层次的连接相当于快速通道，避免了在低层次区域进行大量的距离计算。这样可以降低整体的计算成本。
3. 适应性：`HNSW` 算法可以根据数据集的规模和密度自适应地调整层次结构，从而在不同数据集上实现较好的搜索性能。


## 3-In Practice


> 2个参数. `m` 和 `ef` , `ef` 代表候选集.

先看 **m**:

1. 这个值大 **可能** 的作用: 更精确一些，全局连接也会更多，维度高可能要提升一下，然后就是这个值变大，存储一定会变大 ;
2. 合理的值大概是 `2->100` ;
3. 这个值决定了 **memory consumption , 真正的占****内存****会更大;** 

下面是 `m`  的一些例子:

- 如果 `dim=4` 那么 `M near 6` 是合理的值
- 如果是为了 `word embedding` `image vector` 这种高纬度, `M = 48 - 64` 是不错的值
- `m` 的修改往往伴随着 `ef`, 一开始可以简单搞个常数


再看 `ef_construction`: the parameter is the size of dynamic list for nearest neighbors (use during in the construction)


1. 用来控制 `index_time / index_accuracy` ;
2. 值越大,  `index_time_add` 和 `index_accuracy_add`, 官方的原话是: **At some point, increasing ef_construction does not improve the quality of the index**
3. 这个值建议是, `ef=ef_construction`, 然后检查 `recall`, 如果 `< 0.9`, 那证明这个值要调整 


> 参数测试代码

```Python
import hnswlib
import numpy as np

dim = 32
num_elements = 100000
k = 10
nun_queries = 10

# Generating sample data
data = np.float32(np.random.random((num_elements, dim)))

# Declaring index
hnsw_index = hnswlib.Index(space='l2', dim=dim)  # possible options are l2, cosine or ip
bf_index = hnswlib.BFIndex(space='l2', dim=dim)

# Initing both hnsw and brute force indices
# max_elements - the maximum number of elements (capacity). Will throw an exception if exceeded
# during insertion of an element.
# The capacity can be increased by saving/loading the index, see below.
#
# hnsw construction params:
# ef_construction - controls index search speed/build speed tradeoff
#
# M - is tightly connected with internal dimensionality of the data. Strongly affects the memory consumption (~M)
# Higher M leads to higher accuracy/run_time at fixed ef/efConstruction

hnsw_index.init_index(max_elements=num_elements, ef_construction=200, M=16)
bf_index.init_index(max_elements=num_elements)

# Controlling the recall for hnsw by setting ef:
# higher ef leads to better accuracy, but slower search
hnsw_index.set_ef(200)

# Set number of threads used during batch search/construction in hnsw
# By default using all available cores
hnsw_index.set_num_threads(1)

print("Adding batch of %d elements" % (len(data)))
hnsw_index.add_items(data)
bf_index.add_items(data)

print("Indices built")

# Generating query data
query_data = np.float32(np.random.random((nun_queries, dim)))

# Query the elements and measure recall:
labels_hnsw, distances_hnsw = hnsw_index.knn_query(query_data, k)
labels_bf, distances_bf = bf_index.knn_query(query_data, k)

# Measure recall
correct = 0
for i in range(nun_queries):
    for label in labels_hnsw[i]:
        for correct_label in labels_bf[i]:
            if label == correct_label:
                correct += 1
                break

print("recall is :", float(correct)/(k*nun_queries))
```


- 把数据集合换成真实的 效果好;
- 比如说要优化一个 `dim=512`
    - 先固定 `M=20`
        - 测试 `ef_construction = ef` = (50, 60, 70 ....) , 判断 `recall`
    - 如果不达标 `M -> 30 -> 40 -> 50`


> 一个 demo 配置， 使用的是 `qdrant`

```Python
client.recreate_collection(
    collection_name="atlas_clip1024",
    vectors_config=models.VectorParams(size=1024, distance=models.Distance.DOT),
    # vector storage on mmap
    optimizers_config=models.OptimizersConfigDiff(memmap_threshold=20000),
    # hnsw index on mmap
    hnsw_config=models.HnswConfigDiff(on_disk=True, m=32),
    quantization_config=models.ScalarQuantization(
        scalar=models.ScalarQuantizationConfig(
            type=models.ScalarType.INT8,
            always_ram=True,
        ),
    ),
    # init_from=models.InitFrom(
    #     collection="atlas_test"
    # ),
    timeout=1000000
)
```

### Refer

- 论文: [https://arxiv.org/abs/1603.09320](https://arxiv.org/abs/1603.09320)
- 源码: [https://github.com/nmslib/hnswlib](https://github.com/nmslib/hnswlib)
- 原理: [https://zhuanlan.zhihu.com/p/441470968](https://zhuanlan.zhihu.com/p/441470968)
- 产品:
    - `Elasticsearch 8.x`
    - `Facebook fassy`
    - `Minvs`
    - `Qdrant`
    - `PgVector`
    - ...

