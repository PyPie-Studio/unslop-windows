# unslop-windows Agent Skills Registry

This document outlines the specialized skills configured for the **unslop-windows** debloater and privacy hardening suite. These skills are discovered from [`.agents/skills/`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills) and provide domain-specific knowledge, invariant guardrails, and procedures for the Antigravity AI Agent.

---

## 🛠 Active Skills Registry

| Skill Name | Scope | Key Capabilities & Purpose |
| :--- | :--- | :--- |
| **[`unslop-safetier-engine`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-safetier-engine/SKILL.md)** | `unslop.ps1`, `unslop.bat` | Core Safe-Tier debloater execution engine, 18-module execution lifecycle, strict 100% symmetrical `-Undo` restoration contract, defensive registry manipulation, safe AppX de-provisioning, privilege boundary defenses (Authenticode verification, batch argument token whitelisting, symlink/junction guard), and service/task transitions. |
| **[`unslop-windows-internals`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-windows-internals/SKILL.md)** | Windows 11 OS Policies | Deep Windows 11 internals across 23H2 (22631), 24H2 (26100), and 25H2 (26200). ConsentStore privacy capabilities, Recall snapshot policies, Copilot suppression, telemetry endpoints, Cumulative Update invariants, hardware driver & firmware CVE patch preservation, and intentional privacy hardening boundaries. |
| **[`unslop-quality-gate`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-quality-gate/SKILL.md)** | `scripts/`, `.githooks/` | Master Quality Gate (`scripts/Test-MasterGate.ps1`), 7-pillar verification (AST syntax, PSScriptAnalyzer, CRLF audit, Pester unit tests & code coverage, non-elevated DryRun, symmetrical Undo DryRun, and Batch launcher passthrough), fast mode, and Git pre-push hook management (`.githooks/pre-push`). |
| **[`unslop-agent-workflow`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-agent-workflow/SKILL.md)** | Workflow & Pair Programming | Antigravity AI pair programming procedures: plan-first for architectural changes, direct execution for verified tasks, Ponytail minimal-diff discipline (PowerShell stdlib first, zero external dependencies), and SemVer release management. |

---

## 📌 Skill File Locations

| Skill | Path |
| :--- | :--- |
| `unslop-safetier-engine` | [`.agents/skills/unslop-safetier-engine/SKILL.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-safetier-engine/SKILL.md) |
| `unslop-windows-internals` | [`.agents/skills/unslop-windows-internals/SKILL.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-windows-internals/SKILL.md) |
| `unslop-quality-gate` | [`.agents/skills/unslop-quality-gate/SKILL.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-quality-gate/SKILL.md) |
| `unslop-agent-workflow` | [`.agents/skills/unslop-agent-workflow/SKILL.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.agents/skills/unslop-agent-workflow/SKILL.md) |

---

## 🔗 Related Configuration

- **Master Harness & Architectural Guardrails:** [`AGENTS.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/AGENTS.md)
- **Architectural Decision Records (ADRs):** [`docs/decisions.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/docs/decisions.md)
- **Local Master Quality Gate:** [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1)
- **Git Hooks Installer:** [`scripts/Install-GitHooks.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Install-GitHooks.ps1)
- **Contributing Guidelines:** [`CONTRIBUTING.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CONTRIBUTING.md)
