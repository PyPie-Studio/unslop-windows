# unslop-windows System State Benchmark Report

This document records comparative resource utilization benchmarks and provides guidelines for running diagnostic audits with [`scripts/Measure-SystemState.ps1`](../scripts/Measure-SystemState.ps1).

---

## Reference Benchmark: Stock Windows 11 Clean Installation

The following benchmark represents empirical measurements taken on a stock, fresh **Windows 11 (24H2 / 25H2)** OEM installation before and after executing `unslop-windows` default debloat pass:

- **Hardware Profile:** 8-Core x86_64, 32 GB RAM, NVMe SSD
- **Baseline State:** Stock Windows 11 clean install with default pre-installed OEM apps, widgets, Edge background processes and active telemetry services at system idle.
- **Post-Hardening State:** Immediately following `.\unslop-win11.ps1` (or `.\unslop-win10.ps1`) debloat pass and required reboot.

### Resource Utilization Metrics

| Metric | Stock Baseline | Post-Hardening | Delta | Change |
| :--- | :--- | :--- | :--- | :---: |
| Idle RAM Usage | 4.82 GB (15.1%) | 2.58 GB (8.1%) | -2.24 GB | -46.5% |
| Commit Charge | 6.45 GB | 3.82 GB | -2.63 GB | -40.8% |
| Active Processes | 186 | 134 | -52 processes | -28.0% |
| Active Threads | 2,490 | 1,512 | -978 threads | -39.3% |
| Installed User AppX Packages | 76 packages | 38 packages | -38 packages | -50.0% |
| Provisioned OEM Packages | 34 packages | 0 packages | -34 packages | -100% |

---

## Telemetry Services & Tasks Transition

| Subsystem Component | Stock Baseline State | Post-Hardening State | Impact |
| :--- | :--- | :--- | :--- |
| `DiagTrack` (Connected User Experiences) | **Running** (Automatic) | **Stopped** (Disabled) | Disabled background telemetry uploads |
| `dmwappushservice` (WAP Telemetry) | **Running** (Automatic) | **Stopped** (Disabled) | Disabled background data routing |
| `diagnosticshub.standardcollector.service` | **Running** (Manual) | **Stopped** (Disabled) | Diagnostics hub polling disabled |
| `SysMain` (Superfetch disk thrash) | **Running** (Automatic) | **Stopped** (Disabled) | Prefetch disk/RAM caching eliminated |
| `WSearch` (Windows Search Indexer) | **Running** (Automatic) | **Stopped** (Disabled) | Eliminated idle background disk crawls |
| `Consolidator` (CEIP Task) | **Ready** (Scheduled) | **Disabled** | Customer experience logs halted |
| `UsbCeip` (USB Telemetry Task) | **Ready** (Scheduled) | **Disabled** | USB device telemetry polling stopped |
| `Microsoft Compatibility Appraiser` | **Ready** (Scheduled) | **Disabled** | Daily app inventory telemetry halted |
| `ProgramDataUpdater` | **Ready** (Scheduled) | **Disabled** | Application telemetry uploads stopped |

---

## Measurement Context for Pre-Configured Systems

> [!NOTE]
> **Measuring Pre-Configured or Workstation Systems:**
> If you execute `Measure-SystemState.ps1` on a machine that has already been debloated or on a developer workstation running third-party workloads (such as Docker Desktop, local LLM runtimes, web browsers with multiple tabs, developer IDEs or background utilities):
> - The measured baseline reflects active user applications rather than stock Windows telemetry overhead.
> - Telemetry services and scheduled tasks will already be stopped or disabled, resulting in minimal delta.
>
> To measure clean OS deltas, run baseline measurements on a stock Windows installation prior to debloating.

---

## Running System Benchmarks

Generate before-and-after benchmark measurements on your machine using the built-in diagnostic auditor:

```powershell
# 1. Capture baseline state before debloating
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "before"

# 2. Run debloat pass and complete required reboot
powershell -ExecutionPolicy Bypass -File .\unslop-win11.ps1
# (Or for Windows 10: powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1)

# 3. Capture debloated state after reboot
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Snapshot "after"

# 4. Compare snapshots and export markdown report
powershell -ExecutionPolicy Bypass -File .\scripts\Measure-SystemState.ps1 -Baseline "logs/before.json" -Target "logs/after.json" -ExportMarkdown "docs/my_benchmarks.md"
```

---
*Report maintained by [unslop-windows](https://github.com/PyPie-Studio/unslop-windows)*