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

### 4. Zero-Advisory Invariants & Anti-Green-Light-Illusion Discipline
- **No Advisory-Only Rules:** Never document an architectural policy or invariant in markdown without adding a corresponding automated test in `tests/unslop.Tests.ps1` or `Test-MasterGate.ps1`. If a rule lacks an automated assertion, it will inevitably be rationalized away or missed due to context attenuation.
- **Reject the Green-Light Illusion:** Never assume that a passing test gate means all edge cases are addressed. Happy-path mocks often mask underlying flaws. Always test negative paths (exception handling, `$global:FailCount` increments, non-elevated boundaries, and CLI injection bounds).

---

## 🏷 Release & Versioning Workflow

### Mandatory Versioning Rules
1. **Batch / Session Consolidation**: Group all code changes made during a task or conversation into **a single combined release**. Never create separate releases for intermediate bug fixes or individual commits while still troubleshooting.
2. **Decimal Roll-Over Invariant**: When a version reaches `x.y.9` (e.g., `1.0.9`), the next release rolls over to `x.(y+1).0` (e.g., `1.1.0`), and continues incrementally `1.1.1` through `1.1.9`. Never produce two-digit patch numbers (`.10`, `.11`, `.12`).

### What Triggers a Version Bump & Tagged Release
Version bumps, changelog entries, annotated tags, and GitHub Releases are reserved strictly for **verified code changes** at the conclusion of a work session:
- `unslop.ps1`, `unslop.bat` (core engine and launcher)
- `scripts/*.ps1` (quality gate, benchmarking, git hooks)
- `tests/*.ps1` (Pester unit tests)
- `.github/workflows/*.yml` (CI/CD pipelines)
- `PSScriptAnalyzerSettings.psd1` (static analysis rules)

**Release sequence** (executed ONCE at the end of the session):
1. **Version Alignment:** Bump version in `unslop.ps1` (header + log banner), `unslop.bat` (menu banner), and `README.md` (download links + ASCII menu).
2. **Changelog:** Add a consolidated version block with current date in `CHANGELOG.md` following Keep a Changelog standard.
3. **Master Gate:** Run `pwsh -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1`.
4. **Commit, Tag & Push:** `git add .` → `git commit -m "feat/fix(...): <summary>"` → `git tag -a vX.Y.Z -m "..."` → `git push origin main --tags`.

### What Does NOT Trigger a Version Bump
Documentation-only changes get committed and pushed directly — **no version bump, no tag, no release**:
- `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `ROADMAP.md`
- `AGENTS.md`, `SKILLS.md`, `.agents/skills/**/*.md`
- `docs/*.md` (decisions, benchmarks)
- `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE.md`
- `.gitignore`, `.gitattributes`, `.editorconfig`

Commit these with a `docs(...)` or `chore(...)` conventional commit and push directly to `main` without tagging.
