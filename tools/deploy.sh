#!/bin/bash
# source deps

PROJECT_NAME="lexin-svr"
USER=$(whoami)
GROUP=$(id -g -n $USER)
SCRIPT_SOURCE_URL="https://raw.githubusercontent.com/pzyyll/lexi-navigator-server/main/tools/deploy.sh"
PROJECT_REPOS="https://github.com/pzyyll/lexi-navigator-server.git"
CURRENT_DIR="$(pwd)"
USER_ENV_FILE="$HOME/.lexin-env"
PYTHON_CMD="python"

TEMP_DIR=$(mktemp -d)
TEMP_MK_FILE_LOG="$TEMP_DIR/mk_files.log"
echo "Temp dir: $TEMP_DIR"


exit_status() {
    EXIT_STATUS="$1"
    exit $EXIT_STATUS
}

color_echo() {
    # 定义颜色
    local style=0
    case $3 in
        "bold") style="1" ;;  # 粗体或高亮
        "lighten") style="2" ;;  # 次亮
        "italic") style="3" ;;  # 斜体，并非所有的终端都支持
        "underline") style="4" ;;  # 下划线
        "blink") style="5" ;;  # 闪烁
        "reverse") style="7" ;;  # 反显
        "conceal") style="8" ;;  # 隐匿
        "strike") style="9" ;;  # 删除线, 并非所有的终端都支持
        *) style="0" ;;
    esac

    local COLOR_PREFIX="\033[${style};"
    local RESET='\033[0m'

    case "$2" in
        "red") echo -e "${COLOR_PREFIX}31m$1${RESET}" ;;
        "green") echo -e "${COLOR_PREFIX}32m$1${RESET}" ;;
        "yellow") echo -e "${COLOR_PREFIX}33m$1${RESET}" ;;
        "blue") echo -e "${COLOR_PREFIX}34m$1${RESET}" ;;
        "purple") echo -e "${COLOR_PREFIX}35m$1${RESET}" ;;
        "cyan") echo -e "${COLOR_PREFIX}36m$1${RESET}" ;;
        "white") echo -e "${COLOR_PREFIX}37m$1${RESET}" ;;
        *) echo -e "$1" ;;
    esac
}


mk_dir() {
    local dir="$1"
    local user=${USER:-$(whoami)}
    local group=$(id -gn $user)

    if [ -d "$dir" ]; then
        echo "Directory $dir already exists."
        return 1
    fi

    local root_dir="$dir"   # return the first directory that does not exist
    local parent_dir=$(dirname "$dir")

    while [ ! -d "$parent_dir" ]; do
        root_dir="$parent_dir"
        parent_dir=$(dirname "$parent_dir")
    done

    if sudo mkdir -p "$dir"; then
        echo "$root_dir"
        sudo chown -R $user:$group "$root_dir"
        return 0
    else
        echo "Failed to create directory $dir."
        return 1
    fi
}


add_env_var() {
    local file=$1
    local var_name=$2
    local var_value=$3

    # 检查文件是否存在
    if [ ! -f "$file" ]; then
        echo "文件不存在: $file"
        return 1
    fi

    # 检查变量是否已存在
    if grep -q "^export $var_name=" "$file"; then
        # 变量存在，更新其值
        local tmp_file="$TEMP_DIR/$(basename $file)"
        sed -e "/^export $var_name=/c\
        export $var_name=\"$var_value\""\
         "$file" > $tmp_file
        mv -f $tmp_file $file
    else
        # 变量不存在，添加到文件末尾
        echo "export $var_name=\"$var_value\"" >> "$file"
    fi
}

prompt_yes_or_no() {
    while true; do
        read -p "$1 $(color_echo "[yes/no]" yellow italic): " answer
        case $answer in
            [Yy][Ee][Ss])
                return 0
                ;;
            [Nn][Oo])
                return 1
                ;;
            *)
                echo "Invalid input. Enter 'yes' or 'no'."
                ;;
        esac
    done
}

prompt_overwrite() {
    local file_path=$1
    if [ -f "$file_path" ]; then
        prompt_yes_or_no "$(color_echo $file_path green) already exists. Overwrite?"
        return $?
    fi
    return 0  # 如果文件不存在，也表示可以创建
}


add_env_to_userfile() {
    if [ ! -f "$USER_ENV_FILE" ]; then
        touch "$USER_ENV_FILE"
    fi
    add_env_var "$USER_ENV_FILE" $1 $2
}

