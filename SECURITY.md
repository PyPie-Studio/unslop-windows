# Security Policy

## Supported Versions

`unslop-windows` targets modern Windows 11 builds.

| Windows 11 Version | Build Range | Supported |
| :--- | :--- | :--- |
| **25H2** | Build 26200+ | Yes |
| **24H2** | Build 26100 - 26120 | Yes |
| **23H2** | Build 22631 | Yes |
| Older builds / Windows 10 | < Build 22000 | Best effort (untested) |

---

## Security Philosophy

`unslop-windows` is designed with a strict **Safe-Tier Guarantee**:

1. **Zero External Binaries & Offline-Only**: All operations are conducted exclusively through standard Windows PowerShell (`powershell.exe` / `pwsh.exe`) and native Windows APIs. No compiled binaries, external DLLs, or third-party executables are packaged or executed. The launcher strictly refuses to pull unsigned or unauthenticated code from the internet.
2. **Servicing Stack & Hardware Patch Preservation**: The script never modifies WinSxS component stores, DISM manifests, or system file permissions (`takeown` / `icacls`). Essential Windows Update hardware and firmware driver updates are preserved so endpoints receive critical security mitigations.
3. **Cryptographic Validation on Elevated Binaries**: Any invocation of external setup or uninstaller binaries located in user-writable paths (e.g. `%LOCALAPPDATA%`) requires valid Microsoft Authenticode digital signatures before elevated execution.
4. **Auditable**: Every action can be reviewed before execution via the non-elevated `-DryRun` switch.
5. **Reversible**: Every policy and service change can be reversed using the `-Undo` switch.
6. **Reparse Point / Symlink Hardening**: Log file paths inspect directory attributes to prevent junction and symlink redirection attacks in multi-user environments.

---

## Reporting a Security Concern or Breaking Change

If you discover that a policy or task modification breaks an unexpected core operating system function or creates a security regression, please report it via GitHub Issues or contact PyPie Studio.
