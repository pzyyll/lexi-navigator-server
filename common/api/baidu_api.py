# -*- coding:utf-8 -*-
# @Date: "2022-11-01"
# @Description: baidu translate api

import random
import hashlib
import requests
import logging
import six
from .base_api import BaseTranslateAPI as BaseAPI
from .base_api import TranslateError
from .api_utils import simple_random_text_segments

HEADERS = {'Content-Type': 'application/x-www-form-urlencoded'}
API_HOST = 'https://fanyi-api.baidu.com/api/trans/vip/'
DETECT = 'language'
TRANSLATE = 'translate'


class BaiduAPI(BaseAPI):
    def init(self, conf):
        super(BaiduAPI, self).init(conf)
        self.app_id = self.conf.get('app_id', '')
        self.auth_key = self.conf.get('auth_key', '')

    def _make_sign(self, query, salt):
        sign = self.app_id + query + str(salt) + self.auth_key
        return hashlib.md5(sign.encode('utf-8')).hexdigest()

    def _make_salt(self):
        return random.randint(0xffff, 0xffffffff)

    def detect_language(self, text, **kwargs) -> dict:
        salt = self._make_salt()
        sign = self._make_sign(text, salt)
        params = {'appid': self.app_id, 'q': text, 'salt': salt, 'sign': sign}
        url = API_HOST + DETECT
        try:
            r = requests.post(url, params=params, headers=HEADERS, timeout=10)
            result = r.json()
            return {"language_code": result.get('data').get('src')}
        except Exception as e:
            logging.error(f"baidu api _detect_language error: {e}")
            raise Exception(f"baidu api _detect_language error: {e}")

    def translate_text(self, text, to_lang=None, **kwargs) -> dict:
        if not isinstance(text, str) or not text.strip():
            raise ValueError("Text must be a non-empty string.")
        
        if isinstance(text, six.binary_type):
            text = text.decode("utf-8")

        logging.debug(f'translate request text: {text}, params: {kwargs}')

        detected_lang = from_lang = kwargs.get('from_lang', None)
        if not to_lang:
            if not detected_lang:
                detected_lang = self.detect_language(simple_random_text_segments(text)).get('language_code', 'en')
            to_lang = 'en' if 'zh' in detected_lang else 'zh'

        salt = self._make_salt()
        sign = self._make_sign(text, salt)
        url_params = {
            'appid': self.app_id,
            'q': text,
            'from': from_lang or "auto",
            'to': to_lang,
            'salt': salt, 'sign': sign
        }
        url = API_HOST + TRANSLATE
        try:
            r = requests.post(url, params=url_params, headers=HEADERS, timeout=10)
            result = r.json()
            if result.get('error_code'):
                # print('translate error: {}'.format(result.get('error_msg')))
                raise TranslateError(f"translate error: {result.get('error_code')}|{result.get('error_msg')}")
            translate_text = '\n'.join([trans.get('dst') for trans in result.get('trans_result')])
            return {"translate_text": translate_text, "detected_language_code": detected_lang}
        except Exception as e:
            logging.error(f"baidu api _translate_text error: {e}")
            raise TranslateError(f"baidu api _translate_text error: {e}")

    def list_languages(self, display_language_code=None, **kwargs):
        print('baidu api not support list language')
        return None


if __name__ == '__main__':
    conf = {
        "app_id": "20200829000554481",
        "auth_key": "FOTTZrDMIe7EejtZy1SH"
    }
    client = BaiduAPI(conf)
    print(client.detect_language('Hello World! This is 1st paragraph.\nThis is 2nd paragraph.'))
    print(client.translate('Hello World! This is 1st paragraph.\nThis is 2nd paragraph.'))
    print(client.translate('你好，世界！这是第一段。\n这是第二段。'))
