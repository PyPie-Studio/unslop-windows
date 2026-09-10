## 2025-05-18 - Reparse Point / Junction Guard for Auxiliary Scripts
**Vulnerability:** Symlink/junction redirection attack (OPSEC-01) where an unprivileged actor creates a reparse point / junction in shared/user directories target path prior to execution.
**Learning:** Hardening core log path in the engine script (`unslop.ps1`) is essential, but standalone diagnostic scripts like `scripts/Measure-SystemState.ps1` that write outputs/snapshots to `logs/` or `docs/` must also inspect `[System.IO.FileAttributes]::ReparsePoint` prior to file operations.
**Prevention:** Always inspect directory attributes for `ReparsePoint` before creating files in local directory trees in PowerShell scripts operating under elevated contexts, and enforce this invariant via AST unit test checks.
