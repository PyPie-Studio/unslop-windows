## What this PR does
<!-- A concise summary of the proposed change, new debloat feature or bugfix -->

## Files changed
<!-- List each file modified, added or removed and briefly explain why -->

## How I tested it
<!-- Describe your verification steps, paste the dry-run excerpt or list tested Windows 11 / Windows 10 build numbers (e.g. Win11 25H2 Build 26200, 24H2 Build 26100; Win10 22H2 Build 19045, LTSC 2021) -->

## System Safety Checklist
All PRs must strictly adhere to the core safety rules before merging:

- [ ] **Symmetrical Restoration (`-Undo`)**: Every policy, service, task or registry key modified in the debloat path has an exact inverse restore mapping in the `$IsUndo` block.
- [ ] **Servicing Stack Safe**: Does NOT delete WinSxS packages, edit DISM manifests or break Cumulative Updates (`0x800f0922`).
- [ ] **Microsoft Store Safe**: Does NOT disable `DoSvc` (*Delivery Optimization* service); uses GPO `DODownloadMode = 0` to block peer-to-peer uploads instead.
- [ ] **Protected Components Intact**: Does NOT target core system tools (Windows Terminal, Store, WinGet, Calculator, Photos, Paint, Snipping Tool, Microphone, Webcam or Developer tools).
- [ ] **Auditable Non-Elevated `-DryRun`**: Tested with `-DryRun` in non-elevated mode and logged expected actions with `[DRY-RUN]` without modifying system state.
- [ ] **Syntax Clean**: Verified zero PowerShell parser errors across both engines:
  ```powershell
  'unslop-win11.ps1', 'unslop-win10.ps1' | ForEach-Object { $errs = $null; [System.Management.Automation.Language.Parser]::ParseFile(".\$_", [ref]$null, [ref]$errs); if ($errs.Length -ne 0) { throw $errs } }; 'Syntax Clean'
  ```
- [ ] **No Leakage**: No temporary logs (`logs/*.log`), backup files (`*.bak`, `*.tmp`) or personal test artifacts committed.
- [ ] **Line Endings**: Windows batch (`*.bat`) and PowerShell (`*.ps1`) scripts have CRLF line endings.

