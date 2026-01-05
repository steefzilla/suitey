#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

# Unit tests for JSON path extraction patterns
# These tests verify that JSON path extraction works correctly for arrays vs objects
# This prevents regressions like the assert_build_command_parallel fix

load ../helpers/json_helpers

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
# Array of Objects Pattern Tests
# ============================================================================

@test "extract field from first object in array uses [0] index" {
	local json='[{"name":"first","value":1},{"name":"second","value":2}]'
	
	local name
	name=$(json_get "$json" '.[0].name')
	[ "$name" = "first" ]
	
	local value
	value=$(json_get "$json" '.[0].value')
	[ "$value" = "1" ]
}

@test "extract field from nested array of objects" {
	local json='{"items":[{"id":1,"name":"item1"},{"id":2,"name":"item2"}]}'
	
	local first_name
	first_name=$(json_get "$json" '.items[0].name')
	[ "$first_name" = "item1" ]
	
	local second_id
	second_id=$(json_get "$json" '.items[1].id')
	[ "$second_id" = "2" ]
}

@test "common pattern: build_steps array extraction" {
	# This is the exact pattern that was fixed
	# Use single quotes to prevent $(nproc) from being expanded by shell
	local build_steps='[{"step_name":"compile","build_command":"cargo build --jobs $(nproc)","docker_image":"rust:latest"}]'
	
	local command
	command=$(json_get "$build_steps" '.[0].build_command')
	# Compare with single quotes to prevent expansion
	[ "$command" = 'cargo build --jobs $(nproc)' ]
	
	local image
	image=$(json_get "$build_steps" '.[0].docker_image')
	[ "$image" = "rust:latest" ]
	
	# Wrong pattern should fail
	run json_get "$build_steps" '.build_command'
	[ $status -ne 0 ]
}

@test "common pattern: multiple objects in array" {
	local suites='[{"name":"suite1","tests":5},{"name":"suite2","tests":10}]'
	
	local first_tests
	first_tests=$(json_get "$suites" '.[0].tests')
	[ "$first_tests" = "5" ]
	
	local second_name
	second_name=$(json_get "$suites" '.[1].name')
	[ "$second_name" = "suite2" ]
}

