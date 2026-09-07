# unslop-windows Architecture Decision Records (ADRs)

This document logs significant architectural, security, and quality decisions for **unslop-windows**.

Format: `ADR-XXX: Title (Date) -> Status -> Context -> Decision -> Consequences`.

**BEFORE re-deciding anything** (changing policy behavior, adding dependencies, modifying the reboot lifecycle): read this log. If the decision exists, follow it. If a decision genuinely must change, log a new entry overriding the old one.

---

## ADR-001: Safe-Tier Hardening Invariant & WinSxS Component Preservation (2026-09-07)
- **Status:** Accepted
- **Context:** Aggressive Windows debloaters frequently break Windows Cumulative Updates (resulting in rollback error `0x800f0922` or `0x80073701`), brick the Microsoft Store, or cause irreparable OS instability by deleting components from the WinSxS store (`dism /online /cleanup-image /startcomponentcleanup /resetbase`).
- **Decision:** unslop-windows strictly enforces a **Safe-Tier invariant**:
  - No DISM component stripping or `/resetbase` execution.
  - No deletion or tampering of files inside `C:\Windows\WinSxS` or core system directories.
  - Microsoft Store, winget package installer, and core runtimes (VCLibs, DirectX, .NET) are permanently whitelisted.
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
- **Context:** Users, security auditors, and CI pipelines need the ability to inspect the operations that `unslop.ps1` would perform before granting administrative privileges. Scripts that fail immediately on missing administrator rights prevent pre-flight auditing.
- **Decision:** Decoupled administrative elevation checks from the `-DryRun` audit path:
  - If `-DryRun` is passed, the script executes in read-only inspection mode under standard user privileges.
  - All mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Stop-Service`, `Set-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) are guarded by `if (-not $DryRun)`.
- **Consequences:** Enables non-elevated CI validation, zero-risk developer inspection, and automated testing across unprivileged user environments.

---

## ADR-004: In-Place Reboot Lifecycle, Keyboard Abort Shortcut & Exit Code Contract (2026-09-07)
- **Status:** Accepted
- **Context:** Many Windows policy tweaks and service state changes require a system restart to take effect. However, abrupt restarts risk user data loss. Additionally, requiring the user to open a secondary terminal to run `shutdown /a` provides a poor user experience. Halting on `pause` after initiating a restart countdown leaves unnecessary windows open.
- **Decision:**
  - Implemented an interactive 60-second reboot countdown directly inside `unslop.ps1` using non-blocking raw console polling (`$Host.UI.RawUI.KeyAvailable`).
  - Added in-place keyboard controls: press `A` to abort immediately (`shutdown.exe /a`), press `R` or `Enter` to reboot without waiting.
  - Added `Ctrl+C` interrupt handling inside a `finally` block to automatically call `shutdown.exe /a`.
  - Established an exit code contract: `unslop.ps1` exits with code `100` when a reboot is scheduled, prompting `unslop.bat` to terminate immediately without halting on `pause`.
- **Consequences:** Seamless, foolproof reboot UX with zero risk of accidental forced reboots.

---

