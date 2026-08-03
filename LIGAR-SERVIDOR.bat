@echo off
title Myboot - Servidor de imagens

rem ===================================================================
rem   LIGAR SERVIDOR
rem
rem   Duplo clique neste arquivo. Nada para digitar.
rem
rem   Se um dia voce mudar a pasta das imagens, troque a linha abaixo.
rem ===================================================================

set "IMAGENS=C:\imagens"

rem ===================================================================

rem --- Precisa de administrador ---
net session >nul 2>&1
if %errorlevel% equ 0 goto :ADMIN_OK

echo.
echo   Preciso de permissao de administrador.
echo   Confirme na janela que vai aparecer.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:ADMIN_OK

if not exist "%IMAGENS%" (
    cls
    echo.
    echo   [ERRO] A pasta das imagens nao existe:
    echo          %IMAGENS%
    echo.
    echo   Coloque as imagens la, ou edite este arquivo e troque
    echo   a linha  set "IMAGENS=..."  pelo caminho certo.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ferramentas\servidor-local.ps1" -Pasta "%IMAGENS%" -AbrirFirewall

echo.
echo   O servidor foi encerrado.
echo.
pause
