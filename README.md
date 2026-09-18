<div align="center">

# unslop-windows

Standalone PowerShell script to debloat Windows 10 and 11.
Disables telemetry, removes junk apps, blocks Recall/Copilot and cleans up background services — without breaking Windows Update or the Microsoft Store.

[![GitHub release](https://img.shields.io/github/v/release/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=green)](https://github.com/PyPie-Studio/unslop-windows/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/PyPie-Studio/unslop-windows/lint.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/PyPie-Studio/unslop-windows/actions)
[![Windows 11](https://img.shields.io/badge/Windows%2011-25H2%20%7C%2024H2%20%7C%2023H2%20%7C%2022H2-0078D6?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![Windows 10](https://img.shields.io/badge/Windows%2010-22H2%20%7C%2021H2%20%7C%20LTSC%20%7C%2010240--19045-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

[Download](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.3.1.zip) · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md)

</div>

---

```text
============================================================
  unslop-windows (v1.3.1) - PyPie Studio
  Windows 10 & 11 Debloater and Privacy Tool
============================================================

  Select your Windows version:

  [1] Windows 11 (25H2 / 24H2 / 23H2 / 22H2 / 21H2)
  [2] Windows 10 (22H2 / 21H2 / 20H2 / Enterprise LTSC / Builds 10240-19045)
  [0] Exit

============================================================
Select an option [0-2]: 
```

---

## Download and Quickstart

> [!IMPORTANT]
> **Run as Administrator.** The script configures Group Policies, Services, Registry keys and de-provisions AppX packages. Administrator rights are required (except `-DryRun`, which runs safely without elevation).
>
> **Restart required after running.** Windows caches service states and policies in memory. A full restart is needed to finalize all changes.
>
> **Save your work first.** After the script finishes, you get an interactive prompt: press `n` to skip restarting or `Enter`/`Y` to start a 30-second countdown. During the countdown, press `A` to abort or `R` to reboot immediately.

### Direct Download (No Git Required)

1. Download **[`unslop-windows-v1.3.1.zip`](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.3.1.zip)** from the [Latest Release](https://github.com/PyPie-Studio/unslop-windows/releases/latest).
2. Extract the `.zip` to any folder.
3. Right-click **`unslop.bat`** → **Run as administrator**.
4. Pick your OS version, then pick a preset:
   - **[1] Full Debloat** — removes OneDrive, telemetry and bloatware
   - **[2] Gamer Preset** — debloat but keep Xbox and Gaming Services
   - **[3] Productivity Preset** — debloat but keep OneDrive and To-Do
   - **[4] Interactive Toggles** — pick exactly what to keep/remove
   - **[5] Dry-Run Audit** — preview all changes without modifying anything
   - **[6] Undo / Restore** — revert all tweaks back to Windows defaults
   - **[7] Custom CLI Flags** — enter specific custom parameters

### Git Clone

```powershell
git clone https://github.com/PyPie-Studio/unslop-windows.git
cd unslop-windows
.\unslop.bat
```

### Direct PowerShell

```powershell
# Full debloat (Windows 11)
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1

# Preview changes without modifying anything (no admin needed)
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -DryRun

# Keep Xbox and OneDrive
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -KeepXbox -KeepOneDrive

# Keep Windows Search and SysMain
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -KeepSearch -KeepSysMain

# Undo everything back to Windows defaults
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -Undo

# Windows 10
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -Undo
```

### CMD

```cmd
unslop.bat                          :: interactive menu
unslop.bat -DryRun                  :: preview mode
unslop.bat -Win10 -KeepXbox         :: Windows 10, keep Xbox
unslop.bat -KeepSearch -KeepSysMain :: keep Search and SysMain
unslop.bat -Undo                    :: undo all changes
```

---

## Supported Versions

Two separate PowerShell scripts — one for Windows 11, one for Windows 10 — so each handles the right OS-specific APIs and policies:

| OS | Builds | Script |
| :--- | :--- | :--- |
| Windows 11 25H2 | 26200+ | `unslop-win11.ps1` |
| Windows 11 24H2 | 26100–26120 | `unslop-win11.ps1` |
| Windows 11 23H2 | 22631 | `unslop-win11.ps1` |
| Windows 11 22H2 / 21H2 | 22621 / 22000 | `unslop-win11.ps1` |
| Windows 10 22H2 | 19045 | `unslop-win10.ps1` |
| Windows 10 21H2–20H2 | 19044–19041 | `unslop-win10.ps1` |
| Windows 10 1909–1507 | 18363–10240 | `unslop-win10.ps1` |
| Windows 10 LTSC 2021/2019/2016 | 19044 / 17763 / 14393 | `unslop-win10.ps1` |
| Windows 10 IoT Enterprise LTSC | 19044–19045 | `unslop-win10.ps1` |

---

## What It Does (18 Modules)

Each script runs 18 modules. Here is what they touch:

1. **Background services** — Disables `SysMain`, `WSearch`, `DiagTrack`, `dmwappushservice`, `TrkWks` and `lfsvc`. Start menu search stays fast (shell in-memory index). Skip with `-KeepSysMain` or `-KeepSearch`.
2. **Recall and Copilot (Win11) / Cortana (Win10)** — Win11: disables Recall snapshotting (`DisableAIDataAnalysis=1`), removes Copilot policies and taskbar shortcuts. Win10: disables Cortana (`AllowCortana=0`) and uninstalls the app.
3. **Telemetry** — Sets `AllowTelemetry=0`, disables CEIP, Application Impact Telemetry and OneSettings config downloads.
4. **Start menu and lock screen ads** — Disables lock screen tips, app recommendations, notification promotions and automatic sponsored app installs.
5. **Speech and typing data** — Disables cloud speech recognition and inking/typing dictionary collection.
6. **Search tracking** — Disables search history, Microsoft account integration and Bing suggestions in Start.
7. **Network privacy** — Disables LLMNR (`EnableMulticast=0`) to block credential sniffing. Disables Wi-Fi hotspot reporting.
8. **Driver updates (kept safe)** — Preserves Windows Update hardware driver delivery by default. Exclude driver updates with `-ExcludeWUDrivers`.
9. **Taskbar and Explorer** — Win11: disables Widgets via GPO, hides Chat. Win10: hides News & Interests, People bar, Meet Now. Both: shows file extensions. Left-align taskbar icons with `-LeftTaskbar`.
10. **App permissions (ConsentStore)** — Revokes background access for location, diagnostics, contacts, calendar, phone. Win11 also blocks `foregroundTextAccess` and `systemAIModels`.
11. **Diagnostic scheduled tasks** — Disables 20+ background telemetry tasks (OneSettings, CEIP, Customer Experience, Disk Diagnostics, etc).
12. **Bloatware removal** — Removes TikTok, Spotify, Instagram, Netflix, Candy Crush, Disney+, Prime Video and other pre-installed apps from current user and system image (so they don't come back for new accounts). Win11 also removes AI integrations (aimgr, AIFabric, AugLoop). Skip with `-KeepXbox`, `-KeepTodos`, `-KeepSpotify`, `-KeepPhoneLink`, `-KeepMail` or `-KeepClock`.
13. **OneDrive removal** — Stops OneDrive, runs uninstaller, unpins from Explorer sidebar, blocks sync. Skip with `-KeepOneDrive`.
14. **Startup and Edge cleanup** — Stops Edge background tasks. Backs up removed startup entries to the registry for `-Undo`.
15. **Defender sample submissions** — Sets `SubmitSamplesConsent=2` (NeverSend) to stop automatic file uploads. Real-time AV stays active. Skip with `-KeepDefenderDefaults`.
16. **Activity history** — Disables timeline feeds, Connected Devices Platform and Cross-Device Resume.
17. **Delivery Optimization** — Disables P2P update sharing via GPO (`DODownloadMode=0`). Throttles Store auto-downloads (skip with `-KeepStoreAutoUpdate`). `DoSvc` service stays active so the Store works.
18. **Outbound firewall rules** — Blocks outbound traffic for diagnostic endpoints, SSDP discovery and connected device tracking.

---

## What It Never Touches

These components are explicitly protected and will not be modified or removed:

| Category | Items | Reason |
| :--- | :--- | :--- |
| System tools | Windows Terminal, Microsoft Store, WinGet | Required for installs and package management |
| Desktop apps | Calculator, Photos, Paint, Snipping Tool | Daily-use tools with no telemetry overhead |
| Clipboard | Local `Win+V` clipboard history | Only cloud cross-device sync is disabled |
| System hosts | CloudExperienceHost, Photon, CoreAI, UCPD | Immutable system packages (AI capabilities disabled via GPO instead) |
| Audio/Video | Microphone, Webcam, NVIDIA/AMD audio filters | Prevents breaking Discord, OBS, Teams |
| Dev tools | Visual Studio, VS Code, Git, Docker, Ollama | Never touched |
| Runtimes | WebView2, Edge rendering engine | Required by desktop apps for web views |
| WinSxS | Component store and DISM manifests | Never touched — monthly Cumulative Updates install cleanly |

---

## Parameters

| Flag | OS | What It Does |
| :--- | :--- | :--- |
| `-DryRun` | Both | Preview all changes without modifying anything. No admin needed. |
| `-Undo` | Both | Revert all changes back to Windows defaults. |
| `-KeepOneDrive` | Both | Skip OneDrive removal. |
| `-KeepTodos` | Both | Keep Microsoft To-Do. |
| `-KeepXbox` | Both | Keep Xbox app and Gaming Services. |
| `-ClassicContextMenu` | Win11 | Restore old right-click menu (skip "Show more options"). |
| `-NoRestart` | Both | Skip the restart prompt after completion. |
| `-ForceRestart` | Both | Restart immediately without prompting. |
| `-SkipBuildCheck` | Both | Skip OS build verification (for CI/testing). |

### Granular Custom Flags

Pass these flags via CLI or enter them under Option `[7]` (Custom CLI Flags) in `unslop.bat` to keep specific components or adjust individual system behaviors:

| Flag | OS | What It Does |
| :--- | :--- | :--- |
| `-KeepSysMain` | Both | Keep SysMain (Superfetch) service running. Recommended for mechanical HDDs and hybrid storage. |
| `-KeepSearch` | Both | Keep Windows Search indexer (`WSearch`) service running. |
| `-KeepPhoneLink` | Both | Keep Phone Link app (`Microsoft.YourPhone`) and cross-device sync services. |
| `-KeepMail` | Both | Keep Outlook / Mail and Calendar apps (`Microsoft.OutlookForWindows`, `Microsoft.WindowsCommunicationsApps`). |
| `-KeepClock` | Win10 | Keep Windows Clock and Alarms app (`Microsoft.WindowsAlarms`). |
| `-KeepSpotify` | Both | Keep pre-installed Spotify app (`SpotifyAB.SpotifyMusic`). |
| `-KeepStoreAutoUpdate` | Both | Keep Microsoft Store automatic background app updates enabled. |
| `-LeftTaskbar` | Win11 | Align taskbar icons to the left instead of center. |
| `-ExcludeWUDrivers` | Both | Prevent Windows Update from delivering hardware driver updates. |
| `-KeepDefenderDefaults` | Both | Preserve default Microsoft Defender sample submission settings. |

---

## Why I Built This

I tried the popular debloaters and ran into real problems:

- Some broke the WebView2 engine that Microsoft is integrating into most Windows 11 components.
- Some were built for older Windows versions and didn't cover Recall, Copilot or the 24H2/25H2 AI features.
- Some had changes that came back after Windows feature updates because they only removed apps from the current user instead of de-provisioning from the system image.
- None had a clean `-Undo` flag that could revert every single change with one command.

This script takes a different approach:
- **Pure PowerShell and Batch.** No compiled binaries, no GUI, no third-party dependencies. You can read every line.
- **Never touches WinSxS or DISM manifests.** Monthly Cumulative Updates install cleanly without `0x800f0922` errors.
- **De-provisions from the system image.** Bloatware doesn't come back for new user accounts or after feature updates.
- **`-Undo` reverts everything.** Every registry key, service state, scheduled task and firewall rule has a matching reverse operation.
- **`-DryRun` for inspection.** Run without admin rights to see every proposed change before committing.
- **Delivery Optimization done right.** Disables P2P sharing via GPO (`DODownloadMode=0`) without killing `DoSvc`, so the Microsoft Store doesn't throw error `0x80d03805`.

Tested across 30+ machines (physical PCs and VMware VMs) running Windows 11 (25H2, 24H2 and 23H2) and Windows 10 (22H2 and LTSC).

---

## Benchmarking

Measure your own system state before and after:

```powershell
# Live system metrics
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1

# Before/after comparison
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "before"
# ... run debloat, restart ...
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "after"
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Baseline "logs/before.json" -Target "logs/after.json" -ExportMarkdown "docs/benchmarks.md"
```

### Cryptographic Verification

Official releases include `SHA256SUMS.txt`:
```powershell
Get-FileHash unslop-windows-v*.zip -Algorithm SHA256
```

---

## Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

- **Bug reports:** [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md)
- **Feature requests:** [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **Architecture decisions:** [docs/decisions.md](docs/decisions.md)

---

## License

MIT License. Copyright (c) 2026 PyPie Studio.
