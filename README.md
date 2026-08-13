# Personal Automation Workspace

> 本仓库仅用于个人学习与技术交流，请勿用于任何商业用途。

这是一个个人自动化工具与数据可视化工作区，整合了浏览器插件、本地后端服务、macOS 客户端、自动化脚本和可视化看板。

## 项目组成

- 浏览器插件：提供页面交互与自动化能力。
- 本地后端服务：负责接收和保存插件推送的数据。
- macOS 客户端：用于管理本地服务、查看运行状态和统计数据。
- 自动化脚本：提供可复用的本地任务处理能力。
- 可视化看板：用于查看本地数据的汇总结果。

## 目录结构

```text
.
├── src/                      # 浏览器插件源码
├── macos/
│   ├── BossHelperMac/        # macOS 客户端
│   ├── backend/              # 本地后端服务
│   └── scripts/              # 打包脚本
├── legacy_tools/             # 个人整理的自动化与可视化资源
└── README.md
```

## 快速开始

### 浏览器插件

```bash
pnpm install
pnpm run build
```

构建产物位于 `.output/chrome-mv3`，在浏览器扩展管理页加载该目录即可。

### 本地后端服务

```bash
cd macos/backend
python3 run.py
```

默认监听：

```text
http://127.0.0.1:5005
```

### macOS 客户端

开发运行：

```bash
cd macos/BossHelperMac
swift run BossHelperMac
```

打包完整应用：

```bash
./macos/scripts/build_app.sh
```

产物：

```text
macos/build/BossHelperMac.app
```

## 免责声明

本项目仅用于学习浏览器插件、本地服务、macOS 客户端和数据可视化等技术的整合与使用。请遵守相关平台和服务的使用条款。