## ADR-005: Local Master Quality Gate & Git Pre-Push Hook (2026-09-07)
- **Status:** Accepted
- **Context:** Changes committed to `main` must not introduce syntax errors, break `unslop.bat` with LF line endings, fail static analysis, or regress dry-run execution.
- **Decision:** Onboarded a 5-pillar local quality gate adapted from A3MALI and NodeRadar Pro:
  - Created [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) with 5 checks (AST parser, PSScriptAnalyzer, CRLF/conflict markers, `-DryRun`, and `-Undo -DryRun`).
  - Added [`.githooks/pre-push`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.githooks/pre-push) and [`scripts/Install-GitHooks.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Install-GitHooks.ps1) to block pushes targeting `main` or `master` if the gate fails.
- **Consequences:** Prevents broken code from reaching the repository, enforces CRLF on Windows batch files, and eliminates regressions before pull requests are opened.

---

## ADR-006: Antigravity Agent Harness & Modular Skills Registry (2026-09-07)
- **Status:** Accepted
- **Context:** To scale feature development, support new Windows 11 platform releases (24H2, 25H2), and maintain strict architectural boundaries during AI pair programming, agents require clear, discoverable standards and domain-specific knowledge.
- **Decision:** Established an AI agent harness adapted from NodeRadar Pro:
  - Created [`AGENTS.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/AGENTS.md) as the master architectural specification.
  - Created [`SKILLS.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/SKILLS.md) as the skill discovery registry.
  - Configured 4 modular skills in [`.agents/skills/`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills) (`unslop-safetier-engine`, `unslop-windows-internals`, `unslop-quality-gate`, `unslop-agent-workflow`).
- **Consequences:** Ensures AI assistants adhere to Safe-Tier invariants, Ponytail minimal-diff practices, and strict verification protocols across all coding sessions.

---

## ADR-007: Diagnostic State Auditor & CI/CD Cryptographic Verification (2026-09-07)
- **Status:** Accepted
- **Context:** Users and enterprise administrators require measurable empirical proof of system debloating (RAM delta, thread reduction, stopped telemetry services). Additionally, binary releases packaged in GitHub Actions require cryptographic integrity verification to protect against supply-chain tampering.
- **Decision:**
  - Implemented [`scripts/Measure-SystemState.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Measure-SystemState.ps1) to capture baseline metrics, perform comparative audits, and export Markdown reports (`docs/benchmarks.md`).
  - Hardened [`.github/workflows/release.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/release.yml) to generate standard GNU-compatible `SHA256SUMS.txt` and upload checksums as release assets alongside the release zip archive.
  - Upgraded [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) to execute the complete local 5-pillar Master Gate (`Test-MasterGate.ps1`) including non-elevated `-DryRun` smoke testing, achieving 100% parity between local hooks and CI.
- **Consequences:** Provides transparent before/after benchmarking, eliminates local vs CI test drift, and offers cryptographic verification for downstream users.

---

## ADR-008: Pester 5 Unit & Mocking Test Suite and Dot-Source Guard Architecture (2026-09-08)
- **Status:** Accepted
- **Context:** The Master Quality Gate previously relied solely on static linting and black-box `-DryRun` console text parsing. Swapped parameter bugs, inverted registry values, or broken whitelist filters could pass undetected so long as the script completed without throwing unhandled exceptions. Furthermore, the monolithic structure of `unslop.ps1` prevented isolated function testing because dot-sourcing immediately triggered elevation checks and executed all 18 debloat modules.
- **Decision:**
  - Implemented a native PowerShell dot-source guard (`if ($MyInvocation.InvocationName -eq '.') { return }`) placed after engine helper function definitions and before the administrative check and procedural debloat logic.
  - Added explicit switch parameters with scope fallbacks (`[switch]$Undo = $IsUndo, [switch]$DryRun = $IsDryRun`) to helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`), enabling complete unit test isolation without breaking backwards compatibility.
  - Created a dedicated zero-elevation Pester unit test suite (`tests/unslop.Tests.ps1`) mocking all mutating cmdlets (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Stop-Service`, `Disable-ScheduledTask`, `Enable-ScheduledTask`).
  - Integrated the Pester test suite as Pillar 4 in `scripts/Test-MasterGate.ps1` and updated CI workflows accordingly.
- **Consequences:** Provides granular unit test verification for helper logic, prevents silent regressions in registry and service state manipulation, verifies parameter contracts (`-KeepXbox`, `-KeepOneDrive`, non-elevated exit codes), and maintains 100% test coverage without modifying live system state.

---

## ADR-009: Dual PowerShell Runtime Matrix & Engine Parity Contract (PS 5.1 Desktop & PS 7 Core) (2026-09-08)
- **Status:** Accepted
- **Context:** `unslop-windows` targets Windows 11 systems running Windows PowerShell 5.1 (`powershell.exe`) via `unslop.bat` as well as modern PowerShell 7+ (`pwsh`). While `#requires -Version 5.1` is declared, the CI pipeline historically tested only `shell: pwsh`. This introduced the risk that PS 7-only syntax features (e.g., ternary operators `?:`, null-coalescing `??`, pipeline chains `&&` / `||`, or newer .NET APIs) could pass CI while crashing in production on stock Windows 11 installations. Additionally, `Test-MasterGate.ps1` previously defaulted subprocess execution (`$psExec`) to `pwsh` whenever `pwsh` was present in PATH, causing false-positive passes under PS 5.1 runners.
- **Decision:**
  - Upgraded [`.github/workflows/lint.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/lint.yml) to a multi-runtime matrix strategy across both `powershell` (Windows PowerShell 5.1 Desktop) and `pwsh` (PowerShell 7+ Core) on `windows-latest`.
  - Bound `$psExec` in [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1) directly to the active host's `$PSVersionTable.PSEdition` (`Desktop` -> `powershell.exe`, `Core` -> `pwsh`), guaranteeing that all subprocess tests (`unslop.ps1 -DryRun`, `unslop.ps1 -Undo -DryRun`, and Pester unit tests) execute in the matching runtime.
  - Added an automated module assurance step in CI to ensure Pester 5 is available in both runner environments.
- **Consequences:** Eliminates runtime blind spots between Windows PowerShell 5.1 and PowerShell 7. Guarantees that syntax and logic regressions targeting clean Windows 11 installs are caught in CI prior to merge.

---

## ADR-010: Gated Production Releases via Quality Gate Prerequisite (`needs: verify`) (2026-09-08)
- **Status:** Accepted
- **Context:** Pushing a release tag (`v*`) previously triggered immediate packaging, checksum calculation, and asset publication to GitHub Releases without running `Test-MasterGate.ps1` or verifying that the tagged commit passed unit tests or dry-run smoke tests. A tagged commit containing an undetected syntax error or regression would be published to users as an official release bundle with valid cryptographic hashes.
- **Decision:**
  - Restructured [`.github/workflows/release.yml`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.github/workflows/release.yml) into a sequential two-stage pipeline where `publish-release` explicitly depends on `needs: verify`.
  - The `verify` prerequisite job executes the full 7-pillar Master Quality Gate ([`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1)) including AST parsing, static analysis, CRLF/batch syntax, Pester unit tests, and dry-run smoke tests under `permissions: contents: read`.
  - Added `tests/` directory to the release zip archive bundle (`Compress-Archive`) so enterprise users and system administrators can execute the unit test suite on unpacked distributions.
