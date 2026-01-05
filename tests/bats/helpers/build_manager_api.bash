#!/usr/bin/env bash
# Helper functions for Build Manager API tests
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

# Source JSON helpers first (required by build_manager_integration.sh)
json_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
  json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
  json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
else
  json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
fi
source "$json_helpers_script"

# Source build_manager.sh (which sources all dependencies including build_manager_integration.sh)
build_manager_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager.sh" ]]; then
  build_manager_script="$BATS_TEST_DIRNAME/../../../src/build_manager.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager.sh" ]]; then
  build_manager_script="$BATS_TEST_DIRNAME/../../src/build_manager.sh"
else
  build_manager_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager.sh"
fi
source "$build_manager_script"

# Note: build_manager.sh already sources build_manager_integration.sh at the end,
# so we don't need to source it separately

json_test_get() { local json="$1"; local path="$2"; echo "$json" | jq -r "$path" 2>/dev/null || return 1; }
json_test_validate() { local json="$1"; echo "$json" | jq . >/dev/null 2>&1; }

setup_build_manager_api_test() { 
  TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_api_test_${1:-test}_XXXXXX")
  export TEST_BUILD_MANAGER_DIR
  # Set test mode for unit tests (unless integration test mode is explicitly set)
  if [[ -z "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    export SUITEY_TEST_MODE=1
  fi
  echo "$TEST_BUILD_MANAGER_DIR"
}
# See tests/TEST_GUIDELINES.md for parallel-safe teardown patterns
# Uses common_teardown.bash utilities for standardized safe cleanup
teardown_build_manager_api_test() { safe_teardown_test_directory "TEST_BUILD_MANAGER_DIR"; }

