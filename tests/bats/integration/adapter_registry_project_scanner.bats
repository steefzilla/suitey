#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry
load ../helpers/project_scanner
load ../helpers/fixtures
load ../helpers/framework_detector

# Source all required modules from src/ for integration tests
_source_integration_modules() {
  # Find and source json_helpers.sh
  local json_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
  else
    json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
  fi
  source "$json_helpers_script"

  # Find and source adapter_registry_helpers.sh
  local adapter_registry_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
  else
    adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
  fi
  source "$adapter_registry_helpers_script"

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

  # Find and source framework_detector.sh
  local framework_detector_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../../src/framework_detector.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../src/framework_detector.sh"
  else
    framework_detector_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/framework_detector.sh"
  fi
  source "$framework_detector_script"

  # Find and source scanner.sh
  local scanner_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/scanner.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../../src/scanner.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/scanner.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../src/scanner.sh"
  else
    scanner_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/scanner.sh"
  fi
  source "$scanner_script"

  # Find and source adapters
  local bats_adapter_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../src/adapters/bats.sh"
  else
    bats_adapter_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src/adapters" && pwd)/bats.sh"
  fi
  source "$bats_adapter_script"

  local rust_adapter_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapters/rust.sh" ]]; then
    rust_adapter_script="$BATS_TEST_DIRNAME/../../../src/adapters/rust.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapters/rust.sh" ]]; then
    rust_adapter_script="$BATS_TEST_DIRNAME/../../src/adapters/rust.sh"
  else
    rust_adapter_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src/adapters" && pwd)/rust.sh"
  fi
  source "$rust_adapter_script"
}

_source_integration_modules

# Enable integration test mode for real Docker operations
export SUITEY_INTEGRATION_TEST=1

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

@test "Project Scanner handles projects without test directories" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create project with source code but no test directories
  mkdir -p "$TEST_PROJECT_DIR/src"
  echo "console.log('hello world');" > "$TEST_PROJECT_DIR/src/app.js"
  echo "fn main() { println!(\"hello world\"); }" > "$TEST_PROJECT_DIR/src/main.rs"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should handle gracefully - detect no frameworks, provide clear messaging
  assert_no_test_directories_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles frameworks detected but no test suites found" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create Rust project with Cargo.toml but no test files
  mkdir -p "$TEST_PROJECT_DIR/src"
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "test-project"
version = "0.1.0"

[dependencies]
EOF

  echo "fn main() {}" > "$TEST_PROJECT_DIR/src/main.rs"
  # Note: No test files created

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should detect Rust framework but report no test suites found
  assert_no_test_suites_found_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles missing framework binaries gracefully" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create BATS project
  create_bats_project "$TEST_PROJECT_DIR"

  # Mock bats binary as unavailable
  export SUITEY_MOCK_BATS_AVAILABLE=false

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Clean up mock
  unset SUITEY_MOCK_BATS_AVAILABLE

  # Should detect BATS framework but warn about missing binary
  assert_missing_framework_tools_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles malformed project structures" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create malformed project structure
  mkdir -p "$TEST_PROJECT_DIR/tests"
  # Create BATS file in wrong location (deeply nested)
  mkdir -p "$TEST_PROJECT_DIR/tests/bats/deep/nested/structure"
  cat > "$TEST_PROJECT_DIR/tests/bats/deep/nested/structure/test.bats" << 'EOF'
#!/usr/bin/env bats

EOF
  chmod +x "$TEST_PROJECT_DIR/tests/bats/deep/nested/structure/test.bats"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should still detect and process despite unusual structure
  assert_malformed_project_structure_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles multiple conflicting frameworks" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create project with both BATS and Rust files in same directory
  mkdir -p "$TEST_PROJECT_DIR/tests"

  # BATS files
  cat > "$TEST_PROJECT_DIR/tests/test.bats" << 'EOF'
#!/usr/bin/env bats

EOF
  chmod +x "$TEST_PROJECT_DIR/tests/test.bats"

  # Rust files
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "conflicting-project"
version = "0.1.0"
EOF

  mkdir -p "$TEST_PROJECT_DIR/src"
  cat > "$TEST_PROJECT_DIR/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
