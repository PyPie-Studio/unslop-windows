# unslop-windows

Universal Windows 11 debloat, telemetry removal, and privacy hardening script for 23H2, 24H2, and 25H2 (Builds 26100 to 26200+).

Single-file PowerShell script. Zero external runtime dependencies. 100% reversible.

---

## Design Principles

Most Windows debloaters break future Windows updates or leave background services in unstable states. `unslop-windows` follows a strict safe-tier architecture:

1. **Servicing Stack Integrity**: Never strips WinSxS packages or modifies DISM system components. Cumulative updates and security patches install without `0x800f0922` failures.
2. **Dual-Stage AppX Removal**: Removes provisioned package bundles from the OS image in addition to installed user apps. Bloatware does not regenerate when creating new accounts or installing feature updates.
3. **Safe Delivery Optimization**: Sets `DODownloadMode = 0` (HTTP only) via Group Policy to stop local and internet peer-to-peer update seeding. The `DoSvc` service stays intact, preventing `0x80d03805` errors in the Microsoft Store.
4. **Symmetrical Restoration**: Every policy, registry key, service state, scheduled task, and firewall rule has an inverse `-Undo` mapping.
5. **Auditable**: `-DryRun` / `-WhatIf` runs in non-elevated user mode to inspect all intended actions before executing with administrator rights.

---

## Comparison Matrix

| Feature | unslop-windows | Chris Titus WinUtil | Sophia Script | Tron Script |
| :--- | :--- | :--- | :--- | :--- |
| **Windows 11 25H2 / 24H2 Support** | Full native support | Partial / lagging | Broken / lagging | Deprecated |
| **Windows Recall & Copilot Killswitch** | GPO + Registry | Registry only | Partial | No |
| **Servicing Stack Safe (No WinSxS cuts)** | Yes | Mixed | Mixed | No (strips components) |
| **Single-File Zero Dependency** | Yes (`unslop.ps1`) | No (GUI / multi-file) | No (Module suite) | No (multi-GB archive) |
| **Symmetrical 1-Click Undo Engine** | Yes (`-Undo`) | Partial | Partial | No |
| **Safe Non-Elevated Dry-Run** | Yes (`-DryRun`) | No | No | No |
| **Untouchable Whitelist Enforced** | Yes (Store/Terminal safe) | User-configured | User-configured | High break risk |
| **Safe Delivery Optimization (No Store breaks)** | GPO `DODownloadMode=0` | Often stops service | Mixed | Disables service |
| **Decoupled Autonomous Logging** | Local `logs/` or `$TEMP` | GUI logs | Local file | Flat text file |

---

## Download & Quickstart

### Method 1: Direct Download (Non-Technical / 1-Click)
No Git or terminal experience needed:

