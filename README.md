# LexiNavigator Server

# 启动脚本

```shell

# 初始化运行环境
PROJECT_DIR=. ./tools/deploy.sh init-pyenv

# Linux
./tools/guni_service.sh {start|stop|restart}
```

# 快速部署

```
curl -s https://raw.githubusercontent.com/pzyyll/lexi-navigator-server/main/tools/deploy.sh | bash -s -- init
```

## 必要的配置修改

- 翻译API配置：app_data/conf/translate_api.conf

    ```
    {
        "google": {
            "project_id": "project-id",
            "auth_key": "path-to-auth-key.json"
        },
        "baidu": {
            "app_id": "baidu-api-auth-id",
            "auth_key": "baidu-api-auth-key"
        }
    }
    ```

- Fask应用和reCaptcha的密钥配置：app_data/conf/flask_config.py

    ```
    ...
    SECRET_KEY = 'random key: openssl rand -hex 32'
    RECAPTCHA_PUBLIC_KEY = "google-recaptcha-public-key"
    RECAPTCHA_PRIVATE_KEY = "oogle-recaptcha-private-key"
    ...
    ```

# 配置Nginx【可选】

```
PROJECT_DIR=. ./tools/deploy.sh init-nginx-conf
# 按照提示自动生成配置
```