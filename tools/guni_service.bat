@echo off
setlocal

set NAME=ts_svr
set TOOLS_DIR=%~dp0
set PROJECT_DIR=%TOOLS_DIR%\..\..
set WORK_DIR=%PROJECT_DIR%\ts_server
set GUNICORN_PATH=%WORK_DIR%\.venv\Scripts\gunicorn
set APP_MODULE=run:app
set PIDFILE=%WORK_DIR%\%NAME%.pid
set CONFIG=%WORK_DIR%\conf\gunicorn_config.py

if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
echo Usage: %0 {start|stop|restart}
goto end

:start
echo Starting %NAME% as %USERNAME%
start "" "%GUNICORN_PATH%" -c "%CONFIG%" %APP_MODULE% -D --pid %PIDFILE%
goto end

:stop
if exist "%PIDFILE%" (
    for /F "tokens=*" %%A in (%PIDFILE%) do (
        taskkill /PID %%A /F
    )
    del /F "%PIDFILE%"
    echo Stopping %NAME%
) else (
    echo %NAME% is not running
)
goto end

:restart
call :stop
call :start
goto end

:end
endlocal
