#!/usr/bin/env bash
# Helper functions for JSON Helper tests

# ============================================================================
# Source the json helpers module
# ============================================================================

# Find and source json_helpers.sh
json_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
	json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
	json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
else
	json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
fi

source "$json_helpers_script"

