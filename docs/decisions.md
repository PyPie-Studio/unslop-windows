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
