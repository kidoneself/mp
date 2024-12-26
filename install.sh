#!/bin/bash

# 公共变量
START_TIME=$(date +%s)
CURRENT_DIR="/root/naspt"
DEFAULT_DOCKER_PATH="/vol2/1000/docker"
DEFAULT_VIDEO_PATH="/vol1/1000/media"
DOCKER_REGISTRY="docker.nastool.de"

export DOCKER_ROOT_PATH="${DOCKER_ROOT_PATH:-$DEFAULT_DOCKER_PATH}"
export VIDEO_ROOT_PATH="${VIDEO_ROOT_PATH:-$DEFAULT_VIDEO_PATH}"
export HOST_IP="${HOST_IP:-$(hostname -I | awk '{print $1}')}"
export PUID="${PUID:-$(id -u)}"
export PGID="${PGID:-$(id -g)}"

# 通用下载函数
download_file() {
    local url=$1
    local output_path=$2
    echo "正在下载 $url 到 $output_path..."
    curl -L "$url" -o "$output_path"
    if [ $? -ne 0 ] || [ ! -s "$output_path" ]; then
        echo "下载失败或文件无效：$output_path"
        exit 1
    fi
    echo "下载完成：$output_path"
}

# qBittorrent 初始化
init_qbittorrent() {
    echo "安装 qBittorrent..."
    mkdir -p "$DOCKER_ROOT_PATH/qbittorrent"
    local tgz_path="$CURRENT_DIR/naspt-qb.tgz"
    if [ ! -f "$tgz_path" ]; then
        download_file "http://43.134.58.162:1999/d/naspt/v2/naspt-qb.tgz" "$tgz_path"
    fi
    tar --strip-components=1 -zxvf "$tgz_path" -C "$DOCKER_ROOT_PATH/qbittorrent/"
    docker run -d --name qbittorrent --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/qbittorrent/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK=022 -e TZ=Asia/Shanghai \
        --network host \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}linuxserver/qbittorrent:4.6.4"
}

# Emby 初始化
init_emby() {
    echo "安装 Emby..."
    mkdir -p "$DOCKER_ROOT_PATH/emby"
    local tgz_path="$CURRENT_DIR/naspt-emby.tgz"
    if [ ! -f "$tgz_path" ]; then
        download_file "http://43.134.58.162:1999/d/naspt/v2/naspt-emby.tgz" "$tgz_path"
    fi
    tar --strip-components=1 -zxvf "$tgz_path" -C "$DOCKER_ROOT_PATH/emby/"
    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/emby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK=022 -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}amilys/embyserver:beta"
}

# MoviePilot 初始化
init_moviepilot() {
    echo "安装 MoviePilot..."
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/core"
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/config"

    local tgz_path="$CURRENT_DIR/naspt-core.tgz"
    if [ ! -f "$tgz_path" ]; then
        download_file "http://43.134.58.162:1999/d/naspt/v2/naspt-core.tgz" "$tgz_path"
    fi
    tar --strip-components=1 -zxvf "$tgz_path" -C "$DOCKER_ROOT_PATH/moviepilot-v2/core/"

    docker run -d \
        --name moviepilot-v2 --restart unless-stopped \
        -v "$VIDEO_ROOT_PATH:/media" \
        -v "$DOCKER_ROOT_PATH/moviepilot-v2/config:/config" \
        -v "$DOCKER_ROOT_PATH/moviepilot-v2/core:/moviepilot/.cache/ms-playwright" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK=022 -e TZ=Asia/Shanghai \
        --network host \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}jxxghp/moviepilot-v2:latest"
}

# Chinese-Sub-Finder 初始化
init_chinese_sub_finder() {
    echo "安装 Chinese-Sub-Finder..."
    mkdir -p "$DOCKER_ROOT_PATH/chinese-sub-finder"
    local tgz_path="$CURRENT_DIR/naspt-csf.tgz"
    if [ ! -f "$tgz_path" ]; then
        download_file "http://43.134.58.162:1999/d/naspt/v2/naspt-csf.tgz" "$tgz_path"
    fi
    tar --strip-components=1 -zxvf "$tgz_path" -C "$DOCKER_ROOT_PATH/chinese-sub-finder/"
    docker run -d --name chinese-sub-finder --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/config:/config" \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/cache:/app/cache" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK=022 -e TZ=Asia/Shanghai \
        --network host \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}allanpk716/chinesesubfinder:latest"
}

# 菜单
main_menu() {
    echo "请选择要安装的服务："
    echo "1. qBittorrent"
    echo "2. Emby"
    echo "3. MoviePilot"
    echo "4. Chinese-Sub-Finder"
    echo "0. 退出"
    read -p "请输入选项：" choice
    case "$choice" in
        1) init_qbittorrent ;;
        2) init_emby ;;
        3) init_moviepilot ;;
        4) init_chinese_sub_finder ;;
        0) echo "退出"; exit 0 ;;
        *) echo "无效选项";;
    esac
}

# 循环显示菜单
while true; do
    main_menu
done