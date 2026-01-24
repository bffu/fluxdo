@echo off
REM FluxDO 发版脚本 (Windows)
REM 用法: scripts\release.bat [版本号] [--pre]
REM 示例: scripts\release.bat 0.1.0
REM       scripts\release.bat 0.1.0-beta --pre

setlocal enabledelayedexpansion

REM 检查参数
if "%~1"=="" (
    echo [ERROR] 请指定版本号，例如: scripts\release.bat 0.1.0
    exit /b 1
)

set VERSION=%~1
set IS_PRERELEASE=false

if "%~2"=="--pre" (
    set IS_PRERELEASE=true
)

REM 提取主版本号
for /f "tokens=1 delims=-" %%a in ("%VERSION%") do set VERSION_NAME=%%a

REM 检查是否在 git 仓库中
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 当前目录不是 git 仓库
    exit /b 1
)

REM 检查是否有未提交的更改
git diff-index --quiet HEAD -- >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 存在未提交的更改，请先提交或暂存
    exit /b 1
)

REM 检查当前分支
for /f "tokens=*" %%a in ('git branch --show-current') do set CURRENT_BRANCH=%%a
if not "!CURRENT_BRANCH!"=="main" (
    echo [WARN] 当前不在 main 分支 ^(当前: !CURRENT_BRANCH!^)
    set /p CONTINUE="是否继续? (y/N) "
    if /i not "!CONTINUE!"=="y" exit /b 1
)

REM 检查 tag 是否已存在
git rev-parse "v%VERSION%" >nul 2>&1
if not errorlevel 1 (
    echo [ERROR] Tag v%VERSION% 已存在
    exit /b 1
)

REM 读取当前版本
for /f "tokens=2 delims=: " %%a in ('findstr "^version:" pubspec.yaml') do set CURRENT_VERSION=%%a
for /f "tokens=1 delims=+" %%a in ("!CURRENT_VERSION!") do set CURRENT_VERSION=%%a

echo [INFO] 当前版本: !CURRENT_VERSION!
echo [INFO] 新版本: %VERSION%

REM 生成 Version Code
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do set DATE=%%c%%a%%b
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set TIME=%%a%%b
set VERSION_CODE=%DATE%%TIME: =0%

echo [INFO] Version Code: !VERSION_CODE!

REM 确认发版
echo.
echo ==========================================
echo   发版信息
echo ==========================================
echo 版本号: %VERSION%
echo Version Name: %VERSION_NAME%
echo Version Code: !VERSION_CODE!
if "%IS_PRERELEASE%"=="true" (
    echo 类型: 预发布版
) else (
    echo 类型: 稳定版
)
echo 分支: !CURRENT_BRANCH!
echo ==========================================
echo.

set /p CONFIRM="确认发版? (y/N) "
if /i not "!CONFIRM!"=="y" (
    echo [INFO] 已取消
    exit /b 0
)

REM 更新 pubspec.yaml
echo [INFO] 更新 pubspec.yaml...
powershell -Command "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %VERSION_NAME%+!VERSION_CODE!' | Set-Content pubspec.yaml"

REM 提交版本号变更
echo [INFO] 提交版本号变更...
git add pubspec.yaml
git commit -m "chore: bump version to %VERSION%" -m "" -m "Co-Authored-By: Release Script <noreply@github.com>"

REM 推送到远程
echo [INFO] 推送到远程仓库...
git push

REM 创建并推送 tag
echo [INFO] 创建 tag v%VERSION%...
git tag -a "v%VERSION%" -m "Release v%VERSION%"

echo [INFO] 推送 tag...
git push origin "v%VERSION%"

REM 完成
echo.
echo ==========================================
echo [SUCCESS] 发版成功!
echo ==========================================
echo Tag: v%VERSION%
echo GitHub Actions: https://github.com/Lingyan000/fluxdo/actions
echo Releases: https://github.com/Lingyan000/fluxdo/releases
echo ==========================================
echo.

if "%IS_PRERELEASE%"=="true" (
    echo [INFO] 这是预发布版，不会生成 Changelog
) else (
    echo [INFO] 稳定版会自动生成 Changelog 并提交到 main 分支
)

endlocal
