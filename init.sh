
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

# 设置默认路径
DOCKER_ROOT_PATH="${DOCKER_ROOT_PATH:-/volume1/docker}"
VIDEO_ROOT_PATH="${VIDEO_ROOT_PATH:-/volume1/media}"

# 输出路径设置
echo -e "${GREEN}Docker 根路径: $DOCKER_ROOT_PATH${RESET}"
echo -e "${GREEN}Midea 根路径: $VIDEO_ROOT_PATH${RESET}"

# 确保用户输入的变量不为空，否则要求重新输入
get_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3
    local value
    while [ -z "$value" ]; do
        read -p "$prompt_message ($default_value): " value
        value="${value:-$default_value}"
        eval "$var_name=$value"
    done
}

get_input "DOCKER_ROOT_PATH" "请输入 Docker 根路径" "$DOCKER_ROOT_PATH"
get_input "VIDEO_ROOT_PATH" "请输入视频文件根路径" "$VIDEO_ROOT_PATH"

# 获取 eth0 网卡的 IPv4 地址，过滤掉回环地址、Docker 地址和私有网段 172.x.x.x
HOST_IP=$(ip -4 addr show dev eth0 | grep inet | grep -v '127.0.0.1' | grep -v '172.' | grep -v 'docker' | awk '{print $2}' | cut -d'/' -f1)
while [ -z "$HOST_IP" ]; do
    read -p "请输入主机 IP 地址 [默认：$HOST_IP]：" input_ip
    HOST_IP="${input_ip:-$HOST_IP}"  # 如果用户输入为空，则使用默认值
    if [ -z "$HOST_IP" ]; then
        echo -e "${RED}主机 IP 地址不能为空，请重新输入。${RESET}"
    fi
done

echo "最终的主机 IP 地址是: $HOST_IP"

# 用户选择镜像源
echo "请选择 Docker 镜像源："
echo "1. docker.naspt.de"
echo "2. hub.naspt.de"
echo "3. 我有梯子不使用加速（建议）"
read -p "请输入数字选择镜像源（默认：1）：" image_choice

# 默认使用 docker.naspt.de
DOCKER_REGISTRY="docker.naspt.de"
if [[ "$image_choice" == "1" ]]; then
    DOCKER_REGISTRY="docker.naspt.de"
fi
if [[ "$image_choice" == "2" ]]; then
    DOCKER_REGISTRY="hub.naspt.de"
fi
if [[ "$image_choice" == "3" ]]; then
    DOCKER_REGISTRY=""
fi

export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

echo -e "${GREEN}创建安装环境中...${RESET}"
cd ~ && mkdir -p nasmpv2 && cd nasmpv2




echo "正在创建所需文件夹..."
# 创建 Docker 根路径下的文件夹
# 定义大类
categories=("剧集" "动漫" "电影")
subcategories_juji=("国产剧集" "日韩剧集" "欧美剧集" "综艺节目" "纪录片")
subcategories_dongman=("国产动漫" "欧美动漫")
subcategories_dianying=("儿童电影" "动画电影" "国产电影" "日韩电影" "欧美电影")

# 创建文件夹
for category in "${categories[@]}"; do
  if [ "$category" == "剧集" ]; then
    subcategories=("${subcategories_juji[@]}")
  elif [ "$category" == "动漫" ]; then
    subcategories=("${subcategories_dongman[@]}")
  else
    subcategories=("${subcategories_dianying[@]}")
  fi

  for subcategory in "${subcategories[@]}"; do
    mkdir -p "$VIDEO_ROOT_PATH/downloads/$category/$subcategory" \
             "$VIDEO_ROOT_PATH/links/$category/$subcategory"
  done
done


# 单服务安装函数
install_service() {
    local service_id=$1
    case "$service_id" in
        1) init_clash ;;
        2) init_qbittorrent ;;
        3) init_emby ;;
        4) init_moviepilot ;;
        5) init_chinese_sub_finder ;;
        6) init_owjdxb ;;
        7) init_database ;;
        8) view_moviepilot_logs ;;  # 新增查看日志功能
        *)
            echo -e "${RED}无效选项：$service_id${RESET}"
        ;;
    esac
}

# 初始化各个服务
init_clash() {
    echo "初始化 Clash"
    mkdir -p "$DOCKER_ROOT_PATH/clash"
    docker run -d --name clash --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/clash:/root/.config/clash" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}laoyutang/clash-and-dashboard:latest"
}

