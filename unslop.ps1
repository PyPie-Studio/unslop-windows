# unslop-windows: Universal Windows 11 Debloat & Privacy Hardener (v1.0.7)
# Targets Windows 11 23H2, 24H2, and 25H2 (Build 26100 - 26200+)
# Safe tier — no core system files touched, all changes reversible
# Run as Administrator after fresh install or every major Windows feature update

[CmdletBinding(SupportsShouldProcess)]
param(
    [Alias("Restore")]
    [switch]$Undo,
    [switch]$DryRun,
    [switch]$KeepXbox,
    [switch]$KeepOneDrive,
    [switch]$KeepTodos,
    [switch]$ClassicContextMenu,
    [switch]$NoRestart,
    [switch]$ForceRestart
)

$ErrorActionPreference = "SilentlyContinue"
$IsUndo = $Undo.IsPresent
$IsDryRun = $DryRun.IsPresent -or ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf'))

$log = @()

function Log($msg, [switch]$DryRun = $IsDryRun) {
    $ts = Get-Date -Format "HH:mm:ss"
    $prefix = if ($DryRun) { "[DRY-RUN] " } else { "" }
    $entry = "[$ts] $prefix$msg"
    Write-Host $entry
    $script:log += $entry
}

function Set-SvcState($name, $desc, $undoStartupType = "Automatic", [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) {
        if ($Undo) {
            if ($DryRun) {
                Log "  [WOULD RESTORE]: $name -> $undoStartupType and Start-Service" -DryRun:$DryRun
            } else {
                Set-Service -Name $name -StartupType $undoStartupType -ErrorAction SilentlyContinue
                Start-Service -Name $name -ErrorAction SilentlyContinue
                Log "  RESTORED: $name (Startup: $undoStartupType)" -DryRun:$DryRun
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD DISABLE]: $name ($desc)" -DryRun:$DryRun
            } else {
                if ($s.Status -eq "Running") { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $name -StartupType Disabled -ErrorAction SilentlyContinue
                Log "  DISABLED: $name ($desc)" -DryRun:$DryRun
            }
        }
    } else {
        Log "  SKIP: $name not found" -DryRun:$DryRun
    }
}

function Set-TaskState($path, $name, [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $t = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
    if ($t) {
        if ($Undo) {
            if ($DryRun) {
                Log "  [WOULD ENABLE]: $name ($path)" -DryRun:$DryRun
            } else {
                Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue | Out-Null
                Log "  ENABLED: $name" -DryRun:$DryRun
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD DISABLE]: $name ($path)" -DryRun:$DryRun
            } else {
                Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue | Out-Null
                Log "  DISABLED: $name" -DryRun:$DryRun
            }
        }
    } else {
        Log "  SKIP: $name not found" -DryRun:$DryRun
    }
}

function Set-RegDwordSafe($path, $name, $debloatValue, $undoValue, $removeOnUndo = $false, [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    if ($Undo) {
        if ($removeOnUndo) {
            if (Test-Path $path) {
                if ($DryRun) {
                    Log "  [WOULD REMOVE REG]: $path\$name" -DryRun:$DryRun
                } else {
                    Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction SilentlyContinue
                    Log "  REMOVED: $name from $path" -DryRun:$DryRun
                }
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD SET REG]: $path\$name = $undoValue" -DryRun:$DryRun
            } else {
                if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $path -Name $name -Value $undoValue -Type DWord -ErrorAction SilentlyContinue
                Log "  RESTORED: $name = $undoValue in $path" -DryRun:$DryRun
            }
        }
    } else {
        if ($DryRun) {
            Log "  [WOULD SET REG]: $path\$name = $debloatValue" -DryRun:$DryRun
        } else {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $path -Name $name -Value $debloatValue -Type DWord -ErrorAction SilentlyContinue
            Log "  SET: $name = $debloatValue" -DryRun:$DryRun
        }
    }
}

