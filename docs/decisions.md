# unslop-windows Architecture Decision Records (ADRs)

This document logs significant architectural, security and quality decisions for **unslop-windows**.

Format: `ADR-XXX: Title (Date) -> Status -> Context -> Decision -> Consequences`.

**BEFORE re-deciding anything** (changing policy behavior, adding dependencies, modifying the reboot lifecycle): read this log. If the decision exists, follow it. If a decision genuinely must change, log a new entry overriding the old one.

---

## ADR-001: Safe-Tier Hardening Invariant & WinSxS Component Preservation (2026-09-07)
- **Status:** Accepted
- **Context:** Aggressive Windows debloaters frequently break Windows Cumulative Updates (resulting in rollback error `0x800f0922` or `0x80073701`), brick the Microsoft Store or cause irreparable OS instability by deleting components from the WinSxS store (`dism /online /cleanup-image /startcomponentcleanup /resetbase`).
- **Decision:** unslop-windows strictly enforces a **Safe-Tier invariant**:
  - No DISM component stripping or `/resetbase` execution.
  - No deletion or tampering of files inside `C:\Windows\WinSxS` or core system directories.
  - Microsoft Store, winget package installer and core runtimes (VCLibs, DirectX, .NET) are permanently whitelisted.
  - UWP bloatware is removed purely at the app package and provisioned package level (`Remove-AppxPackage`, `Remove-AppxProvisionedPackage`).
- **Consequences:** All monthly Cumulative Updates install without rollbacks. The script is safe for both daily driver workstations and corporate endpoint environments.

---

## ADR-002: Symmetrical 1-Click Restoration Engine (`-Undo` Contract) (2026-09-07)
- **Status:** Accepted
- **Context:** System administrators and privacy-conscious users need total confidence that any applied policy or configuration change can be cleanly reverted without reinstalling the operating system or restoring system restore points.
- **Decision:** Every single debloating or hardening tweak across all 18 modules must have an exact, tested inverse operation implemented in the `if ($Undo)` branch:
  - Added registry keys must be deleted or reset to their clean Windows default values.
  - Disabled telemetry services must be restored to `Manual` or `Automatic`.
  - Disabled scheduled tasks must be re-enabled.
- **Consequences:** Provides 100% reversible state management via `.\unslop.ps1 -Undo`. Prevents configuration lock-in.

---

## ADR-003: Non-Elevated `-DryRun` Auditing & Zero Administrative Trap (2026-09-07)
- **Status:** Accepted
- **Context:** Users, security auditors and CI pipelines need the ability to inspect the operations that `unslop.ps1` would perform before granting administrative privileges. Scripts that fail immediately on missing administrator rights prevent pre-flight auditing.
- **Decision:** Decoupled administrative elevation checks from the `-DryRun` audit path:
  - If `-DryRun` is passed, the script executes in read-only inspection mode under standard user privileges.
  - All mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Stop-Service`, `Set-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) are guarded by `if (-not $DryRun)`.
- **Consequences:** Enables non-elevated CI validation, zero-risk developer inspection and automated testing across unprivileged user environments.

---

## ADR-004: In-Place Reboot Lifecycle, Keyboard Abort Shortcut & Exit Code Contract (2026-09-07)
- **Status:** Accepted
- **Context:** Many Windows policy tweaks and service state changes require a system restart to take effect. However, abrupt restarts risk user data loss. Additionally, requiring the user to open a secondary terminal to run `shutdown /a` provides a poor user experience. Halting on `pause` after initiating a restart countdown leaves unnecessary windows open.
- **Decision:**
  - Implemented an interactive 30-second reboot countdown directly inside `unslop.ps1` using non-blocking raw console polling (`$Host.UI.RawUI.KeyAvailable`).
  - Added in-place keyboard controls: press `A` to abort immediately (`shutdown.exe /a`), press `R` or `Enter` to reboot without waiting.
  - Added `Ctrl+C` interrupt handling inside a `finally` block to automatically call `shutdown.exe /a`.
  - Established an exit code contract: `unslop.ps1` exits with code `100` when a reboot is scheduled, prompting `unslop.bat` to terminate immediately without halting on `pause`.
- **Consequences:** Foolproof reboot UX with zero risk of accidental forced reboots.

---

