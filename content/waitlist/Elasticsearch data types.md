

## 1-Intro


> 通过 Es 的数据类型 可以知道他们现在的功能大致卷到什么程度.


- `keyword`, `long` 默认会启动 [doc_values](https://www.elastic.co/guide/en/elasticsearch/reference/current/doc-values.html#doc-value-only-fields), 这是一种在磁盘上的 列存, 主要用来聚合, 排序, 效率会更高, 也可以用来做 `Filter` ;
- `index=true` 则是 表示是否开启 倒排索引, 用的是 `MMAP` ;
- [fielddata](https://www.elastic.co/guide/en/elasticsearch/reference/current/text.html#fielddata-mapping-param) 是一个在 内存中的数据结构, 用于 `text` 类型的 聚合和排序, 建议不要开 ;
- ... ;


## 2-Details

> Aggregate metric field type


- [Aggregate metric field](https://www.elastic.co/guide/en/elasticsearch/reference/current/aggregate-metric-double.html) : 类似 `Clickhouse` 的 预聚合函数, 通过对某个 `numberic` 的字段进行提前的聚合操作

```json
curl -X PUT "localhost:9200/my-index?pretty" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "my-agg-metric-field": {
        "type": "aggregate_metric_double",
        "metrics": [ "min", "max", "sum", "value_count" ],
        "default_metric": "max"
      }
    }
  }
}
'

```

> Array

- [Array](https://www.elastic.co/guide/en/elasticsearch/reference/current/array.html): Es 本身是没有数组类型, 是平铺的. 数组中的所有元素必须是相同的类型

举个例子:

- an array of strings: [ `"one"`, `"two"` ] ;
- an array of integers: [ `1`, `2` ] ;
- an array of arrays: [ `1`, [ `2`, `3` ]] which is the equivalent of [ `1`, `2`, `3` ] ;
- an array of objects: [ `{ "name": "Mary", "age": 12 }`, `{ "name": "John", "age": 10 }`] ;


> Binary

- 这个字段