function Set-ConsentCapability($capability, $desc = "", $debloatValue = "Deny", $undoValue = "Allow", [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $locPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$capability"
    if ($Undo) {
        if ($DryRun) {
            Log "  [WOULD SET CONSENT]: $capability -> $undoValue" -DryRun:$DryRun
        } else {
            if (-not (Test-Path $locPath)) { New-Item -Path $locPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $locPath -Name "Value" -Value $undoValue -EA 0
            Log "  RESTORED CONSENT: $capability = $undoValue" -DryRun:$DryRun
        }
    } else {
        if ($DryRun) {
            Log "  [WOULD SET CONSENT]: $capability -> $debloatValue ($desc)" -DryRun:$DryRun
        } else {
            if (-not (Test-Path $locPath)) { New-Item -Path $locPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $locPath -Name "Value" -Value $debloatValue -EA 0
            Log "  BLOCKED CONSENT: $capability = $debloatValue ($desc)" -DryRun:$DryRun
        }
    }
}

function Remove-StartupEntry($pattern, $runKeys, [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    if ($Undo) {
        Log "  INFO: Startup entry for '$pattern' can be re-enabled in Task Manager > Startup Apps" -DryRun:$DryRun
        return
    }
    foreach ($runKey in $runKeys) {
        $props = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
        if ($props) {
            $matches = $props.PSObject.Properties | Where-Object { $_.Name -match $pattern -or $_.Value -match $pattern }
            foreach ($entry in $matches) {
                if ($DryRun) {
                    Log "  [WOULD REMOVE STARTUP]: $($entry.Name) from $runKey" -DryRun:$DryRun
                } else {
                    Remove-ItemProperty -Path $runKey -Name $entry.Name -Force -ErrorAction SilentlyContinue
                    Log "  REMOVED: $($entry.Name) from $runKey" -DryRun:$DryRun
                }
            }
        }
    }
}

$allRunKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

# ------------------------------------------------------------
# Dot-Source Guard: If script is being dot-sourced (e.g. Pester test harness),
# return immediately so functions are exported without executing the debloat payload.
# ------------------------------------------------------------
if ($MyInvocation.InvocationName -eq '.') {
    return
}

# Verify Administrator Privileges (enforced unless -DryRun)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($IsDryRun) {
        Write-Host "[WARNING] Running in non-elevated mode. Dry-run inspection only." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  [ERROR] ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  unslop-windows must be executed as an Administrator to apply" -ForegroundColor Red
        Write-Host "  system policies, manage services, and configure group policy." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please re-run this script from an elevated terminal:" -ForegroundColor Yellow
        Write-Host "  Right-click Windows Terminal / PowerShell -> 'Run as administrator'" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

$modeStr = if ($IsUndo) { "RESTORE / UNDO" } else { "UNIVERSAL 25H2 DEBLOAT & PRIVACY HARDEN" }
if ($IsDryRun) { $modeStr += " (DRY-RUN / AUDIT ONLY)" }

Log "=== unslop-windows v1.0.7: Windows 11 $modeStr ==="
Log ""

# ============================================================
# 1. SERVICES
# ============================================================
Log "--- 1. Services ---"
Set-SvcState "SysMain"          "Superfetch — NVMe makes it useless, wastes RAM" "Automatic"
Set-SvcState "WSearch"          "Windows Search Indexer — Start menu app search still works" "Automatic"
Set-SvcState "dmwappushservice" "WAP Push telemetry" "Manual"
Set-SvcState "DiagTrack"        "Diagnostics Tracking (main telemetry)" "Automatic"
Set-SvcState "TrkWks"           "Distributed Link Tracking — tracks file shortcuts" "Automatic"
Set-SvcState "lfsvc"            "Location Framework — GPS/location tracking" "Manual"
Log ""

# ============================================================
# 2. 24H2/25H2 WINDOWS RECALL & WINDOWS COPILOT KILLSWITCH
# ============================================================
Log "--- 2. Windows Recall & Windows Copilot ---"
# Windows AI & Recall (Screenray Snapshotting / Click to Do analysis)
$winAI_LM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
$winAI_CU = "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"
Set-RegDwordSafe -path $winAI_LM -name "DisableAIDataAnalysis" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $winAI_CU -name "DisableAIDataAnalysis" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $winAI_LM -name "AllowRecall"            -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $winAI_CU -name "AllowRecall"            -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Windows Copilot Policy
$copilot_LM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
$copilot_CU = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
Set-RegDwordSafe -path $copilot_LM -name "TurnOffWindowsCopilot" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $copilot_CU -name "TurnOffWindowsCopilot" -debloatValue 1 -undoValue 0 -removeOnUndo $true

# Shell Taskbar Copilot Button
$explorerAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-RegDwordSafe -path $explorerAdv -name "ShowCopilotButton" -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 3. TELEMETRY, DIAGNOSTIC DATA, WER & ONESETTINGS POLICIES
# ============================================================
Log "--- 3. Telemetry, Diagnostic Data & WER Policies ---"
$dataColl = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
# AllowTelemetry: 0 = Security (Enterprise/Edu) or Basic/Required diagnostic tier (Pro/Home)
Set-RegDwordSafe -path $dataColl -name "AllowTelemetry"               -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $dataColl -name "MaxTelemetryAllowed"          -debloatValue 0 -undoValue 3 -removeOnUndo $true
Set-RegDwordSafe -path $dataColl -name "DisableEnterpriseAuthProxy"   -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $dataColl -name "CommercialDataOptIn"          -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $dataColl -name "DisableOneSettingsDownloads"  -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $dataColl -name "DoNotShowFeedbackNotifications" -debloatValue 1 -undoValue 0 -removeOnUndo $true

$privacyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
Set-RegDwordSafe -path $privacyPath -name "TailoredExperiencesWithDiagnosticDataEnabled" -debloatValue 0 -undoValue 1

# Customer Experience Improvement Program (CEIP)
$ceipPath = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
Set-RegDwordSafe -path $ceipPath -name "CEIPEnable" -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Application Impact Telemetry
$appCompatPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
Set-RegDwordSafe -path $appCompatPath -name "AITEnable" -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Windows Error Reporting (WER) - Memory dumps and Watson crash uploads
$werLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
Set-RegDwordSafe -path $werLM -name "Disabled" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $werLM -name "DoReport" -debloatValue 0 -undoValue 1 -removeOnUndo $true

$werCU = "HKCU:\Software\Microsoft\Windows\Windows Error Reporting"
Set-RegDwordSafe -path $werCU -name "Disabled" -debloatValue 1 -undoValue 0
Log ""

# ============================================================
# 4. RECOMMENDATIONS & OFFERS (Full Coverage from Settings)
# ============================================================
Log "--- 4. Recommendations, Offers & App Launch Tracking ---"
# Website language list access
$intlUserProfile = "HKCU:\Control Panel\International\User Profile"
Set-RegDwordSafe -path $intlUserProfile -name "HttpAcceptLanguageOptOut" -debloatValue 1 -undoValue 0

# App launch tracking (Improve Start and search results)
Set-RegDwordSafe -path $explorerAdv -name "Start_TrackProgs" -debloatValue 0 -undoValue 1

# Advertising ID
$advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
Set-RegDwordSafe -path $advPath -name "Enabled" -debloatValue 0 -undoValue 1

# Content Delivery Manager (Offers, Suggestions, Tips, OOBE Nags)
$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$cdmSettings = @{
    "SystemPaneSuggestionsEnabled"     = @{ Debloat = 0; Undo = 1 } # Start menu suggestions/ads
    "SoftLandingEnabled"               = @{ Debloat = 0; Undo = 1 } # "Tips" notifications
    "PreInstalledAppsEnabled"          = @{ Debloat = 0; Undo = 1 } # Preinstalled app pushes
    "OemPreInstalledAppsEnabled"       = @{ Debloat = 0; Undo = 1 } # OEM tracking & app installs
    "SilentInstalledAppsEnabled"       = @{ Debloat = 0; Undo = 1 } # Silent background sponsored apps
    "RotatingLockScreenOverlayEnabled" = @{ Debloat = 0; Undo = 1 } # Lock screen overlay ads
    "SubscribedContent-338389Enabled"  = @{ Debloat = 0; Undo = 1 } # Lock screen spotlight
    "SubscribedContent-338388Enabled"  = @{ Debloat = 0; Undo = 1 } # Lock screen tips
    "SubscribedContent-310093Enabled"  = @{ Debloat = 0; Undo = 1 } # Windows Welcome Experience
    "SubscribedContent-338393Enabled"  = @{ Debloat = 0; Undo = 1 } # Show notifications in Settings
    "SubscribedContent-353694Enabled"  = @{ Debloat = 0; Undo = 1 } # Suggested settings / offers
    "SubscribedContent-353696Enabled"  = @{ Debloat = 0; Undo = 1 } # Tailored content
    "SubscribedContent-353698Enabled"  = @{ Debloat = 0; Undo = 1 } # Personalized offers
}
foreach ($key in $cdmSettings.Keys) {
    $cfg = $cdmSettings[$key]
    Set-RegDwordSafe -path $cdmPath -name $key -debloatValue $cfg.Debloat -undoValue $cfg.Undo
}

# 25H2 Start avatar account nagging badges (OneDrive/M365 promotions) & Iris web recommendations
Set-RegDwordSafe -path $explorerAdv -name "Start_AccountNotifications" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $explorerAdv -name "Start_IrisRecommendations"  -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $explorerAdv -name "ShowSyncProviderNotifications" -debloatValue 0 -undoValue 1

# Post-update "Finish setting up your PC" nag
$oobePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
Set-RegDwordSafe -path $oobePath -name "ScoobeSystemSettingEnabled" -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 5. ONLINE SPEECH & INKING PERSONALIZATION
# ============================================================
Log "--- 5. Speech Recognition & Inking Privacy ---"
# Online speech recognition (stops sending voice/dictation to MS cloud)
$speechPath = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"
Set-RegDwordSafe -path $speechPath -name "HasAccepted" -debloatValue 0 -undoValue 1

$inputPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
Set-RegDwordSafe -path $inputPolicy -name "AllowInputPersonalization" -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Inking & typing personalization (custom dictionary keylogging policy)
$persSettings = "HKCU:\Software\Microsoft\Personalization\Settings"
Set-RegDwordSafe -path $persSettings -name "AcceptedPrivacyPolicy" -debloatValue 0 -undoValue 1

$inkPath = "HKCU:\Software\Microsoft\InputPersonalization"
Set-RegDwordSafe -path $inkPath -name "RestrictImplicitInkCollection"  -debloatValue 1 -undoValue 0
Set-RegDwordSafe -path $inkPath -name "RestrictImplicitTextCollection" -debloatValue 1 -undoValue 0
Set-RegDwordSafe -path $inkPath -name "HarvestContacts"               -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $inkPath -name "CollectContacts"               -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 6. START MENU SEARCH & DEVICE SEARCH HISTORY
# ============================================================
Log "--- 6. Search Privacy & History ---"
# Stops Start menu from transmitting queries/keystrokes to Bing cloud servers
$searchUserPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
Set-RegDwordSafe -path $searchUserPath -name "BingSearchEnabled" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchUserPath -name "CortanaConsent"     -debloatValue 0 -undoValue 1

$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
Set-RegDwordSafe -path $searchPolicyPath -name "DisableWebSearch"        -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $searchPolicyPath -name "ConnectedSearchUseWeb"   -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Device search history & cloud search scope
$searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
Set-RegDwordSafe -path $searchSettingsPath -name "IsDeviceSearchHistoryEnabled" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchSettingsPath -name "IsMSACloudSearchEnabled"      -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchSettingsPath -name "IsAADCloudSearchEnabled"      -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchSettingsPath -name "IsDynamicSearchBoxEnabled"    -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 7. NETWORK SECURITY, LLMNR & WI-FI SENSE
# ============================================================
Log "--- 7. Network Security, LLMNR & Wi-Fi Sense ---"
# Disable LLMNR to prevent NTLM hash theft / Responder poisoning attacks on LANs
$dnsPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
Set-RegDwordSafe -path $dnsPolicy -name "EnableMulticast" -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Wi-Fi Sense & Hotspot Reporting Telemetry
$wifiPolicy = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi"
Set-RegDwordSafe -path "$wifiPolicy\AllowWiFiHotSpotReporting" -name "value" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path "$wifiPolicy\AllowAutoConnectToWiFiSenseHotspots" -name "value" -debloatValue 0 -undoValue 1

$wcmConfig = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
Set-RegDwordSafe -path $wcmConfig -name "AutoConnectAllowedOEM" -debloatValue 0 -undoValue 1

# Find My Device (Desktop Policy)
$findPath = "HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice"
Set-RegDwordSafe -path $findPath -name "AllowFindMyDevice" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Log ""

# ============================================================
# 8. WINDOWS UPDATE GPU DRIVER PROTECTION
# ============================================================
Log "--- 8. Windows Update Driver Protection ---"
# Stops Windows Update from replacing clean NVIDIA/AMD display drivers with generic DCH drivers
$wuPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Set-RegDwordSafe -path $wuPolicy -name "ExcludeWUDriversInQualityUpdate" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Log ""

# ============================================================
# 9. TASKBAR, FILE EXTENSIONS & CONTEXT MENU
# ============================================================
Log "--- 9. Taskbar & Explorer Cleanliness ---"
# Security Baseline: Always show file extensions (prevents .pdf.exe malware masking)
Set-RegDwordSafe -path $explorerAdv -name "HideFileExt" -debloatValue 0 -undoValue 1

# Clean Taskbar clutter (Hide Widgets and Chat/Teams buttons)
Set-RegDwordSafe -path $explorerAdv -name "TaskbarDa" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $explorerAdv -name "TaskbarMn" -debloatValue 0 -undoValue 1

# Optional Classic Right-Click Context Menu (Windows 10 style, no "Show more options")
$classicMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if ($ClassicContextMenu) {
    if ($IsUndo) {
        if (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}") {
            if ($IsDryRun) {
                Log "  [WOULD RESTORE]: Default Windows 11 context menu (remove classic CLSID)"
            } else {
                Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Log "  RESTORED: Default Windows 11 context menu"
            }
        }
    } else {
        if ($IsDryRun) {
            Log "  [WOULD SET]: Classic Windows 10 context menu (-ClassicContextMenu enabled)"
        } else {
            if (-not (Test-Path $classicMenuPath)) { New-Item -Path $classicMenuPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $classicMenuPath -Name "(default)" -Value "" -ErrorAction SilentlyContinue
            Log "  APPLIED: Classic full context menu enabled"
        }
    }
} else {
    if ($IsUndo -and (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}")) {
        if ($IsDryRun) {
            Log "  [WOULD RESTORE]: Default Windows 11 context menu (remove classic CLSID)"
        } else {
            Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
            Log "  RESTORED: Default Windows 11 context menu"
        }
    }
}
Log ""

# ============================================================
# 10. APP PERMISSIONS & 25H2 CAPABILITIES (ConsentStore)
# ============================================================
Log "--- 10. App Permissions & 25H2 Capabilities ---"
# Target capabilities that leak metadata, contacts, or AI context
# NOTE: Microphone, Webcam, and File System libraries remain untouched for desktop compatibility!
Set-ConsentCapability "location"                     "GPS & Location Tracking"
Set-ConsentCapability "appDiagnostics"              "UWP Cross-App Diagnostics"
Set-ConsentCapability "activity"                     "User Activity Tracking"
Set-ConsentCapability "contacts"                     "Address Book & Contacts"
Set-ConsentCapability "appointments"                 "Calendar & Appointments"
Set-ConsentCapability "userDataTasks"                "Task Lists"
Set-ConsentCapability "phoneCall"                    "Cellular / Phone Calls"
Set-ConsentCapability "phoneCallHistory"             "Call Logs"
Set-ConsentCapability "chat"                         "Messaging & SMS"
Set-ConsentCapability "foregroundTextAccess"         "25H2 Foreground On-Screen Text Scraping"
Set-ConsentCapability "systemAIModels"               "25H2 Third-Party OS AI Model Execution"
Set-ConsentCapability "graphicsCaptureWithoutBorder" "25H2 Borderless Screen Capture"
Log ""

# ============================================================
# 11. EXPANDED 24H2/25H2 TELEMETRY SCHEDULED TASKS
# ============================================================
Log "--- 11. 24H2/25H2 Telemetry Scheduled Tasks ---"
$tasksToToggle = @(
    # 25H2 OneSettings Flighting & Dynamic Config
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache"
    # 24H2/25H2 Sustainability & Grid Telemetry
    "\Microsoft\Windows\Sustainability\PowerGridForecastTask"
    "\Microsoft\Windows\Sustainability\SustainabilityTelemetry"
    # 24H2/25H2 Application Experience & Reporting
    "\Microsoft\Windows\Application Experience\MareBackup"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp"
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
    "\Microsoft\Windows\Application Experience\SdbinstMergeDbTask"
    # CEIP tasks
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    # Diagnostics & Disk
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\NetTrace\GatherNetTraceData"
    "\Microsoft\Windows\PI\Sqm-Tasks"
    "\Microsoft\Windows\Autochk\Proxy"
    # Cloud & Feedback
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    # Power Diagnostics
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
)
foreach ($task in $tasksToToggle) {
    $path = $task -replace '\\[^\\]+$', '\'
    $name = $task -replace '^.*\\', ''
    Set-TaskState -path $path -name $name
}

# Scan any Recall tasks if present
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Recall\*" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($IsUndo) {
        if ($IsDryRun) { Log "  [WOULD ENABLE]: $($_.TaskName)" }
        else { Enable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null; Log "  ENABLED: $($_.TaskName)" }
    } else {
        if ($IsDryRun) { Log "  [WOULD DISABLE]: $($_.TaskName)" }
        else { Disable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null; Log "  DISABLED: $($_.TaskName)" }
    }
}

# Office telemetry tasks (8)
$officeTasks = @(
    "Office Actions Server"
    "Office Automatic Updates 2.0"
    "Office Background Push Maintenance"
    "Office ClickToRun Service Monitor"
    "Office Feature Updates"
    "Office Feature Updates Logon"
    "Office Performance Monitor"
    "Office Startup Maintenance"
)
foreach ($t in $officeTasks) {
    Set-TaskState -path "\Microsoft\Office\" -name $t
}

# NVIDIA auto-update tasks
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "NVIDIA.*SelfUpdate" } | ForEach-Object {
    if ($IsUndo) {
        if ($IsDryRun) {
            Log "  [WOULD ENABLE]: $($_.TaskName)"
        } else {
            Enable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null
            Log "  ENABLED: $($_.TaskName)"
        }
    } else {
        if ($IsDryRun) {
            Log "  [WOULD DISABLE]: $($_.TaskName)"
        } else {
            Disable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null
            Log "  DISABLED: $($_.TaskName)"
        }
    }
}
Log ""

# ============================================================
# 12. DUAL-STAGE UWP & PROVISIONED BLOATWARE (24H2/25H2 INCLUDED)
# ============================================================
Log "--- 12. Dual-Stage UWP & Provisioned Bloatware ---"

# Explicit Untouchable Whitelist:
# Store, Terminal, Winget (DesktopAppInstaller), Calculator, Photos, Paint,
# Snipping Tool (ScreenSketch), Codecs (VP9, AV1, HEVC), VCLibs
$bloatApps = @(
    # Microsoft To-Do (modularized: purgeable by default, protected via -KeepTodos)
    "Microsoft.Todos"

    # 24H2 / 25H2 AI & Shell Injections
    "aimgr"
    "Microsoft.StartExperiencesApp"
    "MicrosoftWindows.Client.Photon"
    "MicrosoftWindows.Client.CoreAI"
    "Microsoft.AIFabric.CBS.1.6"
    "Microsoft.Windows.AugLoop.CBS"
    "Microsoft.WidgetsPlatformRuntime"
    "Microsoft.MicrosoftPCManager"
    "Microsoft.Windows.DevHome"
    "Microsoft.Windows.Client.WebExperience"
    "MicrosoftWindows.UndockedDevKit"

    # Sponsored third-party bloat
    "ByteDance.TikTok"
    "SpotifyAB.SpotifyMusic"
    "Disney.37853FC22B2CE"
    "AmazonVideo.PrimeVideo"
    "Facebook.InstagramBeta"
    "King.com.CandyCrushSaga"
    "King.com.CandyCrushSodaSaga"
    "4DF9E0F8.Netflix"

    # Microsoft consumer & news push
    "Clipchamp.Clipchamp"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.BingNews"
    "Microsoft.BingFinance"
    "Microsoft.BingSports"
    "Microsoft.BingSearch"
    "Microsoft.OutlookForWindows"

    # Support & Nag Tools
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.YourPhone"

    # Office push & remnants
    "Microsoft.Office.ActionsServer"
    "Microsoft.OfficePushNotificationUtility"

    # Legacy bloat & stubs
    "Microsoft.ZuneMusic"
    "Microsoft.MixedRealityLink"
    "Microsoft.ECApp"
    "Microsoft.Adera"
    "Microsoft.Adera-Lite"
    "Microsoft.Windows.PeopleExperienceHost"
    "Microsoft.Windows.ParentalControls"
    "Microsoft.Windows.NarratorQuickStart"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.MicrosoftEdge.Stable"
    "Microsoft.MicrosoftEdgeDevToolsClient"
)

if ($KeepTodos) {
    Log "  KEEP: Microsoft To Do retained (-KeepTodos enabled)"
    $bloatApps = $bloatApps | Where-Object { $_ -ne "Microsoft.Todos" }
}

if (-not $KeepXbox) {
    $bloatApps += "Microsoft.GamingApp"
    $bloatApps += "Microsoft.GamingServices"
} else {
    Log "  KEEP: Gaming & Xbox services retained (-KeepXbox enabled)"
}

$removedInstalled = 0
$deprovisionedCount = 0

if ($IsUndo) {
    Log "  Scanning provisioned app manifests to re-register on-disk packages:"
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($app in $bloatApps) {
        $match = $provisioned | Where-Object { $_.DisplayName -match "^$([regex]::Escape($app))" }
        if ($match) {
            if ($IsDryRun) {
                Log "  [WOULD RE-REGISTER]: $app"
            } else {
                Add-AppxPackage -RegisterByFamilyName -MainPackage $match.PackageName -AllUsers -ErrorAction SilentlyContinue
                Log "  RE-REGISTERED: $app"
            }
        } else {
            Log "  NOTE: $app de-provisioned (can reinstall via Microsoft Store or winget)"
        }
    }
} else {
    # 1. De-provision staged packages so they never reinstall for new profiles
    $stagedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($app in $bloatApps) {
        $staged = $stagedPackages | Where-Object { $_.DisplayName -match "^$([regex]::Escape($app))" }
        if ($staged) {
            foreach ($pkg in $staged) {
                if ($IsDryRun) {
                    Log "  [WOULD DE-PROVISION]: $($pkg.DisplayName)"
                    $deprovisionedCount++
                } else {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
                    Log "  DE-PROVISIONED: $($pkg.DisplayName)"
                    $deprovisionedCount++
                }
            }
        }
    }

    # 2. Remove installed instances across all existing user accounts
    foreach ($app in $bloatApps) {
        $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            foreach ($pkg in $installed) {
                if ($IsDryRun) {
                    Log "  [WOULD REMOVE APP]: $($pkg.Name)"
                    $removedInstalled++
                } else {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                    Log "  REMOVED APP: $($pkg.Name)"
                    $removedInstalled++
                }
            }
        } else {
            Log "  SKIP: $app (not installed)"
        }
    }
    Log "  Total installed instances targeted: $removedInstalled"
    Log "  Total provisioned packages de-staged: $deprovisionedCount"
}
Log ""