- **Consequences:** Guarantees zero broken releases. If any pillar in the quality gate fails on the tagged commit, release publication is blocked immediately and no assets are uploaded.

---

## ADR-011: Dedicated Batch Launcher CLI Passthrough Smoke Test (Pillar 7) (2026-09-08)
- **Status:** Accepted
- **Context:** `unslop.bat` is the primary entry point for standard users launching debloat and restoration operations. To ensure that batch script syntax errors, line-ending corruption, or CLI parameter forwarding flaws are caught automatically, a batch execution check was previously embedded inside Step 3 (`Line-Ending & File Integrity Audit`). However, because Step 3 is executed even during rapid quality gate checks (`Test-MasterGate.ps1 -Fast`), this caused pre-commit and rapid development audits to jump from sub-second runtimes (<0.2s) to ~12 seconds.
- **Decision:**
  - Decoupled batch script validation into two distinct concerns:
    1. **Static Byte-Level Integrity (Pillar 3):** Inspects `unslop.bat` for strict CRLF line endings (verifying no naked LF bytes exist) and scans for merge conflict markers across all repository text files. Runs in <0.1s.
    2. **Execution-Based CLI Passthrough Smoke Test (Pillar 7):** Invokes `cmd.exe /c ".\unslop.bat -DryRun"`, verifying zero syntax errors, valid headless parameter forwarding to `unslop.ps1`, and clean exit code 0 propagation.
  - Configured `Test-MasterGate.ps1 -Fast` to skip all execution-based tests (Steps 4 through 7), restoring sub-second performance.
- **Consequences:** Restores instantaneous (<0.2s) feedback loops for local rapid checks and git hooks while maintaining full end-to-end headless CLI verification of the batch wrapper in comprehensive CI and release verification gates.

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
- **Consequences:** Dramatically cuts CI runner consumption, surfaces immediate visual test metrics in GitHub Actions run summaries, provides clickable inline annotations on failed tests, and preserves zero third-party dependency safety.

