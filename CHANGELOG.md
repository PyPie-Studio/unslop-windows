# Changelog

All notable changes to the `unslop-windows` project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.7] - 2026-09-08

### Removed
- **`scripts/Publish-Release.ps1`**: Deleted redundant local release publisher. The GitHub Actions `release.yml` pipeline is the single source of truth for building release zips, SHA256 checksums, SLSA build provenance attestations, and publishing to GitHub Releases.

---

## [1.0.6] - 2026-09-08

### Changed
- **Leaner Release Zip**: Trimmed `scripts/`, `docs/`, and `tests/` from the release zip bundle. End users only receive the four essential files (`unslop.bat`, `unslop.ps1`, `README.md`, `LICENSE`). Developer tooling remains available in the source repository.

---

## [1.0.5] - 2026-09-08

### Added
- **Automated Static Symmetry Verification via AST Parity Check (`tests/unslop.Tests.ps1`)**: Added 5 automated static AST parity tests using PowerShell's Abstract Syntax Tree parser (`[System.Management.Automation.Language.Parser]::ParseFile`) to enforce 100% Symmetrical Restoration Contract invariants:
  1. Every `Set-RegDwordSafe` call defines both debloat and undo values.
  2. Zero naked mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Stop-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) exist outside approved defensive helper functions.
  3. Every `Set-SvcState` service call defines a valid restore startup type (`Automatic` or `Manual`).
  4. Core engine helper functions maintain strict bidirectional symmetry.
  5. Firewall hardening loop implements bidirectional rule transitions.
- **Native Pester Code Coverage & JaCoCo Reporting (`scripts/Test-MasterGate.ps1`)**: Added `-CodeCoveragePath` parameter enabling native Pester 5 code coverage on `unslop.ps1` with JaCoCo XML output and console coverage metric reporting.
- **GitHub Actions Coverage Summaries & Step Metrics (`.github/workflows/lint.yml`)**: Automated JaCoCo XML parsing in CI, rendering line and instruction code coverage tables directly into `$env:GITHUB_STEP_SUMMARY` and archiving coverage artifacts.
- **Version-Controlled Static Analysis Ruleset (`PSScriptAnalyzerSettings.psd1`)**: Created repository-level analyzer configuration enforcing `Error` and `Warning` rules (`PSAvoidUsingCmdletAliases`, `PSAvoidUsingEmptyCatchBlock`, `PSAvoidUsingPlainTextForPassword`, `PSAvoidUsingInvokeExpression`, `PSAvoidUsingUsernameAndPasswordParams`) with dynamic binding in `Test-MasterGate.ps1`.
- **GitHub Actions Supply Chain Hardening & SLSA Build Provenance (`.github/workflows/`)**: Pinned all third-party actions to immutable 40-character commit SHAs (`actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`, `actions/upload-artifact@4cec3d8aa04e39d1a68397de0c4cd6fb9dce8ec1`). Integrated `actions/attest-build-provenance@e8998f949152b193b063cb0ec769d69d929409be` in `release.yml` for cryptographic SLSA build provenance attestations on release zip bundles and `SHA256SUMS.txt`.
- **Architectural Decision Records (`docs/decisions.md`)**: Added `ADR-013` (AST Parity Symmetry Verification), `ADR-014` (Native Pester Code Coverage), `ADR-015` (Static Analysis Ruleset), and `ADR-016` (Supply Chain Hardening & SLSA Provenance).

---

## [1.0.4] - 2026-09-08

### Added
- **Pester 5 Unit & Mocking Test Suite (`tests/unslop.Tests.ps1`)**: Introduced 17 isolated unit and integration tests mocking native cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Disable-ScheduledTask`, `Enable-ScheduledTask`), parameter flags (`-KeepXbox`, `-KeepOneDrive`), and non-elevated exit contracts with 100% test pass rate.
- **Dedicated Dot-Source Test Guard (`unslop.ps1`)**: Added early top-level exit guard (`if ($MyInvocation.InvocationName -eq '.') { return }`) allowing the engine to export its helper functions into test harnesses without triggering elevation checks or executing debloat logic.
- **Dual PowerShell Runtime Matrix in CI (`.github/workflows/lint.yml`)**: Multi-runtime matrix testing across both `pwsh` (PowerShell 7 Core) and `powershell` (Windows PowerShell 5.1 Desktop) on `windows-latest` with automated Pester 5 module provisioning.
- **7-Pillar Local Master Quality Gate (`scripts/Test-MasterGate.ps1`)**: Expanded the gate to 7 verification pillars by decoupling the batch launcher smoke test (`cmd.exe /c ".\unslop.bat -DryRun"`) into dedicated Pillar 7, restoring sub-second (`0.1s`) execution speed to `-Fast` checks. Added `-TestResultsPath` for NUnit XML export.
- **Gated Production Releases (`.github/workflows/release.yml`)**: Release builds now strictly require the `verify` job to pass all 7 pillars (`needs: verify`) before packaging and publishing assets. Added `tests/` directory to release archive distribution bundles.
- **CI Concurrency, Test Reporting & Step Summary Annotations**: Added PR-aware `concurrency: cancel-in-progress: true`, zero-dependency Markdown step summaries (`$env:GITHUB_STEP_SUMMARY`), inline GitHub Actions workflow annotations (`::error`), and artifact archiving via `actions/upload-artifact@v4`.
- **Architectural Decision Records (`docs/decisions.md`)**: Added `ADR-008` (Pester 5 Unit Suite), `ADR-009` (Dual PS Runtime Matrix), `ADR-010` (Gated Releases), `ADR-011` (Dedicated Batch Smoke Test), and `ADR-012` (CI Concurrency & Annotations).

### Fixed
- **Helper Function Parameter Binding & Switch Scope Collisions (`unslop.ps1`)**: Fixed PowerShell parameter binding collisions where `-Undo` was interpreted as a partial prefix match for `-undoValue` by adding explicit `[switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun` switches across all helper functions.

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

[Unreleased]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PyPie-Studio/unslop-windows/releases/tag/v1.0.0
