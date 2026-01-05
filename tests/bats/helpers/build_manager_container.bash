#!/usr/bin/env bash
# Helper functions for Build Manager Container tests

# ============================================================================
# Source the build manager container module
# ============================================================================

# Find and source build_manager_container.sh
build_manager_container_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_container.sh" ]]; then
  build_manager_container_script="$BATS_TEST_DIRNAME/../../../src/build_manager_container.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_container.sh" ]]; then
  build_manager_container_script="$BATS_TEST_DIRNAME/../../src/build_manager_container.sh"
else
  build_manager_container_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_container.sh"
fi

source "$build_manager_container_script"

# ============================================================================
# JSON Helper Functions (for test assertions)
# ============================================================================

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

setup_build_manager_container_test() {
  local test_name="${1:-build_manager_container_test}"
  TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_container_test_${test_name}_XXXXXX")
  export TEST_BUILD_MANAGER_DIR

  PROJECT_ROOT="${PROJECT_ROOT:-/tmp/test_project_root}"
  export PROJECT_ROOT

  SUITEY_TEST_MODE=1
  export SUITEY_TEST_MODE

  echo "$TEST_BUILD_MANAGER_DIR"
}

teardown_build_manager_container_test() {
  if [[ -n "${TEST_BUILD_MANAGER_DIR:-}" ]] && [[ -d "$TEST_BUILD_MANAGER_DIR" ]]; then
    rm -rf "$TEST_BUILD_MANAGER_DIR"
    unset TEST_BUILD_MANAGER_DIR
  fi

  # Clean up any containers created during tests
  for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
    docker rm -f "$container" 2>/dev/null || true
  done
  BUILD_MANAGER_ACTIVE_CONTAINERS=()

  unset SUITEY_TEST_MODE
  unset PROJECT_ROOT
}

# ============================================================================
# Container Mock Functions
# ============================================================================

mock_docker_run() {
  local args=("$@")
  echo "mock_container_id_123"
  return 0
}

mock_docker_stop() {
  local container_id="$1"
  return 0
}

mock_docker_rm() {
  local container_id="$1"
  return 0
}

mock_docker_rmi() {
  local image_name="$1"
  return 0
}

# ============================================================================
# Test Helper Functions
# ============================================================================

setup_container_mocks() {
  docker() {
    case "$1" in
      run)
        shift
        mock_docker_run "$@"
        ;;
      stop)
        shift
        mock_docker_stop "$@"
        ;;
      rm)
        shift
        mock_docker_rm "$@"
        ;;
      rmi)
        shift
        mock_docker_rmi "$@"
        ;;
      *)
        command docker "$@"
        ;;
    esac
  }
}

teardown_container_mocks() {
  unset -f docker 2>/dev/null || true
}

assert_container_launched() {
  local expected_framework="$1"
  local container_id="$2"

  [[ -n "$container_id" ]] || {
    echo "ERROR: No container ID returned"
    return 1
  }

  [[ "$container_id" =~ ^[a-zA-Z0-9_.-]+$ ]] || {
    echo "ERROR: Invalid container ID format: $container_id"
    return 1
  }

  return 0
}

assert_container_stopped() {
  local container_id="$1"

  [[ -n "$container_id" ]] || {
    echo "ERROR: No container ID provided to stop"
    return 1
  }

  return 0
}

assert_container_cleaned() {
  local container_id="$1"

  [[ -n "$container_id" ]] || {
    echo "ERROR: No container ID provided to clean"
    return 1
  }

  return 0
}

assert_image_cleaned() {
  local image_name="$1"

  [[ -n "$image_name" ]] || {
    echo "ERROR: No image name provided to clean"
    return 1
  }

  return 0
}
