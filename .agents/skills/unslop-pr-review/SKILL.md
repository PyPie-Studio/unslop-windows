---
name: unslop-pr-review
description: Procedures, inspection checklists, and automation playbooks for critically reviewing, hardening, testing, and merging pull requests on unslop-windows.
---

# unslop-pr-review: Pull Request Inspection & Hardening Standard

This skill establishes the mandatory review protocols, safety checklists, and operational workflows for auditing and merging pull requests on **unslop-windows** — whether submitted by human contributors or automated coding agents (e.g., Jules, Bolt, Palette, Sentinel).

---

## 🎯 Core Philosophy & Ground Rules

1. **Zero-Advisory Invariant**: If a PR introduces a bugfix, security rule, or policy change, it **must not merge** without an automated test in [`tests/unslop.Tests.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/tests/unslop.Tests.ps1) or [`scripts/Test-MasterGate.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-MasterGate.ps1).
2. **Reject the "Green-Light Illusion"**: Passing CI does not mean edge cases are covered. Happy-path mocks often mask real-world failures. Reviewers must scrutinize negative paths, parameter bindings, exception trapping, and elevation boundaries.
3. **Zero-Clutter Repository Root**: Automated agents frequently generate markdown scratchpads or bot logs. PR branches must be scrubbed of all foreign artifacts before merging.
4. **Fix Directly, Then Merge**: When a PR has high merit but small defects (formatting, unneeded bot files, missing tests, array binding bugs), fix them directly on the PR branch rather than bikeshedding in comment threads.

---

## 🔍 The 7-Pillar PR Audit Checklist

Every incoming PR must pass all 7 audit checks before approval and merging:

### 1. Git Hygiene & Bot Artifact Depuration
- **Inspect Git Root**: Search for rogue bot workspace files (`.jules/`, `.Jules/`, `.copilot/`, `.cursor/`, scratchpad markdown files).
- **Windows Case Collision Defense**: Watch out for case-variant directories (e.g., `.jules` vs. `.Jules`). On Windows NTFS (case-insensitive by default), this can create git index collisions and clone corruptions.
- **Action**: Delete all bot notes and unneeded files from the PR branch (`git rm -r .jules`).

