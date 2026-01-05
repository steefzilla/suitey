#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Build Manager Integration functions

load ../helpers/build_manager_integration

# ============================================================================
# Build Start Function Tests
# ============================================================================

@test "build_manager_start_build delegates to orchestrate" {
	setup_build_manager_integration_test

	local build_req='{"framework":"test"}'

	run build_manager_start_build "$build_req"
	# Should not fail - orchestrate handles the logic

	teardown_build_manager_integration_test
}

# ============================================================================
# Adapter Processing Function Tests
# ============================================================================

@test "build_manager_process_adapter_build_steps extracts build steps" {
	setup_build_manager_integration_test

	local build_reqs='[{"framework":"test","build_steps":[{"docker_image":"alpine"}]}]'

	run build_manager_process_adapter_build_steps "$build_reqs" "test"
	[ "$status" -eq 0 ]
	[ "$output" = '[{"docker_image":"alpine"}]' ]

	teardown_build_manager_integration_test
}

@test "build_manager_process_adapter_build_steps fails with invalid framework" {
	setup_build_manager_integration_test

	run build_manager_process_adapter_build_steps '[]' "nonexistent"
	[ "$status" -eq 1 ]
	[ "$output" = "{}" ]

	teardown_build_manager_integration_test
}

# ============================================================================
# Project Scanner Coordination Tests
# ============================================================================

@test "build_manager_coordinate_with_project_scanner validates requirements" {
	setup_build_manager_integration_test

	local valid_reqs='[{"framework":"test","build_steps":[{}]}]'

	run build_manager_coordinate_with_project_scanner "$valid_reqs"
	[ "$status" -eq 0 ]
	[ "$output" = '{"status": "coordinated", "ready": true}' ]

	teardown_build_manager_integration_test
}

@test "build_manager_coordinate_with_project_scanner rejects invalid requirements" {
	setup_build_manager_integration_test

	run build_manager_coordinate_with_project_scanner 'invalid_json'
	[ "$status" -eq 0 ]
	[ "$output" = '{"status": "error", "ready": false}' ]

	teardown_build_manager_integration_test
}

# ============================================================================
# Results Provisioning Tests
# ============================================================================

@test "build_manager_provide_results_to_scanner validates JSON" {
	setup_build_manager_integration_test

	run build_manager_provide_results_to_scanner '{"test": "results"}'
	[ "$status" -eq 0 ]
	[ "$output" = '{"status": "results_received", "processed": true}' ]

	teardown_build_manager_integration_test
}

@test "build_manager_provide_results_to_scanner rejects invalid JSON" {
	setup_build_manager_integration_test

	run build_manager_provide_results_to_scanner 'invalid_json'
	[ "$status" -eq 0 ]
	[ "$output" = '{"status": "error", "processed": false}' ]

	teardown_build_manager_integration_test
}

# ============================================================================
# Adapter Specification Execution Tests
# ============================================================================

@test "build_manager_execute_with_adapter_specs delegates to execute_build" {
	setup_build_manager_integration_test

	local build_reqs='[{"framework":"test","build_command":"echo test"}]'

	run build_manager_execute_with_adapter_specs "$build_reqs" "test"
	[ "$status" -eq 0 ]
	# Should return build result JSON

	teardown_build_manager_integration_test
}

# ============================================================================
# Metadata Passing Tests
# ============================================================================

@test "build_manager_pass_image_metadata_to_adapter validates metadata" {
	setup_build_manager_integration_test

	run build_manager_pass_image_metadata_to_adapter '{"image": "test"}' "test_framework"
	[ "$status" -eq 0 ]
	[[ "$output" == *'"status": "metadata_passed"'* ]]

	teardown_build_manager_integration_test
}

@test "build_manager_pass_image_metadata_to_adapter rejects invalid metadata" {
	setup_build_manager_integration_test

	run build_manager_pass_image_metadata_to_adapter 'invalid_json' "test_framework"
	[ "$status" -eq 0 ]
	[[ "$output" == *'"received": false'* ]]

	teardown_build_manager_integration_test
}

# ============================================================================
# Multi-Framework Execution Tests
# ============================================================================

@test "build_manager_execute_multi_framework returns status message" {
	setup_build_manager_integration_test

	local build_reqs='[{"framework":"test1"},{"framework":"test2"}]'

	run build_manager_execute_multi_framework "$build_reqs"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Executing 2 frameworks"* ]]

	teardown_build_manager_integration_test
}

# ============================================================================
# Dependent Builds Tests
# ============================================================================

@test "build_manager_execute_dependent_builds delegates to orchestrate" {
	setup_build_manager_integration_test

	local build_reqs='[{"framework":"test"}]'

	run build_manager_execute_dependent_builds "$build_reqs"
	# Should not fail - delegates to orchestrate

	teardown_build_manager_integration_test
}

# ============================================================================
# Rust Project Building Tests
# ============================================================================

@test "build_manager_build_containerized_rust_project succeeds in integration test mode" {
	setup_build_manager_integration_test

	export SUITEY_INTEGRATION_TEST=1

	run build_manager_build_containerized_rust_project "/tmp/test_project" "test_image"
	[ "$status" -eq 0 ]

	unset SUITEY_INTEGRATION_TEST
	teardown_build_manager_integration_test
}

@test "build_manager_build_containerized_rust_project handles broken Cargo.toml" {
	setup_build_manager_integration_test

	export SUITEY_INTEGRATION_TEST=1

	# Create test directory with broken Cargo.toml
	mkdir -p "/tmp/broken_project"
	echo 'nonexistent_package = "1.0"' > "/tmp/broken_project/Cargo.toml"

	run build_manager_build_containerized_rust_project "/tmp/broken_project" "test_image"
	[ "$status" -eq 0 ]
	[[ "$output" == *"BUILD_FAILED"* ]]

	rm -rf "/tmp/broken_project"
	unset SUITEY_INTEGRATION_TEST
	teardown_build_manager_integration_test
}

# ============================================================================
# Artifact Image Creation Tests
# ============================================================================

@test "build_manager_create_test_image_from_artifacts generates Dockerfile" {
	setup_build_manager_integration_test

	local project_dir="/tmp/artifact_test"
	mkdir -p "$project_dir/target"

	run build_manager_create_test_image_from_artifacts "$project_dir" "alpine:latest" "test_image"
	[ "$status" -eq 0 ]
	[[ "$output" == *'"success": true'* ]]

	rm -rf "$project_dir"
	teardown_build_manager_integration_test
}

# ============================================================================
# Real Builds Tests
# ============================================================================

@test "build_manager_build_multi_framework_real returns status message" {
	setup_build_manager_integration_test

	local build_reqs='[{"framework":"real1"},{"framework":"real2"},{"framework":"real3"}]'

	run build_manager_build_multi_framework_real "$build_reqs"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Building 3 frameworks"* ]]

	teardown_build_manager_integration_test
}

@test "build_manager_build_dependent_real returns status message" {
	setup_build_manager_integration_test

	run build_manager_build_dependent_real "test_reqs"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Analyzing build dependencies"* ]]

	teardown_build_manager_integration_test
}

