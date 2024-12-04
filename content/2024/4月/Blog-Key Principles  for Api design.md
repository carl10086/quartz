
#blog


[Origin Blog](https://twitter.com/NikkiSiapno/status/1771830828508881176)


一篇关于 `API` 设计的文章, 例子用的是 `REST API` 设计.


> Resource Naming:  `http` 针对的 `resources`, *Clarity* 简单说明需要的资源就行

清晰性是关键。采用简单的资源名称，如使用/users来访问用户信息和/posts来获取用户帖子，可以简化开发流程并减少思维负担


> 使用 名词，而且是复数

> Cross-referencing resources


使用路径的顺序去表达 资源之间的 引用顺序，*这样好像只能表达简单的 引用关系，父子关系*


> Security

使用 `X-AUTH-TOKEN` 和 `X-SIGNATURE` 这样的身份验证方法


> Pagination

- 放到 `URI` 中吗?


> 𝗜𝗱𝗲𝗺𝗽𝗼𝘁𝗲𝗻𝗰𝘆

- 幂等性, 在 `API` 的表层直接能看出来这个 `API` 是支持幂等的, 还是不支持幂等的



> 个人总结


- 都是 `API` 设计中的老生常谈，没有说清楚 *方差*, 也就是 落地的一些取舍
- 原文中是用 `RESTFUL API DESIGN` 作为例子.

![](https://imgs-1322738462.cos.ap-shanghai.myqcloud.com/20240403131641.png?imageSlim)


- 一般企业中的 `API` 有三种套路, 都应该 要想办法去满足上面的条件
	- 全部 `POST`
	- `RESTFUL`
	- `GRAPHQL`

