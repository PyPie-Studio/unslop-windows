---
name: unslop-quality-gate
description: Local Master Quality Gate (scripts/Test-MasterGate.ps1), 7-pillar verification, fast mode, and Git pre-push hook management (.githooks/pre-push).
---

# unslop-quality-gate

This skill governs the local quality gate and Git hook verification pipeline for **unslop-windows**.

---

## 🏛 The 7 Verification Pillars

Every change to the repository must satisfy `scripts/Test-MasterGate.ps1`:

1. **[1/7] AST Syntax & Parser Verification:**
   - Uses `[System.Management.Automation.Language.Parser]::ParseFile` on all `.ps1`, `.psm1`, and `.psd1` files.
   - Requires zero parse errors.
2. **[2/7] Static Code Analysis (PSScriptAnalyzer):**
   - Scans scripts for errors and warnings using `Invoke-ScriptAnalyzer`.
   - Binds to version-controlled [`PSScriptAnalyzerSettings.psd1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/PSScriptAnalyzerSettings.psd1) when present.
   - Requires 0 `Error` severity violations.
   - Gracefully skips if the module is not installed locally.
3. **[3/7] Line-Ending & File Integrity Audit:**
   - Validates that `unslop.bat` uses CRLF (`\r\n`) line endings (preventing `cmd.exe` block parsing errors).
   - Scans all text files for lingering Git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
4. **[4/7] Pester Unit, Mocking & AST Symmetry Suite (`tests/unslop.Tests.ps1`):**
   - Dot-sources `unslop.ps1` via the non-elevated dot-source guard.
   - Verifies helper functions (`Set-RegDwordSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`) with mock assertions.
   - Validates parameter flags (`-KeepXbox`, `-KeepOneDrive`) and non-elevated exit code contracts.
   - Executes static AST parity analysis asserting 100% Symmetrical Restoration Contract invariants (zero naked mutating cmdlets, mandatory debloat & undo value pairs, valid service recovery types).
   - Supports native JaCoCo code coverage instrumentation via `-CodeCoveragePath`.
5. **[5/7] Safe Non-Elevated Dry-Run Execution Test:**
   - Executes `pwsh -File .\unslop.ps1 -DryRun` to ensure all 18 modules run end-to-end without throwing exceptions in user mode.
   - Verifies standard completion banner.
6. **[6/7] Symmetrical Restoration Dry-Run Execution Test:**
   - Executes `pwsh -File .\unslop.ps1 -Undo -DryRun` to verify inverse restoration logic runs cleanly.
   - Verifies restore completion banner.
7. **[7/7] Batch Launcher CLI Parameter Passthrough Audit:**
   - Executes `cmd.exe /c ".\unslop.bat -DryRun"`.
   - Verifies zero batch syntax errors, correct headless argument forwarding, and exit code 0 propagation.

---

## ⚡ Execution Modes

```powershell
# Full 7-pillar gate (recommended before git commit / git push):
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1

# Full 7-pillar gate with Pester NUnit XML test export & JaCoCo Code Coverage:
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -TestResultsPath "test-results\pester.xml" -CodeCoveragePath "test-results\coverage.xml"

# Rapid gate (steps 1-3 only; executes in < 0.2s):
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Fast

# Strict fail-closed gate (fails if PSScriptAnalyzer or Pester 5 is missing; auto-enabled in CI):
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -Strict

# Gate with analyzer bypassed:
powershell -ExecutionPolicy Bypass -File .\scripts\Test-MasterGate.ps1 -SkipAnalyzer
```

> [!NOTE]
> In GitHub Actions CI (`$env:GITHUB_ACTIONS -eq 'true'`) or automated CI environments, `-Strict` mode is auto-enabled, ensuring no linting or unit test steps are ever skipped silently.

---

## 🪝 Git Hooks Pipeline

The pre-push hook ([`.githooks/pre-push`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/.githooks/pre-push)) guards `main` and `master` branches against broken pushes:

- **Activation:** Run `powershell -ExecutionPolicy Bypass -File .\scripts\Install-GitHooks.ps1 -Test`
- **Fallback Synchronization:** `Install-GitHooks.ps1` sets `core.hooksPath .githooks` and copies the hook into `.git/hooks/pre-push`.
- **Pre-Push Behavior:** Reads incoming push refs from standard input. If `refs/heads/main` or `refs/heads/master` is targeted, it runs `Test-MasterGate.ps1`. If any pillar fails, Git rejects the push.
