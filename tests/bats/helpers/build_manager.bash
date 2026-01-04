#!/usr/bin/env bash
# Helper functions for Build Manager tests

# ============================================================================
# Setup/Teardown Functions
# ============================================================================

# Create a temporary directory for Build Manager testing
setup_build_manager_test() {
  local test_name="${1:-build_manager_test}"
  TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_manager_test_${test_name}_XXXXXX")
  export TEST_BUILD_MANAGER_DIR

  # Set PROJECT_ROOT for build manager tests
  PROJECT_ROOT="${PROJECT_ROOT:-/tmp/test_project_root}"
  export PROJECT_ROOT

  # Set test mode for build manager (skip for integration tests)
  if [[ -z "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    SUITEY_TEST_MODE=1
    export SUITEY_TEST_MODE
  fi

  # Initialize mock manager for this test
  mock_manager_init "$test_name"

  echo "$TEST_BUILD_MANAGER_DIR"
}

# Clean up temporary directory and build manager state
teardown_build_manager_test() {
  # Clean up async operations first
  cleanup_async_operations 2>/dev/null || true

  # Clean up environment simulation
  cleanup_environment_simulation 2>/dev/null || true

  if [[ -n "${TEST_BUILD_MANAGER_DIR:-}" ]] && [[ -d "$TEST_BUILD_MANAGER_DIR" ]]; then
    rm -rf "$TEST_BUILD_MANAGER_DIR" 2>/dev/null || true
    unset TEST_BUILD_MANAGER_DIR
  fi

  # Clean up build manager state files
  rm -f /tmp/suitey_build_manager_* /tmp/suitey_build_* 2>/dev/null || true
  # Clean up async operation files
  rm -f /tmp/async_operation_* 2>/dev/null || true
  # Clean up environment simulation files
  rm -f /tmp/mock_* 2>/dev/null || true
  # Clean up any test directories that might be left
  find /tmp -maxdepth 1 -name "suitey_build_manager_test_*" -type d -exec rm -rf {} + 2>/dev/null \; || true

  # Reset mock manager
  mock_manager_reset 2>/dev/null || true
}

# Source mock manager for enhanced functionality
if [[ -f "${BATS_TEST_DIRNAME}/mock_manager.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/mock_manager.bash"
elif [[ -f "${BATS_TEST_DIRNAME}/../helpers/mock_manager.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/../helpers/mock_manager.bash"
fi

# Source async test helpers for background operations
if [[ -f "${BATS_TEST_DIRNAME}/async_test_helpers.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/async_test_helpers.bash"
elif [[ -f "${BATS_TEST_DIRNAME}/../helpers/async_test_helpers.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/../helpers/async_test_helpers.bash"
fi

# Source environment simulator for comprehensive testing
if [[ -f "${BATS_TEST_DIRNAME}/environment_simulator.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/environment_simulator.bash"
elif [[ -f "${BATS_TEST_DIRNAME}/../helpers/environment_simulator.bash" ]]; then
  source "${BATS_TEST_DIRNAME}/../helpers/environment_simulator.bash"
fi

# ============================================================================
# Mock Docker Operations (for Unit Tests)
# ============================================================================

# Mock Docker container run
mock_docker_run() {
  local container_name="$1"
  local image="$2"
  local command="$3"
  local exit_code="${4:-0}"
  local output="${5:-Mock Docker run output}"

  # Initialize mock manager if not already done
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "docker_run_test"
  fi

  # Simulate container creation and execution
  echo "mock_container_${container_name}_$(date +%s)" > "/tmp/suitey_build_mock_container_${container_name}"

  # Generate contextual response based on test context
  local contextual_output="$output"

  # Check for CPU allocation context
  local cpu_context
  cpu_context=$(mock_manager_get_state "cpu_cores" 2>/dev/null || echo "")
  if [[ -n "$cpu_context" ]]; then
    contextual_output=$(generate_cpu_response "$cpu_context")
  fi

  # Check for duration context
  local duration_context
  duration_context=$(_mock_manager_get_context "duration_test")
  if [[ -n "$duration_context" ]]; then
    contextual_output=$(generate_duration_response)
  fi

  # Check for error context
  local error_context
  error_context=$(_mock_manager_get_context "error_test")
  if [[ -n "$error_context" ]]; then
    contextual_output=$(generate_error_response "container_fail")
    exit_code=$?
  fi

  # Check for status context
  local status_context
  status_context=$(_mock_manager_get_context "status_test")
  if [[ -n "$status_context" ]]; then
    contextual_output=$(generate_status_response "building")
  fi

  # Check for dependency installation context
  local dependency_context
  dependency_context=$(_mock_manager_get_context "dependency_test")
  if [[ -n "$dependency_context" ]]; then
    contextual_output="Dependencies installed successfully. Build command executed."
  fi

  # Return contextual mock output
  if [[ $exit_code -eq 0 ]]; then
    echo "$contextual_output"
    return 0
  else
    echo "ERROR: $contextual_output" >&2
    return $exit_code
  fi
}

# Mock Docker build
mock_docker_build() {
  local context_dir="$1"
  local image_name="$2"
  local exit_code="${3:-0}"

  # Initialize mock manager if not already done
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "docker_build_test"
  fi

  # Simulate image build
  if [[ $exit_code -eq 0 ]]; then
    echo "sha256:mock$(date +%s)" > "/tmp/suitey_build_mock_image_${image_name//:/_}"

    # Generate contextual response
    local contextual_output="Successfully built $image_name"

    # Check for image creation context
    local image_context
    image_context=$(_mock_manager_get_context "image_test")
    if [[ -n "$image_context" ]]; then
      contextual_output="Successfully built $image_name with artifacts and source code included"
    fi

    echo "$contextual_output"
    return 0
  else
    # Check for error context
    local error_context
    error_context=$(_mock_manager_get_context "error_test")
    if [[ -n "$error_context" ]]; then
      echo "ERROR: Failed to build Docker image - $(generate_error_response "image_build_fail")" >&2
      return $exit_code
    else
      echo "ERROR: Failed to build Docker image" >&2
      return $exit_code
    fi
  fi
}

# Mock Docker container exec
mock_docker_exec() {
  local container_id="$1"
  local command="$2"
  local exit_code="${3:-0}"
  local output="${4:-Mock Docker exec output}"

  # Simulate command execution in container
  if [[ $exit_code -eq 0 ]]; then
    echo "$output"
    return 0
  else
    echo "ERROR: $output" >&2
    return $exit_code
  fi
}

# Mock Docker container copy
mock_docker_cp() {
  local container_id="$1"
  local source="$2"
  local dest="$3"
  local exit_code="${4:-0}"

  # Initialize mock manager if not already done
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "docker_cp_test"
  fi

  # Simulate file copy from container
  if [[ $exit_code -eq 0 ]]; then
    mkdir -p "$(dirname "$dest")"

    # Generate contextual response for artifact operations
    local contextual_content="copied from $container_id:$source to $dest"

    # Check for artifact context
    local artifact_context
    artifact_context=$(_mock_manager_get_context "artifact_test")
    if [[ -n "$artifact_context" ]]; then
      contextual_content=$(generate_artifact_response "copy" "$dest")
    fi

    echo "$contextual_content" > "$dest"
    return 0
  else
    # Check for error context
    local error_context
    error_context=$(_mock_manager_get_context "error_test")
    if [[ -n "$error_context" ]]; then
      echo "ERROR: $(generate_error_response "artifact_fail")" >&2
      return $exit_code
    else
      echo "ERROR: Failed to copy from container" >&2
      return $exit_code
    fi
  fi
}

# ============================================================================
# Real Docker Operations (for Integration Tests)
# ============================================================================

# Check if Docker is available
check_docker_available() {
  # Check if Docker command is available
  if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker command not found in PATH"
    return 1
  fi

  # Check Docker daemon connectivity
  if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon not accessible - check if Docker is running"
    return 1
  fi

  # Check Docker API connectivity
  if ! docker version &> /dev/null; then
    echo "ERROR: Docker API not accessible"
    return 1
  fi

  # Check available disk space (minimum 1GB for Docker operations)
  local docker_root
  docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
  local available_space
  available_space=$(df -k "$docker_root" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")

  if [[ $available_space -lt 1048576 ]]; then  # 1GB = 1048576 KB
    echo "ERROR: Insufficient disk space for Docker operations (${available_space}KB available, need at least 1GB)"
    return 1
  fi

  return 0
}

# Comprehensive Docker environment validation for integration tests
check_docker_environment() {
  echo "Validating Docker environment for integration tests..."

  # Basic availability checks
  if ! check_docker_available; then
    return 1
  fi

  # Check Docker version compatibility
  local docker_version
  docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  echo "Docker version: $docker_version"

  # Extract major.minor version for comparison
  local major_version
  major_version=$(echo "$docker_version" | cut -d. -f1)
  local minor_version
  minor_version=$(echo "$docker_version" | cut -d. -f2)

  # Require Docker 20.10+ for modern features
  if [[ $major_version -lt 20 ]] || [[ $major_version -eq 20 && $minor_version -lt 10 ]]; then
    echo "WARNING: Docker version $docker_version may not support all required features"
    echo "Recommended: Docker 20.10+ for optimal compatibility"
  fi

  # Check for required Docker features
  if ! docker buildx version &>/dev/null; then
    echo "WARNING: Buildx not available - some advanced build features may not work"
  fi

  # Check network connectivity for image pulls
  if ! timeout 10 docker run --rm -q alpine:latest echo "test" &>/dev/null; then
    echo "WARNING: Cannot pull Docker images - check network connectivity"
    return 1
  fi

  # Check available resources
  local total_memory
  total_memory=$(docker info --format '{{.MemTotal}}' 2>/dev/null | sed 's/[^0-9]*//g' || echo "0")
  if [[ $total_memory -lt 1073741824 ]]; then  # 1GB = 1073741824 bytes
    echo "WARNING: Limited memory available for Docker (${total_memory} bytes)"
  fi

  echo "Docker environment validation completed successfully"
  return 0
}

# Safe Docker operation wrapper with timeout and error handling
# Arguments:
#   operation: Docker operation to execute
#   timeout: Timeout in seconds (default: 300)
# Returns: 0 on success, 1 on failure
safe_docker_operation() {
  local operation="$1"
  local timeout="${2:-300}"  # 5 minutes default

  echo "Executing Docker operation: $operation (timeout: ${timeout}s)"

  # Execute with timeout and capture output
  local output
  local exit_code

  # Use timeout to prevent hanging operations
  if output=$(timeout "$timeout" bash -c "$operation" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  # Log the result
  if [[ $exit_code -eq 0 ]]; then
    echo "Docker operation completed successfully"
    return 0
  else
    echo "Docker operation failed (exit code: $exit_code)" >&2
    echo "Operation: $operation" >&2
    echo "Output: $output" >&2

    # Attempt cleanup on failure
    cleanup_docker_resources_on_failure

    return 1
  fi
}

# Cleanup Docker resources after failed operations
cleanup_docker_resources_on_failure() {
  echo "Attempting to clean up Docker resources after failure..." >&2

  # Remove dangling containers
  docker ps -aq --filter "status=exited" | xargs -r docker rm -f 2>/dev/null || true

  # Remove dangling images
  docker images -q --filter "dangling=true" | xargs -r docker rmi -f 2>/dev/null || true

  # Clean up volumes
  docker volume ls -q --filter "dangling=true" | xargs -r docker volume rm 2>/dev/null || true
}

# Clean up Docker resources created during tests
# Comprehensive cleanup of Docker resources
cleanup_docker_resources() {
  local pattern="${1:-suitey-test-*}"

  echo "Cleaning up Docker resources with pattern: $pattern"

  # Remove containers (running and stopped)
  docker ps -aq --filter "name=$pattern" | xargs -r docker rm -f 2>/dev/null || true

  # Remove images
  docker images -q --filter "reference=$pattern*" | xargs -r docker rmi -f 2>/dev/null || true

  # Remove volumes
  docker volume ls -q --filter "name=$pattern*" | xargs -r docker volume rm 2>/dev/null || true

  # Remove networks
  docker network ls -q --filter "name=$pattern*" | xargs -r docker network rm 2>/dev/null || true

  echo "Docker resource cleanup completed"
}

# Cleanup Docker containers specifically
cleanup_docker_containers() {
  local pattern="${1:-suitey-test-*}"

  echo "Cleaning up Docker containers with pattern: $pattern"
  docker ps -aq --filter "name=$pattern" | xargs -r docker rm -f 2>/dev/null || true
  echo "Container cleanup completed"
}

# Cleanup Docker images specifically
cleanup_docker_images() {
  local pattern="${1:-suitey-test-*}"

  echo "Cleaning up Docker images with pattern: $pattern"
  docker images -q --filter "reference=$pattern*" | xargs -r docker rmi -f 2>/dev/null || true
  echo "Image cleanup completed"
}

# Cleanup Docker volumes specifically
cleanup_docker_volumes() {
  local pattern="${1:-suitey-test-*}"

  echo "Cleaning up Docker volumes with pattern: $pattern"
  docker volume ls -q --filter "name=$pattern*" | xargs -r docker volume rm 2>/dev/null || true
  echo "Volume cleanup completed"
}

# Cleanup Docker networks specifically
cleanup_docker_networks() {
  local pattern="${1:-suitey-test-*}"

  echo "Cleaning up Docker networks with pattern: $pattern"
  docker network ls -q --filter "name=$pattern*" | xargs -r docker network rm 2>/dev/null || true
  echo "Network cleanup completed"
}

# Cleanup all Docker resources aggressively
cleanup_all_docker_resources() {
  echo "Performing aggressive Docker resource cleanup..."

  # Remove all stopped containers
  docker container prune -f 2>/dev/null || true

  # Remove unused images
  docker image prune -f 2>/dev/null || true

  # Remove unused volumes
  docker volume prune -f 2>/dev/null || true

  # Remove unused networks
  docker network prune -f 2>/dev/null || true

  echo "Aggressive Docker cleanup completed"
}

# ============================================================================
# Test Isolation and Resource Management
# ============================================================================

# Generate unique test resource names to prevent conflicts
generate_test_resource_name() {
  local prefix="${1:-test}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local random_suffix
  random_suffix=$(printf "%04x" $((RANDOM % 65536)))

  echo "${prefix}_${timestamp}_${random_suffix}"
}

# Create isolated Docker network for test
create_test_network() {
  local network_name
  network_name=$(generate_test_resource_name "suitey_net")

  echo "Creating test network: $network_name"
  docker network create "$network_name" 2>/dev/null || echo "Failed to create network"

  echo "$network_name"
}

# Setup test environment with isolation
setup_test_isolation() {
  local test_name="${1:-integration_test}"

  echo "Setting up test isolation for: $test_name"

  # Generate unique identifiers
  export TEST_CONTAINER_PREFIX="suitey_${test_name}_$(date +%s)_$$"
  export TEST_NETWORK_NAME="suitey_net_${test_name}_$(date +%s)_$$"
  export TEST_VOLUME_PREFIX="suitey_vol_${test_name}_$(date +%s)_$$"

  # Create isolated network
  docker network create "$TEST_NETWORK_NAME" 2>/dev/null || true

  echo "Test isolation setup complete"
  echo "Container prefix: $TEST_CONTAINER_PREFIX"
  echo "Network: $TEST_NETWORK_NAME"
  echo "Volume prefix: $TEST_VOLUME_PREFIX"
}

# Cleanup test isolation resources
cleanup_test_isolation() {
  echo "Cleaning up test isolation resources..."

  # Remove test-specific containers
  if [[ -n "${TEST_CONTAINER_PREFIX:-}" ]]; then
    cleanup_docker_containers "$TEST_CONTAINER_PREFIX"
  fi

  # Remove test-specific volumes
  if [[ -n "${TEST_VOLUME_PREFIX:-}" ]]; then
    cleanup_docker_volumes "$TEST_VOLUME_PREFIX"
  fi

  # Remove test network
  if [[ -n "${TEST_NETWORK_NAME:-}" ]]; then
    docker network rm "$TEST_NETWORK_NAME" 2>/dev/null || true
  fi

  # Clean up environment variables
  unset TEST_CONTAINER_PREFIX
  unset TEST_NETWORK_NAME
  unset TEST_VOLUME_PREFIX

  echo "Test isolation cleanup complete"
}

# Get unique container name for test
get_test_container_name() {
  local base_name="${1:-container}"
  echo "${TEST_CONTAINER_PREFIX:-suitey_test}_${base_name}"
}

# Get unique volume name for test
get_test_volume_name() {
  local base_name="${1:-volume}"
  echo "${TEST_VOLUME_PREFIX:-suitey_vol}_${base_name}"
}

# Enhanced teardown with comprehensive cleanup
enhanced_teardown_build_manager_test() {
  echo "Performing enhanced test teardown..."

  # Clean up test isolation resources
  cleanup_test_isolation

  # Clean up general test resources
  teardown_build_manager_test

  echo "Enhanced teardown completed"
}

# Create a real Docker volume
create_docker_volume() {
  local volume_name="$1"
  docker volume create "$volume_name" 2>/dev/null || true
  echo "$volume_name"
}

# Remove a Docker volume
remove_docker_volume() {
  local volume_name="$1"
  docker volume rm "$volume_name" 2>/dev/null || true
}

# ============================================================================
# Build Requirements Fixtures
# ============================================================================

# Create mock build requirements for a single framework
create_mock_build_requirements() {
  local framework="${1:-rust}"
  local build_type="${2:-simple}"

  case "$build_type" in
    "simple")
      cat << EOF
[
  {
    "framework": "$framework",
    "build_steps": [
      {
        "step_name": "compile",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "",
        "build_command": "${framework} build --jobs \$(nproc)",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {},
        "cpu_cores": null
      }
    ],
    "build_dependencies": [],
    "artifact_storage": {
      "artifacts": ["target/"],
      "source_code": ["src/"],
      "test_suites": ["tests/"]
    }
  }
]
EOF
      ;;
    "with_dependencies")
      cat << EOF
[
  {
    "framework": "$framework",
    "build_steps": [
      {
        "step_name": "install_deps",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "${framework} deps install",
        "build_command": "${framework} build --jobs \$(nproc)",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {},
        "cpu_cores": 2
      }
    ],
    "build_dependencies": ["dep1", "dep2"],
    "artifact_storage": {
      "artifacts": ["target/", "build/"],
      "source_code": ["src/", "lib/"],
      "test_suites": ["tests/", "integration/"]
    }
  }
]
EOF
      ;;
    "multi_step")
      cat << EOF
[
  {
    "framework": "$framework",
    "build_steps": [
      {
        "step_name": "install_deps",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "${framework} deps install",
        "build_command": "",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {},
        "cpu_cores": 1
      },
      {
        "step_name": "compile",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "",
        "build_command": "${framework} build --jobs \$(nproc)",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {"BUILD_MODE": "release"},
        "cpu_cores": null
      }
    ],
    "build_dependencies": [],
    "artifact_storage": {
      "artifacts": ["target/"],
      "source_code": ["src/"],
      "test_suites": ["tests/"]
    }
  }
]
EOF
      ;;
    "complex")
      cat << EOF
[
  {
    "framework": "$framework",
    "build_steps": [
      {
        "step_name": "setup",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "${framework} setup",
        "build_command": "echo 'Setup complete'",
        "working_directory": "/workspace",
        "volume_mounts": ["/tmp/cache:/cache"],
        "environment_variables": {"SETUP": "true"},
        "cpu_cores": 1
      },
      {
        "step_name": "build",
        "docker_image": "${framework}:latest",
        "install_dependencies_command": "",
        "build_command": "${framework} build --jobs \$(nproc) --release",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {"RUSTFLAGS": "-C target-cpu=native"},
        "cpu_cores": null
      }
    ],
    "build_dependencies": ["rustfmt", "clippy"],
    "artifact_storage": {
      "artifacts": ["target/release/", "target/debug/"],
      "source_code": ["src/", "benches/", "examples/"],
      "test_suites": ["tests/", "benches/"]
    }
  }
]
EOF
      ;;
  esac
}

# Create mock build requirements for multiple frameworks
create_multi_framework_build_requirements() {
  cat << EOF
[
  {
    "framework": "rust",
    "build_steps": [
      {
        "step_name": "compile",
        "docker_image": "rust:latest",
        "install_dependencies_command": "",
        "build_command": "cargo build --jobs \$(nproc)",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {},
        "cpu_cores": null
      }
    ],
    "build_dependencies": [],
    "artifact_storage": {
      "artifacts": ["target/"],
      "source_code": ["src/"],
      "test_suites": ["tests/"]
    }
  },
  {
    "framework": "go",
    "build_steps": [
      {
        "step_name": "compile",
        "docker_image": "golang:latest",
        "install_dependencies_command": "go mod download",
        "build_command": "go build -v ./...",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {"GOOS": "linux"},
        "cpu_cores": 2
      }
    ],
    "build_dependencies": [],
    "artifact_storage": {
      "artifacts": ["bin/"],
      "source_code": ["*.go", "cmd/", "pkg/"],
      "test_suites": ["*_test.go"]
    }
  }
]
EOF
}

# Create empty build requirements
create_empty_build_requirements() {
  echo "[]"
}

# Create invalid build requirements
create_invalid_build_requirements() {
  local invalid_type="${1:-missing_framework}"

  case "$invalid_type" in
    "missing_framework")
      cat << EOF
[
  {
    "build_steps": [
      {
        "step_name": "compile",
        "docker_image": "rust:latest",
        "install_dependencies_command": "",
        "build_command": "cargo build",
        "working_directory": "/workspace",
        "volume_mounts": [],
        "environment_variables": {},
        "cpu_cores": null
      }
    ]
  }
]
EOF
      ;;
    "invalid_json")
      echo '[{"framework": "rust", "build_steps": [invalid json structure]'
      ;;
  esac
}

# ============================================================================
# Build Result Assertions
# ============================================================================

# Assert build status matches expected
assert_build_status() {
  local build_result="$1"
  local expected_status="$2"

  local actual_status
  actual_status=$(echo "$build_result" | grep -o '"status": *"[^"]*"' | cut -d'"' -f4)

  if [[ "$actual_status" != "$expected_status" ]]; then
    echo "ERROR: Expected build status '$expected_status', got '$actual_status'"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# Assert build duration is reasonable
assert_build_duration() {
  local build_result="$1"
  local max_duration="${2:-300}"  # Default 5 minutes

  local duration
  duration=$(echo "$build_result" | grep -o '"duration": *[0-9.]*' | cut -d':' -f2 | tr -d ' ')

  if [[ -z "$duration" ]] || (( $(echo "$duration > $max_duration" | bc -l 2>/dev/null || echo "0") )); then
    echo "ERROR: Build duration $duration exceeds maximum $max_duration seconds"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# Assert container ID is present
assert_container_id_present() {
  local build_result="$1"

  local container_id
  container_id=$(echo "$build_result" | grep -o '"container_id": *"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$container_id" ]] || [[ "$container_id" == "null" ]]; then
    echo "ERROR: Container ID not found in build result"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# Assert exit code matches expected
assert_exit_code() {
  local build_result="$1"
  local expected_exit_code="$2"

  local actual_exit_code
  actual_exit_code=$(echo "$build_result" | grep -o '"exit_code": *[0-9]*' | cut -d':' -f2 | tr -d ' ')

  if [[ "$actual_exit_code" != "$expected_exit_code" ]]; then
    echo "ERROR: Expected exit code $expected_exit_code, got $actual_exit_code"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# Assert CPU cores used is reasonable
assert_cpu_cores_used() {
  local build_result="$1"
  local expected_min="${2:-1}"

  local cpu_cores
  cpu_cores=$(echo "$build_result" | grep -o '"cpu_cores_used": *[0-9]*' | cut -d':' -f2 | tr -d ' ')

  if [[ -z "$cpu_cores" ]] || [[ "$cpu_cores" -lt "$expected_min" ]]; then
    echo "ERROR: CPU cores used $cpu_cores is less than minimum $expected_min"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# ============================================================================
# Test Image Assertions
# ============================================================================

# Assert test image is created
assert_test_image_created() {
  local build_result="$1"

  local image_name
  image_name=$(echo "$build_result" | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$image_name" ]] || [[ "$image_name" == "null" ]]; then
    echo "ERROR: Test image name not found in build result"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# Assert test image has valid structure
assert_test_image_structure() {
  local build_result="$1"

  # Check for required fields in test_image object
  local required_fields=("name" "image_id" "dockerfile_path")
  for field in "${required_fields[@]}"; do
    if ! echo "$build_result" | grep -q "\"$field\""; then
      echo "ERROR: Required field '$field' not found in test_image"
      echo "Build result: $build_result"
      return 1
    fi
  done

  return 0
}

# Assert Dockerfile path exists
assert_dockerfile_exists() {
  local build_result="$1"

  local dockerfile_path
  dockerfile_path=$(echo "$build_result" | grep -o '"dockerfile_path": *"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$dockerfile_path" ]] || [[ ! -f "$dockerfile_path" ]]; then
    echo "ERROR: Dockerfile not found at path: $dockerfile_path"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# ============================================================================
# Build Result Structure Validation
# ============================================================================

# Assert build result has valid JSON structure
assert_build_result_valid_json() {
  local build_result="$1"

  # Check for required top-level fields
  local required_fields=("framework" "status" "duration" "start_time" "end_time" "container_id" "exit_code" "test_image" "output")
  for field in "${required_fields[@]}"; do
    if ! echo "$build_result" | grep -q "\"$field\""; then
      echo "ERROR: Required field '$field' not found in build result"
      echo "Build result: $build_result"
      return 1
    fi
  done

  return 0
}

# Assert build result contains framework identifier
assert_build_result_framework() {
  local build_result="$1"
  local expected_framework="$2"

  local actual_framework
  actual_framework=$(echo "$build_result" | grep -o '"framework": *"[^"]*"' | cut -d'"' -f4)

  if [[ "$actual_framework" != "$expected_framework" ]]; then
    echo "ERROR: Expected framework '$expected_framework', got '$actual_framework'"
    echo "Build result: $build_result"
    return 1
  fi

  return 0
}

# ============================================================================
# Build Manager State Assertions
# ============================================================================

# Assert build manager is initialized
assert_build_manager_initialized() {
  local status_output="$1"

  if ! echo "$status_output" | grep -q "initialized\|ready\|active"; then
    echo "ERROR: Build manager not properly initialized"
    echo "Status output: $status_output"
    return 1
  fi

  return 0
}

# Assert build manager handles Docker unavailability
assert_docker_unavailable_handled() {
  local error_output="$1"

  if ! echo "$error_output" | grep -q "Docker.*not.*available\|daemon.*not.*running\|cannot.*connect"; then
    echo "ERROR: Docker unavailability not properly handled"
    echo "Error output: $error_output"
    return 1
  fi

  return 0
}

# Assert dependency analysis works correctly
assert_dependency_analysis() {
  local analysis_output="$1"
  local expected_tiers="${2:-1}"

  # Check if output is valid JSON
  if ! echo "$analysis_output" | jq . >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON output from dependency analysis"
    echo "Analysis output: $analysis_output"
    return 1
  fi

  # Count tier properties in the JSON
  local tier_count
  tier_count=$(echo "$analysis_output" | jq 'keys | map(select(startswith("tier_"))) | length')

  if [[ $tier_count -lt $expected_tiers ]]; then
    echo "ERROR: Expected at least $expected_tiers dependency tiers, found $tier_count"
    echo "Analysis output: $analysis_output"
    return 1
  fi

  return 0
}

# ============================================================================
# Mock Build Scenarios
# ============================================================================

# Create successful build scenario
mock_successful_build() {
  local framework="${1:-rust}"
  local duration="${2:-5.7}"

  cat << EOF
{
  "framework": "$framework",
  "status": "built",
  "duration": $duration,
  "start_time": "2024-01-15T14:30:45Z",
  "end_time": "2024-01-15T14:30:50Z",
  "container_id": "mock_container_$(date +%s)",
  "exit_code": 0,
  "cpu_cores_used": 4,
  "test_image": {
    "name": "suitey-test-${framework}-$(date +%Y%m%d-%H%M%S)",
    "image_id": "sha256:mock$(date +%s)",
    "dockerfile_path": "/tmp/suitey-build-$(date +%s)/builds/${framework}/Dockerfile"
  },
  "output": "Mock successful build output for $framework",
  "error": null
}
EOF
}

# Create failed build scenario
mock_failed_build() {
  local framework="${1:-rust}"
  local error_message="${2:-Build failed with exit code 1}"

  cat << EOF
{
  "framework": "$framework",
  "status": "build-failed",
  "duration": 2.3,
  "start_time": "2024-01-15T14:30:45Z",
  "end_time": "2024-01-15T14:30:47Z",
  "container_id": "mock_container_$(date +%s)",
  "exit_code": 1,
  "cpu_cores_used": 2,
  "test_image": null,
  "output": "Mock build output",
  "error": "$error_message"
}
EOF
}

# Create build in progress scenario
mock_build_in_progress() {
  local framework="${1:-rust}"

  cat << EOF
{
  "framework": "$framework",
  "status": "building",
  "duration": 1.2,
  "start_time": "2024-01-15T14:30:45Z",
  "end_time": null,
  "container_id": "mock_container_$(date +%s)",
  "exit_code": null,
  "cpu_cores_used": 4,
  "test_image": null,
  "output": "Build in progress...",
  "error": null
}
EOF
}

# ============================================================================
# Real Project Fixtures (for Integration Tests)
# ============================================================================

# Create a real Rust project for testing
create_real_rust_project() {
  local base_dir="$1"
  local project_name="${2:-real_rust_project}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "suitey_test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
EOF

  # Create src directory with main.rs
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/main.rs" << 'EOF'
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
struct TestStruct {
    value: String,
}

fn main() {
    let test = TestStruct {
        value: "Hello, Suitey!".to_string(),
    };
    println!("Test project: {:?}", test);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_struct_creation() {
        let test = TestStruct {
            value: "test".to_string(),
        };
        assert_eq!(test.value, "test");
    }

    #[test]
    fn test_struct_serialization() {
        let test = TestStruct {
            value: "serialize".to_string(),
        };
        let json = serde_json::to_string(&test).unwrap();
        assert!(json.contains("serialize"));
    }
}
EOF

  # Create tests directory with integration test
  mkdir -p "$base_dir/tests"
  cat > "$base_dir/tests/integration_test.rs" << 'EOF'
use suitey_test_project::*;

#[test]
fn integration_test_example() {
    let test = TestStruct {
        value: "integration".to_string(),
    };
    assert_eq!(test.value, "integration");
}

#[test]
fn integration_test_calculation() {
    assert_eq!(2 + 2, 4);
    assert_eq!(10 * 5, 50);
}
EOF

  echo "$base_dir"
}

# Create a broken Rust project for failure testing
create_broken_rust_project() {
  local base_dir="$1"
  local project_name="${2:-broken_rust_project}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "broken_test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
nonexistent_package = "999.999.999"
EOF

  # Create src/main.rs with compilation errors
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/main.rs" << 'EOF'
fn main() {
    // This will cause a compilation error
    undefined_function();
    let x: u32 = "string"; // Type mismatch
    println!("This should not compile");
}
EOF

  echo "$base_dir"
}
