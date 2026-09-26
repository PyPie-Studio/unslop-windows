@echo off
setlocal enabledelayedexpansion
title unslop-windows Launcher

cd /d "%~dp0"

set "MISSING=0"
if not exist "%~dp0unslop-win11.ps1" set "MISSING=1"
if not exist "%~dp0unslop-win10.ps1" set "MISSING=1"

if "!MISSING!"=="1" (
    echo.
    echo ============================================================
    echo   [ERROR] MISSING REQUIRED SCRIPTS
    echo ============================================================
    echo   unslop-win11.ps1 and/or unslop-win10.ps1 were not found in:
    echo   %~dp0
    echo.
    echo   For your security, unslop-windows will not download code
    echo   dynamically from the internet. Please extract the complete
    echo   release package before running unslop.bat.
    echo ============================================================
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: DETECT HOST WINDOWS OS BUILD
:: ------------------------------------------------------------
set "HOST_BUILD=0"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do (
    set "HOST_BUILD=%%A"
)
if "!HOST_BUILD!"=="0" (
    for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul') do (
        set "HOST_BUILD=%%A"
    )
)

set "HOST_OS=UNKNOWN"
set "HOST_OS_LABEL="
if !HOST_BUILD! geq 22000 (
    set "HOST_OS=WIN11"
    set "HOST_OS_LABEL=Windows 11 (Build !HOST_BUILD!)"
) else if !HOST_BUILD! gtr 0 (
    set "HOST_OS=WIN10"
    set "HOST_OS_LABEL=Windows 10 (Build !HOST_BUILD!)"
)

:: ------------------------------------------------------------
:: CLI PASS-THROUGH MODE
:: If arguments are passed via command-line, bypass menu
:: ------------------------------------------------------------
if not "%~1"=="" (
    set "TARGET_SCRIPT=unslop-win11.ps1"
    set "OS_MODE=WIN11"

    :: Validate arguments against strict switch whitelist
    for %%A in (%*) do (
        set "ARG_VALID=0"
        for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -RunDirect -FromMenu -Win11 -Win10 -SkipBuildCheck) do (
            if /i "%%~A"=="%%V" set "ARG_VALID=1"
        )
        if "!ARG_VALID!"=="0" (
            echo.
            echo [ERROR] Unrecognized or illegal parameter switch: "%%~A"
            echo Allowed flags: -Undo, -DryRun, -WhatIf, -KeepXbox, -KeepOneDrive, -KeepTodos, -KeepSysMain, -KeepSearch, -KeepPhoneLink, -KeepMail, -KeepClock, -KeepSpotify, -KeepTeams, -KeepStoreAutoUpdate, -ClassicContextMenu, -LeftTaskbar, -ExcludeWUDrivers, -KeepDefenderDefaults, -NoRestart, -ForceRestart, -Win11, -Win10, -SkipBuildCheck
            exit /b 1
        )
        if /i "%%~A"=="-Win10" (
            set "TARGET_SCRIPT=unslop-win10.ps1"
            set "OS_MODE=WIN10"
        )
        if /i "%%~A"=="-Win11" (
            set "TARGET_SCRIPT=unslop-win11.ps1"
            set "OS_MODE=WIN11"
        )
    )

    :: Check for OS mismatch in CLI mode
    if "!OS_MODE!"=="WIN10" if "!HOST_OS!"=="WIN11" echo [WARNING] OS Mismatch: Running on Windows 11 [Build !HOST_BUILD!], but Windows 10 mode [-Win10] was specified.
    if "!OS_MODE!"=="WIN11" if "!HOST_OS!"=="WIN10" echo [WARNING] OS Mismatch: Running on Windows 10 [Build !HOST_BUILD!], but Windows 11 mode [-Win11] was specified.

    :: Check if invoked from interactive menu
    set "IS_FROM_MENU=0"
    set "FORWARD_ARGS="
    for %%A in (%*) do (
        if /i "%%~A"=="-FromMenu" (
            set "IS_FROM_MENU=1"
        ) else if /i "%%~A"=="-RunDirect" (
            set "IS_FROM_MENU=1"
        ) else if /i "%%~A"=="-Win10" (
            REM Skip adding it to FORWARD_ARGS
        ) else if /i "%%~A"=="-Win11" (
            REM Skip adding it to FORWARD_ARGS
        ) else (
            set "FORWARD_ARGS=!FORWARD_ARGS! %%~A"
        )
    )

    :: Validate forwarded arguments against strict target script switch whitelist
    if defined FORWARD_ARGS (
        for %%A in (!FORWARD_ARGS!) do (
            set "ARG_VALID=0"
            for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
                if /i "%%~A"=="%%V" set "ARG_VALID=1"
            )
            if "!ARG_VALID!"=="0" (
                echo.
                echo [ERROR] Unrecognized or illegal parameter switch in forwarded arguments: "%%~A"
                echo Allowed flags: -Undo, -DryRun, -WhatIf, -KeepXbox, -KeepOneDrive, -KeepTodos, -KeepSysMain, -KeepSearch, -KeepPhoneLink, -KeepMail, -KeepClock, -KeepSpotify, -KeepTeams, -KeepStoreAutoUpdate, -ClassicContextMenu, -LeftTaskbar, -ExcludeWUDrivers, -KeepDefenderDefaults, -NoRestart, -ForceRestart, -SkipBuildCheck
                exit /b 1
            )
        )
    )

    :: Check if non-elevated Dry-Run is requested
    set "IS_DRY=0"
    for %%A in (%*) do (
        if /i "%%~A"=="-DryRun" set "IS_DRY=1"
        if /i "%%~A"=="-WhatIf" set "IS_DRY=1"
    )
    if "!IS_DRY!"=="1" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0!TARGET_SCRIPT!" !FORWARD_ARGS!
        exit /b !errorlevel!
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

    if "!IS_FROM_MENU!"=="1" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0!TARGET_SCRIPT!" !FORWARD_ARGS!
        if !errorlevel! equ 100 exit /b 0
        echo.
        pause
        goto :menu_!OS_MODE!
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0!TARGET_SCRIPT!" !FORWARD_ARGS!
    if !errorlevel! equ 100 exit /b 0
    exit /b !errorlevel!
)

