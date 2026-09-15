# unslop-windows Roadmap

This roadmap tracks feature development, telemetry research and testing milestones for **unslop-windows**.

All additions must follow the safety rules outlined in [README.md](README.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Milestone 1: Project Governance & Testing (Completed)
- [x] Full 1-click rollback engine (`-Undo`).
- [x] Safe non-elevated dry-run inspection (`-DryRun`).
- [x] In-place abort shortcut (`A`) and auto-closing launcher.
- [x] Repository normalization (`.gitattributes`, `.editorconfig`).
- [x] Contributor pull request template (`.github/PULL_REQUEST_TEMPLATE.md`).
- [x] Release history tracking (`CHANGELOG.md`).
- [x] **Local Quality Gate (`scripts/Test-MasterGate.ps1`):** Unified AST parse, PSScriptAnalyzer, DryRun and Undo DryRun check.
- [x] **Git Pre-Push Hook (`.githooks/pre-push`):** Blocks pushes to `main` if the local gate fails.
- [x] **Architectural Standards & Decisions:** Documented invariants, failure handling and ADR ledger.
- [x] **Universal Mutating AST Audit & Negative Error-Trap Tests (`tests/unslop-win11.Tests.ps1`):** Enforces 100% helper routing and failure honesty.
- [x] **Automated CI Tooling (`scripts/Test-MasterGate.ps1`):** Strict automated gate preventing skipped static analysis and uninstalled test frameworks.

---

## Milestone 2: Windows 11 25H2 & 26H2 Hardening
- [x] Disable Windows Recall and Screenray snapshots (`DisableAIDataAnalysis = 1`, `AllowRecall = 0`).
- [x] Windows Copilot taskbar and policy suppression.
- [x] 25H2 ConsentStore permissions (screen text scraping `foregroundTextAccess`, OS AI models `systemAIModels` and borderless capture `graphicsCaptureWithoutBorder`).
- [ ] **OneSettings Flighting DNS Hardening:** Block background telemetry endpoints downloaded via OneSettings config payloads.
- [ ] **Edge Sidebar Policy:** Enforce GPO policies blocking Edge copilot sidebar integration without breaking WebView2.
- [ ] **Cumulative Update Invariant Verification:** Automated testing against novel 25H2 monthly CU rollouts to ensure zero `0x800f0922` update rollbacks.

---

## Milestone 3: Safe OEM Bloatware Profiles
- [ ] **Targeted OEM Parameters:**
  - `-RemoveASUS`: Removes Armoury Crate bloatware while keeping essential ASUS System Control Interface drivers.
  - `-RemoveDell`: Removes Dell SupportAssist telemetry services while preserving power management.
  - `-RemoveHP`: Removes HP Support Assistant and Touchpoint Analytics.
  - `-RemoveLenovo`: Cleans Lenovo Vantage telemetry while preserving conservation mode hardware hooks.
- [ ] **Interactive Menu Expansion:** Add OEM profile selection sub-menu in `unslop.bat`.

---

## Milestone 4: Diagnostic Benchmarking & Automated Testing
- [x] **System State Auditor (`scripts/Measure-SystemState.ps1`):** Standalone before/after diagnostic tool measuring:
  - Real-time idle RAM and commit charge changes.
  - Active telemetry services and background thread counts.
  - Uninstalled vs provisioned AppX package totals.
  - Generates verifiable Markdown audit reports (`docs/benchmarks.md`).
- [ ] **Automated Windows Sandbox Smoke Testing:** Launch `unslop-win11.ps1 -DryRun` inside a clean Windows Sandbox instance via script.
- [x] **Cryptographic Release Hashes:** Automate SHA-256 checksum generation in `.github/workflows/release.yml`.

---

## Milestone 5: Windows 10 Multi-OS Support (Completed)
- [x] **Dedicated Windows 10 Engine (`unslop-win10.ps1`):** Complete debloat and hardening engine for Windows 10 releases (22H2, 21H2, 21H1, 20H2, 2004, 1909, 1809, 1607, 1507, Enterprise LTSC 2021/2019/2016, IoT Enterprise LTSC, Builds 10240 through 19045).
- [x] **Remove Cortana & Suppress Taskbar Feeds:** Group Policy and AppX removal of Cortana, Feeds / News & Interests, People Bar and Meet Now.
- [x] **Unified Dual-OS Launcher (`unslop.bat`):** Interactive OS selection menu with `-Win10` and `-Win11` CLI pass-through routing.
- [x] **Symmetrical Dual-OS Test Suites (`tests/unslop-win11.Tests.ps1` & `tests/unslop-win10.Tests.ps1`):** 74 unit, mocking and AST parity tests.
- [x] **CI/CD Multi-OS Quad Matrix (`.github/workflows/lint.yml`):** Automated validation across both PowerShell 7 Core and Windows PowerShell 5.1 for both OS targets.

---

## Architecture Decisions
See [docs/decisions.md](docs/decisions.md) for full Architectural Decision Records (ADR-001 through ADR-025) and [CONTRIBUTING.md](CONTRIBUTING.md) for core engineering rules and safety guidelines.
