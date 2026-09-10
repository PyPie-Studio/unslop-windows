---
name: unslop-win10-internals
description: Deep Windows 10 internals across all releases (Build 10240 through 19045 22H2). Cortana suppression, Feeds / News & Interests, People bar, Meet Now, ConsentStore, telemetry endpoints, and safe debloating invariants.
---

# unslop-win10-internals

This skill governs Windows 10 operating system internals, telemetry subsystems, policy hives, and version-specific architectural differences for **unslop-windows** (`unslop-win10.ps1`).

---

## 💻 Target Windows 10 Builds

| Version | OS Build Range | Key Architecture Notes |
| :--- | :--- | :--- |
| **Windows 10 22H2** | Build 19045 | Final mainstream Windows 10 feature release (ESU active through Oct 2027). |
| **Windows 10 21H2** | Build 19044 | Vibranium platform servicing release. |
| **Windows 10 21H1 / 20H2 / 2004** | Build 19041 - 19043 | Vibranium convergence baseline; shared servicing stack with 22H2. |
| **Windows 10 Legacy (1507 - 1909)** | Build 10240 - 18363 | Pre-Vibranium legacy releases; supported via generic registry and service debloat fallbacks. |

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
