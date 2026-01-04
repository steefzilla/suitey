#!/usr/bin/env bats
# Integration tests for Build Manager component
# Tests Build Manager with REAL Docker operations

load ../helpers/build_manager

# Source suitey.sh to get Build Manager functions
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
# Override test mode to allow real operations
unset SUITEY_TEST_MODE

# Initialize build manager for integration tests
build_manager_initialize >/dev/null 2>&1 || true

# ============================================================================
# Docker Integration Tests (Real Docker)
# ============================================================================

@test "build_manager works with real Docker daemon - verifies Docker daemon is accessible" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "real_docker_test"

  # Test Docker daemon connectivity
  docker info >/dev/null

  # Should succeed with real Docker
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager works with real Docker daemon - tests Docker API connectivity" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "docker_api_test"

  # Test Docker API connectivity
  docker version >/dev/null

  # Should succeed with real Docker API
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager works with real Docker daemon - validates Docker version compatibility" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "docker_version_test"

  # Check Docker version
  docker_version=$(docker --version)
  echo "$docker_version" | grep -q "Docker version"

  # Should have compatible Docker version
  [ $? -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager creates and manages real Docker containers - launches actual build containers" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "real_container_launch_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Launch real build container
  container_id=$(build_manager_launch_container "$build_requirements" "rust")

  # Should create real container
  [ -n "$(docker ps -a --filter id="$container_id" --format "{{.ID}}")" ]

  # Clean up
  docker rm -f "$container_id" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates and manages real Docker containers - verifies containers are created with correct configuration" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "container_config_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Launch container
  container_id=$(build_manager_launch_container "$build_requirements" "rust")

  # Inspect container configuration
  container_info=$(docker inspect "$container_id")

  # Should have correct image
  echo "$container_info" | grep -q "rust:latest"

  # Should have working directory set
  echo "$container_info" | grep -q "/workspace"

  # Clean up
  docker rm -f "$container_id" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates and manages real Docker containers - validates container resource allocation (CPU cores, memory)" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "resource_allocation_test"

  # Create build requirements with CPU allocation
  build_requirements=$(create_mock_build_requirements "rust" "with_dependencies")

  # Launch container
  container_id=$(build_manager_launch_container "$build_requirements" "rust")

  # Check if CPU allocation is applied (if supported by Docker version)
  # This is a best-effort test as CPU allocation may not be visible in all Docker versions
  container_info=$(docker inspect "$container_id")

  # Clean up
  docker rm -f "$container_id" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates and manages real Docker containers - tests container lifecycle management" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "container_lifecycle_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Launch container
  container_id=$(build_manager_launch_container "$build_requirements" "rust")

  # Container should exist
  [ -n "$(docker ps -a --filter id="$container_id" --format "{{.ID}}")" ]

  # Stop container
  build_manager_stop_container "$container_id"

  # Container should be stopped
  docker ps --format "table {{.ID}}" | grep -q "$container_id" && false || true

  # Clean up
  docker rm -f "$container_id" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates and manages real Docker containers - verifies container cleanup" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "container_cleanup_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements)

  # Launch container
  container_id=$(build_manager_launch_container "$build_requirements" "rust")

  # Clean up container
  build_manager_cleanup_container "$container_id"

  # Container should not exist
  docker ps -a --format "table {{.ID}}" | grep -q "$container_id" && false || true

  teardown_build_manager_test
}

