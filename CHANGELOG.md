# Changelog

All notable changes to the `unslop-windows` project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.3] - 2026-09-08

### Fixed
- **UAC Elevation Batch Syntax Crash (`unslop.bat`)**: Resolved an issue where nested `cmd.exe` quote escaping inside delayed expansion caused `\"'" was unexpected at this time.` syntax errors, crashing `unslop.bat` immediately upon launch. Replaced with clean, native PowerShell process elevation (`Start-Process -FilePath '%~f0' -Verb RunAs`).

### Added
- **Local Master Quality Gate (`scripts/Test-MasterGate.ps1`)**: 5-pillar verification suite combining AST syntax parsing, PSScriptAnalyzer static analysis, CRLF audits, `cmd.exe` batch syntax validation, non-elevated `-DryRun` execution, and symmetrical `-Undo -DryRun` restoration. Includes `-Fast` mode for rapid iteration.
- **Git Pre-Push Hook (`.githooks/pre-push` & `scripts/Install-GitHooks.ps1`)**: Automatic pre-push hook enforcing the 5-pillar quality gate prior to publishing to `main` or `master`.
- **System State Diagnostic Auditor (`scripts/Measure-SystemState.ps1`)**: Standalone tool measuring physical RAM, commit charge, process/thread counts, telemetry services, and AppX packages. Supports `-Snapshot`, `-Baseline`, `-Target`, and `-ExportMarkdown` (`docs/benchmarks.md`).
- **Cryptographic Release Hashes**: Updated `.github/workflows/release.yml` to automatically generate and upload standard GNU-compatible `SHA256SUMS.txt` alongside release bundles.
- **CI Quality Gate Parity**: Updated `.github/workflows/lint.yml` to execute `Test-MasterGate.ps1` and `Measure-SystemState.ps1` on `windows-latest` runners.
- **AI Agent Harness & Modular Skills**: Added [`AGENTS.md`](AGENTS.md), [`SKILLS.md`](SKILLS.md), and 4 domain skills in [`.agents/skills/`](.agents/skills/) (`unslop-safetier-engine`, `unslop-windows-internals`, `unslop-quality-gate`, `unslop-agent-workflow`).
- **Architecture Decision Records (`docs/decisions.md`)**: Formal ledger tracking `ADR-001` through `ADR-007` covering safe-tier invariants, symmetry, non-elevated auditing, restart UX, quality gate, agent harness, and benchmarking.
- **Repository Governance**: Added `.gitattributes`, `.editorconfig`, `.github/PULL_REQUEST_TEMPLATE.md`, and `ROADMAP.md`.

### Security & Hardening
- **Batch Syntax Gate Hardening**: Upgraded `scripts/Test-MasterGate.ps1` to directly test `cmd.exe /c "call unslop.bat -DryRun"` in Step 3 to ensure batch syntax corruptions or quote-escaping bugs can never pass local pre-push or CI/CD gates again.

---

## [1.0.2] - 2026-09-07

### Added
- **In-Place Abort Shortcut (`A`)**: Replaced the cumbersome manual requirement of opening a separate terminal to run `shutdown /a`. Users can now tap **`A`** directly in the active countdown window to immediately cancel the scheduled restart.
- **Instant Reboot Shortcut (`R`)**: Tapping **`R`** or pressing **Enter** during the 30-second countdown immediately triggers the system reboot on demand.
- **Ctrl+C Abort Safeguard**: Interrupting the countdown via `Ctrl+C` automatically triggers `shutdown /a` in a `finally` block, ensuring no scheduled reboot timer is left active in the background.

### Changed
- Live in-place countdown display rendering remaining seconds and active keyboard shortcuts on a single line (`Restarting in 28s... [Press 'A' to Abort | 'R' to Restart Now]`).

### Fixed
- Resolved an issue where `unslop.bat` remained paused at `Press any key to continue . . .` after a reboot was initiated. The launcher now detects exit code `100` and automatically closes the terminal window so Windows can restart without hanging.

---

## [1.0.1] - 2026-09-07

### Added
- **Administrator Privileges Enforcement**: Added an explicit pre-flight check in `unslop.ps1` that blocks non-elevated executions with actionable error messages (while keeping non-elevated `-DryRun` audit inspection intact).
- **Post-Run Restart Prompt**: Introduced an interactive prompt upon script completion offering to restart the system, along with the `-NoRestart` and `-ForceRestart` parameters.
- **System Restart Requirement**: Prominently documented that a reboot is required to flush cached telemetry threads, reload service states, and apply group policy changes.

### Changed
- Updated `README.md` to document mandatory admin rights and post-run reboot requirements across all installation methods.

---

## [1.0.0] - 2026-09-05

### Added
- **Initial Public Release**: Safe-Tier Universal Windows 11 23H2, 24H2 & 25H2 Debloater and Privacy Hardener.
- **18 Hardening Modules**:
  1. Services optimization (`SysMain`, `WSearch`, `DiagTrack`, `dmwappushservice`, `TrkWks`, `lfsvc`).
  2. Windows Recall (`DisableAIDataAnalysis = 1`, `AllowRecall = 0`) and Windows Copilot policies.
  3. Diagnostic data and telemetry collection policies.
  4. Start Menu recommendations, tips, and Content Delivery Manager promotions.
  5. Speech and typing/inking personalization telemetry.
  6. Bing cloud search integration and web suggestions.
  7. Network security: LLMNR mitigation and Wi-Fi Sense suppression.
  8. Windows Update GPU driver overwrite protection.
  9. Explorer & Taskbar: Widgets and Chat removal, file extension visibility enforcement.
  10. ConsentStore: 12 background capability access revocations (Location, Diagnostics, 25H2 screen text scraping, OS AI model execution).
  11. Scheduled tasks: Disables 18+ telemetry tasks across CEIP, OneSettings, PowerGridForecast, and MareBackup.
  12. Dual-Stage AppX Purge: Removes installed packages across user profiles and de-provisions staged packages from the Windows image.
  13. OneDrive Purge Engine: Process termination, silent uninstaller, sidebar unpinning, and sync blocking policies.
  14. Startup entries: Disables Edge background tasks and autorun entries.
  15. Microsoft Defender telemetry sample upload suppression (`SubmitSamplesConsent = 0`).
  16. Activity History and cross-device Cloud Clipboard disabling.
  17. Delivery Optimization: Peer-to-peer upload blocking via GPO (`DODownloadMode = 0`) without disabling `DoSvc`.
  18. Firewall: Blocks 8 outbound telemetry and remote assistance rules.
- **Symmetrical 1-Click Restoration (`-Undo`)**: Exact 1:1 inverse mapping for all services, tasks, registry policies, and firewall rules.
- **Safe Non-Elevated Dry-Run (`-DryRun`)**: Zero modifications inspection mode.
- **Untouchable Whitelist**: Protected daily tools (Terminal, Store, WinGet, Calculator, Photos, Paint, Snipping Tool, Microphone, Webcam, Developer environments).
- **Interactive Menu Launcher (`unslop.bat`)**: Standalone self-bootstrapping console launcher.
- **Decoupled Autonomous Logging**: Automatic logging to `logs/` or `$env:TEMP\unslop_logs`.

---

[Unreleased]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PyPie-Studio/unslop-windows/releases/tag/v1.0.0
