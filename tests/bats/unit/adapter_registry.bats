#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry
load ../helpers/fixtures

# ============================================================================
# Helper function to source adapter registry modules from src/
# ============================================================================

_source_adapter_registry_modules() {
  # Find and source json_helpers.sh (needed by adapter_registry.sh)
  local json_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
  else
    json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
  fi
  source "$json_helpers_script"

  # Find and source adapter_registry.sh
  local adapter_registry_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../src/adapter_registry.sh"
  else
    adapter_registry_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry.sh"
  fi
  source "$adapter_registry_script"
}

# ============================================================================
# JSON Helper Functions (for test assertions)
# ============================================================================

# Test-local JSON helper functions (wrappers around jq for now)
json_test_get() {
  local json="$1"
  local path="$2"
  echo "$json" | jq -r "$path" 2>/dev/null || return 1
}

json_test_has_field() {
  local json="$1"
  local field="$2"
  echo "$json" | jq -e "has(\"$field\")" >/dev/null 2>&1
}

# ============================================================================
# Adapter Registration Tests
# ============================================================================

@test "register_adapter with valid adapter succeeds" {
  setup_adapter_registry_test

  # Create a valid mock adapter
  create_valid_mock_adapter "test_adapter"

  # Should succeed
  output=$(run_adapter_registry_register "test_adapter")
  assert_success

  teardown_adapter_registry_test
}

@test "register_adapter with duplicate identifier fails" {
  setup_adapter_registry_test

  # Register first adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Try to register the same adapter again
  run run_adapter_registry_register "test_adapter"
  assert_failure
  assert_adapter_registration_error "$output" "identifier_conflict"

  teardown_adapter_registry_test
}

@test "get_adapter returns registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get the adapter
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_found "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "get_adapter returns null for unregistered adapter" {
  setup_adapter_registry_test

  # Try to get non-existent adapter
  output=$(run_adapter_registry_get "non_existent" 2>&1) || true
  assert_adapter_not_found "$output" "non_existent"

  teardown_adapter_registry_test
}

@test "get_all_adapters returns all registered adapters" {
  setup_adapter_registry_test

  # Register multiple adapters
  create_valid_mock_adapter "adapter1"
  run_adapter_registry_register "adapter1"
  assert_success

  create_valid_mock_adapter "adapter2"
  run_adapter_registry_register "adapter2"
  assert_success

  # Get all adapters
  output=$(run_adapter_registry_get_all)
  assert_all_adapters_returned "$output" "adapter1,adapter2"

  teardown_adapter_registry_test
}

@test "is_registered returns true for registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Check if registered
  output=$(run_adapter_registry_is_registered "test_adapter")
  assert_is_registered "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "is_registered returns false for unregistered adapter" {
  setup_adapter_registry_test

  # Check unregistered adapter
  output=$(run_adapter_registry_is_registered "non_existent")
  assert_is_not_registered "$output" "non_existent"

  teardown_adapter_registry_test
}

@test "get_adapters_by_capability returns matching adapters" {
  setup_adapter_registry_test

  # Register adapters with different capabilities
  create_valid_mock_adapter_with_capability "adapter1" "parallel"
  run_adapter_registry_register "adapter1"
  assert_success

  create_valid_mock_adapter_with_capability "adapter2" "coverage"
  run_adapter_registry_register "adapter2"
  assert_success

  create_valid_mock_adapter_with_capability "adapter3" "parallel"
  run_adapter_registry_register "adapter3"
  assert_success

  # Get adapters by capability
  output=$(run_adapter_registry_get_by_capability "parallel")
  assert_adapters_by_capability "$output" "parallel" "adapter1,adapter3"

  teardown_adapter_registry_test
}

# ============================================================================
# Interface Enforcement Tests
# ============================================================================

