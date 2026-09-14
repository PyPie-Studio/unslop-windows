<div align="center">

# 🧹 unslop-windows

### Stop Microsoft from turning your PC into an ad-riddled, AI-telemetry terminal.
**The Safe-Tier Windows 11 (25H2/24H2/23H2/22H2) & Windows 10 (22H2/21H2/LTSC/Build 10240+) Unslopper, Debloater, and Privacy Hardener.**

[![GitHub stars](https://img.shields.io/github/stars/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/network/members)
[![GitHub release](https://img.shields.io/github/v/release/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=green)](https://github.com/PyPie-Studio/unslop-windows/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/PyPie-Studio/unslop-windows/lint.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/PyPie-Studio/unslop-windows/actions)
[![Windows 11](https://img.shields.io/badge/Windows%2011-25H2%20%7C%2024H2%20%7C%2023H2%20%7C%2022H2-0078D6?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![Windows 10](https://img.shields.io/badge/Windows%2010-22H2%20%7C%2021H2%20%7C%20LTSC%20%7C%2010240--19045-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

[⚡ Quick Download](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.2.1.zip) • [📋 Changelog](CHANGELOG.md) • [🗺️ Roadmap](ROADMAP.md) • [🚀 Real-World Impact](#-measured-real-world-impact) • [📊 Comparison](#-comparison-matrix) • [🛡️ Safe-Tier Principles](#-safe-tier-design-principles) • [⚙️ All 18 Modules](#-what-gets-hardened-18-modules-per-engine) • [🔒 Untouchable Whitelist](#-untouchable-safety-whitelist)

</div>

---

> [!TIP]
> ⭐ **Reclaiming your system from Windows Slop?**
> Give this repository a star on GitHub! It helps more users find a clean, open-source alternative that doesn't break Cumulative Updates or the Microsoft Store.

---

```text
============================================================
  unslop-windows (v1.2.1) - PyPie Studio
  Universal Windows Unslopper, Debloater & Privacy Hardener
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

1. Download **[`unslop-windows-v1.2.1.zip`](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.2.1.zip)** from the [Latest Release](https://github.com/PyPie-Studio/unslop-windows/releases/latest).
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
* 🚫 **Zero Bloatware Respawns**: Dual-stage AppX de-provisioning ensures consumer bloatware (TikTok, Spotify, Candy Crush) never reinstalls after Windows updates.
* ⚡ **Eliminated Background Thrashing**: Stops idle `svchost` telemetry threads, `SearchIndexer` disk crawls, and `SysMain` (Superfetch) prefetch bloat.
* 🧠 **More Headroom for Heavy Workloads**: Frees up vital host RAM for local LLMs (Ollama / vLLM), Docker containers, compilation, and high-performance gaming.

---

## 📊 Comparison Matrix

How `unslop-windows` compares to other popular debloaters:

| Feature / Capability | unslop-windows | Chris Titus WinUtil | Sophia Script | Tron Script |
| :--- | :---: | :---: | :---: | :---: |
| **Windows 11 (25H2 / 24H2 / 23H2 / 22H2)** | ✅ Full Native | ⚠️ Partial / Lagging | ❌ Broken / Lagging | ❌ Deprecated |
| **Windows 10 (22H2 / 21H2 / LTSC / 10240+)**| ✅ Full Native | ⚠️ Generic | ⚠️ Legacy Sophia | ❌ Deprecated |
| **Windows Recall & Copilot Killswitch** | ✅ Full GPO + Registry | ⚠️ Registry Only | ⚠️ Partial | ❌ No |
| **Cortana Complete Purge (Win10)** | ✅ GPO + AppX | ⚠️ Partial | ⚠️ AppX Only | ❌ Unclean |
| **Servicing Stack Safe (No WinSxS cuts)** | ✅ 100% Safe | ⚠️ Mixed | ⚠️ Mixed | ❌ Strips Components |
| **Zero Third-Party Dependencies** | ✅ Pure Native PS/Batch | ❌ GUI / Multi-file | ❌ Module Suite | ❌ Multi-GB Archive |
| **Symmetrical 1-Click Undo Engine** | ✅ Yes (`-Undo`) | ⚠️ Partial | ⚠️ Partial | ❌ No |
| **Safe Non-Elevated Dry-Run** | ✅ Yes (`-DryRun`) | ❌ No | ❌ No | ❌ No |
| **Untouchable Whitelist Enforced** | ✅ Guaranteed | ⚠️ User Config | ⚠️ User Config | ❌ High Break Risk |
| **Safe Delivery Optimization (No Store breaks)** | ✅ GPO `DODownloadMode=0` | ❌ Disables Service | ⚠️ Mixed | ❌ Disables Service |
| **Decoupled Autonomous Logging** | ✅ Local `logs/` or `$TEMP` | ⚠️ GUI Logs | ⚠️ Flat File | ⚠️ Flat Text |
| **Test-Driven Invariants & Fail-Closed CI** | ✅ 74 AST & Pester Invariants | ❌ None | ❌ None | ❌ None |

---

## 🛡️ Safe-Tier Design Principles

Most debloaters break future Windows updates or leave background services in unstable states. `unslop-windows` follows five non-negotiable engineering mandates:

1. **Servicing Stack Integrity**: Never strips WinSxS packages or tampers with DISM manifests. Monthly Cumulative Updates install cleanly without `0x800f0922` error rollbacks.
2. **Dual-Stage AppX Removal**: Strips provisioned packages from the system image in addition to installed user profile apps. Bloatware does not regenerate when creating new accounts or installing Windows feature updates.
3. **Safe Delivery Optimization**: Uses GPO policy `DODownloadMode = 0` (HTTP only) to kill background local and internet P2P seeding. The `DoSvc` service stays intact, preventing error `0x80d03805` in the Microsoft Store.
4. **100% Symmetrical Restoration**: Every policy, registry key, service state, scheduled task, and firewall rule has an exact inverse `-Undo` mapping.
5. **Auditable Non-Elevated Inspection**: `-DryRun` runs in standard user mode, allowing sysadmins to audit every single proposed change before granting administrative privileges.

---

## ⚙️ What Gets Hardened (18 Modules per Engine)

1. **Services (6)**: Disables `SysMain`, `WSearch`, `dmwappushservice`, `DiagTrack`, `TrkWks`, and `lfsvc`. Start Menu app search remains functional via shell in-memory index.
2. **Windows Recall & Copilot** *(Win11)* / **Cortana Complete Purge** *(Win10)*: On Win11, sets `DisableAIDataAnalysis = 1`, `AllowRecall = 0`, `TurnOffWindowsCopilot = 1`, and removes the Copilot taskbar button. On Win10, sets `AllowCortana = 0`, hides the search box, and dual-stage de-provisions the Cortana UWP app.
3. **Telemetry & Diagnostics**: Disables `AllowTelemetry`, CEIP, Application Impact Telemetry, and OneSettings telemetry flighting downloads.
4. **Settings Recommendations & Offers**: Disables lockscreen tips, start menu recommendations, account notification badges, and Content Delivery Manager promotions.
5. **Speech & Inking Personalization**: Disables cloud speech recognition and removes typing/inking dictionary collection.
6. **Search History & Cloud Integration**: Disables local search history tracking, MSA cloud search, and Bing web suggestions.
7. **Network Security & Wi-Fi Sense**: Disables LLMNR (`EnableMulticast = 0`) to mitigate NTLM hash theft on local networks. Disables Wi-Fi hotspot reporting and auto-connect beacons.
8. **Windows Update Driver & Firmware Integrity**: Preserves Windows Update delivery of hardware driver and firmware updates so critical security patches and hardware CVE mitigations install cleanly, while proactively clearing legacy overwrite blocks.
9. **Explorer & Taskbar Cleanliness**: On Win11, disables Widgets via GPO (`AllowNewsAndInterests = 0`) and hides Chat (`TaskbarMn = 0`). On Win10, suppresses News & Interests (`ShellFeedsTaskbarViewMode = 2`), hides People bar and Meet Now. Both engines ensure file extensions are visible (`HideFileExt = 0`).
10. **ConsentStore Permissions**: Revokes background access for location, diagnostics, contacts, calendar, and phone capabilities. Win11 manages 12 capabilities including 25H2 screen text scraping (`foregroundTextAccess`), OS AI model execution (`systemAIModels`), and borderless screen capture (`graphicsCaptureWithoutBorder`). Win10 manages 9 core capabilities.
11. **Scheduled Tasks**: Disables 20+ telemetry tasks across OneSettings, PowerGridForecast, MareBackup, CEIP, Customer Experience, and Disk Diagnostics.
12. **Dual-Stage AppX Purge**: Removes installed packages for all existing user profiles and de-provisions staged packages from the Windows image. Win11 targets 34 packages including 24H2/25H2 AI injections (aimgr, AIFabric, AugLoop, WidgetsPlatformRuntime, StartExperiencesApp), sponsored bloat (TikTok, Spotify, Instagram, Netflix, Candy Crush, Disney+, Prime Video), Microsoft consumer apps (Clipchamp, Outlook, Solitaire, News, BingSearch, BingFinance, BingSports, PC Manager, DevHome, Phone Link), and Office push services. Win10 targets 39 packages including legacy apps (Print3D, 3DBuilder, Skype, Maps, Alarms, Mail & Calendar, Mixed Reality Portal, Cortana). Both engines add Xbox (+2 packages) unless `-KeepXbox` is specified.
13. **OneDrive Purge Engine**: Terminates running processes, runs the silent uninstaller, unpins the Explorer sidebar icon (`{018D5C66-4533-4307-9B53-224DE2ED1FE6}`), sets sync block policies (`DisableFileSyncNGSC = 1`), and removes startup registry entries.
14. **Startup Entries & Edge Background**: Disables Edge background application access. Removed startup run keys are safely archived under `HKCU:\Software\unslop-windows\StartupBackup` and symmetrically restored on `-Undo` (zero data loss).
15. **Microsoft Defender Telemetry**: Configures `SubmitSamplesConsent = 2` (NeverSend) to block automatic memory and sample file uploads while keeping real-time antivirus active.
16. **Activity History & Cloud Clipboard**: Disables timeline feeds, activity publishing, and cross-device clipboard sync. Local multi-item clipboard history (`Win + V`) remains fully functional.
17. **Delivery Optimization**: Disables local and internet peer-to-peer update distribution via GPO (`DODownloadMode = 0`) without disabling the servicing daemon.
18. **Firewall Telemetry Rules**: Blocks 8 unnecessary outbound rules for SSDP, Remote Assistance, and Connected Devices Platform.

---

## 🔒 Untouchable Safety Whitelist

`unslop-windows` explicitly protects core system applications and daily desktop tools:

| Component Category | Preserved Items | Why It Is Untouched |
| :--- | :--- | :--- |
| **System Package Tools** | Windows Terminal, Microsoft Store, WinGet (`DesktopAppInstaller`) | Required for software installation and package management |
| **Essential Desktop Apps** | Calculator, Photos, Paint, Snipping Tool (`ScreenSketch`) | Daily workflow tools with zero telemetry overhead |
| **Productivity Features** | Local `Win + V` clipboard history buffer | Daily workflow convenience preserved; only cloud cross-device sync is disabled |
| **System Experience Hosts** | `CloudExperienceHost`, `Photon`, `CoreAI`, `UndockedDevKit`, `PeopleExperienceHost`, `ParentalControls`, `NarratorQuickStart`, `ECApp` | Immutable system packages preserved to prevent AppX de-provisioning `0x80070032`/`0x80073CFA` errors (AI capabilities neutralized via GPO/ConsentStore) |
| **Audio & Video Hardware** | Microphone access, Webcam access, AMD Noise Suppression / NVIDIA Broadcast | Prevents breaking Discord, OBS, Teams, and voice chat |
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
