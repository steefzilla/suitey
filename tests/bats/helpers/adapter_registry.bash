#!/usr/bin/env bash
# Helper functions for Adapter Registry tests

# ============================================================================
# Setup/Teardown Functions
# ============================================================================

# Create a temporary directory for Adapter Registry testing
setup_adapter_registry_test() {
  local test_name="${1:-adapter_registry_test}"
  TEST_ADAPTER_REGISTRY_DIR=$(mktemp -d -t "suitey_adapter_test_${test_name}_XXXXXX")
  export TEST_ADAPTER_REGISTRY_DIR
  echo "$TEST_ADAPTER_REGISTRY_DIR"
}

# Clean up temporary directory and registry state
teardown_adapter_registry_test() {
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -d "$TEST_ADAPTER_REGISTRY_DIR" ]]; then
    rm -rf "$TEST_ADAPTER_REGISTRY_DIR"
    unset TEST_ADAPTER_REGISTRY_DIR
  fi

  # Clean up registry state files
  rm -f /tmp/suitey_adapter_registry /tmp/suitey_adapter_capabilities /tmp/suitey_adapter_order /tmp/suitey_adapter_init
  # Clean up any test directories that might be left
  find /tmp -maxdepth 1 -name "suitey_adapter_test_*" -type d -exec rm -rf {} + 2>/dev/null || true
}

# ============================================================================
# Mock Adapter Creation Functions
# ============================================================================

# Create a valid mock adapter with all required interface methods
create_valid_mock_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter script with all required interface methods
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Mock adapter for testing - $adapter_identifier

# Required interface methods
${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  # Mock detection logic - always succeeds for testing
  return 0
}

${adapter_identifier}_adapter_get_metadata() {
  echo '{"name": "Test Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}'
}

${adapter_identifier}_adapter_check_binaries() {
  # Mock binary check - assume available
  return 0
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[
  {
    "name": "${adapter_identifier}_suite",
    "framework": "$adapter_identifier",
    "test_files": ["test_file.txt"],
    "metadata": {},
    "execution_config": {}
  }
]
SUITES_EOF
}

${adapter_identifier}_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << BUILD_EOF
{
  "requires_build": false,
  "build_steps": [],
  "build_commands": [],
  "build_dependencies": [],
  "build_artifacts": []
}
BUILD_EOF
}

${adapter_identifier}_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"

  cat << STEPS_EOF
[]
STEPS_EOF
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.5,
  "output": "Mock test output",
  "container_id": "mock_container",
  "execution_method": "mock"
}
EXEC_EOF
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"

  cat << RESULTS_EOF
{
  "total_tests": 5,
  "passed_tests": 5,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  # Source the mock adapter to make functions available
  source "$adapter_dir/adapter.sh"
}

# Create a valid mock adapter with specific capabilities
create_valid_mock_adapter_with_capability() {
  local adapter_identifier="$1"
  local capability="$2"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter script with custom capabilities
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Mock adapter with capability - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}

${adapter_identifier}_adapter_get_metadata() {
  echo '{"name": "Capability Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["'$capability'"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}'
}

${adapter_identifier}_adapter_check_binaries() {
  return 0
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[
  {
    "name": "${adapter_identifier}_suite",
    "framework": "$adapter_identifier",
    "test_files": ["test_file.txt"],
    "metadata": {},
    "execution_config": {}
  }
]
SUITES_EOF
}

${adapter_identifier}_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << BUILD_EOF
{
  "requires_build": false,
  "build_steps": [],
  "build_commands": [],
  "build_dependencies": [],
  "build_artifacts": []
}
BUILD_EOF
}

${adapter_identifier}_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"

  cat << STEPS_EOF
[]
STEPS_EOF
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.5,
  "output": "Mock test output",
  "container_id": "mock_container",
  "execution_method": "mock"
}
EXEC_EOF
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"

  cat << RESULTS_EOF
{
  "total_tests": 5,
  "passed_tests": 5,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# Create an invalid mock adapter missing required methods
create_invalid_mock_adapter() {
  local adapter_identifier="$1"
  local missing_method="$2"  # Optional: specify which method to omit
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # If missing_method not specified, infer from adapter_identifier
  if [[ -z "$missing_method" ]]; then
    case "$adapter_identifier" in
      *missing_detect*)
        missing_method="detect"
        ;;
      *missing_discover*)
        missing_method="discover"
        ;;
      *missing_metadata*)
        missing_method="metadata"
        ;;
      *)
        missing_method="discover"  # Default: miss discover
        ;;
    esac
  fi

  # Create mock adapter script missing some methods
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Invalid mock adapter - $adapter_identifier