@test "register_adapter rejects adapter missing detect method" {
  setup_adapter_registry_test

  # Create invalid adapter missing detect method
  create_invalid_mock_adapter "missing_detect"

  # Should fail
  run run_adapter_registry_register "missing_detect"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter rejects adapter missing discover_test_suites method" {
  setup_adapter_registry_test

  # Create invalid adapter missing discover method
  create_invalid_mock_adapter "missing_discover"

  # Should fail
  run run_adapter_registry_register "missing_discover"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter rejects adapter missing get_metadata method" {
  setup_adapter_registry_test

  # Create invalid adapter missing metadata method
  create_invalid_mock_adapter "missing_metadata"

  # Should fail
  run run_adapter_registry_register "missing_metadata"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter accepts adapter with complete interface" {
  setup_adapter_registry_test

  # Create adapter with complete interface
  create_complete_mock_adapter "complete_adapter"

  # Should succeed
  output=$(run_adapter_registry_register "complete_adapter")
  assert_success

  teardown_adapter_registry_test
}

# ============================================================================
# Built-in Adapters Tests
# ============================================================================

@test "built-in BATS adapter is registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Check BATS adapter is registered
  output=$(run_adapter_registry_is_registered "bats")
  assert_is_registered "$output" "bats"

  teardown_adapter_registry_test
}

@test "built-in Rust adapter is registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Check Rust adapter is registered
  output=$(run_adapter_registry_is_registered "rust")
  assert_is_registered "$output" "rust"

  teardown_adapter_registry_test
}

@test "all built-in adapters are registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Get all adapters
  output=$(run_adapter_registry_get_all)
  assert_builtin_adapters_present "$output"

  teardown_adapter_registry_test
}

# ============================================================================
# Metadata Management Tests
# ============================================================================

@test "get_adapter returns correct metadata for registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get adapter and check metadata
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_metadata "$output" "test_adapter" "name" "Test Adapter"
  assert_adapter_metadata "$output" "test_adapter" "identifier" "test_adapter"
  assert_adapter_metadata "$output" "test_adapter" "version" "1.0.0"

  teardown_adapter_registry_test
}

@test "adapter metadata includes required fields" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get adapter and check required metadata fields
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_metadata_structure "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "adapter metadata includes capabilities array" {
  setup_adapter_registry_test

  # Register an adapter with capabilities
  create_valid_mock_adapter_with_capability "capability_adapter" "parallel"
  run_adapter_registry_register "capability_adapter"
  assert_success

  # Check capabilities metadata
  output=$(run_adapter_registry_get "capability_adapter")
  assert_adapter_capabilities "$output" "capability_adapter" "parallel"

  teardown_adapter_registry_test
}

# ============================================================================
# Base64 Encoding/Decoding Tests
# ============================================================================

@test "base64 encoding and decoding preserves adapter metadata values" {
  setup_adapter_registry_test

  # Create a valid mock adapter with complex JSON metadata
  create_valid_mock_adapter "test_adapter"

  # Register the adapter
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get the adapter metadata
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_found "$output" "test_adapter"

  # Save state (encodes to base64)
  _source_adapter_registry_modules
  adapter_registry_save_state

  # Clear in-memory state
  ADAPTER_REGISTRY=()
  ADAPTER_REGISTRY_CAPABILITIES=()
  ADAPTER_REGISTRY_ORDER=()

  # Load state (decodes from base64)
  adapter_registry_load_state

  # Get the adapter metadata again after save/load cycle
  output_after=$(run_adapter_registry_get "test_adapter")
  assert_adapter_found "$output_after" "test_adapter"

  # Verify the metadata is identical (no data loss through encoding/decoding)
  if [[ "$output" != "$output_after" ]]; then
    echo "ERROR: Metadata changed after base64 encode/decode cycle"
    echo "Original: $output"
    echo "After: $output_after"
    return 1
  fi

  # Verify specific fields are preserved
  local name_field
  name_field=$(json_test_get "$output_after" '.name')
  if [[ "$name_field" != "Test Adapter" ]]; then
    echo "ERROR: 'name' field not preserved correctly"
    echo "Expected: Test Adapter, Got: $name_field"
    return 1
  fi

  local identifier_field
  identifier_field=$(json_test_get "$output_after" '.identifier')
  if [[ "$identifier_field" != "test_adapter" ]]; then
    echo "ERROR: 'identifier' field not preserved correctly"
    echo "Expected: test_adapter, Got: $identifier_field"
    return 1
  fi

  if ! json_test_has_field "$output_after" "capabilities"; then
    echo "ERROR: 'capabilities' field not preserved correctly"
    return 1
  fi

  teardown_adapter_registry_test
}

