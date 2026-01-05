#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry
load ../helpers/framework_detector
load ../helpers/fixtures

# Source suitey.sh to get all functions
# Try multiple possible locations using BATS_TEST_DIRNAME
if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
  source "$BATS_TEST_DIRNAME/../../../suitey.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
  source "$BATS_TEST_DIRNAME/../../suitey.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../../../suitey.sh" ]]; then
  source "$BATS_TEST_DIRNAME/../../../../suitey.sh"
else
  # Fallback: try to find it from the workspace root
  suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  if [[ -f "$suitey_script" ]]; then
    source "$suitey_script"
  else
    echo "ERROR: Could not find suitey.sh" >&2
    exit 1
  fi
fi

# Enable integration test mode for real Docker operations
export SUITEY_INTEGRATION_TEST=1

# ============================================================================
# Framework Detector - Adapter Registry Integration Tests
# ============================================================================

@test "Framework Detector accesses adapters from registry" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Initialize registry with built-in adapters
  run_adapter_registry_initialize

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector (should use registry)
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have accessed registry adapters
  assert_framework_detector_used_registry "$output"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector calls detect method on registered adapters" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register a mock adapter
  create_valid_mock_adapter "mock_detector_adapter"
  run_adapter_registry_register "mock_detector_adapter"

  # Create a test project that the mock adapter should detect
  create_project_with_pattern "$TEST_PROJECT_DIR" "mock_pattern"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have called detect method on mock adapter
  assert_adapter_detect_method_called "$output" "mock_detector_adapter"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector calls check_binaries method on detected adapters" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register a mock adapter
  create_valid_mock_adapter "binary_check_adapter"
  run_adapter_registry_register "binary_check_adapter"

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have called check_binaries method
  assert_adapter_binary_check_called "$output" "binary_check_adapter"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector aggregates detection results from multiple adapters" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register multiple mock adapters
  create_valid_mock_adapter "multi_adapter1"
  run_adapter_registry_register "multi_adapter1"

  create_valid_mock_adapter "multi_adapter2"
  run_adapter_registry_register "multi_adapter2"

  # Create a test project that multiple adapters detect
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have aggregated results from both adapters
  assert_multiple_adapter_results_aggregated "$output" "multi_adapter1,multi_adapter2"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector handles adapter detection failures gracefully" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register a mock adapter that fails detection
  create_failing_mock_adapter "failing_adapter"
  run_adapter_registry_register "failing_adapter"

  # Register a working adapter
  create_valid_mock_adapter "working_adapter"
  run_adapter_registry_register "working_adapter"

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should handle failing adapter gracefully and continue with working one
  assert_adapter_failure_handled_gracefully "$output" "failing_adapter"
  assert_adapter_success_processed "$output" "working_adapter"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector iterates through all registered adapters" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register multiple adapters
  create_valid_mock_adapter "iter_adapter1"
  run_adapter_registry_register "iter_adapter1"

  create_valid_mock_adapter "iter_adapter2"
  run_adapter_registry_register "iter_adapter2"

  create_valid_mock_adapter "iter_adapter3"
  run_adapter_registry_register "iter_adapter3"

  # Create a test project
  create_empty_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have iterated through all adapters
  assert_all_registered_adapters_iterated "$output" "iter_adapter1,iter_adapter2,iter_adapter3"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector skips adapters that fail during iteration" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register mix of working and failing adapters
  create_failing_mock_adapter "skip_adapter1"
  run_adapter_registry_register "skip_adapter1"

  create_valid_mock_adapter "skip_adapter2"
  run_adapter_registry_register "skip_adapter2"

  create_failing_mock_adapter "skip_adapter3"
  run_adapter_registry_register "skip_adapter3"

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should skip failing adapters but process working ones
  assert_failing_adapters_skipped "$output" "skip_adapter1,skip_adapter3"
  assert_working_adapters_processed "$output" "skip_adapter2"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector collects metadata from adapter registry" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register an adapter with specific metadata
  create_valid_mock_adapter_with_capability "metadata_adapter" "parallel"
  run_adapter_registry_register "metadata_adapter"

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have collected metadata from registry
  assert_adapter_metadata_collected "$output" "metadata_adapter"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector reports binary availability from registry checks" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register adapters with different binary availability
  create_valid_mock_adapter "available_binary_adapter"
  run_adapter_registry_register "available_binary_adapter"

  create_unavailable_binary_adapter "unavailable_binary_adapter"
  run_adapter_registry_register "unavailable_binary_adapter"

  # Create a test project
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should report binary availability correctly
  assert_binary_availability_reported "$output" "available_binary_adapter" "true"
  assert_binary_availability_reported "$output" "unavailable_binary_adapter" "false"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector uses built-in adapters from registry" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Create a project that built-in adapters should detect
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have used built-in adapters from registry
  assert_builtin_adapters_used "$output" "bats"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}