# Include some methods but miss others
${adapter_identifier}_adapter_check_binaries() {
  return 0
}
EOF

  # Add methods conditionally based on what's missing
  case "$missing_method" in
    "detect")
      # Add metadata and check_binaries but miss detect
      cat >> "$adapter_dir/adapter.sh" << EOF
${adapter_identifier}_adapter_get_metadata() {
  echo '{"name": "Invalid Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}';
}
EOF
      ;;
    "discover")
      # Add metadata and detect but miss discover
      cat >> "$adapter_dir/adapter.sh" << EOF
${adapter_identifier}_adapter_get_metadata() {
  echo '{"name": "Invalid Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}';
}
${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}
EOF
      ;;
    "metadata")
      # Add detect but miss metadata
      cat >> "$adapter_dir/adapter.sh" << EOF
${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}
EOF
      ;;
    *)
      # Add metadata and detect but miss discover
      cat >> "$adapter_dir/adapter.sh" << EOF
${adapter_identifier}_adapter_get_metadata() {
  echo '{"name": "Invalid Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}';
}
${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}
EOF
      ;;
  esac

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# Create a complete mock adapter with all interface methods
create_complete_mock_adapter() {
  local adapter_identifier="$1"

  # Same as valid adapter - all methods present
  create_valid_mock_adapter "$adapter_identifier"
}

# Create an adapter with invalid metadata
create_invalid_metadata_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter script with invalid metadata
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Invalid metadata adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}

${adapter_identifier}_adapter_get_metadata() {
  # Invalid JSON metadata (missing required fields)
  echo '{"invalid": "metadata"}'
}

${adapter_identifier}_adapter_check_binaries() {
  return 0
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[]
SUITES_EOF
}

${adapter_identifier}_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << BUILD_EOF
{
  "requires_build": false
}
BUILD_EOF
}

${adapter_identifier}_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"

  cat << STEPS_EOF
[]
STEPS_EOF
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.0,
  "output": "Mock output",
  "container_id": null,
  "execution_method": "mock"
}
EXEC_EOF
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"

  cat << RESULTS_EOF
{
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# ============================================================================
# Adapter Registry Function Wrappers
# ============================================================================

# Call adapter registry functions
run_adapter_registry_register() {
  local adapter_identifier="$1"

  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function and capture both stdout and stderr
  adapter_registry_register "$adapter_identifier" 2>&1
  return $?
}

run_adapter_registry_get() {
  local adapter_identifier="$1"

  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_get "$adapter_identifier"
}

run_adapter_registry_get_all() {
  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_get_all
}

run_adapter_registry_is_registered() {
  local adapter_identifier="$1"

  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_is_registered "$adapter_identifier"
}

run_adapter_registry_get_by_capability() {
  local capability="$1"

  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_get_adapters_by_capability "$capability"
}

run_adapter_registry_initialize() {
  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_initialize
}

run_adapter_registry_cleanup() {
  # Source suitey.sh to make functions available
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script to make functions available
  source "$suitey_script"

  # Call the function
  adapter_registry_cleanup
}

# ============================================================================
# Basic BATS Assertions (for compatibility)
# ============================================================================

# Assert that the last command succeeded
assert_success() {
  local exit_code=${status:-$?}
  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: Expected command to succeed, but it failed" >&2
    return 1
  fi
  return 0
}

# Assert that the last command failed
assert_failure() {
  local exit_code=${status:-$?}
  if [[ $exit_code -eq 0 ]]; then
    echo "ERROR: Expected command to fail, but it succeeded" >&2
    return 1
  fi
  return 0
}

# ============================================================================
# Assertion Helpers
# ============================================================================

# Assert that adapter registration succeeded
assert_adapter_registration_success() {
  local output="$1"
  if [[ -z "$output" ]] || echo "$output" | grep -q "ERROR\|error\|failed\|Failed"; then
    echo "ERROR: Expected successful adapter registration"
    echo "Output was: $output"
    return 1
  fi
  return 0
}

# Assert that adapter registration failed with specific error
assert_adapter_registration_error() {
  local output="$1"
  local error_type="$2"

  case "$error_type" in
    "identifier_conflict")
      if ! echo "$output" | grep -q "identifier.*conflict\|already.*registered"; then
        echo "ERROR: Expected identifier conflict error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "invalid_interface")
      if ! echo "$output" | grep -q "invalid.*interface\|missing.*method"; then
        echo "ERROR: Expected invalid interface error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "invalid_metadata")
      if ! echo "$output" | grep -q "invalid.*metadata\|missing.*field"; then
        echo "ERROR: Expected invalid metadata error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "null_adapter")
      if ! echo "$output" | grep -q "null.*adapter\|empty.*identifier"; then
        echo "ERROR: Expected null adapter error"
        echo "Output was: $output"
        return 1
      fi
      ;;
  esac

  return 0
}