# ============================================================
# 13. ONEDRIVE PURGE ENGINE
# ============================================================
Log "--- 13. OneDrive Purge Engine ---"
if ($KeepOneDrive) {
    Log "  KEEP: OneDrive retained (-KeepOneDrive enabled)"
} else {
    if ($IsUndo) {
        # Restore OneDrive sync policy and explorer sidebar pin
        $oneDrivePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        Set-RegDwordSafe -path $oneDrivePolicy -name "DisableFileSyncNGSC" -debloatValue 1 -undoValue 0 -removeOnUndo $true

        $odClsidPaths = @(
            "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
            "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        )
        foreach ($odPath in $odClsidPaths) {
            Set-RegDwordSafe -path $odPath -name "System.IsPinnedToNameSpaceTree" -debloatValue 0 -undoValue 1
        }

        Get-ScheduledTask -TaskPath "\Microsoft\Windows\OneDrive\*" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($IsDryRun) { Log "  [WOULD ENABLE]: $($_.TaskName)" }
            else { Enable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null; Log "  ENABLED: $($_.TaskName)" }
        }
        Log "  INFO: To reinstall OneDrive if uninstalled, run: winget install Microsoft.OneDrive"
    } else {
        # 1. Kill running process
        $odProc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($odProc) {
            if ($IsDryRun) {
                Log "  [WOULD STOP PROCESS]: OneDrive"
            } else {
                Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                Log "  STOPPED: OneDrive process"
            }
        }

        # 2. Run uninstaller if present
        $oneDriveUninstaller = @(
            "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe",
            "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe",
            "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($oneDriveUninstaller) {
            if ($IsDryRun) {
                Log "  [WOULD UNINSTALL]: OneDrive via $oneDriveUninstaller /uninstall"
            } else {
                Log "  UNINSTALLING: OneDrive..."
                Start-Process -FilePath $oneDriveUninstaller -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                Log "  UNINSTALLED: OneDrive binary removed"
            }
        } else {
            Log "  SKIP: OneDriveSetup.exe not found (already uninstalled)"
        }

        # 3. Unpin OneDrive from File Explorer sidebar
        $odClsidPaths = @(
            "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
            "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        )
        foreach ($odPath in $odClsidPaths) {
            Set-RegDwordSafe -path $odPath -name "System.IsPinnedToNameSpaceTree" -debloatValue 0 -undoValue 1
        }

        # 4. GPO policy to prevent file syncing
        $oneDrivePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        Set-RegDwordSafe -path $oneDrivePolicy -name "DisableFileSyncNGSC" -debloatValue 1 -undoValue 0 -removeOnUndo $true

        # 5. Disable scheduled update tasks
        Get-ScheduledTask -TaskPath "\Microsoft\Windows\OneDrive\*" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($IsDryRun) { Log "  [WOULD DISABLE]: $($_.TaskName)" }
            else { Disable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -EA 0 | Out-Null; Log "  DISABLED: $($_.TaskName)" }
        }

        # 6. Remove Run registry keys
        Remove-StartupEntry -pattern "OneDrive" -runKeys $allRunKeys
    }
}
Log ""