local_mkdir() {
    # log the first not exist dir
    local dir="$1"
    if [ ! -d "$dir" ]; then
        local result=$(USER=$USER mk_dir "$dir")
        if [ "$?" -eq 0 ]; then
            echo "$result" >> "$TEMP_MK_FILE_LOG"
            return 0
        else
            echo "Error: Failed to create directory '$dir'."
            return 1
        fi
    fi
}


check_python_version() {
    local python_cmd="$1"

    if [ -z "$python_cmd" ]; then
        if command -v python3 &>/dev/null; then
            python_cmd=python3
        elif command -v python &>/dev/null; then
            python_cmd=python
        else
            echo "Python is not installed. Please install Python 3."
            return 1
        fi
    elif [ ! -x "$python_cmd" ]; then
        echo "The provided Python path '$python_cmd' is not an executable."
        return 1
    fi

    # 检查 Python 可执行文件
    if ! $python_cmd -c '' &>/dev/null; then
        echo "The provided Python path '$python_cmd' is not valid"
        return 1
    fi

    # 检查 Python 版本
    local python_version=$($python_cmd -c 'import sys; print(sys.version_info.major)')
    if [ "$python_version" -lt 3 ]; then
        echo "Found Python, but it is not Python 3. Detected version: Python $python_version"
        return 1
    else
        PYTHON_CMD=$python_cmd
        echo "Detected Python 3 version: $($python_cmd --version)"
        return 0
    fi
}


get_python_env() {
    local python_version=$(check_python_version "${1}")
    result=$?
    if [ ! "$result" -eq 0 ]; then
        echo "未检测到可用的 Python 版本, 请安装 Python 3.6或更高版本。如果你已经安装，可以提供其安装路径给我。"
        while true; do
            read -p "输入：/path/to/your/bin/python3，或者回车退出：" PYTHON_CMD
            if [ -z "$PYTHON_CMD" ]; then
                color_echo "See you next time! :)" green
                exit_status 1
            fi
            python_version=$(check_python_version "$PYTHON_CMD")
            if [ "$?" -eq 0 ]; then
                break
            else
                echo "提供的 Python 路径未检测到，请重新输入..."
            fi
        done    
    fi
    color_echo "$python_version" yellow
}


check_git() {
    # 检查 Git 是否已安装
    if ! command -v git &> /dev/null
    then
        if ! prompt_yes_or_no "Git 未安装。是否尝试安装？"; then
            echo "See you next time! :)"
            exit_status 1
        fi
        echo "正在安装 Git..."
        # 检测操作系统
        OS="$(uname -s)"
        case "${OS}" in
            Linux*)     os=Linux;;
            Darwin*)    os=Mac;;
            # CYGWIN*)    os=Cygwin;;
            # MINGW*)     os=MinGw;;
            *)          os="UNKNOWN:${OS}"
        esac

        echo "检测到的操作系统：${os}"

        # 根据操作系统安装 Git
        case "${os}" in
            Linux)
                if [ -f /etc/debian_version ]; then
                    # 基于 Debian 的系统
                    sudo apt-get update
                    sudo apt-get install git -y
                elif [ -f /etc/redhat-release ]; then
                    # 基于 RedHat 的系统
                    sudo yum update
                    sudo yum install git -y
                else
                    color_echo "未检测到当前系统可用安装包, 请手动安装 Git: https://git-scm.com/downloads" red

                fi
                ;;
            Mac)
                # 使用 Homebrew 安装 Git
                which -s brew
                if [[ $? != 0 ]] ; then
                    # 安装 Homebrew
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
                brew install git
                ;;
            *)
                color_echo "未检测到当前系统可用安装包, 请手动安装 Git: https://git-scm.com/downloads" red
                ;;
        esac
    else
        color_echo "Git 版本：$(git --version)" yellow
    fi
}


