

## Refer

- [原文](https://www.elastic.co/blog/understanding-ai-search-algorithms?ultron=insights%2Bai_seo&blade=twitter&hulk=social&utm_content=12719417639&linkId=333764643)
- 文章来自 `ElasticSearch` 官方团队
- 后续简称 Ai Search algorithm 为 ASA



## 1-Intro



> 什么是 ASA


 A method for understanding nlp queries and find relevant results by evaluating indexed data and docs.


> ASA 的基本要素

文章中的原始内容如下:

1. States: a snapshot of the problem at a particular point in time
2. Actions: possible transitions between the states
3. Goal: the ultimate objective of the search process
4. Path costs: the trade-off between precision and recall for each step or action in the path toward answering the query


假设我们正在处理一个文本执行任务，目标是根据所给问题从一个大型文本数据库中找出最相关的答案。这个问题可以转化为状态，行动，目标和路径成本的格式。

• **状态**：在这个案例中，状态可以理解为当前问题的信息和已经从文本数据库检索的信息。
• **行动**：行动是该算法可能执行的步骤，例如，搜索不同的关键词，查找特定主题的文本，或者基于某种模式匹配策略进行匹配等。
• **目标**：目标在此处就是找到最满足当前问题的答案。对于NLP作业，它可以是提供一个清晰、准确的回答，或者找到一个最相关的文档或引用。
• **路径成本**：在寻找答案的过程中，每一步可能需要花费一些时间或计算资源。路径成本就是指这样的代价。例如，搜索一大批文件可能花费更多的时间，而搜索一个小型数据库则会快很多。算法需要基于这个路径成本来决定是否要执行某一行动。


> 按照实际场景对 算法进行 类型的分类.


**自然语言处理（NLP）算法：** 使用聊天机器人的例子，NLP算法扮演了至关重要的角色，使得聊天机器人可以理解我们问的问题并给出相关应答。

**词嵌入：** 在用户评价分析中，我们可以利用词嵌入如Word2Vec和GloVe识别文本中的情感，对产品或服务进行情感打分。

**语言模型：** 当我们在Google搜索栏键入一半的句子，Google会预测我们接下来可能要输入的内容。这就是BERT等语言模型的实际应用，预测词序。

**k-最近邻（kNN）：** 当我们在购物网站浏览商品时，网站会给我们推荐类似商品。这背后就是kNN在起作用，根据我们浏览的商品（新数据点），找到其他与其相似的商品（最近邻）。

**近似最近邻（ANN）：** ANN在音频识别中表现良好，即使声音并不完全一致，ANN仍能通过查找接近的匹配结果完成任务。

**无信息（盲目）搜索算法：** 盲目搜索算法如宽度优先搜索（BFS）或深度优先搜索（DFS）等被广泛用于路由查找等任务，它们只依赖搜索空间的结构寻找解决方案。

**启发式搜索算法：** 当我们使用导航软件寻找到达目的地的最佳路线时，这就是启发式搜索算法如 A* 搜索的应用。这类算法会使用一些额外的信息（如交通情况）来指导搜索，为我们找到最佳 路径。


> 例子.


- [**Informational retrieval**](https://www.elastic.co/what-is/information-retrieval)**:** NLP search algorithms can enhance search results by understanding the context and tone of a query to retrieve more useful information.
    
- **Recommendations:** kNN algorithms are often used to recommend products, movies, or music based on their preferences and past behavior.
    
- **Speech recognition:** ANN algorithms are commonly used to recognize patterns in speech. This is useful in things like speech-to-text and language identification.
    
- **Medical diagnosis:** AI search algorithms can help with speeding up medical diagnosis. For example, they can be trained on massive data sets of medical images and use image recognition to detect anomalies from photos, X-rays, CT scans, etc.
    
- **Pathfinding:** Uninformed search algorithms can help find the shortest path between two points on a map or network. For example, determining the shortest delivery route for a driver.


> 考虑点 Or Limitations


**人工智能搜索算法的挑战和局限性：**

**1. 计算复杂性：** 考虑我们正在使用一款在线翻译工具，这款工具使用了复杂的AI搜索算法来确保准确度。对大段文本的翻译可能需要大量的处理、计算和内存资源，这使得翻译过程可能变得相当缓慢，尤其是当硬件资源有限的时候。

**2. 启发式准确性：** 假如你正在使用一款公交路线规划软件，如果该软件的启发式搜索算法使用了不准确的交通信息（例如因为数据过时或者误报），则可能提供一个并不是最快的路线。这是因为算法的性能受限于其使用的启发式函数的精度。

**3. 问题范围限制：** AI搜索算法通常被设计去解决特定类型的问题，譬如寻路问题和约束满足问题。这对特定任务非常有用，但在解决更多元、更复杂的问题时可能面临限制。例如，如果我们尝试让一个主要用于路径规划的AI搜索算法去处理一个涉及协同过滤的推荐系统问题，可能会碰到很大的困难，因为此类问题的复杂性和性质可能超越了它的设计原则和范围。

