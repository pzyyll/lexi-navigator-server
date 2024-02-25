# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: run

# import debugpy
# debugpy.listen(('localhost', 5678))
# debugpy.wait_for_client()

import os
import atexit


from utils import path_helper, get_flask_env
path_helper.set_exec_file(__file__)

from dotenv import load_dotenv
load_dotenv(path_helper.get_path('.flaskenv'))
load_dotenv()

from libs.pyhelper.logging_helper import init_logging

LOG_FILE = os.environ.get('LOG_FILE', 'output.log')
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'DEBUG')
init_logging(LOG_FILE, LOG_LEVEL,
    format='%(asctime)s - %(threadName)s - %(thread)d - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)


from app import create_app
app = create_app(get_flask_env('FLASK_APP_CONFIG', 'config.py'))


with app.app_context():
    from app.admin.db import db
    db.create_all()


@app.shell_context_processor
def make_shell_context():
    from app.models import User
    from app.admin.gm_cmd import GMCommand
    from app.admin.db import db
    return {'db': db, 'User': User, 'gm': GMCommand()}


def exit_clear():
    from libs.pyhelper.proxy_helper import ProxyWorkerPoolManager

    ProxyWorkerPoolManager().shutdown()


if __name__ == '__main__':
    atexit.register(exit_clear)
    app.run(debug=True)