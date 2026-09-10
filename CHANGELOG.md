# Changelog

All notable changes to the `unslop-windows` project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.1.5] - 2026-09-10

### Security
- **Reparse Point & Symlink Traversal Defense (`scripts/Measure-SystemState.ps1`)**: Resolved `$snapshotPath` before checking directory attributes and enforced `exit 1` fail-closed termination when a reparse point or directory junction is encountered in user profiles, neutralizing symlink redirection attacks (OPSEC-01).

### Added
- **Local Pre-Commit Git Hook (`.githooks/pre-commit`)**: Added automated pre-commit quality gate execution running rapid AST, PSScriptAnalyzer, and CRLF integrity checks on feature branches and full 7-pillar gates on `main`.
- **Automated Developer Prerequisite Installer (`scripts/Install-GitHooks.ps1`)**: Added `-InstallPrerequisites` switch to automatically discover and install `Pester 5+` and `PSScriptAnalyzer` into the current user's profile and configure Git hook paths in a single command.
- **Production PR Standards Documentation (`CONTRIBUTING.md`)**: Comprehensive testing guidelines, Git hook lifecycles, and mandatory pull request checklist requiring 0 failures under `Test-MasterGate.ps1 -Strict`.
- **Architectural Decision Record (`docs/decisions.md`)**: Documented ADR-021 detailing diagnostic benchmark security, multi-architecture AppX array binding, and local developer hook gates.

### Fixed
- **AppX Multi-Architecture Parameter Binding (`unslop.ps1`)**: Handled multi-architecture AppX matches safely by iterating over matched packages (`foreach ($pkg in $match)`) rather than binding package arrays directly to `Add-AppxPackage -PackagePath`.
- **Log Buffer Variable Scoping (`unslop.ps1`)**: Explicitly scoped `$script:log` in the log buffer export routine, guaranteeing complete log flushing even when called across nested scopes.

### Changed
- **Interactive Batch Toggles Sub-Menu UX (`unslop.bat`)**: Added a dynamic active flags preview banner, a quick reset toggle (`[0] Reset all options to default`), and streamlined argument construction by directly reusing validated active switches.

---

## [1.1.4] - 2026-09-09

### Fixed
- **Widgets Policy Alignment & UCPD Defense (`unslop.ps1`)**: Switched Widgets disablement from user-mode `HKCU:\...\Advanced\TaskbarDa` to machine-wide Group Policy `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0` (undo `1`, `removeOnUndo = $true`). This avoids `UnauthorizedAccessException` from the Windows 11 User Choice Protection Driver (`UCPD.sys`) introduced in 23H2/24H2 while cleanly disabling Widgets system-wide.
- **SYSTEM-Restricted Task Cleanup (`unslop.ps1`)**: Removed `\Microsoft\Windows\Application Experience\SdbinstMergeDbTask` from debloat scheduled tasks list. This task is Windows' internal app compat shim DB merger (non-telemetry) and has an explicit SDDL descriptor restricting write access to `SYSTEM` (`BA` only has Read/Execute), which caused `Access is denied` under standard Administrator elevation.
- **Inbox SystemApps Depuration & NonRemovable Filter (`unslop.ps1`)**: Removed protected inbox SystemApps (`MicrosoftWindows.Client.Photon`, `MicrosoftWindows.Client.CoreAI`, `MicrosoftWindows.UndockedDevKit`) from `$bloatApps` and added `-not $_.NonRemovable` filtering to `Get-AppxPackage` retrieval, preventing `0x80070032` (`ERROR_NOT_SUPPORTED`) deployment errors on immutable system components while keeping AI engines neutralized via GPO and ConsentStore.
- **PowerShell Registry Drive Mapping (`unslop.ps1`)**: Replaced unmounted `HKCR:\CLSID\{018D5C66-...}` with `HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-...}` in both debloat and undo OneDrive unpinning routines, eliminating "Cannot find drive HKCR" errors.

