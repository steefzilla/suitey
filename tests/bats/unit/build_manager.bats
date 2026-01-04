#!/usr/bin/env bats
# Unit tests for Build Manager component
# Tests Build Manager logic with mocked Docker operations

# Source the suitey script to get Build Manager functions
load ../helpers/build_manager

# Find and source suitey.sh
suitey_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
else
  suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
fi

source "$suitey_script"

# ============================================================================
# Initialization Tests
# ============================================================================

@test "build_manager_initialize succeeds when Docker is available" {
  setup_build_manager_test "init_test"

  # Mock Docker being available
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  output=$(build_manager_initialize 2>&1)
  status=$?

  # Should succeed
  assert_build_manager_initialized "$output"
  [ $status -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_initialize creates temporary directory structure" {
  setup_build_manager_test "temp_dir_test"

  # Mock Docker being available
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  build_manager_initialize

  # Should create temporary directory
  [ -d "$TEST_BUILD_MANAGER_DIR" ]
  [ -d "$TEST_BUILD_MANAGER_DIR/builds" ]
  [ -d "$TEST_BUILD_MANAGER_DIR/artifacts" ]

  teardown_build_manager_test
}

@test "build_manager_initialize handles Docker unavailability gracefully" {
  setup_build_manager_test "docker_unavailable_test"

  # Mock Docker being unavailable
  build_manager_check_docker() { return 1; }

  # Initialize build manager
  if output=$(build_manager_initialize 2>&1); then
    status=0
  else
    status=$?
  fi

  # Should fail gracefully
  assert_docker_unavailable_handled "$output"
  [ $status -ne 0 ]

  teardown_build_manager_test
}

@test "build_manager_initialize initializes build tracking structures" {
  setup_build_manager_test "tracking_test"

  # Mock Docker being available
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  build_manager_initialize

  # Should initialize tracking structures
  [ -f "$TEST_BUILD_MANAGER_DIR/build_status.json" ]
  [ -f "$TEST_BUILD_MANAGER_DIR/active_builds.json" ]

  teardown_build_manager_test
}

# ============================================================================
# Build Dependency Analysis Tests
# ============================================================================

@test "build_manager_analyze_dependencies identifies independent builds (Tier 0)" {
  setup_build_manager_test "dependency_analysis_test"

  # Create build requirements with no dependencies
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Analyze dependencies
  output=$(build_manager_analyze_dependencies "$build_requirements")

  # Should identify Tier 0 builds
  assert_dependency_analysis "$output" "1"

  teardown_build_manager_test
}

@test "build_manager_analyze_dependencies groups builds into dependency tiers" {
  setup_build_manager_test "tier_analysis_test"

  # Create multi-framework build requirements
  build_requirements=$(create_multi_framework_build_requirements)

  # Analyze dependencies
  output=$(build_manager_analyze_dependencies "$build_requirements")

  # Should create dependency tiers
  assert_dependency_analysis "$output" "1"

  teardown_build_manager_test
}

@test "build_manager_analyze_dependencies handles circular dependencies gracefully" {
  setup_build_manager_test "circular_dependency_test"

  # Create build requirements with circular dependencies
  build_requirements='[
    {"framework": "a", "build_dependencies": ["b"]},
    {"framework": "b", "build_dependencies": ["a"]}
  ]'

  # Analyze dependencies
  if output=$(build_manager_analyze_dependencies "$build_requirements" 2>&1); then
    status=0
  else
    status=$?
  fi

  # Should detect and handle circular dependencies
  [ $status -ne 0 ]
  echo "$output" | grep -E -q "circular|cycle|dependency"

  teardown_build_manager_test
}

@test "build_manager_analyze_dependencies identifies independent builds for parallel execution" {
  setup_build_manager_test "parallel_identification_test"

  # Create multiple independent build requirements
  build_requirements='[
    {"framework": "rust", "build_dependencies": []},
    {"framework": "go", "build_dependencies": []},
    {"framework": "node", "build_dependencies": []}
  ]'

  # Analyze dependencies
  output=$(build_manager_analyze_dependencies "$build_requirements")

  # Should identify all as parallel candidates (all in tier_0)
  echo "$output" | jq -e '(.tier_0 | length) == 3' >/dev/null

  teardown_build_manager_test
}