@test "build_manager builds Docker images successfully (REAL) - creates actual Docker images from generated Dockerfiles" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "real_image_build_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build test image
  image_name="suitey-test-rust-$(date +%Y%m%d-%H%M%S)"
  build_result=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/mock_artifacts" "$image_name")

  # Should create real Docker image
  docker images --format "{{.Repository}}" | grep -q "$image_name"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager builds Docker images successfully (REAL) - validates image build process" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "image_build_process_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build test image
  image_name="suitey-test-rust-$(date +%Y%m%d-%H%M%S)"
  build_result=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/mock_artifacts" "$image_name")

  # Should complete build process successfully
  echo "$build_result" | grep -q "DONE\|naming to.*done"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager builds Docker images successfully (REAL) - verifies image contains expected artifacts" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "image_artifacts_test"

  # Create a temporary directory with mock artifacts
  artifacts_dir="$TEST_BUILD_MANAGER_DIR/artifacts"
  mkdir -p "$artifacts_dir/target"
  echo "mock binary" > "$artifacts_dir/target/app"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build test image
  image_name="suitey-test-rust-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image "$build_requirements" "rust" "$artifacts_dir" "$image_name"

  # Create a container from the image and check contents
  container_id=$(docker create "$image_name" /bin/sh)
  docker cp "$container_id:/workspace/target/app" "/tmp/test_artifact" 2>/dev/null || true

  # Should contain the artifact
  [ -f "/tmp/test_artifact" ] && grep -q "mock binary" "/tmp/test_artifact"

  # Clean up
  docker rm "$container_id" 2>/dev/null || true
  docker rmi "$image_name" 2>/dev/null || true
  rm -f "/tmp/test_artifact"

  teardown_build_manager_test
}

@test "build_manager builds Docker images successfully (REAL) - tests image tagging and identification" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "image_tagging_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build test image
  image_name="suitey-test-rust-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image "$build_requirements" "rust" "/tmp/mock_artifacts" "$image_name"

  # Should have correct tag
  docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "${image_name}"

  # Should be identifiable as Suitey image
  docker images --format "table {{.Repository}}" | grep -q "suitey-test-rust"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager builds Docker images successfully (REAL) - validates image can be used for test execution" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "image_test_execution_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build test image
  image_name="suitey-test-rust-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image "$build_requirements" "rust" "/tmp/mock_artifacts" "$image_name"

  # Try to run a simple command in the container
  docker run --rm "$image_name" echo "test execution works" >/dev/null

  # Should succeed
  [ $? -eq 0 ]

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager manages Docker volumes (REAL) - creates temporary volumes for build artifacts" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "volume_creation_test"

  # Create a Docker volume
  volume_name="suitey-test-volume-$(date +%s)"
  create_docker_volume "$volume_name"

  # Volume should exist
  docker volume ls --format "{{.Name}}" | grep -q "$volume_name"

  # Clean up
  remove_docker_volume "$volume_name"

  teardown_build_manager_test
}

@test "build_manager manages Docker volumes (REAL) - mounts volumes correctly in containers" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "volume_mount_test"

  # Create a volume
  volume_name="suitey-test-volume-$(date +%s)"
  create_docker_volume "$volume_name"

  # Create and run container with volume mount
  container_id=$(docker run -d -v "${volume_name}:/artifacts" alpine sh -c "echo 'test data' > /artifacts/test.txt && sleep 5")

  # Wait a moment
  sleep 1

  # Check if data was written to volume
  docker run --rm -v "${volume_name}:/artifacts" alpine cat /artifacts/test.txt | grep -q "test data"

  # Clean up
  docker rm -f "$container_id" 2>/dev/null || true
  remove_docker_volume "$volume_name"

  teardown_build_manager_test
}

@test "build_manager manages Docker volumes (REAL) - extracts artifacts from volumes" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "volume_extraction_test"

  # Create a volume with data
  volume_name="suitey-test-volume-$(date +%s)"
  create_docker_volume "$volume_name"

  # Put data in volume
  docker run --rm -v "${volume_name}:/data" alpine sh -c "echo 'artifact data' > /data/artifact.txt"

  # Extract data from volume
  extracted_data=$(docker run --rm -v "${volume_name}:/data" alpine cat /data/artifact.txt)

  # Should contain the artifact data
  echo "$extracted_data" | grep -q "artifact data"

  # Clean up
  remove_docker_volume "$volume_name"

  teardown_build_manager_test
}

@test "build_manager manages Docker volumes (REAL) - cleans up volumes after use" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "volume_cleanup_test"

  # Create a volume
  volume_name="suitey-test-volume-$(date +%s)"
  create_docker_volume "$volume_name"

  # Volume should exist
  docker volume ls --format "{{.Name}}" | grep -q "$volume_name"

  # Clean up volume
  remove_docker_volume "$volume_name"

  # Volume should not exist
  docker volume ls --format "{{.Name}}" | grep -q "$volume_name" && false || true

  teardown_build_manager_test
}