initialize_variables() {
    if [ -z "${PROJECT_DIR:-}" ]; then
        if [ -z "${PROJECT_DIR_ENV:-}" ]; then
            # 如果环境变量文件中没有设置项目路径，则使用当前目录
            PROJECT_DIR="${CURRENT_DIR}/${PROJECT_NAME}"
        else
            PROJECT_DIR="$PROJECT_DIR_ENV"
        fi
    fi

    if [ -d "$PROJECT_DIR" ]; then
        PROJECT_DIR=$(realpath "$PROJECT_DIR")
    fi
    
    WORK_DIR="$PROJECT_DIR"
    TOOLS_DIR="$WORK_DIR/tools"
    DEPS_REQUIREMENTS_FILE="$TOOLS_DIR/requirements.txt"
    SERVICE_TEMPLATE="$TOOLS_DIR/deploy_templates/service.template"
    GUNICORN_CONFIG_TEMPLATE="$TOOLS_DIR/deploy_templates/gunicorn_config.py.template"
    TRANSLATE_CONFIG_TEMPLATE="$TOOLS_DIR/deploy_templates/translate_api.conf.template"
    FLASK_CONFIG_FILE_TEMPLATE="$TOOLS_DIR/deploy_templates/flask_config.py.template"
    NGINX_CONFIG_TEMPLATE="$TOOLS_DIR/deploy_templates/nginx.conf.template"
    FLASK_ENV_TEMPLATE="$TOOLS_DIR/deploy_templates/flaskenv.template"

    ENV_BIN_DIR="$WORK_DIR/.venv/bin"

    APP_DATA="$WORK_DIR/app_data"
    DEFAULT_LOG_DIR="$APP_DATA/logs"
    DEFAULT_DB_DIR="$APP_DATA/db"
    DEFAULT_FLASK_SESSION_DIR="$APP_DATA/flask_session"
    DEFAULT_CONFIG_DIR="$APP_DATA/conf"

    SERVICE_NAME="${PROJECT_NAME}.$(basename ${SERVICE_TEMPLATE%.template})"
    NGINX_CONFIG_NAME="${PROJECT_NAME}_$(basename ${NGINX_CONFIG_TEMPLATE%.template})"

    GUNI_CONFIG_FILE="$DEFAULT_CONFIG_DIR/$(basename ${GUNICORN_CONFIG_TEMPLATE%.template})"
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
    FLASK_CONFIG_FILE="$DEFAULT_CONFIG_DIR/flask_config.py"
    TRANSLATE_CONFIG_FILE="$DEFAULT_CONFIG_DIR/$(basename ${TRANSLATE_CONFIG_TEMPLATE%.template})"
}


check_ip_port() {
    # 输入参数：形如“127.0.0.1:8080”的字符串
    local input="$1"

    # IPv4地址和端口的正则表达式
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$"

    # 检查输入是否符合正则表达式
    if [[ $input =~ $regex ]]; then
        ip="${input%:*}" # 提取IP部分
        port="${input##*:}" # 提取端口部分
        
        # 分割IP地址，检查每部分是否小于等于255
        IFS='.' read -r -a ip_parts <<< "$ip"
        valid_ip=true
        for part in "${ip_parts[@]}"; do
            if ((part > 255)); then
                valid_ip=false
                break
            fi
        done
        
        # 检查端口号是否在0到65535之间
        valid_port=false
        if ((port >= 0 && port <= 65535)); then
            valid_port=true
        fi
        
        if $valid_ip && $valid_port; then
            echo "Valid input: IP address and port are correct."
            return 0
        else
            color_echo "Invalid input: IP address(0~255) or port(0~65535) is incorrect." red
            return 1
        fi
    else
        color_echo "Invalid input format. Please use the format 'IP:Port'." red
        return 1
    fi
}


init() {
    read -p "Set the root path of the app service(default: $(color_echo "${CURRENT_DIR}" green underline)) :" project_root_path
    PROJECT_ROOT_DIR="${project_root_path:-$CURRENT_DIR}"

    if [ ! -d $PROJECT_ROOT_DIR ]; then
        if prompt_yes_or_no "The path does not exist. Do you want to create?";
        then
            local_mkdir $PROJECT_ROOT_DIR || exit_status 1
        else
            color_echo "See you next time! :)" green
            exit_status 1
        fi
    fi

    PROJECT_ROOT_DIR=$(realpath "$PROJECT_ROOT_DIR")
    PROJECT_DIR="$PROJECT_ROOT_DIR/$PROJECT_NAME"
    if [ -d $PROJECT_DIR ]; then
        echo "Project directory $(color_echo $PROJECT_DIR green underline) already exists. "
        if prompt_yes_or_no "Do you want to $(color_echo "remove" red) it and re-initialize?"; then
            sudo rm -rf $PROJECT_DIR
        else
            exit_status 0
        fi
    fi

    # 重新根据 PROJECT_DIR 路径初始化相关路径参数
    initialize_variables
    echo "项目将会在以下路径创建：$(color_echo "$PROJECT_DIR" green)"
    # git clone --no-checkout $PROJECT_REPOS $PROJECT_DIR || exit_status 1
    echo "$PROJECT_DIR" >> "$TEMP_MK_FILE_LOG"
    git clone $PROJECT_REPOS $PROJECT_DIR || exit_status 1

    cd $PROJECT_DIR || exit_status 1

    # git sparse-checkout init
    # git sparse-checkout set ts_server/ ts_common/ .gitmodules

    git pull origin main
    # git read-tree -mu HEAD

    # 更新依赖的子模块
    git submodule init || exit_status 1
    # 替换掉 ssh 成 https
    git submodule set-url libs/pyhelper https://github.com/pzyyll/python_common.git
    git submodule update --recursive || exit_status 1

    init_pyenv

    add_env_to_userfile "PROJECT_DIR_ENV" "$PROJECT_DIR"
}