init_qbittorrent() {
    echo "初始化 qBittorrent"
    mkdir -p "$DOCKER_ROOT_PATH/qb-9000"
    curl -L https://mpnas.oss-cn-shanghai.aliyuncs.com/qbittorrentbak.tgz > qbittorrentbak.tgz
    tar -zxvf qbittorrentbak.tgz
    cp -rf qbittorrent/* "$DOCKER_ROOT_PATH/qb-9000/"
    docker run -d --name qb-9000 --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/qb-9000/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=9000 \
        -e SavePatch="/media/downloads" -e TempPatch="/media/downloads" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}linuxserver/qbittorrent:4.6.4"
}

init_emby() {
    echo "初始化 Emby"
    mkdir -p "$DOCKER_ROOT_PATH/emby"
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/embybak4.8.tgz > embybak.tgz
    tar -zxvf embybak.tgz
    cp -rf emby/* "$DOCKER_ROOT_PATH/emby/"
    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/emby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e UID=0 -e GID=0 -e GIDLIST=0 -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}amilys/embyserver:beta"
}

init_moviepilot() {
    echo "初始化 MoviePilot"
   mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/main"
   mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/config"
   mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/core"

    docker run -d \
      --name moviepilot-v2 \
      --restart unless-stopped \
      --privileged \
      -v ${VIDEO_ROOT_PATH}:/media \
      -v ${DOCKER_ROOT_PATH}/moviepilot-v2/config:/config \
      -v ${DOCKER_ROOT_PATH}/moviepilot-v2/core:/moviepilot/.cache/ms-playwright \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -e NGINX_PORT=3000 \
      -e PORT=3001 \
      -e PUID=0 \
      -e PGID=0 \
      -e UMASK=000 \
      -e TZ=Asia/Shanghai \
      -e AUTH_SITE=iyuu \
      -e IYUU_SIGN=IYUU49479T2263e404ce3e261473472d88f75a55d3d44faad1 \
      -e SUPERUSER=root \
      -e API_TOKEN=nasptnasptnasptnaspt \
      --network host \
      -it \
      "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}jxxghp/moviepilot-v2:latest"

      echo "容器启动完成，开始检测是否生成了 user.db 文件..."

    # 持续检测是否生成 user.db 文件
    while true; do
        # 等待容器启动完成并生成文件
        sleep 5  # 每 5 秒检查一次

        # 检查容器内是否存在 user.db 文件
        USER_DB_FILE="/config/user.db"
        FILE_EXISTS=$(docker exec moviepilot-v2 test -f "$USER_DB_FILE" && echo "exists" || echo "not exists")

        if [ "$FILE_EXISTS" == "exists" ]; then
            echo "user.db 文件已成功生成在 /config 文件夹下。"
            break  # 跳出循环，继续后续操作
        else
            echo "等待 user.db 文件生成..."
        fi
    done

}

init_chinese_sub_finder() {
    echo "初始化 Chinese-Sub-Finder"
    mkdir -p "$DOCKER_ROOT_PATH/chinese-sub-finder"
    curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/chinese-sub-finder.tgz > chinese-sub-finder.tgz
    tar -zxvf chinese-sub-finder.tgz
    cp -rf chinese-sub-finder/* "$DOCKER_ROOT_PATH/chinese-sub-finder/"
    sed -i "s/192.168.2.100/$HOST_IP/g" "$DOCKER_ROOT_PATH/chinese-sub-finder/config/config.json"
    docker run -d --name chinese-sub-finder --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/config:/config" \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/cache:/app/cache" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e UMASK=022 -e TZ=Asia/Shanghai \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}allanpk716/chinesesubfinder:latest"
}

init_owjdxb() {
    echo "初始化 Owjdxb"
    mkdir -p "$DOCKER_ROOT_PATH/store"
    docker run -d --name wx --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/store:/data/store" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}ionewu/owjdxb"
}

init_database() {
    echo "下载必要文件..."
    if [ ! -f "category.yaml" ]; then
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/category.yaml > category.yaml
    else
        echo "category.yaml 已存在，跳过下载。"
    fi
     if [ ! -f "script.sql" ]; then
        curl -L https://mpnasv2.oss-cn-shanghai.aliyuncs.com/script.sql > script.sql
    else
        echo "category.yaml 已存在，跳过下载。"
    fi
    cp script.sql "$DOCKER_ROOT_PATH/moviepilot-v2/config/"
    sed -i "s/119.3.173.6/$HOST_IP/g" "$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"
    echo "初始化数据库..."
    # SQL 文件路径
    SQL_FILE="$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"
    # 确保 SQL 文件存在
    if [ ! -f "$SQL_FILE" ]; then
        echo "错误: SQL 文件 $SQL_FILE 不存在。请确认文件路径是否正确。"
        exit 1
    fi
    # 在容器中通过 Python 执行 SQL 文件
    docker exec -i  -w /config moviepilot-v2 python -c "
import sqlite3

# 连接数据库
conn = sqlite3.connect('user.db')
# 创建游标
cur = conn.cursor()
# 读取 SQL 文件
with open('/config/script.sql', 'r') as file:
    sql_script = file.read()
# 执行 SQL 脚本
cur.executescript(sql_script)
# 提交事务
conn.commit()
# 关闭连接
conn.close()
    "
    echo "SQL 文件已在容器中执行并修改数据库。"

# 输出操作完成信息
    echo "SQL 脚本已执行完毕"
    echo "数据库初始化完成！"

      # 重启容器
    docker restart moviepilot-v2

    # 获取容器日志，显示最后 30 秒
 #   echo "获取容器日志..."
  #  docker logs --tail 30 --follow moviepilot-v2

    # 等待容器重启完成并检查状态
    echo "正在检查容器是否成功重启..."
    sleep 5  # 等待容器重新启动

    # 检查容器状态
    CONTAINER_STATUS=$(docker inspect --format '{{.State.Status}}' moviepilot-v2)

    if [ "$CONTAINER_STATUS" == "running" ]; then
        echo "容器 moviepilot-v2 重启成功！"
    else
        echo "错误: 容器 moviepilot-v2 重启失败！状态：$CONTAINER_STATUS"
        exit 1
    fi
}

# 查看 MoviePilot 日志
view_moviepilot_logs() {
    echo "查看 moviepilot-v2 容器日志..."
    docker logs -f moviepilot-v2
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
    echo "8. 查看 MoviePilot 日志"
    echo "0. 退出"
    read -p "请输入选择的服务数字： " service_choice

    if [[ "$service_choice" -eq 0 ]]; then
        echo "安装流程结束！"
        break
    fi

    install_service "$service_choice"
done

echo "安装完毕！"
