#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Build Manager Docker wrapper functions

load ../helpers/build_manager_docker

# ============================================================================
# Docker Run Function Tests
# ============================================================================

@test "docker_run simple interface returns mock output" {
	setup_build_manager_docker_test

	local container_name="test_container"
	local image="test_image"
	local command="echo hello"

	run docker_run "$container_name" "$image" "$command"
	[ "$status" -eq 0 ]
	[ "$output" = "Mock Docker run output" ]

	teardown_build_manager_docker_test
}

@test "docker_run simple interface accepts exit code parameter" {
	setup_build_manager_docker_test

	local container_name="test_container"
	local image="test_image"
	local command="failing_command"
	local expected_exit=42

	run docker_run "$container_name" "$image" "$command" "$expected_exit"
	[ "$status" -eq "$expected_exit" ]

	teardown_build_manager_docker_test
}

@test "docker_run complex interface calls transform_docker_args" {
	setup_build_manager_docker_test

	# Mock the transform_docker_args function
	transform_docker_args() {
		echo "mock_container"
		echo "mock_image"
		echo "mock_command"
	}

	run docker_run --name "complex_container" "complex_image" "complex_command"
	[ "$status" -eq 0 ]

	teardown_build_manager_docker_test
}

@test "_execute_docker_run builds correct docker command" {
	setup_build_manager_docker_test

	# Mock docker command to capture arguments
	docker() {
		echo "docker called with: $*" >&2
		return 0
	}

	run _execute_docker_run "test_container" "test_image" "echo hello" "2" "/workspace" "/artifacts" "/working"
	[ "$status" -eq 0 ]

	teardown_build_manager_docker_test
}

# ============================================================================
# Docker Build Function Tests
# ============================================================================

@test "docker_build simple interface succeeds" {
	setup_build_manager_docker_test

	run docker_build "/tmp/context" "test_image"
	[ "$status" -eq 0 ]

	teardown_build_manager_docker_test
}

@test "docker_build complex interface calls real docker" {
	setup_build_manager_docker_test

	# Override docker command to verify it's called
	# Use a temp file to capture the call since run executes in a subshell
	local capture_file
	capture_file=$(mktemp)
	docker() {
		echo "called" > "$capture_file"
		return 0
	}

	run docker_build --tag "complex_image" "/tmp/context"
	[ "$status" -eq 0 ]
	
	local captured
	captured=$(cat "$capture_file" 2>/dev/null || echo "")
	[ "$captured" = "called" ]

	rm -f "$capture_file"
	teardown_build_manager_docker_test
}

# ============================================================================
# Docker CP Function Tests
# ============================================================================

@test "docker_cp calls docker cp with correct arguments" {
	setup_build_manager_docker_test

	# Mock docker cp to verify arguments
	# Use a temp file to capture arguments since run executes in a subshell
	local capture_file
	capture_file=$(mktemp)
	docker() {
		if [[ "$1" == "cp" ]]; then
			echo "$2|$3" > "$capture_file"
			return 0
		fi
		command docker "$@"
	}

	run docker_cp "/source/path" "/dest/path"
	[ "$status" -eq 0 ]
	
	local captured
	captured=$(cat "$capture_file")
	[ "$captured" = "/source/path|/dest/path" ]

	rm -f "$capture_file"
	teardown_build_manager_docker_test
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "docker_run integration with mocked docker" {
	setup_build_manager_docker_test

	setup_docker_mocks

	local container_name="integration_container"
	local image="integration_image"
	local command="integration_command"

	run docker_run "$container_name" "$image" "$command"
	[ "$status" -eq 0 ]
	[ "$output" = "Mock Docker run output" ]

	teardown_docker_mocks
	teardown_build_manager_docker_test
}

@test "test_docker_run_complex_parsing works" {
	setup_build_manager_docker_test

	test_docker_run_complex_parsing
	[ "$?" -eq 0 ]

	teardown_build_manager_docker_test
}

@test "test_docker_build_simple_interface works" {
	setup_build_manager_docker_test

	test_docker_build_simple_interface
	[ "$?" -eq 0 ]

	teardown_build_manager_docker_test
}

@test "test_docker_build_complex_interface works" {
	setup_build_manager_docker_test

	test_docker_build_complex_interface
	[ "$?" -eq 0 ]

	teardown_build_manager_docker_test
}

@test "test_docker_cp_functionality works" {
	setup_build_manager_docker_test

	test_docker_cp_functionality
	[ "$?" -eq 0 ]

	teardown_build_manager_docker_test
}

# ============================================================================
# Function Override Support Tests
# ============================================================================

@test "docker_build allows function override in tests" {
	setup_build_manager_docker_test
	
	# Verify that function overrides work (not using 'command')
	# Use temp file since run executes in subshell
	local capture_file
	capture_file=$(mktemp)
	docker() {
		if [[ "$1" == "build" ]]; then
			echo "override_worked" > "$capture_file"
			return 0
		fi
		command docker "$@"
	}
	
	run docker_build --tag "test" "/tmp"
	[ "$status" -eq 0 ]
	
	local captured
	captured=$(cat "$capture_file" 2>/dev/null || echo "")
	[ "$captured" = "override_worked" ]
	
	rm -f "$capture_file"
	teardown_build_manager_docker_test
}

@test "docker_cp allows function override in tests" {
	setup_build_manager_docker_test
	
	# Verify that function overrides work (not using 'command')
	local capture_file
	capture_file=$(mktemp)
	docker() {
		if [[ "$1" == "cp" ]]; then
			echo "$2|$3" > "$capture_file"
			return 0
		fi
		command docker "$@"
	}
	
	run docker_cp "/source" "/dest"
	[ "$status" -eq 0 ]
	
	local captured
	captured=$(cat "$capture_file" 2>/dev/null || echo "")
	[ "$captured" = "/source|/dest" ]
	
	rm -f "$capture_file"
	teardown_build_manager_docker_test
}

