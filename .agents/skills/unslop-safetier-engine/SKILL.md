---
name: unslop-safetier-engine
description: Core debloater and hardening engine procedures, 18-module execution lifecycle, strict 100% symmetrical -Undo restoration contract, defensive registry tree manipulation, safe AppX package de-provisioning, and service/task transitions.
---

# unslop-safetier-engine

This skill governs the core execution engine of **unslop-windows** ([`unslop.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.ps1) and [`unslop.bat`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.bat)).

---

## 🛡 The 18 Hardening Modules
`unslop.ps1` executes 18 distinct modular stages in a deterministic sequence:

1. **Telemetry & Diagnostics:** DiagTrack, dmwappushservice, Connected User Experiences and Telemetry.
2. **Advertising & Privacy ID:** Tailored experiences, Advertising ID, typing/inking telemetry.
3. **Consumer Bloat & Cloud Recommendations:** ContentDeliveryManager silent consumer app installs.
4. **Bing & Search Bloat:** Start menu web search integration, Bing search highlights.
5. **Cortana & Windows Copilot:** Taskbar integration, sidebar policy, Copilot killswitches.
6. **Windows Recall & Screenray Snapshots:** 24H2/25H2 AI snapshot engine, `DisableAIDataAnalysis = 1`.
7. **25H2 ConsentStore Capabilities:** Sensor and scraping access permissions (`foregroundTextAccess`, `systemAIModels`, `graphicsCaptureWithoutBorder`).
8. **App Permissions & Sensor Scrapers:** Radios, call history, diagnostics data access.
9. **Diagnostics & Error Reporting (WER):** Watson error reporting throttling and crash dump uploads.
10. **Windows Feedback & Customer Experience (CEIP):** Feedback frequency policies and scheduled tasks.
11. **Start Menu & Lock Screen Recommendations:** Lock screen tips, suggestions, and rotating ads.
12. **File Explorer Ads & Upsells:** Sync provider notifications and Office/OneDrive upsell banners.
13. **Activity History & Timeline:** Device clipboard history cloud sync and activity history tracking.
14. **Safe UWP / AppX Bloatware Removal:** Non-essential preloaded apps (Cortana, Solitaire, Tips, Xbox companion) with strict runtime whitelist.
15. **Telemetry Scheduled Tasks:** Disabling Windows Customer Experience and Application Experience tasks.
16. **Telemetry Services State:** Setting unneeded telemetry collection services to `Disabled`.
17. **Edge Background Bloat:** Startup boost background processes and pre-launch telemetry tasks.
18. **Network & DNS Privacy Hardening:** NCSI passive probing and smart multi-homed name resolution.

---

## 🔒 Engine Invariants & Modification Rules

### 1. The Symmetry Requirement (`-Undo`)
- Every new tweak or modification added to an existing module **MUST** include an exact inverse implementation in the `if ($Undo)` block.
- When creating a registry key that didn't previously exist in clean Windows, the `-Undo` routine must use `Remove-ItemProperty` or `Remove-Item` to restore original state.
- When changing a default Windows value, the `-Undo` routine must set it back to the exact default value.
- Never add a one-way modification to `unslop.ps1`.

### 2. Defensive Registry & Mutation Architecture (No Placebo Logging)
- Pre-create missing keys defensively:
  ```powershell
  if (-not (Test-Path $regPath)) {
      New-Item -Path $regPath -Force -ErrorAction SilentlyContinue | Out-Null
  }
  ```
- Gate every mutating action behind `if (-not $DryRun)` and wrap inside `try/catch` with `-ErrorAction Stop`:
  ```powershell
  if (-not $DryRun) {
      try {
          Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord -Force -ErrorAction Stop
          Log "  [+] SET: $path\$name = $value" "Green"
      } catch {
          Log "  [-] FAILED: $path\$name - $($_.Exception.Message)" "Red"
          $global:FailCount++
      }
  } else {
      Log "  [DRY-RUN] Would set: $path\$name = $value" "Cyan"
  }
  ```
- **Zero Placebo Logging:** Never use blanket `-ErrorAction SilentlyContinue` on mutations followed by unconditional success logs (`[+] SET:`). If an operation fails due to permissions, locks, or missing keys, log `[-] FAILED:` and increment `$global:FailCount`.

### 3. Safe AppX Removal & Condensation
- Distinguish between current user packages and all-users provisioned packages:
  ```powershell
  Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
  Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
  ```
- **Condense Repetitive Non-Events:** When packages are already absent from the OS image, do not flood the console with dozens of `SKIP: ... (not installed)` lines. Track absent packages in an aggregate counter and emit a single summary line:
  ```powershell
  if ($skipCount -gt 0) {
      Log "  [-] SKIP: $skipCount bloatware packages not installed (already clean)" "DarkGray"
  }
  ```
- **Never Touch System Packages:**
  - Whitelist: `Microsoft.WindowsStore`, `Microsoft.DesktopAppInstaller`, `Microsoft.WindowsTerminal`, `Microsoft.XboxIdentityProvider`, VCLibs, DirectX, and .NET packages.
  - Never use wildcards like `*Microsoft*` without an explicit, scrutinized allow-list.

### 4. Reboot & Exit Code Contract
- Post-execution reboot countdown uses in-place console detection (`$Host.UI.RawUI.KeyAvailable`).
- Handles `A` (abort via `shutdown.exe /a`), `R`/`Enter` (immediate restart), and `Ctrl+C` interrupt cleanup.
- Exits with code `100` when a reboot is scheduled so `unslop.bat` cleanly closes without pausing.

### 5. Console UI/UX, Color Hierarchy & Reporting Standards
- **Semantic Console Colors**: Use `Write-Host -ForegroundColor` for user feedback:
  - `Cyan`: Titles, stage headers, and dry-run preview tags.
  - `Green`: Successful mutations and completion banners.
  - `Yellow`: Warnings, reboot countdown prompts, and cancellation alerts.
  - `DarkGray`: Skipped items and already-hardened states.
  - `Red`: Hard failures and exceptions.
  - Disk logging (`$LogFile`) must remain clean plain text without ANSI escape sequences.
- **Dynamic Completion Banners**: Summary banners must dynamically reflect runtime parameters (`-KeepOneDrive`, `-KeepXbox`, `-KeepTodos`, `-ClassicContextMenu`) and explicitly flag preview mode when `-DryRun` is active, while preserving quality gate verification tokens (`UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE` and `RESTORE / UNDO COMPLETE`).

### 6. Batch Launcher Interactive Architecture
- **Interactive Multi-Select Toggles**: `unslop.bat` provides sub-menus (`:toggles`) using pure batch flag state tracking (`!TOGGLE_*!`) to toggle arguments before launching.
- **UAC Dismissal Error Trapping**: Always inspect `%errorlevel%` after `Start-Process ... -Verb RunAs`. If non-zero (elevation cancelled or denied), warn the user and return to the menu instead of abruptly closing the terminal.
- **Anti-Screen-Amnesia**: Never clear the screen immediately after an audit run (`:run_dry`); prompt the user to review the output first.

---

## 🛡 Security & Privilege Boundary Engineering Standards

### 1. User-Space Binary Invocation Defense (VULN-01)
Elevated processes must never execute untrusted executables from user-writable directories (`$env:LOCALAPPDATA`, `$env:USERPROFILE`, `$env:TEMP`) without cryptographic validation:
- **Search Order Priority**: Prioritize machine-wide, Administrator-writable directories (`$env:ProgramFiles`, `$env:ProgramFiles(x86)`, `$env:SystemRoot\System32`) first.
- **Authenticode Cryptographic Validation**: If an executable is found in user-writable space (such as legacy user-installed OneDrive uninstaller), verify its digital signature before calling `Start-Process`:
  ```powershell
  $sig = Get-AuthenticodeSignature -FilePath $exePath
  if ($sig.Status -eq "Valid" -and $sig.SignerCertificate.Subject -like "*CN=Microsoft Corporation*") {
      Start-Process -FilePath $exePath -ArgumentList "/uninstall" -Wait -NoNewWindow
  } else {
      Log "  [-] BLOCKED: $exePath signature invalid ($($sig.Status)). Skipping uninstaller execution." "Red"
  }
  ```

### 2. Batch CLI Argument Token Whitelisting (VULN-02)
Never interpolate raw `%*` or `!ARGS!` directly into elevated execution strings (`Start-Process ... -ArgumentList "%*"`), as metacharacters (`&`, `|`, `"`, `;`) allow arbitrary command chaining. Instead, parse arguments iteratively through a strict token whitelist:
```cmd
set "SAFE_ARGS="
for %%A in (%*) do (
    set "VALID_ARG=0"
    if /i "%%~A"=="-DryRun" set "VALID_ARG=1"
    if /i "%%~A"=="-Undo" set "VALID_ARG=1"
    if /i "%%~A"=="-KeepXbox" set "VALID_ARG=1"
    if /i "%%~A"=="-KeepOneDrive" set "VALID_ARG=1"
    if /i "%%~A"=="-KeepTodos" set "VALID_ARG=1"
    if /i "%%~A"=="-ClassicContextMenu" set "VALID_ARG=1"
    if "!VALID_ARG!"=="1" (
        set "SAFE_ARGS=!SAFE_ARGS! %%~A"
    ) else (
        echo [!] WARNING: Ignored untrusted argument '%%~A'
    )
)
```

### 3. Fail-Closed Offline Architecture (VULN-03)
The debloater must operate in strictly isolated, air-gapped, or offline environments. Never implement automatic fallback downloads (`Invoke-RestMethod`, `curl`, `Invoke-WebRequest`) in scripts or batch launchers. If required companion scripts (e.g. `unslop.ps1`) are missing:
```cmd
if not exist "%~dp0unslop.ps1" (
    echo [!] ERROR: unslop.ps1 not found in directory: %~dp0
    echo [*] Please verify all files are extracted together before running.
    exit /b 1
)
```

### 4. Reparse Point & Junction Path Guard (OPSEC-01)
When initializing logging or scratch directories in user-writable paths (`$env:TEMP`, `.\logs`), check for reparse points (symlinks/junctions) to prevent junction redirection attacks targeting arbitrary system locations:
```powershell
if (Test-Path $logDir) {
    $dirItem = Get-Item $logDir -Force -ErrorAction SilentlyContinue
    if ($dirItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Remove-Item -Path $logDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
}
```

