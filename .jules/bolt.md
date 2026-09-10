# Bolt Journal - unslop-windows Critical Learnings

## 2026-09-07 - PowerShell Pipeline & Array Re-allocation Performance Patterns
**Learning:** In PowerShell monolithic scripts, using `| Where-Object` pipeline filters inside tight loops (like iterating through ~35 AppX bloatware packages over 200+ installed packages) creates massive object streaming overhead. Replacing pipelines with the `.Where()` intrinsic collection method speeds up filtering by 3-5x. Additionally, log accumulation with `$array += $item` causes O(N²) memory churn due to array re-allocation; using `List[string]` with `.Add()` makes entry accumulation O(1) amortized.
**Action:** Always prefer `.Where()` intrinsic method over `| Where-Object` when querying pre-fetched collections inside loops, and use `List[T]` over `+=` for string/log buffers in PowerShell.