### Added
- **Automated Registry & System Package Invariant Tests (`tests/unslop.Tests.ps1`)**: Added test assertions ensuring `AllowNewsAndInterests` is used for Widgets, forbidding unmounted `HKCR:` paths in registry operations, verifying `SdbinstMergeDbTask` is excluded, and locking `Photon`, `CoreAI`, and `UndockedDevKit` into the non-removable package invariants.
- **Architectural Decision Record (`docs/decisions.md`)**: Documented ADR-020 detailing Windows 11 24H2/25H2 Protection Driver (UCPD), Inbox SystemApps, and Elevation ACL Alignment.

---

## [1.1.3] - 2026-09-09

### Fixed
- **Defender Telemetry Invariant Alignment (`unslop.ps1`)**: Corrected Defender `SubmitSamplesConsent` from `0` (`AlwaysPrompt`, which caused interactive prompts) to `2` (`NeverSend`) in debloat mode, and `1` (`SendSafeSamples`) in undo mode (BUG-01).
- **Startup Entry Preservation & Restoration Symmetry (`unslop.ps1`)**: Upgraded `Remove-StartupEntry` to archive target startup entries under `HKCU:\Software\unslop-windows\StartupBackup` during debloat, enabling 100% lossless symmetrical restoration under `-Undo` (BUG-02).
- **AppX Package List Depuration (`unslop.ps1`)**: Removed system-protected and non-removable packages (`CloudExperienceHost`, `PeopleExperienceHost`, `ParentalControls`, `NarratorQuickStart`, `ECApp`, `MicrosoftEdge.Stable`, `MicrosoftEdgeDevToolsClient`) from `$bloatApps`, preventing `0x80073CFA` de-provisioning errors (BUG-03).
- **Non-Elevated AppX Audit Fidelity & Sequential Enumeration Bottleneck (`unslop.ps1`)**: Switched AppX evaluation to a single-pass `Get-AppxPackage` query with in-memory regex matching, reducing scan latency from ~14s to <1s while providing clear current-user audit guidance when running non-elevated `-DryRun` (BUG-04, PERF-01).
- **Silent Placebo Logging Elimination (`unslop.ps1`)**: Initialized `$global:FailCount` tracking across all modules; replaced raw unhandled commands in scheduled tasks (NVIDIA, Recall, OneDrive) with defensive `Set-TaskState` invocations, and added error trapping with informative failure reporting to firewall and context menu operations (INV-01).
- **Vanishing Elevated Menu Windows (`unslop.bat`)**: Added `-FromMenu` parameter forwarding to the launcher switch whitelist, ensuring that elevated executions initiated from the interactive console menu pause with anti-screen-amnesia before returning to the menu (INV-02).
- **Local Clipboard History Decoupling (`unslop.ps1`)**: Preserved local `Win + V` multi-item clipboard history by eliminating `EnableClipboardHistory = 0` and `AllowClipboardHistory = 0`, while maintaining strict neutralization of cross-device cloud clipboard synchronization (INV-03).
- **CI PSScriptAnalyzer Pre-Installation (`lint.yml`, `release.yml`)**: Added automated `PSScriptAnalyzer` module installation to CI workflows to guarantee static analysis coverage is never skipped in automated pipelines.

### Added
- **Universal Mutating AST Audit (`tests/unslop.Tests.ps1`)**: Expanded the AST parity suite to scan all registry, scheduled task, and service mutations, strictly forbidding naked mutating cmdlets outside approved bidirectional helper functions.
- **Negative Error-Trap Unit Tests (`tests/unslop.Tests.ps1`)**: Added test cases injecting exceptions into helper mocks, verifying error trapping, `$global:FailCount` increments, and truthful `FAILED:` logging.
- **System Package Blacklist Assertions (`tests/unslop.Tests.ps1`)**: Added automated checks ensuring `$bloatApps` never contains immutable system packages or essential Windows Store runtimes.
- **Fail-Closed CI Tooling (`scripts/Test-MasterGate.ps1`)**: Introduced `-Strict` mode (auto-engaged in GitHub Actions) that fails with exit code 1 if `PSScriptAnalyzer` or `Pester 5` is missing.
- **The Zero-Advisory Invariant Mandate (`AGENTS.md`)**: Codified Section 10 requiring that no architectural policy or safety rule exist purely as markdown prose without automated test enforcement.
- **Architectural Decision Record (`docs/decisions.md`)**: Documented ADR-019 covering engine integrity, startup symmetry, Defender realignment, and audit fidelity.

