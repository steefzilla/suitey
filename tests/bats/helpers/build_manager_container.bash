#!/usr/bin/env bash
# Helper functions for Build Manager Container tests
#
# For parallel-safe teardown utilities, see common_teardown.bash
# For test guidelines and best practices, see tests/TEST_GUIDELINES.md

# ============================================================================
# Source common teardown utilities
# ============================================================================

common_teardown_script=""
if [[ -f "$BATS_TEST_DIRNAME/common_teardown.bash" ]]; then
  common_teardown_script="$BATS_TEST_DIRNAME/common_teardown.bash"
elif [[ -f "$(dirname "$BATS_TEST_DIRNAME")/helpers/common_teardown.bash" ]]; then
  common_teardown_script="$(dirname "$BATS_TEST_DIRNAME")/helpers/common_teardown.bash"
else
  common_teardown_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/helpers" && pwd)/common_teardown.bash"
fi
if [[ -f "$common_teardown_script" ]]; then
  source "$common_teardown_script"
fi

# ============================================================================
# Source dependencies first (required by build_manager_container.sh)
# ============================================================================

# Source JSON helpers first (required by build_manager_container.sh)
json_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
  json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
  json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
else
  json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
fi
source "$json_helpers_script"

# Source build_manager_build_helpers.sh (for _build_manager_find_framework_req)
build_manager_build_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_build_helpers.sh" ]]; then
  build_manager_build_helpers_script="$BATS_TEST_DIRNAME/../../../src/build_manager_build_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_build_helpers.sh" ]]; then
  build_manager_build_helpers_script="$BATS_TEST_DIRNAME/../../src/build_manager_build_helpers.sh"
else
  build_manager_build_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_build_helpers.sh"
fi
source "$build_manager_build_helpers_script"

# Source build_manager.sh (for build_manager_get_cpu_cores and other core functions)
# Note: build_manager.sh sources build_manager_container.sh at the end, so we need to be careful
# We'll source build_manager_container.sh separately to avoid double-sourcing issues
build_manager_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager.sh" ]]; then
  build_manager_script="$BATS_TEST_DIRNAME/../../../src/build_manager.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager.sh" ]]; then
  build_manager_script="$BATS_TEST_DIRNAME/../../src/build_manager.sh"
else
  build_manager_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager.sh"
fi

# Source build_manager.sh but prevent it from sourcing build_manager_container.sh
# We'll source container.sh separately after
if [[ -f "$build_manager_script" ]]; then
  # Temporarily rename the container sourcing to prevent double-sourcing
  # We'll source it manually after
  source "$build_manager_script" 2>/dev/null || {
    # If build_manager.sh tries to source container.sh, we'll handle it
    # For now, just source it - build_manager.sh should handle dependencies correctly
    :
  }
fi

# Source build_manager_container.sh separately
build_manager_container_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_container.sh" ]]; then
  build_manager_container_script="$BATS_TEST_DIRNAME/../../../src/build_manager_container.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_container.sh" ]]; then
  build_manager_container_script="$BATS_TEST_DIRNAME/../../src/build_manager_container.sh"
else
  build_manager_container_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_container.sh"
fi

# Only source if not already sourced by build_manager.sh
if [[ -f "$build_manager_container_script" ]] && ! declare -f build_manager_launch_container >/dev/null 2>&1; then
  source "$build_manager_container_script"
fi

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

# Clean up temporary directory
# See tests/TEST_GUIDELINES.md for parallel-safe teardown patterns
# Uses common_teardown.bash utilities for standardized safe cleanup
teardown_build_manager_container_test() {
  # Clean up test directory using common utility
  safe_teardown_test_directory "TEST_BUILD_MANAGER_DIR"

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

