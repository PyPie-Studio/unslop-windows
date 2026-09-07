# Changelog

All notable changes to the `unslop-windows` project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Automated Windows Sandbox smoke test harness.
- Expanded Windows 11 25H2/26H2 OneSettings telemetry blocklists.
- SHA-256 cryptographic checksum files published with GitHub releases.

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

[Unreleased]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PyPie-Studio/unslop-windows/releases/tag/v1.0.0