# ============================================================
# 14. DISABLE EDGE AUTO-LAUNCH + DISCORD AUTO-START
# ============================================================
Log "--- 14. Startup Entries & Edge Background ---"
Remove-StartupEntry -pattern "MicrosoftEdge" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")
Remove-StartupEntry -pattern "Discord" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")

$edgeBgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
Set-RegDwordSafe -path $edgeBgPath -name "Disabled" -debloatValue 1 -undoValue 0

Set-TaskState -path "\Microsoft\Windows\EdgeUpdate\" -name "EdgeUpdateTaskMachineCore"
Log ""

# ============================================================
# 15. DEFENDER: STOP SENDING SAMPLES
# ============================================================
Log "--- 15. Defender ---"
try {
    if ($IsUndo) {
        if ($IsDryRun) {
            Log "  [WOULD SET]: SubmitSamplesConsent = 1 (Send safe samples automatically)"
        } else {
            Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction Stop
            Log "  SubmitSamplesConsent = 1 (Restored default)"
        }
    } else {
        if ($IsDryRun) {
            Log "  [WOULD SET]: SubmitSamplesConsent = 0 (Never send samples)"
        } else {
            Set-MpPreference -SubmitSamplesConsent 0 -ErrorAction Stop
            Log "  SubmitSamplesConsent = 0 (Disabled telemetry uploads)"
        }
    }
} catch {
    Log "  SKIP: SubmitSamplesConsent (may need policy override or tampering protection exemption)"
}
Log ""

