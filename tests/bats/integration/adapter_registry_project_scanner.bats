#!/usr/bin/env bats

load ../helpers/adapter_registry
load ../helpers/project_scanner
load ../helpers/fixtures

# ============================================================================
# Project Scanner - Adapter Registry Orchestration Tests
# ============================================================================

@test "Project Scanner coordinates Framework Detector using Adapter Registry" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry with built-in adapters
  run_adapter_registry_initialize

  # Create a project that should be detected
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner (should coordinate Framework Detector with registry)
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should coordinate Framework Detector using registry
  assert_project_scanner_coordinated_framework_detector "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner coordinates Test Suite Discovery using Adapter Registry" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create a project with test suites
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should coordinate Test Suite Discovery using registry
  assert_project_scanner_coordinated_test_suite_discovery "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner coordinates Build System Detector using Adapter Registry" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create a project that might require building
  create_rust_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should coordinate Build System Detector using registry
  assert_project_scanner_coordinated_build_detector "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner aggregates results from components using Adapter Registry" {
  setup_adapter_registry_test
  setup_test_project

  # Register multiple adapters
  create_valid_mock_adapter "aggregation_adapter1"
  run_adapter_registry_register "aggregation_adapter1"

  create_valid_mock_adapter "aggregation_adapter2"
  run_adapter_registry_register "aggregation_adapter2"

  # Create a multi-framework project
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should aggregate results from all components using registry
  assert_results_aggregated_from_registry_components "$output" "aggregation_adapter1,aggregation_adapter2"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner executes end-to-end workflow using Adapter Registry" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry with built-in adapters
  run_adapter_registry_initialize

  # Create a complete project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner for complete workflow
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should execute complete workflow: Detection → Discovery → Build Detection
  assert_complete_workflow_executed "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles component failures gracefully when using registry" {
  setup_adapter_registry_test
  setup_test_project

  # Register mix of working and failing adapters
  create_failing_orchestration_adapter "failing_orchestration_adapter"
  run_adapter_registry_register "failing_orchestration_adapter"

  create_valid_mock_adapter "working_orchestration_adapter"
  run_adapter_registry_register "working_orchestration_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should handle component failures gracefully
  assert_component_failures_handled_gracefully "$output" "failing_orchestration_adapter"
  assert_working_components_processed "$output" "working_orchestration_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner maintains component execution order using registry" {
  setup_adapter_registry_test
  setup_test_project

  # Register adapters for different phases
  create_valid_mock_adapter "detection_phase_adapter"
  run_adapter_registry_register "detection_phase_adapter"

  create_valid_mock_adapter "discovery_phase_adapter"
  run_adapter_registry_register "discovery_phase_adapter"

  create_valid_mock_adapter "build_phase_adapter"
  run_adapter_registry_register "build_phase_adapter"

  # Create a project
  create_multi_framework_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should maintain correct execution order: Framework Detection → Test Suite Discovery → Build Detection
  assert_correct_execution_order "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner passes registry data between components correctly" {
  setup_adapter_registry_test
  setup_test_project

  # Register an adapter that will be used across components
  create_valid_mock_adapter "data_flow_adapter"
  run_adapter_registry_register "data_flow_adapter"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should pass registry data correctly between Framework Detector → Test Suite Discovery → Build Detector
  assert_registry_data_flow "$output" "data_flow_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner uses registry for all adapter operations across components" {
  setup_adapter_registry_test
  setup_test_project

  # Register comprehensive adapter
  create_comprehensive_orchestration_adapter "comprehensive_adapter"
  run_adapter_registry_register "comprehensive_adapter"

  # Create a project that exercises all adapter methods
  create_complex_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should use registry for all adapter operations across all components
  assert_all_adapter_operations_via_registry "$output" "comprehensive_adapter"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles registry unavailability gracefully" {
  setup_adapter_registry_test
  setup_test_project

  # Don't initialize registry (simulate unavailability)

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should handle registry unavailability gracefully
  assert_registry_unavailability_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner validates component integration with registry" {
  setup_adapter_registry_test
  setup_test_project

  # Register adapters that components should validate
  create_valid_mock_adapter "validation_adapter1"
  run_adapter_registry_register "validation_adapter1"

  create_valid_mock_adapter "validation_adapter2"
  run_adapter_registry_register "validation_adapter2"

  # Create a project
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should validate that components integrate correctly with registry
  assert_component_registry_integration_validated "$output" "validation_adapter1,validation_adapter2"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner provides unified results from registry-based components" {
  setup_adapter_registry_test
  setup_test_project

  # Register adapters that provide different types of results
  create_valid_mock_adapter "results_adapter1"
  run_adapter_registry_register "results_adapter1"

  create_valid_mock_adapter "results_adapter2"
  run_adapter_registry_register "results_adapter2"

  # Create a comprehensive project
  create_project_with_helpers "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should provide unified results from all registry-based components
  assert_unified_results_from_components "$output" "results_adapter1,results_adapter2"

  teardown_test_project
  teardown_adapter_registry_test
}

# ============================================================================
# Helper Functions for Project Scanner Orchestration Tests
# ============================================================================

# Create a failing orchestration adapter
create_failing_orchestration_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create adapter that fails at orchestration level
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Failing orchestration adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  # Fail during orchestration
  echo "ERROR: Orchestration failed for $adapter_identifier" >&2
  return 1
}

${adapter_identifier}_adapter_get_metadata() {
  cat << METADATA_EOF
{
  "name": "Failing Orchestration Adapter",
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
  return 1  # Fail binary check
}

${adapter_identifier}_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  return 1  # Fail discovery
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
  "output": "Orchestration failed",
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

# Create a comprehensive orchestration adapter
create_comprehensive_orchestration_adapter() {
  local adapter_identifier="$1"
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_identifier"

  mkdir -p "$adapter_dir"

  # Create adapter that exercises all methods
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

# Comprehensive orchestration adapter - $adapter_identifier

${adapter_identifier}_adapter_detect() {
  local project_root="\$1"
  return 0
}

${adapter_identifier}_adapter_get_metadata() {
  cat << METADATA_EOF
{
  "name": "Comprehensive Orchestration Adapter",
  "identifier": "$adapter_identifier",
  "version": "1.0.0",
  "supported_languages": ["bash", "shell"],
  "capabilities": ["parallel", "coverage"],
  "required_binaries": ["bats"],
  "configuration_files": ["*.bats"],
  "test_file_patterns": ["*.bats"],
  "test_directory_patterns": ["tests/bats/"]
}
METADATA_EOF
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
    "name": "${adapter_identifier}_comprehensive_suite",
    "framework": "$adapter_identifier",
    "test_files": ["comprehensive_test.bats"],
    "metadata": {"type": "comprehensive"},
    "execution_config": {"parallel": true}
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
  "duration": 2.5,
  "output": "Comprehensive test execution output",
  "container_id": "comp_container_123",
  "execution_method": "docker"
}
EXEC_EOF
}

${adapter_identifier}_adapter_parse_test_results() {
  local output="\$1"
  local exit_code="\$2"

  cat << RESULTS_EOF
{
  "total_tests": 10,
  "passed_tests": 10,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [
    {"name": "test1", "status": "passed", "duration": 0.1},
    {"name": "test2", "status": "passed", "duration": 0.2}
  ],
  "status": "passed"
}
RESULTS_EOF
}
EOF

  chmod +x "$adapter_dir/adapter.sh"
  source "$adapter_dir/adapter.sh"
}

# Create a complex project for comprehensive testing
create_complex_project() {
  local base_dir="$1"

  # Create project root
  mkdir -p "$base_dir"

  # Add multiple test frameworks and patterns
  mkdir -p "$base_dir/tests/bats/helpers"

  # Create BATS tests
  cat > "$base_dir/tests/bats/complex.bats" << 'EOF'
#!/usr/bin/env bats

@test "complex test 1" {
  [ true ]
}

@test "complex test 2" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/complex.bats"

  # Create helper
  cat > "$base_dir/tests/bats/helpers/complex_helper.bash" << 'EOF'
#!/usr/bin/env bash
# Complex helper
complex_helper() {
  echo "complex"
}
EOF
  chmod +x "$base_dir/tests/bats/helpers/complex_helper.bash"

  echo "$base_dir"
}

# Run Project Scanner with registry orchestration (calls non-existent function)
run_project_scanner_registry_orchestration() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  # Call non-existent orchestration function - will fail for TDD
  project_scanner_registry_orchestration "$project_dir"
}

# ============================================================================
# Project Scanner Orchestration Assertions
# ============================================================================

# Assert Project Scanner coordinated Framework Detector
assert_project_scanner_coordinated_framework_detector() {
  local output="$1"

  if ! echo "$output" | grep -q "framework.*detector\|detector.*coordinated\|orchestrated.*framework"; then
    echo "ERROR: Expected Project Scanner to coordinate Framework Detector"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert Project Scanner coordinated Test Suite Discovery
assert_project_scanner_coordinated_test_suite_discovery() {
  local output="$1"

  if ! echo "$output" | grep -q "suite.*discovery\|discovery.*coordinated\|orchestrated.*discovery"; then
    echo "ERROR: Expected Project Scanner to coordinate Test Suite Discovery"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert Project Scanner coordinated Build System Detector
assert_project_scanner_coordinated_build_detector() {
  local output="$1"

  if ! echo "$output" | grep -q "build.*detector\|detector.*build\|orchestrated.*build"; then
    echo "ERROR: Expected Project Scanner to coordinate Build System Detector"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert results aggregated from registry components
assert_results_aggregated_from_registry_components() {
  local output="$1"
  local expected_adapters="$2"

  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "aggregated.*$adapter\|${adapter}.*aggregated"; then
      echo "ERROR: Expected results to be aggregated from registry component using adapter '$adapter'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert complete workflow executed
assert_complete_workflow_executed() {
  local output="$1"

  # Should show all phases: framework detection, test suite discovery, build detection
  local phases=("detection" "discovery" "build")
  for phase in "${phases[@]}"; do
    if ! echo "$output" | grep -q "$phase.*complete\|complete.*$phase\|workflow.*$phase"; then
      echo "ERROR: Expected $phase phase to be completed in workflow"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert component failures handled gracefully
assert_component_failures_handled_gracefully() {
  local output="$1"
  local failing_adapter="$2"

  if ! echo "$output" | grep -q "failed.*$failing_adapter\|${failing_adapter}.*failed\|handled.*failure"; then
    echo "ERROR: Expected component failure for adapter '$failing_adapter' to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not have crashed the entire orchestration
  if echo "$output" | grep -q "fatal\|crash\|aborted"; then
    echo "ERROR: Project Scanner should not crash when components fail"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert working components processed
assert_working_components_processed() {
  local output="$1"
  local working_adapter="$2"

  if ! echo "$output" | grep -q "processed.*$working_adapter\|${working_adapter}.*processed\|success.*$working_adapter"; then
    echo "ERROR: Expected working component with adapter '$working_adapter' to be processed"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert correct execution order
assert_correct_execution_order() {
  local output="$1"

  # Should show Framework Detection → Test Suite Discovery → Build Detection order
  if ! echo "$output" | grep -q "detection.*then.*discovery\|discovery.*after.*detection\|order.*maintained"; then
    echo "ERROR: Expected correct execution order to be maintained"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert registry data flow
assert_registry_data_flow() {
  local output="$1"
  local adapter_identifier="$2"

  if ! echo "$output" | grep -q "flow.*$adapter_identifier\|${adapter_identifier}.*flow\|passed.*$adapter_identifier"; then
    echo "ERROR: Expected registry data to flow correctly for adapter '$adapter_identifier'"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert all adapter operations via registry
assert_all_adapter_operations_via_registry() {
  local output="$1"
  local adapter_identifier="$2"

  # Should show all adapter methods called via registry
  local operations=("detect" "check_binaries" "discover_test_suites" "detect_build_requirements")
  for operation in "${operations[@]}"; do
    if ! echo "$output" | grep -q "$operation.*$adapter_identifier\|${adapter_identifier}.*$operation\|registry.*$operation"; then
      echo "ERROR: Expected adapter operation '$operation' to be performed via registry for '$adapter_identifier'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert registry unavailability handled
assert_registry_unavailability_handled() {
  local output="$1"

  if ! echo "$output" | grep -q "registry.*unavailable\|unavailable.*registry\|registry.*error"; then
    echo "ERROR: Expected registry unavailability to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not crash
  if echo "$output" | grep -q "fatal\|aborted"; then
    echo "ERROR: Project Scanner should not crash when registry is unavailable"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert component registry integration validated
assert_component_registry_integration_validated() {
  local output="$1"
  local expected_adapters="$2"

  # Should show validation of component-registry integration
  if ! echo "$output" | grep -q "validated\|integration.*verified\|registry.*integration"; then
    echo "ERROR: Expected component-registry integration to be validated"
    echo "Output was: $output"
    return 1
  fi

  # Should include specified adapters in validation
  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "validate.*$adapter\|${adapter}.*validate"; then
      echo "ERROR: Expected adapter '$adapter' to be included in integration validation"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert unified results from components
assert_unified_results_from_components() {
  local output="$1"
  local expected_adapters="$2"

  # Should show unified results from all components
  if ! echo "$output" | grep -q "unified\|combined\|aggregated.*results"; then
    echo "ERROR: Expected unified results from registry-based components"
    echo "Output was: $output"
    return 1
  fi

  # Should include results from specified adapters
  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -q "results.*$adapter\|${adapter}.*results"; then
      echo "ERROR: Expected results from adapter '$adapter' in unified output"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}
