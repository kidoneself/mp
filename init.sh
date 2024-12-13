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

# 其他脚本内容保持不变


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
echo "请选择 Docker 镜像源："
echo "1. docker.naspt.de/"
echo "2. hub.naspt.de/"
read -p "请输入数字选择镜像源（默认：1）：" image_choice

# 默认使用 docker.naspt.de
DOCKER_REGISTRY="docker.naspt.de/"
if [[ "$image_choice" == "2" ]]; then
    DOCKER_REGISTRY="hub.naspt.de/"
fi

export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

echo -e "${GREEN}创建安装环境中...${RESET}"
cd ~ && mkdir -p nasmpv2 && cd nasmpv2


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
            $DOCKER_REGISTRYlaoyutang/clash-and-dashboard:latest
        ;;
    2)
        echo "初始化 qBittorrent"
        mkdir -p $DOCKER_ROOT_PATH/qb-9000
        curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
        tar -zxvf qbittorrentbak.tgz
        cp -rf ~/nasmpv2/qbittorrent/* $DOCKER_ROOT_PATH/qb-9000/
        docker run -d --name qb-9000 --restart unless-stopped \
            -v $DOCKER_ROOT_PATH/qb-9000/config:/config \
            -v $VIDEO_ROOT_PATH:/media \
            -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
            -e WEBUI_PORT=9000 \
            -e SavePatch=/media/downloads -e TempPatch=/media/downloads \
            --network host --privileged \
            $DOCKER_REGISTRYlinuxserver/qbittorrent:4.6.4
        ;;
    3)
        echo "初始化 Emby"
        mkdir -p $DOCKER_ROOT_PATH/emby
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
        tar -zxvf embybak.tgz
        cp -rf ~/nasmpv2/emby/* $DOCKER_ROOT_PATH/emby/
        docker run -d --name emby --restart unless-stopped \
            -v $DOCKER_ROOT_PATH/emby/config:/config \
            -v $VIDEO_ROOT_PATH:/media \
            -e UID=0 -e GID=0 -e GIDLIST=0 -e TZ=Asia/Shanghai \
            --device /dev/dri:/dev/dri \
            --network host --privileged \
            $DOCKER_REGISTRYamilys/embyserver:beta
        ;;
    4)
        echo "初始化 MoviePilot"
        mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/{main,config,core}
        cp config.py $DOCKER_ROOT_PATH/moviepilot-v2/config/
        cp category.yaml $DOCKER_ROOT_PATH/moviepilot-v2/config/
        sed -i "s/119.3.173.6/$HOST_IP/g" $DOCKER_ROOT_PATH/moviepilot-v2/config/config.py
        docker run -d --name moviepilot-v2 --restart unless-stopped \
            -v $VIDEO_ROOT_PATH:/media \
            -v $DOCKER_ROOT_PATH/moviepilot-v2/config:/config \
            -v $DOCKER_ROOT_PATH/moviepilot-v2/core:/moviepilot/.cache/ms-playwright \
            -e NGINX_PORT=3000 -e PORT=3001 \
            -e PUID=0 -e PGID=0 -e UMASK=000 -e TZ=Asia/Shanghai \
            -e AUTH_SITE=iyuu -e IYUU_SIGN=IYUU49479T2263e404ce3e261473472d88f75a55d3d44faad1 \
            -e SUPERUSER=root -e API_TOKEN=nasptnasptnasptnaspt \
            --network host --privileged \
            stdin_open=true --tty=true \
            $DOCKER_REGISTRYjxxghp/moviepilot-v2:latest
        ;;
    5)
        echo "初始化 Chinese-Sub-Finder"
        mkdir -p $DOCKER_ROOT_PATH/chinese-sub-finder
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz > chinese-sub-finder.tgz
        tar -zxvf chinese-sub-finder.tgz
        cp -rf ~/nasmpv2/chinese-sub-finder/* $DOCKER_ROOT_PATH/chinese-sub-finder/
        sed -i "s/192.168.2.100/$HOST_IP/g" `grep '192.168.2.100' -rl $DOCKER_ROOT_PATH/chinese-sub-finder`
        docker run -d --name chinese-sub-finder --restart unless-stopped \
            -v $DOCKER_ROOT_PATH/chinese-sub-finder/config:/config \
            -v $DOCKER_ROOT_PATH/chinese-sub-finder/cache:/app/cache \
            -v $VIDEO_ROOT_PATH:/media \
            -e PUID=0 -e PGID=0 -e UMASK=022 -e TZ=Asia/Shanghai \
            --network host --privileged \
            $DOCKER_REGISTRYallanpk716/chinesesubfinder:latest
        ;;
    6)
        echo "初始化 Owjdxb"
        mkdir -p $DOCKER_ROOT_PATH/store
        docker run -d --name wx --restart unless-stopped \
            -v $DOCKER_ROOT_PATH/store:/data/store \
            --network host --privileged \
            $DOCKER_REGISTRYionewu/owjdxb
        ;;
    7)
        echo "初始化数据库..."
        sqlite3 user.db <<EOF
UPDATE user SET hashed_password = '$2b$12$bKm1.RtmhSZ6hHg5e6EvueBPkCKhLlWb9aJWTB2tns7ZsTK8pTzBO' WHERE id = 1;
INSERT INTO systemconfig (id, key, value) VALUES (5, 'Downloaders', '[{"name": "\u4e0b\u8f7d", "type": "qbittorrent", "default": true, "enabled": true, "config": {"host": "http://$HOST_IP:9000", "username": "admin", "password": "adminadmin", "category": true, "sequentail": true}}]');
INSERT INTO systemconfig (id, key, value) VALUES (6, 'Directories', '[{"name": "\u5f71\u89c6\u8d44\u6e90", "storage": "local", "download_path": "/media/downloads/", "priority": 0, "monitor_type": "monitor", "media_type": "", "media_category": "", "download_type_folder": false, "monitor_mode": "fast", "library_path": "/media/links/", "download_category_folder": true, "library_storage": "local", "transfer_type": "link", "overwrite_mode": "latest", "library_category_folder": true, "scraping": true, "renaming": true}]');
INSERT INTO systemconfig (id, key, value) VALUES (7, 'MediaServers', '[{"name": "emby", "type": "emby", "enabled": true, "config": {"apikey": "4a138e7210704d948dbdd6853e316d9c", "host": "http://$HOST_IP:8096"}, "sync_libraries": ["all"]}]');
EOF
        echo "数据库初始化完成！"
        ;;
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
