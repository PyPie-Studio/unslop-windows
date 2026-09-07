---
name: unslop-agent-workflow
description: Antigravity AI pair programming procedures, plan-first discipline for architectural shifts, direct execution for verified tasks, Ponytail minimal-diff discipline, and SemVer release management.
---

# unslop-agent-workflow

This skill governs the Antigravity AI agent workflow, engineering philosophy, and release discipline for **unslop-windows**.

---

## 🧘 Pair Programming Principles

### 1. Ponytail Minimal-Diff Discipline
- **Standard Library First:** Always leverage PowerShell built-in cmdlets (`Test-Path`, `Get-ItemProperty`, `Set-ItemProperty`, `Get-Service`) rather than spawning external binaries (`reg.exe`, `sc.exe`, `net.exe`) or installing modules.
- **Shortest Working Solution:** Eliminate unnecessary abstractions, wrapper functions, or speculative complexity.
- **Zero New Dependencies:** Maintain strict zero third-party dependency stance. Do not introduce packages, node scripts, or compiled binaries.

### 2. Planning vs. Direct Execution Discipline
- **Create an Implementation Plan** for:
  - New debloating or hardening modules.
  - Changes affecting the reboot lifecycle, UAC elevation, or batch launcher contract.
  - Large refactoring across multiple files.
  - Architectural framework modifications.
- **Execute Directly** without planning for:
  - Minor documentation updates, bug fixes, typo fixes, or syntax corrections.
  - Adding a known registry key to an existing module with symmetrical `-Undo`.
  - Running quality gate or verification tests.

### 3. Direct Verification Standard
- **Never Declare Success Prematurely:** Never claim an issue is resolved or a feature is complete without executing verification commands.
- Run `scripts/Test-MasterGate.ps1` before staging commits.
- Confirm files exist and have correct line endings on disk.

---

## 🏷 Release & Versioning Workflow (Mandatory Post-Verification Rule)

After **every verified change** made to the codebase (confirmed clean by `Test-MasterGate.ps1`), the agent must immediately execute the release sequence so the repository is continuously up to date:

1. **Version Alignment:**
   - Bump version header and log strings in [`unslop.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.ps1).
   - Bump version string in [`unslop.bat`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/unslop.bat) (maintain CRLF).
   - Bump download links and ASCII menu in [`README.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/README.md).
2. **Changelog Maintenance:**
   - Add a new version block with current date in [`CHANGELOG.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CHANGELOG.md).
   - Document all Added, Changed, Fixed, and Security items following Keep a Changelog standard.
   - Update comparison links at the bottom of the changelog.
3. **Master Gate Verification:**
   - Run `pwsh -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1`.
4. **Git Commit, Tag & Push:**
   - Stage all files: `git add .`
   - Commit changes: `git commit -m "feat/fix(...): <summary>"`
   - Create annotated tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z: <summary>"`
   - Push to origin: `git push origin main --tags` (triggers automated GitHub Actions release build).
