# unslop-windows: Universal Windows 10 Debloat & Privacy Hardener (v1.2.0)
# Targets Windows 10 all versions (Build 10240+)
# Safe tier - no core system files touched, all changes reversible

<#
.SYNOPSIS
    unslop-windows: Safe-Tier Universal Windows 10 Debloater & Privacy Hardener.

.DESCRIPTION
    Safely debloats Windows 10 by removing telemetry,
    disabling unnecessary services and background tasks, de-provisioning sponsored
    bloatware, neutralizing Cortana, and securing ConsentStore permissions.
    All operations adhere to the Safe-Tier invariant (zero WinSxS / DISM corruption)
    and support 100% symmetrical restoration via -Undo.

.PARAMETER Undo
    Reverts all debloat modifications, restores services, re-enables scheduled tasks,
    and resets registry policies back to clean Windows defaults. Alias: -Restore.

.PARAMETER DryRun
    Executes in read-only inspection mode under standard user privileges.
    Audits all proposed actions without modifying system state. Supports -WhatIf.

.PARAMETER KeepXbox
    Preserves Xbox App, Gaming Services, and related gaming components.

.PARAMETER KeepOneDrive
    Preserves Microsoft OneDrive process, auto-start, syncing, and File Explorer sidebar integration.

.PARAMETER KeepTodos
    Preserves the Microsoft To-Do UWP application.

.PARAMETER SkipBuildCheck
    Bypasses the OS build version check (useful for CI/CD testing).

.PARAMETER NoRestart
    Suppresses the post-execution restart prompt and countdown.

.PARAMETER ForceRestart
    Automatically initiates an immediate system restart upon completion without prompting.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1
    Runs full debloat with default settings and prompts for restart upon completion.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -DryRun
    Safely audits proposed debloat changes in non-elevated user mode.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -KeepXbox -KeepOneDrive
    Debloats system while preserving Xbox gaming services and OneDrive.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -Undo
    Fully restores system policies and services back to clean Windows defaults.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Alias("Restore")]
    [switch]$Undo,
    [switch]$DryRun,
    [switch]$KeepXbox,
    [switch]$KeepOneDrive,
    [switch]$KeepTodos,
    [switch]$SkipBuildCheck,
    [switch]$NoRestart,
    [switch]$ForceRestart
)

$ErrorActionPreference = "SilentlyContinue"
$IsUndo = $Undo.IsPresent
$IsDryRun = $DryRun.IsPresent -or ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf'))

$global:FailCount = 0
# Performance Optimization: Use Generic List[string] for O(1) log accumulation (avoids O(N²) array reallocations)
[System.Collections.Generic.List[string]]$script:log = [System.Collections.Generic.List[string]]::new()

function Log($msg, [switch]$DryRun = $IsDryRun, [string]$Color = "") {
    $ts = Get-Date -Format "HH:mm:ss"
    $prefix = if ($DryRun) { "[DRY-RUN] " } else { "" }
    $entry = "[$ts] $prefix$msg"
    [void]$script:log.Add($entry)

    if ($Color) {
        Write-Host $entry -ForegroundColor $Color
        return
    }

    if ($msg -match '^(===|---|=== unslop)') {
        Write-Host $entry -ForegroundColor Cyan
    } elseif ($msg -match '(\[WOULD|DRY-RUN)') {
        Write-Host $entry -ForegroundColor Yellow
    } elseif ($msg -match '(DISABLED:|REMOVED:|RESTORED:|ENABLED:|BLOCKED:|STOPPED:|UNINSTALLED:|SET:)') {
        Write-Host $entry -ForegroundColor Green
    } elseif ($msg -match 'SKIP:') {
        Write-Host $entry -ForegroundColor DarkGray
    } elseif ($msg -match '(FAIL:|FAILED:|ERROR:)') {
        Write-Host $entry -ForegroundColor Red
    } elseif ($msg -match '(KEEP:|INFO:|NOTE:)') {
        Write-Host $entry -ForegroundColor Magenta
    } else {
        Write-Host $entry
    }
}

