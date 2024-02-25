# LexiNavigator Server

# 启动脚本

```shell

# 初始化运行环境
PROJECT_DIR=. ./tools/deploy.sh init-pyenv

# Linux
./tools/guni_service.sh {start|stop|restart}
```

# 配置Nginx【可选】

```
PROJECT_DIR=. ./tools/deploy.sh init-nginx-conf
# 按照提示自动生成配置
```