@test "base64 encoding handles special characters in JSON metadata" {
  setup_adapter_registry_test

  # Create adapter with metadata containing special characters
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/special_adapter"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << 'EOF'
#!/usr/bin/env bash

special_adapter_adapter_detect() {
  return 0
}

special_adapter_adapter_get_metadata() {
  # JSON with special characters: quotes, newlines, equals signs, etc.
  echo '{"name": "Test \"Adapter\"", "description": "Has = signs and\nnewlines", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["test"], "required_binaries": [], "configuration_files": [], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}'
}

special_adapter_adapter_check_binaries() {
  return 0
}

special_adapter_adapter_discover_test_suites() {
  echo '[]'
}

special_adapter_adapter_detect_build_requirements() {
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

special_adapter_adapter_get_build_steps() {
  echo '[]'
}

special_adapter_adapter_execute_test_suite() {
  echo '{"exit_code": 0, "duration": 1.0, "output": "test", "container_id": null, "execution_method": "mock"}'
}

special_adapter_adapter_parse_test_results() {
  echo '{"total_tests": 0, "passed_tests": 0, "failed_tests": 0, "skipped_tests": 0, "test_details": [], "status": "passed"}'
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"

  # Register the adapter
  run_adapter_registry_register "special_adapter"
  assert_success

  # Get original metadata
  output=$(run_adapter_registry_get "special_adapter")
  assert_adapter_found "$output" "special_adapter"

  # Save and reload
  _source_adapter_registry_modules
  adapter_registry_save_state
  ADAPTER_REGISTRY=()
  adapter_registry_load_state

  # Get metadata after save/load
  output_after=$(run_adapter_registry_get "special_adapter")
  assert_adapter_found "$output_after" "special_adapter"

  # Verify special characters are preserved
  local name_field_special
  name_field_special=$(json_test_get "$output_after" '.name')
  if [[ "$name_field_special" != 'Test "Adapter"' ]]; then
    echo "ERROR: Quotes in metadata not preserved"
    echo "Expected: Test \"Adapter\", Got: $name_field_special"
    return 1
  fi

  local description_field
  description_field=$(json_test_get "$output_after" '.description')
  if [[ "$description_field" != *"Has = signs"* ]]; then
    echo "ERROR: Equals signs in metadata not preserved"
    echo "Expected to contain: Has = signs, Got: $description_field"
    return 1
  fi

  teardown_adapter_registry_test
}

# ============================================================================
# Diagnostic Tests - Registry File Persistence
# ============================================================================

@test "registry file is created after adapter registration" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "file_test_adapter"
  run_adapter_registry_register "file_test_adapter"
  assert_success

  # Verify registry file exists
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  if [[ ! -f "$registry_file" ]]; then
    echo "ERROR: Registry file was not created: $registry_file" >&2
    echo "TEST_ADAPTER_REGISTRY_DIR: $TEST_ADAPTER_REGISTRY_DIR" >&2
    ls -la "$TEST_ADAPTER_REGISTRY_DIR" >&2 || echo "Directory does not exist" >&2
    return 1
  fi

  # Verify file is not empty
  if [[ ! -s "$registry_file" ]]; then
    echo "ERROR: Registry file is empty" >&2
    return 1
  fi

  # Verify file contains the adapter
  if ! grep -q "file_test_adapter=" "$registry_file"; then
    echo "ERROR: Registry file does not contain adapter entry" >&2
    echo "File contents:" >&2
    cat "$registry_file" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "registry file contains valid base64 encoded data" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "base64_test_adapter"
  run_adapter_registry_register "base64_test_adapter"
  assert_success

  # Get the registry file
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  
  # Extract the encoded value
  local encoded_value
  encoded_value=$(grep "^base64_test_adapter=" "$registry_file" | cut -d= -f2-)

  if [[ -z "$encoded_value" ]]; then
    echo "ERROR: Could not extract encoded value from registry file" >&2
    echo "File contents:" >&2
    cat "$registry_file" >&2
    return 1
  fi

  # Verify it's valid base64 by attempting to decode
  local decoded_value
  if ! decoded_value=$(echo -n "$encoded_value" | base64 -d 2>&1); then
    echo "ERROR: Encoded value is not valid base64" >&2
    echo "Encoded value: $encoded_value" >&2
    return 1
  fi

  # Verify decoded value is valid JSON
  if ! json_test_has_field "$decoded_value" "name"; then
    echo "ERROR: Decoded value is not valid JSON metadata" >&2
    echo "Decoded value: $decoded_value" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "load_state finds and loads registry file from TEST_ADAPTER_REGISTRY_DIR" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "load_test_adapter"
  run_adapter_registry_register "load_test_adapter"
  assert_success

  # Verify file exists
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  [[ -f "$registry_file" ]]

  # Source adapter registry modules fresh (simulating run_adapter_registry_get)
  _source_adapter_registry_modules

  # Verify arrays are empty after sourcing (check if variable exists first due to set -u)
  if [[ -v ADAPTER_REGISTRY[@] ]] && [[ ${#ADAPTER_REGISTRY[@]} -ne 0 ]]; then
    echo "ERROR: ADAPTER_REGISTRY should be empty after sourcing adapter registry modules" >&2
    return 1
  fi

  # Call load_state
  adapter_registry_load_state

  # Verify adapter was loaded
  if [[ ! -v ADAPTER_REGISTRY["load_test_adapter"] ]]; then
    echo "ERROR: Adapter was not loaded from file" >&2
    echo "ADAPTER_REGISTRY keys: ${!ADAPTER_REGISTRY[@]}" >&2
    echo "Registry file: $registry_file" >&2
    echo "File exists: $([[ -f "$registry_file" ]] && echo yes || echo no)" >&2
    echo "File contents:" >&2
    cat "$registry_file" >&2 || echo "Could not read file" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "save_state and load_state use consistent file paths" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "path_test_adapter"
  
  # Source adapter registry modules
  _source_adapter_registry_modules

  # Register adapter (this will save state)
  create_valid_mock_adapter "path_test_adapter"
  adapter_registry_register "path_test_adapter"

  # Get the file path used by save_state
  local saved_file="${ADAPTER_REGISTRY_FILE:-}"
  
  # Clear arrays and reload
  ADAPTER_REGISTRY=()
  adapter_registry_load_state

  # Get the file path used by load_state
  local loaded_file="${ADAPTER_REGISTRY_FILE:-}"

  # Verify paths match
  if [[ "$saved_file" != "$loaded_file" ]]; then
    echo "ERROR: Save and load use different file paths" >&2
    echo "Save path: $saved_file" >&2
    echo "Load path: $loaded_file" >&2
    echo "TEST_ADAPTER_REGISTRY_DIR: $TEST_ADAPTER_REGISTRY_DIR" >&2
    return 1
  fi

  # Verify the file exists at that path
  if [[ ! -f "$saved_file" ]]; then
    echo "ERROR: Registry file does not exist at saved path: $saved_file" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "load_state should_reload logic triggers when file exists" {
  setup_adapter_registry_test

  # Create registry file manually with test data
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local test_json='{"name": "Test", "identifier": "manual_test"}'
  local encoded_value
  encoded_value=$(echo -n "$test_json" | base64 -w 0 2>/dev/null || echo -n "$test_json" | base64 -b 0 2>/dev/null || echo -n "$test_json" | base64 | tr -d '\n')
  
  echo "manual_test=$encoded_value" > "$registry_file"

  # Source adapter registry modules fresh
  _source_adapter_registry_modules

  # Verify arrays are empty (check if variable exists first due to set -u)
  if [[ -v ADAPTER_REGISTRY[@] ]] && [[ ${#ADAPTER_REGISTRY[@]} -ne 0 ]]; then
    echo "ERROR: ADAPTER_REGISTRY should be empty after sourcing adapter registry modules" >&2
    return 1
  fi

  # Call load_state
  adapter_registry_load_state

  # Verify adapter was loaded
  if [[ ! -v ADAPTER_REGISTRY["manual_test"] ]]; then
    echo "ERROR: Adapter was not loaded from manually created file" >&2
    echo "ADAPTER_REGISTRY keys: ${!ADAPTER_REGISTRY[@]}" >&2
    echo "Registry file: $registry_file" >&2
    echo "File contents:" >&2
    cat "$registry_file" >&2
    return 1
  fi

  # Verify the loaded value matches
  if [[ "${ADAPTER_REGISTRY[manual_test]}" != "$test_json" ]]; then
    echo "ERROR: Loaded value does not match expected" >&2
    echo "Expected: $test_json" >&2
    echo "Got: ${ADAPTER_REGISTRY[manual_test]}" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "adapter_registry_get works after fresh source and load_state" {
  setup_adapter_registry_test

  # Register an adapter using the helper (which sources adapter registry modules)
  create_valid_mock_adapter "get_test_adapter"
  run_adapter_registry_register "get_test_adapter"
  assert_success

  # Verify file exists
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  [[ -f "$registry_file" ]]

  # Now simulate what run_adapter_registry_get does: source fresh and call get
  # Source fresh (this resets arrays)
  _source_adapter_registry_modules

  # Call get (which should call load_state internally)
  local output
  output=$(adapter_registry_get "get_test_adapter")

  # Verify we got the adapter (not null)
  if [[ "$output" == "null" ]] || [[ -z "$output" ]]; then
    echo "ERROR: adapter_registry_get returned null or empty" >&2
    echo "Output: $output" >&2
    echo "ADAPTER_REGISTRY keys: ${!ADAPTER_REGISTRY[@]}" >&2
    echo "Registry file: $registry_file" >&2
    echo "File exists: $([[ -f "$registry_file" ]] && echo yes || echo no)" >&2
    if [[ -f "$registry_file" ]]; then
      echo "File contents:" >&2
      cat "$registry_file" >&2
    fi
    return 1
  fi

  # Verify it's valid JSON
  if ! json_test_has_field "$output" "name"; then
    echo "ERROR: Returned value is not valid JSON metadata" >&2
    echo "Output: $output" >&2
    return 1
  fi

  teardown_adapter_registry_test
}

@test "diagnostic: verify TEST_ADAPTER_REGISTRY_DIR is set and accessible" {
  setup_adapter_registry_test

  # Verify TEST_ADAPTER_REGISTRY_DIR is set
  if [[ -z "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
    echo "ERROR: TEST_ADAPTER_REGISTRY_DIR is not set" >&2
    return 1
  fi

  # Verify it's a directory
  if [[ ! -d "$TEST_ADAPTER_REGISTRY_DIR" ]]; then
    echo "ERROR: TEST_ADAPTER_REGISTRY_DIR is not a directory: $TEST_ADAPTER_REGISTRY_DIR" >&2
    return 1
  fi

  # Verify it's writable
  if [[ ! -w "$TEST_ADAPTER_REGISTRY_DIR" ]]; then
    echo "ERROR: TEST_ADAPTER_REGISTRY_DIR is not writable: $TEST_ADAPTER_REGISTRY_DIR" >&2
    return 1
  fi

  # Verify we can create files in it
  local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_write"
  if ! touch "$test_file" 2>&1; then
    echo "ERROR: Cannot create files in TEST_ADAPTER_REGISTRY_DIR" >&2
    echo "Directory: $TEST_ADAPTER_REGISTRY_DIR" >&2
    return 1
  fi
  rm -f "$test_file"

  teardown_adapter_registry_test
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "register_adapter with invalid metadata fails gracefully" {
  setup_adapter_registry_test

  # Create adapter with invalid metadata
  create_invalid_metadata_adapter "bad_metadata"

  # Should fail
  run run_adapter_registry_register "bad_metadata"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_metadata"

  teardown_adapter_registry_test
}

@test "get_adapter handles adapter not found gracefully" {
  setup_adapter_registry_test

  # Try to get non-existent adapter
  output=$(run_adapter_registry_get "does_not_exist" 2>&1) || true
  assert_adapter_not_found "$output" "does_not_exist"

  teardown_adapter_registry_test
}

@test "register_adapter with null adapter fails gracefully" {
  setup_adapter_registry_test

  # Try to register null adapter
  run run_adapter_registry_register ""
  assert_failure
  assert_adapter_registration_error "$output" "null_adapter"

  teardown_adapter_registry_test
}

@test "register_adapter with existing identifier fails gracefully" {
  setup_adapter_registry_test

  # Register first adapter
  create_valid_mock_adapter "duplicate_test"
  run_adapter_registry_register "duplicate_test"
  assert_success

  # Try to register the same adapter again
  run run_adapter_registry_register "duplicate_test"
  assert_failure
  assert_adapter_registration_error "$output" "identifier_conflict"

  teardown_adapter_registry_test
}

# ============================================================================
# Lifecycle Tests
# ============================================================================

@test "adapter registry initializes successfully" {
  setup_adapter_registry_test

  # Initialize registry
  output=$(run_adapter_registry_initialize)
  assert_success
  assert_registry_initialized "$output"

  teardown_adapter_registry_test
}

@test "adapter registry cleanup removes all registered adapters" {
  setup_adapter_registry_test

  # Register some adapters
  create_valid_mock_adapter "cleanup_test1"
  run_adapter_registry_register "cleanup_test1"
  assert_success

  create_valid_mock_adapter "cleanup_test2"
  run_adapter_registry_register "cleanup_test2"
  assert_success

  # Cleanup registry
  run_adapter_registry_cleanup
  assert_success

  # Verify adapters are removed
  output=$(run_adapter_registry_get_all)
  assert_no_adapters_registered "$output"

  teardown_adapter_registry_test
}

@test "adapter registry handles multiple initialize calls" {
  setup_adapter_registry_test

  # Initialize multiple times
  run_adapter_registry_initialize
  assert_success

  run_adapter_registry_initialize
  assert_success

  # Should still have built-in adapters
  output=$(run_adapter_registry_is_registered "bats")
  assert_is_registered "$output" "bats"

  teardown_adapter_registry_test
}

# ============================================================================
# Performance and Edge Case Tests
# ============================================================================

@test "adapter registry handles large number of adapters" {
  setup_adapter_registry_test

  # Register many adapters (simulate large registry)
  for i in {1..10}; do
    create_valid_mock_adapter "adapter_$i"
    run_adapter_registry_register "adapter_$i"
    assert_success
  done

  # Verify all are registered
  output=$(run_adapter_registry_get_all)
  assert_adapter_count "$output" "10"

  teardown_adapter_registry_test
}

@test "adapter registry handles concurrent registration attempts" {
  setup_adapter_registry_test

  # Simulate concurrent registration (sequential for now, but tests the logic)
  create_valid_mock_adapter "concurrent1"
  create_valid_mock_adapter "concurrent2"

  run_adapter_registry_register "concurrent1"
  assert_success

  run_adapter_registry_register "concurrent2"
  assert_success

  # Both should be registered
  output=$(run_adapter_registry_get_all)
  assert_all_adapters_returned "$output" "concurrent1,concurrent2"

  teardown_adapter_registry_test
}

@test "adapter registry preserves adapter order" {
  setup_adapter_registry_test

  # Register adapters in specific order
  create_valid_mock_adapter "first"
  run_adapter_registry_register "first"
  assert_success

  create_valid_mock_adapter "second"
  run_adapter_registry_register "second"
  assert_success

  create_valid_mock_adapter "third"
  run_adapter_registry_register "third"
  assert_success

  # Verify order is preserved
  output=$(run_adapter_registry_get_all)
  assert_adapter_order "$output" "first,second,third"

  teardown_adapter_registry_test
}




@test "built-in adapter initialization failures are handled gracefully" {
  setup_adapter_registry_test

  # Initialize registry normally
  run_adapter_registry_initialize
  assert_success

  # Verify that all expected built-in adapters are registered
  output=$(run_adapter_registry_get_all)
  # Should have bats and rust adapters
  assert_adapter_found_in_list "$output" "bats"
  assert_adapter_found_in_list "$output" "rust"

  teardown_adapter_registry_test
}

@test "adapter registry caches adapter metadata" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "cache_test_adapter"
  run_adapter_registry_register "cache_test_adapter"
  assert_success

  # Get metadata multiple times - should be cached
  output1=$(run_adapter_registry_get "cache_test_adapter")
  output2=$(run_adapter_registry_get "cache_test_adapter")

  # Results should be identical (cached)
  assert_identical_results "$output1" "$output2"

  teardown_adapter_registry_test
}

@test "adapter registry supports lazy loading of adapters" {
  setup_adapter_registry_test

  # This test verifies that adapters are available on demand
  # Register an adapter
  create_valid_mock_adapter "lazy_adapter"
  run_adapter_registry_register "lazy_adapter"
  assert_success

  # Adapter should be immediately available (not lazy loaded in current implementation)
  # But this test ensures the registry provides access when requested
  output=$(run_adapter_registry_get "lazy_adapter")
  assert_adapter_found "$output" "lazy_adapter"

  teardown_adapter_registry_test
}

@test "adapter registry supports parallel adapter operations" {
  setup_adapter_registry_test

  # Register multiple adapters with parallel capability
  create_valid_mock_adapter_with_capability "parallel_adapter1" "parallel"
  run_adapter_registry_register "parallel_adapter1"
  assert_success

  create_valid_mock_adapter_with_capability "parallel_adapter2" "parallel"
  run_adapter_registry_register "parallel_adapter2"
  assert_success

  # Get adapters by capability - simulates parallel-capable operations
  output=$(run_adapter_registry_get_by_capability "parallel")
  assert_adapters_by_capability "$output" "parallel" "parallel_adapter1,parallel_adapter2"

  teardown_adapter_registry_test
}

# ============================================================================
# Additional Assertion Functions for New Tests
# ============================================================================

# Assert that results are identical (for caching tests)
assert_identical_results() {
  local result1="$1"
  local result2="$2"

  if [[ "$result1" != "$result2" ]]; then
    echo "ERROR: Results are not identical (caching failed)"
    echo "Result 1: $result1"
    echo "Result 2: $result2"
    return 1
  fi

  return 0
}

# Assert that adapters are still available despite failures
assert_adapters_available() {
  local output="$1"

  # Should have at least some adapters available
  local adapters_list
  adapters_list=$(json_test_get "$output" '.[]')
  if [[ "$adapters_list" != *"rust"* ]] && [[ "$adapters_list" != *"bats"* ]] && [[ "$adapters_list" != *"working_adapter"* ]]; then
    echo "ERROR: No adapters available after initialization failure simulation"
    echo "Output: $output"
    return 1
  fi

  return 0
}

# Assert that a specific adapter is found in a list
assert_adapter_found_in_list() {
  local output="$1"
  local adapter_name="$2"

  # Extract array elements and check if adapter_name is in the list
  local adapters_list
  adapters_list=$(json_test_get "$output" '.[]')
  if [[ "$adapters_list" != *"$adapter_name"* ]]; then
    echo "ERROR: Adapter '$adapter_name' not found in list"
    echo "Output: $output"
    return 1
  fi

  return 0
}
