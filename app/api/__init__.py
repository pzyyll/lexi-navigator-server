# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: translate

from flask import Blueprint

api = Blueprint('api', __name__, url_prefix='/api')

from app.api import translate