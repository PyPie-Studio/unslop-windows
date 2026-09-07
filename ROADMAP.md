# unslop-windows Engineering Roadmap

This roadmap tracks feature development, privacy research, telemetry mitigations, and testing milestones for **unslop-windows**.

All additions must strictly follow the **Safe-Tier Design Principles** outlined in [`README.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/README.md) and [`CONTRIBUTING.md`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/CONTRIBUTING.md).

---

## 🎯 Milestone 1: Project Governance & Local CI (Current)
- [x] Symmetrical 1-click restore engine (`-Undo`).
- [x] Safe non-elevated dry-run inspection (`-DryRun`).
- [x] In-place abort shortcut (`A`) and auto-closing launcher.
- [x] Repository normalization (`.gitattributes`, `.editorconfig`).
- [x] Contributor pull request template (`.github/PULL_REQUEST_TEMPLATE.md`).
- [x] Release history tracking (`CHANGELOG.md`).
- [x] **Local Master Quality Gate (`scripts/Test-MasterGate.ps1`):** Unified AST parse, PSScriptAnalyzer, DryRun, and Undo DryRun check.
- [x] **Git Pre-Push Hook (`.githooks/pre-push`):** Blocks pushes to `main` if the local Master Gate fails.
- [x] **Agent Governance (`AGENTS.md` & `SKILLS.md`):** System harness, skills registry, and `.agents/skills/` for AI pair programming.

---

## 🛡 Milestone 2: Windows 11 25H2 & 26H2 Hardening
- [x] Windows Recall & Screenray Snapshot killswitches (`DisableAIDataAnalysis = 1`, `AllowRecall = 0`).
- [x] Windows Copilot taskbar and policy suppression.
- [x] 25H2 ConsentStore permissions (screen text scraping `foregroundTextAccess`, OS AI models `systemAIModels`, borderless capture `graphicsCaptureWithoutBorder`).
- [ ] **OneSettings Flighting DNS Hardening:** Block background telemetry endpoints downloaded via OneSettings config payloads.
- [ ] **Edge Sidebar & Hub Policy Killswitch:** Enforce GPO policies blocking Edge copilot sidebar integration without breaking WebView2.
- [ ] **Cumulative Update Invariant Verification:** Automated testing against novel 25H2 monthly CU rollouts to ensure zero `0x800f0922` update rollbacks.

---

## 💻 Milestone 3: Safe OEM Bloatware Profiles
- [ ] **Targeted OEM Parameters:**
  - `-PurgeASUS`: Removes Armoury Crate bloatware while keeping essential ASUS System Control Interface drivers.
  - `-PurgeDell`: Removes Dell SupportAssist telemetry services while preserving power management.
  - `-PurgeHP`: Purges HP Support Assistant, telemetry analytics, and Touchpoint Analytics.
  - `-PurgeLenovo`: Cleans Lenovo Vantage telemetry while preserving conservation mode hardware hooks.
- [ ] **Interactive Menu Expansion:** Add OEM profile selection sub-menu in `unslop.bat`.

---

## ⚡ Milestone 4: Diagnostic Benchmarking & Automated Testing
- [ ] **System State Auditor (`scripts/Measure-SystemState.ps1`):** Standalone before/after diagnostic tool measuring:
  - Real-time idle RAM and commit charge reduction.
  - Active telemetry services and background thread counts.
  - Uninstalled vs. provisioned AppX package totals.
  - Generates verifiable Markdown audit reports (`docs/benchmarks.md`).
- [ ] **Automated Windows Sandbox Smoke Testing:** Launch `unslop.ps1 -DryRun` inside a clean Windows Sandbox instance via script.
- [ ] **Cryptographic Release Hashes:** Automate SHA-256 checksum generation in `.github/workflows/release.yml`.

---

## 📄 Completed Architectural Decisions
See [`docs/decisions.md`](docs/decisions.md) for full Architectural Decision Records (ADR-001 through ADR-006) and [`CONTRIBUTING.md`](CONTRIBUTING.md) for core engineering rules and safe-tier guidelines.
