#!/bin/bash
# 定义变量
SCRIPT_URL="https://ghgo.xyz/https://raw.githubusercontent.com/kidoneself/mp/refs/heads/main/v2-simple.sh"
COMMAND_NAME="naspt"
INSTALL_PATH="/usr/bin/$COMMAND_NAME"

# 检查是否具有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo -e " 请以 root 或使用 sudo 运行此脚本。"
    exit 1
fi

# 卸载现有的脚本
uninstall_script() {
    echo -e "检测到 $COMMAND_NAME 已安装，正在卸载..."
    rm -f "$INSTALL_PATH"
    if [ $? -eq 0 ]; then
        echo -e "$COMMAND_NAME 卸载成功。"
    else
        echo -e "卸载 $COMMAND_NAME 失败。"
        exit 1
    fi
}

# 更新功能：检查当前版本是否为最新
check_for_update() {
    echo -e "检查脚本是否为最新版本..."

    # 临时下载最新的脚本并进行比较
    TEMP_FILE=$(mktemp)
    curl -fsSL "$SCRIPT_URL" -o "$TEMP_FILE"
    if [ $? -ne 0 ]; then
        echo -e " 下载最新脚本失败，请检查网络连接。"
        rm -f "$TEMP_FILE"
        return 1
    fi

    # 对比当前脚本与最新脚本内容是否相同
    if cmp -s "$INSTALL_PATH" "$TEMP_FILE"; then
        echo -e "脚本已是最新版本。"
        rm -f "$TEMP_FILE"
        return 0
    else
        echo -e "检测到新版本，正在更新..."
        rm -f "$TEMP_FILE"
        return 2
    fi
}

# 更新脚本功能
update_script() {
    echo -e "下载最新脚本并更新..."

    # 获取 GitHub API 返回的数据并提取下载 URL
    response=$(curl -fsSL "$SCRIPT_URL")
    download_url=$(echo "$response" | jq -r '.download_url')

    # 如果未能提取到 download_url，说明 API 返回错误
    if [ -z "$download_url" ]; then
        echo -e "无法获取下载 URL，请检查 GitHub API 返回的数据。"
        exit 1
    fi

    # 使用提取到的下载 URL 下载脚本文件
    curl -fsSL "$download_url" -o "$INSTALL_PATH"
    if [ $? -ne 0 ]; then
        echo -e " 下载失败，请检查网络连接或 URL 是否正确。"
        exit 1
    fi

    # 添加执行权限
    chmod +x "$INSTALL_PATH"
    if [ $? -ne 0 ]; then
        echo -e " 添加执行权限失败。"
        exit 1
    fi

    echo -e "脚本更新成功！"
}

# 检查是否已安装，如果已安装则卸载
if command -v $COMMAND_NAME &>/dev/null; then
    uninstall_script
fi

# 安装新脚本
echo -e "正在安装 $COMMAND_NAME..."
curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
if [ $? -ne 0 ]; then
    echo -e " 下载失败，请检查网络连接或 URL 是否正确。"
    exit 1
fi

# 添加执行权限
chmod +x "$INSTALL_PATH"
if [ $? -ne 0 ]; then
    echo -e " 添加执行权限失败。"
    exit 1
fi

echo -e "脚本安装成功！"

# 检查是否成功安装
if ! command -v $COMMAND_NAME &>/dev/null; then
    echo -e "脚本安装失败，请检查安装路径或系统配置。"
    exit 1
fi