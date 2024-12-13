#!/bin/bash

# 输出 NASPT Logo
echo "
#############################################
#                                           #
#       _   _   _ _____ _____ _____         #
#      | \ | | | |_   _|  __ \_   _|        #
#      |  \| | | | | | | |__) || |          #
#      | . \` | | | | | |  _  / | |          #
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

# 设置默认路径
DOCKER_ROOT_PATH="${DOCKER_ROOT_PATH:-/volume1/docker}"
VIDEO_ROOT_PATH="${VIDEO_ROOT_PATH:-/volume1/media}"

# 输出路径设置
echo -e "${GREEN}Docker 根路径: $DOCKER_ROOT_PATH${RESET}"
echo -e "${GREEN}视频文件根路径: $VIDEO_ROOT_PATH${RESET}"

# 获取本机IP地址，兼容 Linux、macOS 和 Windows
get_ip() {
    local ip
    # 使用 Python 获取 IP 地址，兼容不同操作系统
    ip=$(python3 -c "import socket; print(socket.gethostbyname(socket.gethostname()))")
    
    if [ -z "$ip" ]; then
        echo "无法自动获取IP地址，请输入IP地址："
        read -p "请输入主机 IP 地址: " ip
    fi
    echo "$ip"
}

# 获取主机IP
HOST_IP=$(get_ip)

# 用户选择镜像源
echo "请选择 Docker 镜像源："
echo "1. docker.naspt.de"
echo "2. hub.naspt.de"
echo "3. 不使用镜像加速（有梯子）"
read -p "请输入数字选择镜像源（默认：1）：" image_choice

# 设置镜像源和加速设置
DOCKER_REGISTRY="docker.naspt.de/"
if [[ "$image_choice" == "2" ]]; then
    DOCKER_REGISTRY="hub.naspt.de/"
elif [[ "$image_choice" == "3" ]]; then
    echo -e "${GREEN}选择了不使用加速（有梯子），将使用默认 Docker 镜像源${RESET}"
    unset DOCKER_REGISTRY  # 如果选择不使用加速，则取消加速变量
fi

export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

# 显示环境变量
echo -e "${GREEN}当前环境变量：${RESET}"
echo -e "${GREEN}DOCKER_ROOT_PATH: $DOCKER_ROOT_PATH${RESET}"
echo -e "${GREEN}VIDEO_ROOT_PATH: $VIDEO_ROOT_PATH${RESET}"
echo -e "${GREEN}HOST_IP: $HOST_IP${RESET}"
echo -e "${GREEN}DOCKER_REGISTRY: ${DOCKER_REGISTRY:-默认 Docker 镜像源}${RESET}"

echo -e "${GREEN}创建安装环境中...${RESET}"
cd ~ && mkdir -p nasmpv2 && cd nasmpv2

# 初始化文件夹
echo "初始化文件夹..."
mkdir -p "$VIDEO_ROOT_PATH/downloads/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}}" \
         "$VIDEO_ROOT_PATH/links/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}}"

# 单服务安装函数
install_service() {
    local service_id=$1
    case $service_id in
        1) init_clash ;;
        2) init_qbittorrent ;;
        3) init_emby ;;
        4) init_moviepilot ;;
        5) init_chinese_sub_finder ;;
        6) init_owjdxb ;;
        7) init_database ;;
        *)
            echo -e "${RED}无效选项：$service_id${RESET}"
        ;;
    esac
}

# 初始化各个服务
init_clash() {
    echo "初始化 Clash"
    echo "执行命令: mkdir -p $DOCKER_ROOT_PATH/clash"
    mkdir -p "$DOCKER_ROOT_PATH/clash"
    echo "执行命令: docker run -d --name clash --restart unless-stopped -v $DOCKER_ROOT_PATH/clash:/root/.config/clash --network host --privileged $DOCKER_REGISTRY/laoyutang/clash-and-dashboard:latest"
    docker run -d --name clash --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/clash:/root/.config/clash" \
        --network host --privileged \
        "$DOCKER_REGISTRY/laoyutang/clash-and-dashboard:latest"
}

init_qbittorrent() {
    echo "初始化 qBittorrent"
    echo "执行命令: mkdir -p $DOCKER_ROOT_PATH/qb-9000"
    mkdir -p "$DOCKER_ROOT_PATH/qb-9000"
    echo "执行命令: curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz"
    curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
    echo "执行命令: tar -zxvf qbittorrentbak.tgz -C $DOCKER_ROOT_PATH/qb-9000/"
    tar -zxvf qbittorrentbak.tgz -C "$DOCKER_ROOT_PATH/qb-9000/"
    echo "执行命令: rm -f qbittorrentbak.tgz"
    rm -f qbittorrentbak.tgz
    echo "执行命令: docker run -d --name qb-9000 --restart unless-stopped -v $DOCKER_ROOT_PATH/qb-9000/config:/config -v $VIDEO_ROOT_PATH:/media -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai -e WEBUI_PORT=9000 -e SavePatch=/media/downloads -e TempPatch=/media/downloads --network host --privileged $DOCKER_REGISTRY/linuxserver/qbittorrent:4.6.4"
    docker run -d --name qb-9000 --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/qb-9000/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=9000 \
        -e SavePatch=/media/downloads -e TempPatch=/media/downloads \
        --network host --privileged \
        "$DOCKER_REGISTRY/linuxserver/qbittorrent:4.6.4"
}

init_emby() {
    echo "初始化 Emby"
    echo "执行命令: mkdir -p $DOCKER_ROOT_PATH/emby"
    mkdir -p "$DOCKER_ROOT_PATH/emby"
    echo "执行命令: curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz"
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
    echo "执行命令: tar -zxvf embybak.tgz -C $DOCKER_ROOT_PATH/emby/"
    tar -zxvf embybak.tgz -C "$DOCKER_ROOT_PATH/emby/"
    echo "执行命令: rm -f embybak.tgz"
    rm -f embybak.tgz
    echo "执行命令: docker run -d --name emby --restart unless-stopped -v $DOCKER_ROOT_PATH/emby/config:/config -v $VIDEO_ROOT_PATH:/media -e UID=0 -e GID=0 -e GIDLIST=0 -e TZ=Asia/Shanghai --device /dev/dri:/dev/dri --network host --privileged $DOCKER_REGISTRY/amilys/embyserver:beta"
    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/emby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e UID=0 -e GID=0 -e GIDLIST=0 -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host --privileged \
        "$DOCKER_REGISTRY/amilys/embyserver:beta"
}

init_moviepilot() {
    echo "初始化 MoviePilot"
    echo "执行命令: mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/{main,config,core}"
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/{main,config,core}"
    echo "执行命令: cp config.py $DOCKER_ROOT_PATH/moviepilot-v2/config/"
    cp config.py "$DOCKER_ROOT_PATH/moviepilot-v2/config/"
    echo "执行命令: docker run -d --name moviepilot --restart unless-stopped -v $DOCKER_ROOT_PATH/moviepilot-v2:/moviepilot-v2 --network host --privileged $DOCKER_REGISTRY/username/moviepilot:v1"
    docker run -d --name moviepilot --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/moviepilot-v2:/moviepilot-v2" \
        --network host --privileged \
        "$DOCKER_REGISTRY/username/moviepilot:v1"
}

# 调用安装服务
install_service 1
install_service 2
install_service 3
install_service 4