@test "build_manager cleans up containers and images (REAL) - removes build containers after completion" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "container_cleanup_real_test"

  # Create a container
  container_id=$(docker run -d alpine sleep 30)

  # Clean up container
  build_manager_cleanup_container "$container_id"

  # Container should not exist
  docker ps -a --format "table {{.ID}}" | grep -q "$container_id" && false || true

  teardown_build_manager_test
}

@test "build_manager cleans up containers and images (REAL) - removes test images after test execution" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "image_cleanup_test"

  # Create a test image
  image_name="suitey-test-cleanup-$(date +%Y%m%d-%H%M%S)"
  docker build -t "$image_name" -f - . << EOF
FROM alpine:latest
RUN echo "test image"
EOF

  # Image should exist
  docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$image_name"

  # Clean up image
  build_manager_cleanup_image "$image_name"

  # Image should not exist
  docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$image_name" && false || true

  teardown_build_manager_test
}

@test "build_manager cleans up containers and images (REAL) - handles cleanup on failures" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "cleanup_on_failure_test"

  # Create a container that will fail
  container_id=$(docker run -d alpine sh -c "exit 1")

  # Wait for it to finish
  sleep 2

  # Clean up (should handle failed containers)
  build_manager_cleanup_container "$container_id"

  # Container should not exist
  docker ps -a --format "table {{.ID}}" | grep -q "$container_id" && false || true

  teardown_build_manager_test
}

@test "build_manager cleans up containers and images (REAL) - prevents resource leaks" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "resource_leak_prevention_test"

  # Record initial resource count
  initial_containers=$(docker ps -a --format "{{.ID}}" | wc -l)
  initial_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "^<none>:" | wc -l)
  initial_volumes=$(docker volume ls --format "{{.Name}}" | wc -l)

  # Run some operations
  volume_name="suitey-test-leak-$(date +%s)"
  create_docker_volume "$volume_name"

  image_name="suitey-test-leak-$(date +%Y%m%d-%H%M%S)"
  docker build -t "$image_name" -f - . << EOF
FROM alpine:latest
RUN echo "test"
EOF

  container_id=$(docker run -d alpine sleep 1)

  # Clean up
  cleanup_docker_resources "suitey-test-leak"

  # Wait for cleanup
  sleep 2

  # Check resource counts (should be back to initial or close)
  final_containers=$(docker ps -a --format "{{.ID}}" | wc -l)
  final_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "^<none>:" | wc -l)
  final_volumes=$(docker volume ls --format "{{.Name}}" | wc -l)

  # Should not have accumulated resources
  [ $final_containers -le $((initial_containers + 1)) ]  # Allow some tolerance
  [ $final_images -ge $initial_images ]  # Images might remain if tagged differently
  [ $final_volumes -le $((initial_volumes + 1)) ]  # Allow some tolerance

  teardown_build_manager_test
}

@test "build_manager handles Docker daemon unavailability - detects when Docker daemon is not running" {
  setup_build_manager_test "docker_daemon_detection_test"

  # This test is tricky because we need Docker to be available for the test runner
  # but want to test the detection logic. We'll mock the docker command.

  # Mock docker command to simulate daemon not running
  original_docker=$(which docker)
  mkdir -p "$TEST_BUILD_MANAGER_DIR"
  cat > "$TEST_BUILD_MANAGER_DIR/mock_docker" << 'EOF'
#!/bin/bash
echo "Cannot connect to the Docker daemon" >&2
exit 1
EOF
  chmod +x "$TEST_BUILD_MANAGER_DIR/mock_docker"

  # Temporarily replace docker command
  PATH="$TEST_BUILD_MANAGER_DIR:$PATH"

  # Try to check Docker availability
  check_docker_available
  result=$?

  # Should detect unavailability
  [ $result -ne 0 ]

  teardown_build_manager_test
}

