#!/bin/bash

# 红色文本颜色代码
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"


CURRENT_DIR="$PWD"
echo "当前脚本运行目录为: $CURRENT_DIR"
ENV_FILE="$CURRENT_DIR/.env"

# 设定环境变量 PUID、PGID 和 UMASK
PUID="${PUID:-0}"  # 默认为0，如果环境变量已设置，则使用环境变量的值
PGID="${PGID:-0}"  # 默认为0
UMASK="${UMASK:-022}"  # 默认为000
DOCKER_REGISTRY="crpi-pqqbvdf8c8dv7tyr.cn-shanghai.personal.cr.aliyuncs.com/nas-mp"

LOG_FILE="$CURRENT_DIR/install.log"
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}
log "脚本开始运行"

# 从环境变量文件加载已有的环境变量
load_env_vars() {
       if [ -f "$ENV_FILE" ]; then
        # 加载文件中的环境变量
        source "$ENV_FILE"
        echo "环境变量已成功加载。"
    else
        echo "环境变量文件 ($ENV_FILE) 不存在。"
    fi

    # 输出当前所有的环境变量
    # 只输出脚本中定义的环境变量
    echo -e "\n脚本定义的环境变量如下："
    echo "DOCKER_ROOT_PATH=$DOCKER_ROOT_PATH"
    echo "VIDEO_ROOT_PATH=$VIDEO_ROOT_PATH"
    echo "HOST_IP=$HOST_IP"
    echo "DOCKER_REGISTRY=$DOCKER_REGISTRY"
    echo "USER_ID=$USER_ID"
    echo "GROUP_ID=$GROUP_ID"
    echo "USER_GROUPS=$USER_GROUPS"
}
load_env_vars

# 写入环境变量到文件
save_env_vars() {
    # 备份现有的 .env 文件
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${ENV_FILE}.bak"
        echo "已备份环境变量文件为 ${ENV_FILE}.bak"
    fi

    # 使用 `>` 覆盖写入而非 `>>` 追加
    {
        echo "USER_ID=$USER_ID"
        echo "GROUP_ID=$GROUP_ID"
        echo "USER_GROUPS=$USER_GROUPS"
        echo "DOCKER_ROOT_PATH=$DOCKER_ROOT_PATH"
        echo "VIDEO_ROOT_PATH=$VIDEO_ROOT_PATH"
        echo "HOST_IP=$HOST_IP"
        echo "DOCKER_REGISTRY=$DOCKER_REGISTRY"
    } > "$ENV_FILE"
}

# 确保用户输入的变量不为空，否则要求重新输入
get_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3
    local value
    while [ -z "$value" ]; do
        read -p "$prompt_message ($default_value): " value
        value="${value:-$default_value}"
        if [ "$var_name" == "DOCKER_ROOT_PATH" ] || [ "$var_name" == "VIDEO_ROOT_PATH" ]; then
            # 检查路径是否有效
            if [ ! -d "$value" ]; then
                echo -e "${RED}路径无效，请重新输入。${RESET}"
                value=""
            fi
        fi
    done
    eval "$var_name=$value"
}




# 提示并获取 Docker 根路径
if [ -z "$DOCKER_ROOT_PATH" ]; then
    get_input "DOCKER_ROOT_PATH" "请输入 Docker 根路径" "/volume1/docker"
else
    echo -e "${GREEN}当前 Docker 根路径为: $DOCKER_ROOT_PATH${RESET}"
    read -p "是否使用该路径？(y/n): " use_default
    if [ "$use_default" != "y" ]; then
        get_input "DOCKER_ROOT_PATH" "请输入 Docker 根路径" "$DOCKER_ROOT_PATH"
    fi
fi

# 提示并获取视频文件根路径
if [ -z "$VIDEO_ROOT_PATH" ]; then
    get_input "VIDEO_ROOT_PATH" "请输入视频文件根路径" "/volume1/media"
else
    echo -e "${GREEN}当前视频文件根路径为: $VIDEO_ROOT_PATH${RESET}"
    read -p "是否使用该路径？(y/n): " use_default
    if [ "$use_default" != "y" ]; then
        get_input "VIDEO_ROOT_PATH" "请输入视频文件根路径" "$VIDEO_ROOT_PATH"
    fi