@test "Framework Detector coordinates with registry for complete detection workflow" {
  setup_adapter_registry_test
  setup_framework_detector_test

  # Register multiple adapters
  create_valid_mock_adapter "workflow_adapter1"
  run_adapter_registry_register "workflow_adapter1"

  create_valid_mock_adapter "workflow_adapter2"
  run_adapter_registry_register "workflow_adapter2"

  # Create a complex test project
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Framework Detector
  output=$(run_framework_detector_registry_integration "$TEST_PROJECT_DIR")

  # Should have completed full detection workflow using registry
  assert_complete_detection_workflow "$output" "workflow_adapter1,workflow_adapter2"

  teardown_framework_detector_test
  teardown_adapter_registry_test
}


# ============================================================================
# Helper Functions for Framework Detector Integration Tests
# ============================================================================

# Create a mock adapter that fails detection
create_failing_mock_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter that fails detection
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Failing mock adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  # Always fail detection
  return 1
}

${adapter_identifier}_adapter_get_metadata() {
  cat << METADATA_EOF
{
  "name": "Failing Adapter",
  "identifier": "$adapter_identifier",
  "version": "1.0.0",
  "supported_languages": ["test"],
  "capabilities": ["test"],
  "required_binaries": ["test"],
  "configuration_files": ["test.json"],
  "test_file_patterns": ["test_*"],
  "test_directory_patterns": ["tests/"]
}
METADATA_EOF
}

${adapter_identifier}_adapter_check_binaries() {
  return 1  # Binary check fails
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
  "exit_code": 1,
  "duration": 0.1,
  "output": "Failed execution",
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
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "error"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# Create a mock adapter with unavailable binaries
create_unavailable_binary_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter with unavailable binaries
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Unavailable binary adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}

${adapter_identifier}_adapter_get_metadata() {
  cat << METADATA_EOF
{
  "name": "Unavailable Binary Adapter",
  "identifier": "$adapter_identifier",
  "version": "1.0.0",
  "supported_languages": ["test"],
  "capabilities": ["test"],
  "required_binaries": ["nonexistent_binary"],
  "configuration_files": ["test.json"],
  "test_file_patterns": ["test_*"],
  "test_directory_patterns": ["tests/"]
}
METADATA_EOF
}

${adapter_identifier}_adapter_check_binaries() {
  return 1  # Binary not available
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
  "exit_code": 1,
  "duration": 0.1,
  "output": "Binary not available",
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
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "error"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# Run Framework Detector with registry integration (calls non-existent function)
run_framework_detector_registry_integration() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  local output
  local scanner_script

  # Determine the path to suitey.sh
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    scanner_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source suitey.sh to get access to functions, then call the framework detector function
  output=$(
    source "$scanner_script"
    framework_detector_with_registry "$project_dir" 2>&1 || true
  )
  echo "$output"
}

# ============================================================================
# Framework Detector Integration Assertions
# ============================================================================

