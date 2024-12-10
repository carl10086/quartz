

## 1-QuickStart

```
# 1. 安装 核心库
pnpm add @vue-flow/core

# 2. 安装 dagre 库 用来做自动的 layout
pnpm install dagre
```

*确保样式不会有太大问题*

```javascript
/* these are necessary styles for vue flow */
@import '@vue-flow/core/dist/style.css';

/* this contains the default theme, these are optional styles */
@import '@vue-flow/core/dist/theme-default.css';
```

In Vue flow, a graph consists of `nodes` and `edges` 

Each node or edge requires a unique id .
Nodes also need a XY-position, while edges require a source and a target node id.  

## refer

- [vueflow examples](https://vueflow.dev/examples/)
