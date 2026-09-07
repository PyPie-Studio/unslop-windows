---
name: unslop-windows-internals
description: Deep Windows 11 internals across 23H2 (22631), 24H2 (26100), and 25H2 (26200). ConsentStore privacy capabilities, Recall snapshot policies, Copilot suppression, telemetry endpoints, and Cumulative Update safety invariants.
---

# unslop-windows-internals

This skill governs Windows 11 operating system internals, telemetry subsystems, policy hives, and version-specific architectural differences for **unslop-windows**.

---

## 💻 Target Windows Builds

| Milestone | OS Build Range | Key Architecture Notes |
| :--- | :--- | :--- |
| **Windows 11 23H2** | Build 22631 | Momentum 4 updates, initial Copilot preview, Search Highlights, ContentDeliveryManager. |
| **Windows 11 24H2** | Build 26100 | Germanium platform release, Windows Recall preview architecture, Copilot web app encapsulation, sudo for Windows. |
| **Windows 11 25H2** | Build 26200+ | Dilithium / Bromine preview branch, new ConsentStore AI model permissions, Screenray snapshot capture engine. |

---

## 🔑 Critical Hardening Subsystems & Registry Keys

### 1. Windows Recall & Screenray Snapshots (24H2 & 25H2)
- Windows Recall periodically takes snapshots of the user's active screen and OCRs the contents into an embedded vector database.
- **Policies:**
  - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI`
    - `DisableAIDataAnalysis` = `1` (disables background screen capture and analysis)
  - `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI`
    - `DisableAIDataAnalysis` = `1`
  - `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Recall`
    - `AllowRecall` = `0`

### 2. 25H2 ConsentStore AI & Sensor Capabilities
Windows 11 25H2 introduces granular system capabilities under `ConsentStore`:
- `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\foregroundTextAccess` $\rightarrow$ `Value = "Deny"` (blocks screen text OCR scraping)
- `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels` $\rightarrow$ `Value = "Deny"` (blocks background AI model query access)
- `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder` $\rightarrow$ `Value = "Deny"` (blocks borderless screen recording)
- `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener` $\rightarrow$ `Value = "Deny"` (blocks background notification harvesting)

### 3. Windows Copilot Policy Suppression
- Copilot operates both via taskbar pinned integrations and Microsoft Edge sidebar policies.
- **Policies:**
  - `HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot` $\rightarrow$ `TurnOffWindowsCopilot = 1`
  - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot` $\rightarrow$ `TurnOffWindowsCopilot = 1`
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` $\rightarrow$ `ShowCopilotButton = 0`

### 4. Telemetry Services & Scheduled Tasks
- **Services:**
  - `DiagTrack` (Connected User Experiences and Telemetry) $\rightarrow$ `Disabled`
  - `dmwappushservice` (Device Management Wireless Application Protocol) $\rightarrow$ `Disabled`
- **Scheduled Tasks:**
  - `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser` $\rightarrow$ `Disable-ScheduledTask`
  - `\Microsoft\Windows\Application Experience\ProgramDataUpdater` $\rightarrow$ `Disable-ScheduledTask`

---

## 🚫 The Cumulative Update Invariant
Many aggressive debloaters break Windows Updates by running:
```cmd
:: PROHIBITED - DO NOT RUN:
dism /online /cleanup-image /startcomponentcleanup /resetbase
```
When `/resetbase` is executed after removing component manifests, subsequent monthly Cumulative Updates fail with `0x800f0922` or `0x80073701` because the differential staging bits cannot locate baseline delta hashes in the WinSxS store.

**The unslop-windows Guarantee:**
- No DISM component stripping.
- No deletion of files inside `C:\Windows\WinSxS` or `C:\Windows\System32`.
- All modifications are configuration-level (Registry, GPO, Service startup types, and UWP package de-provisioning).
- Every Windows Cumulative Update installs smoothly without rollbacks.