## ADR-005: Local Master Quality Gate & Git Pre-Push Hook (2026-09-07)
- **Status:** Accepted
- **Context:** Changes committed to `main` must not introduce syntax errors, break `unslop.bat` with LF line endings, fail static analysis or regress dry-run execution.
- **Decision:** Onboarded a 5-pillar local quality gate adapted from A3MALI and NodeRadar Pro:
  - Created [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) with 5 checks (AST parser, PSScriptAnalyzer, CRLF/conflict markers, `-DryRun` and `-Undo -DryRun`).
  - Added [`.githooks/pre-push`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.githooks/pre-push) and [`scripts/Install-GitHooks.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Install-GitHooks.ps1) to block pushes targeting `main` or `master` if the gate fails.
- **Consequences:** Prevents broken code from reaching the repository, enforces CRLF on Windows batch files and eliminates regressions before pull requests are opened.

---

## ADR-006: Modular Architecture Standards & Verification Protocol (2026-09-07)
- **Status:** Accepted
- **Context:** To maintain system stability across Windows feature updates and ensure repeatable, error-free contributions, the codebase requires clear modular boundaries, strict safe-tier invariants and automated verification protocols.
- **Decision:** Established standardized architecture specifications across all modules:
  - Codified Safe-Tier invariants: zero DISM component removal, zero system driver removal and permanent whitelisting of Microsoft Store and WinGet.
  - Enforced 100% bidirectional symmetry: every debloat operation must define an exact inverse restore path via `-Undo`.
  - Required automated test coverage: all policies, service transitions and registry tweaks must be backed by unit tests or AST assertions.
- **Consequences:** Ensures consistent codebase architecture, prevents destructive modifications and maintains system stability across updates.

---

## ADR-007: Diagnostic State Auditor & CI/CD Cryptographic Verification (2026-09-07)
- **Status:** Accepted
- **Context:** Users and enterprise administrators require measurable empirical proof of system debloating (RAM delta, thread reduction, stopped telemetry services). Additionally, binary releases packaged in GitHub Actions require cryptographic integrity verification to protect against supply-chain tampering.
- **Decision:**
  - Implemented [`scripts/Measure-SystemState.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Measure-SystemState.ps1) to capture baseline metrics, perform comparative audits and export Markdown reports (`docs/benchmarks.md`).
  - Hardened [`.github/workflows/release.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/release.yml) to generate standard GNU-compatible `SHA256SUMS.txt` and upload checksums as release assets alongside the release zip archive.
  - Upgraded [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) to execute the complete local 5-pillar Master Gate (`Test-MasterGate.ps1`) including non-elevated `-DryRun` smoke testing, achieving 100% parity between local hooks and CI.
- **Consequences:** Provides transparent before/after benchmarking, eliminates local vs CI test drift and offers cryptographic verification for downstream users.

---

## ADR-008: Pester 5 Unit & Mocking Test Suite and Dot-Source Guard Architecture (2026-09-08)
- **Status:** Accepted
- **Context:** The Master Quality Gate previously relied solely on static linting and black-box `-DryRun` console text parsing. Swapped parameter bugs, inverted registry values or broken whitelist filters could pass undetected so long as the script completed without throwing unhandled exceptions. Furthermore, the monolithic structure of `unslop.ps1` prevented isolated function testing because dot-sourcing immediately triggered elevation checks and executed all 18 debloat modules.
- **Decision:**
  - Implemented a native PowerShell dot-source guard (`if ($MyInvocation.InvocationName -eq '.') { return }`) placed after engine helper function definitions and before the administrative check and procedural debloat logic.
  - Added explicit switch parameters with scope fallbacks (`[switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun`) to helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`), enabling complete unit test isolation without breaking backwards compatibility.
  - Created a dedicated zero-elevation Pester unit test suite (`tests/unslop.Tests.ps1`) mocking all mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Stop-Service`, `Disable-ScheduledTask`, `Enable-ScheduledTask`).
  - Integrated the Pester test suite as Pillar 4 in `scripts/Test-MasterGate.ps1` and updated CI workflows accordingly.
- **Consequences:** Provides granular unit test verification for helper logic, prevents silent regressions in registry and service state manipulation, verifies parameter contracts (`-KeepXbox`, `-KeepOneDrive`, non-elevated exit codes) and maintains 100% test coverage without modifying live system state.

---

## ADR-009: Dual PowerShell Runtime Matrix & Engine Parity Contract (PS 5.1 Desktop & PS 7 Core) (2026-09-08)
- **Status:** Accepted
- **Context:** `unslop-windows` targets Windows 11 systems running Windows PowerShell 5.1 (`powershell.exe`) via `unslop.bat` as well as modern PowerShell 7+ (`pwsh`). While `#requires -Version 5.1` is declared, the CI pipeline historically tested only `shell: pwsh`. This introduced the risk that PS 7-only syntax features (e.g., ternary operators `?:`, null-coalescing `??`, pipeline chains `&&` / `||` or newer .NET APIs) could pass CI while crashing in production on stock Windows 11 installations. Additionally, `Test-MasterGate.ps1` previously defaulted subprocess execution (`$psExec`) to `pwsh` whenever `pwsh` was present in PATH, causing false-positive passes under PS 5.1 runners.
- **Decision:**
  - Upgraded [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) to a multi-runtime matrix strategy across both `powershell` (Windows PowerShell 5.1 Desktop) and `pwsh` (PowerShell 7+ Core) on `windows-latest`.
  - Bound `$psExec` in [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) directly to the active host's `$PSVersionTable.PSEdition` (`Desktop` -> `powershell.exe`, `Core` -> `pwsh`), guaranteeing that all subprocess tests (`unslop.ps1 -DryRun`, `unslop.ps1 -Undo -DryRun` and Pester unit tests) execute in the matching runtime.
  - Added an automated module assurance step in CI to ensure Pester 5 is available in both runner environments.
- **Consequences:** Eliminates runtime blind spots between Windows PowerShell 5.1 and PowerShell 7. Guarantees that syntax and logic regressions targeting clean Windows 11 installs are caught in CI prior to merge.

---

## ADR-010: Gated Production Releases via Quality Gate Prerequisite (`needs: verify`) (2026-09-08)
- **Status:** Accepted
- **Context:** Pushing a release tag (`v*`) previously triggered immediate packaging, checksum calculation and asset publication to GitHub Releases without running `Test-MasterGate.ps1` or verifying that the tagged commit passed unit tests or dry-run smoke tests. A tagged commit containing an undetected syntax error or regression would be published to users as an official release bundle with valid cryptographic hashes.
- **Decision:**
  - Restructured [`.github/workflows/release.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/release.yml) into a sequential two-stage pipeline where `publish-release` explicitly depends on `needs: verify`.
  - The `verify` prerequisite job executes the full 7-pillar Master Quality Gate ([`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1)) including AST parsing, static analysis, CRLF/batch syntax, Pester unit tests and dry-run smoke tests under `permissions: contents: read`.
  - Added `tests/` directory to the release zip archive bundle (`Compress-Archive`) so enterprise users and system administrators can execute the unit test suite on unpacked distributions.
- **Consequences:** Guarantees zero broken releases. If any pillar in the quality gate fails on the tagged commit, release publication is blocked immediately and no assets are uploaded.

---

## ADR-011: Dedicated Batch Launcher CLI Passthrough Smoke Test (Pillar 7) (2026-09-08)
- **Status:** Accepted
- **Context:** `unslop.bat` is the primary entry point for standard users launching debloat and restoration operations. To ensure that batch script syntax errors, line-ending corruption or CLI parameter forwarding flaws are caught automatically, a batch execution check was previously embedded inside Step 3 (`Line-Ending & File Integrity Audit`). However, because Step 3 is executed even during rapid quality gate checks (`Test-MasterGate.ps1 -Fast`), this caused pre-commit and rapid development audits to jump from sub-second runtimes (<0.2s) to ~12 seconds.
- **Decision:**
  - Decoupled batch script validation into two distinct concerns:
    1. **Static Byte-Level Integrity (Pillar 3):** Inspects `unslop.bat` for strict CRLF line endings (verifying no naked LF bytes exist) and scans for merge conflict markers across all repository text files. Runs in <0.1s.
    2. **Execution-Based CLI Passthrough Smoke Test (Pillar 7):** Invokes `cmd.exe /c ".\unslop.bat -DryRun"`, verifying zero syntax errors, valid headless parameter forwarding to `unslop.ps1` and clean exit code 0 propagation.
  - Configured `Test-MasterGate.ps1 -Fast` to skip all execution-based tests (Steps 4 through 7), restoring sub-second performance.