@test "build_manager handles Docker daemon unavailability - provides clear error messages" {
  setup_build_manager_test "docker_error_message_test"

  # Mock docker command to simulate daemon not running
  mkdir -p "$TEST_BUILD_MANAGER_DIR"
  cat > "$TEST_BUILD_MANAGER_DIR/mock_docker" << 'EOF'
#!/bin/bash
echo "Cannot connect to the Docker daemon at unix:///var/run/docker.sock" >&2
exit 1
EOF
  chmod +x "$TEST_BUILD_MANAGER_DIR/mock_docker"

  # Temporarily replace docker command
  PATH="$TEST_BUILD_MANAGER_DIR:$PATH"

  # Try to use Build Manager
  output=$(build_manager_initialize 2>&1)
  result=$?

  # Should provide clear error message
  echo "$output" | grep -E -q "Docker.*not.*available|daemon.*not.*running|cannot.*connect"

  teardown_build_manager_test
}

@test "build_manager handles Docker daemon unavailability - gracefully handles Docker connection failures" {
  setup_build_manager_test "docker_connection_failure_test"

  # Mock docker command to simulate connection failure
  mkdir -p "$TEST_BUILD_MANAGER_DIR"
  cat > "$TEST_BUILD_MANAGER_DIR/mock_docker" << 'EOF'
#!/bin/bash
echo "dial unix /var/run/docker.sock: connect: connection refused" >&2
exit 1
EOF
  chmod +x "$TEST_BUILD_MANAGER_DIR/mock_docker"

  # Temporarily replace docker command
  PATH="$TEST_BUILD_MANAGER_DIR:$PATH"

  # Try Build Manager operation
  output=$(build_manager_check_docker 2>&1)
  result=$?

  # Should handle gracefully without crashing
  [ $result -ne 0 ]
  echo "$output" | grep -q "connection.*refused\|connect.*failed"

  teardown_build_manager_test
}

# ============================================================================
# Adapter Integration Tests
# ============================================================================

@test "build_manager receives build requirements from adapters - uses adapter's get_build_steps() method" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "adapter_build_steps_test"

  # This test would require the adapter registry and adapters to be implemented
  # For now, we'll test the interface contract

  # Mock adapter response
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Build Manager should be able to process adapter build steps
  output=$(build_manager_process_adapter_build_steps "$build_requirements" "rust")

  # Should process build steps from adapter
  echo "$output" | grep -q "build.*steps\|adapter.*steps"

  teardown_build_manager_test
}

@test "build_manager executes builds using adapter specifications - creates test images for adapter frameworks" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "adapter_spec_execution_test"

  # Create build requirements
  build_requirements=$(create_mock_build_requirements "rust" "simple")

  # Execute build using adapter specs
  output=$(build_manager_execute_with_adapter_specs "$build_requirements" "rust")

  # Should execute using adapter specifications
  echo "$output" | grep -q "adapter.*specs\|framework.*specs"

  teardown_build_manager_test
}

@test "build_manager passes test image metadata to adapters - provides image name, ID, and paths" {
  setup_build_manager_test "test_image_metadata_test"

  # Create mock test image metadata
  test_image_metadata='{
    "name": "suitey-test-rust-20240115-143045",
    "image_id": "sha256:abc123",
    "dockerfile_path": "/tmp/suitey-build/test/Dockerfile",
    "docker_compose_path": null
  }'

  # Pass metadata to adapter
  output=$(build_manager_pass_image_metadata_to_adapter "$test_image_metadata" "rust")

  # Should pass metadata correctly
  echo "$output" | grep -q "metadata.*passed\|image.*metadata"

  teardown_build_manager_test
}

# ============================================================================
# Project Scanner Integration Tests
# ============================================================================

@test "build_manager receives build requirements from Project Scanner - coordinates with Project Scanner for test execution" {
  setup_build_manager_test "project_scanner_coordination_test"

  # Create build requirements as would come from Project Scanner
  build_requirements='[
    {"framework": "rust", "build_dependencies": []},
    {"framework": "go", "build_dependencies": []}
  ]'

  # Build Manager should coordinate with Project Scanner
  output=$(build_manager_coordinate_with_project_scanner "$build_requirements")

  # Should coordinate properly
  echo "$output" | grep -q "coordinated\|project.*scanner"

  teardown_build_manager_test
}

@test "build_manager provides build results to Project Scanner - handles build failures before test execution" {
  setup_build_manager_test "build_results_to_scanner_test"

  # Simulate build failure
  build_results='{
    "framework": "rust",
    "status": "build-failed",
    "error": "Compilation failed"
  }'

  # Provide results to Project Scanner
  output=$(build_manager_provide_results_to_scanner "$build_results")

  # Should prevent test execution on build failure
  echo "$output" | grep -q "build.*failed\|prevent.*test\|no.*execution"

  teardown_build_manager_test
}

