# -*- coding:utf-8 -*-
# @Date: "2022-11-01"
# @Description: base api

import abc
from typing import TypedDict, List

class TranslateError(Exception):
    pass


class DetectLanguage(TypedDict):
    language_code: str
    confidence: float


class TranslateResult(TypedDict):
    translate_text: str
    detected_language_code: str


class Language(TypedDict):
    display_name: str
    language_code: str


class TranslateAPIProto(abc.ABC):
    @abc.abstractmethod
    def detect_language(self, text, **kwargs) -> DetectLanguage:
        '''
        Detects the language of the given text using an external API.
        
        Parameters:
        - text (str): The text for language detection.
        - kwargs: Optional arguments, including 'mime_type' for specifying the MIME type of the text.
        
        Returns:
        - dict: A dictionary containing the detected language code and the confidence level.
            eg. {'language_code': "en", 'confidence': 0.9}
        '''
        pass

    @abc.abstractmethod
    def translate_text(self, text, to_lang=None, **kwargs) -> TranslateResult:
        '''
        Translate text to target language
        Parameters:
        - text (str): The text to be translated.
        - to_lang (str): The target language code.
        - kwargs: Optional arguments, including 'from_lang' for specifying the source language code.
        Returns:
        - dict: A dictionary containing the translated text and the detected language code.
            eg. {'translate_text': translated_text, 'detected_language_code': "en"}
        '''
        pass

    @abc.abstractmethod
    def list_languages(self, display_language_code=None, **kwargs) -> List[Language]:
        '''
        Retrieves a list of supported languages from an external API.
        
        Parameters:
        - display_language_code (str, optional):
            If provided, the display names of the languages are included in the output.
        
        Returns:
        - list:
            A list of dictionaries, each representing a supported language.
            Each dictionary includes a language code, and optionally,
            a display name if display_language_code is provided.
            eg. [{'display_name': "英语", 'language_code': "en"}]
        '''
        pass


class BaseTranslateAPI(TranslateAPIProto):
    def __init__(self, conf=None):
        self.init(conf)

    def init(self, conf):
        self.api_type = None
        self.conf = conf or {}

    def set_api_type(self, api_type=None):
        self.api_type = api_type
