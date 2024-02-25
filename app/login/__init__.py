# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: login

from flask import Blueprint

login_bp = Blueprint('login', __name__)

from app.login import routes