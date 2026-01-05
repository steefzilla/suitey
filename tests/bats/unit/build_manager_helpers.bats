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
	result=$(_build_manager_execute_tier_loop "2" dependency_analysis build_reqs "$build_results")

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
		return 0
	}

	# Set up test data
	local -A dependency_analysis
	dependency_analysis["tier_0_json"]='["framework1"]'

	local build_reqs=('{"framework": "framework1"}')
	local build_results="[]"

	# Use run to capture both output and status (function returns 1 on failure)
	run _build_manager_execute_tier_loop "1" dependency_analysis build_reqs "$build_results"

	# Should output "false" and return 1
	[ "$output" = "false" ]
	[ "$status" -eq 1 ]

	# Clean up mock
	unset -f build_manager_execute_parallel
}

# ============================================================================
# Failure Detection Tests
# ============================================================================

@test "_build_manager_check_tier_failures detects build failures" {
	local test_results='[{"framework": "test", "status": "build-failed", "exit_code": 1}]'
	
	_build_manager_check_tier_failures "$test_results"
	[ $? -eq 0 ]  # Should return 0 (has failures)
}

@test "_build_manager_check_tier_failures returns no failures for successful builds" {
	local test_results='[{"framework": "test", "status": "built", "exit_code": 0}]'
	
	run _build_manager_check_tier_failures "$test_results"
	[ "$status" -eq 1 ]  # Should return 1 (no failures)
}

@test "_build_manager_check_tier_failures handles empty input" {
	run _build_manager_check_tier_failures ""
	[ "$status" -eq 1 ]  # Should return 1 (no failures for empty input)
}

# ============================================================================
# Tier Loop Edge Case Tests
# ============================================================================

@test "_build_manager_execute_tier_loop handles empty tier_results gracefully" {
	build_manager_execute_parallel() {
		echo ""  # Return empty
		return 0
	}

	local -A dependency_analysis
	dependency_analysis["tier_0_json"]='["framework1"]'
	local build_reqs=('{"framework": "framework1"}')
	local build_results="[]"

	local result
	result=$(_build_manager_execute_tier_loop "1" dependency_analysis build_reqs "$build_results")
	
	# Should return build_results (not "false") when tier_results is empty
	[ -n "$result" ]
	[ "$result" != "false" ]

	unset -f build_manager_execute_parallel
}

@test "_build_manager_execute_tier_loop returns false on build failure" {
	build_manager_execute_parallel() {
		echo '[{"framework": "test", "status": "build-failed", "exit_code": 1}]'
		return 0
	}

	local -A dependency_analysis
	dependency_analysis["tier_0_json"]='["framework1"]'
	local build_reqs=('{"framework": "framework1"}')
	local build_results="[]"

	# Use run to capture both output and status
	run _build_manager_execute_tier_loop "1" dependency_analysis build_reqs "$build_results"
	
	# Should output "false" and return 1
	[ "$output" = "false" ]
	[ "$status" -eq 1 ]

	unset -f build_manager_execute_parallel
}

# ============================================================================
# Project Fixture Validation Tests
# ============================================================================

@test "create_containerized_rust_project creates valid project structure" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Validate required files exist
	[ -f "$test_dir/test_project/Cargo.toml" ]
	[ -f "$test_dir/test_project/src/lib.rs" ]
	[ -f "$test_dir/test_project/src/main.rs" ]
	[ -f "$test_dir/test_project/tests/integration_test.rs" ]
	[ -d "$test_dir/test_project/src" ]
	[ -d "$test_dir/test_project/tests" ]
}

@test "create_containerized_rust_project Cargo.toml has both library and binary sections" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Validate Cargo.toml structure
	grep -q '^\[lib\]' "$test_dir/test_project/Cargo.toml"
	grep -q '^\[\[bin\]\]' "$test_dir/test_project/Cargo.toml"
	grep -q 'name = "suitey_test_project"' "$test_dir/test_project/Cargo.toml"
	grep -q 'path = "src/lib.rs"' "$test_dir/test_project/Cargo.toml"
	grep -q 'path = "src/main.rs"' "$test_dir/test_project/Cargo.toml"
}

@test "create_containerized_rust_project lib.rs exports public struct" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Validate lib.rs has public struct
	grep -q '^pub struct TestStruct' "$test_dir/test_project/src/lib.rs"
	grep -q 'pub value: String' "$test_dir/test_project/src/lib.rs"
	grep -q 'use serde' "$test_dir/test_project/src/lib.rs"
}

