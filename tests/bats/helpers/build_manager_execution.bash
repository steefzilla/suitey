#!/usr/bin/env bash
# Helper functions for Build Manager Execution tests

build_manager_execution_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/build_manager_execution.sh" ]]; then
  build_manager_execution_script="$BATS_TEST_DIRNAME/../../../src/build_manager_execution.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/build_manager_execution.sh" ]]; then
  build_manager_execution_script="$BATS_TEST_DIRNAME/../../src/build_manager_execution.sh"
else
  build_manager_execution_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/build_manager_execution.sh"
fi
source "$build_manager_execution_script"

json_test_get() { local json="$1"; local path="$2"; echo "$json" | jq -r "$path" 2>/dev/null || return 1; }
json_test_validate() { local json="$1"; echo "$json" | jq . >/dev/null 2>&1; }

setup_build_manager_execution_test() { TEST_BUILD_MANAGER_DIR=$(mktemp -d -t "suitey_build_exec_test_${1:-test}_XXXXXX"); export TEST_BUILD_MANAGER_DIR; echo "$TEST_BUILD_MANAGER_DIR"; }
teardown_build_manager_execution_test() { [[ -n "${TEST_BUILD_MANAGER_DIR:-}" ]] && rm -rf "$TEST_BUILD_MANAGER_DIR"; unset TEST_BUILD_MANAGER_DIR; }