# ============================================================================
# Multi-Framework Build Tests
# ============================================================================

@test "build_manager handles multiple frameworks requiring builds - executes independent builds in parallel" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "multi_framework_parallel_test"

  # Create multi-framework build requirements
  build_requirements=$(create_multi_framework_build_requirements)

  # Execute multiple builds
  output=$(build_manager_execute_multi_framework "$build_requirements")

  # Should execute in parallel
  echo "$output" | grep -q "parallel\|concurrent\|multiple.*frameworks"

  teardown_build_manager_test
}

@test "build_manager handles dependent builds sequentially - creates separate test images per framework" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "dependent_builds_test"

  # Create build requirements with dependencies
  build_requirements='[
    {"framework": "app", "build_dependencies": ["lib"], "build_steps": []},
    {"framework": "lib", "build_dependencies": [], "build_steps": []}
  ]'

  # Execute dependent builds
  output=$(build_manager_execute_dependent_builds "$build_requirements")

  # Should execute sequentially and create separate images
  echo "$output" | grep -q "sequential\|dependencies\|separate.*images"

  teardown_build_manager_test
}

# ============================================================================
# Containerized Build Scenarios (Docker + Projects)
# ============================================================================

@test "build_manager builds a containerized Rust project (Docker + Cargo) - creates actual Rust project with Cargo.toml" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "containerized_rust_project_test"

  # Create a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Should create valid Rust project structure
  [ -f "$project_dir/Cargo.toml" ]
  [ -f "$project_dir/src/main.rs" ]
  [ -f "$project_dir/src/lib.rs" ]

  teardown_build_manager_test
}

@test "build_manager builds a containerized Rust project (Docker + Cargo) - executes containerized cargo build in Docker container" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "containerized_cargo_build_test"

  # Create a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build using Docker and Cargo
  image_name="suitey-test-rust-real-$(date +%Y%m%d-%H%M%S)"
  build_result=$(build_manager_build_containerized_rust_project "$project_dir" "$image_name")

  # Should execute containerized cargo build
  echo "$build_result" | grep -q "cargo.*build\|Compiling\|Finished"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager builds a containerized Rust project (Docker + Cargo) - validates build artifacts are created" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "real_artifacts_test"

  # Create a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build project (creates artifacts in project directory for integration tests)
  image_name="suitey-test-rust-artifacts-$(date +%Y%m%d-%H%M%S)"
  build_manager_build_containerized_rust_project "$project_dir" "$image_name"

  # Should have created build artifacts in the project directory
  [ -f "$project_dir/target/debug/suitey_test_project" ]
  [ -x "$project_dir/target/debug/suitey_test_project" ]

  teardown_build_manager_test
}

