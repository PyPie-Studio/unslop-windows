# Antigravity Agent Harness: unslop-windows

Master guide and non-negotiable architectural standards for **unslop-windows** — a production-grade, safe-tier Windows 11 (23H2, 24H2, 25H2+) debloater, telemetry neutralizer, and privacy hardener written in pure PowerShell and Windows Batch.

---

## 🏗 System Architecture & Tech Stack

- **Target Platforms:** Windows 11 23H2 (Build 22631+), 24H2 (Build 26100+), 25H2 (Build 26200+), and Windows 10 (all versions, Build 10240 through 19045 22H2).
- **Engine Architecture:**
  - [`unslop.ps1`](file:///d:/Programming/unslop-windows/unslop.ps1): Pure PowerShell 5.1 & PowerShell 7+ execution engine for Windows 11. Features 18 modular debloat and restoration stages, structured JSON/text logging (`.\logs\`), non-elevated read-only auditing (`-DryRun`), and 1-click restoration (`-Undo`).
  - [`unslop-win10.ps1`](file:///d:/Programming/unslop-windows/unslop-win10.ps1): Standalone execution engine for Windows 10 (Build 10240+). Features Cortana complete purge, People bar/Meet Now/News & Interests suppression, Win10-adapted AppX de-provisioning, and 100% symmetrical restoration.
  - [`unslop.bat`](file:///d:/Programming/unslop-windows/unslop.bat): Unified dual-mode launcher and UAC elevation wrapper. Interactive OS selection menu (Win10 vs Win11), auto-detects admin rights, enforces CRLF, captures exit codes, and supports `-Win10` CLI pass-through.
  - [`scripts/Test-MasterGate.ps1`](file:///d:/Programming/unslop-windows/scripts/Test-MasterGate.ps1): 7-pillar local quality gate (AST syntax, PSScriptAnalyzer, CRLF/conflict check, Pester unit tests & code coverage, DryRun test, Undo DryRun test, Batch launcher passthrough audit). Supports `-Win10` and `-SkipBuildCheck` flags.
  - [`PSScriptAnalyzerSettings.psd1`](file:///d:/Programming/unslop-windows/PSScriptAnalyzerSettings.psd1): Version-controlled static analysis ruleset enforcing security and code quality standards across local and CI environments.
  - [`tests/unslop.Tests.ps1`](file:///d:/Programming/unslop-windows/tests/unslop.Tests.ps1): Pester 6+ unit, mocking & static AST parity test suite for Windows 11.
  - [`tests/unslop-win10.Tests.ps1`](file:///d:/Programming/unslop-windows/tests/unslop-win10.Tests.ps1): Pester 6+ unit, mocking & static AST parity test suite for Windows 10.
  - [`scripts/Install-GitHooks.ps1`](file:///d:/Programming/unslop-windows/scripts/Install-GitHooks.ps1): Git hook orchestrator configuring `.githooks/pre-push`.
- **Zero Third-Party Dependencies:** Zero compiled `.exe` or `.dll` binaries, zero third-party packages, zero cloud API dependencies. All operations rely strictly on native Win32 APIs, Windows Registry hives (`HKCU`, `HKLM`), AppX cmdlets, and built-in service controllers.

---

## ⚡ Non-Negotiable Safe-Tier Engineering Guardrails

### 1. DISM & WinSxS Inviolability (Zero Broken Updates)
- **NEVER** touch, purge, or modify the WinSxS component store (`C:\Windows\WinSxS`).
- **NEVER** execute destructive DISM component cleanups (`dism /online /cleanup-image /startcomponentcleanup /resetbase`).
- **NEVER** rip core Windows feature manifests. Violating this rule causes Cumulative Update installation failures with error `0x800f0922` or `0x80073701`.
- Bloatware AppX packages must be de-provisioned cleanly via `Remove-AppxPackage` and `Remove-AppxProvisionedPackage` without deleting system image manifests.

### 2. Microsoft Store & Critical Runtimes Whitelist
- The Microsoft Store (`Microsoft.WindowsStore`), App Installer (`Microsoft.DesktopAppInstaller` / `winget`), and Xbox Identity Provider (`Microsoft.XboxIdentityProvider`) MUST NEVER be removed or disabled.
- Essential system runtimes, including VCLibs, DirectX runtimes, and .NET Native frameworks, are strictly protected.

### 3. 100% Symmetrical Restoration (`-Undo` Contract)
- **Mandatory Symmetry:** Every single registry modification, service state change, or scheduled task disablement in `unslop.ps1` MUST have an exact inverse operation implemented in the `if ($Undo)` branch.
- If a hardening step writes a registry value (e.g. `Set-ItemProperty ... -Value 1`), the `-Undo` routine must either revert the value to its Windows default or delete the property/key if it was custom-created.
- If a service is set to `Disabled`, `-Undo` must restore it to `Manual` or `Automatic`.
- Never leave an orphaned tweak that cannot be undone in a single run of `.\unslop.ps1 -Undo`.

### 4. Non-Elevated `-DryRun` Auditing Safety
- `.\unslop.ps1 -DryRun` MUST run successfully in standard, non-elevated user mode without prompting for UAC elevation and without throwing access denied errors.
- Every state-mutating command (`Set-ItemProperty`, `Remove-ItemProperty`, `Stop-Service`, `Set-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) must be gated by `if (-not $DryRun)` checks.
- Audit inspection logs must accurately reflect what actions would be performed.

### 5. Reboot Lifecycle & Abort Safety
- When a debloat or restoration pass completes, the user is presented with an interactive confirmation prompt (`Initiate 30-second restart countdown? [Y/n]`):
  - Press `n` to postpone the restart and exit immediately without rebooting.
  - Press `Enter` or `Y` to initiate the 30-second countdown.
- During the active 30-second countdown, the lifecycle provides in-place keyboard shortcuts:
  - Press `A` to immediately abort the scheduled reboot (`shutdown.exe /a`).
  - Press `R` or `Enter` to reboot immediately without waiting.
  - Press `Ctrl+C` interrupt trapped safely in a `finally` block to cancel the restart.
- When `-ForceRestart` is passed, the confirmation prompt and countdown are bypassed and the machine reboots immediately (`shutdown /r /t 0`).
- When a restart is scheduled or triggered, `unslop.ps1` must exit with code `100`, signaling `unslop.bat` to terminate immediately without halting on `pause`.

### 6. Code Quality, AST & Line-Ending Invariants
- `unslop.bat` and all batch scripts MUST maintain CRLF (`\r\n`) line endings. Naked LF causes `cmd.exe` block parsing corruption.
- All PowerShell scripts must pass AST syntax parsing (`[System.Management.Automation.Language.Parser]::ParseFile`) with 0 errors.
- All code must pass the Local Master Quality Gate (`scripts/Test-MasterGate.ps1`) before being pushed to `main`.

### 7. Release & Versioning Policy
- **Batch / Session Consolidation**: If making code changes or debugging issues during a conversation or task, **group all changes together**. Do NOT cut individual releases or version bumps for each micro-commit or intermediate bugfix. Only bump the version, tag, and trigger a release **once at the end of the session** when all changes are verified and complete.
- **Decimal Roll-over Rule**: Versions follow a strict single-digit patch roll-over. When a version reaches `x.y.9` (e.g. `1.0.9`), the next bump rolls to `x.(y+1).0` (e.g. `1.1.0`), and continues incrementally `1.1.1` up to `1.1.9`. Never produce two-digit patch versions like `.10`, `.11`, or `.12`.
- **Code Changes Only**: Version bumps and tags are strictly reserved for verified changes to executable code (`*.ps1`, `*.bat`, `*.yml`, `*.psd1`).
- **Documentation-Only Changes**: Edits to documentation (`*.md`, `.gitignore`, `.editorconfig`, issue templates) do NOT trigger a version bump, changelog update, tag, or release. Commit with `docs(...)` or `chore(...)` and push directly.

### 8. Terminal UI/UX, Dynamic Reporting & Failure Honesty Invariants
- **No Silent Placebo Logging**: NEVER suppress mutation failures with `-ErrorAction SilentlyContinue` while logging success text. All state-mutating operations (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) must execute with `-ErrorAction Stop` inside `try/catch`. On exception, emit explicit `FAILED: <details>` logs and increment failure counters (`$global:FailCount++`) so terminal and file logs remain truthful.
- **Dynamic Summary Invariant**: Completion summary banners must dynamically reflect the active parameter flags (e.g. `-KeepXbox`, `-KeepOneDrive`, `-KeepTodos`, `-ClassicContextMenu`) and explicitly flag preview mode when `-DryRun` is active. Summary banners must strictly retain the exact gate assertion tokens required by `scripts/Test-MasterGate.ps1` (`UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE` and `RESTORE / UNDO COMPLETE`).
- **Signal-to-Noise Ratio (AppX Condensation)**: Repetitive non-events (such as 40+ uninstalled AppX packages) must be condensed into an aggregate summary (e.g., `SKIP: X packages not installed`) rather than flooding the console with line-by-line clutter.
- **Batch Launcher UI Invariants**:
  - Interactive multi-select toggles must be supported in `unslop.bat` via dedicated sub-menus (`:toggles`) using pure batch flag state tracking (`[ ON  ]` / `[ OFF ]`).
  - UAC elevation calls (`Start-Process ... -Verb RunAs`) must check `%errorlevel%` to prevent silent terminal window termination when UAC is dismissed or cancelled by the user.
  - Audit mode (`unslop.bat [3] Dry Run`) must pause before clearing the console or returning to the main menu ("anti-screen-amnesia").

### 9. Security & Privilege Boundary Invariants
- **User-Space Elevated Binary Execution (VULN-01 / LPE Defense)**: Elevated scripts must NEVER blindly invoke executables located in user-writable paths (`$env:LOCALAPPDATA`, `$env:USERPROFILE`, `$env:TEMP`). Prioritize machine-wide system directories (`C:\Program Files`, `C:\Windows\System32`). If a user-profile executable must be invoked (e.g. legacy user-scoped OneDrive uninstaller), verify its cryptographic integrity via `Get-AuthenticodeSignature` (`Status -eq 'Valid'`, publisher matching authorized vendor like `*Microsoft Corporation*`) before spawning.
- **Batch CLI Argument Whitelisting (VULN-02 / Injection Defense)**: In batch elevation wrappers and launchers (`unslop.bat`), NEVER pass raw CLI arguments (`%*`, `!ARGS!`) directly into dynamic shell strings or PowerShell `-Command "Start-Process ... -ArgumentList '%*'"` without strict token whitelist validation. Unfiltered arguments allow command chaining and batch injection. Loop through `%*` and whitelist only known safe switches.
- **Fail-Closed Offline Architecture (VULN-03 / Zero Script Fetching)**: `unslop-windows` is strictly offline-first. Scripts and batch launchers must NEVER attempt ad-hoc network downloads (`Invoke-RestMethod`, `Invoke-WebRequest`, `curl`) to pull missing code or dependencies. If companion files are missing, fail closed immediately with an informative error.
- **Hardware Security & Driver Patch Inviolability (REG-02)**: Debloating and telemetry reduction must never break hardware CVE mitigation or firmware updates. Never set `ExcludeWUDriversInQualityUpdate = 1` as part of general debloating. Any legacy policy setting must be actively cleaned up to preserve driver and microcode CVE patches delivered via Windows Update.
- **Reparse Point / Junction Guard (OPSEC-01)**: When initializing logging, backup, or output directories in user or temporary profiles, always inspect `[System.IO.FileAttributes]::ReparsePoint`. Refuse or remove reparse points/junctions before writing files to prevent redirection attacks targeting arbitrary system paths.
- **Intentional Privacy Hardening vs Bloat Invariants (REG-01, REG-03, REG-04)**: Hardening features that disable Cloud Sample Submission (`SubmitSamplesConsent = 2`), disable Windows Error Reporting telemetry dumps (`Disabled = 1`, `DontSendAdditionalData = 1`), or block MDM/diagnostic telemetry egress via outbound Windows Firewall rules are intentional safe-tier debloat/privacy invariants and must NOT be removed or weakened.

### 10. The Zero-Advisory Invariant & Test-Driven Enforcement Principle
- **No Advisory-Only Rules**: A policy or safety constraint must NEVER exist solely as markdown prose. Any invariant written in `AGENTS.md`, `decisions.md`, or skills MUST have a corresponding automated test in `tests/unslop.Tests.ps1` or `scripts/Test-MasterGate.ps1`. If it is not tested, it is an aspiration, not an invariant.
- **Universal Mutating AST Audit**: State mutations (`Set-ItemProperty`, `Remove-ItemProperty`, `Disable-ScheduledTask`, `Enable-ScheduledTask`, `Set-Service`, `Stop-Service`, `Start-Service`) must NEVER appear as naked cmdlets in procedural script blocks. They must strictly route through approved bidirectional helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`) that guarantee 100% `-Undo` symmetry and truthful failure logging (`$global:FailCount++`).
- **Fail-Closed Tooling & CI Gate**: CI workflows and strict local checks (`-Strict`) must fail closed with exit code 1 if `PSScriptAnalyzer` or `Pester 6` is absent. Never allow graceful `SKIPPED` fallbacks in automated gates.
- **Interactive Batch Validation Standard**: Changes to `unslop.bat` must be validated against both headless CLI execution (`cmd.exe /c "unslop.bat -DryRun"`) AND interactive menu elevation paths (`Start-Process -FilePath '%~f0' -Verb RunAs`), ensuring screens never vanish upon completion.

### 11. Documentation Co-Evolution & Clean Routing Standard
- **Co-Evolution Mandate:** Whenever code changes alter features, telemetry rules, test gates, or safety boundaries, documentation MUST be updated in the same session. Code and documentation must never drift out of sync.
- **Zero-Bloat Discipline:** Follow Ponytail minimal-diff discipline for prose. Avoid conversational padding, redundant summaries, and duplicated paragraphs across files. Keep documentation dense, factual, and high signal-to-noise.
- **Strict Documentation Routing Map:** Route each update strictly to its corresponding document:
  - **[`README.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/README.md)**: User-facing capabilities only (features, 18 modules, untouchable whitelist table, comparison matrix, quickstart, CLI options). Do NOT put developer gate internals, AST details, or ADR rationale here.
  - **[`CHANGELOG.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CHANGELOG.md)**: User and developer release history organized by SemVer tags under Keep a Changelog categories (`Fixed`, `Added`, `Changed`, `Security`).
  - **[`CONTRIBUTING.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CONTRIBUTING.md)**: Open-source developer standards, non-negotiable PR rules, test commands, and quality gate instructions.
  - **[`ROADMAP.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/ROADMAP.md)**: High-level milestone tracking and strategic feature checkboxes (`[x]`).
  - **[`docs/decisions.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/docs/decisions.md)**: Architectural Decision Records (ADRs). Permanent record of problem context, design alternatives, trade-offs, and rationale.
  - **[`AGENTS.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/AGENTS.md)** & **Skills ([`.agents/skills/`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills))**: AI agent execution invariants, non-negotiable system standards, automated testing mandates, and deep OS internals.

---

## 🛠 Active Workspace Skills ([`.agents/skills/`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills))

1. **[`unslop-safetier-engine`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-safetier-engine/SKILL.md):** Core debloater and hardening engine procedures, 18-module execution lifecycle, symmetry enforcement, registry tree manipulation, safe AppX package de-provisioning, service and task state transitions.
2. **[`unslop-windows-internals`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-windows-internals/SKILL.md):** Deep Windows 11 (23H2/24H2/25H2/26H2) internals, ConsentStore permissions, Recall (`DisableAIDataAnalysis`), Copilot policies, Defender SmartScreen balance, Windows Update invariants, and telemetry registry keys.
3. **[`unslop-quality-gate`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-quality-gate/SKILL.md):** Local quality gate (`scripts/Test-MasterGate.ps1`), AST verification, PSScriptAnalyzer integration, CRLF integrity, git hook pipeline (`.githooks/pre-push`), and dry-run execution testing.
4. **[`unslop-agent-workflow`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-agent-workflow/SKILL.md):** Antigravity pair programming guidelines for unslop-windows, direct execution, plan-first for architectural shifts, Ponytail minimal-diff discipline (prefer PowerShell stdlib/built-in cmdlets, zero extra dependencies), and release versioning discipline.
5. **[`unslop-pr-review`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-pr-review/SKILL.md):** Pull request inspection checklists and merge playbooks: bot clutter scrub (`.jules/`), safe-tier AST symmetry audit, exit code contracts (`exit 1` vs `return`), symlink traversal guards, AppX multi-architecture array bindings, and batch CRLF verification.

---

## 🚀 Essential Commands

```powershell
# Run safe non-elevated dry-run inspection
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -DryRun

# Run full local Master Quality Gate (AST + Analyzer + CRLF + Pester + DryRun + Undo + Batch)
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1

# Run Master Quality Gate and export Pester results to NUnit XML & JaCoCo Code Coverage
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -TestResultsPath "test-results\pester.xml" -CodeCoveragePath "test-results\coverage.xml"

# Run rapid quality gate (AST + Analyzer + CRLF only)
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Fast

# Run Windows 10 Master Quality Gate
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Win10 -SkipBuildCheck

# Install or test Git pre-push hook
powershell -ExecutionPolicy Bypass -File .\scripts\Install-GitHooks.ps1 -Test

# Execute Windows 11 debloater with administrative elevation
powershell -ExecutionPolicy Bypass -File .\unslop.ps1

# Execute Windows 11 symmetrical restoration
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -Undo

# Execute Windows 10 debloater with administrative elevation
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1

# Execute Windows 10 symmetrical restoration
powershell -ExecutionPolicy Bypass -File .\unslop-win10.ps1 -Undo
```

---

## 📄 Architectural Decisions Log
All major design decisions, invariant rules, and trade-offs are permanently tracked in [`docs/decisions.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/docs/decisions.md). Review before modifying existing core behavior.
