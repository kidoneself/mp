#!/bin/bash

# 定义变量
SCRIPT_URL="https://raw.githubusercontent.com/kidoneself/mp/refs/heads/main/v2-simple.sh"
COMMAND_NAME="naspt"
INSTALL_PATH="/usr/bin/$COMMAND_NAME"

# 检查是否具有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[31m[ERROR]\033[0m 请以 root 或使用 sudo 运行此脚本。"
    exit 1
fi

# 下载脚本
echo -e "\033[34m[INFO]\033[0m 正在从 $SCRIPT_URL 下载脚本..."
curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
if [ $? -ne 0 ]; then
    echo -e "\033[31m[ERROR]\033[0m 下载失败，请检查网络连接或 URL 是否正确。"
    exit 1
fi

# 添加执行权限
echo -e "\033[34m[INFO]\033[0m 添加执行权限到 $INSTALL_PATH..."
chmod +x "$INSTALL_PATH"
if [ $? -ne 0 ]; then
    echo -e "\033[31m[ERROR]\033[0m 添加执行权限失败。"
    exit 1
fi

# 检查是否成功安装
if command -v $COMMAND_NAME &>/dev/null; then
    echo -e "\033[32m[SUCCESS]\033[0m 脚本已成功安装为系统命令：$COMMAND_NAME"
    echo "你现在可以直接运行 \033[33m$COMMAND_NAME\033[0m 来执行脚本。"
else
    echo -e "\033[31m[ERROR]\033[0m 脚本安装失败，请检查安装路径或系统配置。"
    exit 1
fi
