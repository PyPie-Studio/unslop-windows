<div align="center">

# 🧹 unslop-windows

### Stop Microsoft from harvesting your data and eating your RAM.
**The Safe-Tier Windows 11 (25H2/24H2/23H2/22H2) & Windows 10 (22H2/21H2/LTSC/Build 10240+) Unslopper, Debloater, and Privacy Hardener.**

[![GitHub stars](https://img.shields.io/github/stars/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/network/members)
[![GitHub release](https://img.shields.io/github/v/release/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=green)](https://github.com/PyPie-Studio/unslop-windows/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/PyPie-Studio/unslop-windows/lint.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/PyPie-Studio/unslop-windows/actions)
[![Windows 11](https://img.shields.io/badge/Windows%2011-25H2%20%7C%2024H2%20%7C%2023H2%20%7C%2022H2-0078D6?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![Windows 10](https://img.shields.io/badge/Windows%2010-22H2%20%7C%2021H2%20%7C%20LTSC%20%7C%2010240--19045-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

[⚡ Quick Download](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.2.3.zip) • [📋 Changelog](CHANGELOG.md) • [🗺️ Roadmap](ROADMAP.md) • [🚀 Real-World Impact](#-measured-real-world-impact) • [📊 How It Compares](#-how-it-compares) • [🛡️ Safety Principles](#-safety-principles-what-keeps-windows-working) • [⚙️ All 18 Modules](#-what-unslop-windows-tweaks--cleans-18-modules-per-engine) • [🔒 Protected Components](#-protected-apps--components-what-we-never-touch)

</div>

---

> [!TIP]
> ⭐ **Reclaiming your Windows from Microslop?**
> Give this repository a star on GitHub! It helps more users find a clean, open-source alternative that doesn't break Cumulative Updates or the Microsoft Store.

---

```text
============================================================
  unslop-windows (v1.2.3) - PyPie Studio
  Windows 10 & 11 Unslopper, Debloater and Privacy Tool
============================================================

  Select your Windows version:

  [1] Windows 11 (25H2 / 24H2 / 23H2 / 22H2 / 21H2)
  [2] Windows 10 (22H2 / 21H2 / 20H2 / Enterprise LTSC / Builds 10240-19045)
  [0] Exit

============================================================
Select an option [0-2]: 
```

---

## ⚡ Download & Quickstart

> [!IMPORTANT]
> ### ⚠️ Mandatory Requirements: Administrator Rights & System Restart
> 1. **Run as Administrator**: `unslop-windows` configures system-level Group Policies, Services, Registry trees, and de-provisions AppX packages. The script **must be executed as an Administrator** (except `-DryRun`, which safely audits changes without elevation).
> 2. **System Restart Required**: Windows caches service states, group policies, and background telemetry threads in memory. A **full system restart is required** after the script is done to finalize all debloat, privacy, and performance optimizations.
> 3. **Save Your Work & Restart Controls**: Please save all open documents before running. Upon completion, the script presents an interactive confirmation prompt (`Initiate 30-second restart countdown? [Y/n]`): press **`n`** to postpone the restart and reboot manually later, or press **Enter** (or `Y`) to start the 30-second countdown. During an active countdown, you can tap **`A`** to abort the restart (`shutdown /a`), or **`R`** to reboot immediately. If allowed to finish, the system restarts and the launcher window closes automatically.

### Method 1: Direct Download (1-Click / Non-Technical)
No Git, terminal commands, or PowerShell knowledge needed:

1. Download **[`unslop-windows-v1.2.3.zip`](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.2.3.zip)** from the [Latest Release](https://github.com/PyPie-Studio/unslop-windows/releases/latest).
2. Extract the `.zip` archive to any folder.
3. Right-click **`unslop.bat`** and select **Run as administrator** (or double-click and accept the UAC prompt).
4. Select your operating system from the selection menu:
   - `[1]` **Windows 11** (25H2 / 24H2 / 23H2 / 22H2 / 21H2)
   - `[2]` **Windows 10** (22H2 / 21H2 / 20H2 / Enterprise LTSC / Builds 10240–19045)
5. Choose an option from the OS feature menu:
   - **[1] Full Debloat**: Purge OneDrive, telemetry, and provisioned bloatware.
   - **[2] Gamer Preset**: Debloat, but Keep Xbox & Gaming Services (`-KeepXbox`).
   - **[3] Productivity Preset**: Debloat, but Keep OneDrive & Microsoft To-Do (`-KeepOneDrive -KeepTodos`).
   - **[4] Interactive Toggles**: Configure custom feature combinations with visual toggle states.
   - **[5] Safe Dry-Run Audit**: Inspect all changes safely with zero system modifications (`-DryRun`).
   - **[6] Full Restore / Undo**: Symmetrically revert all tweaks back to defaults (`-Undo`).
   - **[7] Custom CLI Flags**: Manually enter parameter switches (e.g. `-KeepTodos -KeepXbox -NoRestart`).
   - **[8] Back to OS Selection**: Return to the main OS choice screen.
   - **[0] Exit**: Close the launcher.
6. When the script completes, ensure your work is saved: press **`n`** to postpone rebooting and return to the menu, or press **Enter** (or `Y`) to start the 30-second countdown (during the countdown, tap **`A`** to abort or **`R`** to reboot immediately).

### Method 2: Git Clone (Developers & Terminal Users)
Clone and run straight from an elevated terminal:

```powershell
# Run inside an elevated terminal (PowerShell or Windows Terminal)
git clone https://github.com/PyPie-Studio/unslop-windows.git
cd unslop-windows
.\unslop.bat
```

### Method 3: Direct Command-Line Execution
Run directly from an **Administrator Command Prompt** or an **Elevated PowerShell** terminal:

**Command Prompt (CMD - Run as Administrator):**
```cmd
:: Unified interactive launcher (prompts for Windows 10 vs 11)
unslop.bat

:: Windows 11 Direct Execution (targets unslop-win11.ps1)
unslop.bat -DryRun
unslop.bat -Win11 -DryRun
unslop.bat -KeepXbox -KeepOneDrive
unslop.bat -Undo

:: Windows 10 Direct Execution (targets unslop-win10.ps1)
unslop.bat -Win10 -DryRun
unslop.bat -Win10 -KeepXbox
unslop.bat -Win10 -Undo
```

**PowerShell (Run as Administrator):**
```powershell
# ============================================================
# Windows 11 Execution (unslop-win11.ps1)
# Targets: 25H2, 24H2, 23H2, 22H2, 21H2 (Build 22000+)
# ============================================================

# Full default debloat (prompts for restart countdown upon completion)
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1

# Dry-run audit (safe inspection, zero changes, non-elevated)
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -DryRun

# Debloat while preserving Xbox gaming services and OneDrive
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -KeepXbox -KeepOneDrive

# Restore classic Windows 10 full context menu
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -ClassicContextMenu

# Full symmetrical restore back to clean Windows 11 defaults
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -Undo

# ============================================================
# Windows 10 Execution (unslop-win10.ps1)
# Targets: 22H2, 21H2, 20H2, 2004, 1909, 1809, 1607, 1507, LTSC (Builds 10240-19045)
# ============================================================

# Full default debloat for Windows 10
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1

# Dry-run audit for Windows 10 (safe inspection, non-elevated)
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -DryRun

# Debloat Windows 10 while keeping Xbox gaming services
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -KeepXbox

# Full symmetrical restore back to clean Windows 10 defaults
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -Undo
```

---

## 💻 Supported OS Releases, Builds & Script Architecture

`unslop-windows` provides dedicated, isolated PowerShell engines for Windows 11 and Windows 10 to ensure zero feature regressions, clean servicing stack safety, and 100% symmetrical restoration:

| Operating System Version | Build Numbers | Supported Engine Script | Batch Launcher Option | Key OS-Specific Modules |
| :--- | :--- | :--- | :--- | :--- |
| **Windows 11 25H2** | Build 26200+ | [`unslop-win11.ps1`](unslop-win11.ps1) | `unslop.bat [1]` or `-Win11` | AI Agent telemetry, Recall killswitch, ConsentStore `foregroundTextAccess` / `systemAIModels` |
| **Windows 11 24H2** | Build 26100 - 26120 | [`unslop-win11.ps1`](unslop-win11.ps1) | `unslop.bat [1]` or `-Win11` | Recall snapshotting killswitch, Copilot removal, UCPD Widgets GPO defense |
| **Windows 11 23H2** | Build 22631 | [`unslop-win11.ps1`](unslop-win11.ps1) | `unslop.bat [1]` or `-Win11` | Chat taskbar button suppression, Bing search history, 23H2 AppX purge |
| **Windows 11 22H2 / 21H2** | Build 22621 / 22000 | [`unslop-win11.ps1`](unslop-win11.ps1) | `unslop.bat [1]` or `-Win11` | Initial Win11 telemetry endpoints, Widgets GPO, classic context menu option |
| **Windows 10 22H2 (Current / ESU)** | Build 19045 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Complete Cortana de-provisioning, News & Interests suppression, Meet Now hide |
| **Windows 10 21H2 / 21H1** | Build 19044 / 19043 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | News & Interests Feeds suppression, People Band removal, OneDrive purge |
| **Windows 10 20H2 / 2004** | Build 19042 / 19041 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Cortana UWP decoupling, Meet Now icon suppression, Edge background tasks |
| **Windows 10 1909 / 1903** | Build 18363 / 18362 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Search box cloud telemetry, Timeline cross-device sync disablement |
| **Windows 10 1809 / LTSC 2019** | Build 17763 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Enterprise LTSC telemetry compliance, Cloud Clipboard sync disablement |
| **Windows 10 1803 / 1709 / 1703** | Build 17134 / 16299 / 15063 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Diagnostic data tracking, AppX 3DBuilder / Print3D legacy de-provisioning |
| **Windows 10 1607 / LTSB 2016** | Build 14393 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Enterprise LTSB 2016 safe debloat, DiagTrack & dmwappushservice suppression |
| **Windows 10 1511 / 1507 / LTSB 2015**| Build 10586 / 10240 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Base Windows 10 release compatibility, legacy telemetry task cleanup |
| **Windows 10 Enterprise LTSC 2021** | Build 19044.1288+ | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | Safe LTSC debloat preserving enterprise store and activation mechanisms |
| **Windows 10 IoT Enterprise LTSC** | Build 19044 / 19045 | [`unslop-win10.ps1`](unslop-win10.ps1) | `unslop.bat [2]` or `-Win10` | IoT embedded debloat, hardware driver preservation, zero broken components |

---

## 🚀 Measured Real-World Impact

* 📉 **~50% Lower Idle RAM**: Drops idle memory usage from **~10 GB down to ~5 GB** on a typical Windows 11 system (tested on 25H2 with 32 GB RAM).
* 🚫 **Zero Bloatware Respawns**: De-provisioning packages from the system image ensures consumer apps (TikTok, Spotify, Candy Crush) never reinstall after Windows updates.
* ⚡ **Eliminated Background Thrashing**: Stops idle `svchost` telemetry threads, `SearchIndexer` disk crawls and `SysMain` (Superfetch) prefetch bloat.
* 🧠 **More Headroom for Heavy Workloads**: Frees up vital host RAM for local LLMs (Ollama / vLLM), Docker containers, compilation and gaming.

---

## 📊 How It Compares

How `unslop-windows` compares to other popular debloaters:

| Feature / Capability | unslop-windows | Chris Titus WinUtil | Sophia Script | Tron Script |
| :--- | :---: | :---: | :---: | :---: |
| **Windows 11 (25H2 / 24H2 / 23H2 / 22H2)** | ✅ Full Native | ⚠️ Partial / Lagging | ❌ Broken / Lagging | ❌ Deprecated |
| **Windows 10 (22H2 / 21H2 / LTSC / 10240+)**| ✅ Full Native | ⚠️ Generic | ⚠️ Legacy Sophia | ❌ Deprecated |
| **Disable Recall & Copilot (Win11)** | ✅ Full GPO + Registry | ⚠️ Registry Only | ⚠️ Partial | ❌ No |
| **Remove Cortana (Win10)** | ✅ GPO + AppX | ⚠️ Partial | ⚠️ AppX Only | ❌ Unclean |
| **Safe Servicing Stack (Keeps WinSxS & Updates intact)** | ✅ 100% Safe | ⚠️ Mixed | ⚠️ Mixed | ❌ Strips Components |
| **Zero Third-Party Dependencies** | ✅ Pure Native PS/Batch | ❌ GUI / Multi-file | ❌ Module Suite | ❌ Multi-GB Archive |
| **Full 1-Click Rollback (-Undo)** | ✅ Yes (`-Undo`) | ⚠️ Partial | ⚠️ Partial | ❌ No |
| **Safe Non-Elevated Dry-Run** | ✅ Yes (`-DryRun`) | ❌ No | ❌ No | ❌ No |
| **Guaranteed Protection for Essential Apps** | ✅ Guaranteed | ⚠️ User Config | ⚠️ User Config | ❌ High Break Risk |
| **Safe Delivery Optimization (No Store breaks)** | ✅ GPO `DODownloadMode=0` | ❌ Disables Service | ⚠️ Mixed | ❌ Disables Service |
| **Safe Logging (Auto-redirects if write-protected)** | ✅ Local `logs/` or `$TEMP` | ⚠️ GUI Logs | ⚠️ Flat File | ⚠️ Flat Text |
| **Automated Test Suite & CI Validation** | ✅ 74 AST & Pester Invariants | ❌ None | ❌ None | ❌ None |

---

## 🛡️ Safety Principles (What Keeps Windows Working)

Most debloaters break future Windows updates or leave background services in unstable states. `unslop-windows` follows five core engineering rules:

1. **Servicing Stack Integrity**: Never strips WinSxS packages or modifies DISM manifests. Monthly Cumulative Updates install cleanly without error rollbacks.
2. **Dual-Stage AppX Removal**: Removes packages from the Windows system image in addition to installed user apps. Bloatware does not regenerate when creating new user accounts or installing Windows feature updates.
3. **Safe Delivery Optimization**: Uses GPO policy `DODownloadMode = 0` (HTTP only) to turn off background P2P update sharing. The `DoSvc` service stays active, preventing error `0x80d03805` in the Microsoft Store.
4. **100% Symmetrical Restoration**: Every policy, registry key, service state, scheduled task and firewall rule has an exact inverse `-Undo` mapping.
5. **Auditable Non-Elevated Inspection**: `-DryRun` runs in standard user mode, allowing you to audit every proposed change before granting administrative privileges.

---

## ⚙️ What unslop-windows Tweaks & Cleans (18 Modules per Engine)

1. **Background Services (6)**: Disables heavy background services (`SysMain`, `WSearch`, `DiagTrack`, `dmwappushservice`, `TrkWks` and `lfsvc`). Start menu app search remains fast via the shell in-memory index.
2. **Disable Recall & Copilot (Win11) / Remove Cortana (Win10)**: On Win11, turns off Recall snapshotting (`DisableAIDataAnalysis = 1`, `AllowRecall = 0`) and removes Copilot policies and taskbar shortcuts. On Win10, disables Cortana policies (`AllowCortana = 0`) and cleanly uninstalls the Cortana app.
3. **Telemetry & Diagnostic Tracking**: Turns off Windows diagnostic data collection (`AllowTelemetry = 0`), CEIP, Application Impact Telemetry and OneSettings telemetry configuration downloads.
4. **Start Menu & Lock Screen Ads**: Disables lock screen tips, Start menu app recommendations, notification badge promotions and automatic sponsored app installations.
5. **Speech & Typing Data Collection**: Disables cloud speech recognition and stops Windows from collecting inking and typing dictionaries.
6. **Search Tracking & Bing Suggestions**: Disables local search history tracking, Microsoft account search integration and Bing web suggestions in the Start menu.
7. **Local Network & Wi-Fi Privacy**: Disables LLMNR (`EnableMulticast = 0`) to protect against credential sniffing on local networks. Disables Wi-Fi hotspot reporting and automatic network beacons.
8. **Driver & Firmware Updates (Kept Safe)**: Preserves Windows Update delivery of hardware driver and firmware updates so critical security patches install without issues, while proactively clearing legacy overwrite blocks.
9. **Taskbar & File Explorer Cleanliness**: On Win11, disables Widgets via GPO (`AllowNewsAndInterests = 0`) and hides Chat (`TaskbarMn = 0`). On Win10, hides News & Interests (`ShellFeedsTaskbarViewMode = 2`), People bar and Meet Now. Both engines ensure file extensions are visible (`HideFileExt = 0`).
10. **App Permissions (ConsentStore)**: Revokes background app access for location, diagnostics, contacts, calendar and phone capabilities. On Win11, blocks screen text scraping (`foregroundTextAccess`) and background OS AI models (`systemAIModels`). Win10 manages 9 core capabilities.
11. **Diagnostic Scheduled Tasks**: Disables over 20 background telemetry tasks across OneSettings, PowerGridForecast, MareBackup, CEIP, Customer Experience and Disk Diagnostics.
12. **Bloatware & Junk App Removal**: Deletes pre-installed sponsored bloatware (TikTok, Spotify, Instagram, Netflix, Candy Crush, Disney+, Prime Video) and consumer apps for current user profiles and future accounts. On Win11, removes AI integrations (aimgr, AIFabric, AugLoop, WidgetsPlatformRuntime). On Win10, cleans legacy apps (Print3D, 3DBuilder, Skype, Maps). Keeps Xbox when `-KeepXbox` is used.
13. **Uninstall OneDrive & Clean Explorer**: Stops running OneDrive processes, runs the uninstaller, unpins the folder from File Explorer's sidebar (`{018D5C66-4533-4307-9B53-224DE2ED1FE6}`) and blocks background sync folders (`DisableFileSyncNGSC = 1`).
14. **Startup Apps & Edge Background Tasks**: Stops Microsoft Edge from running in the background. Backs up removed startup items to the registry so `-Undo` restores them with zero data loss.
15. **Defender Cloud Sample Submissions**: Configures `SubmitSamplesConsent = 2` (NeverSend) to block automatic memory dumps and sample file uploads, while keeping real-time antivirus fully active.
16. **Activity History & Cross-Device Resume**: Disables timeline activity feeds, Connected Devices Platform (`EnableCdp = 0`) and Cross-Device Resume (`DisableCrossDeviceResume = 1`), stopping `sihost.exe` from spawning `CrossDeviceResume.exe` at logon. Local multi-item clipboard history (`Win + V`) remains fully functional.
17. **Delivery Optimization & Store Auto-Downloads**: Disables peer-to-peer update distribution via GPO (`DODownloadMode = 0`) and throttles background Store app auto-downloads (`AutoDownload = 2`) to stop NVMe write spikes, while keeping manual Store updates fully functional.
18. **Outbound Telemetry Firewall Rules**: Blocks outbound firewall rules for background diagnostics, SSDP discovery and connected device tracking.

---

## 🔒 Protected Apps & Components (What We Never Touch)

`unslop-windows` explicitly protects core system applications and daily desktop tools:

| Component Category | Preserved Items | Why It Is Untouched |
| :--- | :--- | :--- |
| **System Package Tools** | Windows Terminal, Microsoft Store, WinGet (`DesktopAppInstaller`) | Required for software installation and package management |
| **Essential Desktop Apps** | Calculator, Photos, Paint, Snipping Tool (`ScreenSketch`) | Daily workflow tools with zero telemetry overhead |
| **Productivity Features** | Local `Win + V` clipboard history buffer | Daily workflow convenience preserved; only cloud cross-device sync is disabled |
| **System Experience Hosts** | `CloudExperienceHost`, `Photon`, `CoreAI`, `UndockedDevKit`, `PeopleExperienceHost`, `ParentalControls`, `NarratorQuickStart`, `ECApp` | Immutable system packages preserved to prevent AppX de-provisioning errors (AI capabilities neutralized via GPO and ConsentStore) |
| **Audio & Video Hardware** | Microphone access, Webcam access, AMD Noise Suppression / NVIDIA Broadcast | Prevents breaking Discord, OBS, Teams and voice chat |
| **Developer Environments** | Visual Studio, VS Code, Git, Docker Desktop, Ollama, existing toolchains, browsers | Developer toolchains and container runtimes |
| **Application Runtimes** | WebView2, Edge Rendering Engine | Required by modern desktop applications to display web views |

---

## 🎛️ Optional Parameters

| Parameter | OS | Default | Description |
| :--- | :--- | :--- | :--- |
| `-DryRun` | Both | `False` | Audits planned modifications without writing changes. Runs without admin rights. |
| `-Undo` | Both | `False` | Restores all disabled services, scheduled tasks, and policies back to Windows defaults. |
| `-KeepOneDrive` | Both | `False` | Skips OneDrive uninstallation, registry unpinning, and sync blocking policies. |
| `-KeepTodos` | Both | `False` | Preserves Microsoft To-Do (`Microsoft.Todos`) during AppX cleanup. |
| `-KeepXbox` | Both | `False` | Preserves Xbox app and Gaming Services for Game Pass users. |
| `-ClassicContextMenu`| Win11 | `False` | Restores Windows 10 style full right-click context menu (bypasses "Show more options"). |
| `-NoRestart` | Both | `False` | Suppresses the post-execution restart prompt (user must manually restart computer). |
| `-ForceRestart` | Both | `False` | Bypasses confirmation and immediately restarts the computer (`shutdown /r /t 0`). |
| `-SkipBuildCheck` | Both | `False` | Bypasses OS build verification. Used for CI/CD and cross-OS testing. |

### Parameter Examples

```powershell
# Debloat Windows 11 without triggering automatic restart prompt
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -NoRestart

# Keep Xbox gaming services and OneDrive on Windows 11
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -KeepXbox -KeepOneDrive

# Debloat Windows 11 and restore the classic Windows 10 right-click context menu
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1 -ClassicContextMenu

# Debloat Windows 10 with Xbox gaming services preserved
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -KeepXbox
```

---

## 📊 Benchmarking & Diagnostics

Measure system resource footprint before and after debloating using the built-in system state auditor:

```powershell
# Display live system metrics (RAM, commit charge, threads, telemetry services)
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1

# Capture before/after snapshots and generate comparative benchmark report
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "before"
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "after"
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Baseline "logs/before.json" -Target "logs/after.json" -ExportMarkdown "docs/benchmarks.md"
```

### 🔒 Cryptographic Verification
Official releases include `SHA256SUMS.txt`. Verify your release bundle locally:
```powershell
Get-FileHash unslop-windows-v*.zip -Algorithm SHA256
```

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=PyPie-Studio/unslop-windows&type=Date)](https://star-history.com/#PyPie-Studio/unslop-windows&Date)

---

## 🤝 Community & Contributing

Contributions are welcome! Please review our [Contributing Guidelines](CONTRIBUTING.md), [Changelog](CHANGELOG.md), [Roadmap](ROADMAP.md), [Architecture Decisions](docs/decisions.md), and [Security Policy](SECURITY.md) before submitting a pull request.

* **AI Pair Programming:** See [AGENTS.md](AGENTS.md) and [SKILLS.md](SKILLS.md) for non-negotiable safe-tier engineering standards and automated skills.
* **Found a bug?** Open an issue using the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md).
* **Found new 25H2 bloatware or telemetry tasks?** Submit a [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md).

---

## 📄 License

MIT License. Copyright (c) 2026 PyPie Studio.
