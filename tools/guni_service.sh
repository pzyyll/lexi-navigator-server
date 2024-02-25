#!/bin/bash

NAME="lexin-svr"
TOOLS_DIR=${TOOLS_DIR:-"$(readlink -f $(dirname $0))"}
PROJECT_DIR="$(realpath $TOOLS_DIR/..)"
WORK_DIR="$PROJECT_DIR"
GUNICORN_PATH="$WORK_DIR/.venv/bin/gunicorn"
APP_MODULE="run:app"
PIDFILE="$WORK_DIR/app_data/${NAME}.pid"
CONFIG="$WORK_DIR/app_data/conf/gunicorn_config.py"


start() {
    echo "Starting $NAME as `whoami`"
    # 启动gunicorn进程
    $GUNICORN_PATH -c $CONFIG $APP_MODULE -D --pid $PIDFILE
}


stop() {
    if [ -f $PIDFILE ]; then
        echo "Stopping $NAME"
        # 停止gunicorn进程
        kill -9 `cat $PIDFILE`
        rm -f $PIDFILE
    else
        echo "$NAME is not running"
    fi
}   


restart() {
    stop
    start
}


case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: service.sh {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