:: ------------------------------------------------------------
:: OS SELECTION MENU
:: ------------------------------------------------------------
:os_select
set "OVERRIDE_BUILD_CHECK=0"
cls
echo ============================================================
echo   unslop-windows (v1.3.2) - PyPie Studio
echo   Universal Windows Unslopper, Debloater ^& Privacy Hardener
echo ============================================================
echo.
if not "!HOST_OS_LABEL!"=="" (
    echo   Detected System: !HOST_OS_LABEL!
    echo.
)
echo   Select your Windows version:
echo.
echo   [1] Windows 11 (25H2 / 24H2 / 23H2 / 22H2 / 21H2)
echo   [2] Windows 10 (22H2 / 21H2 / 20H2 / Enterprise LTSC / Builds 10240-19045)
echo   [0] Exit
echo.
echo ============================================================
set /p "os_choice=Select an option [0-2]: "

if "%os_choice%"=="0" exit /b
if "%os_choice%"=="1" (
    if "!HOST_OS!"=="WIN10" goto :warn_win11_on_win10
    set "TARGET_SCRIPT=unslop-win11.ps1"
    set "OS_MODE=WIN11"
    goto :menu_WIN11
)
if "%os_choice%"=="2" (
    if "!HOST_OS!"=="WIN11" goto :warn_win10_on_win11
    set "TARGET_SCRIPT=unslop-win10.ps1"
    set "OS_MODE=WIN10"
    goto :menu_WIN10
)

echo Invalid selection.
timeout /t 2 >nul
goto :os_select

