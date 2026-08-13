# BossHelper macOS 客户端

本目录用于存放 Mac 版应用代码，与仓库根目录的浏览器插件解耦。

## 目录结构

- `BossHelperMac/`：SwiftUI 原生客户端，负责 UI、后端进程管理和 API 轮询。
- `backend/boss_helper_service/`：Python 常驻服务，同时接收插件投递数据并运行 Selenium 爬虫。
- `backend/tests/`：Python 服务测试。
- `scripts/build_backend.sh`：把 Python 后端打包为可执行 sidecar。

## 开发模式运行后端

```bash
cd backend
python3 run.py --data-dir "$HOME/Library/Application Support/BossHelper"
```

默认监听 `127.0.0.1:5005`。可用 `--port` 覆盖端口。

## 开发模式运行客户端

```bash
cd BossHelperMac
swift run BossHelperMac
```

客户端会优先使用环境变量 `BOSS_HELPER_BACKEND_PATH` 指向的 Python 脚本或打包后端；否则回退到 `../backend/run.py`。

## 打包后端

```bash
./scripts/build_backend.sh
```

产物位于 `macos/build/backend/boss-helper-backend`，可放入 App bundle 的 `Contents/MacOS/` 下作为辅助可执行文件。

## 打包完整 App

```bash
./scripts/build_app.sh
```

脚本会自动完成：

1. 编译 SwiftUI 客户端；
2. 用 PyInstaller 构建 Python 后端 sidecar；
3. 把 `boss-helper-backend` 复制进 `.app/Contents/MacOS/`。

最终产物：

```text
macos/build/BossHelperMac.app
```

这个 App 不再依赖目标机器的 Python 环境或项目源码，只需对方安装对应的浏览器插件并在 BOSS 页面登录。

## 分发到个人 Mac

当前版本未做 Apple 签名/公证，发送给其他 Mac 时建议：

```bash
cd macos/build
ditto -c -k --keepParent BossHelperMac.app BossHelperMac.zip
```

对方解压后首次打开时，右键 `BossHelperMac.app` → `打开`。若仍提示无法验证，可在对方机器执行：

```bash
xattr -cr /path/to/BossHelperMac.app
```

> 仅供个人学习与低频求职辅助使用，请遵守目标网站规则并保留限流保护。
