
## Batch File Testing via Pester Invariants
* When direct batch script execution in non-Windows environments (`cmd.exe` missing) is unavailable, static AST and regex-based Pester invariant testing on batch file contents (`tests/unslop.bat.Tests.ps1`) allows fast, deterministic validation of CRLF line endings, dependency checks, whitelist parameter arrays, and sub-menu structures.
