#!/usr/bin/env bash
# Helper functions for Adapter Registry tests

# ============================================================================
# Source the adapter registry helpers module
# ============================================================================

# Find and source adapter_registry_helpers.sh
adapter_registry_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
  adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
  adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
else
  adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
fi

source "$adapter_registry_helpers_script"

# ============================================================================
# JSON Helper Functions (will be replaced with shared helpers in Phase 2)
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

json_test_field_contains() {
  local json="$1"
  local field="$2"
  local value="$3"
  echo "$json" | jq -r ".$field" 2>/dev/null | grep -q "$value" 2>/dev/null
}

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
[
  {
    "step_name": "build",
    "docker_image": "test:latest",
    "install_dependencies_command": "",
    "build_command": "echo 'build command'",
    "working_directory": "/workspace",
    "volume_mounts": [],
    "environment_variables": {},
    "cpu_cores": null
  }
]
STEPS_EOF
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local test_image="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.5,
  "output": "Mock test output",
  "container_id": "mock_container",
  "execution_method": "mock",
  "test_image": "\${test_image:-}"
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
[
  {
    "step_name": "build",
    "docker_image": "test:latest",
    "install_dependencies_command": "",
    "build_command": "echo 'build command'",
    "working_directory": "/workspace",
    "volume_mounts": [],
    "environment_variables": {},
    "cpu_cores": null
  }
]
STEPS_EOF
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local test_image="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.5,
  "output": "Mock test output",
  "container_id": "mock_container",
  "execution_method": "mock",
  "test_image": "\${test_image:-}"
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
[
  {
    "step_name": "build",
    "docker_image": "test:latest",
    "install_dependencies_command": "",
    "build_command": "echo 'build command'",
    "working_directory": "/workspace",
    "volume_mounts": [],
    "environment_variables": {},
    "cpu_cores": null
  }
]
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

  # Source the adapter script if it exists
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"
  if [[ -f "$adapter_dir/adapter.sh" ]]; then
    source "$adapter_dir/adapter.sh"
  fi

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
  if [[ -z "$output" ]] || echo "$output" | grep -iE -q "ERROR|error|failed"; then
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
      if ! echo "$output" | grep -E -q "identifier.*conflict|already.*registered"; then
        echo "ERROR: Expected identifier conflict error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "invalid_interface")
      if ! echo "$output" | grep -E -q "invalid.*interface|missing.*method"; then
        echo "ERROR: Expected invalid interface error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "invalid_metadata")
      if ! echo "$output" | grep -E -q "invalid.*metadata|missing.*field"; then
        echo "ERROR: Expected invalid metadata error"
        echo "Output was: $output"
        return 1
      fi
      ;;
    "null_adapter")
      if ! echo "$output" | grep -E -q "null.*adapter|empty.*identifier"; then
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

  if echo "$output" | grep -E -q "not.*found|null|empty"; then
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

  if ! echo "$output" | grep -E -q "not.*found|null|empty"; then
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

  if ! echo "$output" | grep -E -q "true|registered|found"; then
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

  if ! echo "$output" | grep -E -q "false|not.*registered|not.*found"; then
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

  if ! json_test_field_contains "$output" "$field" "$expected_value"; then
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
    if ! json_test_has_field "$output" "$field"; then
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

  if ! json_test_field_contains "$output" "capabilities" "$expected_capability"; then
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

  if echo "$output" | grep -iE -q "ERROR|error|failed"; then
    echo "ERROR: Expected registry initialization to succeed"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert no adapters registered