@test "create_containerized_rust_project main.rs uses library" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Validate main.rs imports from library
	grep -q 'use suitey_test_project::TestStruct' "$test_dir/test_project/src/main.rs"
}

@test "create_containerized_rust_project integration test can use library" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Validate integration test imports from library
	grep -q 'use suitey_test_project::\*' "$test_dir/test_project/tests/integration_test.rs"
	grep -q 'TestStruct' "$test_dir/test_project/tests/integration_test.rs"
}

@test "create_containerized_rust_project cargo metadata validates project" {
	# Skip if cargo is not available
	command -v cargo >/dev/null 2>&1 || skip "cargo not available"

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Cargo should be able to parse the project
	cd "$test_dir/test_project"
	cargo metadata --format-version 1 >/dev/null 2>&1
	[ $? -eq 0 ]

	# Verify cargo recognizes both library and binary
	local lib_targets
	lib_targets=$(cargo metadata --format-version 1 2>/dev/null | grep -c '"lib"' || echo "0")
	[ "$lib_targets" -ge 1 ]

	local bin_targets
	bin_targets=$(cargo metadata --format-version 1 2>/dev/null | grep -c '"bin"' || echo "0")
	[ "$bin_targets" -ge 1 ]
}

@test "create_containerized_rust_project cargo check validates library compilation" {
	# Skip if cargo is not available
	command -v cargo >/dev/null 2>&1 || skip "cargo not available"

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Cargo check should succeed (validates syntax without full compilation)
	cd "$test_dir/test_project"
	cargo check --lib >/dev/null 2>&1
	[ $? -eq 0 ]
}

@test "create_containerized_rust_project cargo check validates binary compilation" {
	# Skip if cargo is not available
	command -v cargo >/dev/null 2>&1 || skip "cargo not available"

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Cargo check should succeed for binary
	cd "$test_dir/test_project"
	cargo check --bin suitey_test_project >/dev/null 2>&1
	[ $? -eq 0 ]
}

@test "create_containerized_rust_project integration test compiles" {
	# Skip if cargo is not available
	command -v cargo >/dev/null 2>&1 || skip "cargo not available"

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	create_containerized_rust_project "$test_dir/test_project"

	# Integration test should compile (this validates lib.rs is accessible)
	cd "$test_dir/test_project"
	cargo check --tests >/dev/null 2>&1
	[ $? -eq 0 ]
}

# ============================================================================
# Docker Availability Check Tests with Function Overriding
# ============================================================================

@test "check_docker_available respects docker function override" {
	# Override docker function to simulate unavailability
	docker() {
		case "$1" in
			info|version)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
			*)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
		esac
	}
	export -f docker

	# check_docker_available should detect unavailability
	run check_docker_available
	[ "$status" -ne 0 ]
	echo "$output" | grep -q "Docker daemon not accessible"

	# Clean up
	unset -f docker
}

@test "check_docker_available command -v finds overridden docker function" {
	# Override docker function
	docker() {
		return 0
	}
	export -f docker

	# command -v should find the function, not the binary
	local docker_path
	docker_path=$(command -v docker)
	[ "$docker_path" = "docker" ]

	# Verify it's a function
	type docker | grep -q "is a function"

	# Clean up
	unset -f docker
}

@test "build_manager_check_docker respects docker function override" {
	# Override docker function to simulate unavailability
	docker() {
		case "$1" in
			info)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
			*)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
		esac
	}
	export -f docker

	# build_manager_check_docker should detect unavailability
	run build_manager_check_docker
	[ "$status" -ne 0 ]
	echo "$output" | grep -q "Cannot connect to Docker daemon"

	# Clean up
	unset -f docker
}

@test "docker function override works in subshells with export -f" {
	# Override docker function
	local capture_file
	capture_file=$(mktemp)
	docker() {
		echo "mocked_docker_called" > "$capture_file"
		return 0
	}
	export -f docker

	# Call docker in a subshell (simulating how functions call it)
	(docker info >/dev/null 2>&1)

	# Verify the function was called, not the binary
	local captured
	captured=$(cat "$capture_file" 2>/dev/null || echo "")
	[ "$captured" = "mocked_docker_called" ]

	# Clean up
	rm -f "$capture_file"
	unset -f docker
}

@test "check_docker_available handles docker info failure correctly" {
	# Override docker to fail on info but succeed on version check
	docker() {
		case "$1" in
			info)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
			version)
				return 0
				;;
			*)
				return 1
				;;
		esac
	}
	export -f docker

	# Should detect failure at info step
	run check_docker_available
	[ "$status" -ne 0 ]
	echo "$output" | grep -q "Docker daemon not accessible"

	# Clean up
	unset -f docker
}