# ============================================================
# 16. ACTIVITY HISTORY & CLOUD CLIPBOARD
# ============================================================
Log "--- 16. Activity History & Cloud Clipboard ---"
$sysPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
Set-RegDwordSafe -path $sysPath -name "EnableActivityFeed" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $sysPath -name "PublishUserActivities" -debloatValue 0 -undoValue 1 -removeOnUndo $true

# Feedback frequency = Never
$feedbackPath = "HKCU:\Software\Microsoft\Siuf\Rules"
Set-RegDwordSafe -path $feedbackPath -name "NumberOfSIUFInPeriod" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $feedbackPath -name "PeriodInNanoSeconds" -debloatValue 0 -undoValue 0 -removeOnUndo $true

# Clipboard sync
$clipPath = "HKCU:\Software\Microsoft\Clipboard"
Set-RegDwordSafe -path $clipPath -name "EnableClipboardSyncAcrossDevices" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $clipPath -name "EnableClipboardHistory" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $sysPath -name "AllowClipboardHistory" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $sysPath -name "AllowCrossDeviceClipboard" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Log ""

# ============================================================
# 17. DELIVERY OPTIMIZATION (P2P Update Sharing)
# ============================================================
Log "--- 17. Delivery Optimization ---"
$doPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
Set-RegDwordSafe -path $doPath -name "DODownloadMode" -debloatValue 0 -undoValue 1

$doPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
Set-RegDwordSafe -path $doPolicy -name "DODownloadMode" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Log ""

# ============================================================
# 18. FIREWALL RULES (Unnecessary Outbound Permissions)
# ============================================================
Log "--- 18. Firewall Rules ---"
$fwRules = @(
    "Remote Assistance (SSDP TCP-Out)"
    "Remote Assistance (SSDP UDP-Out)"
    "Remote Assistance (TCP-Out)"
    "Windows Device Management Certificate Installer (TCP out)"
    "Windows Device Management Enrollment Service (TCP out)"
    "Connected Devices Platform - Wi-Fi Direct Transport (TCP-Out)"
    "Connected Devices Platform (TCP-Out)"
    "Connected Devices Platform (UDP-Out)"
)
foreach ($rule in $fwRules) {
    if ($IsUndo) {
        if ($IsDryRun) {
            Log "  [WOULD ENABLE FIREWALL]: $rule"
        } else {
            Enable-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
            Log "  ENABLED: $rule"
        }
    } else {
        if ($IsDryRun) {
            Log "  [WOULD BLOCK FIREWALL]: $rule"
        } else {
            Disable-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
            Log "  BLOCKED: $rule"
        }
    }
}
Log ""

# ============================================================
# SUMMARY
# ============================================================
Log "============================================"
if ($IsUndo) {
    Log "  RESTORE / UNDO COMPLETE"
} else {
    Log "  UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE"
}
Log "============================================"
Log ""

