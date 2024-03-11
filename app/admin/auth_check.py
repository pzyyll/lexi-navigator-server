# -*- coding:utf-8 -*-
# @Date: "2024-02-19"
# @Description: auth check

import jwt
import time
import logging
from flask_httpauth import HTTPTokenAuth

logger = logging.getLogger(__name__)
token_auth = HTTPTokenAuth(scheme='Bearer')


def jwt_encode(user_name, token_cnt=0):
    from app.admin.db import db
    from run import app
    payload = {
        'user': user_name,
        'ts': time.time(),
        'cnt': token_cnt,
    }
    return jwt.encode(payload,
                      app.config.get('SECRET_KEY', '123456'),
                      algorithm='HS256')


def jwt_check(token, username=None):
    from run import app
    from app.models import User
    try:
        token_decode = jwt.decode(token,
                                  app.config.get('SECRET_KEY', '123456'),
                                  algorithms='HS256')
        token_user = token_decode['user']
    except Exception as e:
        logger.error('jwt_check error: %s|%s', str(e), token)
        return False
    user = User.query.filter_by(username=token_user).first()
    if not user:
        logger.warning('jwt_check token user invalid: %s', token_user)
        return False
    # Detect if token is expired (new token count +1)
    if user.auth_key != str(token_decode['cnt']):
        logger.warning('jwt_check token invalid: %s|%s', token_user, token)
        return False
    return True


@token_auth.verify_token
def verify_token(token):
    return jwt_check(token)
