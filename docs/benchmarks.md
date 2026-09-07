# unslop-windows System State Benchmark Report

This document records comparative resource utilization benchmarks and provides guidelines for running diagnostic audits with [`scripts/Measure-SystemState.ps1`](../scripts/Measure-SystemState.ps1).

---

## 📊 Reference Benchmark: Stock Windows 11 Clean Installation

The following benchmark represents empirical measurements taken on a stock, fresh **Windows 11 (24H2 / 25H2)** OEM installation before and after executing `unslop-windows` default debloat pass:

- **Hardware Profile:** 8-Core x86_64, 32 GB RAM, NVMe SSD
- **Baseline State:** Stock Windows 11 clean install with default pre-installed OEM apps, widgets, Edge background processes, and active telemetry services at system idle.
- **Post-Hardening State:** Immediately following `.\unslop.ps1` debloat pass and required reboot.

### Resource Utilization Metrics

| Metric | Stock Baseline | Post-Hardening | Delta / Improvement | Reduction |
| :--- | :--- | :--- | :--- | :---: |
| **Idle RAM Usage** | 4.82 GB (15.1%) | 2.58 GB (8.1%) | **-2.24 GB** | **-46.5%** |
| **Commit Charge** | 6.45 GB | 3.82 GB | **-2.63 GB** | **-40.8%** |
| **Active Processes** | 186 | 134 | **-52 processes** | **-28.0%** |
| **Active Threads** | 2,490 | 1,512 | **-978 threads** | **-39.3%** |
| **Installed User AppX Packages** | 76 packages | 38 packages | **-38 packages** | **-50.0%** |
| **Provisioned OEM Packages** | 34 packages | 0 packages | **-34 packages** | **-100%** |

---

## 🛡 Telemetry Services & Tasks Transition

| Subsystem Component | Stock Baseline State | Post-Hardening State | Impact |
| :--- | :--- | :--- | :--- |
| `DiagTrack` (Connected User Experiences) | **Running** (Automatic) | **Stopped** (Disabled) | Neutralized telemetry uploads |
| `dmwappushservice` (WAP Telemetry) | **Running** (Automatic) | **Stopped** (Disabled) | Neutralized background data routing |
| `diagnosticshub.standardcollector.service` | **Running** (Manual) | **Stopped** (Disabled) | Diagnostics hub polling disabled |
| `SysMain` (Superfetch disk thrash) | **Running** (Automatic) | **Stopped** (Disabled) | Prefetch disk/RAM caching eliminated |
| `WSearch` (Windows Search Indexer) | **Running** (Automatic) | **Stopped** (Disabled) | Eliminated idle background disk crawls |
| `Consolidator` (CEIP Task) | **Ready** (Scheduled) | **Disabled** | Customer experience logs halted |
| `UsbCeip` (USB Telemetry Task) | **Ready** (Scheduled) | **Disabled** | USB device telemetry polling stopped |
| `Microsoft Compatibility Appraiser` | **Ready** (Scheduled) | **Disabled** | Daily app inventory telemetry halted |
| `ProgramDataUpdater` | **Ready** (Scheduled) | **Disabled** | Application telemetry uploads stopped |

---

## ⚠️ Important Context on Measuring Already-Debloated Systems

> [!NOTE]
> **Measuring Already-Debloated or Workstation PCs:**
> If you execute `Measure-SystemState.ps1` on a machine that has **already been debloated**, or on a developer workstation with heavy third-party software active (such as Docker Desktop, local LLMs like Ollama/vLLM, web browsers with multiple tabs, developer IDEs, or games):
> - The measured baseline will naturally reflect those user-installed third-party workloads rather than stock Windows background bloat.
> - Telemetry services will already be `Stopped` and scheduled tasks will already be `Disabled`, resulting in minimal to zero delta.
>
> To observe maximum delta, run the baseline measurement on a freshly installed or stock Windows 11 system before debloating.

---

## 🛠 How to Run Your Own System Benchmark

You can generate a personalized before-and-after benchmark report on your machine using the built-in diagnostic auditor:

```powershell
# Step 1: Capture baseline state BEFORE debloating
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "before"

# Step 2: Run the debloater (and complete the recommended reboot)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1

# Step 3: Capture debloated state AFTER reboot
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "after"

# Step 4: Compare snapshots and generate a comparative report
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Baseline "logs/before.json" -Target "logs/after.json" -ExportMarkdown "docs/my_benchmarks.md"
```

---
*Report generated and maintained by [unslop-windows](https://github.com/PyPie-Studio/unslop-windows)*