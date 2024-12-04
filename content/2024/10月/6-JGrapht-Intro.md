


## refer

- [Hello-world](https://jgrapht.org/guide/UserOverview#development-setup)
- [github](https://github.com/jgrapht/jgrapht)


**其他的项目:**

- [taskflow](https://github.com/ytyht226/taskflow/tree/master): 一个编排的框架. 可以参考一下思路研发, 不建议直接使用
- [flowable-engine](https://www.flowable.com/getting-started-open-source): 企业级的一个编排框架 .


## 1-Intro


**1)-What ?**

1. `Java` 库，同时支持 `Python-Binding` 的方式使用
2. 包含了 `Graph` 相关的数据结构和对应的算法


**2)-Features?**

1. Flexible:
	1. 泛型安全
	2. 支持图的各种特性
2. Powerfule
	1. 支持各种 `bfs`, `dfs` 算法
	2. 支持 `JGraphX` 的可视化
3. Efficient
	1. 基于 fastutil 的优化, 也就是说接近于 基础类型的性能





**3)-Hello world**

```java
import org.jgrapht.*;
import org.jgrapht.graph.*;
import org.jgrapht.nio.*;
import org.jgrapht.nio.dot.*;
import org.jgrapht.traverse.*;

import java.io.*;
import java.net.*;
import java.util.*;

        Graph<URI, DefaultEdge> g = new DefaultDirectedGraph<>(DefaultEdge.class);

        URI google = new URI("http://www.google.com");
        URI wikipedia = new URI("http://www.wikipedia.org");
        URI jgrapht = new URI("http://www.jgrapht.org");

        // add the vertices
        g.addVertex(google);
        g.addVertex(wikipedia);
        g.addVertex(jgrapht);

        // add edges to create linking structure
        g.addEdge(jgrapht, wikipedia);
        g.addEdge(google, jgrapht);
        g.addEdge(google, wikipedia);
        g.addEdge(wikipedia, google);
```



- 一般对 `Vertex` 和 `Edge` 的要求是实现 `Equals/Hashcode` 方法，参考 [VertexAndEdge](https://jgrapht.org/guide/VertexAndEdgeTypes)



## 2-Graph Structures


| Class Name                     | Edges      | Self-loops | Multiple edges | Weighted |
| ------------------------------ | ---------- | ---------- | -------------- | -------- |
| SimpleGraph                    | undirected | no         | no             | no       |
| Multigraph                     | undirected | no         | yes            | no       |
| Pseudograph                    | undirected | yes        | yes            | no       |
| DefaultUndirectedGraph         | undirected | yes        | no             | no       |
| SimpleWeightedGraph            | undirected | no         | no             | yes      |
| WeightedMultigraph             | undirected | no         | yes            | yes      |
| WeightedPseudograph            | undirected | yes        | yes            | yes      |
| DefaultUndirectedWeightedGraph | undirected | yes        | no             | yes      |
| SimpleDirectedGraph            | directed   | no         | no             | no       |
| DirectedMultigraph             | directed   | no         | yes            | no       |
| DirectedPseudograph            | directed   | yes        | yes            | no       |
| DefaultDirectedGraph           | directed   | yes        | no             | no       |
| SimpleDirectedWeightedGraph    | directed   | no         | no             | yes      |
| DirectedWeightedMultigraph     | directed   | no         | yes            | yes      |
| DirectedWeightedPseudograph    | directed   | yes        | yes            | yes      |
| DefaultDirectedWeightedGraph   | directed   | yes        | no             | yes      |



解释一下:

- `undirected` 和 `directed` 就是有向和无向的意思
- `self-loops` : 是否允许自循环，就是 `vertex` 顶点是否允许连接到自己
- `multiple-edges`: 是否允许有多条边



**1)-支持 builder 模式构建**


```java
    private static Graph<Integer, DefaultEdge> buildKiteGraph() {
        return new GraphBuilder<>(buildEmptySimpleGraph())
            .addEdgeChain(1, 2, 3, 4, 1).addEdge(2, 4).addEdge(3, 5).buildAsUnmodifiable();
    }
```


**2)-支持 modification listener**

- 监听 图的数据结构变化


**3)-Concurrency**

- 默认都是 非 `Thread-Safe` 的 . 
- 需要多线程并发修改 图数据结构，可以考虑使用 [AsSync...](https://jgrapht.org/javadoc/org.jgrapht.core/org/jgrapht/graph/concurrent/AsSynchronizedGraph.html)



**4)-Wrapper**

- `Union`: 2个 `Graph` 合并
- `SubGraph`: `SubGraph` 的能力
- `AsUndirectedGraph`
- `AsUnmodifiedGraph`
- `AsUnweightedGraph`
- `AsWeightedGraph`
- `EdgeReversedGraph`
- ...
