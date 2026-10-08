@echo off
echo Iniciando CatalogoExpresso Bypass Server...
cd /d "%~dp0"
python server.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERRO ao iniciar. Verifique se Python 3 esta instalado.
    pause
)
