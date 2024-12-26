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
        return 2
    fi
}

# 更新脚本功能
update_script() {
    echo -e "下载最新脚本并更新..."
    curl -H "Authorization: token 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" \
         -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
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

# 安装或更新脚本
if ! command -v $COMMAND_NAME &>/dev/null; then
    echo -e "脚本未安装，正在安装..."
    curl -H "Authorization: token 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" \
         -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
    if [ $? -ne 0 ]; then
        echo -e " 下载失败，请检查网络连接或 URL 是否正确。"
        exit 1
    fi

    chmod +x "$INSTALL_PATH"
    if [ $? -ne 0 ]; then
        echo -e " 添加执行权限失败。"
        exit 1
    fi

    echo -e "脚本安装成功！"
else
    # 如果已经安装，检查是否需要更新
    check_for_update
    UPDATE_STATUS=$?
    if [ $UPDATE_STATUS -eq 2 ]; then
        update_script
    fi
fi

# 最终检查脚本是否成功安装或更新
if ! command -v $COMMAND_NAME &>/dev/null; then
    echo -e "脚本安装失败，请检查安装路径或系统配置。"
    exit 1
fi