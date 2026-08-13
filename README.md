# BOSS Helper Personal Workspace

> 本项目仅供个人学习与技术交流使用，请勿用于商业用途或进行高频恶意抓取。使用自动化脚本可能带来账号风控风险，请自行承担。

本仓库是个人工作区，整合了以下内容：

- Chrome 浏览器插件
- Python 本地数据后台
- macOS 客户端
- Selenium 职位爬虫
- ECharts 数据可视化看板

## 项目来源说明

### Chrome 插件

Chrome 插件部分来源于开源项目：

<https://github.com/Ocyss/boss-helper>

用于 BOSS 直聘页面的简历批量投递、筛选和自动打招呼。插件源码位于仓库根目录的 `src/`，技术栈为 WXT + Vue 3 + Element Plus。

### 其他部分

以下内容是个人独立整理和维护的：

- Python 本地数据后台：`macos/backend/`
- macOS 客户端：`macos/BossHelperMac/`
- Selenium 爬虫：`boss_spider_个人版本/spider/`
- 数据可视化看板：`boss_spider_个人版本/dashboard/`

## 目录结构

```text
.
├── src/                      # Chrome 插件源码
├── macos/
│   ├── BossHelperMac/        # SwiftUI macOS 客户端
│   ├── backend/              # Python 数据后台
│   └── scripts/              # 打包脚本
├── boss_spider_个人版本/
│   ├── spider/               # Selenium 爬虫
│   ├── dashboard/            # ECharts 数据看板
│   └── requirements.txt
└── README.md
```

## 快速开始

### 1. Chrome 插件

```bash
pnpm install
pnpm run build
```

构建产物位于：

```text
.output/chrome-mv3
```

在 Chrome 的 `chrome://extensions/` 中开启开发者模式，加载该目录即可。

### 2. Python 本地数据后台

```bash
cd macos/backend
python3 run.py
```

默认监听：

```text
http://127.0.0.1:5005
```

### 3. macOS 客户端

开发运行：

```bash
cd macos/BossHelperMac
swift run BossHelperMac
```

打包完整 App：

```bash
./macos/scripts/build_app.sh
```

产物：

```text
macos/build/BossHelperMac.app
```

### 4. Selenium 爬虫

```bash
cd boss_spider_个人版本
python3 spider/bossspider.py
```

爬虫会将结构化职位数据写入本地 MySQL。

### 5. 数据可视化看板

```bash
cd boss_spider_个人版本/dashboard
python3 -m http.server 8000
```

访问：

```text
http://localhost:8000
```

## 免责声明

本项目仅用于学习 BOSS 直聘页面交互、浏览器插件开发、Python 后端、macOS 客户端和数据可视化。请遵守目标网站的使用条款，控制访问频率，不要用于任何商业或违规用途。
