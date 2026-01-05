#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Build Manager Execution functions

load ../helpers/build_manager_execution

# ============================================================================
# Parallel Execution Function Tests
# ============================================================================

@test "build_manager_execute_parallel handles empty builds array" {
	setup_build_manager_execution_test

	run build_manager_execute_parallel "[]"
	[ "$status" -eq 0 ]
	[ "$output" = "[]" ]

	teardown_build_manager_execution_test
}

@test "build_manager_execute_parallel processes build specs" {
	setup_build_manager_execution_test

	local build_specs='[{"framework":"test","build_command":"echo hello"}]'

	run build_manager_execute_parallel "$build_specs"
	[ "$status" -eq 0 ]
	# Should return JSON array of results

	teardown_build_manager_execution_test
}

# ============================================================================
# Build Execution Function Tests
# ============================================================================

@test "build_manager_execute_build requires framework parameter" {
	setup_build_manager_execution_test

	local build_spec='{"build_command":"echo hello","docker_image":"alpine"}'

	run build_manager_execute_build "$build_spec" "test_framework"
	[ "$status" -eq 0 ]
	# Should create result file and return JSON

	teardown_build_manager_execution_test
}

@test "build_manager_execute_build_async runs in background" {
	setup_build_manager_execution_test

	local build_spec='{"framework":"test","build_command":"echo hello"}'

	run build_manager_execute_build_async "$build_spec"
	[ "$status" -eq 0 ]

	teardown_build_manager_execution_test
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "execution pipeline integration test" {
	setup_build_manager_execution_test

	local build_spec='{"framework":"integration","build_command":"echo test","docker_image":"alpine"}'

	# Test parallel execution with single build
	run build_manager_execute_parallel "[$build_spec]"
	[ "$status" -eq 0 ]

	teardown_build_manager_execution_test
}