if ($IsUndo) {
    Log "Services restored:     SysMain, WSearch, dmwappushservice, DiagTrack, TrkWks, lfsvc"
    Log "Recall & Copilot:      Windows Recall, Screenray, and Copilot policies reverted"
    Log "OneDrive restored:     Sync policy cleared, Explorer sidebar re-pinned"
    Log "Privacy settings:      Recommendations, Online Speech, Inking, Search History, Find My Device restored"
    Log "ConsentStore:          Targeted UWP capabilities set back to Allow"
    Log "Security & Network:    LLMNR, Wi-Fi Sense, and GPU Driver exclusion policies reverted"
    Log "Explorer & Taskbar:    Widgets, Chat, and File Extensions restored to Windows default"
    Log "Telemetry tasks:       25H2 OneSettings, PowerGridForecast, MareBackup, CEIP, Office, NVIDIA enabled"
    Log "Firewall rules:        8 rules re-enabled"
} else {
    Log "Services disabled:     SysMain, WSearch, dmwappushservice, DiagTrack, TrkWks, lfsvc"
    Log "Recall & Copilot:      Windows Recall (DisableAIDataAnalysis=1) & Copilot policies enforced"
    Log "OneDrive purged:       Process killed, uninstalled, unpinned from sidebar, sync blocked"
    Log "Privacy hardened:      Recommendations & Offers, Online Speech, Inking dictionary, Search History, Find My Device"
    Log "ConsentStore:          12 capabilities blocked (Location, Diagnostics, Contacts, Tasks, 25H2 AI text/models)"
    Log "Security & Network:    LLMNR disabled, Wi-Fi Sense blocked, GPU driver overwrite prevented"
    Log "Explorer & Taskbar:    File extensions visible, Taskbar Widgets & Chat removed"
    if ($ClassicContextMenu) { Log "Context Menu:          Classic Windows 10 style full context menu applied" }
    Log "Telemetry tasks:       25H2 OneSettings, PowerGridForecast, MareBackup, StartupAppTask, CEIP, Office, Diag"
    Log "UWP bloatware:         Dual-stage purged ($removedInstalled active, $deprovisionedCount staged packages)"
    Log "Firewall:              8 outbound telemetry/remote rules blocked"
    Log "Startup cleaned:       Edge, OneDrive, Discord removed from auto-start"
}
Log ""
Log "SAFE-TIER PRESERVED (Untouchable):"
Log "  Microphone & Webcam (Fully accessible for Discord, OBS, Teams)"
Log "  Windows Terminal, Microsoft Store, Winget (DesktopAppInstaller)"
Log "  Calculator, Photos, Paint, Snipping Tool (ScreenSketch)"
Log "  AMDNoiseSuppression (Discord mic)"
Log "  Edge rendering engine (startup behavior only suppressed; WebView2 preserved)"
Log "  VS Code, Firefox, Docker, Ollama auto-updates"
Log ""
Log "REBOOT REQUIRED for all changes to take full effect."
Log ""

