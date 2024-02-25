# -*- coding:utf-8 -*-
# @Date: "2024-02-17"
# @Description: login

from flask import render_template, redirect, url_for, flash
from flask_login import login_user, logout_user

from app.forms import LoginForm
from app.models import User
from app.login import login_bp

from app import login_manager


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


@login_manager.unauthorized_handler
def unauthorized():
    return redirect(url_for('login.login'))


@login_bp.route('/login', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        if form.recaptcha.errors:
            flash('Invalid reCAPTCHA. Please try again.', 'error')
            return redirect(url_for('login'))
        username = form.username.data
        password = form.password.data
        user = User.query.filter_by(username=username).first()
        if user and user.check_passwd(password):
            login_user(user)
            flash('Login successful!', 'success')
            return redirect(url_for('admin.index'))
        else:
            flash('Invalid username or password', 'error')
    return render_template('login.html', form=form)


@login_bp.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('login.login'))