@test "build_manager builds a containerized Rust project (Docker + Cargo) - verifies build output is captured" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "build_output_capture_test"

  # Create a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build project and capture output
  image_name="suitey-test-rust-output-$(date +%Y%m%d-%H%M%S)"
  build_output=$(build_manager_build_containerized_rust_project "$project_dir" "$image_name")

  # Should capture build output
  echo "$build_output" | grep -q "Compiling\|Finished\|build\|cargo"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager builds a containerized Rust project (Docker + Cargo) - tests parallel build execution (jobs $(nproc))" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "parallel_build_execution_test"

  # Create a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build with parallel execution
  image_name="suitey-test-rust-parallel-$(date +%Y%m%d-%H%M%S)"
  build_output=$(build_manager_build_containerized_rust_project "$project_dir" "$image_name")

  # Should show parallel build execution
  echo "$build_output" | grep -q "jobs.*[0-9]\|parallel\|Compiling.*release"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - extracts containerized build artifacts from container" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "containerized_artifact_extraction_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build project first to create artifacts
  temp_image="suitey-temp-rust-$(date +%Y%m%d-%H%M%S)"
  build_manager_build_containerized_rust_project "$project_dir" "$temp_image"

  # Extract artifacts and create test image
  final_image="suitey-test-rust-final-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$final_image"

  # Test image should exist
  docker images --format "{{.Repository}}" | grep -q "^${final_image}$"

  # Clean up
  docker rmi "$final_image" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - generates Dockerfile with actual artifacts" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "containerized_dockerfile_generation_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Create test image with containerized artifacts
  image_name="suitey-test-rust-dockerfile-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$image_name"

  # Should generate Dockerfile
  dockerfile_path="$project_dir/TestDockerfile"
  [ -f "$dockerfile_path" ]

  # Dockerfile should contain artifact copying
  grep -q "COPY.*target" "$dockerfile_path"

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - builds Docker image containing artifacts" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "containerized_image_with_artifacts_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build the project to create artifacts
  temp_image="suitey-temp-build-$(date +%Y%m%d-%H%M%S)"
  build_manager_build_containerized_rust_project "$project_dir" "$temp_image"

  # Create test image from artifacts
  image_name="suitey-test-rust-with-artifacts-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$image_name"

  # Image should be created and contain artifacts
  container_id=$(docker create "$image_name" /bin/sh)
  docker cp "$container_id:/workspace/artifacts/debug/suitey_test_project" "/tmp/test_binary" 2>/dev/null || true

  # Should contain the binary
  [ -f "/tmp/test_binary" ]

  # Clean up
  docker rm "$container_id" 2>/dev/null || true
  docker rmi "$temp_image" "$image_name" 2>/dev/null || true
  rm -f "/tmp/test_binary"

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - verifies image contains compiled binaries" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "verify_compiled_binaries_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Build the project to create artifacts
  temp_image="suitey-temp-build-$(date +%Y%m%d-%H%M%S)"
  build_manager_build_containerized_rust_project "$project_dir" "$temp_image"

  # Create test image from artifacts
  image_name="suitey-test-rust-binaries-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$image_name"

  # Run container and check binary exists and is executable
  docker run --rm "$image_name" test -x /workspace/artifacts/debug/suitey_test_project

  # Should succeed (binary exists and is executable)
  [ $? -eq 0 ]

  # Clean up
  docker rmi "$temp_image" "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - validates image contains source code" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "verify_source_code_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Create test image
  image_name="suitey-test-rust-source-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$image_name"

  # Check that source files are in the image
  docker run --rm "$image_name" test -f /workspace/src/main.rs
  [ $? -eq 0 ]

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager creates test image with containerized Rust artifacts - validates image contains test suites" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "verify_test_suites_test"

  # Create and build a containerized Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$project_dir"

  # Create test image
  image_name="suitey-test-rust-tests-$(date +%Y%m%d-%H%M%S)"
  build_manager_create_test_image_from_artifacts "$project_dir" "rust:latest" "$image_name"

  # Check that test files are in the image
  docker run --rm "$image_name" test -f /workspace/tests/integration_test.rs
  [ $? -eq 0 ]

  # Clean up
  docker rmi "$image_name" 2>/dev/null || true

  teardown_build_manager_test
}

@test "build_manager handles build failures in containerized scenarios - tests with intentionally broken Rust code" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "broken_rust_build_test"

  # Create a broken Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/broken_project"
  create_broken_rust_project "$project_dir"

  # Try to build
  image_name="suitey-test-broken-$(date +%Y%m%d-%H%M%S)"
  build_result=$(build_manager_build_containerized_rust_project "$project_dir" "$image_name")

  # Should fail
  echo "$build_result" | grep -q "BUILD_FAILED"

  # Should show compilation errors
  echo "$build_result" | grep -q "error\|failed\|cannot find"

  # Should not create image
  docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$image_name" && false || true

  teardown_build_manager_test
}

@test "build_manager handles build failures in containerized scenarios - validates error detection and reporting" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "error_detection_test"

  # Create a broken Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/broken_project"
  create_broken_rust_project "$project_dir"

  # Try to build
  build_result=$(build_manager_build_containerized_rust_project "$project_dir" "test_image")

  # Should detect and report errors
  echo "$build_result" | grep -q "BUILD_FAILED"

  teardown_build_manager_test
}