@test "check_docker_available handles docker version failure correctly" {
	# Override docker to succeed on info but fail on version
	docker() {
		case "$1" in
			info)
				# Return success with minimal output
				echo "Server Version: 20.10.0" >&2
				return 0
				;;
			version)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
			*)
				return 1
				;;
		esac
	}
	export -f docker

	# Should detect failure at version step
	run check_docker_available
	[ "$status" -ne 0 ]
	echo "$output" | grep -q "Docker API not accessible"

	# Clean up
	unset -f docker
}

@test "build_manager_initialize handles docker unavailability gracefully" {
	# Override docker function to simulate unavailability
	docker() {
		case "$1" in
			info|version)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
			*)
				echo "Cannot connect to the Docker daemon" >&2
				return 1
				;;
		esac
	}
	export -f docker

	# build_manager_initialize should fail gracefully
	run build_manager_initialize
	[ "$status" -ne 0 ]
	echo "$output" | grep -E -q "Docker.*not.*available|daemon.*not.*running|cannot.*connect"

	# Clean up
	unset -f docker
}

# ============================================================================
# JSON Output Parsing Tests
# ============================================================================

@test "build_manager_build_test_image returns JSON with output field" {
	# Mock docker_build to simulate successful build
	docker_build() {
		echo "#0 building with default instance"
		echo "#1 DONE 0.0s"
		echo "#2 naming to test-image:latest done"
		return 0
	}
	export -f docker_build

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	mkdir -p "$test_dir"
	echo "FROM alpine:latest" > "$test_dir/Dockerfile"

	# Call function (in test mode)
	export SUITEY_TEST_MODE=1
	output=$(build_manager_build_test_image "$test_dir/Dockerfile" "$test_dir" "test-image")

	# Should return valid JSON
	echo "$output" | jq . >/dev/null 2>&1
	[ $? -eq 0 ]

	# Should have output field
	build_output=$(json_get "$output" '.output' 2>/dev/null || echo "")
	[ -n "$build_output" ]

	# Output should contain build process indicators
	echo "$build_output" | grep -q "DONE\|naming to"

	unset -f docker_build
	unset SUITEY_TEST_MODE
}

@test "build_manager_create_test_image JSON output can be parsed for build status" {
	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	# Create minimal build requirements
	build_requirements='[{"framework": "rust", "build_steps": [{"docker_image": "rust:latest"}], "artifact_storage": {"artifacts": [], "source_code": [], "test_suites": []}}]'

	# Mock mock_docker_build (function checks for this, not docker_build)
	mock_docker_build() {
		return 0
	}
	export -f mock_docker_build

	# Call function (will use mock path when mock_docker_build is defined)
	output=$(build_manager_create_test_image "$build_requirements" "rust" "/tmp/artifacts")

	# Should return valid JSON
	echo "$output" | jq . >/dev/null 2>&1
	[ $? -eq 0 ]

	# Should have success field
	success=$(json_get "$output" '.success' 2>/dev/null || echo "")
	[ "$success" = "true" ] || [ "$success" = "false" ]

	# Should have image_name field
	image_name=$(json_get "$output" '.image_name' 2>/dev/null || echo "")
	[ -n "$image_name" ]

	unset -f mock_docker_build
}

@test "build_manager_build_test_image output field contains build process information" {
	# Mock docker_build to return build output
	docker_build() {
		echo "#0 building with default instance"
		echo "#1 [internal] load build definition"
		echo "#1 DONE 0.0s"
		echo "#2 naming to test-image:latest done"
		return 0
	}
	export -f docker_build

	local test_dir=$(mktemp -d)
	trap "rm -rf '$test_dir'" EXIT

	mkdir -p "$test_dir"
	echo "FROM alpine:latest" > "$test_dir/Dockerfile"

	export SUITEY_TEST_MODE=1
	output=$(build_manager_build_test_image "$test_dir/Dockerfile" "$test_dir" "test-image")

	# Extract output field
	build_output=$(json_get "$output" '.output' 2>/dev/null || echo "")

	# Should contain build process steps
	echo "$build_output" | grep -q "building"
	echo "$build_output" | grep -q "DONE"
	echo "$build_output" | grep -q "naming to"

	unset -f docker_build
	unset SUITEY_TEST_MODE
}

# ============================================================================
# Docker Resource Cleanup Pattern Matching Tests
# ============================================================================

