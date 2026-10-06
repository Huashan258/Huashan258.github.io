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

分类总览只显示分类入口；点击后进入独立目录，文章按发表时间从早到晚排列。添加文章时会自动更新目录，无须手工创建分类页面。首页和“全部文章”仍按最新文章优先排列。

想让某篇测试文章保留直达地址，但不出现在正式列表，在 front matter 中添加 `listed: false`；若也要从站点地图隐藏，加上 `sitemap: false`。

## 自定义头像和分类封面

把头像放到 `assets/images/avatar.jpg`，然后修改 `_config.yml`：

```yaml
avatar: "/assets/images/avatar.jpg"
```

头像显示在左侧“华扇”旁，建议使用正方形图片。支持 JPG、PNG、WebP、SVG、GIF、AVIF，路径以 `/assets/images/` 开头。`avatar: ""` 保留原来的“扇”字，文件不存在时也使用原来的样式。

分类封面在 `_data/categories.yml` 设置，例如：

```yaml
胶粘剂:
  image: "/assets/images/covers/adhesives.webp"
  description: "从胶粘剂基础到木材工业中的应用。"
```

把设计好的图片放到对应目录即可；可自行新建 `assets/images/covers/`。封面按 8:5 裁切，建议使用 1600×1000 或同等比例图片。`image: ""` 保留文字卡片，`description` 可以省略。这里只影响分类卡片和分类简介，不修改文章的分类名称。新增分类即使没写进这个配置文件，也会自动显示默认卡片。

头像和封面自带固定展示尺寸，不需要另填 `_data/image_dimensions.json`。修改配置后重新构建或发布，预览网页才会更新。

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
bundle exec ruby tests/categories.test.rb
node --test tests/*.test.cjs
python scripts/verify_site.py
```

GitHub Actions 会执行相同检查，然后发布。检查包括全部正式文章入索引、中文与正文搜索、公式解析、原文章地址、站内链接与锚点、图片尺寸、SEO、分类目录顺序、自定义图片与缺图回退。

2026-10-06 本次以已发布的 `main` 提交 `6b71a72` 为基础，在本地分支 `avatar-category-update` 完成修改，包含新增的《酸菜鱼》。已通过 65 个页面、48 个原文章地址、47 篇正式文章搜索、12 个分类目录、30 个本地公式、8 项 Node 测试及 Ruby 图片和分类检查。没有修改文章正文或原文章网址，也没有推送、发布。浏览器受环境访问限制，未实际操作修改后的页面或手机视口，请用附带的本地预览确认个人观感。

# 本地运行

在文件夹中输入bundle exec jekyll build

然后把生成的 source/_site/ 内部文件和preview.py放在同一级再运行