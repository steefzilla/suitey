#!/usr/bin/env bats

load ../helpers/adapter_registry
load ../helpers/project_scanner
load ../helpers/fixtures

# ============================================================================
# Test Suite Discovery - Adapter Registry Integration Tests
# ============================================================================

@test "Test Suite Discovery accesses adapters from registry via Framework Detector results" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry with built-in adapters
  run_adapter_registry_initialize

  # Create a project that should be detected by built-in adapters
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery with registry integration
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should have accessed registry adapters via Framework Detector results
  assert_test_suite_discovery_used_registry "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery calls discover_test_suites method on adapters" {
  setup_adapter_registry_test
  setup_test_project

  # Register a mock adapter
  create_valid_mock_adapter "mock_discovery_adapter"
  run_adapter_registry_register "mock_discovery_adapter"

  # Create a project that the adapter should detect
  create_project_with_pattern "$TEST_PROJECT_DIR" "mock_pattern"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should have called discover_test_suites method
  assert_adapter_discovery_method_called "$output" "mock_discovery_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery uses adapters to find test files" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter that provides test suites
  create_valid_mock_adapter "file_finder_adapter"
  run_adapter_registry_register "file_finder_adapter"

  # Create a project with test files
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should have found test files using adapter
  assert_test_files_found_via_adapter "$output" "file_finder_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery groups test files using adapter logic" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter that groups test files
  create_valid_mock_adapter "grouping_adapter"
  run_adapter_registry_register "grouping_adapter"

  # Create a project with multiple test files
  create_project_with_helpers "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should have grouped test files according to adapter logic
  assert_test_files_grouped_by_adapter "$output" "grouping_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery handles adapter errors gracefully" {
  setup_adapter_registry_test
  setup_test_project

  # Register a failing adapter
  create_failing_discovery_adapter "failing_discovery_adapter"
  run_adapter_registry_register "failing_discovery_adapter"

  # Register a working adapter
  create_valid_mock_adapter "working_discovery_adapter"
  run_adapter_registry_register "working_discovery_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should handle failing adapter gracefully and continue with working one
  assert_discovery_adapter_failure_handled "$output" "failing_discovery_adapter"
  assert_discovery_adapter_success_processed "$output" "working_discovery_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery discovers suites for all detected frameworks" {
  setup_adapter_registry_test
  setup_test_project

  # Register multiple adapters for different frameworks
  create_valid_mock_adapter "framework1_adapter"
  run_adapter_registry_register "framework1_adapter"

  create_valid_mock_adapter "framework2_adapter"
  run_adapter_registry_register "framework2_adapter"

  # Create a multi-framework project
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should discover suites for all detected frameworks, not just first one
  assert_suites_discovered_for_all_frameworks "$output" "framework1_adapter,framework2_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery doesn't stop after first framework detection" {
  setup_adapter_registry_test
  setup_test_project

  # Register multiple adapters
  create_valid_mock_adapter "first_framework_adapter"
  run_adapter_registry_register "first_framework_adapter"

  create_valid_mock_adapter "second_framework_adapter"
  run_adapter_registry_register "second_framework_adapter"

  create_valid_mock_adapter "third_framework_adapter"
  run_adapter_registry_register "third_framework_adapter"

  # Create a project that all adapters should detect
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should process all frameworks, not stop after first
  assert_all_frameworks_processed "$output" "first_framework_adapter,second_framework_adapter,third_framework_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery aggregates suites from multiple adapters" {
  setup_adapter_registry_test
  setup_test_project

  # Register adapters that provide different test suites
  create_valid_mock_adapter "suite_adapter1"
  run_adapter_registry_register "suite_adapter1"

  create_valid_mock_adapter "suite_adapter2"
  run_adapter_registry_register "suite_adapter2"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should aggregate suites from both adapters
  assert_suites_aggregated_from_adapters "$output" "suite_adapter1,suite_adapter2"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery uses framework metadata from registry" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter with specific metadata
  create_valid_mock_adapter_with_capability "metadata_discovery_adapter" "parallel"
  run_adapter_registry_register "metadata_discovery_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should use framework metadata from registry
  assert_framework_metadata_used "$output" "metadata_discovery_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery coordinates with Framework Detector results" {
  setup_adapter_registry_test
  setup_test_project

  # Register adapters that Framework Detector would detect
  create_valid_mock_adapter "detected_adapter1"
  run_adapter_registry_register "detected_adapter1"

  create_valid_mock_adapter "detected_adapter2"
  run_adapter_registry_register "detected_adapter2"

  # Create a project that should be detected
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery (which depends on Framework Detector results)
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should coordinate with Framework Detector results from registry
  assert_coordination_with_framework_detector "$output" "detected_adapter1,detected_adapter2"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery handles empty adapter list gracefully" {
  setup_adapter_registry_test
  setup_test_project

  # Don't register any adapters (empty list from Framework Detector)

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should handle empty adapter list gracefully
  assert_empty_adapter_list_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery handles adapter discovery failures gracefully" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter that fails during discovery
  create_failing_discovery_adapter "discovery_failure_adapter"
  run_adapter_registry_register "discovery_failure_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should handle discovery failure gracefully
  assert_discovery_failure_handled "$output" "discovery_failure_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Test Suite Discovery validates test suite structure from adapters" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter that returns valid test suites
  create_valid_mock_adapter "validation_adapter"
  run_adapter_registry_register "validation_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Test Suite Discovery
  output=$(run_test_suite_discovery_registry_integration "$TEST_PROJECT_DIR")

  # Should validate and accept properly structured test suites
  assert_test_suite_structure_validated "$output" "validation_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

# ============================================================================
# Helper Functions for Test Suite Discovery Integration Tests
# ============================================================================

# Create a mock adapter that fails during discovery
create_failing_discovery_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create mock adapter that fails during discovery
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Failing discovery adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0  # Detection succeeds
}

${adapter_identifier}_adapter_get_metadata() {
  cat << METADATA_EOF
{
  "name": "Failing Discovery Adapter",
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
  return 0
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  # Fail during discovery
  echo "ERROR: Discovery failed for $adapter_identifier" >&2
  return 1
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
  "output": "Discovery failed",
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

# Run Test Suite Discovery with registry integration (calls non-existent function)
run_test_suite_discovery_registry_integration() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  # Call non-existent integration function - will fail for TDD
  test_suite_discovery_with_registry "$project_dir"
}

# ============================================================================
# Test Suite Discovery Integration Assertions
# ============================================================================

# Assert Test Suite Discovery used registry
assert_test_suite_discovery_used_registry() {
  local output="$1"

  if ! echo "$output" | grep -q "registry\|adapter.*discovery\|discovery.*adapter"; then
    echo "ERROR: Expected Test Suite Discovery to use adapter registry"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert adapter discovery method was called
assert_adapter_discovery_method_called() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "discover.*$adapter_identifier\|${adapter_identifier}.*discover"; then
    echo "ERROR: Expected discover_test_suites method to be called on adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert test files found via adapter
assert_test_files_found_via_adapter() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "files.*found.*$adapter_identifier\|${adapter_identifier}.*files.*found\|test.*files.*$adapter_identifier"; then
    echo "ERROR: Expected test files to be found via adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert test files grouped by adapter
assert_test_files_grouped_by_adapter() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "grouped.*$adapter_identifier\|${adapter_identifier}.*grouped\|suite.*$adapter_identifier"; then
    echo "ERROR: Expected test files to be grouped by adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert discovery adapter failure handled
assert_discovery_adapter_failure_handled() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "failed.*$adapter_identifier\|${adapter_identifier}.*failed\|skipped.*discovery.*$adapter_identifier"; then
    echo "ERROR: Expected discovery failure of adapter '$adapter_identifier' to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not have crashed the entire discovery process
  if echo "$output" | grep -q "fatal\|crash\|aborted"; then
    echo "ERROR: Test Suite Discovery should not crash when adapter fails"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert discovery adapter success processed
assert_discovery_adapter_success_processed() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "success.*$adapter_identifier\|${adapter_identifier}.*success\|discovered.*$adapter_identifier"; then
    echo "ERROR: Expected successful discovery processing of adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert suites discovered for all frameworks
assert_suites_discovered_for_all_frameworks() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "suites.*$adapter\|${adapter}.*suites\|discovered.*$adapter"; then
      echo "ERROR: Expected test suites to be discovered for framework adapter '$adapter'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert all frameworks processed
assert_all_frameworks_processed() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "processed.*$adapter\|${adapter}.*processed"; then
      echo "ERROR: Expected framework adapter '$adapter' to be processed"
      echo "Output was: $output"
      return 1
    fi
  done

  # Should show continuation after first framework
  if ! echo "$output" | grep -q "continue\|next\|additional"; then
    echo "ERROR: Expected indication that processing continued after first framework"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert suites aggregated from adapters
assert_suites_aggregated_from_adapters() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "aggregated.*$adapter\|${adapter}.*aggregated"; then
      echo "ERROR: Expected suites to be aggregated from adapter '$adapter'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert framework metadata used
assert_framework_metadata_used() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "metadata.*$adapter_identifier\|${adapter_identifier}.*metadata"; then
    echo "ERROR: Expected framework metadata to be used for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert coordination with Framework Detector
assert_coordination_with_framework_detector() {
  local output="$1"
  local expected_adapters="$2"

  # Should show coordination between components
  if ! echo "$output" | grep -q "framework.*detector\|detector.*framework\|coordinated"; then
    echo "ERROR: Expected coordination with Framework Detector"
    echo "Output was: $output"
    return 1
  fi

  # Should include results from specified adapters
  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "$adapter"; then
      echo "ERROR: Expected coordination results for adapter '$adapter'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert empty adapter list handled
assert_empty_adapter_list_handled() {
  local output="$1"

  if ! echo "$output" | grep -q "empty.*list\|no.*adapters\|list.*empty"; then
    echo "ERROR: Expected empty adapter list to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not crash
  if echo "$output" | grep -q "fatal\|crash\|error.*adapter"; then
    echo "ERROR: Test Suite Discovery should not crash with empty adapter list"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert discovery failure handled
assert_discovery_failure_handled() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "discovery.*failed.*$adapter_identifier\|${adapter_identifier}.*discovery.*failed"; then
    echo "ERROR: Expected discovery failure of adapter '$adapter_identifier' to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not crash the entire process
  if echo "$output" | grep -q "fatal\|aborted"; then
    echo "ERROR: Test Suite Discovery should not crash on discovery failures"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert test suite structure validated
assert_test_suite_structure_validated() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "validated.*$adapter_identifier\|${adapter_identifier}.*validated\|structure.*$adapter_identifier"; then
    echo "ERROR: Expected test suite structure to be validated for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}
