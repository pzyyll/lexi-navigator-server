# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: utils for flask app

import os
from libs.pyhelper.path_helper import PathHelper
from libs.pyhelper.singleton import SingletonMeta


class GlobalPathHelper(PathHelper, metaclass=SingletonMeta):
    pass


path_helper = GlobalPathHelper()


def get_flask_env(name, default=None):
    return os.environ.get(name, default)