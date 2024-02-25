# -*- coding:utf-8 -*-
# @Date: "2024-02-18"
# @Description: flask admin

from flask import Blueprint


admin_bp = Blueprint('admin_view', __name__, url_prefix='/admin')


from app.admin import routes
