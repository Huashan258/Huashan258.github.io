# 华扇的小家

Jekyll 博客，发布到原有 GitHub Pages 仓库。保留原有角色背景、文章内容和访问地址，使用本地样式与全文搜索。

发布步骤见 **[发布说明.md](发布说明.md)**。

## 本地运行

需要 Ruby 3.2 与 Bundler。

```sh
bundle install
bundle exec jekyll serve
```

在浏览器打开 `http://127.0.0.1:4000/`。需要通过 HTTP 预览，直接双击 HTML 文件无法正常加载搜索索引。

## 继续写文章

在 `_posts/` 中添加 `YYYY-MM-DD-文章名.md`：

```yaml
---
layout: post
title: "文章标题"
date: 2026-10-06 12:00:00 +0800
categories: 食物
description: "可选，简短介绍这篇文章。"
---
```

之后正常写 Markdown。默认文章会自动进入首页、全部文章、分类与全文搜索。每次上传后要等 GitHub Actions 构建和部署完成，再刷新网站；没有手动更新搜索索引的步骤。文章日期按北京时间处理，未来时间的文章默认暂不生成，需要到时重新构建。

新主题会自动出现在分类页的“其他记录”。想把它放到首页四个分区之一，可以编辑 `_data/topics.yml` 的 `categories`。

想让某篇测试文章保留直达地址，但不出现在正式列表，在 front matter 中添加 `listed: false`；若也要从站点地图隐藏，加上 `sitemap: false`。

## 图片与公式

- 本地图片继续放在 `assets/images/`，Markdown 可以使用 `/assets/images/图片名.png`。
- `_data/image_dimensions.json` 保存现有图片的原始宽高。添加新图片时，可在这个文件加入 `"/assets/images/图片名.png": [宽, 高]`，或在 HTML 图片标签中填写 `width` 和 `height`，避免加载时正文跳动。新增图片若漏写尺寸，构建检查会提醒。
- 公式只在需要的文章中加载本地 KaTeX。旧的 CodeCogs 公式链接会在构建时自动转换，新公式可使用 `$...$` 或 `$$...$$`。
- CSS 由 `assets/css/site.css` 管理，搜索由 `assets/js/search-engine.js` 与 `site.js` 管理。
- 原背景 JPG 保留供旧链接使用，页面实际加载压缩的 WebP。

## 修改后验证

构建后，可使用 Node.js 22 与 Python 3.12 运行：

```sh
bundle exec jekyll build
node --test tests/*.test.cjs
python scripts/verify_site.py
```

GitHub Actions 会执行相同检查，然后发布。检查包括全部正式文章入索引、中文与正文搜索、公式解析、原文章地址、站内链接与锚点、图片尺寸以及 SEO。

2026-10-06 本次交付已通过：52 个页面、47 个文章地址、46 篇正式文章搜索、30 个本地公式及 7 项测试。包括当天新增的《小炒秋葵》和《蒜蓉生菜》。浏览器受环境访问限制，未实际操作手机视口；手机布局已按响应式样式调整，请用本地预览确认个人观感。