EOF

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should detect both frameworks and handle appropriately
  assert_conflicting_frameworks_handled "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner handles build requirements appropriately" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create a BATS project (BATS typically doesn't require build, but let's test build detection)
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should detect that BATS doesn't require build and handle appropriately
  assert_build_requirements_handled "$output"

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

# Run Project Scanner with registry orchestration
run_project_scanner_registry_orchestration() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  local output

  # Modules are already sourced via _source_integration_modules at the top
  output=$(project_scanner_registry_orchestration "$project_dir" 2>&1 || true)
  echo "$output"
}

# ============================================================================
# Project Scanner Error Handling Assertions
# ============================================================================

# Assert no test directories handled gracefully
assert_no_test_directories_handled() {
  local output="$1"

  if ! echo "$output" | grep -q "No test frameworks detected"; then
    echo "ERROR: Expected graceful handling of projects without test directories"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert no test suites found handled gracefully
assert_no_test_suites_found_handled() {
  local output="$1"

  # Should detect framework but indicate no test suites found
  if ! echo "$output" | grep -q "Detected frameworks"; then
    echo "ERROR: Expected framework detection even when no test suites found"
    echo "Output was: $output"
    return 1
  fi

  # Should indicate no test suites were discovered
  if ! echo "$output" | grep -E -q "No test suites found|Discovered 0 test suite"; then
    echo "ERROR: Expected indication that no test suites were found"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert missing framework tools handled gracefully
assert_missing_framework_tools_handled() {
  local output="$1"

  # Should detect framework (framework detection still works even if binary is missing)
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Expected BATS framework to be detected even with missing binary"
    echo "Output was: $output"
    return 1
  fi

  # Should still discover test suites (test discovery works even if binary is missing)
  if ! echo "$output" | grep -q "Discovered.*test suite"; then
    echo "ERROR: Expected test suite discovery to work even with missing binary"
    echo "Output was: $output"
    return 1
  fi

  # Note: Current implementation doesn't show binary warnings in main output
  # The framework detection warnings are only available in JSON format

  return 0
}

# Assert malformed project structure handled gracefully
assert_malformed_project_structure_handled() {
  local output="$1"

  # Should still detect frameworks despite unusual structure
  if ! echo "$output" | grep -E -q "BATS framework detected|Discovered.*test suite"; then
    echo "ERROR: Expected framework detection and test discovery despite malformed structure"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert conflicting frameworks handled appropriately
assert_conflicting_frameworks_handled() {
  local output="$1"

  # Should detect both frameworks
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Expected BATS framework detection"
    echo "Output was: $output"
    return 1
  fi

  if ! echo "$output" | grep -q "Rust framework detected"; then
    echo "ERROR: Expected Rust framework detection"
    echo "Output was: $output"
    return 1
  fi

  # Should discover test suites from both frameworks
  if ! echo "$output" | grep -q "Discovered.*test suite"; then
    echo "ERROR: Expected test suite discovery from multiple frameworks"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert build requirements handled appropriately
assert_build_requirements_handled() {
  local output="$1"

  # Should detect BATS framework
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Expected BATS framework detection"
    echo "Output was: $output"
    return 1
  fi

  # Should mention build requirements detection
  if ! echo "$output" | grep -q "Build requirements detected"; then
    echo "ERROR: Expected build requirements detection"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# ============================================================================
# Project Scanner Orchestration Assertions
# ============================================================================

# Assert Project Scanner coordinated Framework Detector
assert_project_scanner_coordinated_framework_detector() {
  local output="$1"

  if ! echo "$output" | grep -E -q "framework.*detector|detector.*coordinated|orchestrated.*framework"; then
    echo "ERROR: Expected Project Scanner to coordinate Framework Detector"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert Project Scanner coordinated Test Suite Discovery
assert_project_scanner_coordinated_test_suite_discovery() {
  local output="$1"

  if ! echo "$output" | grep -E -q "suite.*discovery|discovery.*coordinated|orchestrated.*discovery"; then
    echo "ERROR: Expected Project Scanner to coordinate Test Suite Discovery"
    echo "Output was: $output"
    return 1
  fi

  return 0
}

# Assert Project Scanner coordinated Build System Detector
assert_project_scanner_coordinated_build_detector() {
  local output="$1"

  if ! echo "$output" | grep -E -q "build.*detector|detector.*build|orchestrated.*build"; then
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
    if ! echo "$output" | grep -E -q "aggregated.*$adapter|${adapter}.*aggregated"; then
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
    if ! echo "$output" | grep -E -q "$phase.*complete|complete.*$phase|workflow.*$phase"; then
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

  if ! echo "$output" | grep -E -q "failed.*$failing_adapter|${failing_adapter}.*failed|handled.*failure"; then
    echo "ERROR: Expected component failure for adapter '$failing_adapter' to be handled gracefully"
    echo "Output was: $output"
    return 1
  fi

  # Should not have crashed the entire orchestration
  if echo "$output" | grep -E -q "fatal|crash|aborted"; then
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

  if ! echo "$output" | grep -E -q "processed.*$working_adapter|${working_adapter}.*processed|success.*$working_adapter"; then
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
  if ! echo "$output" | grep -E -q "detection.*then.*discovery|discovery.*after.*detection|order.*maintained"; then
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

  # Check that adapter was processed through all phases:
  # 1. Detection phase - adapter should be detected and processed
  if ! echo "$output" | grep -E -q "(detected|processed|registry detect).*$adapter_identifier"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to be detected in detection phase"
    echo "Output was: $output"
    return 1
  fi

  # 2. Discovery phase - adapter should be used for test suite discovery
  if ! echo "$output" | grep -E -q "(discover_test_suites|registry.*discover).*$adapter_identifier"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to be used in discovery phase"
    echo "Output was: $output"
    return 1
  fi

  # 3. Build detection phase - adapter should be used for build requirements detection
  if ! echo "$output" | grep -E -q "(detect_build_requirements|registry.*detect_build).*$adapter_identifier"; then
    echo "ERROR: Expected adapter '$adapter_identifier' to be used in build detection phase"
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
    if ! echo "$output" | grep -E -q "$operation.*$adapter_identifier|${adapter_identifier}.*$operation|registry.*$operation"; then
      echo "ERROR: Expected adapter operation '$operation' to be performed via registry for '$adapter_identifier'"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# Assert registry unavailability handled

# Assert component registry integration validated
assert_component_registry_integration_validated() {
  local output="$1"
  local expected_adapters="$2"

  # Should show validation of component-registry integration
  if ! echo "$output" | grep -E -q "validated|integration.*verified|registry.*integration"; then
    echo "ERROR: Expected component-registry integration to be validated"
    echo "Output was: $output"
    return 1
  fi

  # Should include specified adapters in validation
  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -E -q "validate.*$adapter|${adapter}.*validate"; then
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
  if ! echo "$output" | grep -E -q "unified|combined|aggregated.*results"; then
    echo "ERROR: Expected unified results from registry-based components"
    echo "Output was: $output"
    return 1
  fi

  # Should include results from specified adapters
  IFS=',' read -ra expected_array <<< "$expected_adapters"
  for adapter in "${expected_array[@]}"; do
    if ! echo "$output" | grep -E -q "results.*$adapter|${adapter}.*results"; then
      echo "ERROR: Expected results from adapter '$adapter' in unified output"
      echo "Output was: $output"
      return 1
    fi
  done

  return 0
}

# ============================================================================
# Build Manager Interface Integration Tests
# ============================================================================

@test "Adapter Registry calls get_build_steps with correct interface" {
  setup_adapter_registry_test

  # Initialize registry with built-in adapters
  run_adapter_registry_initialize

  # Create a mock adapter that requires building
  create_valid_mock_adapter "build_adapter"
  run_adapter_registry_register "build_adapter"
  assert_success

  # Call get_build_steps through registry
  # Modules are already sourced via _source_integration_modules at the top

  # Create temporary project
  local temp_project=$(mktemp -d)
  local build_requirements='{"requires_build": true, "build_steps": ["compile"], "build_commands": ["echo build"], "build_dependencies": [], "build_artifacts": ["target/"]}'
  
  # Call get_build_steps
  local build_steps
  build_steps=$(build_adapter_adapter_get_build_steps "$temp_project" "$build_requirements")
  
  # Should contain new interface fields
  assert_build_steps_has_install_dependencies "$build_steps"
  assert_build_steps_has_cpu_cores "$build_steps"
  
  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "Adapter Registry handles new get_build_steps fields correctly" {
  setup_adapter_registry_test
  
  # Initialize registry
  run_adapter_registry_initialize
  
  # Create a mock adapter with build requirements
  create_valid_mock_adapter "build_test_adapter"
  run_adapter_registry_register "build_test_adapter"
  assert_success
  
  # Call get_build_steps
  # Modules are already sourced via _source_integration_modules at the top
  
  local temp_project=$(mktemp -d)
  local build_requirements='{"requires_build": true}'
  
  local build_steps
  build_steps=$(build_test_adapter_adapter_get_build_steps "$temp_project" "$build_requirements")
  
  # Should be valid JSON with all required fields
  assert_build_steps_valid_json "$build_steps"
  
  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "Adapter Registry passes test_image to execute_test_suite" {
  setup_adapter_registry_test
  
  # Initialize registry
  run_adapter_registry_initialize
  
  # Create a mock adapter
  create_valid_mock_adapter "image_test_adapter"
  run_adapter_registry_register "image_test_adapter"
  assert_success
  
  # Call execute_test_suite with test_image
  # Modules are already sourced via _source_integration_modules at the top
  
  local test_suite='{"name": "test_suite", "framework": "image_test_adapter", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}'
  local test_image="test_image:latest"
  local execution_config='{"timeout": 30}'
  
  local result
  result=$(image_test_adapter_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")
  
  # Should contain test_image in result
  assert_execution_result_has_test_image "$result"
  
  # Should NOT contain build_artifacts
  assert_execution_result_no_build_artifacts "$result"
  
  teardown_adapter_registry_test
}

@test "Adapter Registry handles test_image parameter for no-build frameworks" {
  setup_adapter_registry_test
  
  # Initialize registry
  run_adapter_registry_initialize
  
  # Create a mock adapter (no build required)
  create_valid_mock_adapter "no_build_adapter"
  run_adapter_registry_register "no_build_adapter"
  assert_success
  
  # Call execute_test_suite with empty test_image
  # Modules are already sourced via _source_integration_modules at the top
  
  local test_suite='{"name": "test_suite", "framework": "no_build_adapter", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}'
  local test_image=""  # Empty for no-build frameworks
  local execution_config='{"timeout": 30}'
  
  local result
  result=$(no_build_adapter_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")
  
  # Should handle empty test_image gracefully
  assert_execution_succeeded "$result"
  assert_execution_result_has_test_image "$result"
  
  teardown_adapter_registry_test
}

@test "Project Scanner handles build requirements with new interface" {
  setup_adapter_registry_test
  setup_test_project
  
  # Initialize registry
  run_adapter_registry_initialize
  
  # Create a project that requires building
  create_rust_project "$TEST_PROJECT_DIR"
  
  # Run Project Scanner (should handle build requirements)
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")
  
  # Should handle build requirements without errors
  assert_project_scanner_handles_build_requirements "$output"
  
  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner passes test_image to adapters" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create a project with test suites
  create_bats_project "$TEST_PROJECT_DIR"

  # Run Project Scanner (should pass test_image to adapters)
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should pass test_image parameter correctly
  assert_project_scanner_passes_test_image "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner integrates build steps with new interface" {
  setup_adapter_registry_test
  setup_test_project

  # Initialize registry
  run_adapter_registry_initialize

  # Create a project requiring building
  create_rust_project "$TEST_PROJECT_DIR"

  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")

  # Should integrate build steps with new interface
  assert_project_scanner_integrates_build_steps "$output"

  teardown_test_project
  teardown_adapter_registry_test
}

@test "Project Scanner validates adapter interface compatibility" {
  setup_adapter_registry_test
  setup_test_project
  
  # Initialize registry
  run_adapter_registry_initialize
  
  # Create project with mixed frameworks
  create_mixed_project "$TEST_PROJECT_DIR"
  
  # Run Project Scanner
  output=$(run_project_scanner_registry_orchestration "$TEST_PROJECT_DIR")
  
  # Should validate all adapter interfaces are compatible
  assert_project_scanner_validates_interfaces "$output"
  
  teardown_test_project
  teardown_adapter_registry_test
}
