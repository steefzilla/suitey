#!/usr/bin/env bash
# Helper functions for Build Manager Integration tests

build_manager_integration_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_integration.sh" ]]; then
  build_manager_integration_script="$BATS_TEST_DIRNAME/../../../src/build_manager_integration.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_integration.sh" ]]; then
  build_manager_integration_script="$BATS_TEST_DIRNAME/../../src/build_manager_integration.sh"
else
  build_manager_integration_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_integration.sh"
fi
source "$build_manager_integration_script"

json_test_get() { local json="$1"; local path="$2"; echo "$json" | jq -r "$path" 2>/dev/null || return 1; }
json_test_validate() { local json="$1"; echo "$json" | jq . >/dev/null 2>&1; }

setup_build_manager_integration_test() { TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_int_test_${1:-test}_XXXXXX"); export TEST_BUILD_MANAGER_DIR; echo "$TEST_BUILD_MANAGER_DIR"; }
teardown_build_manager_integration_test() { [[ -n "${TEST_BUILD_MANAGER_DIR:-}" ]] && rm -rf "$TEST_BUILD_MANAGER_DIR"; unset TEST_BUILD_MANAGER_DIR; }

