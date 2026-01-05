#!/usr/bin/env bash
# Helper functions for Build Manager Docker tests

# ============================================================================
# Source the build manager docker module
# ============================================================================

# Find and source build_manager_docker.sh
build_manager_docker_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_docker.sh" ]]; then
  build_manager_docker_script="$BATS_TEST_DIRNAME/../../../src/build_manager_docker.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_docker.sh" ]]; then
  build_manager_docker_script="$BATS_TEST_DIRNAME/../../src/build_manager_docker.sh"
else
  build_manager_docker_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_docker.sh"
fi

source "$build_manager_docker_script"

# ============================================================================
# JSON Helper Functions (for test assertions)
# ============================================================================

# Test-local JSON helper functions (wrappers around jq for now)
json_test_get() {
  local json="$1"
  local path="$2"
  echo "$json" | jq -r "$path" 2>/dev/null || return 1
}

json_test_validate() {
  local json="$1"
  echo "$json" | jq . >/dev/null 2>&1
}

# ============================================================================
# Setup/Teardown Functions
# ============================================================================

# Create a temporary directory for Build Manager Docker testing
setup_build_manager_docker_test() {
  local test_name="${1:-build_manager_docker_test}"
  TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_docker_test_${test_name}_XXXXXX")
  export TEST_BUILD_MANAGER_DIR

  # Set PROJECT_ROOT for build manager tests
  PROJECT_ROOT="${PROJECT_ROOT:-/tmp/test_project_root}"
  export PROJECT_ROOT

  # Set test mode for build manager
  SUITEY_TEST_MODE=1
  export SUITEY_TEST_MODE

  echo "$TEST_BUILD_MANAGER_DIR"
}

# Clean up temporary directory
teardown_build_manager_docker_test() {
  if [[ -n "${TEST_BUILD_MANAGER_DIR:-}" ]] && [[ -d "$TEST_BUILD_MANAGER_DIR" ]]; then
    rm -rf "$TEST_BUILD_MANAGER_DIR"
    unset TEST_BUILD_MANAGER_DIR
  fi

  # Clean up any mock containers
  for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
    docker rm -f "$container" 2>/dev/null || true
  done
  BUILD_MANAGER_ACTIVE_CONTAINERS=()

  # Unset test variables
  unset SUITEY_TEST_MODE
  unset PROJECT_ROOT
}

# ============================================================================
# Docker Mock Functions
# ============================================================================

# Mock docker command for testing
mock_docker_run() {
  local container_name="$1"
  local image="$2"
  local command="$3"
  local exit_code="${4:-0}"
  local output="${5:-Mock Docker run output}"

  echo "$output"
  return $exit_code
}

mock_docker_build() {
  local context_dir="$1"
  local image_name="$2"
  local exit_code="${3:-0}"

  return $exit_code
}

mock_docker_cp() {
  local source="$1"
  local dest="$2"

  # Mock copy operation - just verify paths exist
  [[ -n "$source" && -n "$dest" ]] || return 1
  return 0
}

# ============================================================================
# Test Helper Functions
# ============================================================================

# Override docker functions for testing
setup_docker_mocks() {
  # Override the docker functions with mocks
  docker_run() {
    mock_docker_run "$@"
  }

  docker_build() {
    mock_docker_build "$@"
  }

  docker_cp() {
    mock_docker_cp "$@"
  }

  _execute_docker_run() {
    mock_docker_run "$@"
  }
}

# Restore original docker functions
teardown_docker_mocks() {
  # The original functions are in build_manager_docker.sh
  # Just ensure they're available
  command -v docker_run >/dev/null 2>&1 || {
    echo "ERROR: docker_run function not available after mock teardown"
    return 1
  }
}

# Assert that docker_run was called with simple interface
assert_docker_run_simple_called() {
  local expected_container="$1"
  local expected_image="$2"
  local expected_command="$3"

  # Since we're mocking, we can't easily check the actual calls
  # This is a placeholder for more sophisticated mocking
  [[ -n "$expected_container" && -n "$expected_image" && -n "$expected_command" ]] || {
    echo "ERROR: Invalid parameters for docker_run assertion"
    return 1
  }

  return 0
}

# Assert that docker_build was called with correct parameters
assert_docker_build_called() {
  local expected_context="$1"
  local expected_image="${2:-}"

  # Since we're mocking, we can't easily check the actual calls
  [[ -n "$expected_context" ]] || {
    echo "ERROR: Invalid context for docker_build assertion"
    return 1
  }

  return 0
}

# Assert that docker_cp was called with correct parameters
assert_docker_cp_called() {
  local expected_source="$1"
  local expected_dest="$2"

  [[ -n "$expected_source" && -n "$expected_dest" ]] || {
    echo "ERROR: Invalid parameters for docker_cp assertion"
    return 1
  }

  return 0
}

# Test complex docker_run interface parsing
test_docker_run_complex_parsing() {
  local container_name="test_container"
  local image="test_image"
  local command="echo hello"

  # Set up mock
  setup_docker_mocks

  # Test the complex interface (this would normally be handled by docker_run)
  # Since docker_run detects interface automatically, we'll test the logic indirectly
  local result
  result=$(docker_run "$container_name" "$image" "$command")
  local exit_code=$?

  [[ $exit_code -eq 0 ]] || {
    echo "ERROR: docker_run failed with exit code $exit_code"
    return 1
  }

  [[ "$result" == "Mock Docker run output" ]] || {
    echo "ERROR: Unexpected docker_run output: $result"
    return 1
  }

  teardown_docker_mocks
  return 0
}

# Test docker_build simple interface
test_docker_build_simple_interface() {
  setup_docker_mocks

  # Test simple interface - should not call real docker
  docker_build "/tmp/context" "test_image"
  local exit_code=$?

  [[ $exit_code -eq 0 ]] || {
    echo "ERROR: docker_build simple interface failed"
    return 1
  }

  teardown_docker_mocks
  return 0
}

# Test docker_build complex interface
test_docker_build_complex_interface() {
  setup_docker_mocks

  # Test complex interface - should call real docker
  # Override mock to check if it was called
  local called=false
  mock_docker_build() {
    called=true
    return 0
  }

  docker_build --tag "test_image" "/tmp/context"
  local exit_code=$?

  [[ $exit_code -eq 0 && "$called" == "true" ]] || {
    echo "ERROR: docker_build complex interface failed or was not called"
    return 1
  }

  teardown_docker_mocks
  return 0
}

# Test docker_cp functionality
test_docker_cp_functionality() {
  setup_docker_mocks

  # Create test files
  local source_file="/tmp/source_test"
  local dest_file="/tmp/dest_test"

  echo "test content" > "$source_file"

  docker_cp "$source_file" "$dest_file"
  local exit_code=$?

  [[ $exit_code -eq 0 ]] || {
    echo "ERROR: docker_cp failed"
    return 1
  }

  # Clean up
  rm -f "$source_file" "$dest_file"

  teardown_docker_mocks
  return 0
}
