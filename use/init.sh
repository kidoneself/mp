#!/bin/bash

# 捕获 Ctrl+C 信号并处理
trap 'echo -e "\n检测到 Ctrl+C，使用选项 q 退出程序。" && continue' SIGINT

while true; do
    echo "================================"
    echo "请选择要安装的脚本："
    echo "1) 安装家庭影院"
    echo "2) 安装家庭影院(微信交互)"
    echo "3) 安装音乐服务"
    echo "4) 安装工具类"
    echo "b) 返回上一层"
    echo "q) 退出"
    echo "================================"
    read -p "请输入你的选择：" choice

    case $choice in
        1)
            echo "正在安装 安装家庭影院.sh..."
            bash <(curl -Ls https://naspt.oss-cn-shanghai.aliyuncs.com/MoviePilot/MoviePilot.sh)
            ;;
        2)
            echo "正在安装 安装家庭影院(微信交互)"
            bash <(curl -Ls https://naspt.oss-cn-shanghai.aliyuncs.com/MoviePilot/MoviePilotwx.sh)
            ;;
        3)
            echo "正在安装 音乐服务"
            bash <(curl -Ls https://naspt.oss-cn-shanghai.aliyuncs.com/music/music.sh)
            ;;
        4)
            echo "正在安装 工具类"
            bash <(curl -Ls https://naspt.oss-cn-shanghai.aliyuncs.com/tool/tool.sh)
            ;;
        b)
            echo "返回上一层。"
            ;;
        q)
            echo "退出程序。"
            exit 0
            ;;
        *)
            echo "无效选择，请重试。"
            ;;
    esac
done