init_default_data_path() {
    local_mkdir $DEFAULT_LOG_DIR
    local_mkdir $DEFAULT_DB_DIR
    local_mkdir $DEFAULT_FLASK_SESSION_DIR
    local_mkdir $DEFAULT_CONFIG_DIR
}


init_gunicorn_config() {
    if ! prompt_overwrite "$GUNI_CONFIG_FILE"; then
        return 1
    fi

    while true; do
        read -p "Bind ip and port (default: $(color_echo "127.0.0.1:6868" green)): " bind
        bind=${bind:-127.0.0.1:6868}
        result_info=$(check_ip_port $bind)
        if [ $? -eq 0 ]; then
            break
        else
            echo $result_info
        fi
    done

    sed -e "s|{{LOG_PATH}}|$DEFAULT_LOG_DIR|g" \
        -e "s|{{BIND}}|$bind|g" \
        $GUNICORN_CONFIG_TEMPLATE | tee $GUNI_CONFIG_FILE > /dev/null
}


init_flask_config() {
    if prompt_overwrite "$FLASK_CONFIG_FILE"; then
        sed -e "s|{{DB_PATH}}|$DEFAULT_DB_DIR|g" \
            $FLASK_CONFIG_FILE_TEMPLATE | tee $FLASK_CONFIG_FILE > /dev/null
    fi
    
    if prompt_overwrite "$TRANSLATE_CONFIG_FILE"; then
        cp -f $TRANSLATE_CONFIG_TEMPLATE $TRANSLATE_CONFIG_FILE
    fi

    local flaskenv="$WORK_DIR/.flaskenv"
    if prompt_overwrite $flaskenv; then
        sed -e "s|{{LOG_PATH}}|$DEFAULT_LOG_DIR|g" \
            -e "s|{{APP_DATA_PATH}}|$APP_DATA_PATH|g" \
            -e "s|{{FLASK_APP_CONFIG}}|$FLASK_CONFIG_FILE|g" \
            -e "s|{{TRANSLATE_API_CONFIG}}|$TRANSLATE_CONFIG_FILE|g" \
            $FLASK_ENV_TEMPLATE | tee $flaskenv > /dev/null
    fi
}

init_systemd_service() {
    if [ ! -d "/run/systemd/system" ]; then
        color_echo "Systemd not support." red
        return 1
    fi

    GUNI_BIN="$ENV_BIN_DIR/gunicorn"

    # sudo cp -f $SERVICE_TEMPLATE $SERVICE_FILE

    # sudo sed -i "s|{{WORKING_DIR}}|$WORK_DIR|g" $SERVICE_FILE
    # sudo sed -i "s|{{USER}}|$USER|g" $SERVICE_FILE
    # sudo sed -i "s|{{GROUP}}|$GROUP|g" $SERVICE_FILE
    # sudo sed -i "s|{{ENV_BIN_DIR}}|$ENV_BIN_DIR|g" $SERVICE_FILE
    # sudo sed -i "s|{{GUNI_BIN}}|$GUNI_BIN|g" $SERVICE_FILE
    # sudo sed -i "s|{{GUNI_CONFIG}}|$GUNI_CONFIG_FILE|g" $SERVICE_FILE

    sudo sed -e "s|{{WORKING_DIR}}|$WORK_DIR|g" \
        -e "s|{{USER}}|$USER|g" \
        -e "s|{{GROUP}}|$GROUP|g" \
        -e "s|{{ENV_BIN_DIR}}|$ENV_BIN_DIR|g" \
        -e "s|{{GUNI_BIN}}|$GUNI_BIN|g" \
        -e "s|{{GUNI_CONFIG}}|$GUNI_CONFIG_FILE|g" \
        $SERVICE_TEMPLATE | sudo tee $SERVICE_FILE > /dev/null

    sudo systemctl daemon-reload
}