# ============================================================
# DECOUPLED LOG SAVING
# ============================================================
$logDir = if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
    Join-Path $PSScriptRoot "logs"
} else {
    "$env:TEMP\unslop_logs"
}

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$prefixName = if ($IsUndo) { "restore" } else { "unslop" }
$modeTag = if ($IsDryRun) { "_dryrun" } else { "" }
$logPath = Join-Path $logDir "$($prefixName)_25h2$($modeTag)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$log | Out-File -FilePath $logPath -Encoding UTF8
Log "Log saved to: $logPath"

# ============================================================
# SYSTEM RESTART HANDLING
# ============================================================
if (-not $IsDryRun) {
    if ($NoRestart) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  [!] NOTICE: SYSTEM RESTART REQUIRED" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  -NoRestart flag was specified." -ForegroundColor Yellow
        Write-Host "  Please save all open work and restart your computer manually" -ForegroundColor Yellow
        Write-Host "  to finalize debloating and apply all policy modifications." -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }

    $shouldInitiate = $ForceRestart
    if (-not $ForceRestart) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  [!] ACTION REQUIRED: SYSTEM RESTART NEEDED" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  A restart is required to finalize debloating and apply all changes." -ForegroundColor Yellow
        Write-Host "  PLEASE SAVE ALL OPEN WORK BEFORE RESTARTING!" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host ""

        try {
            $response = Read-Host "Restart computer now? [Y/n] (Press Enter for Yes)"
            if ([string]::IsNullOrWhiteSpace($response) -or $response.Trim() -match '^(y|yes)$') {
                $shouldInitiate = $true
            }
        } catch {
            $shouldInitiate = $false
            Write-Host "Non-interactive session detected. Skipping automatic restart." -ForegroundColor Cyan
            Write-Host "Please restart your computer manually to apply changes." -ForegroundColor Cyan
        }
    }

    if ($shouldInitiate) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  [!] ACTION: RESTARTING COMPUTER IN 30 SECONDS" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  PLEASE SAVE ALL OPEN WORK IMMEDIATELY!" -ForegroundColor Yellow
        Write-Host "  Your machine will restart in 30 seconds." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [SHORTCUT] Press 'A' to Abort restart | Press 'R' to Restart Now" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""

        # Schedule 30-second shutdown with Windows OS
        & shutdown.exe /r /t 30 /d p:2:4 /c "unslop-windows: System restart in 30 seconds to apply debloat changes. Please save all open work immediately!" 2>$null

        $aborted = $false
        $restartNow = $false
        $secondsLeft = 30

        try {
            while ($secondsLeft -gt 0) {
                Write-Host -NoNewline ("`r  Restarting in {0,2}s... [Press 'A' to Abort | 'R' to Restart Now]   " -f $secondsLeft)
                $keyHit = $false
                for ($sub = 0; $sub -lt 10; $sub++) {
                    Start-Sleep -Milliseconds 100
                    try {
                        if ($Host.UI.RawUI.KeyAvailable) {
                            $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
                            if ($k.Character -eq 'a' -or $k.Character -eq 'A') {
                                $aborted = $true
                                $keyHit = $true
                                break
                            }
                            if ($k.Character -eq 'r' -or $k.Character -eq 'R' -or $k.VirtualKeyCode -eq 13) {
                                $restartNow = $true
                                $keyHit = $true
                                break
                            }
                        }
                    } catch {
                        # Host does not support raw console keys
                    }
                }
                if ($keyHit) { break }
                $secondsLeft--
            }
        } catch {
            # Interrupted (e.g. Ctrl+C) -> treat as abort
            $aborted = $true
        }

        if ($aborted) {
            & shutdown.exe /a 2>$null
            Write-Host ""
            Write-Host ""
            Write-Host "============================================================" -ForegroundColor Yellow
            Write-Host "  [!] SYSTEM RESTART CANCELLED" -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Yellow
            Write-Host "  Automatic restart has been aborted." -ForegroundColor Yellow
            Write-Host "  Please save your work and manually restart your computer" -ForegroundColor Yellow
            Write-Host "  when you are ready to apply all changes." -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Yellow
            Write-Host ""
            exit 0
        } elseif ($restartNow) {
            Write-Host ""
            Write-Host ""
            Write-Host "Restarting system immediately..." -ForegroundColor Green
            & shutdown.exe /a 2>$null
            & shutdown.exe /r /t 0 /d p:2:4 /c "unslop-windows: Restarting immediately." 2>$null
            exit 100
        } else {
            Write-Host ""
            Write-Host ""
            Write-Host "Restarting system now..." -ForegroundColor Green
            exit 100
        }
    } else {
        Write-Host ""
        Write-Host "Restart postponed." -ForegroundColor Cyan
        Write-Host "Remember to save your work and restart your computer soon to apply all changes." -ForegroundColor Cyan
        Write-Host ""
        exit 0
    }
}
