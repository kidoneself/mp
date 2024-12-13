#!/bin/bash

# 输出 NASPT Logo
echo "
#############################################
#                                           #
#       _   _   _ _____ _____ _____         #
#      | \ | | | |_   _|  __ \_   _|        #
#      |  \| | | | | | | |__) || |          #
#      | . \` | | | | |  _  / | |          #
#      | |\  |_| |_| |_| | \ \_| |_         #
#      |_| \_(_)_____|____| \_(_)____       #
#                                           #
#      NASPT - 你的 NAS 一站式工具平台      #
#############################################
"

# 红色文本颜色代码
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

# 确保用户输入的变量不为空，否则要求重新输入
while [ -z "$DOCKER_ROOT_PATH" ]; do
    read -p "请输入 Docker 根路径（如 /volume1/docker）： " DOCKER_ROOT_PATH
    if [ -z "$DOCKER_ROOT_PATH" ]; then
        echo -e "${RED}Docker 根路径不能为空，请重新输入。${RESET}"
    fi
done

while [ -z "$VIDEO_ROOT_PATH" ]; do
    read -p "请输入视频文件根路径（如 /volume1/media）： " VIDEO_ROOT_PATH
    if [ -z "$VIDEO_ROOT_PATH" ]; then
        echo -e "${RED}视频文件根路径不能为空，请重新输入。${RESET}"
    fi
done

while [ -z "$HOST_IP" ]; do
    read -p "请输入主机 IP 地址： " HOST_IP
    if [ -z "$HOST_IP" ]; then
        echo -e "${RED}主机 IP 地址不能为空，请重新输入。${RESET}"
    fi
done

# 用户选择镜像源
echo "请选择 Docker 镜像源（如果不想使用镜像源，请直接按 Enter）："
echo "1. docker.naspt.de"
echo "2. hub.naspt.de"
read -p "请输入数字选择镜像源（默认：1）：" image_choice

# 如果用户没有输入，则使用默认值或空值
if [ -z "$image_choice" ]; then
    DOCKER_REGISTRY=""
else
    case "$image_choice" in
        1)
            DOCKER_REGISTRY="docker.naspt.de"
            ;;
        2)
            DOCKER_REGISTRY="hub.naspt.de"
            ;;
        *)
            echo -e "${RED}无效选项，使用默认镜像源：docker.naspt.de${RESET}"
            DOCKER_REGISTRY="docker.naspt.de"
            ;;
    esac
fi

export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

echo -e "${GREEN}创建安装环境中...${RESET}"
cd ~ && mkdir -p nasmpv2 && cd nasmpv2

# 下载文件
echo "下载必要文件..."
if [ ! -f "category.yaml" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/category.yaml > category.yaml
else
    echo "category.yaml 已存在，跳过下载。"
fi

# 安装 docker-compose
if [ ! -f "./docker-compose" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/docker-compose > docker-compose
    chmod a+x docker-compose
else
    echo "docker-compose 已存在，跳过下载。"
fi

# 初始化文件夹
echo "初始化文件夹..."
mkdir -p $VIDEO_ROOT_PATH/downloads/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}} \
         $VIDEO_ROOT_PATH/links/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}}

# 单服务安装函数
install_service() {
    case $1 in
    1)
        echo "初始化 Clash"
        mkdir -p $DOCKER_ROOT_PATH/clash
        docker run -d --name clash --restart unless-stopped \
            -v $DOCKER_ROOT_PATH/clash:/root/.config/clash \
            --network host --privileged \
            $DOCKER_REGISTRY/laoyutang/clash-and-dashboard:latest
        ;;

    # 其他服务的安装代码保持不变...
    *)
        echo -e "${RED}无效选项：$1${RESET}"
        ;;
    esac
}

# 循环安装服务
while true; do
    echo "请选择要安装的服务（输入数字）："
    echo "1. Clash"
    echo "2. qBittorrent"
    echo "3. Emby"
    echo "4. MoviePilot"
    echo "5. Chinese-Sub-Finder"
    echo "6. Owjdxb"
    echo "7. 初始化数据库"
    echo "0. 退出"
    read -p "请输入选择的服务数字： " service_choice

    if [[ $service_choice -eq 0 ]]; then
        echo "安装流程结束！"
        break
    fi

    install_service $service_choice
done

echo "安装完毕！"
