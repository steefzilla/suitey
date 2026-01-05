#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Build Manager Container management functions

load ../helpers/build_manager_container

# ============================================================================
# Container Launch Function Tests
# ============================================================================

@test "build_manager_launch_container returns container ID on success" {
	setup_build_manager_container_test

	setup_container_mocks

	local build_req='{"build_steps":[{"docker_image":"alpine:latest","cpu_cores":"1","working_directory":"/workspace"}]}'

	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_launch_container fails with invalid framework" {
	setup_build_manager_container_test

	# No need for mocks here - function should fail before Docker call
	run build_manager_launch_container '[]' "nonexistent"
	[ "$status" -eq 1 ]
	[ "$output" = "" ]

	teardown_build_manager_container_test
}

# ============================================================================
# Container Stop Function Tests
# ============================================================================

@test "build_manager_stop_container succeeds with valid container" {
	setup_build_manager_container_test

	setup_container_mocks

	run build_manager_stop_container "test_container_id"
	[ "$status" -eq 0 ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_stop_container handles empty container ID" {
	setup_build_manager_container_test

	run build_manager_stop_container ""
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

# ============================================================================
# Container Cleanup Function Tests
# ============================================================================

@test "build_manager_cleanup_container succeeds with valid container" {
	setup_build_manager_container_test

	setup_container_mocks

	run build_manager_cleanup_container "test_container_id"
	[ "$status" -eq 0 ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_cleanup_container handles empty container ID" {
	setup_build_manager_container_test

	run build_manager_cleanup_container ""
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

# ============================================================================
# Image Cleanup Function Tests
# ============================================================================

@test "build_manager_cleanup_image succeeds with valid image" {
	setup_build_manager_container_test

	setup_container_mocks

	run build_manager_cleanup_image "test_image:latest"
	[ "$status" -eq 0 ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_cleanup_image handles empty image name" {
	setup_build_manager_container_test

	run build_manager_cleanup_image ""
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "container lifecycle integration test" {
	setup_build_manager_container_test

	setup_container_mocks

	# Test launching
	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	local container_id="$output"
	[ -n "$container_id" ]

	# Test stopping
	run build_manager_stop_container "$container_id"
	[ "$status" -eq 0 ]

	# Test cleanup
	run build_manager_cleanup_container "$container_id"
	[ "$status" -eq 0 ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "assert_container_launched validates container ID" {
	setup_build_manager_container_test

	run assert_container_launched "test_framework" "valid_container_id"
	[ "$status" -eq 0 ]

	run assert_container_launched "test_framework" ""
	[ "$status" -eq 1 ]

	teardown_build_manager_container_test
}

@test "assert_container_stopped validates container operations" {
	setup_build_manager_container_test

	run assert_container_stopped "test_container"
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

@test "assert_container_cleaned validates cleanup operations" {
	setup_build_manager_container_test

	run assert_container_cleaned "test_container"
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

@test "assert_image_cleaned validates image cleanup" {
	setup_build_manager_container_test

	run assert_image_cleaned "test_image:latest"
	[ "$status" -eq 0 ]

	teardown_build_manager_container_test
}

# ============================================================================
# Dependency Sourcing Regression Tests
# ============================================================================

@test "build_manager_container helper sources all required dependencies" {
	# This test verifies that all required functions are available after loading the helper
	# This catches missing dependency sourcing issues
	
	# Verify json_get is available
	command -v json_get >/dev/null 2>&1 || {
		echo "ERROR: json_get function not found - json_helpers.sh not sourced"
		return 1
	}
	
	# Verify _build_manager_find_framework_req is available
	command -v _build_manager_find_framework_req >/dev/null 2>&1 || {
		echo "ERROR: _build_manager_find_framework_req not found - build_manager_build_helpers.sh not sourced"
		return 1
	}
	
	# Verify build_manager_get_cpu_cores is available
	command -v build_manager_get_cpu_cores >/dev/null 2>&1 || {
		echo "ERROR: build_manager_get_cpu_cores not found - build_manager.sh not sourced"
		return 1
	}
	
	# Verify build_manager_launch_container is available
	command -v build_manager_launch_container >/dev/null 2>&1 || {
		echo "ERROR: build_manager_launch_container not found - build_manager_container.sh not sourced"
		return 1
	}
}

@test "build_manager_launch_container requires json_get function (dependency check)" {
	# This test ensures json_get is available (catches missing json_helpers.sh sourcing)
	setup_build_manager_container_test
	setup_container_mocks

	# Function should work - if json_get is missing, this will fail
	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_launch_container requires _build_manager_find_framework_req function (dependency check)" {
	# This test ensures _build_manager_find_framework_req is available
	setup_build_manager_container_test
	setup_container_mocks

	# Function should work - if _build_manager_find_framework_req is missing, this will fail
	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_launch_container requires build_manager_get_cpu_cores function (dependency check)" {
	# This test ensures build_manager_get_cpu_cores is available
	setup_build_manager_container_test
	setup_container_mocks

	# Function should work - if build_manager_get_cpu_cores is missing, this will fail
	# Use build_steps without cpu_cores to trigger the fallback
	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

@test "build_manager_launch_container uses Docker mocks in test mode" {
	# This test ensures Docker is properly mocked in test mode
	setup_build_manager_container_test
	setup_container_mocks

	# Call function - should use mocked docker
	run build_manager_launch_container '[{"framework":"test","build_steps":[{"docker_image":"alpine:latest"}]}]' "test"
	[ "$status" -eq 0 ]
	
	# Should return mock container ID
	[ "$output" = "mock_container_id_123" ]

	teardown_container_mocks
	teardown_build_manager_container_test
}

