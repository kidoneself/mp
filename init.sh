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

# 确保用户输入的变量不为空，否则要求重新输入
while [ -z "$DOCKER_ROOT_PATH" ]; do
    read -p "请输入 Docker 根路径（如 /root/docker）： " DOCKER_ROOT_PATH
    if [ -z "$DOCKER_ROOT_PATH" ]; then
        echo "Docker 根路径不能为空，请重新输入。"
    fi
done

while [ -z "$VIDEO_ROOT_PATH" ]; do
    read -p "请输入视频文件根路径（如 /root/videos）： " VIDEO_ROOT_PATH
    if [ -z "$VIDEO_ROOT_PATH" ]; then
        echo "视频文件根路径不能为空，请重新输入。"
    fi
done

while [ -z "$HOST_IP" ]; do
    read -p "请输入主机 IP 地址： " HOST_IP
    if [ -z "$HOST_IP" ]; then
        echo "主机 IP 地址不能为空，请重新输入。"
    fi
done

export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP

echo "创建安装环境"
cd ~ && mkdir -p nasmpv2 && cd nasmpv2

# 拉取安装文件
echo "拉取安装文件"
if [ ! -f "install_bash.sh" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/install_bash.sh > install_bash.sh
    chmod a+x install_bash.sh
else
    echo "install_bash.sh 已存在，跳过下载。"
fi

if [ ! -f "install.sh" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/install.sh > install.sh
    chmod a+x install.sh
else
    echo "install.sh 已存在，跳过下载。"
fi

# 拉取配置文件
echo "拉取配置文件"
if [ ! -f ".env" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/.env > .env
else
    echo ".env 已存在，跳过下载。"
fi

if [ ! -f "docker-compose.yml" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/docker-compose.yml > docker-compose.yml
else
    echo "docker-compose.yml 已存在，跳过下载。"
fi

if [ ! -f "config.py" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/config.py > config.py
else
    echo "config.py 已存在，跳过下载。"
fi

if [ ! -f "script.sql" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/script.sql > script.sql
else
    echo "script.sql 已存在，跳过下载。"
fi

if [ ! -f "category.yaml" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/category.yaml > category.yaml
else
    echo "category.yaml 已存在，跳过下载。"
fi

if [ ! -f "config.sh" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/config.sh > config.sh
    chmod a+x config.sh
else
    echo "config.sh 已存在，跳过下载。"
fi

# 安装 docker-compose
if [ ! -f "./docker-compose" ]; then
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/docker-compose > docker-compose
    chmod a+x docker-compose
else
    echo "docker-compose 已存在，跳过下载。"
fi

# 初始化文件夹
echo "初始化文件夹"
mkdir -p $VIDEO_ROOT_PATH/downloads/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}} \
         $VIDEO_ROOT_PATH/links/{剧集/{国产剧集,日韩剧集,欧美剧集,综艺节目,纪录片},动漫/{国产动漫,欧美动漫},电影/{儿童电影,动画电影,国产电影,日韩电影,欧美电影}}

# 单服务安装函数
install_service() {
    case $1 in
    1)
        echo "初始化 Clash"
        mkdir -p $DOCKER_ROOT_PATH/clash
        ./docker-compose up -d clash
        ;;
    2)
        echo "初始化 qBittorrent"
        mkdir -p $DOCKER_ROOT_PATH/qb-9000
        curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
        tar -zxvf qbittorrentbak.tgz
        cp -rf ~/nasmpv2/qbittorrent/* $DOCKER_ROOT_PATH/qb-9000/
        ./docker-compose up -d qb-9000
        ;;
    3)
        echo "初始化 Emby"
        mkdir -p $DOCKER_ROOT_PATH/emby
        curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
        tar -zxvf embybak.tgz
        cp -rf ~/nasmpv2/emby/* $DOCKER_ROOT_PATH/emby/
        ./docker-compose up -d emby
        ;;
    4)
        echo "初始化 MoviePilot"
        mkdir -p $DOCKER_ROOT_PATH/moviepilot-v2/{main,config,core}
        cp config.py $DOCKER_ROOT_PATH/moviepilot-v2/config/
        cp category.yaml $DOCKER_ROOT_PATH/moviepilot-v2/config/
        cp script.sql $DOCKER_ROOT_PATH/moviepilot-v2/config/
        sed -i "s/119.3.173.6/$HOST_IP/g" `grep '119.3.173.6' -rl $DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql`
        ./docker-compose up -d moviepilot-v2
        docker exec -w /config moviepilot-v2 python config.py
        docker restart moviepilot-v2
        ;;
    5)
        echo "初始化 Chinese-Sub-Finder"
        mkdir -p $DOCKER_ROOT_PATH/chinese-sub-finder
        curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz > chinese-sub-finder.tgz
        tar -zxvf chinese-sub-finder.tgz
        cp -rf ~/nasmpv2/chinese-sub-finder/* $DOCKER_ROOT_PATH/chinese-sub-finder/
        sed -i "s/192.168.2.100/$HOST_IP/g" `grep '192.168.2.100' -rl $DOCKER_ROOT_PATH/chinese-sub-finder`
        ./docker-compose up -d chinese-sub-finder
        ;;
    6)
        echo "初始化 Owjdxb"
        mkdir -p $DOCKER_ROOT_PATH/store
        ./docker-compose up -d wx
        ;;
    *)
        echo "无效选项：$1"
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
    echo "0. 退出"
    read -p "请输入选择的服务数字： " service_choice

    if [[ $service_choice -eq 0 ]]; then
        echo "安装流程结束！"
        break
    fi

    install_service $service_choice
done