fi

# 获取 eth0 网卡的 IPv4 地址，过滤掉回环地址、Docker 地址和私有网段 172.x.x.x
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip -4 addr show | grep inet | grep -v '127.0.0.1' | grep -v 'docker' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
fi

if [ -z "$HOST_IP" ]; then
    while [ -z "$HOST_IP" ]; do
        read -p "请输入主机 IP 地址 [默认：$HOST_IP]：" input_ip
        HOST_IP="${input_ip:-$HOST_IP}"  # 如果用户输入为空，则使用默认值
        if [ -z "$HOST_IP" ]; then
            echo -e "${RED}主机 IP 地址不能为空，请重新输入。${RESET}"
        fi
    done
else
    echo -e "${GREEN}当前主机 IP 地址为: $HOST_IP${RESET}"
    read -p "是否使用该 IP 地址？(y/n): " use_default
    if [ "$use_default" != "y" ]; then
        get_input "HOST_IP" "请输入主机 IP 地址" "$HOST_IP"
    fi
fi


docker login -u naspt -p naspt1995  crpi-pqqbvdf8c8dv7tyr.cn-shanghai.personal.cr.aliyuncs.com


#!/bin/bash

# 让用户输入用户名
read -p "请输入用户名: " USER_NAME

# 获取当前用户的信息
USER_ID=$(id -u "$USER_NAME")
GROUP_ID=$(id -g "$USER_NAME")
USER_GROUPS=$(id -G "$USER_NAME" | tr ' ' ',')

# 检查用户是否存在
if [ $? -eq 0 ]; then
    # 格式化并输出
    echo "uid=$USER_ID($USER_NAME) gid=$GROUP_ID(groups) groups=$USER_GROUPS"
else
    echo "错误：用户 '$USER_NAME' 不存在！"
fi

export USER_ID
export GROUP_ID
export USER_GROUPS
export DOCKER_ROOT_PATH
export VIDEO_ROOT_PATH
export HOST_IP
export DOCKER_REGISTRY

# 保存环境变量到文件
save_env_vars

echo -e "${GREEN}最终的主机 IP 地址是: $HOST_IP${RESET}"
if [ -z "$DOCKER_REGISTRY" ]; then
    echo -e "${GREEN}有梯子所以不选择镜像加速${RESET}"
else
    echo -e "${GREEN}Docker 镜像源: $DOCKER_REGISTRY${RESET}"
fi
echo -e "${GREEN}Docker 根路径: $DOCKER_ROOT_PATH${RESET}"
echo -e "${GREEN}Midea 根路径: $VIDEO_ROOT_PATH${RESET}"
echo -e "${GREEN}用户信息：PUID=$USER_ID($USER_NAME) PGID=$GROUP_ID UMASK=022"


check_container_status() {
    local container_name=$1
    local status=$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null)
    case "$status" in
        running) echo -e "${GREEN}[✔] $container_name 已启动${RESET}" ;;
        exited) echo -e "${RED}[✘] $container_name 已停止${RESET}" ;;
        *) echo -e "${RED}[✘] $container_name 未安装${RESET}" ;;
    esac
}


# 定义一个函数来获取服务的安装状态，并根据状态显示颜色
get_service_status() {
    local container_name=$1
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        echo -e "${GREEN}[✔] $container_name 已安装${RESET}"
    else
        echo -e "${RED}[✘] $container_name 未安装${RESET}"
    fi
}

echo -e "${GREEN}创建安装环境中...${RESET}"
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
        1) init_clash ; check_container_status "clash" ;;
        2) init_qbittorrent ; check_container_status "qb-9000" ;;
        3) init_emby ; check_container_status "emby" ;;
        4) init_moviepilot ; check_container_status "moviepilot-v2" ;;
        5) init_chinese_sub_finder ; check_container_status "chinese-sub-finder" ;;
        6) init_owjdxb ; check_container_status "wx" ;;
        7) init_database  ;;
        8) view_moviepilot_logs ;;
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
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}clash-and-dashboard:latest"
}

