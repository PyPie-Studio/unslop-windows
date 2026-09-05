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

1. **Zero External Binaries**: All operations are conducted exclusively through standard Windows PowerShell (`powershell.exe` / `pwsh.exe`) and native Windows APIs. No compiled binaries, external DLLs, or third-party executables are packaged or executed.
2. **Servicing Stack Preservation**: The script never modifies WinSxS component stores, DISM manifests, or system file permissions (`takeown` / `icacls`). This ensures Windows Servicing and Cumulative Updates remain stable.
3. **Auditable**: Every action can be reviewed before execution via the non-elevated `-DryRun` switch.
4. **Reversible**: Every policy and service change can be reversed using the `-Undo` switch.

---

## Reporting a Security Concern or Breaking Change

If you discover that a policy or task modification breaks an unexpected core operating system function or creates a security regression, please report it via GitHub Issues or contact PyPie Studio.
