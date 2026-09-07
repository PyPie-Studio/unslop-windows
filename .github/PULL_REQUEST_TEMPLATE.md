## What this PR does
<!-- A concise summary of the proposed change, new debloat feature, or bugfix -->

## Files changed
<!-- List each file modified, added, or removed and briefly explain why -->

## How I tested it
<!-- Describe your verification steps, paste the dry-run excerpt, or list tested Windows 11 build numbers (e.g. 24H2 Build 26100, 25H2 Build 26200) -->

## Safe-Tier Checklist
All PRs must strictly adhere to the five Safe-Tier engineering rules before merging:

- [ ] **Symmetrical Restoration (`-Undo`)**: Every policy, service, task, or registry key modified in the debloat path has an exact inverse restore mapping in the `$IsUndo` block.
- [ ] **Servicing Stack Safe**: Does NOT delete WinSxS packages, edit DISM manifests, or break Cumulative Updates (`0x800f0922`).
- [ ] **Microsoft Store Safe**: Does NOT disable `DoSvc` (*Delivery Optimization* service); uses GPO `DODownloadMode = 0` to block peer-to-peer uploads instead.
- [ ] **Untouchable Whitelist Intact**: Does NOT target core system tools (Windows Terminal, Store, WinGet, Calculator, Photos, Paint, Snipping Tool, Microphone, Webcam, Developer tools).
- [ ] **Auditable Non-Elevated `-DryRun`**: Tested with `-DryRun` in non-elevated mode and logged expected actions with `[DRY-RUN]` without modifying system state.
- [ ] **Syntax Clean**: Verified zero PowerShell parser errors:
  ```powershell
  $errs = $null; [System.Management.Automation.Language.Parser]::ParseFile('.\unslop.ps1', [ref]$null, [ref]$errs); if ($errs.Length -eq 0) { 'Syntax Clean' } else { $errs }
  ```
- [ ] **No Leakage**: No temporary logs (`logs/*.log`), backup files (`*.bak`, `*.tmp`), or personal test artifacts committed.
- [ ] **Line Endings**: Windows batch (`*.bat`) and PowerShell (`*.ps1`) scripts have CRLF line endings.
