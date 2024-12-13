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

# 获取本机IP地址，优先使用内网IP
get_ip() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
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
echo "1. docker.naspt.de/"
echo "2. hub.naspt.de/"
echo "3. 不使用镜像加速（有梯子）"
read -p "请输入数字选择镜像源（默认：1）：" image_choice

# 设置镜像源和加速设置
DOCKER_REGISTRY="docker.naspt.de"
if [[ "$image_choice" == "2" ]]; then
    DOCKER_REGISTRY="hub.naspt.de"
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
    mkdir -p "$DOCKER_ROOT_PATHclash"
    docker run -d --name clash --restart unless-stopped \
        -v "$DOCKER_ROOT_PATHclash:/root/.config/clash" \
        --network host --privileged \
        "$DOCKER_REGISTRY/laoyutang/clash-and-dashboard:latest"
}

init_qbittorrent() {
    echo "初始化 qBittorrent"
    mkdir -p "$DOCKER_ROOT_PATHqb-9000"
    curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
    tar -zxvf qbittorrentbak.tgz -C "$DOCKER_ROOT_PATHqb-9000/"
    rm -f qbittorrentbak.tgz
    docker run -d --name qb-9000 --restart unless-stopped \
        -v "$DOCKER_ROOT_PATHqb-9000/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=9000 \
        -e SavePatch=/media/downloads -e TempPatch=/media/downloads \
        --network host --privileged \
        "$DOCKER_REGISTRY/linuxserver/qbittorrent:4.6.4"
}

init_emby() {
    echo "初始化 Emby"
    mkdir -p "$DOCKER_ROOT_PATHemby"
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
    tar -zxvf embybak.tgz -C "$DOCKER_ROOT_PATHemby/"
    rm -f embybak.tgz
    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATHemby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e UID=0 -e GID=0 -e GIDLIST=0 -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host --privileged \
        "$DOCKER_REGISTRY/amilys/embyserver:beta"
}

init_moviepilot() {
    echo "初始化 MoviePilot"
    mkdir -p "$DOCKER_ROOT_PATHmoviepilot-v2/{main,config,core}"
    cp config.py "$DOCKER_ROOT_PATHmoviepilot-v2/config/"
    cp category.yaml "$DOCKER_ROOT_PATHmoviepilot-v2/config/"
    sed -i "s/119.3.173.6/$HOST_IP/g" "$DOCKER_ROOT_PATHmoviepilot-v2/config/config.py"
    docker run -d --name moviepilot-v2 --restart unless-stopped \
        -v "$VIDEO_ROOT_PATH:/media" \
        -v "$DOCKER_ROOT_PATHmoviepilot-v2/config:/config" \
        -v "$DOCKER_ROOT_PATHmoviepilot-v2/core:/moviepilot/.cache/ms-playwright" \
        -e NGINX_PORT=3000 -e PORT=3001 \
        -e PUID=0 -e PGID=0 -e UMASK=000 -e TZ=Asia/Shanghai \
        -e AUTH_SITE=iyuu -e IYUU_SIGN=IYUU49479T2263e404ce3e261473472d88f75a55d3d44faad1 \
        -e SUPERUSER=root -e API_TOKEN=nasptnasptnasptnaspt \
        --network host --privileged \
        stdin_open=true --tty=true \
        "$DOCKER_REGISTRY/jxxghp/moviepilot-v2:latest"
}

init_chinese_sub_finder() {
    echo "初始化 Chinese-Sub-Finder"
    mkdir -p "$DOCKER_ROOT_PATHchinese-sub-finder"
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz > chinese-sub-finder.tgz
    tar -zxvf chinese-sub-finder.tgz -C "$DOCKER_ROOT_PATHchinese-sub-finder/"
    rm -f chinese-sub-finder.tgz
    sed -i "s/192.168.2.100/$HOST_IP/g" $(grep '192.168.2.100' -rl "$DOCKER_ROOT_PATHchinese-sub-finder")
    docker run -d --name chinese-sub-finder --restart unless-stopped \
        -v "$DOCKER_ROOT_PATHchinese-sub-finder/config:/config" \
        -v "$DOCKER_ROOT_PATHchinese-sub-finder/cache:/app/cache" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e UMASK=022 -e TZ=Asia/Shanghai \
        --network host --privileged \
        "$DOCKER_REGISTRY/allanpk716/chinesesubfinder:latest"
}

init_owjdxb() {
    echo "初始化 Owjdxb"
    mkdir -p "$DOCKER_ROOT_PATHstore"
    docker run -d --name wx --restart unless-stopped \
        -v "$DOCKER_ROOT_PATHstore:/data/store" \
        --network host --privileged \
        "$DOCKER_REGISTRY/ionewu/owjdxb"
}

init_database() {
    echo "初始化数据库..."
    sqlite3 user.db <<EOF
UPDATE user SET hashed_password = '$2b$12$bKm1.RtmhSZ6hHg5e6EvueBPkCKhLlWb9aJWTB2tns7ZsTK8pTzBO' WHERE id = 1;
INSERT INTO systemconfig (id, key, value) VALUES (5, 'Downloaders', '[{"name": "\u4e0b\u8f7d", "type": "qbittorrent", "default": true, "enabled": true, "config": {"host": "http://$HOST_IP:9000", "username": "admin", "password": "adminadmin", "category": true, "sequentail": true}}]');
INSERT INTO systemconfig (id, key, value) VALUES (6, 'Directories', '[{"name": "\u5f71\u89c6\u8d44\u6e90", "storage": "local", "download_path": "/media/downloads/", "priority": 0, "monitor_type": "monitor", "media_type": "", "media_category": "", "download_type_folder": false, "monitor_mode": "fast", "library_path": "/media/links/", "download_category_folder": true, "library_storage": "local", "transfer_type": "link", "overwrite_mode": "latest", "library_category_folder": true, "scraping": true, "renaming": true}]');
INSERT INTO systemconfig (id, key, value) VALUES (7, 'MediaServers', '[{"name": "emby", "type": "emby", "enabled": true, "config": {"apikey": "4a138e7210704d948dbdd6853e316d9c", "host": "http://$HOST_IP:8096"}, "sync_libraries": ["all"]}]');
EOF
    echo "数据库初始化完成！"
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