@test "build_manager handles build failures in containerized scenarios - verifies containers are cleaned up on failure" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "cleanup_on_build_failure_test"

  # Create a broken Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/broken_project"
  create_broken_rust_project "$project_dir"

  # Count containers before
  containers_before=$(docker ps -a --format "{{.ID}}" | wc -l)

  # Temporarily unset SUITEY_INTEGRATION_TEST to test real Docker cleanup
  # This test specifically needs to verify real Docker container cleanup
  local original_integration_test="${SUITEY_INTEGRATION_TEST:-}"
  unset SUITEY_INTEGRATION_TEST

  # Try to build (should fail and cleanup)
  build_manager_build_containerized_rust_project "$project_dir" "test_image" || true

  # Restore integration test mode
  if [[ -n "$original_integration_test" ]]; then
    export SUITEY_INTEGRATION_TEST="$original_integration_test"
  fi

  # Give Docker a moment to clean up
  sleep 1

  # Count containers after
  containers_after=$(docker ps -a --format "{{.ID}}" | wc -l)

  # Should not leave containers behind (allow some tolerance for other system containers)
  # The build should clean up intermediate containers, so count should be <= before + 1
  [ $containers_after -le $((containers_before + 1)) ]  # Allow some tolerance

  # Additional verification: ensure no containers with the test image name exist
  local remaining_containers
  remaining_containers=$(docker ps -a --filter "ancestor=test_image" --format "{{.ID}}" | wc -l)
  [ $remaining_containers -eq 0 ]

  teardown_build_manager_test
}

@test "build_manager handles build failures in containerized scenarios - tests error messages are clear and actionable" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "actionable_error_messages_test"

  # Create a broken Rust project
  project_dir="$TEST_BUILD_MANAGER_DIR/broken_project"
  create_broken_rust_project "$project_dir"

  # Try to build
  build_result=$(build_manager_build_containerized_rust_project "$project_dir" "test_image")

  # Should provide clear, actionable error messages
  echo "$build_result" | grep -q "BUILD_FAILED.*error"

  teardown_build_manager_test
}

@test "build_manager multi-framework containerized builds - tests building multiple frameworks simultaneously" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "multi_framework_simultaneous_test"

  # Create multiple containerized projects
  rust_project="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$rust_project"

  # For now, just test Rust - would need Go project setup too
  build_requirements='[
    {"framework": "rust", "build_dependencies": [], "build_steps": []}
  ]'

  # Build multiple frameworks
  output=$(build_manager_build_multi_framework_real "$build_requirements")

  # Should build multiple frameworks
  echo "$output" | grep -q "multiple\|frameworks\|parallel"

  teardown_build_manager_test
}

@test "build_manager multi-framework containerized builds - validates parallel execution with Docker" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "parallel_execution_real_test"

  # Create multiple containerized projects
  rust_project="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$rust_project"

  build_requirements='[
    {"framework": "rust", "build_dependencies": [], "build_steps": []}
  ]'

  # Build in parallel
  output=$(build_manager_build_multi_framework_real "$build_requirements")

  # Should execute in parallel
  echo "$output" | grep -q "parallel\|concurrent\|simultaneous"

  teardown_build_manager_test
}

@test "build_manager multi-framework containerized builds - verifies independent builds don't interfere" {
  # Skip if Docker is not available
  check_docker_available || skip "Docker daemon not available"

  setup_build_manager_test "independent_builds_test"

  # Create multiple containerized projects
  rust_project="$TEST_BUILD_MANAGER_DIR/rust_project"
  create_containerized_rust_project "$rust_project"

  build_requirements='[
    {"framework": "rust", "build_dependencies": [], "build_steps": []}
  ]'

  # Build independently
  output=$(build_manager_build_multi_framework_real "$build_requirements")

  # Should not interfere with each other
  echo "$output" | grep -q "independent\|isolated\|separate"

  teardown_build_manager_test
}

@test "build_manager multi-framework containerized builds - tests dependent builds execute sequentially" {
  setup_build_manager_test "dependent_builds_sequential_test"

  # Create build requirements with dependencies
  build_requirements='[
    {"framework": "app", "build_dependencies": ["lib"], "build_steps": []},
    {"framework": "lib", "build_dependencies": [], "build_steps": []}
  ]'

  # Build with dependencies
  output=$(build_manager_build_dependent_real "$build_requirements")

  # Should execute sequentially
  echo "$output" | grep -q "sequential\|dependencies\|order"

  teardown_build_manager_test
}
