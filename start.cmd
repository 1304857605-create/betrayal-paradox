@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================
echo   背叛者悖论 - 本地网页
echo   地址: http://localhost:8083
echo   关闭这个窗口即可停止服务
echo ============================================
start "" http://localhost:8083
python -m http.server 8083
pause
