# -*- coding:utf-8 -*-
# @Date: "2024-02-21"
# @Description: flask admin db

from libs.pyhelper.singleton import SingletonMeta
from flask_sqlalchemy import SQLAlchemy


class DB(metaclass=SingletonMeta):
    def __init__(self):
        self.db = SQLAlchemy()

    def init_app(self, app):
        self.db.init_app(app)
        return self.db

    def __getattr__(self, name):
        return getattr(self.db, name)

    def query_user_by_name(self, username):
        from app.models import User
        return User.query.filter_by(username=username).first()

    def add_user(self, username, password):
        from app.models import User
        if self.query_user_by_name(username) is not None:
            raise Exception('user exists')
        user = User(username=username)
        user.set_passwd(password)
        self.db.session.add(user)
        self.db.session.commit()

db = DB()