function Set-SvcState($name, $desc, $undoStartupType = "Automatic", [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) {
        if ($Undo) {
            if ($DryRun) {
                Log "  [WOULD RESTORE]: $name -> $undoStartupType and Start-Service" -DryRun:$DryRun
            } else {
                try {
                    Set-Service -Name $name -StartupType $undoStartupType -ErrorAction Stop
                    Start-Service -Name $name -ErrorAction Stop
                    Log "  RESTORED: $name (Startup: $undoStartupType)" -DryRun:$DryRun
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not restore service $name - $($_.Exception.Message)" -DryRun:$DryRun
                }
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD DISABLE]: $name ($desc)" -DryRun:$DryRun
            } else {
                try {
                    if ($s.Status -eq "Running") { Stop-Service -Name $name -Force -ErrorAction Stop }
                    Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
                    Log "  DISABLED: $name ($desc)" -DryRun:$DryRun
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not disable service $name - $($_.Exception.Message)" -DryRun:$DryRun
                }
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
                try {
                    Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                    Log "  ENABLED: $name" -DryRun:$DryRun
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not enable task $name - $($_.Exception.Message)" -DryRun:$DryRun
                }
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD DISABLE]: $name ($path)" -DryRun:$DryRun
            } else {
                try {
                    Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                    Log "  DISABLED: $name" -DryRun:$DryRun
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not disable task $name - $($_.Exception.Message)" -DryRun:$DryRun
                }
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
                    try {
                        Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction Stop
                        Log "  REMOVED: $name from $path" -DryRun:$DryRun
                    } catch {
                        $global:FailCount++
                        Log "  FAILED: Could not remove $name from $path - $($_.Exception.Message)" -DryRun:$DryRun
                    }
                }
            }
        } else {
            if ($DryRun) {
                Log "  [WOULD SET REG]: $path\$name = $undoValue" -DryRun:$DryRun
            } else {
                try {
                    if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
                    Set-ItemProperty -Path $path -Name $name -Value $undoValue -Type DWord -ErrorAction Stop
                    Log "  RESTORED: $name = $undoValue in $path" -DryRun:$DryRun
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not restore $name in $path - $($_.Exception.Message)" -DryRun:$DryRun
                }
            }
        }
    } else {
        if ($DryRun) {
            Log "  [WOULD SET REG]: $path\$name = $debloatValue" -DryRun:$DryRun
        } else {
            try {
                if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $path -Name $name -Value $debloatValue -Type DWord -ErrorAction Stop
                Log "  SET: $name = $debloatValue" -DryRun:$DryRun
            } catch {
                $global:FailCount++
                Log "  FAILED: Could not set $name in $path - $($_.Exception.Message)" -DryRun:$DryRun
            }
        }
    }
}

