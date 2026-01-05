#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Build Manager helper functions

load ../helpers/build_manager

# ============================================================================
# Helper Function Tests
# ============================================================================

@test "_build_manager_find_framework_req finds framework in requirements" {
	local build_reqs_json='[
		{"framework": "bats", "artifact_storage": {"source_code": ["src/"], "test_suites": ["tests/"]}},
		{"framework": "rust", "artifact_storage": {"source_code": ["src/"], "test_suites": ["tests/"]}}
	]'

	local result
	result=$(_build_manager_find_framework_req "$build_reqs_json" "rust")

	[ -n "$result" ]
	[ "$result" != "null" ]

	# Verify it contains the rust framework
	local framework_name
	framework_name=$(json_get "$result" ".framework")
	[ "$framework_name" = "rust" ]
}

@test "_build_manager_find_framework_req returns empty when framework not found" {
	local build_reqs_json='[
		{"framework": "bats", "artifact_storage": {"source_code": ["src/"], "test_suites": ["tests/"]}}
	]'

	local result
	run _build_manager_find_framework_req "$build_reqs_json" "nonexistent"

	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "_build_manager_execute_tier_loop executes builds in tier order" {
	# Mock the build_manager_execute_parallel function
	build_manager_execute_parallel() {
		echo '[{"framework": "test", "status": "built", "exit_code": 0}]'
	}

	# Set up test data
	local -A dependency_analysis
	dependency_analysis["tier_0_json"]='["framework1"]'
	dependency_analysis["tier_1_json"]='["framework2"]'
	dependency_analysis["tier_count"]="2"

	local build_reqs=('{"framework": "framework1"}' '{"framework": "framework2"}')
	local build_results="[]"

	# Execute tier loop
	local result
	result=$(_build_manager_execute_tier_loop "2" dependency_analysis "${build_reqs[@]}" "$build_results")

	# Should succeed and return results
	[ -n "$result" ]
	[ "$result" != "false" ]

	# Clean up mock
	unset -f build_manager_execute_parallel
}

@test "_build_manager_execute_tier_loop stops on build failure" {
	# Mock build_manager_execute_parallel to return failed build
	build_manager_execute_parallel() {
		echo '[{"framework": "test", "status": "build-failed", "exit_code": 1}]'
	}

	# Set up test data
	local -A dependency_analysis
	dependency_analysis["tier_0_json"]='["framework1"]'

	local build_reqs=('{"framework": "framework1"}')
	local build_results="[]"

	# Execute tier loop - should fail
	local result
	result=$(_build_manager_execute_tier_loop "1" dependency_analysis "${build_reqs[@]}" "$build_results")

	# Should indicate failure
	[ "$result" = "false" ]

	# Clean up mock
	unset -f build_manager_execute_parallel
}
