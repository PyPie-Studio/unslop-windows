# Bolt Performance Learnings

## PowerShell Array Concatenation in Loops (`+=`)

In PowerShell, arrays are immutable fixed-size data structures (`System.Array`). Using `$array += $item` inside a loop creates a brand new array and copies all existing elements on every iteration ($O(n^2)$ time/memory overhead).

### Recommended Patterns:
1. **Direct Assign from Loop:**
   Assign the loop output directly to a variable wrapped in `@(...)`:
   ```powershell
   $result = @(
       foreach ($item in $collection) {
           # emit items to pipeline
       }
   )
   ```
2. **Generic List (`System.Collections.Generic.List[T]`):**
   When incremental element addition is needed:
   ```powershell
   $list = [System.Collections.Generic.List[string]]::new()
   foreach ($item in $collection) {
       $list.Add($item)
   }
   ```
