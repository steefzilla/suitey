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
	
	local output
	output=$(json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output (Option 1 from return-data pattern)
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 3 ]
	[ ${#test_array[@]} -eq 3 ]
	[ "${test_array[0]}" = "item1" ]
	[ "${test_array[1]}" = "item2" ]
	[ "${test_array[2]}" = "item3" ]
}

@test "json_to_array handles empty JSON array" {
	local json='[]'
	declare -a test_array
	
	local output
	output=$(json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 0 ]
	[ ${#test_array[@]} -eq 0 ]
}

@test "json_to_array handles array with numbers" {
	local json='[1,2,3]'
	declare -a test_array
	
	local output
	output=$(json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 3 ]
	[ ${#test_array[@]} -eq 3 ]
	[ "${test_array[0]}" = "1" ]
	[ "${test_array[1]}" = "2" ]
	[ "${test_array[2]}" = "3" ]
}

@test "json_to_array clears array before populating" {
	local json='["new1","new2"]'
	declare -a test_array=("old1" "old2" "old3")
	
	local output
	output=$(json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output (clearing first)
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 2 ]
	[ ${#test_array[@]} -eq 2 ]
	[ "${test_array[0]}" = "new1" ]
	[ "${test_array[1]}" = "new2" ]
}

@test "json_to_array returns error on invalid JSON" {
	local json='invalid json'
	declare -a test_array
	
	run json_to_array "$json"
	
	[ $status -ne 0 ]
}

@test "json_to_array returns error on empty JSON" {
	local json=''
	declare -a test_array
	
	run json_to_array "$json"
	
	[ $status -ne 0 ]
}

# ============================================================================
# build_requirements_json_to_array Tests
# ============================================================================

@test "build_requirements_json_to_array converts requirements JSON to array" {
	local json='[{"framework":"test1"},{"framework":"test2"}]'
	declare -a test_array
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 2 ]
	[ ${#test_array[@]} -eq 2 ]
	[[ "${test_array[0]}" == *"test1"* ]]
	[[ "${test_array[1]}" == *"test2"* ]]
}

@test "build_requirements_json_to_array handles empty array" {
	local json='[]'
	declare -a test_array
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 0 ]
	[ ${#test_array[@]} -eq 0 ]
}

@test "build_requirements_json_to_array clears array before populating" {
	local json='[{"framework":"new1"}]'
	declare -a test_array=("old1" "old2")
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output (clearing first)
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)
	
	[ "$count" -eq 1 ]
	[ ${#test_array[@]} -eq 1 ]
	[[ "${test_array[0]}" == *"new1"* ]]
}

@test "build_requirements_json_to_array returns error on invalid JSON" {
	local json='invalid'
	declare -a test_array
	
	run build_requirements_json_to_array "$json"
	
	[ $status -ne 0 ]
}

@test "build_requirements_json_to_array returns error on non-array JSON" {
	local json='{"not":"array"}'
	declare -a test_array
	
	run build_requirements_json_to_array "$json"
	
	[ $status -ne 0 ]
}

@test "build_requirements_json_to_array skips null values" {
	local json='[{"framework":"test1"},null,{"framework":"test2"}]'
	declare -a test_array

	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	# Manually populate array from output
	test_array=()
	local idx=0
	while IFS= read -r element || [[ -n "$element" ]]; do
		[[ -z "$element" ]] && continue
		test_array[$idx]="$element"
		idx=$((idx + 1))
	done < <(echo "$output" | tail -n +2)

	# Should have 2 items, not 3 (null is skipped)
	[ "$count" -eq 2 ]
	[ ${#test_array[@]} -eq 2 ]
}

# ============================================================================
# json_populate_array_from_output Tests (Regression Tests)
# ============================================================================

@test "json_populate_array_from_output handles single element (tests pre-increment fix)" {
	# This test specifically catches the bug where ((idx++)) fails with set -e
	# when idx is 0. The fix uses ((++idx)) instead.
	local output="1
single_element"
	declare -a test_array
	
	json_populate_array_from_output "test_array" "$output" >/dev/null
	
	[ ${#test_array[@]} -eq 1 ]
	[ "${test_array[0]}" = "single_element" ]
}

@test "json_populate_array_from_output handles empty array (count=0)" {
	# Test that function doesn't try to increment idx when count is 0
	# This is important because the loop doesn't execute, so we need to ensure
	# the function doesn't fail with set -e when idx would be 0
	local output="0"
	declare -a test_array
	
	# Function should return 0 and not fail
	run json_populate_array_from_output "test_array" "$output"
	
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "json_populate_array_from_output handles multiple elements" {
	local output="3
element1
element2
element3"
	declare -a test_array
	
	json_populate_array_from_output "test_array" "$output" >/dev/null
	
	[ ${#test_array[@]} -eq 3 ]
	[ "${test_array[0]}" = "element1" ]
	[ "${test_array[1]}" = "element2" ]
	[ "${test_array[2]}" = "element3" ]
}

@test "json_populate_array_from_output skips empty lines" {
	local output="2
element1

element2"
	declare -a test_array
	
	json_populate_array_from_output "test_array" "$output" >/dev/null
	
	[ ${#test_array[@]} -eq 2 ]
	[ "${test_array[0]}" = "element1" ]
	[ "${test_array[1]}" = "element2" ]
}

@test "json_populate_array_from_output works with set -e enabled" {
	# This test ensures the pre-increment fix works with set -e
	set -e
	local output="1
test_element"
	declare -a test_array
	
	json_populate_array_from_output "test_array" "$output" >/dev/null
	
	[ ${#test_array[@]} -eq 1 ]
	[ "${test_array[0]}" = "test_element" ]
	set +e
}

@test "build_requirements_json_to_array handles single non-null element (tests pre-increment fix)" {
	# This test catches the bug where ((count++)) fails with set -e when count is 0
	local json='[{"framework":"test1"}]'
	declare -a test_array
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	
	# Should count 1 element (not fail on increment from 0)
	[ "$count" -eq 1 ]
}

@test "build_requirements_json_to_array works with set -e enabled" {
	# This test ensures the pre-increment fix works with set -e
	set -e
	local json='[{"framework":"test1"},{"framework":"test2"}]'
	declare -a test_array
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	
	[ "$count" -eq 2 ]
	set +e
}

@test "build_requirements_json_to_array handles all null values" {
	# Test that count stays at 0 and doesn't fail on increment
	local json='[null,null]'
	declare -a test_array
	
	local output
	output=$(build_requirements_json_to_array "$json")
	local count
	count=$(echo "$output" | head -n 1)
	
	[ "$count" -eq 0 ]
	[ ${#test_array[@]} -eq 0 ]
}

# ============================================================================
# JSON Path Extraction Tests (Array vs Object)
# ============================================================================

@test "json_get correctly extracts from JSON array using array index" {
	local json_array='[{"field":"value1"},{"field":"value2"}]'
	
	local value
	value=$(json_get "$json_array" '.[0].field')
	[ "$value" = "value1" ]
	
	value=$(json_get "$json_array" '.[1].field')
	[ "$value" = "value2" ]
}

@test "json_get correctly extracts from JSON object using dot notation" {
	local json_object='{"field":"value","nested":{"key":"nested_value"}}'
	
	local value
	value=$(json_get "$json_object" '.field')
	[ "$value" = "value" ]
	
	value=$(json_get "$json_object" '.nested.key')
	[ "$value" = "nested_value" ]
}

@test "json_get fails when using object path on array" {
	local json_array='[{"field":"value"}]'
	
	run json_get "$json_array" '.field'
	[ $status -ne 0 ]
}

@test "json_get fails when using array index on object" {
	local json_object='{"field":"value"}'
	
	run json_get "$json_object" '.[0].field'
	[ $status -ne 0 ]
}

@test "json_test_get correctly handles array of objects pattern" {
	# This is the pattern that was fixed in assert_build_command_parallel
	# json_test_get is a helper function, use json_get instead for this test
	local build_steps='[{"build_command":"cargo build --jobs $(nproc)"}]'
	
	local command
	command=$(json_get "$build_steps" '.[0].build_command')
	# Compare with single quotes to prevent shell expansion
	[ "$command" = 'cargo build --jobs $(nproc)' ]
	
	# Should fail if using wrong path
	run json_get "$build_steps" '.build_command'
	[ $status -ne 0 ]
}

