

## 1-Intro


> 快速的学习一下 `Es` 的 `Suggesters` 功能


- `Term Suggester` : 查找和提供的文本最接近的条目, 适合用来纠正用户输入的拼写错误 ;  
- `Phrase Suggester` : 增强了对短语的支持, 能在多个词条间进行智能纠错 ;
- `Completion Suggester` : 针对前缀补全建议, 适合用于提供输入建议 ;
- `Context Suggester` : 在 `Completion Suggester` 的基础上提供了上下文的支持 ;


> 基本的实现思路


- `Term` : 应该要根据 `Levenshtein` 距离来做, 也就是 [LeeCode编辑距离算法](https://leetcode.cn/problems/edit-distance/description/) 来判断, 这个算法是个异常简单的 动态规划，有兴趣可以自己实现一下 ;
- `Phrase` : 应该会对句子中的词，进行移动和替换，猜测要同时考虑到 词的关系 ;
- `Completion Suggester`: 猜测应该是 `Trie` 树的类似结构 ;


## 2-Term


> 非常简单的例子

```JSON
POST acm-model-20230606/_search
{
  "suggest": {
    "my-suggest-1": {
      "text": "中花大赛",
      "term": {
        "field": "kw_modelName"
      }
    }
  }
}
```

返回结果:

```json
"suggest": {
    "my-suggest-1": [
      {
        "text": "中花大赛",
        "offset": 0,
        "length": 4,
        "options": [
          {
            "text": "中华大赏",
            "score": 0.5,
            "freq": 6
          }
        ]
      }
    ]
  }
```


> 基本的原理: 不支持 `Text` 类型


1. 首先会对 `text` 进行分析, 这个和搜索，查询是一样的, `text` 被分为 `tokens` .
2. 然后 `Term Suggester` 针对 这个 `Index` 可能的所有 `Term` 进行一个计算，得到一个排序的结果.

```Python
def suggest_terms(suggest_text, index):
    # 分析 suggest_text，分解为tokens
    tokens = analyze_text(suggest_text)
    
    suggestions = {}
    # 对于每一个token
    for token in tokens:
        best_distance = float('inf')
        best_term = None
        
        # 遍历索引中的每一个词条
        for term in index:
            # 计算token与词条的编辑距离
            distance = edit_distance(token, term)
            
            # 如果编辑距离更小，则更新建议词条
            if distance < best_distance:
                best_distance = distance
                best_term = term
        # 推荐编辑距离最小的词条
        suggestions[token] = best_term
    return suggestions

```

因为是 基于 `Term` 的，我可以使用一些近似的算法去 预估一下 全部的 `term` 有多少种. 使用 近似算法可以先预估一下:  [cardinality-aggregation](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-metrics-cardinality-aggregation.html)

```JSON
GET acm-model-20230606/_search
{
  "size":0,
    "aggs" : {
        "type_count" : {
            "cardinality" : {
                "field" : "kw_modelName"
            }
        }
    }
}
```


> 基于原理我们再来看 `Options`


1. `text` : 提供了建议的基本文本。必须在全局或每个建议上设置
2. `field` : 从其中获取候选建议的字段。必须在全局或每个建议上设置
3. `analyzer` : 对基本文本进行分析的分析器
4. `sort` : 如何按照分词的金阿姨排序
	1. `score`: 该选项会先根据编辑距离计算出的相似度分数（编辑距离越小，分数越高），再根据词条在索引中的文档频率（出现的次数），然后是词条本身对建议词条排序
	2. `frequncy` : 该选项会先根据词条在索引中的文档频率，再根据编辑距离计算出的相似度分数，然后是词条本身对建议词条排序
5. `suggest_mode`: 简单理解就是 建议的 `Filter`
	▪	﻿`missing`：在这种模式下，建议器只会为输入的文本中不在索引中的分词提供建议。例如，如果你的输入文本是 "aple"，而你的索引中有词条 "apple"，那么 Term Suggester 将会返回 "apple" 作为建议词条，因为 "aple" 并不在索引中。
	▪	﻿`popular`：索引中有 "aple" 和 "apple"，其中 "apple" 在文档中出现的频率更高，那么就只会建议 "apple"，因为它比 "aple" 更常见
	▪	﻿`always`：在这种模式下，只要输入分词在索引中有匹配项，建议器就会提供建议，无论该词条在索引中的频率如何。例如，在上述情况下，Term Suggester 将返回 "aple" 和 "apple" 作为建议词条，无论它们在文档中的频率如何



## 3-Phase


> What's Phrase


- 在 `Term` 至上做了一些工作，能够纠正 的不仅仅是单词维度，而是整个 短语
- 基于 `n-gram` 算法 赋予权重，实践 中可以利用 词频 等信息，提供更准确的建议


> n-gram 实际上是一个模型

- **通过观察和学习一段文本的词序列**, 预测接下来可能出现的词 ;
- 其中 `n` 表示词序列的长度, `1-gram` 只考虑单独的词,  `2-gram` 考虑2个一起出现的 ... , 然后基于之前的 `n-1` 个去预测下一个词


> examples 比较严格

**1. 准备数据**

```json
PUT test
{
  "settings": {
    "index": {
      "number_of_shards": 1,
      "analysis": {
        "analyzer": {
          "trigram": {
            "type": "custom",
            "tokenizer": "standard",
            "filter": ["lowercase","shingle"]
          },
          "reverse": {
            "type": "custom",
            "tokenizer": "standard",
            "filter": ["lowercase","reverse"]
          }
        },
        "filter": {
          "shingle": {
            "type": "shingle",
            "min_shingle_size": 2,
            "max_shingle_size": 3
          }
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "fields": {
          "trigram": {
            "type": "text",
            "analyzer": "trigram"
          },
          "reverse": {
            "type": "text",
            "analyzer": "reverse"
          }
        }
      }
    }
  }
}
POST test/_doc?refresh=true
{"title": "noble warriors"}
POST test/_doc?refresh=true
{"title": "nobel prize"}
```

- 首先创建了 2个自定义分析器: `trigram` 和 `reverse` 的自定义分析器
	- `shingle` 过滤器是 `n-grams` 的关键, 这个例子中 `min_shingle_size = 2`, `max_shingle_size = 3`  就是 2-3 的 `n-grams`
	- `reverse` 过滤器是反转的文本, 这个分析也很有用处，比如说 前缀 能直接变为后缀  

**2. 搜索**

```json
POST test/_search
{
  "suggest": {
    "text": "noble prize",
    "simple_phrase": {
      "phrase": {
        "field": "title.trigram",
        "size": 1,
        "gram_size": 3,
        "direct_generator": [ {
          "field": "title.trigram",
          "suggest_mode": "always"
        } ],
        "highlight": {
          "pre_tag": "<em>",
          "post_tag": "</em>"
        }
      }
    }
  }
}

{
  "_shards": ...
  "hits": ...
  "timed_out": false,
  "took": 3,
  "suggest": {
    "simple_phrase" : [
      {
        "text" : "noble prize",
        "offset" : 0,
        "length" : 11,
        "options" : [ {
          "text" : "nobel prize",
          "highlighted": "<em>nobel</em> prize",
          "score" : 0.48614594
        }]
      }
    ]
  }
}
```


- 可以看到修复为 `noble prize` .
- `field`: 使用  `title.trigram` 建议 ，表示使用名为 "title" 的字段的 "trigram" 子字段，该子字段使用了 "trigram" 分析器.
- `gram_size`: `n_gram` 算法中的大小，考虑大小为 3的词组

其配置非常丰富，功能也很强大，细节见下面的官方文档.



## 4-Completion

> 他需要使用非常 昂贵的内存

- 不像之前用于 拼写校正的功能
- 因为需要跟的上用户的 实时输入速度, 所以 需要一个快速查找的数据结构，然后把这种数据结构放在内存中


```json
PUT music
{
  "mappings": {
    "properties": {
      "suggest": {
        "type": "completion"
      }
    }
  }
}
```

- 这是一种独立于 `text` 或者 `keyword` 的字段，会构建专门的 数据结构 用来做 **completion**.

 这种字段创建的时候有额外的配置, 更类似 `text`
 
- `analyzer` 和 `search_analyzer` : 分词器，建议使用简单一些的，例如 `simple` 和 `whitespace` 
- `preserve_separators`: 建议 `true`, 否则 为 `foof` 提供建议，可能会给出 `Foo Fighters` 的字段
- `preserve_position_increments`：是否启用位置增量，默认为 ﻿true。如果禁用并且使用停用词分析器，当你为 "b" 提供建议时，可能会找到以 "The Beatles" 开始的字段, 因为 `The` 可能是个停用词 ;
- `max_input_length` ：限制单个输入长度，默认为 50 个 UTF-16 字符。此限制仅在索引时使用，以减小输入字符串中的字符总数，防止过大的输入引起底层数据结构的膨胀


> 查询的功能也非常的丰富:


```json
curl -X POST "localhost:9200/music/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "_source": "suggest",     
  "suggest": {
    "song-suggest": {
      "prefix": "nir",
      "completion": {
        "field": "suggest", 
        "size": 5           
      }
    }
  }
}
'

```

- skip duplication suggestions: 跳过重复的建议
- fuzzy: 模糊
- regex: 正则


## 5-Context

`Context` 是对 `Completion` 的增强, 加入 地理信息(`GEO`) 或者 分类信息 (`CateGory`).

- 从而达到 **在不同的条件下 进行不同的 自动完成功能**

> 下面给索引增加了2个上下文信息

```json
curl -X PUT "localhost:9200/place?pretty" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "suggest": {
        "type": "completion",
        "contexts": [
          {                                 
            "name": "place_type",
            "type": "category"
          },
          {                                 
            "name": "location",
            "type": "geo",
            "precision": 4
          }
        ]
      }
    }
  }
}
'
curl -X PUT "localhost:9200/place_path_category?pretty" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "suggest": {
        "type": "completion",
        "contexts": [
          {                           
            "name": "place_type",
            "type": "category",
            "path": "cat"
          },
          {                           
            "name": "location",
            "type": "geo",
            "precision": 4,
            "path": "loc"
          }
        ]
      },
      "loc": {
        "type": "geo_point"
      }
    }
  }
}
'

```


然后增加数据的时候提供 `Context` 信息即可.

```json
curl -X PUT "localhost:9200/place/_doc/1?pretty" -H 'Content-Type: application/json' -d'
{
  "suggest": {
    "input": [ "timmy\u0027s", "starbucks", "dunkin donuts" ],
    "contexts": {
      "place_type": [ "cafe", "food" ]                    
    }
  }
}
'

curl -X PUT "localhost:9200/place_path_category/_doc/1?pretty" -H 'Content-Type: application/json' -d'
{
  "suggest": ["timmy\u0027s", "starbucks", "dunkin donuts"],
  "cat": ["cafe", "food"] 
}
'

curl -X POST "localhost:9200/place/_search?pretty&pretty" -H 'Content-Type: application/json' -d'
{
  "suggest": {
    "place_suggestion": {
      "prefix": "tim",
      "completion": {
        "field": "suggest",
        "size": 10,
        "contexts": {
          "place_type": [ "cafe", "restaurants" ]
        }
      }
    }
  }
}
'



```


## Refer

- [Search Suggesters](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-suggesters.html)
