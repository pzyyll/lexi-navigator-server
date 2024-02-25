# -*- coding:utf-8 -*-
# @Date: "2024-02-17"
# @Description: flask app routes

import logging

from flask import render_template, redirect, url_for, request, jsonify
from app.index import index_bp
from app import limiter

from flask_login import login_required

logger = logging.getLogger(__name__)


@index_bp.route('/', methods=['GET'])
@login_required
def root_default_request():
    return render_template('base.html')


def get_translate_text(text, source_lang_code=None, target_lang_code=None, api_type=None):
    from app.translate_api import translate_api
    try:
        with translate_api.api_type_context(api_type):
            result = translate_api.translate_text(text, target_lang_code, from_lang=source_lang_code)
            api_type = result.get('from_api_type') or api_type
            translate_text = result.get('translate_text', "")
            logger.debug('processed_text: %s', result)
    except Exception as exc:
        translate_text = "An error occurred in the translation 🤔"
        api_type = "error occurred😩"
        logger.debug('processed_text err: %s', str(exc))
    return translate_text, api_type


@index_bp.route('/translate', methods=['GET'])
@login_required
def translate_request():
    request_data = request.args
    logger.debug('request_data: %s', request_data)
    text = request_data.get('text', '')
    if text and not text.isspace():
        source_lang_code = request_data.get('sl')
        target_lang_code = request_data.get('tl')
        api_type = request_data.get('at', "")

        translate_text, api_type = get_translate_text(text, source_lang_code, target_lang_code, api_type)

        return render_template(
            'translate.html',
            source_text=text,
            target_text=translate_text,
            extra_content=api_type.capitalize())
    return render_template('translate.html')


@index_bp.route('/translate/translate_text', methods=['POST'])
@login_required
@limiter.limit("2 per second")
def translate_text():
    # from app.api.translate import gl_proxy_apis
    data = request.json
    text = data.get('text', '')
    api_type = data.get('api_type', "")

    translate_text, api_type = get_translate_text(text, api_type=api_type)
    redirect_url = url_for('index.translate_request', text=text, at=api_type)

    return jsonify({'redirect_url': redirect_url, 'translate_text': translate_text, 'api_type': api_type})