:: ------------------------------------------------------------
:: OS MISMATCH WARNING HANDLERS
:: ------------------------------------------------------------
:warn_win10_on_win11
cls
echo ============================================================
echo   [WARNING] OPERATING SYSTEM MISMATCH DETECTED
echo ============================================================
echo.
echo   Current System:   Windows 11 (Build !HOST_BUILD!)
echo   Selected Script:  Windows 10 (unslop-win10.ps1)
echo.
echo   Notice:
echo   - unslop-win10.ps1 targets Windows 10 components (Cortana,
echo     News ^& Interests, People Bar and Meet Now).
echo   - It does NOT include Windows 11 features (Recall, Copilot,
echo     UCPD Widgets policy or modern context menu).
echo   - unslop-win10.ps1 will abort on Windows 11 by default.
echo     Proceeding will automatically enable -SkipBuildCheck.
echo.
echo ============================================================
echo.
set /p "mismatch_confirm=Are you sure you want to proceed with Windows 10? [y/N]: "
if /i "!mismatch_confirm!"=="y" (
    set "TARGET_SCRIPT=unslop-win10.ps1"
    set "OS_MODE=WIN10"
    set "OVERRIDE_BUILD_CHECK=1"
    goto :menu_WIN10
)
goto :os_select

:warn_win11_on_win10
cls
echo ============================================================
echo   [WARNING] OPERATING SYSTEM MISMATCH DETECTED
echo ============================================================
echo.
echo   Current System:   Windows 10 (Build !HOST_BUILD!)
echo   Selected Script:  Windows 11 (unslop-win11.ps1)
echo.
echo   Notice:
echo   - unslop-win11.ps1 targets Windows 11 components (Recall,
echo     Copilot, UCPD Widgets policy, modern context menu).
echo   - It does NOT include Windows 10 debloating (Cortana removal,
echo     Feeds / News ^& Interests, People Bar and Meet Now).
echo   - unslop-win11.ps1 will abort on Windows 10 by default.
echo     Proceeding will automatically enable -SkipBuildCheck.
echo.
echo ============================================================
echo.
set /p "mismatch_confirm=Are you sure you want to proceed with Windows 11? [y/N]: "
if /i "!mismatch_confirm!"=="y" (
    set "TARGET_SCRIPT=unslop-win11.ps1"
    set "OS_MODE=WIN11"
    set "OVERRIDE_BUILD_CHECK=1"
    goto :menu_WIN11
)
goto :os_select

:: ------------------------------------------------------------
:: WIN 11 MAIN MENU
:: ------------------------------------------------------------
:menu_WIN11
cls
echo ============================================================
echo   unslop-windows (v1.3.2) - PyPie Studio
echo   Universal Windows 11 (25H2 / 24H2 / 23H2 / 22H2 / 21H2) Debloat ^& Privacy
echo ============================================================
echo.
echo   [1] Full Debloat (Remove OneDrive, telemetry and bloatware)
echo   [2] Gamer Preset (Debloat, keep Xbox ^& Gaming Services)
echo   [3] Productivity Preset (Debloat, keep OneDrive ^& To-Do)
echo   [4] Interactive Toggles (Configure custom feature combinations)
echo   [5] Safe Dry-Run Audit (Inspect changes safely, zero modifications)
echo   [6] Full Restore / Undo (Revert all tweaks back to defaults)
echo   [7] Custom CLI Flags (Manually enter parameter switches)
echo   [8] Back to OS Selection
echo   [0] Exit
echo.
echo ============================================================
set /p "choice=Select an option [0-8]: "

if "%choice%"=="0" exit /b
if "%choice%"=="1" set "ARGS=" & goto :run
if "%choice%"=="2" set "ARGS=-KeepXbox" & goto :run
if "%choice%"=="3" set "ARGS=-KeepOneDrive -KeepTodos" & goto :run
if "%choice%"=="4" goto :toggles_WIN11
if "%choice%"=="5" set "ARGS=-DryRun" & goto :run_dry
if "%choice%"=="6" set "ARGS=-Undo" & goto :run
if "%choice%"=="7" goto :custom_WIN11
if "%choice%"=="8" goto :os_select

echo Invalid selection.
timeout /t 2 >nul
goto :menu_WIN11