uninstall_service() {
    if [ ! -d "/run/systemd/system" ]; then
        color_echo "Systemd not support." red
    fi
    if [ ! -f $SERVICE_FILE ]; then
        color_echo "Service file not found: $(color_echo $SERVICE_FILE red)" red
        return 1
    fi
    sudo systemctl stop $SERVICE_NAME
    sudo systemctl disable $SERVICE_NAME
    sudo rm -f $SERVICE_FILE
    sudo systemctl daemon-reload
}


uninstall() {
    if ! prompt_yes_or_no "Remove: ${PROJECT_DIR}?"; then
        exit_status 1
    fi

    uninstall_service
    if [ -d $APP_DATA ]; then
        sudo rm -rf $APP_DATA
    fi
    if [ -z "${NGINX_CONFIG_FILE}" ] && [ -f $NGINX_CONFIG_FILE ]; then
        sudo rm -rf $GUNI_CONFIG_FILE
    fi
    sudo rm -rf $PROJECT_DIR
    sudo rm -rf $USER_ENV_FILE
}


init_conf() {
    init_default_data_path
    init_gunicorn_config
    init_flask_config
}


# 定义更新函数
update_script() {
    echo "Updating script..."
    # 使用curl下载最新的脚本到当前目录的临时文件
    curl -H "Cache-Control: no-cache" -s $SCRIPT_SOURCE_URL -o "$0.tmp"
    
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        # 替换旧的脚本文件，并保留执行权限
        chmod --reference="$0" "$0.tmp"
        mv "$0.tmp" "$0"
        echo "The script has been updated."
    else
        color_echo "Failed to update the script." red
        # 清理临时文件
        sudo rm -f "$0.tmp"
    fi
}