# Assert Framework Detector used registry
assert_framework_detector_used_registry() {
  local output="$1"

  if ! echo "$output" | grep -q "registry\|adapter"; then
    echo "ERROR: Expected Framework Detector to use adapter registry"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter detect method was called
assert_adapter_detect_method_called() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "detect.*$adapter_identifier\|${adapter_identifier}.*detect"; then
    echo "ERROR: Expected detect method to be called on adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter binary check was called
assert_adapter_binary_check_called() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "binary.*check.*$adapter_identifier\|${adapter_identifier}.*binary"; then
    echo "ERROR: Expected binary check to be called for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert multiple adapter results aggregated
assert_multiple_adapter_results_aggregated() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected results from adapter '$adapter' to be aggregated"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert adapter failure handled gracefully
assert_adapter_failure_handled_gracefully() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "failed.*$adapter_identifier\|${adapter_identifier}.*failed\|skipped.*$adapter_identifier"; then
    echo "ERROR: Expected failure of adapter '$adapter_identifier' to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not have crashed the entire detection process
  if echo "$output" | grep -q "fatal\|crash\|aborted"; then
    echo "ERROR: Framework Detector should not crash when adapter fails"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter success processed
assert_adapter_success_processed() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "success.*$adapter_identifier\|${adapter_identifier}.*success\|detected.*$adapter_identifier"; then
    echo "ERROR: Expected successful processing of adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert all registered adapters iterated
assert_all_registered_adapters_iterated() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' to be iterated over"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert failing adapters skipped
assert_failing_adapters_skipped() {
  local output="$1"
  local failing_adapters="$2"

  IFS=',' read -ra failing_array <<< "$failing_adapters"
  for adapter in "${failing_array[@]}"; do
    # Check for "skipped $adapter" or "$adapter" followed by "skip" (case insensitive)
    # Escape the adapter identifier to handle any special regex characters
    local escaped_adapter=$(printf '%s\n' "$adapter" | sed 's/[][\.*^$()+?{|]/\\&/g')
    if ! echo "$output" | grep -iE -q "skip.*${escaped_adapter}|${escaped_adapter}.*skip"; then
      echo "ERROR: Expected failing adapter '$adapter' to be skipped"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert working adapters processed
assert_working_adapters_processed() {
  local output="$1"
  local working_adapters="$2"

  IFS=',' read -ra working_array <<< "$working_adapters"
  for adapter in "${working_array[@]}"; do
    if ! echo "$output" | grep -q "processed.*$adapter\|$adapter.*processed\|success.*$adapter"; then
      echo "ERROR: Expected working adapter '$adapter' to be processed"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert adapter metadata collected
assert_adapter_metadata_collected() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "metadata.*$adapter_identifier\|$adapter_identifier.*metadata"; then
    echo "ERROR: Expected metadata to be collected for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert binary availability reported
assert_binary_availability_reported() {
  local output="$1"
  local adapter_identifier="$2"
  local expected_available="$3"

  if ! echo "$output" | grep -q "binary.*$adapter_identifier.*$expected_available\|$adapter_identifier.*binary.*$expected_available"; then
    echo "ERROR: Expected binary availability '$expected_available' to be reported for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert built-in adapters used
assert_builtin_adapters_used() {
  local output="$1"
  local builtin_adapters="$2"

  IFS=',' read -ra builtin_array <<< "$builtin_adapters"
  for adapter in "${builtin_array[@]}"; do
    if ! echo "$output" | grep -q "builtin.*$adapter\|$adapter.*builtin\|registry.*$adapter"; then
      echo "ERROR: Expected built-in adapter '$adapter' to be used from registry"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert complete detection workflow
assert_complete_detection_workflow() {
  local output="$1"
  local adapters="$2"

  # Should show all phases: detection, binary check, metadata collection
  if ! echo "$output" | grep -q "detection.*complete\|workflow.*complete"; then
    echo "ERROR: Expected complete detection workflow to be executed"
    echo "Output was: $output"
    return 1
  fi

  # Should include results from specified adapters
  IFS=',' read -ra adapter_array <<< "$adapters"
  for adapter in "${adapter_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected adapter '$adapter' to be part of complete workflow"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

