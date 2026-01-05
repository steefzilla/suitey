# Test Guidelines for Parallel Execution

This document provides guidelines for writing tests that are safe for parallel execution using BATS' `-j` flag.

## Table of Contents

- [Teardown Best Practices](#teardown-best-practices)
- [File Operations](#file-operations)
- [Global Variable Initialization](#global-variable-initialization)
- [Common Patterns](#common-patterns)
- [Using Common Teardown Utilities](#using-common-teardown-utilities)

## Teardown Best Practices

### ✅ DO: Clean up only your test's directory

Each test should only clean up resources it created. Use the test directory variable that was set during setup:

```bash
teardown_my_test() {
  if [[ -n "${TEST_MY_DIR:-}" ]] && [[ -d "$TEST_MY_DIR" ]]; then
    rm -rf "$TEST_MY_DIR"
    unset TEST_MY_DIR
  fi
  
  # Clean up additional files specific to this test
  rm -f /tmp/suitey_my_test_* 2>/dev/null || true
}
```

### ❌ DON'T: Delete all matching directories

**NEVER** use `find` to delete all directories matching a pattern in teardown:

```bash
# WRONG - Causes race conditions in parallel execution
teardown_my_test() {
  # This will delete directories from OTHER parallel tests!
  find /tmp -maxdepth 1 -name "suitey_*_test_*" -type d -exec rm -rf {} + 2>/dev/null || true
}
```

**Why this is dangerous:**
- In parallel execution, multiple tests run simultaneously
- One test's teardown can delete directories that other tests are still using
- This causes "No such file or directory" errors
- Tests fail intermittently and unpredictably

### ✅ DO: Use common teardown utilities

Use the standardized functions from `common_teardown.bash`:

```bash
# In your helper file
source "$BATS_TEST_DIRNAME/common_teardown.bash"

teardown_adapter_registry_test() {
  safe_teardown_adapter_registry
}
```

Or create a custom teardown using the utility function:

```bash
source "$BATS_TEST_DIRNAME/common_teardown.bash"

teardown_my_custom_test() {
  safe_teardown_test_directory "TEST_MY_DIR" \
    "/tmp/suitey_my_file1" \
    "/tmp/suitey_my_file2"
}
```

## File Operations

### ✅ DO: Use atomic file writes

When writing files that may be read by other processes, use atomic writes:

```bash
# Write to temp file first, then atomically rename
temp_file=$(mktemp -p "$dir_path" "file.tmp.XXXXXX")
echo "data" > "$temp_file"
mv "$temp_file" "$final_file"  # Atomic on most filesystems
```

### ✅ DO: Compute file paths dynamically

Don't initialize file paths at module load time. Compute them when needed:

```bash
# WRONG - Initialized at module load time
REGISTRY_FILE="${TEST_ADAPTER_REGISTRY_DIR:-/tmp}/registry"

# RIGHT - Computed dynamically when needed
get_registry_file() {
  local base_dir="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
  echo "$base_dir/registry"
}
```

## Global Variable Initialization

### ✅ DO: Use lazy initialization

Initialize global variables that depend on test-specific environment variables lazily:

```bash
# WRONG - Initialized before TEST_ADAPTER_REGISTRY_DIR is set
REGISTRY_BASE_DIR="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"

# RIGHT - Initialized as empty, computed when needed
REGISTRY_BASE_DIR=""
# Then compute it in functions that use it
```

### ❌ DON'T: Initialize at module load time

If your module is sourced before test setup runs, global variables will have wrong values:

```bash
# This will use /tmp for all tests if sourced before setup
REGISTRY_FILE="${TEST_ADAPTER_REGISTRY_DIR:-/tmp}/registry"
```

## Common Patterns

### Pattern 1: Test Directory Setup

```bash
setup_my_test() {
  local test_name="${1:-my_test}"
  TEST_MY_DIR=$(mktemp -d -t "suitey_my_test_${test_name}_XXXXXX")
  export TEST_MY_DIR
  echo "$TEST_MY_DIR"
}
```

### Pattern 2: Safe Teardown

```bash
teardown_my_test() {
  # Only clean up THIS test's directory
  if [[ -n "${TEST_MY_DIR:-}" ]] && [[ -d "$TEST_MY_DIR" ]]; then
    rm -rf "$TEST_MY_DIR" 2>/dev/null || true
    unset TEST_MY_DIR
  fi
  
  # Clean up test-specific files (not directories!)
  rm -f /tmp/suitey_my_test_* 2>/dev/null || true
}
```

### Pattern 3: Dynamic Path Computation

```bash
get_my_test_file() {
  local base_dir="${TEST_MY_DIR:-${TMPDIR:-/tmp}}"
  echo "$base_dir/my_file"
}

# Use it in functions
my_function() {
  local file_path
  file_path=$(get_my_test_file)
  # Use file_path...
}
```

## Using Common Teardown Utilities

The project provides standardized teardown utilities in `tests/bats/helpers/common_teardown.bash`.

### Available Functions

1. **`safe_teardown_test_directory`** - Generic safe teardown function
2. **`safe_teardown_adapter_registry`** - Pre-configured for adapter registry tests
3. **`safe_teardown_build_manager`** - Pre-configured for build manager tests
4. **`safe_teardown_framework_detector`** - Pre-configured for framework detector tests

### Example Usage

```bash
#!/usr/bin/env bash
# My test helper

# Source common teardown utilities
if [[ -f "$BATS_TEST_DIRNAME/common_teardown.bash" ]]; then
  source "$BATS_TEST_DIRNAME/common_teardown.bash"
fi

# Use pre-configured teardown
teardown_adapter_registry_test() {
  safe_teardown_adapter_registry
}

# Or create custom teardown
teardown_my_custom_test() {
  safe_teardown_test_directory "TEST_MY_DIR" \
    "/tmp/suitey_custom_file1" \
    "/tmp/suitey_custom_file2"
}
```

## Testing Parallel Execution

To test that your tests work in parallel:

```bash
# Run tests in parallel (16 jobs)
bats -rj 16 ./tests/bats/unit/my_tests.bats

# Compare with serial execution
bats -r ./tests/bats/unit/my_tests.bats
```

If tests pass serially but fail in parallel, check for:
- Aggressive teardown cleanup
- Shared global state
- Non-atomic file operations
- Module-load-time initialization

## Summary

1. **Each test only cleans up its own directory** - Never use `find` to delete multiple directories
2. **Use common teardown utilities** - Standardized, tested, and safe
3. **Compute paths dynamically** - Don't initialize at module load time
4. **Use atomic file operations** - Write to temp file, then rename
5. **Test in parallel** - Always verify tests work with `-j` flag

For questions or issues, see the implementation in `tests/bats/helpers/common_teardown.bash` or review existing test helpers that follow these patterns.