1. Download **[`unslop-windows-v1.0.0.zip`](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.0.0.zip)** from the [Latest Release](https://github.com/PyPie-Studio/unslop-windows/releases/latest).
2. Extract the zip file to any folder.
3. Double-click **`unslop.bat`**.
4. In the console menu, type your choice (e.g. `1` for Full Debloat) and press Enter. If Windows prompts for Administrator elevation (UAC), click **Yes**.

### Method 2: PowerShell One-Liner (Terminal Users)
Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/PyPie-Studio/unslop-windows/main/unslop.bat -OutFile unslop.bat; .\unslop.bat
```

### Method 3: Direct Command-Line Execution
Run directly from Command Prompt or an elevated PowerShell terminal:

**Command Prompt:**
```cmd
unslop.bat -DryRun
unslop.bat -KeepTodos
unslop.bat -Undo
```

**PowerShell:**
```powershell
# Full default debloat
powershell -ExecutionPolicy Bypass -File .\unslop.ps1

# Dry-run audit (safe inspection, no elevation needed)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -DryRun

# Full restore / undo back to Windows defaults
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -Undo
```

---

### Interactive Menu Reference (`unslop.bat`)
When double-clicked without arguments, `unslop.bat` presents this menu:

* `[1]` Full Debloat (Default: Purge OneDrive, telemetry, and consumer bloat)
* `[2]` Dry-Run Audit (Inspect all planned changes safely without modifying system)
* `[3]` Debloat, but Keep Microsoft To-Do (`-KeepTodos`)
* `[4]` Debloat, but Keep Xbox & Gaming Services (`-KeepXbox`)
* `[5]` Debloat, but Keep OneDrive (`-KeepOneDrive`)
* `[6]` Debloat + Enable Classic Context Menu (`-ClassicContextMenu`)
* `[7]` Custom Flags (Prompt for custom parameter combinations)
* `[8]` Full Restore / Undo (`-Undo`: Revert all changes back to defaults)
* `[0]` Exit

---

## Optional Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-DryRun` | Switch | `False` | Audits planned modifications without writing changes. Runs without admin rights. |
| `-Undo` | Switch | `False` | Restores all disabled services, scheduled tasks, and policies. |
| `-KeepOneDrive` | Switch | `False` | Skips OneDrive uninstallation, registry unpinning, and sync blocking policies. |
| `-KeepTodos` | Switch | `False` | Preserves Microsoft To-Do (`Microsoft.Todos`) during AppX cleanup. |
| `-KeepXbox` | Switch | `False` | Preserves Xbox app and Gaming Services for Game Pass users. |
| `-ClassicContextMenu`| Switch | `False` | Restores Windows 10 style full right-click context menu (bypasses "Show more options"). |

### Parameter Examples

**Preserve Gaming Services and OneDrive:**
```powershell
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -KeepXbox -KeepOneDrive
```

**Apply Full Debloat and Enable Classic Context Menu:**
```powershell
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -ClassicContextMenu
```

---

## What Gets Hardened (18 Modules)

1. **Services (6)**: Disables `SysMain`, `WSearch`, `dmwappushservice`, `DiagTrack`, `TrkWks`, and `lfsvc`. Start Menu app search remains functional via shell in-memory index.
2. **Windows Recall & Copilot**: Sets `DisableAIDataAnalysis = 1`, `AllowRecall = 0`, `TurnOffWindowsCopilot = 1`, and removes the Copilot taskbar button.
3. **Telemetry & Diagnostics**: Disables `AllowTelemetry`, CEIP, Application Impact Telemetry, and OneSettings telemetry flighting downloads.
4. **Settings Recommendations & Offers**: Disables lockscreen tips, start menu recommendations, account notification badges, and Content Delivery Manager promotions.
5. **Speech & Inking Personalization**: Disables cloud speech recognition and removes typing/inking dictionary collection.
6. **Search History & Cloud Integration**: Disables local search history tracking, MSA cloud search, and Bing web suggestions.
7. **Network Security & Wi-Fi Sense**: Disables LLMNR (`EnableMulticast = 0`) to mitigate NTLM hash theft on local networks. Disables Wi-Fi hotspot reporting and auto-connect beacons.
8. **Windows Update GPU Driver Protection**: Sets `ExcludeWUDriversInQualityUpdate = 1` to stop Windows Update from overwriting custom NVIDIA or AMD display drivers with generic DCH drivers.
9. **Explorer & Taskbar Cleanliness**: Hides Widgets (`TaskbarDa = 0`) and Chat (`TaskbarMn = 0`). Ensures file extensions are visible (`HideFileExt = 0`).
10. **ConsentStore Permissions (12)**: Revokes background access for location, diagnostics, contacts, calendar, phone, and 25H2 screen text scraping (`foregroundTextAccess`), OS AI model execution (`systemAIModels`), and borderless screen capture (`graphicsCaptureWithoutBorder`).
11. **Scheduled Tasks**: Disables 18+ telemetry tasks across OneSettings, PowerGridForecast, MareBackup, CEIP, Customer Experience, and Disk Diagnostics.
12. **Dual-Stage AppX Purge**: Removes installed packages for all existing user profiles and de-provisions staged packages from the Windows image (TikTok, Spotify, Instagram, Netflix, Solitaire, News, Weather, Get Help, Tips, Feedback Hub).
13. **OneDrive Purge Engine**: Terminates running processes, runs the silent uninstaller, unpins the Explorer sidebar icon (`{018D5C66-4533-4307-9B53-224DE2ED1FE6}`), sets sync block policies (`DisableFileSyncNGSC = 1`), and removes startup registry entries.
14. **Startup Entries & Edge Background**: Disables Edge background application access and startup run keys.
15. **Microsoft Defender Telemetry**: Configures `SubmitSamplesConsent = 0` to block automatic memory and sample file uploads while keeping real-time antivirus active.
16. **Activity History & Cloud Clipboard**: Disables timeline feeds, activity publishing, and cross-device clipboard sync.
17. **Delivery Optimization**: Disables local and internet peer-to-peer update distribution via GPO (`DODownloadMode = 0`) without disabling the servicing daemon.
18. **Firewall Telemetry Rules**: Blocks 8 unnecessary outbound rules for SSDP, Remote Assistance, and Connected Devices Platform.

---

## Untouchable Safety Whitelist

The script explicitly preserves core applications and critical desktop infrastructure:

* **System Tools**: Windows Terminal, Microsoft Store, WinGet (`DesktopAppInstaller`).
* **Essential Desktop Utilities**: Calculator, Photos, Paint, Snipping Tool (`ScreenSketch`).
* **Hardware & Audio**: AMD Noise Suppression / NVIDIA Broadcast, microphone access, and webcam access (never breaks Discord, OBS, or Teams).
* **Developer Tools**: VS Code, Visual Studio, Your already existent stack and browser update tasks.
* **WebView2 / Edge Engine**: Runtime engines are preserved so desktop apps relying on web views function normally.

---

## Logs

Execution logs are saved automatically to `.\logs\unslop_25h2_<timestamp>.log` relative to the script, or to `$env:TEMP\unslop_logs` when executed via remote streams.

---

## License

MIT License. Copyright (c) 2026 PyPie Studio.