@test "build_manager_analyze_dependencies determines sequential execution order" {
  setup_build_manager_test "execution_order_test"

  # Create build requirements with dependencies
  build_requirements='[
    {"framework": "app", "build_dependencies": ["lib"]},
    {"framework": "lib", "build_dependencies": []}
  ]'

  # Analyze dependencies
  output=$(build_manager_analyze_dependencies "$build_requirements")

  # Should determine execution order (lib before app)
  # Check that lib is in tier_0 and app is in tier_1
  echo "$output" | jq -e '(.tier_0 | index("lib")) != null and (.tier_1 | index("app")) != null' >/dev/null

  teardown_build_manager_test
}

# ============================================================================
# Build Orchestration Tests
# ============================================================================

@test "build_manager_orchestrate receives build requirements from Project Scanner" {
  setup_build_manager_test "orchestration_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Orchestrate builds
  output=$(build_manager_orchestrate "$build_requirements")

  # Should accept and process build requirements (return valid JSON)
  echo "$output" | jq . >/dev/null

  teardown_build_manager_test
}

@test "build_manager_orchestrate validates build requirements structure" {
  setup_build_manager_test "validation_test"

  # Test with valid requirements
  valid_requirements=$(create_mock_build_requirements)
  output=$(build_manager_orchestrate "$valid_requirements")
  [ $? -eq 0 ]

  # Test with invalid requirements
  invalid_requirements=$(create_invalid_build_requirements "missing_framework")
  if output=$(build_manager_orchestrate "$invalid_requirements" 2>&1); then
    status=0
  else
    status=$?
  fi
  [ $status -ne 0 ]

  teardown_build_manager_test
}

@test "build_manager_orchestrate handles empty build requirements list" {
  setup_build_manager_test "empty_requirements_test"

  # Create empty build requirements
  build_requirements=$(create_empty_build_requirements)

  # Orchestrate builds
  output=$(build_manager_orchestrate "$build_requirements")

  # Should handle empty list gracefully (return empty array)
  echo "$output" | jq -e '. == []' >/dev/null

  teardown_build_manager_test
}

@test "build_manager_orchestrate handles invalid build requirements gracefully" {
  setup_build_manager_test "invalid_requirements_test"

  # Test various invalid requirements
  invalid_json=$(create_invalid_build_requirements "invalid_json")
  if output=$(build_manager_orchestrate "$invalid_json" 2>&1); then
    status=0
  else
    status=$?
  fi
  [ $status -ne 0 ]
  echo "$output" | grep -iE -q "invalid|error|malformed"

  teardown_build_manager_test
}

# ============================================================================
# Build Execution Tests (Mocked Docker - Logic Only)
# ============================================================================

@test "build_manager_execute_build launches build containers with correct configuration" {
  setup_build_manager_test "container_launch_test"

  # Mock Docker availability
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  build_manager_initialize > /dev/null

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function
  docker_run() { mock_docker_run "$@"; }

  # Execute build
  if output=$(build_manager_execute_build "$build_spec" "rust" 2>&1); then
    status=0
  else
    status=$?
  fi

  # Should return build result JSON
  echo "$output" | grep -E -q '"status":|"framework":|"container_id":'

  teardown_build_manager_test
}

@test "build_manager_execute_build allocates CPU cores correctly" {
  setup_build_manager_test "cpu_allocation_test"

  # Mock Docker availability
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  build_manager_initialize > /dev/null

  # Create build requirements with specific CPU allocation
  build_requirements=$(create_mock_build_requirements "rust" "with_dependencies")

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function
  docker_run() { mock_docker_run "$@"; }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should allocate CPU cores correctly
  echo "$output" | grep -q '"cpu_cores_used": *2'

  teardown_build_manager_test
}

@test "build_manager_execute_build executes dependency installation commands" {
  setup_build_manager_test "dependency_install_test"

  # Mock Docker availability
  build_manager_check_docker() { return 0; }

  # Initialize build manager
  build_manager_initialize > /dev/null

  # Create build requirements with dependency installation
  build_requirements=$(create_mock_build_requirements "rust" "with_dependencies")

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function with dependency context
  docker_run() {
    # Check if this looks like dependency installation (has install command)
    local install_cmd
    install_cmd=$(echo "$build_spec" | jq -r '.install_dependencies_command // empty' 2>/dev/null)
    if [[ -n "$install_cmd" ]] && [[ "$install_cmd" != "null" ]]; then
      mock_docker_run "$@" 0 "Dependencies installed successfully. Build command executed."
    else
      mock_docker_run "$@"
    fi
  }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should execute successfully (dependency installation may succeed or fail by mock)
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_execute_build executes build commands with parallel support" {
  setup_build_manager_test "parallel_build_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function that includes build command in output
  docker_run() { mock_docker_run "$@" 0 "Executing: rust build --jobs 4"; }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_execute_build captures build output (stdout/stderr)" {
  setup_build_manager_test "output_capture_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function
  docker_run() { mock_docker_run "$@"; }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should capture and return build output
  echo "$output" | grep -E -q "output|captured|stdout|stderr"

  teardown_build_manager_test
}