---

## [1.1.2] - 2026-09-08

### Security
- **Elevated Binary Authenticode Verification (`unslop.ps1`)**: Prioritized protected system directories (`SysWOW64`, `System32`) for `OneDriveSetup.exe` uninstaller resolution. Strictly enforced cryptographic `Get-AuthenticodeSignature` verification (`Status = Valid`, `CN=Microsoft Corporation`) before executing any user-writable `%LOCALAPPDATA%` binary in an elevated Administrator context (VULN-01).
- **CLI & Parameter Whitelist Validation Loop (`unslop.bat`)**: Implemented strict token whitelist checking (`-Undo`, `-Restore`, `-DryRun`, `-WhatIf`, `-KeepXbox`, `-KeepOneDrive`, `-KeepTodos`, `-ClassicContextMenu`, `-NoRestart`, `-ForceRestart`, `-RunDirect`), rejecting unlisted parameters and metacharacters with exit code 1 to eliminate command and argument injection vectors (VULN-02).
- **Fail-Closed Offline Architecture (`unslop.bat`)**: Removed unauthenticated `Invoke-RestMethod` script downloads from GitHub CDN. If `unslop.ps1` is missing, the launcher halts with a clear error requiring users to extract the full release archive, eliminating supply chain and MITM risks (VULN-03).
- **Reparse Point & Symlink Defense (`unslop.ps1`)**: Decoupled log saving fallback now targets isolated `$env:LOCALAPPDATA\unslop-windows\logs` and inspects directory attributes for `[System.IO.FileAttributes]::ReparsePoint`, preventing junction/symlink redirection attacks in shared or multi-user environments (OPSEC-01).
- **Release Archive Unit Test Packaging (`.github/workflows/release.yml`)**: Added `tests/` directory to `Compress-Archive` in GitHub Actions release packaging step per ADR-010.

### Changed
- **Windows Update Hardware Driver & Firmware Preservation (`unslop.ps1`)**: Removed `ExcludeWUDriversInQualityUpdate = 1` from debloat passes and added proactive removal of any legacy key so Windows Update hardware CVE patches and firmware updates flow freely (REG-02).

### Added
- **Security & Privilege Boundary Unit Tests (`tests/unslop.Tests.ps1`)**: Added 3 new unit and AST invariant tests verifying Authenticode verification enforcement, reparse point detection, and legacy driver policy cleanup, expanding the test suite to 25 passing assertions.

---

## [1.1.1] - 2026-09-08

### Added
- **PowerShell Comment-Based Help (`unslop.ps1`)**: Integrated comprehensive `<# .SYNOPSIS ... #>` documentation enabling native `Get-Help .\unslop.ps1 -Full` inspection across all parameters, switches, and usage examples.
- **Pure-Batch Interactive Feature Toggles Sub-Menu (`unslop.bat`)**: Added Option `[4] Interactive Toggles` allowing users to configure custom combinations (Xbox, OneDrive, To-Do, Classic Menu, Dry-Run) with visual `[ ON  ]` / `[ OFF ]` toggle states without typing CLI parameters.
- **Curated Launcher Presets (`unslop.bat`)**: Replaced rigid single-app options with curated profiles: `[2] Gamer Preset (-KeepXbox)` and `[3] Productivity Preset (-KeepOneDrive -KeepTodos)`.
- **Dynamic Build Detection (`unslop.ps1`)**: Dynamically resolves the Windows 11 build tag (`23H2`, `24H2`, `25H2`) for runtime console banners and log file names instead of hardcoding `25h2`.

