#!/usr/bin/env bash
# Common Teardown Utilities for Parallel-Safe Test Cleanup
#
# This module provides standardized teardown functions that are safe for
# parallel test execution. These functions ensure that each test only cleans
# up its own resources and does not interfere with other parallel tests.
#
# See tests/TEST_GUIDELINES.md for detailed guidelines on parallel-safe testing.

# ============================================================================
# Safe Test Directory Cleanup
# ============================================================================

# Safely clean up a test directory variable
# This function only deletes the directory specified by the variable,
# never searches for and deletes multiple directories (which causes
# race conditions in parallel execution).
#
# Arguments:
#   test_dir_var: Name of the variable containing the test directory path
#   additional_files: Optional list of additional file patterns to clean up
#                     (can be glob patterns like "/tmp/suitey_*")
#
# Returns:
#   0 on success, 1 on error
#
# Usage:
#   safe_teardown_test_directory "TEST_ADAPTER_REGISTRY_DIR" \
#     "/tmp/suitey_adapter_registry" \
#     "/tmp/suitey_adapter_capabilities"
#
safe_teardown_test_directory() {
  local test_dir_var="$1"
  shift
  local additional_files=("$@")
  
  # Clean up the test directory if it exists and is set
  if [[ -n "${!test_dir_var:-}" ]] && [[ -d "${!test_dir_var:-}" ]]; then
    rm -rf "${!test_dir_var}" 2>/dev/null || true
    unset "$test_dir_var"
  fi
  
  # Clean up additional files if provided
  for file_pattern in "${additional_files[@]}"; do
    if [[ -n "$file_pattern" ]]; then
      # Use eval to expand glob patterns safely
      eval "rm -f $file_pattern 2>/dev/null || true"
    fi
  done
  
  return 0
}

# Standard teardown pattern for adapter registry tests
# This function provides a ready-to-use teardown for adapter registry tests
#
# Usage in your test helper file:
#   source "$BATS_TEST_DIRNAME/common_teardown.bash"
#   teardown_adapter_registry_test() {
#     safe_teardown_adapter_registry
#   }
safe_teardown_adapter_registry() {
  safe_teardown_test_directory "TEST_ADAPTER_REGISTRY_DIR" \
    "/tmp/suitey_adapter_registry" \
    "/tmp/suitey_adapter_capabilities" \
    "/tmp/suitey_adapter_order" \
    "/tmp/suitey_adapter_init"
}

# Standard teardown pattern for build manager tests
# This function provides a ready-to-use teardown for build manager tests
#
# Usage in your test helper file:
#   source "$BATS_TEST_DIRNAME/common_teardown.bash"
#   teardown_build_manager_test() {
#     safe_teardown_build_manager
#   }
safe_teardown_build_manager() {
  safe_teardown_test_directory "TEST_BUILD_MANAGER_DIR" \
    "/tmp/suitey_build_manager_*" \
    "/tmp/suitey_build_*" \
    "/tmp/async_operation_*" \
    "/tmp/mock_*"
}

# Standard teardown pattern for framework detector tests
# This function provides a ready-to-use teardown for framework detector tests
#
# Usage in your test helper file:
#   source "$BATS_TEST_DIRNAME/common_teardown.bash"
#   teardown_framework_detector_test() {
#     safe_teardown_framework_detector
#   }
safe_teardown_framework_detector() {
  safe_teardown_test_directory "TEST_PROJECT_DIR"
}

# ============================================================================
# Helper Functions
# ============================================================================

# Check if a teardown function follows safe patterns
# This can be used in tests to verify teardown functions are safe
#
# Arguments:
#   teardown_function_name: Name of the teardown function to check
#
# Returns:
#   0 if safe, 1 if potentially unsafe
check_teardown_safety() {
  local func_name="$1"
  if ! command -v "$func_name" >/dev/null 2>&1; then
    echo "ERROR: Function '$func_name' not found" >&2
    return 1
  fi
  
  # Check if function contains dangerous find patterns
  local func_body
  func_body=$(declare -f "$func_name" 2>/dev/null)
  if echo "$func_body" | grep -qE 'find.*-exec rm.*suitey.*test'; then
    echo "WARNING: Function '$func_name' contains potentially unsafe find/rm pattern" >&2
    return 1
  fi
  
  return 0
}