# Assert that adapter was found
assert_adapter_found() {
  local output="$1"
  local adapter_identifier="$2"

  if echo "$output" | grep -q "not.*found\|null\|empty"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to be found"
    echo "Output was: $output"
    return 1
  fi

  if ! echo "$output" | grep -q "$adapter_identifier"; then
    echo "ERROR: Expected adapter identifier '$adapter_identifier' in output"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert that adapter was not found
assert_adapter_not_found() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "not.*found\|null\|empty"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to not be found"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert that all expected adapters are returned
assert_all_adapters_returned() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' in results"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert adapter is registered
assert_is_registered() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "true\|registered\|found"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to be registered"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter is not registered
assert_is_not_registered() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "false\|not.*registered\|not.*found"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to not be registered"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapters returned by capability
assert_adapters_by_capability() {
  local output="$1"
  local capability="$2"
  local expected_adapters="$3"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' with capability '$capability' in results"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert adapter metadata
assert_adapter_metadata() {
  local output="$1"
  local adapter_identifier="$2"
  local field="$3"
  local expected_value="$4"

  if ! echo "$output" | grep -q "\"$field\".*\"$expected_value\""; then
    echo "ERROR: Expected metadata field '$field' with value '$expected_value' for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter metadata structure
assert_adapter_metadata_structure() {
  local output="$1"
  local adapter_identifier="$2"

  local required_fields=("name" "identifier" "version" "supported_languages" "capabilities" "required_binaries")

  for field in "${required_fields[@]}"; do
    if ! echo "$output" | grep -q "\"$field\""; then
      echo "ERROR: Expected required metadata field '$field' for adapter '$adapter_identifier'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert adapter capabilities
assert_adapter_capabilities() {
  local output="$1"
  local adapter_identifier="$2"
  local expected_capability="$3"

  if ! echo "$output" | grep -q "\"capabilities\".*\"$expected_capability\""; then
    echo "ERROR: Expected capability '$expected_capability' for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert built-in adapters are present
assert_builtin_adapters_present() {
  local output="$1"

  local builtin_adapters=("bats" "rust")

  for adapter in "${builtin_adapters[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected built-in adapter '$adapter' to be present"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert registry initialized
assert_registry_initialized() {
  local output="$1"

  if echo "$output" | grep -q "ERROR\|error\|failed\|Failed"; then
    echo "ERROR: Expected registry initialization to succeed"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert no adapters registered
assert_no_adapters_registered() {
  local output="$1"

  if echo "$output" | grep -q "bats\|rust\|test_adapter"; then
    echo "ERROR: Expected no adapters to be registered after cleanup"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter count
assert_adapter_count() {
  local output="$1"
  local expected_count="$2"

  # Count occurrences of "adapter_" in the JSON output
  local count=0
  count=$(echo "$output" | grep -o '"adapter_[^"]*"' | wc -l)

  if [[ $count -ne $expected_count ]]; then
    echo "ERROR: Expected $expected_count adapters, found $count"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter order
assert_adapter_order() {
  local output="$1"
  local expected_order="$2"

  # Check that adapters appear in expected order
  local adapters_found=""
  while IFS= read -r line; do
    for adapter in first second third; do
      if echo "$line" | grep -q "$adapter" && ! echo "$adapters_found" | grep -q "$adapter"; then
        adapters_found="${adapters_found:+$adapters_found,}$adapter"
      fi
    done
  done <<< "$output"

  if [[ "$adapters_found" != "$expected_order" ]]; then
    echo "ERROR: Expected adapter order '$expected_order', found '$adapters_found'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}
