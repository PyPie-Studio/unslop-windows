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
        if !errorlevel! neq 0 (
            echo [ERROR] UAC elevation was cancelled or denied.
            exit /b 1
        )
        exit /b 0
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
echo   unslop-windows (v1.1.1) - PyPie Studio
echo   Universal Windows 11 23H2 / 24H2 / 25H2 Debloat ^& Privacy
echo ============================================================
echo.
echo   [1] Full Debloat (Purge OneDrive, telemetry, and bloatware)
echo   [2] Gamer Preset (Debloat, but Keep Xbox ^& Gaming Services)
echo   [3] Productivity Preset (Debloat, but Keep OneDrive ^& To-Do)
echo   [4] Interactive Toggles (Configure custom feature combinations)
echo   [5] Safe Dry-Run Audit (Inspect changes safely, zero modifications)
echo   [6] Full Restore / Undo (Revert all tweaks back to defaults)
echo   [7] Custom CLI Flags (Manually enter parameter switches)
echo   [0] Exit
echo.
echo ============================================================
set /p "choice=Select an option [0-7]: "

if "%choice%"=="0" exit /b
if "%choice%"=="1" set "ARGS=" & goto :run
if "%choice%"=="2" set "ARGS=-KeepXbox" & goto :run
if "%choice%"=="3" set "ARGS=-KeepOneDrive -KeepTodos" & goto :run
if "%choice%"=="4" goto :toggles
if "%choice%"=="5" set "ARGS=-DryRun" & goto :run_dry
if "%choice%"=="6" set "ARGS=-Undo" & goto :run
if "%choice%"=="7" goto :custom

echo Invalid selection.
timeout /t 2 >nul
goto :menu

:: ------------------------------------------------------------
:: INTERACTIVE TOGGLES SUB-MENU
:: ------------------------------------------------------------
:toggles
set "TOGGLE_XBOX=0"
set "TOGGLE_ONEDRIVE=0"
set "TOGGLE_TODOS=0"
set "TOGGLE_CLASSIC=0"
set "TOGGLE_DRYRUN=0"

:toggles_menu
cls
echo ============================================================
echo   unslop-windows - Interactive Feature Toggles
echo ============================================================
echo.
if "!TOGGLE_XBOX!"=="1" ( echo   [1] Preserve Xbox ^& Gaming Services     : [ ON  ] ) else ( echo   [1] Preserve Xbox ^& Gaming Services     : [ OFF ] )
if "!TOGGLE_ONEDRIVE!"=="1" ( echo   [2] Preserve Microsoft OneDrive         : [ ON  ] ) else ( echo   [2] Preserve Microsoft OneDrive         : [ OFF ] )
if "!TOGGLE_TODOS!"=="1" ( echo   [3] Preserve Microsoft To-Do            : [ ON  ] ) else ( echo   [3] Preserve Microsoft To-Do            : [ OFF ] )
if "!TOGGLE_CLASSIC!"=="1" ( echo   [4] Enable Classic Context Menu         : [ ON  ] ) else ( echo   [4] Enable Classic Context Menu         : [ OFF ] )
if "!TOGGLE_DRYRUN!"=="1" ( echo   [5] Dry-Run Inspection Mode (Read-Only) : [ ON  ] ) else ( echo   [5] Dry-Run Inspection Mode (Read-Only) : [ OFF ] )
echo.
echo ============================================================
echo   [R] Run with selected configuration
echo   [B] Back to Main Menu
echo ============================================================
set /p "tchoice=Select an option to toggle, or [R] to run: "

if /i "!tchoice!"=="b" goto :menu
if /i "!tchoice!"=="1" (
    if "!TOGGLE_XBOX!"=="1" ( set "TOGGLE_XBOX=0" ) else ( set "TOGGLE_XBOX=1" )
    goto :toggles_menu
)
if /i "!tchoice!"=="2" (
    if "!TOGGLE_ONEDRIVE!"=="1" ( set "TOGGLE_ONEDRIVE=0" ) else ( set "TOGGLE_ONEDRIVE=1" )
    goto :toggles_menu
)
if /i "!tchoice!"=="3" (
    if "!TOGGLE_TODOS!"=="1" ( set "TOGGLE_TODOS=0" ) else ( set "TOGGLE_TODOS=1" )
    goto :toggles_menu
)
if /i "!tchoice!"=="4" (
    if "!TOGGLE_CLASSIC!"=="1" ( set "TOGGLE_CLASSIC=0" ) else ( set "TOGGLE_CLASSIC=1" )
    goto :toggles_menu
)
if /i "!tchoice!"=="5" (
    if "!TOGGLE_DRYRUN!"=="1" ( set "TOGGLE_DRYRUN=0" ) else ( set "TOGGLE_DRYRUN=1" )
    goto :toggles_menu
)
if /i "!tchoice!"=="r" goto :toggles_run

echo Invalid selection.
timeout /t 1 >nul
goto :toggles_menu

:toggles_run
set "ARGS="
if "!TOGGLE_XBOX!"=="1" set "ARGS=!ARGS! -KeepXbox"
if "!TOGGLE_ONEDRIVE!"=="1" set "ARGS=!ARGS! -KeepOneDrive"
if "!TOGGLE_TODOS!"=="1" set "ARGS=!ARGS! -KeepTodos"
if "!TOGGLE_CLASSIC!"=="1" set "ARGS=!ARGS! -ClassicContextMenu"
if "!TOGGLE_DRYRUN!"=="1" (
    set "ARGS=!ARGS! -DryRun"
    goto :run_dry
)
goto :run

:: ------------------------------------------------------------
:: CUSTOM CLI PARAMETERS
:: ------------------------------------------------------------
:custom
echo.
echo Examples: -KeepTodos -KeepXbox
echo           -KeepOneDrive -ClassicContextMenu
echo           -KeepTodos -NoRestart
echo           -Undo -DryRun
echo.
set /p "ARGS=Enter parameter flags: "
if "%ARGS%"=="" goto :menu
echo "%ARGS%" | findstr /i /c:"-DryRun" /c:"-WhatIf" >nul
if !errorlevel! equ 0 goto :run_dry
goto :run

:: ------------------------------------------------------------
:: DRY-RUN EXECUTION (Non-Elevated with Anti-Amnesia Prompt)
:: ------------------------------------------------------------
:run_dry
echo.
echo Starting Dry-Run Audit (Non-Elevated)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" !ARGS!
echo.
echo Audit complete. Review the inspection results above or check the log file.
echo Press [Enter] to return to the menu, or [Q] to exit...
set /p "postchoice="
if /i "!postchoice!"=="q" exit /b 0
goto :menu

:: ------------------------------------------------------------
:: LIVE EXECUTION (Elevated)
:: ------------------------------------------------------------
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
    if !errorlevel! neq 0 (
        echo.
        echo [ERROR] UAC elevation was cancelled or denied.
        echo Administrator privileges are required to apply system modifications.
        echo.
        pause
        goto :menu
    )
    exit /b 0
)

echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0unslop.ps1" !ARGS!
if !errorlevel! equ 100 exit /b 0
echo.
pause
goto :menu
