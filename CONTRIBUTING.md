# Contributing to unslop-windows

Thank you for your interest in improving `unslop-windows`.

To maintain stability across Windows 11 updates, all contributions must adhere to our strict **Safe-Tier** engineering standards.

---

## Non-Negotiable Core Rules

Every Pull Request must meet these five requirements:

### 1. The Safe-Tier Mandate
* **Never touch WinSxS or DISM servicing components.**
* **Never break Windows Update.** Cumulative updates and security patches must install cleanly.
* **Never break the Microsoft Store.** Do not disable `DoSvc` (*Delivery Optimization* service); use GPO `DODownloadMode = 0` to block peer-to-peer uploads instead.
* **Never disable critical security hardware or system drivers.**

### 2. Symmetrical Restoration (`-Undo`)
Any modification added to `unslop.ps1` must have an exact inverse restore path. If you disable a service, scheduled task, firewall rule, or registry key in the main debloat path, you must restore it to its default state in the `$IsUndo` block.

### 3. Zero Binary Dependencies
The project is pure PowerShell. Pull requests introducing external `.exe`, `.dll`, or third-party binary dependencies will be rejected. Use native Windows APIs, Group Policy registry paths, or PowerShell cmdlets.

### 4. Respect the Untouchable Whitelist
The following components must remain functional and un-targeted:
* Windows Terminal, Microsoft Store, WinGet (`DesktopAppInstaller`).
* Calculator, Photos, Paint, Snipping Tool (`ScreenSketch`).
* Microphone and webcam access (for Discord, Teams, OBS).
* Hardware noise suppression and GPU control panels (AMD / NVIDIA).
* Developer toolchains (VS Code, Git, Docker, Ollama).

### 5. Idempotent & Auditable
* Your additions must be safe to execute multiple times without corrupting keys or failing on missing elements.
* All additions must support `-DryRun` by logging intended actions with `[DRY-RUN]` without modifying system state.

---

## Local Development & Testing Workflow

Before opening a Pull Request, verify your changes locally:

### 1. Syntax & AST Verification
Run the PowerShell parser to confirm zero syntax errors:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(".\unslop.ps1", [ref]$null, [ref]$errors)
if ($errors.Length -eq 0) { "Syntax Clean" } else { $errors }
```

### 2. Linting (PSScriptAnalyzer)
Run `PSScriptAnalyzer` to match the GitHub Actions CI rules:

```powershell
Invoke-ScriptAnalyzer -Path .\ -Recurse -Severity Error, Warning
```

### 3. Dry-Run Execution Test
Run both standard and undo dry-run modes:

```powershell
# Verify audit output for your feature
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -DryRun

# Verify inverse restore output
powershell -ExecutionPolicy Bypass -File .\unslop.ps1 -Undo -DryRun
```

---

## Submitting a Pull Request

1. **Fork the Repository** to your personal GitHub account.
2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-hardening-policy
   ```
3. **Commit with Clear Messages**:
   ```bash
   git commit -m "feat(telemetry): disable novel 25h2 activity tracking task"
   ```
4. **Push and Open a PR**:
   * Include the Windows build number tested (e.g. 24H2 Build 26100 or 25H2 Build 26200).
   * Include the relevant excerpt from `.\logs\unslop_25h2_dryrun_*.log`.
