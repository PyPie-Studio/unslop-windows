---
name: unslop-win10-internals
description: Deep Windows 10 internals across all releases (Build 10240 through 19045 22H2). Cortana suppression, Feeds / News & Interests, People bar, Meet Now, ConsentStore, telemetry endpoints, and safe debloating invariants.
---

# unslop-win10-internals

This skill governs Windows 10 operating system internals, telemetry subsystems, policy hives, and version-specific architectural differences for **unslop-windows** (`unslop-win10.ps1`).

---

## 💻 Target Windows 10 Builds

| Version / Milestone | OS Build | Platform Servicing & Architecture Notes |
| :--- | :--- | :--- |
| **Windows 10 22H2** | Build 19045 | Final mainstream Windows 10 feature release (ESU active through Oct 2027). |
| **Windows 10 21H2** | Build 19044 | Vibranium platform servicing release. |
| **Windows 10 21H1** | Build 19043 | Vibranium platform servicing release. |
| **Windows 10 20H2** | Build 19042 | First release with Chromium-based Edge integrated. |
| **Windows 10 2004** | Build 19041 | Vibranium convergence baseline; shared servicing stack with 20H2-22H2. |
| **Windows 10 1909** | Build 18363 | 19H2 servicing update. |
| **Windows 10 1903** | Build 18362 | 19H1 release (Light Theme, Windows Sandbox). |
| **Windows 10 1809 / LTSC 2019** | Build 17763 | Enterprise LTSC 2019 baseline; extended servicing. |
| **Windows 10 1803** | Build 17134 | Redstone 4 (April 2018 Update). |
| **Windows 10 1709** | Build 16299 | Redstone 3 (Fall Creators Update). |
| **Windows 10 1703** | Build 15063 | Redstone 2 (Creators Update). |
| **Windows 10 1607 / LTSB 2016** | Build 14393 | Enterprise LTSB 2016 baseline; anniversary update. |
| **Windows 10 1511** | Build 10586 | First major update (Threshold 2). |
| **Windows 10 1507 / LTSB 2015** | Build 10240 | Windows 10 RTM release; original LTSB. |
| **Enterprise LTSC 2021** | Build 19044 | Long-Term Servicing Channel; supported through 2027. |
| **IoT Enterprise LTSC** | Build 19044 / 17763 | IoT long-term release; supported through 2032. |

---

## 🔑 Critical Hardening Subsystems & Registry Keys

### 1. Cortana Complete Purge & Taskbar Suppression
Unlike Windows 11 where Cortana was decoupled and phased out in favor of Copilot, Windows 10 features deep, shell-integrated Cortana:
- **Registry Policies:**
  - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
    - `AllowCortana = 0` (undo `1`, `removeOnUndo = $true`)
    - `AllowSearchToUseLocation = 0` (undo `1`, `removeOnUndo = $true`)
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search`
    - `SearchboxTaskbarMode = 0` (hidden; undo `1` = search icon)
    - `AllowCortanaAboveLock = 0` (undo `1`)
- **UWP App Package:**
  - `Microsoft.549981C3F5F10` de-provisioned and removed across all user profiles.

### 2. Taskbar Bloat: News & Interests (Feeds), People Bar, Meet Now
- **News and Interests (Feeds):**
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds`
    - `ShellFeedsTaskbarViewMode = 2` (2 = hidden/disabled; undo `0` = show icon and text)
    - `IsFeedsAvailable = 0` (undo `1`)
- **People Bar:**
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People`
    - `PeopleBand = 0` (undo `1`)
- **Meet Now (Skype Integration):**
  - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`
    - `HideSCAMeetNow = 1` (undo `0`, `removeOnUndo = $true`)

### 3. Start Menu Search & Search History
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search`
  - `BingSearchEnabled = 0` (undo `1`)
  - `CortanaConsent = 0` (undo `1`)
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
  - `DisableWebSearch = 1` (undo `0`, `removeOnUndo = $true`)
  - `ConnectedSearchUseWeb = 0` (undo `1`, `removeOnUndo = $true`)
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings`
  - `IsDeviceSearchHistoryEnabled = 0` (undo `1`)
  - `IsMSACloudSearchEnabled = 0` (undo `1`)
  - `IsAADCloudSearchEnabled = 0` (undo `1`)
  - `IsDynamicSearchBoxEnabled = 0` (undo `1`)

### 4. Telemetry Services & Scheduled Tasks
- **Services:**
  - `DiagTrack` (Connected User Experiences and Telemetry) $\rightarrow$ `Disabled`
  - `dmwappushservice` (WAP Push Message Routing) $\rightarrow$ `Disabled`
  - `SysMain` (Superfetch) $\rightarrow$ `Disabled`
  - `WSearch` (Windows Search Indexer) $\rightarrow$ `Disabled`
  - `TrkWks` (Distributed Link Tracking Client) $\rightarrow$ `Disabled`
  - `lfsvc` (Geolocation Service) $\rightarrow$ `Disabled`
- **Scheduled Tasks:**
  - `\Microsoft\Windows\Application Experience\StartupAppTask` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Application Experience\ProgramDataUpdater` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip` $\rightarrow$ `Disable-ScheduledTask`

### 5. Windows 10 Specific Bloatware AppX Packages
Target packages uniquely present or prevalent on Windows 10:
- `Microsoft.Print3D`
- `Microsoft.3DBuilder`
- `Microsoft.Microsoft3DViewer`
- `Microsoft.OneConnect`
- `Microsoft.MSPaint` (Paint 3D — classic `mspaint.exe` remains untouched)
- `Microsoft.People`
- `Microsoft.SkypeApp`
- `Microsoft.WindowsAlarms`
- `Microsoft.WindowsMaps`
- `Microsoft.WindowsSoundRecorder`
- `Microsoft.WindowsCommunicationsApps` (Mail & Calendar)
- `Microsoft.MixedReality.Portal`

---

## 🚫 Safe-Tier Invariants on Windows 10
- **Zero DISM Component Stripping:** Never execute `dism /online /cleanup-image /startcomponentcleanup /resetbase`.
- **Untouchable Whitelist:** Microsoft Store (`Microsoft.WindowsStore`), App Installer (`Microsoft.DesktopAppInstaller`), Xbox Identity Provider (`Microsoft.XboxIdentityProvider`), Calculator, Photos, and classic Paint (`mspaint.exe`) MUST NEVER be removed.
- **Symmetrical `-Undo`:** Every registry modification, disabled service, or task must have an exact inverse restoration in `unslop-win10.ps1 -Undo`.