:: ------------------------------------------------------------
:: WIN 10 MAIN MENU
:: ------------------------------------------------------------
:menu_WIN10
cls
echo ============================================================
echo   unslop-windows (v1.3.2) - PyPie Studio
echo   Universal Windows 10 (22H2 / 21H2 / Enterprise LTSC / Builds 10240-19045) Debloat ^& Privacy
echo ============================================================
echo.
echo   [1] Full Debloat (Remove OneDrive, telemetry and bloatware)
echo   [2] Gamer Preset (Debloat, keep Xbox ^& Gaming Services)
echo   [3] Productivity Preset (Debloat, keep OneDrive ^& To-Do)
echo   [4] Interactive Toggles (Configure custom feature combinations)
echo   [5] Safe Dry-Run Audit (Inspect changes safely, zero modifications)
echo   [6] Full Restore / Undo (Revert all tweaks back to defaults)
echo   [7] Custom CLI Flags (Manually enter parameter switches)
echo   [8] Back to OS Selection
echo   [0] Exit
echo.
echo ============================================================
set /p "choice=Select an option [0-8]: "

if "%choice%"=="0" exit /b
if "%choice%"=="1" set "ARGS=" & goto :run
if "%choice%"=="2" set "ARGS=-KeepXbox" & goto :run
if "%choice%"=="3" set "ARGS=-KeepOneDrive -KeepTodos" & goto :run
if "%choice%"=="4" goto :toggles_WIN10
if "%choice%"=="5" set "ARGS=-DryRun" & goto :run_dry
if "%choice%"=="6" set "ARGS=-Undo" & goto :run
if "%choice%"=="7" goto :custom_WIN10
if "%choice%"=="8" goto :os_select

echo Invalid selection.
timeout /t 2 >nul
goto :menu_WIN10

:: ------------------------------------------------------------
:: WIN 11 TOGGLES
:: ------------------------------------------------------------
:toggles_WIN11
set "TOGGLE_XBOX=0"
set "TOGGLE_ONEDRIVE=0"
set "TOGGLE_TODOS=0"
set "TOGGLE_CLASSIC=0"
set "TOGGLE_DRYRUN=0"

:toggles_menu_WIN11
cls
set "ACTIVE_FLAGS="
if "!TOGGLE_XBOX!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepXbox"
if "!TOGGLE_ONEDRIVE!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepOneDrive"
if "!TOGGLE_TODOS!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepTodos"
if "!TOGGLE_CLASSIC!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -ClassicContextMenu"
if "!TOGGLE_DRYRUN!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -DryRun"

echo ============================================================
echo   unslop-windows - Interactive Feature Toggles (Win 11)
echo ============================================================
echo.
if "!TOGGLE_XBOX!"=="1" ( echo   [1] Preserve Xbox ^& Gaming Services     : [ ON  ] ) else ( echo   [1] Preserve Xbox ^& Gaming Services     : [ OFF ] )
if "!TOGGLE_ONEDRIVE!"=="1" ( echo   [2] Preserve Microsoft OneDrive         : [ ON  ] ) else ( echo   [2] Preserve Microsoft OneDrive         : [ OFF ] )
if "!TOGGLE_TODOS!"=="1" ( echo   [3] Preserve Microsoft To-Do            : [ ON  ] ) else ( echo   [3] Preserve Microsoft To-Do            : [ OFF ] )
if "!TOGGLE_CLASSIC!"=="1" ( echo   [4] Enable Classic Context Menu         : [ ON  ] ) else ( echo   [4] Enable Classic Context Menu         : [ OFF ] )
if "!TOGGLE_DRYRUN!"=="1" ( echo   [5] Dry-Run Inspection Mode (Read-Only) : [ ON  ] ) else ( echo   [5] Dry-Run Inspection Mode (Read-Only) : [ OFF ] )
echo.
if defined ACTIVE_FLAGS (
    echo   Active Flags:!ACTIVE_FLAGS!
) else (
    echo   Active Flags: (None - Full Default Debloat)
)
echo.
echo ============================================================
echo   [R] Run with selected configuration
echo   [C] Clear / Reset all toggles
echo   [B] Back to Main Menu
echo ============================================================
set /p "tchoice=Select an option to toggle or [R] to run: "