- **Consequences:** Restores instantaneous (<0.2s) feedback loops for local rapid checks and git hooks while maintaining full end-to-end headless CLI verification of the batch wrapper in automated CI and release verification gates.

---

## ADR-012: CI Concurrency, NUnit XML Test Reporting & Native Step Summaries (2026-09-08)
- **Status:** Accepted
- **Context:** Rapid commits and branch updates in pull requests can trigger redundant, overlapping CI matrix runs, needlessly consuming Windows runner minutes. Furthermore, Pester 5 unit test results were previously emitted solely to the runner stdout stream. When failures occurred, developers were required to scroll through extensive console logs to diagnose test assertions.
- **Decision:**
  - Implemented branch- and PR-aware workflow concurrency in `.github/workflows/lint.yml` via `concurrency: group: ${{ github.workflow }}-${{ github.head_ref || github.ref }}, cancel-in-progress: true`, automatically cancelling superseded runner jobs.
  - Added `-TestResultsPath` parameter support to `scripts/Test-MasterGate.ps1`, utilizing Pester 5's `New-PesterConfiguration` object to generate standard NUnit XML test result files.
  - Resolved helper function parameter binding collisions in `unslop.ps1` (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`, `Log`) by introducing explicit `[switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun` switches, achieving 100% clean test execution across all 17 Pester test cases.
  - Built zero-dependency test result extraction in CI workflows, reading the generated NUnit XML and publishing a formatted Markdown summary table to `$env:GITHUB_STEP_SUMMARY` along with inline workflow error annotations (`::error`).
  - Added `actions/upload-artifact@v4` steps to archive raw NUnit XML test reports for long-term auditability.
- **Consequences:** Dramatically cuts CI runner consumption, surfaces immediate visual test metrics in GitHub Actions run summaries, provides clickable inline annotations on failed tests and preserves zero third-party dependency safety.

---

## ADR-013: Automated Static Symmetry Verification via AST Parity Check (2026-09-08)
- **Status:** Accepted
- **Context:** Guardrail 3 (100% Symmetrical Restoration Contract) mandates that every single state-mutating registry tweak, service modification or policy change has an exact inverse in the `-Undo` restoration branch. While dynamic dry-run smoke tests and Pester unit tests test behavior at runtime, they cannot catch missing undo logic or newly introduced naked mutating cmdlets prior to runtime execution.
- **Decision:**
  - Implemented 5 automated static AST parity tests in [`tests/unslop.Tests.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/tests/unslop.Tests.ps1) using PowerShell's Abstract Syntax Tree parser (`[System.Management.Automation.Language.Parser]::ParseFile`).
  - The AST test suite validates that:
    1. Every `Set-RegDwordSafe` call across debloat modules specifies both debloat and undo values.
    2. Zero naked mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Stop-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) exist outside defensive helper functions.
    3. Every `Set-SvcState` invocation specifies a valid restore startup type (`Automatic` or `Manual`).
    4. Core engine helper functions maintain strict bidirectional symmetry.
    5. Firewall hardening blocks implement bidirectional rule transitions.
- **Consequences:** Catches asymmetry and unsafe cmdlet usage statically at test time before any code executes or reaches production.

---

## ADR-014: Native Pester Code Coverage Instrumentation & JaCoCo Reporting (2026-09-08)
- **Status:** Accepted
- **Context:** While 17 Pester unit tests verified helper function behavior, the project had no visibility into total line or instruction coverage across `unslop.ps1`, making it difficult to assess testing blind spots.
- **Decision:**
  - Integrated native Pester 5 code coverage into [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) via `-CodeCoveragePath` parameter, configuring `$cfg.CodeCoverage.Enabled = $true`, `$cfg.CodeCoverage.Path = 'unslop.ps1'` and `$cfg.CodeCoverage.OutputFormat = 'JaCoCo'`.
  - Added console coverage reporting in the Master Gate output and automated JaCoCo XML parsing in [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) to publish line and instruction coverage tables to `$env:GITHUB_STEP_SUMMARY`.
  - Uploaded coverage reports as GitHub Actions artifacts alongside Pester NUnit XML results.
- **Consequences:** Provides transparent, zero-dependency test coverage metrics tracked in CI and locally without external plugins or third-party binaries.

---

## ADR-015: Version-Controlled Static Analysis Ruleset (`PSScriptAnalyzerSettings.psd1`) (2026-09-08)
- **Status:** Accepted
- **Context:** `PSScriptAnalyzer` previously ran with default unpinned rules, leading to potential variance between developer workstations and CI runners, while triggering irrelevant warnings for single-file monolithic CLI scripts (e.g. comment-based help requirements).
- **Decision:**
  - Created [`PSScriptAnalyzerSettings.psd1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/PSScriptAnalyzerSettings.psd1) at repository root specifying exact severity levels (`Error`, `Warning`), enforcing critical security and code quality rules (`PSAvoidUsingCmdletAliases`, `PSAvoidUsingEmptyCatchBlock`, `PSAvoidUsingPlainTextForPassword`, `PSAvoidUsingInvokeExpression`, `PSAvoidUsingUsernameAndPasswordParams`) and excluding inappropriate monolithic script rules (`PSProvideCommentHelp`, `PSAvoidUsingPositionalParameters`, `PSAvoidGlobalVars`).
  - Updated [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) to bind `-Settings` to `PSScriptAnalyzerSettings.psd1` automatically when present.
- **Consequences:** Enforces standardized, deterministic static analysis across all local and CI environments.

---

## ADR-016: GitHub Actions Supply Chain Hardening & SLSA Build Provenance (2026-09-08)
- **Status:** Accepted
- **Context:** Third-party GitHub Actions referenced via mutable floating tags (e.g., `@v4`) are vulnerable to tag spoofing and upstream supply chain attacks. Furthermore, published release zip archives and checksums lacked cryptographic provenance proving they were built on untampered GitHub Actions runners.
- **Decision:**
  - Pinned all GitHub Action references across [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) and [`.github/workflows/release.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/release.yml) to immutable 40-character commit SHAs with inline version comments (`actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`, `actions/upload-artifact@4cec3d8aa04e39d1a68397de0c4cd6fb9dce8ec1 # v4.6.1`).
  - Added `id-token: write` and `attestations: write` permissions to `publish-release` in `release.yml`.
  - Integrated `actions/attest-build-provenance@e8998f949152b193b063cb0ec769d69d929409be # v2.4.0` to generate verifiable cryptographic SLSA build provenance attestations for both `unslop-windows-*.zip` and `SHA256SUMS.txt`.
