---
name: unslop-quality-gate
description: Local Master Quality Gate (scripts/Test-MasterGate.ps1), 5-pillar verification, fast mode, and Git pre-push hook management (.githooks/pre-push).
---

# unslop-quality-gate

This skill governs the local quality gate and Git hook verification pipeline for **unslop-windows**.

---

## 🏛 The 5 Verification Pillars

Every change to the repository must satisfy `scripts/Test-MasterGate.ps1`:

1. **[1/5] AST Syntax & Parser Verification:**
   - Uses `[System.Management.Automation.Language.Parser]::ParseFile` on all `.ps1`, `.psm1`, and `.psd1` files.
   - Requires zero parse errors.
2. **[2/5] Static Code Analysis (PSScriptAnalyzer):**
   - Scans scripts for errors and warnings using `Invoke-ScriptAnalyzer`.
   - Requires 0 `Error` severity violations.
   - Gracefully skips if the module is not installed locally.
3. **[3/5] Line-Ending & File Integrity Audit:**
   - Validates that `unslop.bat` uses CRLF (`\r\n`) line endings (preventing `cmd.exe` block parsing errors).
   - Scans all text files for lingering Git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
4. **[4/5] Safe Non-Elevated Dry-Run Execution Test:**
   - Executes `pwsh -File .\unslop.ps1 -DryRun` to ensure all 18 modules run end-to-end without throwing exceptions in user mode.
   - Verifies standard completion banner.
5. **[5/5] Symmetrical Restoration Dry-Run Execution Test:**
   - Executes `pwsh -File .\unslop.ps1 -Undo -DryRun` to verify inverse restoration logic runs cleanly.
   - Verifies restore completion banner.

---

## ⚡ Execution Modes

```powershell
# Full 5-pillar gate (recommended before git commit / git push):
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1

# Rapid gate (steps 1-3 only; executes in < 0.2s):
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Fast

# Gate with analyzer bypassed:
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -SkipAnalyzer
```

---

## 🪝 Git Hooks Pipeline

The pre-push hook ([`.githooks/pre-push`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.githooks/pre-push)) guards `main` and `master` branches against broken pushes:

- **Activation:** Run `powershell -ExecutionPolicy Bypass -File .\scripts\Install-GitHooks.ps1 -Test`
- **Fallback Synchronization:** `Install-GitHooks.ps1` sets `core.hooksPath .githooks` and copies the hook into `.git/hooks/pre-push`.
- **Pre-Push Behavior:** Reads incoming push refs from standard input. If `refs/heads/main` or `refs/heads/master` is targeted, it runs `Test-MasterGate.ps1`. If any pillar fails, Git rejects the push.
