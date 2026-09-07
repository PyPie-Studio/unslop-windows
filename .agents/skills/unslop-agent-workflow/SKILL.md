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

## 🏷 Release & Versioning Workflow

When releasing a new version of `unslop-windows`:

1. **Version Alignment:**
   - Update `$version` variable in `unslop.ps1`.
   - Update version string in `unslop.bat` header.
2. **Changelog Maintenance:**
   - Add a new version block with current date in [`CHANGELOG.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CHANGELOG.md).
   - Document all Added, Changed, Fixed, and Security items following Keep a Changelog standard.
3. **Roadmap Sync:**
   - Update [`ROADMAP.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/ROADMAP.md) milestones.
4. **Master Gate Verification:**
   - Run `pwsh -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1`.
5. **Git Tag & GitHub Release:**
   - Commit changes: `git commit -m "chore(release): vX.Y.Z"`
   - Create annotated tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
   - Push to origin: `git push origin main --tags`
   - Publish release notes via GitHub CLI: `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`