if /i "!tchoice!"=="b" goto :menu_WIN11
if /i "!tchoice!"=="c" goto :toggles_WIN11
if /i "!tchoice!"=="1" (
    if "!TOGGLE_XBOX!"=="1" ( set "TOGGLE_XBOX=0" ) else ( set "TOGGLE_XBOX=1" )
    goto :toggles_menu_WIN11
)
if /i "!tchoice!"=="2" (
    if "!TOGGLE_ONEDRIVE!"=="1" ( set "TOGGLE_ONEDRIVE=0" ) else ( set "TOGGLE_ONEDRIVE=1" )
    goto :toggles_menu_WIN11
)
if /i "!tchoice!"=="3" (
    if "!TOGGLE_TODOS!"=="1" ( set "TOGGLE_TODOS=0" ) else ( set "TOGGLE_TODOS=1" )
    goto :toggles_menu_WIN11
)
if /i "!tchoice!"=="4" (
    if "!TOGGLE_CLASSIC!"=="1" ( set "TOGGLE_CLASSIC=0" ) else ( set "TOGGLE_CLASSIC=1" )
    goto :toggles_menu_WIN11
)
if /i "!tchoice!"=="5" (
    if "!TOGGLE_DRYRUN!"=="1" ( set "TOGGLE_DRYRUN=0" ) else ( set "TOGGLE_DRYRUN=1" )
    goto :toggles_menu_WIN11
)
if /i "!tchoice!"=="r" goto :toggles_run

echo Invalid selection.
timeout /t 1 >nul
goto :toggles_menu_WIN11

:: ------------------------------------------------------------
:: WIN 10 TOGGLES
:: ------------------------------------------------------------
:toggles_WIN10
set "TOGGLE_XBOX=0"
set "TOGGLE_ONEDRIVE=0"
set "TOGGLE_TODOS=0"
set "TOGGLE_DRYRUN=0"

:toggles_menu_WIN10
cls
set "ACTIVE_FLAGS="
if "!TOGGLE_XBOX!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepXbox"
if "!TOGGLE_ONEDRIVE!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepOneDrive"
if "!TOGGLE_TODOS!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -KeepTodos"
if "!TOGGLE_DRYRUN!"=="1" set "ACTIVE_FLAGS=!ACTIVE_FLAGS! -DryRun"

echo ============================================================
echo   unslop-windows - Interactive Feature Toggles (Win 10)
echo ============================================================
echo.
if "!TOGGLE_XBOX!"=="1" ( echo   [1] Preserve Xbox ^& Gaming Services     : [ ON  ] ) else ( echo   [1] Preserve Xbox ^& Gaming Services     : [ OFF ] )
if "!TOGGLE_ONEDRIVE!"=="1" ( echo   [2] Preserve Microsoft OneDrive         : [ ON  ] ) else ( echo   [2] Preserve Microsoft OneDrive         : [ OFF ] )
if "!TOGGLE_TODOS!"=="1" ( echo   [3] Preserve Microsoft To-Do            : [ ON  ] ) else ( echo   [3] Preserve Microsoft To-Do            : [ OFF ] )
if "!TOGGLE_DRYRUN!"=="1" ( echo   [4] Dry-Run Inspection Mode (Read-Only) : [ ON  ] ) else ( echo   [4] Dry-Run Inspection Mode (Read-Only) : [ OFF ] )
echo.
if defined ACTIVE_FLAGS (
    echo   Active Flags:!ACTIVE_FLAGS!
) else (
    echo   Active Flags: (None - Full Default Debloat)
)
echo.
echo ============================================================
echo   [R] Run with selected configuration
echo   [C] Clear / Reset all toggles
echo   [B] Back to Main Menu
echo ============================================================
set /p "tchoice=Select an option to toggle or [R] to run: "

