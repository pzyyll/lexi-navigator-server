# -*- coding:utf-8 -*-
# @Date: "2024-02-17"
# @Description: api routes

import logging

from http import HTTPStatus
from flask import request, make_response, jsonify


from app.api import api
from app.admin.auth_check import token_auth
from app import limiter

logger = logging.getLogger(__name__)

from app.translate_api import translate_api


@api.route('/translate', methods=['POST'])
@limiter.limit("5 per second")
@token_auth.login_required
def handle_translate_request():
    from google.protobuf import json_format
    from common.proto.translate_pb2 import TranslateTextRequest

    requestMsg = json_format.ParseDict(request.get_json(), TranslateTextRequest())
    logger.debug("requestMsg: %s", requestMsg)
    if not requestMsg.data:
        return jsonify({'code': HTTPStatus.BAD_REQUEST, 'msg': 'Invalid request data.'}), HTTPStatus.BAD_REQUEST
    api_type = requestMsg.data.api_type

    try:
        with translate_api.api_type_context(api_type):
            result = translate_api.translate_text(requestMsg.data.text, requestMsg.data.target_lang_code)
            logger.debug("result: %s", result)
            response_body = {
                'code': HTTPStatus.OK,
                'result': result,
                **({'from_api_type': result["from_api_type"]} if not api_type else {})
            }
            return jsonify(response_body), HTTPStatus.OK
    except Exception as e:
        logger.error("handle_translate_request error: %s", e)
        return jsonify({
            'code': HTTPStatus.INTERNAL_SERVER_ERROR,
            'msg': 'Server error.'
            }), HTTPStatus.INTERNAL_SERVER_ERROR
