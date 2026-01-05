# Return-Data Pattern for Array Population Functions

## Overview

The return-data pattern is a methodology for functions that need to populate caller's arrays, especially when those functions are tested in BATS. This pattern avoids scoping issues that can occur with namerefs and eval in BATS test contexts.

## Problem

When functions use namerefs or eval to modify caller's arrays in BATS tests, they can encounter scoping issues where:
- Arrays appear to be populated inside the function
- But are empty after the function returns
- This is due to BATS running tests in subshells with different scoping rules

## Solution: Return-Data Pattern

Instead of modifying the caller's array directly, functions:
1. Process the data
2. Return it in a structured format (first line = count, subsequent lines = key=value pairs)
3. Let the caller populate their own array from the returned data

## When to Use

**Use return-data pattern when:**
- Function needs to populate caller's array
- Function is tested in BATS
- Function processes data from files/external sources
- You want explicit control over array population

**Nameref is acceptable when:**
- Function only reads from arrays (not modifies)
- Function modifies global arrays directly
- Function is not tested in BATS or tests pass
- Performance is critical (nameref is slightly faster)

## Implementation

### Function Signature

```bash
# Function returns: first line is count, subsequent lines are key=value pairs
function_name() {
    local array_name="$1"  # For documentation, not used for modification
    local file_path="$2"
    
    # Process data and build output
    local count=0
    local output_lines=""
    
    while IFS= read -r line; do
        # Process line
        output_lines+="${key}=${value}"$'\n'
        count=$((count + 1))
    done < "$file_path"
    
    # Output count first, then data
    echo "$count"
    echo -n "$output_lines"
    return 0
}
```

### Caller Usage

```bash
# Option 1: Manual processing
output=$(function_name "array_name" "$file")
count=$(echo "$output" | head -n 1)
if [[ "$count" -gt 0 ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" ]] && continue
        array["$key"]="$value"
    done < <(echo "$output" | tail -n +2)
fi

# Option 2: Using helper function
output=$(function_name "array_name" "$file")
count=$(_adapter_registry_populate_array_from_output "array_name" "$output")
```

## Helper Function

A reusable helper function `_adapter_registry_populate_array_from_output()` is available in `adapter_registry_helpers.sh`:

```bash
# Populates an associative array from return-data format
# Arguments:
#   array_name: Name of associative array to populate
#   output: Output from a return-data function
# Returns:
#   The count (first line of output)
count=$(_adapter_registry_populate_array_from_output "array_name" "$output")
```

## Examples

### Current Implementation

- `_adapter_registry_load_array_from_file()` - Uses return-data pattern
- `json_to_array()` - Uses nameref (works, no BATS issues)
- `build_requirements_json_to_array()` - Uses nameref (works, no BATS issues)

### Migration Example

**Before (nameref - can fail in BATS):**
```bash
load_array() {
    local array_name="$1"
    local -n arr="$array_name"
    arr["key"]="value"
}
```

**After (return-data - works in BATS):**
```bash
load_array() {
    local array_name="$1"
    echo "1"
    echo "key=value"
}

# Caller:
output=$(load_array "my_array")
count=$(_adapter_registry_populate_array_from_output "my_array" "$output")
```

## Benefits

1. **Avoids BATS scoping issues** - No eval/nameref scoping problems
2. **Clearer separation** - Function returns data, caller populates
3. **Easier to test** - Caller controls array population
4. **More flexible** - Caller can transform data before populating
5. **Better error handling** - Caller can validate before populating

## Testing

Functions using return-data pattern should be tested to verify:
1. Correct count is returned
2. Data format is correct (key=value pairs)
3. Caller can successfully populate array
4. Empty/non-existent file cases are handled

See `tests/bats/unit/adapter_registry_helpers.bats` for examples.