if /i "!tchoice!"=="b" goto :menu_WIN10
if /i "!tchoice!"=="c" goto :toggles_WIN10
if /i "!tchoice!"=="1" (
    if "!TOGGLE_XBOX!"=="1" ( set "TOGGLE_XBOX=0" ) else ( set "TOGGLE_XBOX=1" )
    goto :toggles_menu_WIN10
)
if /i "!tchoice!"=="2" (
    if "!TOGGLE_ONEDRIVE!"=="1" ( set "TOGGLE_ONEDRIVE=0" ) else ( set "TOGGLE_ONEDRIVE=1" )
    goto :toggles_menu_WIN10
)
if /i "!tchoice!"=="3" (
    if "!TOGGLE_TODOS!"=="1" ( set "TOGGLE_TODOS=0" ) else ( set "TOGGLE_TODOS=1" )
    goto :toggles_menu_WIN10
)
if /i "!tchoice!"=="4" (
    if "!TOGGLE_DRYRUN!"=="1" ( set "TOGGLE_DRYRUN=0" ) else ( set "TOGGLE_DRYRUN=1" )
    goto :toggles_menu_WIN10
)
if /i "!tchoice!"=="r" goto :toggles_run

echo Invalid selection.
timeout /t 1 >nul
goto :toggles_menu_WIN10

:toggles_run
set "ARGS=!ACTIVE_FLAGS!"
if "!TOGGLE_DRYRUN!"=="1" goto :run_dry
goto :run

:: ------------------------------------------------------------
:: WIN 11 CUSTOM CLI PARAMETERS
:: ------------------------------------------------------------
:custom_WIN11
echo.
echo Examples: -KeepSysMain -KeepSearch
echo           -KeepPhoneLink -KeepMail
echo           -LeftTaskbar -ExcludeWUDrivers
echo           -KeepSpotify -KeepTeams
echo           -KeepStoreAutoUpdate -KeepTodos
echo.
set /p "ARGS=Enter parameter flags: "
if "!ARGS!"=="" goto :menu_WIN11

:: Validate entered custom parameters against strict whitelist
set "ARGS_OK=1"
for %%A in (!ARGS!) do (
    set "ARG_VALID=0"
    for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
        if /i "%%~A"=="%%V" set "ARG_VALID=1"
    )
    if "!ARG_VALID!"=="0" (
        echo [ERROR] Unrecognized or illegal parameter flag: "%%~A"
        set "ARGS_OK=0"
    )
)
if "!ARGS_OK!"=="0" (
    echo Allowed flags: -Undo, -DryRun, -WhatIf, -KeepXbox, -KeepOneDrive, -KeepTodos, -KeepSysMain, -KeepSearch, -KeepPhoneLink, -KeepMail, -KeepClock, -KeepSpotify, -KeepTeams, -KeepStoreAutoUpdate, -ClassicContextMenu, -LeftTaskbar, -ExcludeWUDrivers, -KeepDefenderDefaults, -NoRestart, -ForceRestart, -SkipBuildCheck
    echo.
    pause
    goto :custom_WIN11
)

goto :custom_run

:: ------------------------------------------------------------
:: WIN 10 CUSTOM CLI PARAMETERS
:: ------------------------------------------------------------
:custom_WIN10
echo.
echo Examples: -KeepSysMain -KeepSearch
echo           -KeepPhoneLink -KeepMail
echo           -KeepClock -ExcludeWUDrivers
echo           -KeepSpotify -KeepTeams
echo           -KeepStoreAutoUpdate -KeepTodos
echo.
set /p "ARGS=Enter parameter flags: "
if "!ARGS!"=="" goto :menu_WIN10

:: Validate entered custom parameters against strict whitelist
set "ARGS_OK=1"
for %%A in (!ARGS!) do (
    set "ARG_VALID=0"
    for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
        if /i "%%~A"=="%%V" set "ARG_VALID=1"
    )
    if "!ARG_VALID!"=="0" (
        echo [ERROR] Unrecognized or illegal parameter flag: "%%~A"
        set "ARGS_OK=0"
    )
)
if "!ARGS_OK!"=="0" (
    echo Allowed flags: -Undo, -DryRun, -WhatIf, -KeepXbox, -KeepOneDrive, -KeepTodos, -KeepSysMain, -KeepSearch, -KeepPhoneLink, -KeepMail, -KeepClock, -KeepSpotify, -KeepTeams, -KeepStoreAutoUpdate, -ExcludeWUDrivers, -KeepDefenderDefaults, -NoRestart, -ForceRestart, -SkipBuildCheck
    echo.
    pause
    goto :custom_WIN10
)

