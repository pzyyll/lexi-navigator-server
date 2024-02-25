# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: index

from flask import Blueprint

index_bp = Blueprint('index', __name__)

from app.index import routes