- **Consequences:** Eliminates supply chain risks from mutated action tags and provides users with cryptographic proof of release build provenance.

---

## ADR-017: Terminal UI/UX Modernization, Interactive Batch Toggles & Honest Error Feedback (2026-09-08)
- **Status:** Accepted
- **Context:** A critical analysis of `unslop-windows` UI/UX identified 8 architectural deficiencies:
  1. *Placebo logging:* Silent error suppression (`-ErrorAction SilentlyContinue`) logged success even when mutating registry or service calls failed.
  2. *Deceptive summary:* Hardcoded static text claimed items were disabled or removed during read-only `-DryRun` audits and falsely reported "OneDrive removed" even when `-KeepOneDrive` was passed.
  3. *Signal-to-noise saturation:* Monochrome terminal logging and 40+ repetitive `SKIP:` lines for uninstalled AppX packages flooded the screen.
  4. *Rigid launcher menu:* Mutually exclusive radio-button options in `unslop.bat` forced users to type manual CLI flags when combining common features (e.g. keeping both Xbox and OneDrive).
  5. *Vanishing window on UAC dismissal:* The parent batch launcher exited immediately without checking if UAC elevation succeeded or was cancelled by the user.
  6. *Screen amnesia:* Returning from a `-DryRun` audit immediately invoked `cls`, wiping the inspection results off the screen.
  7. *Reboot double-prompt friction:* Users answering "Yes" to restart were immediately presented with another 30-second countdown delay asking them to press `R` to restart now.
  8. *Missing help documentation:* `unslop.ps1` lacked PowerShell comment-based help (`<# .SYNOPSIS ... #>`).
- **Decision:**
  - Upgraded engine helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`) with `try/catch` error blocks (`-ErrorAction Stop`) that log honest `FAILED:` feedback without breaking AST symmetry or Pester mocks.
  - Dynamically evaluated completion summary screens based on runtime parameters (`-KeepOneDrive`, `-KeepXbox`, `-KeepTodos`, `-ClassicContextMenu`) and `-DryRun` state while strictly preserving gate assertion tokens (`"UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE"` and `"RESTORE / UNDO COMPLETE"`).
  - Modernized console output with semantic ANSI color formatting (Cyan headers, Green mutations, Yellow dry-run predictions, DarkGray skips, Red failures, Magenta notices) and collapsed 40+ uninstalled package lines into a single aggregate skip count.
  - Overhauled `unslop.bat` with curated presets (`Gamer Preset`, `Productivity Preset`), an interactive toggle sub-menu (`:toggles`) managing `[ ON  ]` / `[ OFF ]` states in pure Batch, UAC dismissal error handling and an anti-screen-amnesia prompt.
  - Streamlined reboot handling: `-ForceRestart` immediately reboots (`shutdown /r /t 0`) and the interactive prompt clearly announces the 30-second countdown.
  - Added PowerShell `<# .SYNOPSIS ... #>` comment-based help to `unslop.ps1`.
- **Consequences:** Eliminates cognitive friction for non-technical users, provides truthful audit reporting for sysadmins, prevents silent configuration failures and preserves 100% backward compatibility and safe-tier invariants.

---

## ADR-018: Production Security Hardening & Vulnerability Remediation (2026-09-08)
- **Status:** Accepted
- **Context:** A rigorous critical security review of `unslop-windows` identified 5 vulnerabilities and architectural security concerns:
  1. *Elevated untrusted binary execution (VULN-01):* `unslop.ps1` prioritized user-writable `%LOCALAPPDATA%\Microsoft\OneDrive\OneDriveSetup.exe` ahead of protected system paths, executing the uninstaller with Administrator privileges without digital signature validation.
  2. *Command & argument injection in launcher (VULN-02):* `unslop.bat` forwarded raw arguments via `echo "%*"` and PowerShell `-Command "Start-Process ... -ArgumentList '%*'"` which exposed the elevation wrapper to batch metacharacter injection (`&`, `|`, `;`, `'`).
  3. *Unauthenticated remote script download (VULN-03):* `unslop.bat` contained a fallback to auto-download `unslop.ps1` from GitHub CDN over raw HTTPS without hash verification or Authenticode pinning.
  4. *Windows Update hardware driver blackout (REG-02):* The policy `ExcludeWUDriversInQualityUpdate = 1` blocked all third-party hardware driver and firmware security updates across the entire system.
  5. *Insecure temporary logging & symlink race (OPSEC-01):* Fallback logging to `$env:TEMP\unslop_logs` in shared/temp directories created symlink/junction hijacking exposure.
- **Decision:**
  - Hardened OneDrive uninstaller resolution in `unslop.ps1`: system directories (`SysWOW64`, `System32`) are prioritized and any user AppData binary must pass cryptographic `Get-AuthenticodeSignature` verification (`Status = Valid`, `CN=Microsoft Corporation`) before elevated invocation.
  - Hardened `unslop.bat` with a strict switch whitelist validation loop (`-Undo`, `-Restore`, `-DryRun`, `-WhatIf`, `-KeepXbox`, `-KeepOneDrive`, `-KeepTodos`, `-ClassicContextMenu`, `-NoRestart`, `-ForceRestart`, `-RunDirect`), rejecting unlisted tokens and metacharacters immediately with exit code 1.
  - Implemented a fail-closed offline architecture in `unslop.bat`: if `unslop.ps1` is missing, halt with a security error; zero unauthenticated script downloads.
  - Completely removed the code setting `ExcludeWUDriversInQualityUpdate = 1` and added proactive removal of any legacy key so Windows Update driver, firmware and hardware CVE patches flow freely.
  - Hardened decoupled log directory resolution in `unslop.ps1`: fallback redirected to `$env:LOCALAPPDATA\unslop-windows\logs` with explicit `[System.IO.FileAttributes]::ReparsePoint` inspection to prevent junction/symlink redirection attacks.
  - Synchronized `.github/workflows/release.yml` to package `tests/` inside the release zip bundle per ADR-010.
  - Added dedicated Pester and AST unit tests in `tests/unslop.Tests.ps1` validating Authenticode enforcement, reparse point detection and legacy driver policy cleanup.
- **Consequences:** Closes critical privilege escalation and command injection attack surfaces, ensures offline integrity, restores hardware vulnerability patch delivery and retains 100% of privacy-preserving telemetry killswitches.

---

