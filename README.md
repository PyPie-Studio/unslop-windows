<div align="center">

# 🧹 unslop-windows

### Stop Microsoft from turning your PC into an ad-riddled, AI-telemetry terminal.
**The Safe-Tier Universal Windows 11 23H2, 24H2 & 25H2 Debloater and Privacy Hardener.**

[![GitHub stars](https://img.shields.io/github/stars/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=blue)](https://github.com/PyPie-Studio/unslop-windows/network/members)
[![GitHub release](https://img.shields.io/github/v/release/PyPie-Studio/unslop-windows?style=for-the-badge&logo=github&color=green)](https://github.com/PyPie-Studio/unslop-windows/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/PyPie-Studio/unslop-windows/lint.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/PyPie-Studio/unslop-windows/actions)
[![Windows 11](https://img.shields.io/badge/Windows%2011-23H2%20%7C%2024H2%20%7C%2025H2-0078D6?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/PyPie-Studio/unslop-windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

[⚡ Quick Download](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.0.2.zip) • [🚀 Real-World Impact](#-measured-real-world-impact) • [📊 Comparison](#-comparison-matrix) • [🛡️ Safe-Tier Principles](#-safe-tier-design-principles) • [⚙️ All 18 Modules](#-what-gets-hardened-18-modules) • [🔒 Untouchable Whitelist](#-untouchable-safety-whitelist)

</div>

---

> [!TIP]
> ⭐ **Reclaiming your system from Windows 11 bloat?**
> Give this repository a star on GitHub! It helps more users find a clean, open-source alternative that doesn't break Cumulative Updates or the Microsoft Store.

---

```text
============================================================
  unslop-windows (v1.0.2) - PyPie Studio
  Universal Windows 11 24H2 / 25H2 Debloat & Privacy Hardener
============================================================

  [1] Full Debloat (Purge OneDrive, telemetry & bloatware)
  [2] Dry-Run Audit (Inspect changes safely, no modifications)
  [3] Debloat, but Keep Microsoft To-Do
  [4] Debloat, but Keep Xbox & Gaming Services
  [5] Debloat, but Keep OneDrive
  [6] Debloat + Enable Classic Context Menu
  [7] Custom Flags (Enter custom parameter combinations)
  [8] Full Restore / Undo (Revert all changes back to defaults)
  [0] Exit

============================================================
Select an option [0-8]: 
```

---

## ⚡ Download & Quickstart

> [!IMPORTANT]
> ### ⚠️ Mandatory Requirements: Administrator Rights & System Restart
> 1. **Run as Administrator**: `unslop-windows` configures system-level Group Policies, Services, Registry trees, and de-provisions AppX packages. The script **must be executed as an Administrator** (except `-DryRun`, which safely audits changes without elevation).
> 2. **System Restart Required**: Windows caches service states, group policies, and background telemetry threads in memory. A **full system restart is required** after the script is done to finalize all debloat, privacy, and performance optimizations.
> 3. **Save Your Work & In-Place Abort Shortcut**: Please save all open documents before running. Upon completion, the script notifies you to save your work and initiates a 30-second restart countdown with an in-place shortcut: press **`A`** to abort the restart at any time, or **`R`** to reboot immediately. If not aborted, the restart proceeds and the launcher window closes automatically.

### Method 1: Direct Download (1-Click / Non-Technical)
No Git, terminal commands, or PowerShell knowledge needed:

1. Download **[`unslop-windows-v1.0.2.zip`](https://github.com/PyPie-Studio/unslop-windows/releases/latest/download/unslop-windows-v1.0.2.zip)** from the [Latest Release](https://github.com/PyPie-Studio/unslop-windows/releases/latest).
2. Extract the `.zip` archive to any folder.
3. Right-click **`unslop.bat`** and select **Run as administrator** (or double-click and accept the UAC prompt).
4. In the console menu, type `1` (or your preferred option) and press Enter.
5. When the script completes, ensure your work is saved and press **Enter** (or `Y`) to initiate the 30-second restart countdown (press **`A`** to abort or **`R`** to reboot immediately; if allowed to finish, the window closes automatically).

### Method 2: PowerShell One-Liner (Terminal Users)
Launch the interactive menu straight from an elevated PowerShell terminal:

```powershell
# Run inside an elevated PowerShell prompt (Right-click Start -> Terminal (Admin) / PowerShell (Admin))
irm https://raw.githubusercontent.com/PyPie-Studio/unslop-windows/main/unslop.bat -OutFile unslop.bat; .\unslop.bat
```

### Method 3: Direct Command-Line Execution
Run directly from an **Administrator Command Prompt** or an **Elevated PowerShell** terminal:

**Command Prompt (CMD - Run as Administrator):**
```cmd
unslop.bat
unslop.bat -DryRun
unslop.bat -KeepTodos
unslop.bat -NoRestart
unslop.bat -Undo
```

**PowerShell (Run as Administrator):**
```powershell
# Full default debloat (notifies and prompts for reboot upon completion)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1

# Full default debloat without automatic reboot prompt (restart manually later)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -NoRestart

# Dry-run audit (safe inspection, zero changes written, no elevation required)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -DryRun

# Full restore back to Windows defaults (prompts for reboot upon completion)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -Undo
```

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
| **Windows 11 25H2 / 24H2 Support** | ✅ Full Native | ⚠️ Partial / Lagging | ❌ Broken / Lagging | ❌ Deprecated |
| **Windows Recall & Copilot Killswitch** | ✅ Full GPO + Registry | ⚠️ Registry Only | ⚠️ Partial | ❌ No |
| **Servicing Stack Safe (No WinSxS cuts)** | ✅ 100% Safe | ⚠️ Mixed | ⚠️ Mixed | ❌ Strips Components |
| **Single-File Zero Dependency** | ✅ Yes (`unslop.ps1`) | ❌ GUI / Multi-file | ❌ Module Suite | ❌ Multi-GB Archive |
| **Symmetrical 1-Click Undo Engine** | ✅ Yes (`-Undo`) | ⚠️ Partial | ⚠️ Partial | ❌ No |
| **Safe Non-Elevated Dry-Run** | ✅ Yes (`-DryRun`) | ❌ No | ❌ No | ❌ No |
| **Untouchable Whitelist Enforced** | ✅ Guaranteed | ⚠️ User Config | ⚠️ User Config | ❌ High Break Risk |
| **Safe Delivery Optimization (No Store breaks)** | ✅ GPO `DODownloadMode=0` | ❌ Disables Service | ⚠️ Mixed | ❌ Disables Service |
| **Decoupled Autonomous Logging** | ✅ Local `logs/` or `$TEMP` | ⚠️ GUI Logs | ⚠️ Flat File | ⚠️ Flat Text |

---

## 🛡️ Safe-Tier Design Principles

Most debloaters break future Windows updates or leave background services in unstable states. `unslop-windows` follows five non-negotiable engineering mandates:

1. **Servicing Stack Integrity**: Never strips WinSxS packages or tampers with DISM manifests. Monthly Cumulative Updates install cleanly without `0x800f0922` error rollbacks.
2. **Dual-Stage AppX Removal**: Strips provisioned packages from the system image in addition to installed user profile apps. Bloatware does not regenerate when creating new accounts or installing Windows feature updates.
3. **Safe Delivery Optimization**: Uses GPO policy `DODownloadMode = 0` (HTTP only) to kill background local and internet P2P seeding. The `DoSvc` service stays intact, preventing error `0x80d03805` in the Microsoft Store.
4. **100% Symmetrical Restoration**: Every policy, registry key, service state, scheduled task, and firewall rule has an exact inverse `-Undo` mapping.
5. **Auditable Non-Elevated Inspection**: `-DryRun` runs in standard user mode, allowing sysadmins to audit every single proposed change before granting administrative privileges.

---

## ⚙️ What Gets Hardened (18 Modules)

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

## 🔒 Untouchable Safety Whitelist

`unslop-windows` explicitly protects core system applications and daily desktop tools:

| Component Category | Preserved Items | Why It Is Untouched |
| :--- | :--- | :--- |
| **System Package Tools** | Windows Terminal, Microsoft Store, WinGet (`DesktopAppInstaller`) | Required for software installation and package management |
| **Essential Desktop Apps** | Calculator, Photos, Paint, Snipping Tool (`ScreenSketch`) | Daily workflow tools with zero telemetry overhead |
| **Audio & Video Hardware** | Microphone access, Webcam access, AMD Noise Suppression / NVIDIA Broadcast | Prevents breaking Discord, OBS, Teams, and voice chat |
| **Developer Environments** | Visual Studio, VS Code, Git, Docker Desktop, Ollama, existing toolchains, browsers | Developer toolchains and container runtimes |
| **Application Runtimes** | WebView2, Edge Rendering Engine | Required by modern desktop applications to display web views |

---

## 🎛️ Optional Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-DryRun` | Switch | `False` | Audits planned modifications without writing changes. Runs without admin rights. |
| `-Undo` | Switch | `False` | Restores all disabled services, scheduled tasks, and policies back to Windows defaults. |
| `-KeepOneDrive` | Switch | `False` | Skips OneDrive uninstallation, registry unpinning, and sync blocking policies. |
| `-KeepTodos` | Switch | `False` | Preserves Microsoft To-Do (`Microsoft.Todos`) during AppX cleanup. |
| `-KeepXbox` | Switch | `False` | Preserves Xbox app and Gaming Services for Game Pass users. |
| `-ClassicContextMenu`| Switch | `False` | Restores Windows 10 style full right-click context menu (bypasses "Show more options"). |
| `-NoRestart` | Switch | `False` | Suppresses the post-execution restart prompt (user must manually restart computer). |
| `-ForceRestart` | Switch | `False` | Automatically initiates a 30-second countdown restart without prompting for confirmation. |

### Parameter Examples

```powershell
# Debloat without triggering automatic restart prompt
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -NoRestart

# Keep Xbox gaming services and OneDrive
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -KeepXbox -KeepOneDrive

# Debloat and restore the Windows 10 right-click context menu
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -ClassicContextMenu
```

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=PyPie-Studio/unslop-windows&type=Date)](https://star-history.com/#PyPie-Studio/unslop-windows&Date)

---

## 🤝 Community & Contributing

Contributions are welcome! Please review our [Contributing Guidelines](CONTRIBUTING.md) and [Security Policy](SECURITY.md) before submitting a pull request.

* **Found a bug?** Open an issue using the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md).
* **Found new 25H2 bloatware or telemetry tasks?** Submit a [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md).

---

## 📄 License

MIT License. Copyright (c) 2026 PyPie Studio.