@test "cleanup_docker_resources matches containers by name pattern" {
	# Skip if Docker is not available
	command -v docker >/dev/null 2>&1 || skip "Docker not available"
	check_docker_available || skip "Docker daemon not available"

	local test_pattern="suitey-test-cleanup-$(date +%s)"
	local container_name="${test_pattern}-container"

	# Create container with matching name
	container_id=$(docker run -d --name "$container_name" alpine sleep 10)

	# Verify container exists
	docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"
	[ $? -eq 0 ]

	# Clean up with pattern
	cleanup_docker_resources "$test_pattern"

	# Verify container was removed
	! docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"
	[ $? -eq 0 ]

	# Clean up any remaining containers
	docker rm -f "$container_id" 2>/dev/null || true
}

@test "cleanup_docker_resources does not remove containers without matching name" {
	# Skip if Docker is not available
	command -v docker >/dev/null 2>&1 || skip "Docker not available"
	check_docker_available || skip "Docker daemon not available"

	local test_pattern="suitey-test-cleanup-$(date +%s)"
	local other_container_name="other-container-$(date +%s)"

	# Create container without matching name
	other_container_id=$(docker run -d --name "$other_container_name" alpine sleep 10)

	# Verify container exists
	docker ps -a --format "{{.Names}}" | grep -q "^${other_container_name}$"
	[ $? -eq 0 ]

	# Clean up with pattern (should not affect other container)
	cleanup_docker_resources "$test_pattern"

	# Verify other container still exists
	docker ps -a --format "{{.Names}}" | grep -q "^${other_container_name}$"
	[ $? -eq 0 ]

	# Clean up
	docker rm -f "$other_container_id" 2>/dev/null || true
}

@test "cleanup_docker_resources requires container name to match pattern" {
	# Skip if Docker is not available
	command -v docker >/dev/null 2>&1 || skip "Docker not available"
	check_docker_available || skip "Docker daemon not available"

	local test_pattern="suitey-test-cleanup-$(date +%s)"

	# Create container without name (Docker auto-generates name)
	container_id=$(docker run -d alpine sleep 10)

	# Get the auto-generated name
	container_name=$(docker ps --format "{{.Names}}" --filter "id=$container_id" | head -1)

	# Verify container exists
	[ -n "$container_name" ]
	[ -n "$container_id" ]

	# Verify auto-generated name doesn't match pattern
	[[ "$container_name" != *"$test_pattern"* ]]

	# Clean up with pattern (won't match auto-generated name)
	cleanup_docker_resources "$test_pattern"

	# Container should still exist (pattern didn't match)
	# Check by ID since name might have changed
	docker ps -a --format "{{.ID}}" | grep -q "${container_id:0:12}"
	[ $? -eq 0 ]

	# Clean up manually
	docker rm -f "$container_id" 2>/dev/null || true
}

@test "cleanup_docker_resources matches images by reference pattern" {
	# Skip if Docker is not available
	command -v docker >/dev/null 2>&1 || skip "Docker not available"
	check_docker_available || skip "Docker daemon not available"

	local test_pattern="suitey-test-cleanup-$(date +%s)"
	local image_name="${test_pattern}-image"

	# Create a simple image
	docker build -t "$image_name" -f - . << EOF
FROM alpine:latest
RUN echo "test"
EOF

	# Verify image exists
	docker images --format "{{.Repository}}" | grep -q "^${image_name}$"
	[ $? -eq 0 ]

	# Clean up with pattern
	cleanup_docker_resources "$test_pattern"

	# Verify image was removed
	! docker images --format "{{.Repository}}" | grep -q "^${image_name}$"
	[ $? -eq 0 ]

	# Clean up any remaining images
	docker rmi "$image_name" 2>/dev/null || true
}

@test "cleanup_docker_resources matches volumes by name pattern" {
	# Skip if Docker is not available
	command -v docker >/dev/null 2>&1 || skip "Docker not available"
	check_docker_available || skip "Docker daemon not available"

	local test_pattern="suitey-test-cleanup-$(date +%s)"
	local volume_name="${test_pattern}-volume"

	# Create volume with matching name
	docker volume create "$volume_name" >/dev/null 2>&1

	# Verify volume exists
	docker volume ls --format "{{.Name}}" | grep -q "^${volume_name}$"
	[ $? -eq 0 ]

	# Clean up with pattern
	cleanup_docker_resources "$test_pattern"

	# Verify volume was removed
	! docker volume ls --format "{{.Name}}" | grep -q "^${volume_name}$"
	[ $? -eq 0 ]

	# Clean up any remaining volumes
	docker volume rm "$volume_name" 2>/dev/null || true
}