goto :custom_run

:custom_run
set "IS_DRY=0"
for %%A in (!ARGS!) do (
    if /i "%%~A"=="-DryRun" set "IS_DRY=1"
    if /i "%%~A"=="-WhatIf" set "IS_DRY=1"
)
if "!IS_DRY!"=="1" goto :run_dry
goto :run

:: ------------------------------------------------------------
:: DRY-RUN EXECUTION (Non-Elevated with Anti-Amnesia Prompt)
:: ------------------------------------------------------------
:run_dry
echo.
echo Starting Dry-Run Audit (Non-Elevated)...
set "FINAL_ARGS=!ARGS!"
if "!OVERRIDE_BUILD_CHECK!"=="1" set "FINAL_ARGS=!FINAL_ARGS! -SkipBuildCheck"
if defined FINAL_ARGS (
    for %%A in (!FINAL_ARGS!) do (
        set "ARG_VALID=0"
        for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
            if /i "%%~A"=="%%V" set "ARG_VALID=1"
        )
        if "!ARG_VALID!"=="0" (
            echo.
            echo [ERROR] Unrecognized or illegal parameter flag in execution args: "%%~A"
            exit /b 1
        )
    )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0!TARGET_SCRIPT!" !FINAL_ARGS!
echo.
echo Audit complete. Review the inspection results above or check the log file.
echo Press [Enter] to return to the menu or [Q] to exit...
set /p "postchoice="
if /i "!postchoice!"=="q" exit /b 0
goto :menu_!OS_MODE!

:: ------------------------------------------------------------
:: LIVE EXECUTION (Elevated)
:: ------------------------------------------------------------
:run
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo Administrator privileges required. Prompting for UAC elevation...
    set "FINAL_ARGS=!ARGS!"
    if "!OVERRIDE_BUILD_CHECK!"=="1" set "FINAL_ARGS=!FINAL_ARGS! -SkipBuildCheck"
    if defined FINAL_ARGS (
        for %%A in (!FINAL_ARGS!) do (
            set "ARG_VALID=0"
            for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
                if /i "%%~A"=="%%V" set "ARG_VALID=1"
            )
            if "!ARG_VALID!"=="0" (
                echo.
                echo [ERROR] Unrecognized or illegal parameter flag in execution args: "%%~A"
                exit /b 1
            )
        )
    )
    if "!OS_MODE!"=="WIN10" (
        if defined FINAL_ARGS (
            set "UAC_ARGS=-Win10 -FromMenu !FINAL_ARGS!"
        ) else (
            set "UAC_ARGS=-Win10 -FromMenu"
        )
    ) else (
        if defined FINAL_ARGS (
            set "UAC_ARGS=-Win11 -FromMenu !FINAL_ARGS!"
        ) else (
            set "UAC_ARGS=-Win11 -FromMenu"
        )
    )
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '!UAC_ARGS!' -Verb RunAs"
    if !errorlevel! neq 0 (
        echo.
        echo [ERROR] UAC elevation was cancelled or denied.
        echo Administrator privileges are required to apply system modifications.
        echo.
        pause
        goto :menu_!OS_MODE!
    )
    exit /b 0
)

echo.
set "FINAL_ARGS=!ARGS!"
if "!OVERRIDE_BUILD_CHECK!"=="1" set "FINAL_ARGS=!FINAL_ARGS! -SkipBuildCheck"
if defined FINAL_ARGS (
    for %%A in (!FINAL_ARGS!) do (
        set "ARG_VALID=0"
        for %%V in (-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck) do (
            if /i "%%~A"=="%%V" set "ARG_VALID=1"
        )
        if "!ARG_VALID!"=="0" (
            echo.
            echo [ERROR] Unrecognized or illegal parameter flag in execution args: "%%~A"
            exit /b 1
        )
    )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0!TARGET_SCRIPT!" !FINAL_ARGS!
if !errorlevel! equ 100 exit /b 0
echo.
pause
goto :menu_!OS_MODE!