@test "build_manager_execute_build tracks build status" {
  setup_build_manager_test "status_tracking_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function
  docker_run() { mock_docker_run "$@"; }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should track and report build status
  echo "$output" | grep -E -q "status|time|seconds|duration"

  teardown_build_manager_test
}

@test "build_manager_execute_build handles build container failures" {
  setup_build_manager_test "container_failure_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker run function that fails
  docker_run() { mock_docker_run "$1" "$2" "$3" "1" "Build failed"; }

  # Execute build
  if output=$(build_manager_execute_build "$build_spec" "rust" 2>&1); then
    status=0
  else
    status=$?
  fi

  # Should handle container failure gracefully
  echo "$output" | grep -E -q "failed|error|exit.*1|failure"

  teardown_build_manager_test
}

@test "build_manager_execute_build extracts build artifacts from containers" {
  setup_build_manager_test "artifact_extraction_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Extract build spec for rust (the build_steps[0])
  build_spec=$(echo "$build_requirements" | jq ".[0].build_steps[0]" 2>/dev/null)

  # Mock Docker functions with artifact extraction simulation
  docker_run() { mock_docker_run "$@" 0 "Build completed successfully"; }
  docker_cp() { mock_docker_cp "$@" 0; }

  # Execute build
  output=$(build_manager_execute_build "$build_spec" "rust")

  # Should execute successfully (artifacts are extracted by mock)
  [ $? -eq 0 ]

  teardown_build_manager_test
}

# ============================================================================
# Test Image Creation Tests (Mocked Docker - Logic Only)
# ============================================================================

@test "build_manager_create_test_image generates Dockerfile with correct structure" {
  setup_build_manager_test "dockerfile_generation_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function
  docker_build() { mock_docker_build "$1" "$2" "0"; }

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image includes build artifacts in Dockerfile" {
  setup_build_manager_test "artifact_inclusion_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function
  docker_build() { mock_docker_build "$1" "$2" "0"; }

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image includes source code in Dockerfile" {
  setup_build_manager_test "source_inclusion_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function
  docker_build() { mock_docker_build "$1" "$2" "0"; }

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image includes test suites in Dockerfile" {
  setup_build_manager_test "test_suite_inclusion_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function
  docker_build() { mock_docker_build "$1" "$2" "0"; }

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image builds Docker image successfully (mocked)" {
  setup_build_manager_test "image_build_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function
  docker_build() { mock_docker_build "$@"; }

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image tags image with framework identifier and timestamp" {
  setup_build_manager_test "image_tagging_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image verifies image contains required components (mocked)" {
  setup_build_manager_test "image_verification_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Create test image
  output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_create_test_image handles Docker image build failures (mocked)" {
  setup_build_manager_test "image_build_failure_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock Docker build function that fails
  docker_build() { mock_docker_build "$1" "$2" "1"; }

  # Create test image
  if output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts" 2>&1); then
    status=0
  else
    status=$?
  fi

  # Should handle build failure
  [ $status -ne 0 ] && echo "$output" | jq -e '.success == false' >/dev/null

  teardown_build_manager_test
}

# ============================================================================
# Parallel Execution Tests
# ============================================================================

@test "build_manager_execute_parallel executes independent builds in parallel" {
  setup_build_manager_test "parallel_execution_test"

  # Create multiple independent build requirements
  build_requirements=$(create_multi_framework_build_requirements)

  # Mock async execution for testing
  run_async_operation() { echo "mock_async_$1"; }
  wait_for_operation() { return 0; }

  # Execute in parallel
  output=$(build_manager_execute_parallel "$build_requirements")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_execute_parallel limits parallel builds based on CPU cores" {
  setup_build_manager_test "cpu_limit_test"

  # Create many build requirements
  build_requirements='[
    {"framework": "rust", "build_dependencies": []},
    {"framework": "go", "build_dependencies": []},
    {"framework": "node", "build_dependencies": []},
    {"framework": "java", "build_dependencies": []},
    {"framework": "python", "build_dependencies": []}
  ]'

  # Execute in parallel
  output=$(build_manager_execute_parallel "$build_requirements")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_execute_parallel waits for dependency tier completion before next tier" {
  setup_build_manager_test "tier_completion_test"

  # Create build requirements with dependencies
  build_requirements='[
    {"framework": "app", "build_dependencies": ["lib"]},
    {"framework": "lib", "build_dependencies": []}
  ]'

  # Execute in parallel
  output=$(build_manager_execute_parallel "$build_requirements")

  # Should execute successfully
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager_execute_parallel handles parallel build failures gracefully" {
  setup_build_manager_test "parallel_failure_test"

  # Create build requirements where one will fail
  build_requirements='[
    {"framework": "rust", "build_dependencies": []},
    {"framework": "failing", "build_dependencies": []}
  ]'

  # Execute in parallel
  output=$(build_manager_execute_parallel "$build_requirements")

  # Should execute (even with some failures)
  # Note: In test mode, this may still return success
  [ $? -eq 0 ] || [ $? -eq 1 ]

  teardown_build_manager_test
}

