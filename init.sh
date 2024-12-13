#!/bin/bash

# 安全选项
set -euo pipefail

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
    exit 1
}

# 手动输入变量
read -p "请输入视频存储路径 (默认: /mnt/video): " VIDEO_ROOT_PATH
VIDEO_ROOT_PATH=${VIDEO_ROOT_PATH:-/mnt/video}

read -p "请输入Docker存储路径 (默认: /mnt/docker): " DOCKER_ROOT_PATH
DOCKER_ROOT_PATH=${DOCKER_ROOT_PATH:-/mnt/docker}

read -p "请输入主机IP地址 (默认: 192.168.1.1): " HOST_IP
HOST_IP=${HOST_IP:-192.168.1.1}

# 定义服务名称常量
QB="qb"
MP="mp"
EB="eb"
CSF="csf"
WX="wx"
CL="cl"

# 读取用户输入服务
read -p "请输入你想安装的服务（如：qb,mp,eb,csf,wx,cl）: " server

# 初始化文件夹
log_info "初始化文件夹结构..."
create_directories() {
    mkdir -p $VIDEO_ROOT_PATH/downloads/剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片} \
             $VIDEO_ROOT_PATH/downloads/动漫/{国产动漫,欧美动漫} \
             $VIDEO_ROOT_PATH/downloads/电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影} \
             $VIDEO_ROOT_PATH/links/剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片} \
             $VIDEO_ROOT_PATH/links/动漫/{国产动漫,欧美动漫} \
             $VIDEO_ROOT_PATH/links/电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}
}
create_directories

# 下载文件函数
download_file() {
    local url="$1"
    local output="$2"
    log_info "下载文件：$url 到 $output"
    curl -fsSL "$url" -o "$output" || log_error "下载失败: $url"
}

# 下载配置文件
log_info "下载配置文件..."
download_file "https://mpnasv2.oss-cn-shanghai.aliyuncs.com/config.py" "config.py"
download_file "https://mpnasv2.oss-cn-shanghai.aliyuncs.com/script.sql" "script.sql"
download_file "https://mpnasv2.oss-cn-shanghai.aliyuncs.com/category.yaml" "category.yaml"
download_file "https://mpnasv2.oss-cn-shanghai.aliyuncs.com/config.sh" "config.sh"
chmod a+x config.sh

# 服务安装函数
install_service() {
    local service="$1"
    local path="$2"
    local docker_compose_name="$3"
    local archive_url="$4"

    log_info "初始化 $service 服务..."
    mkdir -p "$path"
    
    if [ -n "$archive_url" ]; then
        local archive_name="${archive_url##*/}"
        download_file "$archive_url" "$archive_name"
        tar -zxvf "$archive_name"
        cp -rf ~/nasmpv2/"$service"/* "$path/"
    fi

    ./docker-compose up -d "$docker_compose_name"
}

# 安装具体服务
log_info "开始安装服务: $server"

if echo "$server" | grep -q "$CL"; then
    install_service "clash" "$DOCKER_ROOT_PATH/clash" "clash" ""
fi

if echo "$server" | grep -q "$QB"; then
    install_service "qbittorrent" "$DOCKER_ROOT_PATH/qb-9000" "qb-9000" "https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz"
fi

if echo "$server" | grep -q "$EB"; then
    install_service "emby" "$DOCKER_ROOT_PATH/emby" "emby" "https://mpnas.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz"
fi

if echo "$server" | grep -q "$MP"; then
    install_service "moviepilot-v2" "$DOCKER_ROOT_PATH/moviepilot-v2/main" "moviepilot-v2" ""
    mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/config $DOCKER_ROOT_PATH/moviepilot-v2/core
fi

if echo "$server" | grep -q "$CSF"; then
    log_info "初始化 chinese-sub-finder"
    install_service "chinese-sub-finder" "$DOCKER_ROOT_PATH/chinese-sub-finder" "chinese-sub-finder" "https://mpnas.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz"
    sed -i "s/192.168.2.100/$HOST_IP/g" `grep '192.168.2.100' -rl $DOCKER_ROOT_PATH/chinese-sub-finder`
fi

if echo "$server" | grep -q "$WX"; then
    install_service "owjdxb" "$DOCKER_ROOT_PATH/store" "wx" ""
fi

log_info "所有安装任务已完成！"
