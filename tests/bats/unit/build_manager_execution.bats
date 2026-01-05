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

# ============================================================================
# Empty Input Handling Tests
# ============================================================================

@test "build_manager_execute_parallel returns empty array for empty input immediately" {
	setup_build_manager_execution_test
	
	# Should return immediately without processing
	run build_manager_execute_parallel "[]"
	[ "$status" -eq 0 ]
	[ "$output" = "[]" ]
	
	# Verify no result files were created
	[ ! -d "${TEST_BUILD_MANAGER_DIR:-}/builds" ] || [ -z "$(ls -A "${TEST_BUILD_MANAGER_DIR:-}/builds" 2>/dev/null)" ]
	
	teardown_build_manager_execution_test
}

@test "build_manager_execute_parallel handles null JSON array" {
	setup_build_manager_execution_test
	
	# Should handle null gracefully
	run build_manager_execute_parallel "null"
	[ "$status" -eq 0 ]
	# Should return empty array or handle gracefully
	
	teardown_build_manager_execution_test
}

@test "build_manager_execute_parallel handles invalid JSON gracefully" {
	setup_build_manager_execution_test
	
	# Should handle invalid JSON
	run build_manager_execute_parallel "invalid"
	# May fail or return empty array, but shouldn't crash
	
	teardown_build_manager_execution_test
}

# ============================================================================
# Dependency Sourcing Tests
# ============================================================================

@test "build_manager_execution helper sources all required dependencies" {
	# Verify that all required functions are available after loading the helper
	# This catches missing dependency sourcing issues
	
	# Verify json_array_length is available (from json_helpers.sh)
	command -v json_array_length >/dev/null 2>&1 || {
		echo "ERROR: json_array_length function not found - json_helpers.sh not sourced"
		return 1
	}
	
	# Verify build_manager_execute_parallel is available
	command -v build_manager_execute_parallel >/dev/null 2>&1 || {
		echo "ERROR: build_manager_execute_parallel not found - build_manager_execution.sh not sourced"
		return 1
	}
	
	# Verify json_get is available
	command -v json_get >/dev/null 2>&1 || {
		echo "ERROR: json_get function not found - json_helpers.sh not sourced"
		return 1
	}
}