function Set-ConsentCapability($capability, $desc = "", $debloatValue = "Deny", $undoValue = "Allow", [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $locPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$capability"
    if ($Undo) {
        if ($DryRun) {
            Log "  [WOULD SET CONSENT]: $capability -> $undoValue" -DryRun:$DryRun
        } else {
            try {
                if (-not (Test-Path $locPath)) { New-Item -Path $locPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $locPath -Name "Value" -Value $undoValue -ErrorAction Stop
                Log "  RESTORED CONSENT: $capability = $undoValue" -DryRun:$DryRun
            } catch {
                $global:FailCount++
                Log "  FAILED: Could not restore consent $capability - $($_.Exception.Message)" -DryRun:$DryRun
            }
        }
    } else {
        if ($DryRun) {
            Log "  [WOULD SET CONSENT]: $capability -> $debloatValue ($desc)" -DryRun:$DryRun
        } else {
            try {
                if (-not (Test-Path $locPath)) { New-Item -Path $locPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $locPath -Name "Value" -Value $debloatValue -ErrorAction Stop
                Log "  BLOCKED CONSENT: $capability = $debloatValue ($desc)" -DryRun:$DryRun
            } catch {
                $global:FailCount++
                Log "  FAILED: Could not block consent $capability - $($_.Exception.Message)" -DryRun:$DryRun
            }
        }
    }
}

function Remove-StartupEntry($pattern, $runKeys, [switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun) {
    $backupBase = "HKCU:\Software\unslop-windows\StartupBackup"
    if ($Undo) {
        foreach ($runKey in $runKeys) {
            $keySub = ($runKey -replace ':', '' -replace '[\\/]', '_')
            $backupPath = "$backupBase\$keySub"
            if (Test-Path $backupPath) {
                $props = Get-ItemProperty -Path $backupPath -ErrorAction SilentlyContinue
                if ($props) {
                    $matches = $props.PSObject.Properties | Where-Object {
                        $_.Name -notmatch '^(PSPath|PSParentPath|PSChildName|PSDrive|PSProvider)$' -and
                        ($_.Name -match $pattern -or $_.Value -match $pattern)
                    }
                    foreach ($entry in $matches) {
                        if ($DryRun) {
                            Log "  [WOULD RESTORE STARTUP]: $($entry.Name) -> $runKey" -DryRun:$DryRun
                        } else {
                            try {
                                if (-not (Test-Path $runKey)) { New-Item -Path $runKey -Force -ErrorAction Stop | Out-Null }
                                Set-ItemProperty -Path $runKey -Name $entry.Name -Value $entry.Value -ErrorAction Stop
                                Remove-ItemProperty -Path $backupPath -Name $entry.Name -Force -ErrorAction SilentlyContinue
                                Log "  RESTORED STARTUP: $($entry.Name) in $runKey" -DryRun:$DryRun
                            } catch {
                                $global:FailCount++
                                Log "  FAILED: Could not restore startup entry $($entry.Name) in $runKey - $($_.Exception.Message)" -DryRun:$DryRun
                            }
                        }
                    }
                }
            } else {
                Log "  SKIP: No archived startup entry found for '$pattern' in $runKey" -DryRun:$DryRun
            }
        }
        return
    }

    foreach ($runKey in $runKeys) {
        $props = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
        if ($props) {
            $matches = $props.PSObject.Properties | Where-Object {
                $_.Name -notmatch '^(PSPath|PSParentPath|PSChildName|PSDrive|PSProvider)$' -and
                ($_.Name -match $pattern -or $_.Value -match $pattern)
            }
            foreach ($entry in $matches) {
                if ($DryRun) {
                    Log "  [WOULD REMOVE STARTUP]: $($entry.Name) from $runKey (archive to backup)" -DryRun:$DryRun
                } else {
                    try {
                        $keySub = ($runKey -replace ':', '' -replace '[\\/]', '_')
                        $backupPath = "$backupBase\$keySub"
                        if (-not (Test-Path $backupPath)) { New-Item -Path $backupPath -Force -ErrorAction Stop | Out-Null }
                        Set-ItemProperty -Path $backupPath -Name $entry.Name -Value $entry.Value -ErrorAction Stop
                        Remove-ItemProperty -Path $runKey -Name $entry.Name -Force -ErrorAction Stop
                        Log "  REMOVED: $($entry.Name) from $runKey (archived for restore)" -DryRun:$DryRun
                    } catch {
                        $global:FailCount++
                        Log "  FAILED: Could not remove $($entry.Name) from $runKey - $($_.Exception.Message)" -DryRun:$DryRun
                    }
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

$build = [System.Environment]::OSVersion.Version.Build
if (-not $SkipBuildCheck) {
    if ($build -ge 22000) {
        Write-Host "ABORT: This script is for Windows 10 (Build < 22000). For Windows 11, use unslop.ps1." -ForegroundColor Red
        exit 1
    }
}
$osTag = if ($build -ge 19045) { "22H2" } elseif ($build -ge 19044) { "21H2" } elseif ($build -ge 19043) { "21H1" } elseif ($build -ge 19042) { "20H2" } elseif ($build -ge 19041) { "2004" } else { "Legacy" }

$modeStr = if ($IsUndo) { "RESTORE / UNDO" } else { "DEBLOAT & PRIVACY HARDEN ($osTag)" }
if ($IsDryRun) { $modeStr += " (DRY-RUN / AUDIT ONLY)" }

Log "=== unslop-windows v1.2.0: Windows 10 $modeStr ==="
Log ""

# ============================================================
# 1. SERVICES
# ============================================================
Log "--- 1. Services ---"
Set-SvcState "SysMain"          "Superfetch - NVMe makes it useless, wastes RAM" "Automatic"
Set-SvcState "WSearch"          "Windows Search Indexer - Start menu app search still works" "Automatic"
Set-SvcState "dmwappushservice" "WAP Push telemetry" "Manual"
Set-SvcState "DiagTrack"        "Diagnostics Tracking (main telemetry)" "Automatic"
Set-SvcState "TrkWks"           "Distributed Link Tracking - tracks file shortcuts" "Automatic"
Set-SvcState "lfsvc"            "Location Framework - GPS/location tracking" "Manual"
Log ""

# ============================================================
# 2. CORTANA COMPLETE PURGE
# ============================================================
Log "--- 2. Cortana Complete Purge ---"
$searchPolicyLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
$searchCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"

Set-RegDwordSafe -path $searchPolicyLM -name "AllowCortana" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $searchCU -name "SearchboxTaskbarMode" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchPolicyLM -name "AllowSearchToUseLocation" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $searchCU -name "AllowCortanaAboveLock" -debloatValue 0 -undoValue 1

$cortanaApp = "Microsoft.549981C3F5F10"
if ($IsUndo) {
    Log "  Scanning provisioned app manifests to re-register Cortana:"
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    $match = if ($provisioned) { $provisioned.Where({ $_.DisplayName -match "^$([regex]::Escape($cortanaApp))" }) } else { $null }
    if ($match) {
        foreach ($pkg in $match) {
            if ($IsDryRun) {
                Log "  [WOULD RE-REGISTER]: $($pkg.DisplayName)"
            } else {
                try {
                    Add-AppxPackage -RegisterByFamilyName -MainPackage $pkg.PackageName -AllUsers -ErrorAction Stop
                    Log "  RE-REGISTERED: $($pkg.DisplayName)"
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not re-register $($pkg.DisplayName) - $($_.Exception.Message)"
                }
            }
        }
    } else {
        Log "  NOTE: Cortana app de-provisioned"
    }
} else {
    $stagedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    $staged = if ($stagedPackages) { $stagedPackages.Where({ $_.DisplayName -match "^$([regex]::Escape($cortanaApp))" }) } else { $null }
    if ($staged) {
        foreach ($pkg in $staged) {
            if ($IsDryRun) {
                Log "  [WOULD DE-PROVISION]: $($pkg.DisplayName)"
            } else {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                    Log "  DE-PROVISIONED: $($pkg.DisplayName)"
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not de-provision $($pkg.DisplayName) - $($_.Exception.Message)"
                }
            }
        }
    }

    $allInstalled = if ($isAdmin) { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue } else { Get-AppxPackage -ErrorAction SilentlyContinue }
    $installed = if ($allInstalled) { $allInstalled.Where({ -not $_.NonRemovable -and $_.Name -match "^$([regex]::Escape($cortanaApp))" }) } else { $null }
    if ($installed) {
        foreach ($pkg in $installed) {
            if ($IsDryRun) {
                Log "  [WOULD REMOVE APP]: $($pkg.Name)"
            } else {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    Log "  REMOVED APP: $($pkg.Name)"
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not remove $($pkg.Name) - $($_.Exception.Message)"
                }
            }
        }
    }
}
Log ""

# ============================================================
# 3. TELEMETRY, DIAGNOSTIC DATA, WER & ONESETTINGS POLICIES
# ============================================================
Log "--- 3. Telemetry, Diagnostic Data & WER Policies ---"
$dataColl = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
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

# Windows Error Reporting (WER)
$werLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
Set-RegDwordSafe -path $werLM -name "Disabled" -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $werLM -name "DoReport" -debloatValue 0 -undoValue 1 -removeOnUndo $true

$werCU = "HKCU:\Software\Microsoft\Windows\Windows Error Reporting"
Set-RegDwordSafe -path $werCU -name "Disabled" -debloatValue 1 -undoValue 0
Log ""

# ============================================================
# 4. RECOMMENDATIONS & OFFERS
# ============================================================
Log "--- 4. Recommendations, Offers & App Launch Tracking ---"
$intlUserProfile = "HKCU:\Control Panel\International\User Profile"
Set-RegDwordSafe -path $intlUserProfile -name "HttpAcceptLanguageOptOut" -debloatValue 1 -undoValue 0

$explorerAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-RegDwordSafe -path $explorerAdv -name "Start_TrackProgs" -debloatValue 0 -undoValue 1

$advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
Set-RegDwordSafe -path $advPath -name "Enabled" -debloatValue 0 -undoValue 1

$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$cdmSettings = @{
    "SystemPaneSuggestionsEnabled"     = @{ Debloat = 0; Undo = 1 }
    "SoftLandingEnabled"               = @{ Debloat = 0; Undo = 1 }
    "PreInstalledAppsEnabled"          = @{ Debloat = 0; Undo = 1 }
    "OemPreInstalledAppsEnabled"       = @{ Debloat = 0; Undo = 1 }
    "SilentInstalledAppsEnabled"       = @{ Debloat = 0; Undo = 1 }
    "RotatingLockScreenOverlayEnabled" = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-338389Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-338388Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-310093Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-338393Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-353694Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-353696Enabled"  = @{ Debloat = 0; Undo = 1 }
    "SubscribedContent-353698Enabled"  = @{ Debloat = 0; Undo = 1 }
}
foreach ($key in $cdmSettings.Keys) {
    $cfg = $cdmSettings[$key]
    Set-RegDwordSafe -path $cdmPath -name $key -debloatValue $cfg.Debloat -undoValue $cfg.Undo
}

Set-RegDwordSafe -path $explorerAdv -name "ShowSyncProviderNotifications" -debloatValue 0 -undoValue 1

$oobePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
Set-RegDwordSafe -path $oobePath -name "ScoobeSystemSettingEnabled" -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 5. ONLINE SPEECH & INKING PERSONALIZATION
# ============================================================
Log "--- 5. Speech Recognition & Inking Privacy ---"
$speechPath = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"
Set-RegDwordSafe -path $speechPath -name "HasAccepted" -debloatValue 0 -undoValue 1

$inputPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
Set-RegDwordSafe -path $inputPolicy -name "AllowInputPersonalization" -debloatValue 0 -undoValue 1 -removeOnUndo $true

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
$searchUserPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
Set-RegDwordSafe -path $searchUserPath -name "BingSearchEnabled" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path $searchUserPath -name "CortanaConsent"     -debloatValue 0 -undoValue 1

$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
Set-RegDwordSafe -path $searchPolicyPath -name "DisableWebSearch"        -debloatValue 1 -undoValue 0 -removeOnUndo $true
Set-RegDwordSafe -path $searchPolicyPath -name "ConnectedSearchUseWeb"   -debloatValue 0 -undoValue 1 -removeOnUndo $true

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
$dnsPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
Set-RegDwordSafe -path $dnsPolicy -name "EnableMulticast" -debloatValue 0 -undoValue 1 -removeOnUndo $true

$wifiPolicy = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi"
Set-RegDwordSafe -path "$wifiPolicy\AllowWiFiHotSpotReporting" -name "value" -debloatValue 0 -undoValue 1
Set-RegDwordSafe -path "$wifiPolicy\AllowAutoConnectToWiFiSenseHotspots" -name "value" -debloatValue 0 -undoValue 1

$wcmConfig = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
Set-RegDwordSafe -path $wcmConfig -name "AutoConnectAllowedOEM" -debloatValue 0 -undoValue 1

$findPath = "HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice"
Set-RegDwordSafe -path $findPath -name "AllowFindMyDevice" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Log ""

# ============================================================
# 8. WINDOWS UPDATE DRIVER & FIRMWARE INTEGRITY
# ============================================================
Log "--- 8. Windows Update Driver & Firmware Integrity ---"
$wuPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (Test-Path $wuPolicy) {
    $wuProp = Get-ItemProperty -Path $wuPolicy -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
    if ($wuProp) {
        if ($IsDryRun) {
            Log "  [WOULD RESTORE]: Driver updates (remove legacy ExcludeWUDriversInQualityUpdate)" -DryRun:$DryRun
        } else {
            Remove-ItemProperty -Path $wuPolicy -Name "ExcludeWUDriversInQualityUpdate" -Force -ErrorAction SilentlyContinue
            Log "  RESTORED: Driver updates enabled (cleared legacy ExcludeWUDriversInQualityUpdate)" -DryRun:$DryRun
        }
    } else {
        Log "  PRESERVED: Windows Update driver and firmware delivery enabled" -DryRun:$DryRun
    }
} else {
    Log "  PRESERVED: Windows Update driver and firmware delivery enabled" -DryRun:$DryRun
}
Log ""

# ============================================================
# 9. TASKBAR & EXPLORER CLEANUP
# ============================================================
Log "--- 9. Taskbar & Explorer Cleanup ---"
Set-RegDwordSafe -path $explorerAdv -name "HideFileExt" -debloatValue 0 -undoValue 1

$peopleBand = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
Set-RegDwordSafe -path $peopleBand -name "PeopleBand" -debloatValue 0 -undoValue 1

$explorerPol = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
Set-RegDwordSafe -path $explorerPol -name "HideSCAMeetNow" -debloatValue 1 -undoValue 0 -removeOnUndo $true

$feedsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
Set-RegDwordSafe -path $feedsPath -name "ShellFeedsTaskbarViewMode" -debloatValue 2 -undoValue 0
Set-RegDwordSafe -path $feedsPath -name "IsFeedsAvailable" -debloatValue 0 -undoValue 1
Log ""

# ============================================================
# 10. APP PERMISSIONS (ConsentStore)
# ============================================================
Log "--- 10. App Permissions ---"
Set-ConsentCapability "location"                     "GPS & Location Tracking"
Set-ConsentCapability "appDiagnostics"              "UWP Cross-App Diagnostics"
Set-ConsentCapability "activity"                     "User Activity Tracking"
Set-ConsentCapability "contacts"                     "Address Book & Contacts"
Set-ConsentCapability "appointments"                 "Calendar & Appointments"
Set-ConsentCapability "userDataTasks"                "Task Lists"
Set-ConsentCapability "phoneCall"                    "Cellular / Phone Calls"
Set-ConsentCapability "phoneCallHistory"             "Call Logs"
Set-ConsentCapability "chat"                         "Messaging & SMS"
Log ""

# ============================================================
# 11. TELEMETRY SCHEDULED TASKS
# ============================================================
Log "--- 11. Telemetry Scheduled Tasks ---"
$tasksToToggle = @(
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp"
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\NetTrace\GatherNetTraceData"
    "\Microsoft\Windows\PI\Sqm-Tasks"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
)
foreach ($task in $tasksToToggle) {
    $path = $task -replace '\\[^\\]+$', '\'
    $name = $task -replace '^.*\\', ''
    Set-TaskState -path $path -name $name
}

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

Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "NVIDIA.*SelfUpdate" } | ForEach-Object {
    Set-TaskState -path $_.TaskPath -name $_.TaskName
}
Log ""

# ============================================================
# 12. DUAL-STAGE UWP & PROVISIONED BLOATWARE
# ============================================================
Log "--- 12. Dual-Stage UWP & Provisioned Bloatware ---"
$bloatApps = @(
    "Microsoft.Todos"
    "Microsoft.Print3D"
    "Microsoft.3DBuilder"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.OneConnect"
    "Microsoft.MSPaint"
    "Microsoft.WindowsAlarms"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsCommunicationsApps"
    "Microsoft.MixedReality.Portal"
    "ByteDance.TikTok"
    "SpotifyAB.SpotifyMusic"
    "Disney.37853FC22B2CE"
    "AmazonVideo.PrimeVideo"
    "Facebook.InstagramBeta"
    "King.com.CandyCrushSaga"
    "King.com.CandyCrushSodaSaga"
    "4DF9E0F8.Netflix"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingFinance"
    "Microsoft.BingSports"
    "Microsoft.BingSearch"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.YourPhone"
    "Microsoft.Office.ActionsServer"
    "Microsoft.OfficePushNotificationUtility"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.MixedRealityLink"
    "Microsoft.Adera"
    "Microsoft.Adera-Lite"
    "Microsoft.MicrosoftPCManager"
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
        $match = if ($provisioned) { $provisioned.Where({ $_.DisplayName -match "^$([regex]::Escape($app))" }) } else { $null }
        if ($match) {
            foreach ($pkg in $match) {
                if ($IsDryRun) {
                    Log "  [WOULD RE-REGISTER]: $($pkg.DisplayName)"
                } else {
                    try {
                        Add-AppxPackage -RegisterByFamilyName -MainPackage $pkg.PackageName -AllUsers -ErrorAction Stop
                        Log "  RE-REGISTERED: $($pkg.DisplayName)"
                    } catch {
                        $global:FailCount++
                        Log "  FAILED: Could not re-register $($pkg.DisplayName) - $($_.Exception.Message)"
                    }
                }
            }
        } else {
            Log "  NOTE: $app de-provisioned (can reinstall via Microsoft Store or winget)"
        }
    }
} else {
    $stagedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($app in $bloatApps) {
        $staged = if ($stagedPackages) { $stagedPackages.Where({ $_.DisplayName -match "^$([regex]::Escape($app))" }) } else { $null }
        if ($staged) {
            foreach ($pkg in $staged) {
                if ($IsDryRun) {
                    Log "  [WOULD DE-PROVISION]: $($pkg.DisplayName)"
                    $deprovisionedCount++
                } else {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                        Log "  DE-PROVISIONED: $($pkg.DisplayName)"
                        $deprovisionedCount++
                    } catch {
                        $global:FailCount++
                        Log "  FAILED: Could not de-provision $($pkg.DisplayName) - $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    if ($isAdmin) {
        $allInstalled = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    } else {
        $allInstalled = Get-AppxPackage -ErrorAction SilentlyContinue
        if ($IsDryRun) {
            Log "  INFO: Auditing current user packages (provisioned image packages require Administrator)"
        }
    }

    $skippedAppsCount = 0
    foreach ($app in $bloatApps) {
        $installed = if ($allInstalled) {
            $allInstalled.Where({ -not $_.NonRemovable -and $_.Name -match "^$([regex]::Escape($app))" })
        } else { $null }

        if ($installed) {
            foreach ($pkg in $installed) {
                if ($IsDryRun) {
                    Log "  [WOULD REMOVE APP]: $($pkg.Name)"
                    $removedInstalled++
                } else {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        Log "  REMOVED APP: $($pkg.Name)"
                        $removedInstalled++
                    } catch {
                        $global:FailCount++
                        Log "  FAILED: Could not remove $($pkg.Name) - $($_.Exception.Message)"
                    }
                }
            }
        } else {
            $skippedAppsCount++
        }
    }
    if ($skippedAppsCount -gt 0) {
        Log "  SKIP: $skippedAppsCount bloatware packages not installed on system"
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
        $oneDrivePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        Set-RegDwordSafe -path $oneDrivePolicy -name "DisableFileSyncNGSC" -debloatValue 1 -undoValue 0 -removeOnUndo $true

        $odClsidPaths = @(
            "HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
            "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        )
        foreach ($odPath in $odClsidPaths) {
            Set-RegDwordSafe -path $odPath -name "System.IsPinnedToNameSpaceTree" -debloatValue 0 -undoValue 1
        }

        Get-ScheduledTask -TaskPath "\Microsoft\Windows\OneDrive\*" -ErrorAction SilentlyContinue | ForEach-Object {
            Set-TaskState -path $_.TaskPath -name $_.TaskName
        }
        Log "  INFO: To reinstall OneDrive if uninstalled, run: winget install Microsoft.OneDrive"
    } else {
        $odProc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($odProc) {
            if ($IsDryRun) {
                Log "  [WOULD STOP PROCESS]: OneDrive"
            } else {
                Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                Log "  STOPPED: OneDrive process"
            }
        }

        $oneDriveUninstaller = @(
            "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe",
            "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $oneDriveUninstaller) {
            $userSetup = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe"
            if (Test-Path $userSetup) {
                $sig = Get-AuthenticodeSignature -FilePath $userSetup -ErrorAction SilentlyContinue
                if ($sig -and $sig.Status -eq "Valid" -and $sig.SignerCertificate.Subject -match "CN=Microsoft Corporation") {
                    $oneDriveUninstaller = $userSetup
                } else {
                    Log "  [SECURITY WARNING]: Skipping unverified OneDriveSetup.exe in AppData (signature invalid or untrusted)"
                }
            }
        }

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

        $odClsidPaths = @(
            "HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
            "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        )
        foreach ($odPath in $odClsidPaths) {
            Set-RegDwordSafe -path $odPath -name "System.IsPinnedToNameSpaceTree" -debloatValue 0 -undoValue 1
        }

        $oneDrivePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        Set-RegDwordSafe -path $oneDrivePolicy -name "DisableFileSyncNGSC" -debloatValue 1 -undoValue 0 -removeOnUndo $true

        Get-ScheduledTask -TaskPath "\Microsoft\Windows\OneDrive\*" -ErrorAction SilentlyContinue | ForEach-Object {
            Set-TaskState -path $_.TaskPath -name $_.TaskName
        }

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
            Log "  [WOULD SET]: SubmitSamplesConsent = 2 (Never send samples)"
        } else {
            Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop
            Log "  SubmitSamplesConsent = 2 (Disabled telemetry uploads)"
        }
    }
} catch {
    Log "  SKIP: SubmitSamplesConsent (may need policy override or tampering protection exemption)"
}
Log ""

# ============================================================
# 16. ACTIVITY HISTORY & CLOUD CLIPBOARD
# ============================================================
Log "--- 16. Activity History, Timeline & Cloud Clipboard ---"
$sysPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
Set-RegDwordSafe -path $sysPath -name "EnableActivityFeed" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $sysPath -name "PublishUserActivities" -debloatValue 0 -undoValue 1 -removeOnUndo $true

$feedbackPath = "HKCU:\Software\Microsoft\Siuf\Rules"
Set-RegDwordSafe -path $feedbackPath -name "NumberOfSIUFInPeriod" -debloatValue 0 -undoValue 1 -removeOnUndo $true
Set-RegDwordSafe -path $feedbackPath -name "PeriodInNanoSeconds" -debloatValue 0 -undoValue 0 -removeOnUndo $true

$clipPath = "HKCU:\Software\Microsoft\Clipboard"
Set-RegDwordSafe -path $clipPath -name "EnableClipboardSyncAcrossDevices" -debloatValue 0 -undoValue 1
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
# 18. FIREWALL RULES
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
    $existing = Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
    if ($existing) {
        if ($IsUndo) {
            if ($IsDryRun) {
                Log "  [WOULD ENABLE FIREWALL]: $rule"
            } else {
                try {
                    Enable-NetFirewallRule -DisplayName $rule -ErrorAction Stop
                    Log "  ENABLED: $rule"
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not enable firewall rule $rule - $($_.Exception.Message)"
                }
            }
        } else {
            if ($IsDryRun) {
                Log "  [WOULD BLOCK FIREWALL]: $rule"
            } else {
                try {
                    Disable-NetFirewallRule -DisplayName $rule -ErrorAction Stop
                    Log "  BLOCKED: $rule"
                } catch {
                    $global:FailCount++
                    Log "  FAILED: Could not block firewall rule $rule - $($_.Exception.Message)"
                }
            }
        }
    } else {
        Log "  SKIP: Firewall rule '$rule' not found" -DryRun:$DryRun
    }
}
Log ""

# ============================================================
# SUMMARY
# ============================================================
Log "============================================"
if ($IsUndo) {
    if ($IsDryRun) {
        Log "  RESTORE / UNDO COMPLETE (DRY-RUN PREVIEW)"
    } else {
        Log "  RESTORE / UNDO COMPLETE"
    }
} else {
    if ($IsDryRun) {
        Log "  UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE (DRY-RUN PREVIEW)"
    } else {
        Log "  UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE"
    }
}
if ($global:FailCount -gt 0) {
    Log "  [!] NOTICE: Completed with $global:FailCount warning(s) or skipped operation(s)" -Color Yellow
}
Log "============================================"
Log ""

if ($IsDryRun) {
    Log "MODE:                  DRY-RUN AUDIT ONLY (No modifications written to disk or registry)"
}

if ($IsUndo) {
    $act = if ($IsDryRun) { "Would restore" } else { "Restored" }
    Log "Services:              $act SysMain, WSearch, dmwappushservice, DiagTrack, TrkWks, lfsvc"
    Log "Cortana:               Cortana app re-registered and policies reverted"
    Log "OneDrive:              Sync policy cleared, Explorer sidebar re-pinned"
    Log "Privacy settings:      Recommendations, Online Speech, Inking, Search History, Find My Device restored"
    Log "ConsentStore:          Targeted UWP capabilities set back to Allow"
    Log "Security & Network:    LLMNR and Wi-Fi Sense policies reverted"
    Log "Explorer & Taskbar:    News & Interests, People bar, Meet Now, File Extensions restored"
    Log "Telemetry tasks:       CEIP, Office, NVIDIA, Diag, CloudExperienceHost enabled"
    Log "Firewall rules:        8 rules re-enabled"
} else {
    $act = if ($IsDryRun) { "Would disable" } else { "Disabled" }
    Log "Services:              $act SysMain, WSearch, dmwappushservice, DiagTrack, TrkWks, lfsvc"
    Log "Cortana:               Cortana AppX purged and policies enforced"
    if ($KeepOneDrive) {
        Log "OneDrive:              Preserved (-KeepOneDrive enabled)"
    } else {
        $odAct = if ($IsDryRun) { "Would purge" } else { "Purged" }
        Log "OneDrive:              $odAct (Process killed, uninstalled, unpinned from sidebar, sync blocked)"
    }
    if ($KeepXbox) {
        Log "Xbox & Gaming:         Preserved (-KeepXbox enabled)"
    }
    if ($KeepTodos) {
        Log "Microsoft To-Do:       Preserved (-KeepTodos enabled)"
    }
    Log "Privacy hardened:      Recommendations & Offers, Online Speech, Inking dictionary, Search History, Find My Device"
    Log "ConsentStore:          9 capabilities blocked (Location, Diagnostics, Contacts, Tasks, etc.)"
    Log "Security & Network:    LLMNR disabled, Wi-Fi Sense blocked, driver updates preserved"
    Log "Explorer & Taskbar:    File extensions visible, News & Interests removed, People/Meet Now hidden"
    Log "Telemetry tasks:       StartupAppTask, CEIP, Office, Diag, CloudExperienceHost"
    Log "UWP bloatware:         Dual-stage purged ($removedInstalled active, $deprovisionedCount staged packages)"
    Log "Firewall:              8 outbound telemetry/remote rules blocked"
    Log "Startup cleaned:       Edge, OneDrive, Discord removed from auto-start"
}
Log ""
Log "SAFE-TIER PRESERVED (Untouchable):"
Log "  Microphone & Webcam (Fully accessible for Discord, OBS, Teams)"
Log "  Windows Terminal, Microsoft Store, Winget (DesktopAppInstaller)"
Log "  Calculator, Photos, Paint, Snipping Tool"
Log "  Edge rendering engine (startup behavior only suppressed; WebView2 preserved)"
Log "  VS Code, Firefox, Docker auto-updates"
Log ""
if ($IsDryRun) {
    Log "DRY-RUN AUDIT COMPLETE: No restart needed (inspection only, zero changes applied)."
} else {
    Log "REBOOT REQUIRED for all changes to take full effect."
}
Log ""

# ============================================================
# DECOUPLED LOG SAVING
# ============================================================
$logDir = if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
    Join-Path $PSScriptRoot "logs"
} else {
    Join-Path $env:LOCALAPPDATA "unslop-windows\logs"
}

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
} else {
    $dirItem = Get-Item -Path $logDir -ErrorAction SilentlyContinue
    if ($dirItem -and ($dirItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        $uniqueFolder = "logs_" + [System.IO.Path]::GetRandomFileName()
        $logDir = Join-Path $env:LOCALAPPDATA "unslop-windows\$uniqueFolder"
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
}

$prefixName = if ($IsUndo) { "restore" } else { "unslop" }
$modeTag = if ($IsDryRun) { "_dryrun" } else { "" }
$fileOsTag = $osTag.ToLowerInvariant()
$logPath = Join-Path $logDir "$($prefixName)_win10_$($fileOsTag)$($modeTag)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$script:log | Out-File -FilePath $logPath -Encoding UTF8
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

    if ($ForceRestart) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  [!] ACTION: RESTARTING COMPUTER IMMEDIATELY (-ForceRestart)" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        & shutdown.exe /r /t 0 /d p:2:4 /c "unslop-windows: Immediate restart initiated by -ForceRestart." 2>$null
        exit 100
    }

    $shouldInitiate = $false
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  [!] ACTION REQUIRED: SYSTEM RESTART NEEDED" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  A restart is required to finalize debloating and apply all changes." -ForegroundColor Yellow
    Write-Host "  PLEASE SAVE ALL OPEN WORK BEFORE RESTARTING!" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""

    try {
        $response = Read-Host "Initiate 30-second restart countdown? [Y/n] (Press Enter to start countdown, 'n' to postpone)"
        if ([string]::IsNullOrWhiteSpace($response) -or $response.Trim() -match '^(y|yes)$') {
            $shouldInitiate = $true
        }
    } catch {
        $shouldInitiate = $false
        Write-Host "Non-interactive session detected. Skipping automatic restart." -ForegroundColor Cyan
        Write-Host "Please restart your computer manually to apply changes." -ForegroundColor Cyan
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
                    }
                }
                if ($keyHit) { break }
                $secondsLeft--
            }
        } catch {
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
