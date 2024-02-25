# -*- coding:utf-8 -*-
# @Date: "2024-02-17"
# @Description: flask app model

from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from app.admin.db import db


class User(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    passwd = db.Column(db.String(256), unique=False, nullable=False)
    auth_key = db.Column(db.String(1000), unique=False, nullable=True)

    def set_passwd(self, passwd):
        self.passwd = generate_password_hash(passwd)

    def check_passwd(self, passwd):
        return check_password_hash(self.passwd, passwd)