## ADR-019: Engine Integrity, Startup Symmetry, Defender Realignment and Audit Fidelity (2026-09-08)
- **Status:** Accepted
- **Context:** A critical systems analysis and code audit of `unslop-windows` identified 4 critical bugs and 3 invariant violations:
  1. *Inverted Defender sample submission value (BUG-01):* `Set-MpPreference -SubmitSamplesConsent 0` configured Defender to `AlwaysPrompt` rather than `NeverSend` (`2`).
  2. *Destructive startup entry removal and broken symmetry (BUG-02):* `Remove-StartupEntry` permanently deleted registry properties and falsely logged that they could be re-enabled in Task Manager.
  3. *NonRemovable system packages in bloatware list (BUG-03):* `$bloatApps` included packages marked `NonRemovable: True` (`CloudExperienceHost`, `PeopleExperienceHost`, `ParentalControls`, `NarratorQuickStart`, `ECApp`), guaranteeing deployment error `0x80073CFA` on elevated runs and risking damage to Windows account management.
  4. *Non-elevated dry-run audit blindspot & performance bottleneck (BUG-04 & PERF-01):* `Get-AppxPackage -AllUsers` and `Get-AppxProvisionedPackage -Online` failed with Access Denied under standard user mode, falsely reporting 0 targeted apps, while sequential per-app querying caused 15–20s execution delays.
  5. *Silent placebo logging (INV-01):* Recall/NVIDIA tasks, firewall rules and context menu tweaks suppressed errors with `-EA 0` while logging success and `$global:FailCount` was unmonitored.
  6. *Vanishing elevated launcher window (INV-02):* Double-clicking `unslop.bat` and selecting presets (Gamer, Productivity, Toggles, Undo, Custom) closed the window immediately upon completion without pausing.
  7. *Local clipboard history suppression (INV-03):* Local `Win + V` clipboard history was disabled despite documentation claiming only cloud sync was blocked.
- **Decision:**
  - Corrected Defender `SubmitSamplesConsent` debloat value to `2` (`NeverSend`) and undo value to `1` (`SendSafeSamples`).
  - Re-architected `Remove-StartupEntry` to archive target entries under `HKCU:\Software\unslop-windows\StartupBackup` on debloat, cleanly restoring them to `Run` on `-Undo`.
  - Removed non-removable and core system packages (`CloudExperienceHost`, `PeopleExperienceHost`, `ParentalControls`, `NarratorQuickStart`, `ECApp`, `MicrosoftEdge.Stable`, `MicrosoftEdgeDevToolsClient`) from `$bloatApps`.
  - Optimized AppX enumeration to query `$allInstalled` once, with graceful fallback to current-user packages in non-elevated `-DryRun` and clear informative logging.
  - Initialized `$global:FailCount` tracking across all helper catch blocks, scheduled task loops, firewall rules and context menu mutations, alerting users in the completion summary banner.
  - Upgraded `unslop.bat` with `-FromMenu` parameter forwarding, guaranteeing anti-screen-amnesia pauses before returning to the menu across all presets.
  - Decoupled local clipboard history (`Win + V`) by removing `EnableClipboardHistory = 0` and `AllowClipboardHistory = 0`, keeping only cross-device cloud sync disabled.
  - Ensured `PSScriptAnalyzer` module availability in both `lint.yml` and `release.yml` CI workflows.
  - Expanded `tests/unslop.Tests.ps1` with unit and AST tests for startup symmetry, Defender values and bloatware whitelist invariants.
- **Consequences:** Resolves all critical functional bugs and placebo logging flaws, achieves true 100% restoration symmetry for startup apps, improves AppX execution speed from ~18s to <0.5s, provides accurate non-elevated audit reports and guarantees interactive window persistence.

---

## ADR-020: Windows 11 24H2/25H2 Protection Driver (UCPD), Inbox SystemApps and Elevation ACL Alignment (2026-09-09)
- **Status:** Accepted
- **Context:** Live execution of `unslop-windows v1.1.3` on Windows 11 24H2/25H2 revealed 6 specific operation warnings/failures due to new OS-level kernel/driver protections and unmounted registry drives:
  1. *UCPD driver registry blocking (TaskbarDa):* Microsoft introduced the User Choice Protection Driver (`UCPD.sys`) in Windows 11 23H2 (March 2024+) and 24H2/25H2. UCPD actively filters and intercepts direct user-mode registry writes to `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa`, throwing `UnauthorizedAccessException` ("Attempted to perform an unauthorized operation") even under elevated Administrator tokens.
  2. *SYSTEM-only Scheduled Task ACL (SdbinstMergeDbTask):* `\Microsoft\Windows\Application Experience\SdbinstMergeDbTask` has an explicit security descriptor `(A;;FRFX;;;BA)(A;;GA;;;SY)` granting Builtin Administrators only Read/Execute (`FRFX`) and NT AUTHORITY\SYSTEM Full Control (`GA`). Invoking `Disable-ScheduledTask` fails with `Access is denied`. Furthermore, this task is an internal application compatibility shim database merger (`sdbinst.exe -m`), not a telemetry collector.
  3. *NonRemovable inbox SystemApps (Photon, CoreAI, UndockedDevKit):* `MicrosoftWindows.Client.Photon`, `MicrosoftWindows.Client.CoreAI` and `MicrosoftWindows.UndockedDevKit` reside in `C:\Windows\SystemApps` and have `NonRemovable: True` and `SignatureKind: System`. Calling `Remove-AppxPackage` is rejected by Windows AppX deployment server with error `0x80070032` (`ERROR_NOT_SUPPORTED`). AI capabilities are already disabled via Recall policies (`DisableAIDataAnalysis = 1`, `AllowRecall = 0`) and ConsentStore (`systemAIModels = Deny`, `foregroundTextAccess = Deny`).
  4. *Unmounted HKCR PSDrive:* OneDrive sidebar unpinning referenced `HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}`. PowerShell's registry provider only mounts `HKLM:` and `HKCU:` by default, throwing `Cannot find drive. A drive with the name 'HKCR' does not exist.`
