# -*- coding:utf-8 -*-
# @Date: "2024-02-17"
# @Description: flask app forms

from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField
from wtforms.validators import DataRequired
from flask_wtf.recaptcha import RecaptchaField


class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    recaptcha = RecaptchaField()
    submit = SubmitField('Login')
