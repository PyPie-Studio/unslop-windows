# unslop-windows System State Benchmark Report

Comparative audit report measuring baseline system footprint versus post-hardening optimization.

- **Benchmark Date:** 2026-09-07 23:50:18
- **OS Version:** Windows 11 25H2 (Build 10.0.26200.0)
- **Baseline Snapshot:** `logs/before.json` (2026-09-07 23:49:40)
- **Debloated Snapshot:** `logs/before.json` (2026-09-07 23:49:40)

## 📊 Resource Utilization Metrics

| Metric | Baseline | Post-Hardening | Delta / Reduction |
| :--- | :--- | :--- | :--- |
| **Used RAM** | 11.44 GB (36.7%) | 11.44 GB (36.7%) | **0 GB** (0%) |
| **Commit Charge** | 13.16 GB | 13.16 GB | **0 GB** |
| **Active Processes** | 193 | 193 | **0** |
| **Active Threads** | 3383 | 3383 | **0** |
| **User AppX Packages** | 129 | 129 | **0** |

## 🛡 Telemetry Services State

| Service Name | Baseline State | Hardened State |
| :--- | :--- | :--- |
| `dmwappushservice` | Stopped | Stopped |
| `DiagTrack` | Stopped | Stopped |
| `WSearch` | Stopped | Stopped |
| `SysMain` | Stopped | Stopped |
| `diagnosticshub.standardcollector.service` | NotFound | NotFound |

---
*Report generated automatically by `scripts/Measure-SystemState.ps1` — [unslop-windows](https://github.com/PyPie-Studio/unslop-windows)*