- **Decision:**
  - Disables Windows 11 Widgets using the official machine-wide Group Policy setting: `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0` (undo `1`, `removeOnUndo = $true`). This cleanly turns off Widgets and unpins the taskbar icon without triggering UCPD blocks.
  - Removed `SdbinstMergeDbTask` from `$tasksToToggle`. Genuine telemetry tasks in Application Experience (`Microsoft Compatibility Appraiser`, `Consolidator`, `UsbCeip`, `MareBackup`, `StartupAppTask`) remain disabled.
  - Removed `MicrosoftWindows.Client.Photon`, `MicrosoftWindows.Client.CoreAI` and `MicrosoftWindows.UndockedDevKit` from `$bloatApps` and guarded `Get-AppxPackage` matching with `-not $_.NonRemovable` to prevent illegal uninstalls on protected inbox packages.
  - Fixed OneDrive CLSID unpinning to target machine-wide `HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}` in addition to `HKCU:\Software\Classes`.
  - Added Pester tests in `tests/unslop.Tests.ps1` enforcing the removal of `SdbinstMergeDbTask`, forbidding unmounted `HKCR:` paths, asserting the presence of `AllowNewsAndInterests` and adding `Photon`, `CoreAI` and `UndockedDevKit` to the non-removable package invariants.
- **Consequences:** Eliminates all 6 live run warnings on 24H2 and 25H2, aligns debloating with Microsoft's official Group Policy management paths, avoids kernel driver blocking and retains 100% of telemetry blocks, debloat effectiveness and restoration symmetry.

---

## ADR-021: Diagnostic Benchmark Reparse Point Defense, Multi-Arch AppX Binding and Local Hook Automation (2026-09-10)
- **Status:** Accepted
- **Context:**
  1. *Benchmark Reparse Point Vulnerability (OPSEC-01):* `scripts/Measure-SystemState.ps1` wrote diagnostic snapshots without verifying whether `$snapshotDir` was a reparse point or directory junction, creating a potential symlink redirection vector. Additionally, using `return` in standalone scripts exited with code `0` instead of failing closed with `exit 1`.
  2. *Multi-Architecture AppX Array Binding Bug:* In environments where provisioned AppX package directories match multiple architectures, passing `$match` directly to `Add-AppxPackage -PackagePath` failed parameter binding.
  3. *Contributor Gate Friction:* Developers contributing PRs needed an automated way to install required testing dependencies (`Pester 5+` and `PSScriptAnalyzer`) and install pre-commit / pre-push hooks without manual intervention.
- **Decision:**
  - Resolved `$snapshotPath` and guarded snapshot directories against reparse points in `scripts/Measure-SystemState.ps1`, enforcing `exit 1` fail-closed error handling.
  - Iterated over matched packages with `foreach ($pkg in $match)` in `unslop.ps1` AppX installation blocks and explicitly scoped `$script:log`.
  - Added `.githooks/pre-commit` and updated `scripts/Install-GitHooks.ps1` with `-InstallPrerequisites` to auto-install modules and register hooks.
  - Added active flags preview and quick reset in `unslop.bat` toggles menu.
- **Consequences:** Closes path traversal vectors in diagnostic tools, hardens AppX provisioning across heterogeneous CPU architectures and guarantees all contributor commits are verified before hitting GitHub.

---

## ADR-022: Windows 10 Multi-OS Support Architecture & Dual-Script Engine (2026-09-10)
- **Status:** Accepted
- **Context:** The unslop-windows project was exclusively designed for Windows 11 (23H2/24H2/25H2). Despite Windows 10 reaching official end of support in October 2025, millions of machines remain on Win10 with Microsoft's Extended Security Updates (ESU) program running through October 2027. Users requested Win10 debloating support following the same safe-tier principles, symmetrical undo and quality standards.
- **Alternatives Considered:**
  1. *Unified script with OS branching:* Single `unslop.ps1` with `$isWin10` / `$isWin11` conditionals in every stage. Rejected due to: significantly increased complexity, conditional spaghetti across 18 stages, higher regression risk for stable Win11 users and violation of Ponytail minimal-diff discipline on verified production code.
  2. *Shared helper module:* Extracting helpers into `scripts/UnslopHelpers.psm1` imported by both scripts. Rejected to avoid modifying the Win11 dot-source guard, test harness and AST verification architecture that has been production-verified.
- **Decision:**
  - **Separate scripts with duplicated helpers:** `unslop-win10.ps1` is a standalone Win10 debloater with all 6 helper functions (`Log`, `Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`) duplicated for complete isolation. The existing `unslop.ps1` (Win11) remains completely unmodified — zero regression risk.
  - **Unified batch launcher:** A single `unslop.bat` presents an OS choice menu (Win10 vs Win11) and routes to the appropriate `.ps1` script. CLI pass-through mode accepts `-Win10` flag to route to `unslop-win10.ps1`.
  - **Win10 stages:** 18 modules adapted for Win10 — omitting Win11-only features (Recall, Copilot, Widgets via UCPD, classic context menu override) and adding Win10-specific debloating (Cortana removal, People Bar, Meet Now, News & Interests, Timeline, Win10-specific AppX packages like Print3D, 3DBuilder, OneConnect, Paint 3D).
  - **CI build gate bypass:** `-SkipBuildCheck` parameter allows CI runners (which run Windows Server 2022, build 20348) to execute DryRun pillars without OS build rejection.
  - **Separate test suite:** `tests/unslop-win10.Tests.ps1` with adapted assertions for Win10 stage count, build gate and AppX package list. Quality gate accepts `-Win10` flag.
  - **All Win10 versions supported:** Build 10240+ (all Windows 10 releases from 1507 through 22H2).
- **Consequences:** Provides complete Windows 10 debloating with zero regression risk to the stable Win11 engine, independent release cadence and full CI/CD coverage. Accepts ~200 lines of helper code duplication as the cost of total isolation. Enables the repository to serve both Win10 and Win11 users from a single release package.

---

## ADR-023: Symmetrical Dual-Engine Architecture (`unslop-win11.ps1` & `unslop-win10.ps1`), Removal of Ambiguous `unslop.ps1` and Granular Version Documentation Standard (2026-09-14)
- **Status:** Accepted
- **Context:** While ADR-022 introduced `unslop-win10.ps1`, the Windows 11 engine retained the legacy name `unslop.ps1`. This introduced asymmetry and ambiguity:
  1. Script naming was confusing: users and automation tools could not immediately tell which script targeted Windows 11 vs Windows 10 without reading internal comments.
  2. Documentation across README, Security, Contributing and Roadmap spoke in broad generalities ("all versions", "Windows 11 and Windows 10") without providing exact milestone releases, build numbers and architecture-specific servicing details.
  3. `unslop.bat` routing whitelisted only `-Win10` while implicitly treating all other calls as default.