### Changed
- **Semantic Console Logging (`unslop.ps1`)**: Modernized terminal output with contextual `-ForegroundColor` formatting (Cyan headers, Green mutations, Yellow dry-run predictions, DarkGray skips, Red errors, Magenta preserved items) while maintaining clean timestamped disk logs.
- **AppX Package Skip Condensation (`unslop.ps1`)**: Collapsed 40+ repetitive `SKIP: [App] (not installed)` lines into a single aggregate summary line (`SKIP: X bloatware packages not installed on system`), drastically reducing terminal noise.
- **Dynamic & Honest Summary Reporting (`unslop.ps1`)**: Replaced static summary text with dynamic reporting that honors `-KeepOneDrive`, `-KeepXbox`, and `-KeepTodos` parameter flags, and explicitly marks `-DryRun` as preview-only with zero modifications written.
- **Streamlined Reboot Ergonomics (`unslop.ps1`)**: Clarified the interactive restart prompt text (`Initiate 30-second restart countdown? [Y/n]`) and configured `-ForceRestart` to execute immediate reboot without the 30-second delay.
- **Anti-Screen-Amnesia Protection (`unslop.bat`)**: Added an interactive post-audit prompt (`Press [Enter] to return to the menu, or [Q] to exit...`) preventing `cls` from wiping dry-run inspection output.

### Fixed
- **Placebo Logging Elimination (`unslop.ps1`)**: Replaced silent error suppression across helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`) with `try/catch` error trapping that logs honest `FAILED:` feedback when operations encounter locked hives or permissions errors.
- **UAC Elevation Cancellation Handling (`unslop.bat`)**: Added explicit `%errorlevel%` checks after `Start-Process ... -Verb RunAs` to prevent the terminal window from silently vanishing when a user cancels or denies the UAC elevation prompt.

---

## [1.1.0] - 2026-09-08

### Fixed
- **Windows PowerShell 5.1 Dual-Runtime Compatibility**:
  - Replaced Unicode em dashes (`—`, byte `0x94`) with standard hyphens in `unslop.ps1` service descriptions, preventing premature string-quote termination under Windows-1252 ANSI codepages.
  - Simplified mock service status in `tests/unslop.Tests.ps1` from .NET `[System.ServiceProcess.ServiceControllerStatus]` to string literals (`"Running"` / `"Stopped"`), preventing type resolution exceptions in environments where `System.ServiceProcess` is not preloaded.
- **Local Master Gate (`Test-MasterGate.ps1`)**: Refactored Pester 5 subprocess invocation to execute via parameterized script block instead of an escaped command string. Eliminates Windows PowerShell 5.1 command-line expression parsing error (`At line:1 char:890`) during automated CI execution.
- **CI/CD Summary Steps (`lint.yml`, `release.yml`)**: Replaced raw UTF-8 emoji literals in workflow summary blocks with standard ASCII GitHub Markdown shortcodes (`:test_tube:`, `:bar_chart:`, `:shield:`, `:white_check_mark:`, `:x:`). Resolves Windows PowerShell 5.1 ANSI codepage script parsing corruption on GitHub Actions runners.

---

## [1.0.9] - 2026-09-08

### Fixed
- **CI/CD Pipeline (`lint.yml`)**: Resolved GitHub Actions workflow parse failure caused by unsupported expression evaluation in the `shell` keyword (`shell: ${{ matrix.shell }}`). Split execution into two explicit, parallel jobs (`quality-gate-core` for PowerShell 7 and `quality-gate-desktop` for Windows PowerShell 5.1), with `PSScriptAnalyzer` gated on both.

---

## [1.0.8] - 2026-09-08

### Fixed
- **Documentation**: Corrected reboot countdown timer from 60 seconds to 30 seconds in `AGENTS.md` and `docs/decisions.md` to match actual implementation.

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

[Unreleased]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.5...HEAD
[1.1.5]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PyPie-Studio/unslop-windows/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PyPie-Studio/unslop-windows/releases/tag/v1.0.0