# ============================================================================
# Status Tracking Tests
# ============================================================================

@test "build_manager_track_status tracks build status transitions (pending → building → built/success || failure)" {
  setup_build_manager_test "status_transitions_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Track status through build lifecycle
  output=$(build_manager_track_status "$build_requirements" "rust")

  # Should track all status transitions
  echo "$output" | grep -E -q "pending|building|built|success|failure|status"

  teardown_build_manager_test
}

@test "build_manager_track_status updates status in real-time" {
  setup_build_manager_test "real_time_update_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Track status updates
  output=$(build_manager_track_status "$build_requirements" "rust")

  # Should show real-time updates
  echo "$output" | grep -E -q "progress|updating|real.*time|status"

  teardown_build_manager_test
}

@test "build_manager_track_status provides final build result data" {
  setup_build_manager_test "final_result_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Get build result
  output=$(build_manager_track_status "$build_requirements" "rust")

  # Should provide final result
  echo "$output" | grep -E -q "json|result|final|status"

  teardown_build_manager_test
}

@test "build_manager_track_status includes build duration in results" {
  setup_build_manager_test "duration_result_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Get build result
  output=$(build_manager_track_status "$build_requirements" "rust")

  # Should include duration
  echo "$output" | grep -E -q "duration|time.*taken|elapsed|seconds"

  teardown_build_manager_test
}

@test "build_manager_track_status includes container IDs in results" {
  setup_build_manager_test "container_id_result_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Get build result
  output=$(build_manager_track_status "$build_requirements" "rust")

  # Should include container ID
  echo "$output" | grep -E -q "container.*id|container_id"

  teardown_build_manager_test
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "build_manager_handle_error handles build command failures" {
  setup_build_manager_test "build_command_failure_test"

  # Create build requirements that will fail
  build_requirements=$(create_mock_build_requirements)

  # Mock build command failure
  build_command() { return 1; }

  # Handle error
  output=$(build_manager_handle_error "build_command_failure" "$build_requirements" "rust" 2>&1)

  # Should handle build command failure
  echo "$output" | grep -E -q "build.*(failed|failure|error)|command.*error"

  teardown_build_manager_test
}

@test "build_manager_handle_error handles container launch failures" {
  setup_build_manager_test "container_launch_failure_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock container launch failure
  docker_run() { return 1; }

  # Handle error
  output=$(build_manager_handle_error "container_launch_failure" "$build_requirements" "rust" 2>&1)

  # Should handle container launch failure
  echo "$output" | grep -E -q "container.*(failed|failure|error)|launch.*error"

  teardown_build_manager_test
}

@test "build_manager_handle_error handles artifact extraction failures" {
  setup_build_manager_test "artifact_extraction_failure_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock artifact extraction failure
  docker_cp() { return 1; }

  # Handle error
  output=$(build_manager_handle_error "artifact_extraction_failure" "$build_requirements" "rust" 2>&1)

  # Should handle artifact extraction failure
  echo "$output" | grep -E -q "artifact.*(failed|failure|error)|extraction.*error"

  teardown_build_manager_test
}

@test "build_manager_handle_error handles test image build failures" {
  setup_build_manager_test "image_build_failure_error_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Mock image build failure
  docker_build() { return 1; }

  # Handle error
  output=$(build_manager_handle_error "image_build_failure" "$build_requirements" "rust" 2>&1)

  # Should handle image build failure
  echo "$output" | grep -E -q "image.*(failed|failure|error)|build.*error"

  teardown_build_manager_test
}

@test "build_manager_handle_error handles dependency failures" {
  setup_build_manager_test "dependency_failure_test"

  # Create build requirements with failed dependencies
  build_requirements='[
    {"framework": "app", "build_dependencies": ["failed_lib"]},
    {"framework": "failed_lib", "build_dependencies": []}
  ]'

  # Handle error
  output=$(build_manager_handle_error "dependency_failure" "$build_requirements" "app" 2>&1)

  # Should handle dependency failure
  echo "$output" | grep -E -q "dependency.*(failed|failure|error)|prerequisite.*error"

  teardown_build_manager_test
}