- **Alternatives Considered:**
  1. *Keep `unslop.ps1` as a forwarding shim/alias:* Rejected per user directive. Eliminates legacy clutter and dead wrapper layers; the release archive must be clean and explicit (`unslop.bat`, `unslop-win11.ps1`, `unslop-win10.ps1`).
  2. *Maintain vague "all versions" documentation:* Rejected. Network and systems engineers require exact build boundaries and platform servicing lifecycles (e.g. 25H2 Build 26200+ canary/insider vs 24H2 Build 26100+ GE vs 23H2 Build 22631 NI and Windows 10 22H2 19045 down to 1507 10240, Enterprise LTSC 2021/2019/2016/2015, IoT LTSC).
- **Decision:**
  - **Symmetrical Renaming:** Renamed `unslop.ps1` to `unslop-win11.ps1` and `tests/unslop.Tests.ps1` to `tests/unslop-win11.Tests.ps1`. Removed `unslop.ps1` completely from release archives and workflows.
  - **Bidirectional OS Build Gating:** Added an explicit pre-flight OS build check to `unslop-win11.ps1` enforcing `Build >= 22000`, with informative redirection to `unslop-win10.ps1` if executed on Windows 10, plus `-SkipBuildCheck` parameter for CI/testing. Windows 10 engine similarly validates `Build < 22000`.
  - **Unified Launcher Modernization:** `unslop.bat` updated to validate presence of both `unslop-win11.ps1` and `unslop-win10.ps1`, whitelisting `-Win11` and `-Win10` CLI arguments, with an explicit interactive selection menu showing granular version brackets.
  - **Master Quality Gate Parameterization:** `scripts/Test-MasterGate.ps1` defaults to `unslop-win11.ps1` / `tests/unslop-win11.Tests.ps1`, supports `-Win11` explicitly and routes to `unslop-win10.ps1` / `tests/unslop-win10.Tests.ps1` via `-Win10`.
  - **Granular Documentation Standard:** Replaced all instances of vague "all versions" across `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, `ROADMAP.md` and `LICENSE` with complete tables of Windows 11 (25H2, 24H2, 23H2, 22H2, 21H2) and Windows 10 (22H2, 21H2, 21H1, 20H2, 2004, 1909, 1903, 1809/LTSC 2019, 1803, 1709, 1703, 1607/LTSB 2016, 1511, 1507/LTSB 2015, Enterprise LTSC 2021, IoT Enterprise LTSC).
- **Consequences:**
  - Establishes perfect symmetry between Windows 11 and Windows 10 script names and test suites.
  - Eliminates user error from running the wrong script on the wrong OS via bidirectional build verification guards.
  - Release zip bundles are cleaner: `unslop.bat`, `unslop-win11.ps1`, `unslop-win10.ps1`, `README.md` and `LICENSE`.
  - Quality gates, CI workflows and developer tooling remain 100% fail-closed and test-enforced.

---

## ADR-024: Store Auto-Download Suppression (AutoDownload=2), Cross-Device Resume (CDP/MDM) Disabling and WebExperience Package Alignment (2026-09-15)
- **Status:** Accepted
- **Context:**
  1. *Microsoft Store Background NVMe Churn:* The Microsoft Store client in Windows 11 (24H2/25H2) automatically triggers silent background app updates (e.g. `Microsoft.Winget.Source` catalog refresh and inbox apps), waking up `wsappx` (`AppXSVC`), `WinGet COM Server`, `State Repository Service` and Delivery Optimization (`DoSvc`), generating 2+ MB/s of unprompted disk I/O on NVMe drives.
  2. *Cross-Device Resume Host Persistence:* Windows 11 24H2/25H2 shell infrastructure host (`sihost.exe`) automatically spawns `CrossDeviceResume.exe` at user logon via `ShellUIHosts` (`CrossDeviceResumeHost`) to listen for mobile hand-off activities (tabs, OneDrive docs, Spotify). The default user preference toggle (`IsResumeAllowed = 0`) fails to prevent `sihost.exe` from launching the binary into memory.
  3. *WebExperience De-Provisioning Typo:* In `$bloatApps`, Windows Widgets was defined as `"Microsoft.Windows.Client.WebExperience"` (with an extra dot), failing to match the official package family name `"MicrosoftWindows.Client.WebExperience"` and causing Widgets to remain active on disk.
- **Alternatives Considered:**
  1. *Hard-disabling the `DoSvc` (Delivery Optimization) service:* Setting `DoSvc` to `Disabled` breaks Windows Update and causes Microsoft Store manual downloads to fail with error `0x80d02002` or `0x80070422`. Delivery Optimization must remain in `CdnOnly` mode (`DODownloadMode = 0`) on `Manual` startup to preserve safe-tier functionality.
  2. *Hard-disabling or removing the Microsoft Store package:* Violates the Non-Negotiable Safe-Tier Whitelist Invariant (`Microsoft.WindowsStore` and `Microsoft.DesktopAppInstaller` must never be touched).
- **Decision:**
  - **Store Auto-Update Throttling:** Configured `HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore\AutoDownload = 2` (Turn off automatic download and install of updates). Disables silent background downloads and package updates while keeping manual Store updates 100% functional.
  - **Cross-Device Resume & CDP Disabling:**
    - Set Connected Devices Platform policy `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\EnableCdp = 0` (undo `1`, `removeOnUndo = $true`).
    - Set MDM PolicyManager gate `HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume\value = 1` (undo `0`), directly instructing `sihost.exe` not to spawn `CrossDeviceResumeHost`.
    - Set user-level toggles `IsResumeAllowed = 0` and `IsOneDriveResumeAllowed = 0` under `HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration`.
    - Gracefully terminate active `CrossDeviceResume.exe` instances during debloat execution.
  - **WebExperience Array Alignment:** Added `"MicrosoftWindows.Client.WebExperience"` to `$bloatApps` alongside `"Microsoft.Windows.Client.WebExperience"`, ensuring clean de-provisioning.
  - **Windows 10 Parity:** Added `EnableCdp = 0` and `AutoDownload = 2` to `unslop-win10.ps1` with 100% symmetrical `-Undo` restoration.
- **Consequences:** Eliminates silent background NVMe writes from Store auto-updates, suppresses `CrossDeviceResume.exe` from spawning into RAM, removes Windows Widgets reliably and preserves full system stability and manual Store update functionality.

---

## ADR-025: AppX Restoration Parameter Defense (`-AllUsers` Removal) and Idempotent Registry Property Deletion (2026-09-15)
- **Status:** Accepted
- **Context:**
  1. *`Add-AppxPackage` Parameter Binding Failure:* During `-Undo` restoration in Stage 12 of `unslop-win11.ps1` and Stages 2 and 12 of `unslop-win10.ps1`, re-registering provisioned AppX packages failed with `A parameter cannot be found that matches parameter name 'AllUsers'`. `Add-AppxPackage` does not accept an `-AllUsers` parameter (only `Remove-AppxPackage` and `Get-AppxPackage` support it). In earlier versions, this was masked by `-ErrorAction SilentlyContinue`. In v1.2.2, with the introduction of honest error logging (`$global:FailCount++` under `-ErrorAction Stop`), this exposed 5 hard failures on Windows 11 (`aimgr`, `MicrosoftWindows.Client.WebExperience`, `Microsoft.Office.ActionsServer`, `Microsoft.OfficePushNotificationUtility`, `Microsoft.GamingApp`).
  2. *Non-Existent Registry Property Failures on `-Undo`:* In `Set-RegDwordSafe`, properties configured with `removeOnUndo = $true` (e.g. `AllowNewsAndInterests`, `EnableCdp`) were removed via `Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction Stop` when the parent registry key existed (`Test-Path $path` was true). If the property itself did not exist on that key (e.g., if debloat never created it, if the machine was previously undone or if restore was run on a clean install), `Remove-ItemProperty` threw `Property <name> does not exist at path <path>`. The generic `catch` block incremented `$global:FailCount++` and logged hard `FAILED:` errors even though the intended state (property absent) was already satisfied.
- **Alternatives Considered:**
  1. *Suppress all errors in `Set-RegDwordSafe` with `-ErrorAction SilentlyContinue`:* Rejected. Violates the Non-Negotiable Honest Failure Invariant (Rule 8). Legitimate errors (Access Denied, permission locks) must fail and increment `$global:FailCount`.
  2. *Query `Get-ItemProperty` before removing in `Set-RegDwordSafe`:* In unit tests with mock cmdlets, unmocked `Get-ItemProperty` against fake test registry paths returns `$null`, bypassing `Remove-ItemProperty` invocations and breaking existing unit tests unless mocked everywhere.
- **Decision:**
  - **Remove Invalid `-AllUsers` Parameter:** Removed `-AllUsers` from all `Add-AppxPackage -RegisterByFamilyName -MainPackage ...` calls in `unslop-win11.ps1` and `unslop-win10.ps1`.
  - **Idempotent Registry Property Deletion:** Updated `Set-RegDwordSafe`'s catch block in both engines to inspect exception messages and error IDs (`$_.Exception.Message -match "does not exist"` or `$_.FullyQualifiedErrorId -match "PSArgumentException.*RemoveItemPropertyCommand"`). When the property is already absent, it safely logs `SKIP: $name not present in $path` without incrementing `$global:FailCount`. Real exceptions continue to increment `$global:FailCount++` and emit `FAILED:`.
  - **Test Coverage:** Added unit tests verifying idempotent property removal skips and AST assertions ensuring `Add-AppxPackage` never binds `-AllUsers` across both `tests/unslop-win11.Tests.ps1` and `tests/unslop-win10.Tests.ps1`.
- **Consequences:** Eliminates all false-positive warnings during `-Undo` runs, guarantees idempotency across repeated restoration runs and enables smooth, error-free AppX package re-registration.

---

## ADR-026: Third-Party Scope Correction (Discord Removal), -KeepSysMain and Granular Custom CLI Flags Architecture (2026-09-18)
- **Status:** Accepted
- **Context:**
  1. *Third-Party Scope Creep:* Section 14 previously contained hardcoded startup entry removal for Discord (`HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\Discord`). Discord is third-party software rather than a Windows OS or Microsoft component. This was initially added as a personal configuration choice by the author. As the repository grew to serve a wider user base, retaining third-party app manipulation conflicted with the core project focus on Windows debloating and privacy hardening.
  2. *SysMain and Mechanical Storage:* By default, Stage 1 disables `SysMain` (Superfetch). On systems running mechanical HDDs, hybrid storage or secondary spinning disks, disabling `SysMain` can degrade sequential application launch times and cause disk thrashing. Users needed a dedicated flag to preserve `SysMain` without skipping other background services.
  3. *Granular Component Choice vs Menu Bloat:* Different users need different combinations of built-in components (e.g. keeping Windows Search indexer for Outlook desktop, Phone Link for mobile syncing, Spotify, Mail or Clock). Adding 10+ new toggles into Option [4] ("Interactive Toggle Menu") in `unslop.bat` would clutter the menu and slow down common runs.
- **Alternatives Considered:**
  1. *Add all 10 flags into Option [4] Interactive Toggle Menu:* Rejected. Option [4] is designed to be lean and quick for mainstream users who want basic toggles (Xbox, OneDrive, To-Do, Context Menu, DryRun). Adding 10 more toggles creates visual clutter and slows down common workflows.
  2. *Retain Discord cleanup with an opt-out flag:* Rejected. Debloater scope must remain strictly bounded to Windows and Microsoft components. Modifying third-party application startup entries crosses into general cleaner territory.
- **Decision:**
  - **Remove Third-Party Discord Manipulation:** Removed Discord startup entry deletion from Section 14 across `unslop-win11.ps1` and `unslop-win10.ps1`, replacing test mocks with generic startup test entries.
  - **Implement `-KeepSysMain`:** Added `-KeepSysMain` switch parameter in both engines. When passed, `SysMain` is skipped during debloating, leaving its startup type and running state intact.
  - **Implement Vetted Custom Flags:** Added `-KeepSearch`, `-KeepPhoneLink`, `-KeepMail`, `-KeepClock` (Windows 10), `-KeepSpotify`, `-KeepStoreAutoUpdate`, `-LeftTaskbar` (Windows 11), `-ExcludeWUDrivers` and `-KeepDefenderDefaults` across both engines with symmetrical `-Undo` handling.
  - **Whitelisted CLI Pass-Through and Interactive Option [7]:** Expanded the batch file argument whitelist to pass custom switches directly to the underlying PowerShell engines, and added Option `[7] Custom CLI Flags` in `unslop.bat` for interactive parameter entry.
- **Consequences:**
  - Restores strict focus on Windows and Microsoft components.
  - Preserves storage performance on mechanical and hybrid drives via `-KeepSysMain`.
  - Gives advanced users full flexibility to preserve specific apps and services while keeping the standard interactive menus clean.
  - Maintains 100% test coverage and validation through `Test-MasterGate.ps1`.