init_nginx_conf() {
    read -p "Nginx config path(default: $(color_echo "/etc/nginx" green)):" NGINX_CONFIG_DIR
    NGINX_CONFIG_DIR=${NGINX_CONFIG_DIR:-/etc/nginx}
    if [ ! -d "$NGINX_CONFIG_DIR" ]; then
        color_echo "Nginx not support!!!" red
        exit_status 1
    fi
    if [ ! -f "$NGINX_CONFIG_DIR/nginx.conf" ]; then
        color_echo "Nginx not installed!!!" red
        exit_status 1
    fi

    if [ -n "${NGINX_CONFIG_FILE}" ] && [ -f "$NGINX_CONFIG_FILE" ]; then
        color_echo "Nginx config file already exists: $(color_echo $NGINX_CONFIG_FILE green underline)"
        if ! prompt_overwrite "$NGINX_CONFIG_FILE"; then
            exit_status 1
        fi
    fi

    if [ -d "$NGINX_CONFIG_DIR/sites-available" ]; then
        NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/sites-available/$NGINX_CONFIG_NAME"
    elif [ -d "$NGINX_CONFIG_DIR/conf.d" ]; then
        NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/conf.d/$NGINX_CONFIG_NAME"
    else
        color_echo "Nginx config path not found!!!" red
        exit_status 1
    fi

    read -p "Enter the domain name or ip (default $(color_echo "127.0.0.1" green underline)): " domain
    domain=${domain:-127.0.0.1}
    read -p "Enter the port (default $(color_echo "8888" green underline)): " port
    port=${port:-8888}
    read -p "Enter the local server ip and port (default $(color_echo "http://127.0.0.1:6868" green underline)): " flask_server
    flask_server=${flask_server:-http://127.0.0.1:6868}

    echo "Copy config template $NGINX_CONFIG_TEMPLATE to $(color_echo "$NGINX_CONFIG_FILE" green) ..."
    sudo cp -f $NGINX_CONFIG_TEMPLATE $NGINX_CONFIG_FILE
    sudo sed -i "s|{{PUBLIC_IP}}|$domain|g" $NGINX_CONFIG_FILE
    sudo sed -i "s|{{PORT}}|$port|g" $NGINX_CONFIG_FILE
    sudo sed -i "s|{{FLASK_IP}}|$flask_server|g" $NGINX_CONFIG_FILE

    echo "Run $(color_echo "'sudo systemctl reload nginx'" red) to apply changes."
    echo "Additional modifications are in the file: $(color_echo "$NGINX_CONFIG_FILE" green)"

    add_env_to_userfile "NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE"
}


up_source() {
    # 更新项目代码
    color_echo "Updating project source code..."
    cd $PROJECT_DIR
    git pull origin main
    if [ $1 == "force" ]; then
        git read-tree -mu HEAD
    fi
    git submodule update --init --recursive
}


init_pyenv() {
    color_echo "Initializing python running deps..."

    cd $WORK_DIR || exit_status 1

    color_echo "Start installing python venv ..."
    init_venv=true
    if [ -d .venv ]; then
        if ! prompt_yes_or_no "The python venv already exists. Remove and re-initialize?"; then
            init_venv=false
        fi
    fi
    if [ "$init_venv" == "true" ]; then
        $PYTHON_CMD -m pip install --upgrade pip || exit_status 1
        $PYTHON_CMD -m pip install virtualenv --user
        $PYTHON_CMD -m venv .venv
    fi

    color_echo "Start installing python deps ..." yellow
    source .venv/bin/activate
    python -m pip install --upgrade pip
    python -m pip install -r $DEPS_REQUIREMENTS_FILE
}


service() {
    if [ "$1" == "start" ]; then
        systemctl start $SERVICE_NAME
    elif [ "$1" == "stop" ]; then
        systemctl stop $SERVICE_NAME
    elif [ "$1" == "restart" ]; then
        systemctl restart $SERVICE_NAME
    elif [ "$1" == "status" ]; then
        systemctl status $SERVICE_NAME
    elif [ "$1" == "reload" ]; then
        systemctl daemon-reload
    else
        echo "Usage: $0 $1 {start|stop|restart|status|reload}"
    fi
}


init_socks(){
    sock_file="$APP_DATA/${PROJECT_NAME}.sock"
    sock_url="unix:$sock_file"
    sed -i'' -e "s/bind\s*=\s*\"[^\"]*\"/bind = \"$sock_file\"/g" $GUNI_CONFIG_FILE
    color_echo "Set nginx proxy_pass to $sock_url : $NGINX_CONFIG_FILE" yellow"
    sed -i'' -e "s|\(proxy_pass\s*\).*;|\1http://${sock_url};|" $NGINX_CONFIG_FILE
}


help() {
    echo "Usage: $0 {init|install-service|uninstall-service|service|up-source|init-pyenv|update|init-nginx-conf|uninstall}"
    echo "init: Initialize the project directory and install the service."
    echo "install-service: Install the service."
    echo "uninstall-service: Uninstall the service."
    echo "service: Start, stop, restart, or check the status of the service."
    echo "up-source: Update the project source code."
    echo "init-pyenv: Initialize the python environment."
    echo "update: Update the script."
    echo "init-nginx-conf: Initialize the nginx configuration."
    echo "uninstall: Uninstall the project."
}


exit_cleanup() {
    # 只在 EXIT_STATUS 非零且 TEMP_MK_FILE_LOG 文件存在时执行清理
    if [[ $EXIT_STATUS -ne 0 ]] && [[ -f $TEMP_MK_FILE_LOG ]]; then
        # 读取 TEMP_MK_FILE_LOG 文件中的每个条目并删除
        echo "Cleaning up..."
        cat $TEMP_MK_FILE_LOG
        xargs -I {} sudo rm -rf {} < $TEMP_MK_FILE_LOG
    fi
    rm -rf "$TEMP_DIR"
}


sig_cleanup() {
    exit_status 1
}


trap exit_cleanup EXIT
trap sig_cleanup SIGINT SIGTERM


if [ -f $USER_ENV_FILE ]; then
    source $USER_ENV_FILE
fi

check_git
get_python_env
initialize_variables


case $1 in
    "init")
        init
        init_conf
        init_systemd_service

        color_echo "Default configuration file path: $(color_echo "$DEFAULT_CONFIG_DIR" green)"
        color_echo "Default log file path: $(color_echo "$DEFAULT_LOG_DIR" green)"
        color_echo "Default db file path: $(color_echo "$DEFAULT_DB_DIR" green)"
        color_echo "Then run $(color_echo "'sudo systemctl start ${PROJECT_NAME}'" red) to start the service."
        ;;
    "install-service")
        init_systemd_service
        ;;
    "uninstall-service")
        uninstall_service
        ;;
    "service")
        service $2
        ;;
    "up-source")
        up_source force
        ;;
    "init-pyenv")
        color_echo "Start initializing python environment..."
        color_echo "Project path: $(color_echo "$PROJECT_DIR" green)"

        init_conf
        init_pyenv
        ;;
    "init-socks")
        init_socks
        ;;
    "update")
        update_script
        ;;
    "init-nginx-conf")
        init_nginx_conf
        ;;
    "uninstall")
        uninstall
        ;;
    *)
        help
        ;;
esac
