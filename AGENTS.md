# Antigravity Agent Harness: unslop-windows

Master guide and non-negotiable architectural standards for **unslop-windows** — a production-grade, safe-tier Windows 11 (23H2, 24H2, 25H2+) debloater, telemetry neutralizer, and privacy hardener written in pure PowerShell and Windows Batch.

---

## 🏗 System Architecture & Tech Stack

- **Target Platforms:** Windows 11 23H2 (Build 22631+), 24H2 (Build 26100+), 25H2 (Build 26200+), and future Insider preview branches.
- **Engine Architecture:**
  - [`unslop.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.ps1): Pure PowerShell 5.1 & PowerShell 7+ execution engine. Features 18 modular debloat and restoration stages, structured JSON/text logging (`.\logs\`), non-elevated read-only auditing (`-DryRun`), and 1-click restoration (`-Undo`).
  - [`unslop.bat`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.bat): Dual-mode launcher and UAC elevation wrapper. Auto-detects admin rights, enforces CRLF, invokes `unslop.ps1`, captures exit codes, and manages post-execution reboot lifecycle.
  - [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1): 5-pillar local quality gate (AST syntax, PSScriptAnalyzer, CRLF/conflict check, DryRun test, Undo DryRun test).
  - [`scripts/Install-GitHooks.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Install-GitHooks.ps1): Git hook orchestrator configuring `.githooks/pre-push`.
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
- When a debloat or restoration pass completes, a 60-second reboot countdown is initiated.
- The lifecycle must provide an in-place keyboard shortcut:
  - Press `A` to immediately abort the scheduled reboot (`shutdown.exe /a`).
  - Press `R` or `Enter` to reboot immediately without waiting.
  - Press `Ctrl+C` interrupt trapped safely in a `finally` block to cancel the restart.
- When a restart is scheduled, `unslop.ps1` must exit with code `100`, signaling `unslop.bat` to terminate immediately without halting on `pause`.

### 6. Code Quality, AST & Line-Ending Invariants
- `unslop.bat` and all batch scripts MUST maintain CRLF (`\r\n`) line endings. Naked LF causes `cmd.exe` block parsing corruption.
- All PowerShell scripts must pass AST syntax parsing (`[System.Management.Automation.Language.Parser]::ParseFile`) with 0 errors.
- All code must pass the Local Master Quality Gate (`scripts/Test-MasterGate.ps1`) before being pushed to `main`.

---

## 🛠 Active Workspace Skills ([`.agents/skills/`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills))

1. **[`unslop-safetier-engine`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-safetier-engine/SKILL.md):** Core debloater and hardening engine procedures, 18-module execution lifecycle, symmetry enforcement, registry tree manipulation, safe AppX package de-provisioning, service and task state transitions.
2. **[`unslop-windows-internals`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-windows-internals/SKILL.md):** Deep Windows 11 (23H2/24H2/25H2/26H2) internals, ConsentStore permissions, Recall (`DisableAIDataAnalysis`), Copilot policies, Defender SmartScreen balance, Windows Update invariants, and telemetry registry keys.
3. **[`unslop-quality-gate`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-quality-gate/SKILL.md):** Local quality gate (`scripts/Test-MasterGate.ps1`), AST verification, PSScriptAnalyzer integration, CRLF integrity, git hook pipeline (`.githooks/pre-push`), and dry-run execution testing.
4. **[`unslop-agent-workflow`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-agent-workflow/SKILL.md):** Antigravity pair programming guidelines for unslop-windows, direct execution, plan-first for architectural shifts, Ponytail minimal-diff discipline (prefer PowerShell stdlib/built-in cmdlets, zero extra dependencies), and release versioning discipline.

---

## 🚀 Essential Commands

```powershell
# Run safe non-elevated dry-run inspection
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -DryRun

# Run full local Master Quality Gate (AST + Analyzer + CRLF + DryRun + Undo)
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1

# Run rapid quality gate (AST + Analyzer + CRLF only)
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Fast

# Install or test Git pre-push hook
powershell -ExecutionPolicy Bypass -File .\scripts\Install-GitHooks.ps1 -Test

# Execute debloater with administrative elevation (apply tweaks)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1

# Execute symmetrical restoration (undo all tweaks)
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -Undo
```

---

## 📄 Architectural Decisions Log
All major design decisions, invariant rules, and trade-offs are permanently tracked in [`docs/decisions.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/docs/decisions.md). Review before modifying existing core behavior.