assert_no_adapters_registered() {
  local output="$1"

  if echo "$output" | grep -E -q "bats|rust|test_adapter"; then
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
# ============================================================================
# Error Handling and Performance Test Helpers
# ============================================================================

# Create an adapter that fails during method calls
create_failing_method_adapter() {
  local adapter_identifier="$1"
  local failing_method="${2:-get_metadata}"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create a complete adapter script
  cat > "$adapter_dir/adapter.sh" << 'ADAPTER_EOF'
#!/usr/bin/env bash

# Failing method adapter
ADAPTER_EOF

  # Add the adapter identifier
  echo "# Adapter: $adapter_identifier" >> "$adapter_dir/adapter.sh"

  # Add the detect method
  echo "" >> "$adapter_dir/adapter.sh"
  echo "${adapter_identifier}_adapter_detect() {" >> "$adapter_dir/adapter.sh"
  echo '  local project_root="$1"' >> "$adapter_dir/adapter.sh"
  echo '  echo '\''{"detected": true, "confidence": "high", "indicators": ["test"], "metadata": {}}'\' >> "$adapter_dir/adapter.sh"
  echo "}" >> "$adapter_dir/adapter.sh"

  # Add check_binaries method
  echo "" >> "$adapter_dir/adapter.sh"
  echo "${adapter_identifier}_adapter_check_binaries() {" >> "$adapter_dir/adapter.sh"
  echo '  echo "true"' >> "$adapter_dir/adapter.sh"
  echo "}" >> "$adapter_dir/adapter.sh"

  # Add get_metadata method
  echo "" >> "$adapter_dir/adapter.sh"
  echo "${adapter_identifier}_adapter_get_metadata() {" >> "$adapter_dir/adapter.sh"
  if [[ "$failing_method" == "get_metadata" ]]; then
    echo '  # This method fails' >> "$adapter_dir/adapter.sh"
    echo '  echo "ERROR: Get metadata method failed" >&2' >> "$adapter_dir/adapter.sh"
    echo '  return 1' >> "$adapter_dir/adapter.sh"
  else
    echo '  echo '\''{"name": "Failing Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["bash"], "capabilities": ["testing"], "required_binaries": [], "configuration_files": [], "test_file_patterns": ["*.bats"]}'\' >> "$adapter_dir/adapter.sh"
  fi
  echo "}" >> "$adapter_dir/adapter.sh"

  # Add the rest of the methods
  cat >> "$adapter_dir/adapter.sh" << ADAPTER_EOF

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[
  {
    "name": "failing_suite",
    "framework": "test",
    "test_files": ["test.txt"],
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

  echo "[]"
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 1,
  "duration": 1.0,
  "output": "Test failed",
  "container_id": null,
  "execution_method": "failed"
}
EXEC_EOF
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"

  cat << RESULTS_EOF
{
  "total_tests": 1,
  "passed_tests": 0,
  "failed_tests": 1,
  "skipped_tests": 0,
  "test_details": [],
  "status": "failed"
}
RESULTS_EOF
}
ADAPTER_EOF
}
# Create a completely failing adapter
create_failing_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create a complete adapter script that fails on all methods
  cat > "$adapter_dir/adapter.sh" << 'ADAPTER_EOF'
#!/usr/bin/env bash

# Failing adapter
ADAPTER_EOF

  # Add the adapter identifier
  echo "# Adapter: $adapter_identifier" >> "$adapter_dir/adapter.sh"

  # Add all the failing methods
  cat >> "$adapter_dir/adapter.sh" << ADAPTER_EOF

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  echo "ERROR: Adapter detect failed" >&2
  return 1
}

${adapter_identifier}_adapter_check_binaries() {
  echo "false"
}

${adapter_identifier}_adapter_get_metadata() {
  echo "ERROR: Adapter get_metadata failed" >&2
  return 1
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo "ERROR: Adapter discover_test_suites failed" >&2
  return 1
}

${adapter_identifier}_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo "ERROR: Adapter detect_build_requirements failed" >&2
  return 1
}

${adapter_identifier}_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo "ERROR: Adapter get_build_steps failed" >&2
  return 1
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"
  echo "ERROR: Adapter execute_test_suite failed" >&2
  return 1
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"
  echo "ERROR: Adapter parse_test_results failed" >&2
  return 1
}
ADAPTER_EOF
}

# Create an adapter that returns invalid data
create_invalid_return_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create a complete adapter script that returns invalid JSON for metadata
  cat > "$adapter_dir/adapter.sh" << 'ADAPTER_EOF'
#!/usr/bin/env bash

# Invalid return adapter
ADAPTER_EOF

  # Add the adapter identifier
  echo "# Adapter: $adapter_identifier" >> "$adapter_dir/adapter.sh"

  # Add all the methods
  cat >> "$adapter_dir/adapter.sh" << ADAPTER_EOF

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  echo '{"detected": true, "confidence": "high", "indicators": ["test"], "metadata": {}}'
}

${adapter_identifier}_adapter_check_binaries() {
  echo "true"
}

${adapter_identifier}_adapter_get_metadata() {
  # Return invalid JSON
  echo '{"name": "test", "identifier": invalid json structure}'
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[
  {
    "name": "invalid_suite",
    "framework": "test",
    "test_files": ["test.txt"],
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

  echo "[]"
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.0,
  "output": "Test passed",
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
  "total_tests": 1,
  "passed_tests": 1,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}
ADAPTER_EOF
}

# Create an adapter that times out during method calls
create_timeout_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << ADAPTER_EOF
#!/usr/bin/env bash

# Timeout adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  echo '{"detected": true, "confidence": "high", "indicators": ["test"], "metadata": {}}'
}

${adapter_identifier}_adapter_check_binaries() {
  echo "true"
}