### 2. Safe-Tier & 100% Symmetrical Restoration Invariants
- **WinSxS & DISM Inviolability**: Verify the PR NEVER invokes `dism /cleanup-image /resetbase` or deletes files in `C:\Windows\WinSxS`.
- **Untouchable Whitelist**: Ensure Microsoft Store (`Microsoft.WindowsStore`), App Installer (`Microsoft.DesktopAppInstaller`), and Xbox Identity Provider (`Microsoft.XboxIdentityProvider`) are not removed or disabled.
- **Universal Mutating AST Audit**: State mutations (`Set-ItemProperty`, `Remove-ItemProperty`, `Set-Service`, `Disable-ScheduledTask`, `Remove-AppxPackage`) must strictly route through approved bidirectional helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`). Naked mutating cmdlets outside helpers are strictly forbidden.

### 3. Script Execution Context & Exit Code Contracts
- **Standalone Script Exit Trap**: In PowerShell, calling `return` at the root of a standalone script file (`scripts/*.ps1`) exits with code `0`.
- **Security Tripwire Enforcement**: Any security violation, reparse point trap, or validation failure in standalone utility scripts must call `exit 1` to ensure CI pipelines and parent processes fail closed.
- **Reparse Point Path Resolution Order**: When validating directories against symlinks or directory junctions, **always resolve the path first**:
  ```powershell
  $fullPath = [System.IO.Path]::GetFullPath($targetPath)
  $dirInfo = New-Object System.IO.DirectoryInfo($fullPath)
  if ($dirInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      exit 1 # Fail closed immediately
  }
  ```
  Checking attributes before resolving paths allows relative path traversal bypasses.

### 4. System & Runtime Boundary Edge Cases
- **Multi-Architecture AppX Array Traps**: When searching provisioned package directories or AppX databases on machines with multi-arch installations (e.g., x64 + ARM64 / x86), path resolution can return an array of strings. Passing an array directly to `-PackagePath` throws a parameter binding exception. Always iterate over matches:
  ```powershell
  foreach ($pkg in $match) {
      Add-AppxPackage -PackagePath $pkg.FullName ...
  }
  ```
- **Log Buffer Variable Scoping**: Helper functions writing to shared buffers must explicitly scope to the script/global level (`$script:log += ...`) to prevent log drops across dot-sourced or nested scopes.

### 5. Batch Launcher Fragility & CRLF Integrity
- **CRLF Invariant**: All `*.bat` files MUST use Windows CRLF (`\r\n`) line endings. Naked LFs (`\n`) corrupt `cmd.exe` parentheses block parsing and cause syntax crashes.
- **CLI Argument Whitelisting**: `unslop.bat` must never pass unsanitized arguments (`%*`) into dynamic shell strings. Every switch must pass through the token whitelist loop.
- **Interactive Anti-Screen-Amnesia**: Any elevated execution initiated from the batch console menu must pass `-FromMenu` to pause upon completion before returning to the menu.

### 6. Failure Honesty & Negative Error Trapping
- **No Silent Placebo Logging**: Operations must NEVER suppress errors with `-ErrorAction SilentlyContinue` while logging success text.
- **Failure Counters**: Operations must trap exceptions inside `try/catch`, emit `FAILED: <details>` logs, and increment `$global:FailCount++`.

### 7. Dual-Runtime Local Verification
- PRs must execute cleanly under both:
  - **Windows PowerShell 5.1 Desktop Edition**
  - **PowerShell 7+ Core (`pwsh`)**
- All 36+ Pester unit tests and Dry-Run passes must achieve 100% pass rate (0 failures, 0 skips).

---

## 🛠 Step-by-Step PR Review & Merge Playbook

Follow this precise sequence when reviewing and merging open PRs:

### Step 1: List and Inspect Open PRs
```bash
# List all open pull requests
gh pr list

# View PR diff and summary
gh pr view <PR_NUMBER>
gh pr diff <PR_NUMBER>
```

### Step 2: Check Out the PR Branch
```bash
gh pr checkout <PR_NUMBER>
```

### Step 3: Audit & Scrub the Branch
1. Check for rogue bot artifacts (`.jules/`, `.copilot/`):
   ```powershell
   if (Test-Path .jules) { git rm -r .jules }
   if (Test-Path .Jules) { git rm -r .Jules }
   ```
2. Check for naked mutating cmdlets or array-binding bugs in modified files.
3. Check for proper exit codes (`exit 1` instead of `return` in standalone scripts).
4. Verify CRLF integrity on modified batch scripts.

### Step 4: Run the Local Master Quality Gate in Strict Mode
```powershell
# Run with Windows PowerShell 5.1
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Strict

# Run with PowerShell 7 Core
pwsh -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Strict
```
*Never proceed to merge if any pillar fails or is skipped.*

### Step 5: Commit and Push Branch Fixes
If you made corrections or purged bot artifacts:
```bash
git add -A
git commit -m "fix(pr-review): scrub bot artifacts and resolve edge case issues"
git push
```

### Step 6: Verify Remote CI Checks
Wait for GitHub Actions workflows to pass on the PR branch:
```bash
gh pr checks <PR_NUMBER>
```
Ensure all required jobs (`PSScriptAnalyzer`, `Quality Gate PS 7`, `Quality Gate PS 5.1`) report `pass`.

### Step 7: Squash and Merge with Branch Deletion
Merge the PR using a standardized conventional commit subject:
```bash
gh pr merge <PR_NUMBER> --squash --delete-branch --subject "<type>(<scope>): <clear description of change>"
```

### Step 8: Sync Local `main` and Prune Tracking Branches
```bash
git checkout main
git pull origin main
git fetch --prune origin
```

### Step 9: Verify Local Tree Cleanliness
```bash
git status
git branch -a
```
Confirm that no orphan local branches or deleted remote branches remain.

---

## 📋 Fast Review Triage Matrix

| PR Type | Priority Checks | Mandatory Tests |
| :--- | :--- | :--- |
| **Engine / Registry (`unslop.ps1`)** | Helper routing, 100% `-Undo` symmetry, non-elevated `-DryRun` check, whitelist preservation | AST parity test, helper unit mock |
| **Batch Launcher (`unslop.bat`)** | CRLF line endings, argument whitelist loop, anti-screen-amnesia (`-FromMenu`), UAC elevation error handling | Headless batch audit (Pillar 7) |
| **Diagnostic Scripts (`scripts/`)** | Reparse point symlink check, `exit 1` fail-closed exit contract, absolute path resolution | Reparse point unit mock test |
| **CI / Workflows (`.github/`, `.githooks/`)** | Module installation logic (`Pester 6+`, `PSScriptAnalyzer`), strict failure rules, runner matrix | Dual-runtime local gate |
| **Documentation (`*.md`)** | Clean document routing (ADRs in `decisions.md`, features in `README.md`), Ponytail minimal-diff discipline | Line-ending and conflict audit |
