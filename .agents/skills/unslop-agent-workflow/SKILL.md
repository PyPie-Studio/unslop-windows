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

### What Triggers a Version Bump & Tagged Release
Version bumps, changelog entries, annotated tags, and GitHub Releases are reserved for **verified code changes** — meaning changes to files that contain executable logic:
- `unslop.ps1`, `unslop.bat` (core engine and launcher)
- `scripts/*.ps1` (quality gate, benchmarking, git hooks)
- `tests/*.ps1` (Pester unit tests)
- `.github/workflows/*.yml` (CI/CD pipelines)
- `PSScriptAnalyzerSettings.psd1` (static analysis rules)

**Release sequence** (only for code changes confirmed clean by `Test-MasterGate.ps1`):
1. **Version Alignment:** Bump version in `unslop.ps1` (header + log banner), `unslop.bat` (menu banner), and `README.md` (download links + ASCII menu).
2. **Changelog:** Add a new version block with current date in `CHANGELOG.md` following Keep a Changelog standard.
3. **Master Gate:** Run `pwsh -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1`.
4. **Commit, Tag & Push:** `git add .` → `git commit -m "feat/fix(...): <summary>"` → `git tag -a vX.Y.Z -m "..."` → `git push origin main --tags`.

### What Does NOT Trigger a Version Bump
Documentation-only changes get committed and pushed directly — **no version bump, no tag, no release**:
- `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `ROADMAP.md`
- `AGENTS.md`, `SKILLS.md`, `.agents/skills/**/*.md`
- `docs/*.md` (decisions, benchmarks)
- `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE.md`
- `.gitignore`, `.gitattributes`, `.editorconfig`

Commit these with a `docs(...)` or `chore(...)` conventional commit and push to `main` without tagging.
