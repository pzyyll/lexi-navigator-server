# -*- coding:utf-8 -*-
# @Date: "2024-02-15"
# @Description: APIs Proxy

import logging
from collections import OrderedDict

from libs.pyhelper.singleton import ABCSingletonMeta
from libs.pyhelper.proxy_helper import ProxyWorkerPool

from .base_api import BaseTranslateAPI, TranslateError
from .google_api import GoogleAPI
from .baidu_api import BaiduAPI


class ApiTypeContext(object):
    def __init__(self, api, api_type):
        self.api_type = api_type
        self.api = api

    def __enter__(self):
        self.api.set_api_type(self.api_type)
        return self.api

    def __exit__(self, exc_type, exc_value, traceback):
        self.api.set_api_type(None)


class TranslateAPIProxyExecutor(BaseTranslateAPI):
    @classmethod
    def create(cls, proxy, proxy_cls, *args, **kwargs):
        proxy_executor = cls()
        proxy_executor._set_worker_info(proxy, proxy_cls, *args, **kwargs)
        return proxy_executor

    def init(self, conf):
        super().init(conf)
        self._proxy_worker = None
        self.proxy = None
        self.proxy_cls = None
        self.proxy_cls_args = ()
        self.proxy_cls_kwargs = {}


    def _set_worker_info(self, proxy, proxy_cls, *proxy_cls_args, **proxy_cls_kwargs):
        self.proxy = proxy
        self.proxy_cls = proxy_cls
        self.proxy_cls_args = proxy_cls_args
        self.proxy_cls_kwargs = proxy_cls_kwargs

    def _init_worker(self):
        if self.proxy and self.proxy_cls:
            # 需要代理访问的API，创建一个新的代理进程池处理，代理需要设置全局的socket.socket避免多线程下代理设置污染主进程
            self._proxy_worker = ProxyWorkerPool()
            self._proxy_worker.set_proxy_info(self.proxy, self.proxy_cls, *self.proxy_cls_args, **self.proxy_cls_kwargs)

    @property
    def proxy_worker(self):
        if not self._proxy_worker:
            self._init_worker()
        return self._proxy_worker

    def _execute(self, func, *args, **kwargs):
        if self.proxy_worker:
            result = self.proxy_worker.submit(func, *args, **kwargs)
            return result.result()

    def translate_text(self, text, to_lang=None, **kwargs):
        return self._execute("translate_text", text, to_lang, **kwargs)

    def detect_language(self, text, **kwargs):
        return self._execute("detect_language", text, **kwargs)

    def list_languages(self, display_language_code=None, **kwargs):
        return self._execute("list_languages", display_language_code, **kwargs)


class GlobalGoobleAPI(GoogleAPI, metaclass=ABCSingletonMeta):
    pass


class ProxyAPIs(BaseTranslateAPI):
    GOOGLE = 'google'
    BAIDU = 'baidu'
    
    API_TYPE = OrderedDict({
        GOOGLE: GlobalGoobleAPI,
        BAIDU: BaiduAPI
    })

    @property
    def _default_api(self):
        return self._apis.get(self.api_type, None)

    def init(self, conf):
        super(ProxyAPIs, self).init(conf)
        self._apis = OrderedDict({})
        for api_type, api_class in self.API_TYPE.items():
            api_conf = self.conf.get(api_type, {})
            self._apis[api_type] = (
                TranslateAPIProxyExecutor.create(api_conf.get("proxy"), api_class, api_conf)
                if "proxy" in api_conf else api_class(api_conf)
            )

    def set_api_type(self, api_type=None):
        super(ProxyAPIs, self).set_api_type(None)
        if api_type and api_type not in self._apis:
            raise ValueError('Invalid API type.')

    def api_type_context(self, api_type):
        from contextlib import nullcontext
        return ApiTypeContext(self, api_type) if api_type else nullcontext()

    def detect_language(self, text, **kwargs):
        if self._default_api:
            try:
                return self._default_api.detect_language(text, **kwargs)
            except Exception as exc:
                raise TranslateError('Default API failed to detect language.') from exc

        for _, api in self._apis.items():
            try:
                return api.detect_language(text, **kwargs)
            except Exception as exc:
                logging.warning(f'API {api} failed to detect language: {exc}')
                continue
        raise TranslateError('All APIs failed to detect language.')

    def translate_text(self, text, to_lang=None, **kwargs):
        if self._default_api:
            try:
                return self._default_api.translate_text(text, to_lang, **kwargs)
            except Exception as exc:
                raise TranslateError('Default API failed to translate text.') from exc

        for api_type, api in self._apis.items():
            try:
                result = api.translate_text(text, to_lang, **kwargs)
                result['from_api_type'] = api_type
                return result
            except Exception as e:
                logging.warning(f'API {api} failed to translate text: {e}')
                continue
        raise TranslateError('All APIs failed to translate text.')

    def list_languages(self, display_language_code=None):
        if self._default_api:
            try:
                return self._default_api.list_languages(display_language_code)
            except Exception as exc:
                raise TranslateError('Default API failed to list languages.') from exc

        for api in self._apis.items():
            try:
                return api.list_languages(display_language_code)
            except Exception as e:
                logging.warning(f'API {api} failed to list languages: {e}')
                continue
        raise TranslateError('All APIs failed to list languages.')
