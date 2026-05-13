---
title: "2026 阅读仪表盘"
draft: true
---

> 本地浏览用。`draft: true` 让 Quartz 跳过此文件，不会发布。

## 📚 按主题（场景 A）

```dataview
TABLE WITHOUT ID rows.file.link AS "文章", length(rows) AS "篇数"
FROM "carl-blogs/2026"
WHERE file.name != "00_📰_dashboard"
FLATTEN tags AS topic
GROUP BY topic
SORT length(rows) DESC
```

## 🕐 时间线最近 30 篇（场景 B）

```dataview
TABLE WITHOUT ID file.link AS "文章", date AS "日期", join(tags, ", ") AS "主题"
FROM "carl-blogs/2026"
WHERE file.name != "00_📰_dashboard"
SORT date DESC, file.name DESC
LIMIT 30
```
