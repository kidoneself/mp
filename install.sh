#!/bin/bash
set -x
START_TIME=$(date +%s)
CURRENT_DIR="/root/naspt"
PUID="${PUID:-0}"
PGID="${PGID:-0}"
UMASK="${UMASK:-022}"
DOCKER_REGISTRY="docker.nastool.de"
DEFAULT_DOCKER_PATH="/vol1/1000/docker"
DEFAULT_VIDEO_PATH="/vol1/1000/media"

# 获取用户输入
get_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3
    local value
    while true; do
        read -p "$prompt_message ($default_value): " value
        value="${value:-$default_value}"
        eval "$var_name='$value'"
        break
    done
}

# 获取 Docker 根路径和视频根路径
get_input "DOCKER_ROOT_PATH" "请输入 Docker 根路径" "$DEFAULT_DOCKER_PATH"
get_input "VIDEO_ROOT_PATH" "请输入视频文件根路径" "$DEFAULT_VIDEO_PATH"

# 获取 eth0 网卡的 IPv4 地址
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip -4 addr show | grep inet | grep -v '127.0.0.1' | grep -v 'docker' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
fi

while [ -z "$HOST_IP" ]; do
    read -p "请输入主机 IP 地址 [回车使用默认：$HOST_IP]：" input_ip
    HOST_IP="${input_ip:-$HOST_IP}"
    if [ -z "$HOST_IP" ]; then
        echo -e "主机 IP 地址不能为空，请重新输入。"
    fi
done

# 获取用户名并设置 USER_ID 和 GROUP_ID
read -p "请输入nas登录用户名: " USER_NAME
USER_ID=$(id -u "$USER_NAME")
GROUP_ID=$(id -g "$USER_NAME")

# 导出环境变量
export USER_ID
export GROUP_ID
export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

# 确保目录结构
mkdir -p "$VIDEO_ROOT_PATH/downloads" "$VIDEO_ROOT_PATH/links"

# 显示设置的配置信息
echo -e "最终的主机 IP 地址是: $HOST_IP"
echo -e "Docker 镜像源: $DOCKER_REGISTRY"
echo -e "Docker 根路径: $DOCKER_ROOT_PATH"
echo -e "视频文件根路径: $VIDEO_ROOT_PATH"
echo -e "用户信息：PUID=$USER_ID($USER_NAME) PGID=$GROUP_ID UMASK=022"

# 启动每个服务的函数
init_qbittorrent() {
    echo "初始化 qBittorrent"
    mkdir -p "$DOCKER_ROOT_PATH/qb-9000"
    curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-qb.tgz -o "$CURRENT_DIR/naspt-qb.tgz"
    tar --strip-components=1 -zxvf "$CURRENT_DIR/naspt-qb.tgz" -C "$DOCKER_ROOT_PATH/qb-9000/"
    docker run -d --name qb-9000 --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/qb-9000/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK="$UMASK" -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=9000 \
        -e SavePatch="/media/downloads" -e TempPatch="/media/downloads" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}linuxserver/qbittorrent:4.6.4"
}

init_emby() {
    echo "初始化 Emby"
    mkdir -p "$DOCKER_ROOT_PATH/emby"
    curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-emby.tgz > "$CURRENT_DIR/naspt-emby.tgz"
    tar --strip-components=1 -zxvf "$CURRENT_DIR/naspt-emby.tgz" -C "$DOCKER_ROOT_PATH/emby/"
    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/emby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e UID="$PUID" -e GID="$PGID" -e UMASK="$UMASK" -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}amilys/embyserver:beta"
}

init_chinese_sub_finder() {
    echo "初始化 Chinese-Sub-Finder"
    mkdir -p "$DOCKER_ROOT_PATH/chinese-sub-finder"
    curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-csf.tgz > "$CURRENT_DIR/naspt-csf.tgz"
    tar --strip-components=1 -zxvf "$CURRENT_DIR/naspt-csf.tgz" -C "$DOCKER_ROOT_PATH/chinese-sub-finder/"
    sed -i "s/192.168.2.100/$HOST_IP/g" "$DOCKER_ROOT_PATH/chinese-sub-finder/config/ChineseSubFinderSettings.json"
    docker run -d --name chinese-sub-finder --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/config:/config" \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/cache:/app/cache" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK="$UMASK" -e TZ=Asia/Shanghai \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}allanpk716/chinesesubfinder:latest"
}

init_moviepilot() {
    echo "初始化 MoviePilot"
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2"
    curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-core.tgz -o "$CURRENT_DIR/naspt-core.tgz"
    tar --strip-components=1 -zxvf "$CURRENT_DIR/naspt-core.tgz" -C "$DOCKER_ROOT_PATH/moviepilot-v2/"
    docker run -d --name moviepilot-v2 --restart always \
        -v "$VIDEO_ROOT_PATH:/media" \
        -v "$DOCKER_ROOT_PATH/moviepilot-v2:/config" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK="$UMASK" -e TZ=Asia/Shanghai \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}jxxghp/moviepilot-v2:latest"
}

init_database() {
    echo "初始化数据库..."
    # 提示输入数据库配置
    get_input "DB_HOST" "请输入数据库主机地址" "$HOST_IP"
    get_input "DB_PORT" "请输入数据库端口" "3306"
    get_input "DB_USER" "请输入数据库用户名" "root"
    get_input "DB_PASS" "请输入数据库密码" "password"
    echo "数据库配置: Host=$DB_HOST Port=$DB_PORT User=$DB_USER"
    # 这里可以根据数据库配置执行初始化脚本
}

# 安装服务
install_service() {
    local service_id=$1
    case "$service_id" in
        1) init_moviepilot ;;
        2) init_emby ;;
        3) init_qbittorrent ;;
        4) init_chinese_sub_finder ;;
        5) init_database ;;
        *)
            echo -e "无效选项：$service_id"
        ;;
    esac
}

# 主菜单
while true; do
    echo "请选择要安装的服务（输入数字组合，如 '1234' 表示依次安装多个服务）："
    echo "1. MoviePilot"
    echo "2. Emby"
    echo "3. qBittorrent"
    echo "4. Chinese-Sub-Finder"
    echo "5. 数据库"
    read -p "请输入选项： " selection
    for option in $(echo "$selection" | sed 's/./& /g'); do
        install_service "$option"
    done
    read -p "安装完成，是否继续安装其他服务？ (y/n): " continue_choice
    if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
        break
    fi
done

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "安装完成，运行时间：$RUN_TIME 秒"