# BOSS SPIDER 🚀 服务启动与运行指南

本文档记录了 `boss-helper` 及其 Python 后台组件与可视化看板的启动指令、运行说明及常见问题排查。

---

## 📌 服务汇总一览

| 服务模块 | 核心功能 | 运行端口 / 模式 | 推荐启动命令 |
| :--- | :--- | :--- | :--- |
| **Flask 数据后台** | 接收插件投递数据、同步 CSV/JS、提供简历接口 | `http://localhost:5005` | `cd "boss_spider_个人版本" && python3 spider/app.py` |
| **数据可视化看板** | ECharts 大屏分析（包含市场大盘 & 个人投递分析）| `http://localhost:8000` | `cd "boss_spider_个人版本/dashboard" && python3 -m http.server 8000` |
| **Selenium 爬虫引擎** | 独立自动化网页抓取 (PyMySQL 入库) | 浏览器 GUI 交互 | `cd "boss_spider_个人版本" && python3 spider/bossspider.py` |

---

## 1. 🐍 启动本地 Flask 数据后台 (`spider/app.py`)

Flask 后台用于实时接收 Chrome 扩展 `boss-helper` 发送的 `POST /api/save_job` 请求，使用全新的 21 字段精简模板（包含独立拆分的 `filter_reason` 与 `filter_detail`）进行去重处理，自动归档保存至 `jobdata/YYYY-MM/week_WW.csv`（按月文件夹、按周 CSV），并实时合并写入 `dashboard/data.js` 供看板分析。

### 方式 A：前台启动（推荐，便于查看实时日志）
```bash
cd "/Users/whiteclip/Documents/001-Project/boss-helper/boss_spider_个人版本"
python3 spider/app.py
```

### 方式 B：后台静默启动（不占用终端）
```bash
cd "/Users/whiteclip/Documents/001-Project/boss-helper/boss_spider_个人版本"
nohup python3 spider/app.py > spider_backend.log 2>&1 &
```

> **停止后台 Flask 服务**：
> ```bash
> lsof -i:5005 | awk 'NR>1 {print $2}' | xargs kill -9
> ```

---

## 2. 📊 启动数据可视化看板 (`dashboard`)

数据看板为纯前端应用，通过静态服务器运行后可读取 `data.js` 和 `resume.md`。包含全量市场极化分析与个人投递漏斗（支持按具体自定义日期范围筛选）。

### 启动命令：
```bash
cd "/Users/whiteclip/Documents/001-Project/boss-helper/boss_spider_个人版本/dashboard"
python3 -m http.server 8000
```

### 访问方式：
在浏览器中打开地址：[http://localhost:8000](http://localhost:8000)

---

## 3. 🕸️ 启动 Selenium 独立抓取脚本 (`spider/bossspider.py`)

基于 Selenium 模拟 Edge/Chrome 行为直接拉取 BOSS直聘 职位列表并写入本地 MySQL 数据库 (`spider_db`)。

### 启动命令：
```bash
cd "/Users/whiteclip/Documents/001-Project/boss-helper/boss_spider_个人版本"
python3 spider/bossspider.py
```

> **注意**：
> 1. 启动前需确保本地 MySQL 已运行并已导入 `spider/init_db.sql`。
> 2. 启动后需在弹出的浏览器窗口内 30 秒内手动完成人机滑动或扫码登录验证。

---

## 4. 🧩 Chrome 扩展 `boss-helper` 配合说明

1. 在 Chrome 浏览器打开 `chrome://extensions/`。
2. 开启右上角「开发者模式」。
3. 点击「加载已解压的扩展程序」，选择项目根目录下的 `.output/chrome-mv3` 文件夹。
4. 打开 BOSS直聘 页面，点击插件的「开始投递」，插件会将数据自动同步回 Flask 后台（5005 端口）。

---

## ❓ 常见问题排查

* **看板提示“未载入简历”**：请确认 Flask 后台已在 `5005` 端口启动，或看板服务是通过 `python3 -m http.server 8000` 访问。
* **数据没有同步进看板**：只有在 Chrome 插件中点击了「开始投递」触发岗位处理后，数据才会推送给 Flask 后台。
