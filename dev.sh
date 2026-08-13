#!/bin/bash
# 自动设置正确的 Node 路径（基于本地安装的 NVM）
export PATH="/Users/whiteclip/.nvm/versions/node/v24.14.0/bin:$PATH"

echo "正在启动 Boss Helper 浏览器插件开发服务器..."
echo "启动成功后，会自动弹出一个特殊的 Chrome 窗口，该窗口中会自动加载你的本地修改版插件。"
echo "修改本地文件，页面和插件会自动热重载。"

npm run dev