init_qbittorrent() {
    echo "初始化 qBittorrent"
    mkdir -p "$DOCKER_ROOT_PATH/qb-9000"
    # 检查 qbittorrentbak.tgz 是否已经存在，如果存在则跳过下载

    # 检查 qbittorrentbak.tgz 是否已存在，如果存在则跳过下载
    if [ ! -f "$CURRENT_DIR/qbittorrentbak.tgz" ]; then
        echo "下载 qbittorrentbak.tgz 文件..."
        curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-qb.tgz -o "naspt-qb.tgz"
    else
        echo "naspt-qb.tgz 文件已存在，跳过下载。"
    fi

    tar -zxvf naspt-qb.tgz
    cp -rf qb-9000/* "$DOCKER_ROOT_PATH/qb-9000/"
    docker run -d --name qb-9000 --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/qb-9000/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=9000 \
        -e SavePatch="/media/downloads" -e TempPatch="/media/downloads" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}qbittorrent:4.6.4"
}

init_moviepilot() {
    echo "初始化 MoviePilot"
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/main"
    mkdir -p "$DOCKER_ROOT_PATH/moviepilot-v2/config"

    # 下载并解压文件
  # 检查 core.tgz 是否已经存在，如果存在则跳过下载
    if [ ! -f "$DOCKER_ROOT_PATH/moviepilot-v2/core.tgz" ]; then
        echo "下载 core.tgz 文件..."
        curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-core.tgz -o "$DOCKER_ROOT_PATH/moviepilot-v2/core.tgz"
    else
        echo "core.tgz 文件已存在，跳过下载。"
    fi
    # 解压到指定目录
    tar -zxvf "$DOCKER_ROOT_PATH/moviepilot-v2/core.tgz" -C "$DOCKER_ROOT_PATH/moviepilot-v2/"

    docker run -d \
      --name moviepilot-v2 \
      --restart always \
      --privileged \
      -v "$VIDEO_ROOT_PATH:/media" \
      -v "$DOCKER_ROOT_PATH/moviepilot-v2/config:/config" \
      -v "$DOCKER_ROOT_PATH/moviepilot-v2/core:/moviepilot/.cache/ms-playwright" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -e MOVIEPILOT_AUTO_UPDATE=false \
      -e PROXY_HOST="http://$HOST_IP:7890" \
      -e PUID="$PUID" \
      -e PGID="$PGID" \
      -e UMASK="$UMASK"  \
      -e TZ=Asia/Shanghai \
      -e AUTH_SITE=iyuu \
      -e IYUU_SIGN="IYUU49479T2263e404ce3e261473472d88f75a55d3d44faad1" \
      -e SUPERUSER="admin" \
      -e API_TOKEN="nasptnasptnasptnaspt" \
      --network host \
      "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}moviepilot-v2:latest"

      echo "容器启动完成，开始检测是否生成了 user.db 文件..."
      SECONDS=0
while true; do
    # 等待容器启动完成并生成文件
    sleep 1  # 每 5 秒检查一次
    # 检查容器内是否存在 user.db 文件
    USER_DB_FILE="/config/user.db"
    FILE_EXISTS=$(docker exec moviepilot-v2 test -f "$USER_DB_FILE" && echo "exists" || echo "not exists")
  # 检查日志文件中是否存在 "所有插件初始化完成"
    LOG_FILES=$(docker exec moviepilot-v2 ls /docker/moviepilot-v2/config/logs/*.log 2>/dev/null)
    LOG_MSG_FOUND=$(docker exec moviepilot-v2 grep -l "所有插件初始化完成" $LOG_FILES 2>/dev/null)
    if [ "$FILE_EXISTS" == "exists" ]; then
        echo "user.db 文件已成功生成在 /config 文件夹下。"
        break  # 跳出循环，继续后续操作
    else
        # 追加输出，确保前面的信息不变
        echo -ne "正在初始化moviepilot-v2... $SECONDS 秒 \r"

    fi
done
}

init_emby() {
    echo "初始化 Emby"
    mkdir -p "$DOCKER_ROOT_PATH/emby"
# 检查 embybak.tgz 是否已经存在，如果存在则跳过下载
    if [ ! -f "embybak.tgz" ]; then
        echo "下载 embybak4.8.tgz 文件..."
        curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-emby.tgz > naspt-emby.tgz
    else
        echo "naspt-emby.tgz 文件已存在，跳过下载。"
    fi
    tar -zxvf naspt-emby.tgz

    cp -rf emby/* "$DOCKER_ROOT_PATH/emby/"

    docker run -d --name emby --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/emby/config:/config" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e UID="$PUID" -e GID="$PGID" -e GIDLIST="$PGID" -e TZ=Asia/Shanghai \
        --device /dev/dri:/dev/dri \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}embyserver:beta"
}

init_chinese_sub_finder() {
    echo "初始化 Chinese-Sub-Finder"
    mkdir -p "$DOCKER_ROOT_PATH/chinese-sub-finder"
 # 检查 chinese-sub-finder.tgz 是否已经存在，如果存在则跳过下载
    if [ ! -f "chinese-sub-finder.tgz" ]; then
        echo "下载 chinese-sub-finder.tgz 文件..."
        curl -L http://43.134.58.162:1999/d/naspt/v2/naspt-csf.tgz > naspt-csf.tgz
    else
        echo "naspt-csf.tgz 文件已存在，跳过下载。"
    fi
    tar -zxvf naspt-csf.tgz
    cp -rf chinese-sub-finder/* "$DOCKER_ROOT_PATH/chinese-sub-finder/"
    sed -i "s/192.168.2.100/$HOST_IP/g" "$DOCKER_ROOT_PATH/chinese-sub-finder/config/ChineseSubFinderSettings.json"
    docker run -d --name chinese-sub-finder --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/config:/config" \
        -v "$DOCKER_ROOT_PATH/chinese-sub-finder/cache:/app/cache" \
        -v "$VIDEO_ROOT_PATH:/media" \
        -e PUID="$PUID" -e PGID="$PGID" -e UMASK="$UMASK" -e TZ=Asia/Shanghai \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}chinesesubfinder:latest"
}

init_owjdxb() {
    echo "初始化 Owjdxb"
    mkdir -p "$DOCKER_ROOT_PATH/store"
    docker run -d --name wx --restart unless-stopped \
        -v "$DOCKER_ROOT_PATH/store:/data/store" \
        --network host --privileged \
        "${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}owjdxb"
}

init_database() {
    echo "app.env..."
      # 生成 app.env 文件并写入内容
    echo "GITHUB_PROXY='https://mirror.ghproxy.com/'" > "$DOCKER_ROOT_PATH/moviepilot-v2/config/"app.env

      # 检查文件是否已成功创建并写入
    if [ -f "app.env" ]; then
        echo "app.env 文件已成功创建并写入内容："
        cat app.env  # 显示文件内容确认
    else
        echo "创建 app.env 文件失败！"
    fi
    echo "category.yaml"
    cat <<EOF > "$DOCKER_ROOT_PATH/moviepilot-v2/config/category.yaml"
movie:
  电影/动画电影:
    genre_ids: '16'
  电影/儿童电影:
    genre_ids: '10762'
  电影/歌舞电影:
    genre_ids: '10402'
  电影/港台电影:
    origin_country: 'TW,HK'
  电影/国产电影:
    origin_country: 'CN'
  电影/日韩电影:
    origin_country: 'JP,KP,KR'
  电影/南亚电影:
    origin_country: 'TH,IN,SG'
  电影/欧美电影:

tv:
  动漫/国产动漫:
    genre_ids: '16'
    origin_country: 'CN,TW,HK'
  动漫/欧美动漫:
    genre_ids: '16'
    origin_country: 'US,FR,GB,DE,ES,IT,NL,PT,RU,UK'
  动漫/日本番剧:
    genre_ids: '16'
    origin_country: 'JP'
  剧集/儿童剧集:
    genre_ids: '10762'
  剧集/纪录影片:
    genre_ids: '99'
  剧集/综艺节目:
    genre_ids: '10764,10767'
  剧集/港台剧集:
    origin_country: 'TW,HK'
  剧集/国产剧集:
    origin_country: 'CN'
  剧集/日韩剧集:
    origin_country: 'JP,KP,KR'
  剧集/南亚剧集:
    origin_country: 'TH,IN,SG'
  剧集/欧美剧集:
EOF

   # 检查文件是否已成功创建并写入
    if [ -f "category.yaml" ]; then
        echo "category.yaml 文件已成功创建并写入内容："
        cat category.yaml  # 显示文件内容确认
    else
        echo "创建 category.yaml 文件失败！"
    fi

    echo 'UPDATE user SET hashed_password = "$2b$12$9Lcemwg/PNtVaegry6wY.eZL41dENcX3f9Bt.NdhxMtzAsrhv1Cey" WHERE id = 1;' > "$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"
    echo "INSERT INTO systemconfig (id, key, value) VALUES (5, 'Downloaders', '[{\"name\": \"\\u4e0b\\u8f7d\", \"type\": \"qbittorrent\", \"default\": true, \"enabled\": true, \"config\": {\"host\": \"http://119.3.173.6:9000\", \"username\": \"admin\", \"password\": \"a123456!@\", \"category\": true, \"sequentail\": true}}]');" >> "$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"
    echo "INSERT INTO systemconfig (id, key, value) VALUES (6, 'Directories', '[{\"name\": \"\\u5f71\\u89c6\\u8d44\\u6e90\", \"storage\": \"local\", \"download_path\": \"/media/downloads/\", \"priority\": 0, \"monitor_type\": \"monitor\", \"media_type\": \"\", \"media_category\": \"\", \"download_type_folder\": false, \"monitor_mode\": \"fast\", \"library_path\": \"/media/links/\", \"download_category_folder\": true, \"library_storage\": \"local\", \"transfer_type\": \"link\", \"overwrite_mode\": \"latest\", \"library_category_folder\": true, \"scraping\": true, \"renaming\": true}]');" >> "$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"
    echo "INSERT INTO systemconfig (id, key, value) VALUES (7, 'MediaServers', '[{\"name\": \"emby\", \"type\": \"emby\", \"enabled\": true, \"config\": {\"apikey\": \"4a138e7210704d948dbdd6853e316d9c\", \"host\": \"http://119.3.173.6:8096\"}, \"sync_libraries\": [\"all\"]}]');" >> "$DOCKER_ROOT_PATH/moviepilot-v2/config/script.sql"

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

    echo "正在检查容器是否成功重启..."
    sleep 1  # 等待容器重新启动
    SECONDS=0
# 持续检查容器状态，直到容器运行或失败
    while true; do
        CONTAINER_STATUS=$(docker inspect --format '{{.State.Status}}' moviepilot-v2)

        if [ "$CONTAINER_STATUS" == "running" ]; then
            echo "容器 moviepilot-v2 重启成功！"
            break
        elif [ "$CONTAINER_STATUS" == "starting" ]; then
        # 追加输出，确保前面的信息不变
        echo -ne "正在初始化moviepilot-v2... $SECONDS 秒 \r"
            sleep 1 # 等待2秒后再次检查
        else
            echo "错误: 容器 moviepilot-v2 重启失败！状态：$CONTAINER_STATUS"
            exit 1
        fi
    done
}

view_moviepilot_logs() {
    echo "查看 moviepilot-v2 容器日志..."
    docker logs -f moviepilot-v2
}

# 循环安装服务
while true; do
    # 获取各服务的安装状态
    clash_status=$(get_service_status "clash")
    qbittorrent_status=$(get_service_status "qb-9000")
    emby_status=$(get_service_status "emby")
    moviepilot_status=$(get_service_status "moviepilot-v2")
    chinese_sub_finder_status=$(get_service_status "chinese-sub-finder")
    owjdxb_status=$(get_service_status "wx")
    database_status=$(get_service_status "moviepilot-v2")  # 根据需要选择具体容器

    echo "请选择要安装的服务（输入数字）："
    echo "1. Clash $clash_status"
    echo "2. qBittorrent $qbittorrent_status"
    echo "3. Emby $emby_status"
    echo "4. MoviePilot $moviepilot_status"
    echo "5. Chinese-Sub-Finder $chinese_sub_finder_status"
    echo "6. Owjdxb $owjdxb_status"
    echo "7. 初始化数据库 "
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
