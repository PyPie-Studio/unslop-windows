# Security Policy

## Supported Versions

`unslop-windows` targets modern Windows 11 and Windows 10 builds.

| Operating System Version | Build Range | Supported Engine |
| :--- | :--- | :--- |
| **Windows 11 25H2** | Build 26200+ | Yes ([`unslop-win11.ps1`](unslop-win11.ps1)) |
| **Windows 11 24H2** | Build 26100 - 26120 | Yes ([`unslop-win11.ps1`](unslop-win11.ps1)) |
| **Windows 11 23H2** | Build 22631 | Yes ([`unslop-win11.ps1`](unslop-win11.ps1)) |
| **Windows 11 22H2 / 21H2** | Build 22621 / 22000 | Yes ([`unslop-win11.ps1`](unslop-win11.ps1)) |
| **Windows 10 22H2 (Current / ESU)** | Build 19045 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 21H2 / 21H1** | Build 19044 / 19043 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 20H2 / 2004** | Build 19042 / 19041 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 1909 / 1903** | Build 18363 / 18362 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 1809 / LTSC 2019** | Build 17763 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 1803 / 1709 / 1703** | Build 17134 / 16299 / 15063 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 1607 / LTSB 2016** | Build 14393 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 1511 / 1507 / LTSB 2015**| Build 10586 / 10240 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 Enterprise LTSC 2021** | Build 19044.1288+ | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |
| **Windows 10 IoT Enterprise LTSC** | Build 19044 / 19045 | Yes ([`unslop-win10.ps1`](unslop-win10.ps1)) |

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
