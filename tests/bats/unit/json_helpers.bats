#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

# Unit tests for JSON Helper functions
# Tests JSON conversion functions, especially those using namerefs

load ../helpers/json_helpers

# ============================================================================
# Setup/Teardown
# ============================================================================

setup() {
	# Source json_helpers.sh
	json_helpers_script=""
	if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
		json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
	elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
		json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
	else
		json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
	fi
	source "$json_helpers_script"
}

# ============================================================================
# json_to_array Tests
# ============================================================================

@test "json_to_array converts simple JSON array to Bash array" {
	local json='["item1","item2","item3"]'
	declare -a test_array
	
	json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 3 ]
	[ "${test_array[0]}" = "item1" ]
	[ "${test_array[1]}" = "item2" ]
	[ "${test_array[2]}" = "item3" ]
}

@test "json_to_array handles empty JSON array" {
	local json='[]'
	declare -a test_array
	
	json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 0 ]
}

@test "json_to_array handles array with numbers" {
	local json='[1,2,3]'
	declare -a test_array
	
	json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 3 ]
	[ "${test_array[0]}" = "1" ]
	[ "${test_array[1]}" = "2" ]
	[ "${test_array[2]}" = "3" ]
}

@test "json_to_array clears array before populating" {
	local json='["new1","new2"]'
	declare -a test_array=("old1" "old2" "old3")
	
	json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 2 ]
	[ "${test_array[0]}" = "new1" ]
	[ "${test_array[1]}" = "new2" ]
}

@test "json_to_array returns error on invalid JSON" {
	local json='invalid json'
	declare -a test_array
	
	run json_to_array "$json" "test_array"
	
	[ $status -ne 0 ]
}

@test "json_to_array returns error on empty var_name" {
	local json='["item1"]'
	declare -a test_array
	
	run json_to_array "$json" ""
	
	[ $status -ne 0 ]
}

# ============================================================================
# build_requirements_json_to_array Tests
# ============================================================================

@test "build_requirements_json_to_array converts requirements JSON to array" {
	local json='[{"framework":"test1"},{"framework":"test2"}]'
	declare -a test_array
	
	build_requirements_json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 2 ]
	[[ "${test_array[0]}" == *"test1"* ]]
	[[ "${test_array[1]}" == *"test2"* ]]
}

@test "build_requirements_json_to_array handles empty array" {
	local json='[]'
	declare -a test_array
	
	build_requirements_json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 0 ]
}

@test "build_requirements_json_to_array clears array before populating" {
	local json='[{"framework":"new1"}]'
	declare -a test_array=("old1" "old2")
	
	build_requirements_json_to_array "$json" "test_array"
	
	[ ${#test_array[@]} -eq 1 ]
	[[ "${test_array[0]}" == *"new1"* ]]
}

@test "build_requirements_json_to_array returns error on invalid JSON" {
	local json='invalid'
	declare -a test_array
	
	run build_requirements_json_to_array "$json" "test_array"
	
	[ $status -ne 0 ]
}

@test "build_requirements_json_to_array returns error on non-array JSON" {
	local json='{"not":"array"}'
	declare -a test_array
	
	run build_requirements_json_to_array "$json" "test_array"
	
	[ $status -ne 0 ]
}

@test "build_requirements_json_to_array skips null values" {
	local json='[{"framework":"test1"},null,{"framework":"test2"}]'
	declare -a test_array

	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)

	# Should have 2 items, not 3 (null is skipped)
	[ ${#test_array[@]} -eq 2 ]
}

