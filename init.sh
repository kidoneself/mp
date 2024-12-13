#!/bin/bash

# 输出 naspt logo
echo -e "\033[1;32m
  _   _             _   _____ _____ _____  _____  ______ ______
 | \ | |  ___   ___| |_| ____|  _ \ ___||  ___||  ____|  ____|
 |  \| | / _ \ / _ \ __|  _| | |_) / _ \| |_   | |__  | |__
 | |\  || (_) | (_) | |_| |___|  __/ (_) |  _|  |  __| |  __|
 |_| \_|\___/ \___/ \__|_____|_|   \___/|_|    |_|    |_|    |_|
\033[0m"

# 必须输入的变量
read -p "请输入 Docker 根路径 (DOCKER_ROOT_PATH): " DOCKER_ROOT_PATH
read -p "请输入 视频文件存储路径 (VIDEO_ROOT_PATH): " VIDEO_ROOT_PATH
read -p "请输入 主机 IP 地址 (HOST_IP): " HOST_IP

# 确保输入不为空
if [ -z "$DOCKER_ROOT_PATH" ] || [ -z "$VIDEO_ROOT_PATH" ] || [ -z "$HOST_IP" ]; then
    echo -e "\033[1;31m错误: 必须提供所有路径信息！\033[0m"
    exit 1
fi

# 创建安装环境并进入
echo "创建安装环境..."
cd ~ && mkdir -p nasmpv2 && cd nasmpv2

# 拉取安装文件并检查是否已存在
echo "拉取安装文件..."
[ ! -f "install_bash.sh" ] && curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/install_bash.sh > install_bash.sh
[ ! -f "install.sh" ] && curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/install.sh > install.sh
chmod a+x install.sh
chmod a+x install_bash.sh

# 拉取配置
echo "拉取配置文件..."
[ ! -f ".env" ] && curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/.env > .env

# 拉取 docker-compose.yml 文件
echo "拉取容器编排文件..."
[ ! -f "./docker-compose.yml" ] && curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/docker-compose.yml > docker-compose.yml

# 安装 docker-compose
echo "安装容器编排环境..."
[ ! -f "./docker-compose" ] && curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/docker-compose > docker-compose && chmod a+x docker-compose

# 读取 .env 文件
source ./.env

# 选择要安装的服务
echo -e "\033[1;34m请选择要安装的服务:\033[0m"
echo "1. clash"
echo "2. qbittorrent"
echo "3. emby"
echo "4. moviepilot"
echo "5. chinese-sub-finder"
echo "6. wx"
echo "7. 初始化数据库"
read -p "请输入数字选择服务: " server_choice

case $server_choice in
    1)
        # 安装 clash
        echo "初始化 clash..."
        mkdir -p $DOCKER_ROOT_PATH/clash
        ./docker-compose up -d clash
        ;;
    2)
        # 安装 qbittorrent
        echo "初始化 qbittorrent..."
        mkdir -p $DOCKER_ROOT_PATH/qb-9000
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
        tar -zxvf qbittorrentbak.tgz
        cp -rf ~/nasmpv2/qbittorrent/* $DOCKER_ROOT_PATH/qb-9000/
        ./docker-compose up -d qb-9000
        ;;
    3)
        # 安装 emby
        echo "初始化 emby..."
        mkdir -p $DOCKER_ROOT_PATH/emby
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
        tar -zxvf embybak.tgz
        cp -rf ~/nasmpv2/emby/* $DOCKER_ROOT_PATH/emby/
        ./docker-compose up -d emby
        ;;
    4)
        # 安装 moviepilot
        echo "初始化 moviepilot..."
        mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/main
        mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/config
        mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/core
        ./docker-compose up -d moviepilot-v2
        ;;
    5)
        # 安装 chinese-sub-finder
        echo "初始化 chinese-sub-finder..."
        mkdir -p $DOCKER_ROOT_PATH/chinese-sub-finder
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz > chinese-sub-finder.tgz
        tar -zxvf chinese-sub-finder.tgz
        cp -rf ~/nasmpv2/chinese-sub-finder/* $DOCKER_ROOT_PATH/chinese-sub-finder/
        sed -i "s/192.168.2.100/$HOST_IP/g" `grep '192.168.2.100' -rl $DOCKER_ROOT_PATH/chinese-sub-finder`
        ./docker-compose up -d chinese-sub-finder
        ;;
    6)
        # 安装 wx
        echo "初始化 owjdxb..."
        mkdir -p $DOCKER_ROOT_PATH/store
        ./docker-compose up -d wx
        ;;
    7)
        # 初始化数据库
        echo "初始化数据库..."
        python3 - <<END
import sqlite3

# 创建数据库连接
conn = sqlite3.connect('$DOCKER_ROOT_PATH/user.db')

# 打开并读取SQL文件
with open('script.sql', 'r') as file:
    sql_script = file.read()

# 使用数据库连接执行SQL脚本
conn.executescript(sql_script)
conn.close()
END
        ;;
    *)
        echo -e "\033[1;31m无效的选择，请重新运行脚本并选择有效选项！\033[0m"
        exit 1
        ;;
esac

echo -e "\033[1;32m安装完成！\033[0m"