${adapter_identifier}_adapter_get_metadata() {
  # Simulate timeout by sleeping (but keep it short for tests)
  sleep 0.1
  echo '{"name": "Timeout Adapter", "identifier": "'$adapter_identifier'", "version": "1.0.0", "supported_languages": ["test"], "capabilities": ["testing"], "required_binaries": [], "configuration_files": [], "test_file_patterns": ["*.test"], "test_directory_patterns": ["tests/"]}'
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"

  cat << SUITES_EOF
[
  {
    "name": "timeout_suite",
    "framework": "test",
    "test_files": ["test.txt"],
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

  echo "[]"
}

${adapter_identifier}_adapter_execute_test_suite() {
  local test_suite="\$1"
  local build_artifacts="\$2"
  local execution_config="\$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.0,
  "output": "Test passed",
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
  "total_tests": 1,
  "passed_tests": 1,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}
ADAPTER_EOF
}

# ============================================================================
# Error Handling and Performance Test Assertions
# ============================================================================

# Assert method call failure handled
assert_method_call_failure_handled() {
  local output="$1"

  # Should indicate the failure was handled
  if ! echo "$output" | grep -iE -q "ERROR|failed|Method call failed"; then
    echo "ERROR: Expected method call failure to be indicated"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert invalid return value handled
assert_invalid_return_value_handled() {
  local output="$1"

  # Should handle invalid JSON gracefully
  if echo "$output" | grep -E -q "fatal|crash"; then
    echo "ERROR: Invalid return value should not cause crash"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert graceful degradation
assert_graceful_degradation() {
  local output="$1"
  local expected_adapters="$2"

  # Should contain both working and failing adapters
  for adapter in $(echo "$expected_adapters" | tr ',' ' '); do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' in output despite failures"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert initialization failure handled
assert_initialization_failure_handled() {
  local output="$1"

  # Should indicate initialization failure was handled
  if ! echo "$output" | grep -iE -q "failed|error|initialization"; then
    echo "ERROR: Expected initialization failure to be indicated"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert empty adapter list
assert_empty_adapter_list() {
  local output="$1"

  if ! echo "$output" | grep -q "\[\]"; then
    echo "ERROR: Expected empty adapter list"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter list contains
assert_adapter_list_contains() {
  local output="$1"
  local expected_adapter="$2"

  if ! echo "$output" | grep -q "$expected_adapter"; then
    echo "ERROR: Expected adapter '$expected_adapter' in list"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert metadata cached
assert_metadata_cached() {
  local output1="$1"
  local output2="$2"

  if [[ "$output1" != "$output2" ]]; then
    echo "ERROR: Expected cached metadata to be identical"
    echo "Output1: $output1"
    echo "Output2: $output2"
    return 1
  fi

  return 0
}

# Assert parallel operations supported
assert_parallel_operations_supported() {
  local output="$1"
  local expected_adapters="$2"

  # Should contain all expected adapters
  for adapter in $(echo "$expected_adapters" | tr ',' ' '); do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' in parallel operations"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert timeout handled
assert_timeout_handled() {
  local output="$1"

  # Should handle timeout gracefully without crashing
  if echo "$output" | grep -E -q "fatal|crash"; then
    echo "ERROR: Timeout should not cause crash"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert resource exhaustion handled
assert_resource_exhaustion_handled() {
  local output="$1"

  # Should handle many adapters without crashing
  if echo "$output" | grep -E -q "fatal|crash|resource.*exhausted"; then
    echo "ERROR: Resource exhaustion should be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should contain many adapters
  local adapter_count=$(echo "$output" | grep -o '"resource_adapter_[0-9]*"' | wc -l)
  if [[ $adapter_count -lt 15 ]]; then
    echo "ERROR: Expected many adapters to be registered"
    echo "Found $adapter_count adapters"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert concurrent access handled
assert_concurrent_access_handled() {
  local output1="$1"
  local output2="$2"
  local output3="$3"

  # All operations should have succeeded
  if [[ -z "$output1" ]] || [[ -z "$output2" ]] || [[ -z "$output3" ]]; then
    echo "ERROR: Concurrent operations should all succeed"
    echo "Output1: $output1"
    echo "Output2: $output2"
    echo "Output3: $output3"
    return 1
  fi

  return 0
}

# ============================================================================
# Build Manager Interface Validation Helpers
# ============================================================================

# Assert build steps contain install_dependencies_command
assert_build_steps_has_install_dependencies() {
  local build_steps_json="$1"

  if ! json_test_has_field "$build_steps_json" "install_dependencies_command"; then
    echo "ERROR: Expected install_dependencies_command field in build steps"
    echo "Build steps: $build_steps_json"
    return 1
  fi

  return 0
}

# Assert build steps contain cpu_cores
assert_build_steps_has_cpu_cores() {
  local build_steps_json="$1"

  if ! json_test_has_field "$build_steps_json" "cpu_cores"; then
    echo "ERROR: Expected cpu_cores field in build steps"
    echo "Build steps: $build_steps_json"
    return 1
  fi

  return 0
}

# Assert build command supports parallel builds
assert_build_command_parallel() {
  local build_steps_json="$1"

  jobs_value=$(json_test_get "$build_steps_json" '.build_command')
  if [[ "$jobs_value" != *'jobs $(nproc)'* ]]; then
    echo "ERROR: Expected parallel build command with --jobs \$(nproc)"
    echo "Build steps: $build_steps_json"
    return 1
  fi

  return 0
}

# Assert build steps is empty array
assert_build_steps_empty_array() {
  local build_steps_json="$1"

  if [[ "$build_steps_json" != "[]" ]]; then
    echo "ERROR: Expected empty array for build steps"
    echo "Build steps: $build_steps_json"
    return 1
  fi

  return 0
}

# Assert execution succeeded (has valid exit_code)
assert_execution_succeeded() {
  local execution_result_json="$1"

  if ! json_test_has_field "$execution_result_json" "exit_code"; then
    echo "ERROR: Expected exit_code field in execution result"
    echo "Execution result: $execution_result_json"
    return 1
  fi

  return 0
}

# Assert execution result contains test_image
assert_execution_result_has_test_image() {
  local execution_result_json="$1"

  if ! json_test_has_field "$execution_result_json" "test_image"; then
    echo "ERROR: Expected test_image field in execution result"
    echo "Execution result: $execution_result_json"
    return 1
  fi

  return 0
}

# Assert execution result does not contain build_artifacts
assert_execution_result_no_build_artifacts() {
  local execution_result_json="$1"

  if json_test_has_field "$execution_result_json" "build_artifacts"; then
    echo "ERROR: Should not contain build_artifacts field in execution result"
    echo "Execution result: $execution_result_json"
    return 1
  fi

  return 0
}

# Assert build steps JSON is valid
assert_build_steps_valid_json() {
  local build_steps_json="$1"

  # Check for required fields
  local required_fields=("step_name" "docker_image" "install_dependencies_command" "build_command" "working_directory" "volume_mounts" "environment_variables" "cpu_cores")

  for field in "${required_fields[@]}"; do
    if ! json_test_has_field "$build_steps_json" "$field"; then
      echo "ERROR: Missing required field '$field' in build steps JSON"
      echo "Build steps: $build_steps_json"
      return 1
    fi
  done

  return 0
}

# Assert execution result JSON is valid
assert_execution_result_valid_json() {
  local execution_result_json="$1"

  # Check for required fields
  local required_fields=("exit_code" "duration" "output" "container_id" "execution_method" "test_image")

  for field in "${required_fields[@]}"; do
    if ! json_test_has_field "$execution_result_json" "$field"; then
      echo "ERROR: Missing required field '$field' in execution result JSON"
      echo "Execution result: $execution_result_json"
      return 1
    fi
  done

  return 0
}

# Assert project scanner handles build requirements
assert_project_scanner_handles_build_requirements() {
  local output="$1"
  
  # Should not contain build requirement errors
  if echo "$output" | grep -iE -q "ERROR.*build|build.*failed|build.*error"; then
    echo "ERROR: Expected project scanner to handle build requirements"
    echo "Output was: $output"
    return 1
  fi
  
  return 0
}

# Assert project scanner passes test_image to adapters
assert_project_scanner_passes_test_image() {
  local output="$1"
  
  # Should indicate test_image parameter was passed
  if ! echo "$output" | grep -E -q "test_image|image.*passed"; then
    echo "ERROR: Expected test_image parameter to be passed to adapters"
    echo "Output was: $output"
    return 1
  fi
  
  return 0
}

# Assert project scanner integrates build steps
assert_project_scanner_integrates_build_steps() {
  local output="$1"
  
  # Should show build steps integration
  if ! echo "$output" | grep -E -q "build.*step|step.*build|build.*integration"; then
    echo "ERROR: Expected build steps integration"
    echo "Output was: $output"
    return 1
  fi
  
  return 0
}

# Assert project scanner validates interfaces
assert_project_scanner_validates_interfaces() {
  local output="$1"
  
  # Should validate adapter interfaces
  if ! echo "$output" | grep -E -q "interface|validated|compatibility"; then
    echo "ERROR: Expected interface validation"
    echo "Output was: $output"
    return 1
  fi
  
  return 0
}
