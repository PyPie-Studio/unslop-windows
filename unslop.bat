@echo off
setlocal enabledelayedexpansion
title unslop-windows Launcher

:: Change directory to script directory
cd /d "%~dp0"

:: Ensure unslop.ps1 exists locally; auto-download from GitHub if standalone
if not exist "%~dp0unslop.ps1" (
    echo [unslop] unslop.ps1 not found locally.
    echo [unslop] Downloading latest unslop.ps1 from PyPie-Studio/unslop-windows...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/PyPie-Studio/unslop-windows/main/unslop.ps1' -OutFile '%~dp0unslop.ps1'"
    if not exist "%~dp0unslop.ps1" (
        echo [ERROR] Failed to download unslop.ps1. Check your internet connection.
        pause
        exit /b 1
    )
    echo [unslop] Download complete.
    echo.
)

:: ------------------------------------------------------------
:: CLI PASS-THROUGH MODE
:: If arguments are passed via command-line, bypass menu
:: ------------------------------------------------------------
if not "%~1"=="" (
    echo "%*" | findstr /i /c:"-DryRun" /c:"-WhatIf" >nul
    if !errorlevel! equ 0 (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" %*
        exit /b !errorlevel!
    )

    if "%~1"=="-RunDirect" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1"
        if !errorlevel! equ 100 exit /b 0
        echo.
        pause
        goto :menu
    )

    net session >nul 2>&1
    if !errorlevel! neq 0 (
        echo Requesting Administrator privileges...
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
        exit /b
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" %*
    if !errorlevel! equ 100 exit /b 0
    exit /b !errorlevel!
)

:: ------------------------------------------------------------
:: INTERACTIVE MENU MODE (Double-click)
:: ------------------------------------------------------------
:menu
cls
echo ============================================================
echo   unslop-windows (v1.0.3) - PyPie Studio
echo   Universal Windows 11 24H2 / 25H2 Debloat ^& Privacy Hardener
echo ============================================================
echo.
echo   [1] Full Debloat (Purge OneDrive, telemetry ^& bloatware)
echo   [2] Dry-Run Audit (Inspect changes safely, no modifications)
echo   [3] Debloat, but Keep Microsoft To-Do
echo   [4] Debloat, but Keep Xbox ^& Gaming Services
echo   [5] Debloat, but Keep OneDrive
echo   [6] Debloat + Enable Classic Context Menu
echo   [7] Custom Flags (Enter custom parameter combinations)
echo   [8] Full Restore / Undo (Revert all changes back to defaults)
echo   [0] Exit
echo.
echo ============================================================
set /p "choice=Select an option [0-8]: "

if "%choice%"=="0" exit /b
if "%choice%"=="1" set "ARGS=" & goto :run
if "%choice%"=="2" set "ARGS=-DryRun" & goto :run_dry
if "%choice%"=="3" set "ARGS=-KeepTodos" & goto :run
if "%choice%"=="4" set "ARGS=-KeepXbox" & goto :run
if "%choice%"=="5" set "ARGS=-KeepOneDrive" & goto :run
if "%choice%"=="6" set "ARGS=-ClassicContextMenu" & goto :run
if "%choice%"=="7" goto :custom
if "%choice%"=="8" set "ARGS=-Undo" & goto :run

echo Invalid selection.
timeout /t 2 >nul
goto :menu

:custom
echo.
echo Examples: -KeepTodos -KeepXbox
echo           -KeepTodos -ClassicContextMenu
echo           -KeepTodos -NoRestart
echo           -Undo -DryRun
echo.
set /p "ARGS=Enter parameter flags: "
if "%ARGS%"=="" goto :menu
echo "%ARGS%" | findstr /i /c:"-DryRun" /c:"-WhatIf" >nul
if !errorlevel! equ 0 goto :run_dry
goto :run

:run_dry
echo.
echo Starting Dry-Run Audit (Non-Elevated)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" !ARGS!
echo.
pause
goto :menu

:run
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo Administrator privileges required. Prompting for UAC elevation...
    if defined ARGS (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '!ARGS!' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '-RunDirect' -Verb RunAs"
    )
    exit /b
)

echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" !ARGS!
if !errorlevel! equ 100 exit /b 0
echo.
pause
goto :menu
