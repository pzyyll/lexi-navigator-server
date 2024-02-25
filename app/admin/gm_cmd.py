# -*- coding:utf-8 -*-
# @Date: "2024-02-21"
# @Description: flask admin gm cmd


from libs.pyhelper.singleton import SingletonMeta


class GMCommand(metaclass=SingletonMeta):
    def __init__(self):
        pass

    def add_user(self, username, password):
        from app.admin.db import DB
        DB().add_user(username, password)

    def delete_user(self, *args, **kwargs):
        pass