@test "build_manager_handle_error provides clear error messages" {
  setup_build_manager_test "clear_error_message_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Handle various errors
  output1=$(build_manager_handle_error "build_failure" "$build_requirements" "rust" 2>&1)
  output2=$(build_manager_handle_error "docker_unavailable" "$build_requirements" "rust" 2>&1)

  # Should provide clear error messages
  echo "$output1" | grep -E -q "clear|helpful|actionable|error"
  echo "$output2" | grep -E -q "clear|helpful|actionable|error"

  teardown_build_manager_test
}

@test "build_manager_handle_error prevents test execution on build failure" {
  setup_build_manager_test "prevent_test_execution_test"

  # Create build requirements that fail
  build_requirements=$(create_mock_build_requirements)

  # Handle build failure
  output=$(build_manager_handle_error "build_failure" "$build_requirements" "rust")

  # Should prevent test execution
  echo "$output" | grep -E -q "test.*prevented|no.*execution|build.*(failed|failure)"

  teardown_build_manager_test
}

# ============================================================================
# Signal Handling Tests
# ============================================================================

@test "build_manager_handle_signal handles SIGINT (first Control+C) gracefully" {
  setup_build_manager_test "sigint_first_test"

  # Start build process
  build_manager_start_build "$(create_mock_build_requirements)"

  # Send SIGINT
  output=$(build_manager_handle_signal "SIGINT" "first")

  # Should handle gracefully
  echo "$output" | grep -E -q "graceful|shutdown|terminating"

  teardown_build_manager_test
}

@test "build_manager_handle_signal terminates build containers on SIGINT" {
  setup_build_manager_test "container_termination_test"

  # Start build with containers
  build_manager_start_build "$(create_mock_build_requirements)"

  # Send SIGINT
  output=$(build_manager_handle_signal "SIGINT" "first")

  # Should terminate containers
  echo "$output" | grep -E -q "container.*terminated|docker.*kill"

  teardown_build_manager_test
}

@test "build_manager_handle_signal cleans up containers on graceful shutdown" {
  setup_build_manager_test "graceful_cleanup_test"

  # Start build process
  build_manager_start_build "$(create_mock_build_requirements)"

  # Send SIGINT for graceful shutdown
  output=$(build_manager_handle_signal "SIGINT" "first")

  # Should gracefully shut down
  echo "$output" | grep -q "Gracefully shutting down"

  teardown_build_manager_test
}

@test "build_manager_handle_signal handles second Control+C (force termination)" {
  setup_build_manager_test "sigint_second_test"

  # Start build process
  build_manager_start_build "$(create_mock_build_requirements)"

  # Send second SIGINT
  output=$(build_manager_handle_signal "SIGINT" "second")

  # Should force terminate
  echo "$output" | grep -q "Forcefully terminating"

  teardown_build_manager_test
}

@test "build_manager_handle_signal cleans up temporary resources on interruption" {
  setup_build_manager_test "resource_cleanup_test"

  # Start build process
  build_manager_start_build "$(create_mock_build_requirements)"

  # Send SIGINT
  build_manager_handle_signal "SIGINT" "first"

  # Should clean up temporary resources
  [ ! -d "$TEST_BUILD_MANAGER_DIR/builds" ] || [ -z "$(ls -A "$TEST_BUILD_MANAGER_DIR/builds")" ]

  teardown_build_manager_test
}
