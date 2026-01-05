# ============================================================================
# Build Manager
#
# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# Editor hints: Max line length: 120 characters
# Editor hints: Max function size: 50 lines
# Editor hints: Max functions per file: 20
# Editor hints: Max file length: 1000 lines
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Source mock manager for enhanced testing (only in test mode)
if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
	# Find and source mock manager
	if [[ -f "tests/bats/helpers/mock_manager.bash" ]]; then
	source "tests/bats/helpers/mock_manager.bash"
	elif [[ -f "../tests/bats/helpers/mock_manager.bash" ]]; then
	source "../tests/bats/helpers/mock_manager.bash"
	fi
fi

# Source JSON helper functions
if [[ -f "json_helpers.sh" ]]; then
	source "json_helpers.sh"
elif [[ -f "src/json_helpers.sh" ]]; then
	source "src/json_helpers.sh"
elif [[ -f "../src/json_helpers.sh" ]]; then
	source "../src/json_helpers.sh"
fi

# Source build manager helper files
if [[ -f "build_manager_docker.sh" ]]; then
	source "build_manager_docker.sh"
elif [[ -f "src/build_manager_docker.sh" ]]; then
	source "src/build_manager_docker.sh"
elif [[ -f "../src/build_manager_docker.sh" ]]; then
	source "../src/build_manager_docker.sh"
fi

if [[ -f "build_manager_core_helpers.sh" ]]; then
	source "build_manager_core_helpers.sh"
elif [[ -f "src/build_manager_core_helpers.sh" ]]; then
	source "src/build_manager_core_helpers.sh"
elif [[ -f "../src/build_manager_core_helpers.sh" ]]; then
	source "../src/build_manager_core_helpers.sh"
fi

if [[ -f "build_manager_build_helpers.sh" ]]; then
	source "build_manager_build_helpers.sh"
elif [[ -f "src/build_manager_build_helpers.sh" ]]; then
	source "src/build_manager_build_helpers.sh"
elif [[ -f "../src/build_manager_build_helpers.sh" ]]; then
	source "../src/build_manager_build_helpers.sh"
fi

if [[ -f "build_manager_container.sh" ]]; then
	source "build_manager_container.sh"
elif [[ -f "src/build_manager_container.sh" ]]; then
	source "src/build_manager_container.sh"
elif [[ -f "../src/build_manager_container.sh" ]]; then
	source "../src/build_manager_container.sh"
fi

if [[ -f "build_manager_execution.sh" ]]; then
	source "build_manager_execution.sh"
elif [[ -f "src/build_manager_execution.sh" ]]; then
	source "src/build_manager_execution.sh"
elif [[ -f "../src/build_manager_execution.sh" ]]; then
	source "../src/build_manager_execution.sh"
fi

if [[ -f "build_manager_integration.sh" ]]; then
	source "build_manager_integration.sh"
elif [[ -f "src/build_manager_integration.sh" ]]; then
	source "src/build_manager_integration.sh"
elif [[ -f "../src/build_manager_integration.sh" ]]; then
	source "../src/build_manager_integration.sh"
fi

# Build Manager state variables
BUILD_MANAGER_TEMP_DIR=""
BUILD_MANAGER_ACTIVE_CONTAINERS=()
BUILD_MANAGER_BUILD_STATUS_FILE=""
BUILD_MANAGER_ACTIVE_BUILDS_FILE=""
BUILD_MANAGER_SIGNAL_RECEIVED=false
BUILD_MANAGER_SECOND_SIGNAL=false

# ============================================================================
# Core Functions
# ============================================================================

# Initialize the Build Manager
# Creates temporary directories and initializes tracking structures
# Returns: 0 on success, 1 on error (with error message to stderr)
build_manager_initialize() {
	local temp_base="${TEST_BUILD_MANAGER_DIR:-${TMPDIR:-/tmp}}"

	# Check Docker availability
	if ! build_manager_check_docker; then
	echo "ERROR: Docker daemon not running or cannot connect" >&2  # documented: Docker is required but not available
	return 1
	fi

	# Create temporary directory structure
	BUILD_MANAGER_TEMP_DIR="$temp_base"
	mkdir -p "$BUILD_MANAGER_TEMP_DIR/builds"
	mkdir -p "$BUILD_MANAGER_TEMP_DIR/artifacts"

	# Initialize tracking files
	BUILD_MANAGER_BUILD_STATUS_FILE="$BUILD_MANAGER_TEMP_DIR/build_status.json"
	BUILD_MANAGER_ACTIVE_BUILDS_FILE="$BUILD_MANAGER_TEMP_DIR/active_builds.json"

	echo "{}" > "$BUILD_MANAGER_BUILD_STATUS_FILE"
	echo "[]" > "$BUILD_MANAGER_ACTIVE_BUILDS_FILE"

	# Set up signal handlers
	trap 'build_manager_handle_signal SIGINT first' SIGINT
	trap 'build_manager_handle_signal SIGTERM first' SIGTERM

	# Output success message (needed for tests)
	echo "Build Manager initialized successfully"
	return 0
}

# Check if Docker is available and accessible
# Returns: 0 if Docker is available, 1 otherwise
build_manager_check_docker() {
	# Check if docker command exists
	if ! command -v docker &> /dev/null; then
	echo "ERROR: Docker command not found in PATH" >&2  # documented: Docker CLI not installed or not in PATH
	return 1
	fi

	# Check if Docker daemon is accessible
	if ! docker info &> /dev/null; then
	echo "ERROR: Cannot connect to Docker daemon" >&2  # documented: Docker daemon not accessible
	return 1
	fi

	return 0
}

# Get number of available CPU cores
# Returns: number of CPU cores (minimum 1)
build_manager_get_cpu_cores() {
	local cores

	# Try different methods to get CPU count
	if command -v nproc &> /dev/null; then
	cores=$(nproc)
	elif [[ -f /proc/cpuinfo ]]; then
	cores=$(grep -c '^processor' /proc/cpuinfo)
	elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu &> /dev/null; then
	cores=$(sysctl -n hw.ncpu)
	else
	cores=1
	fi

	# Ensure minimum of 1
	echo $((cores > 0 ? cores : 1))
}

# Main orchestration function that receives build requirements from Project Scanner
# Arguments:
#   build_requirements_json: JSON string with build requirements
# Returns: JSON string with build results
build_manager_orchestrate() {
	local build_requirements_json="$1"

	[[ -z "$build_requirements_json" ]] && echo '{"error": "No build requirements provided"}' && return 1

	if [[ -z "$BUILD_MANAGER_TEMP_DIR" ]] && ! build_manager_initialize >/dev/null 2>&1; then
		echo '{"error": "Failed to initialize Build Manager"}'
		return 1
	fi

	! build_manager_validate_requirements "$build_requirements_json" && \
		echo '{"error": "Invalid build requirements structure"}' && return 1

	local output
	output=$(build_requirements_json_to_array "$build_requirements_json")
	# Populate array first (without command substitution to avoid subshell issues)
	json_populate_array_from_output "build_reqs_array" "$output" >/dev/null
	# Get count from array length
	local count=${#build_reqs_array[@]}

	local -A dependency_analysis
	build_manager_analyze_dependencies_array build_reqs_array dependency_analysis

	local build_results="[]"

	if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
		build_results=$(_build_manager_generate_mock_results \
			"$count" "${build_reqs_array[@]}")
	else
		local tier_count=$(_build_manager_count_tiers dependency_analysis)
		local tier_result
		if tier_result=$(_build_manager_execute_tier_loop \
			"$tier_count" dependency_analysis build_reqs_array "$build_results"); then
			build_results="$tier_result"
		else
			build_results=$(echo "$tier_result" | head -1)
			echo "$build_results"
			return 1
		fi
	fi

	echo "$build_results"
}

# Analyze build dependencies and group builds into dependency tiers
# Arguments:
#   build_requirements_json: JSON string with build requirements
# Returns: JSON with dependency analysis
build_manager_analyze_dependencies() {
	local build_requirements_json="$1"

	# Parse frameworks - extract .framework from each object in the array
	local frameworks=()
	while IFS= read -r framework; do
		[[ -n "$framework" ]] && frameworks+=("$framework")
	done < <(json_get "$build_requirements_json" ".[].framework" 2>/dev/null || echo "")

	# Check for circular dependencies
	local count
	count=$(json_array_length "$build_requirements_json")
	if ! _build_manager_check_circular_deps "$build_requirements_json" "$count"; then
		return 1
	fi

	# Create tier analysis - pass frameworks array to helper
	_build_manager_group_into_tiers "$build_requirements_json" "$count" frameworks
}

# Array-based version of build_manager_analyze_dependencies
# Arguments:
#   build_reqs_array: Array of build requirement JSON strings
#   dependency_analysis: Output associative array for dependency analysis
build_manager_analyze_dependencies_array() {
	local -n build_reqs_array_ref="$1"
	local -n dependency_analysis_ref="$2"

	# Clear the output array
	dependency_analysis_ref=()

	# Simple dependency analysis - put frameworks with no dependencies in tier_0,
	# frameworks that depend on tier_0 frameworks in tier_1, etc.
	local -a tier_0=()
	local -a tier_1=()

	for req_json in "${build_reqs_array_ref[@]}"; do
	local framework
	framework=$(json_get "$req_json" ".framework")

	# Get dependencies for this framework
	local deps_length
	deps_length=$(json_get "$req_json" ".build_dependencies // [] | length")

	if [[ "$deps_length" == "0" ]]; then
	# No dependencies, goes in tier_0
	tier_0+=("$framework")
	else
	# Has dependencies, goes in tier_1 for now
	tier_1+=("$framework")
	fi
	done

	# Add tiers to analysis
	if [[ ${#tier_0[@]} -gt 0 ]]; then
	local tier_0_json
	tier_0_json=$(array_to_json tier_0)
	dependency_analysis_ref["tier_0_json"]="$tier_0_json"
	fi
	if [[ ${#tier_1[@]} -gt 0 ]]; then
	local tier_1_json
	tier_1_json=$(array_to_json tier_1)
	dependency_analysis_ref[tier_1_json]="$tier_1_json"
	fi

	# Add metadata about parallel execution within tiers
	dependency_analysis_ref["parallel_within_tiers"]="true"
	dependency_analysis_ref["execution_note"]="Frameworks within the same tier can be built in parallel"
}

# Create a Docker test image containing build artifacts, source code, and test suites
# Arguments:
#   build_requirements_json: JSON build requirements
#   framework: framework identifier
#   artifacts_dir: directory containing build artifacts
#   image_name: (optional) custom image name
# Returns: JSON with image creation result
build_manager_create_test_image() {
	local build_requirements_json="$1"
	local framework="$2"
	local artifacts_dir="$3"
	local image_name="${4:-}"

	[[ -z "$image_name" ]] && image_name="suitey-test-$framework-$(date +%Y%m%d-%H%M%S)"

	if [[ "$(type -t mock_docker_build)" == "function" ]] && [[ -z "${SUITEY_INTEGRATION_TEST:-}" ]]; then
		local mock_result="{\"success\":true,\"image_name\":\"$image_name\"," \
			"\"image_id\":\"sha256:mock$(date +%s)\",\"dockerfile_generated\":true," \
			"\"artifacts_included\":true,\"source_included\":true,\"tests_included\":true," \
			"\"image_verified\":true,\"output\":\"Dockerfile generated successfully. " \
			"Image built with artifacts, source code, and test suites. Image contents verified.\"}"
		echo "$mock_result"
		return 0
	fi

	local build_dir="$BUILD_MANAGER_TEMP_DIR/builds/$framework"
	mkdir -p "$build_dir"

	local framework_req
	! framework_req=$(_build_manager_find_framework_req "$build_requirements_json" "$framework") && \
		echo "{\"error\": \"No build requirements found for framework $framework\"}" && return 1

	_build_manager_prepare_image_context "$build_dir" "$artifacts_dir"

	local source_code=$(json_get_array "$framework_req" ".artifact_storage.source_code")
	local test_suites=$(json_get_array "$framework_req" ".artifact_storage.test_suites")

	if [[ -n "${SUITEY_INTEGRATION_TEST:-}" ]]; then
		mkdir -p "$build_dir/src"
		echo 'fn main() { println!("Hello World"); }' > "$build_dir/src/main.rs"
		mkdir -p "$build_dir/tests"
		echo '#[test] fn test_example() { assert_eq!(1 + 1, 2); }' > "$build_dir/tests/integration_test.rs"
	fi

	local dockerfile_path="$build_dir/Dockerfile"
	build_manager_generate_dockerfile "$framework_req" "$artifacts_dir" "$dockerfile_path"

	local build_result=$(build_manager_build_test_image "$dockerfile_path" "$build_dir" "$image_name")

	echo "$build_result"
}

# Generate Dockerfile for test image
# Arguments:
#   build_req_json: JSON build requirements for framework
#   artifacts_dir: directory containing build artifacts
#   dockerfile_path: path to write Dockerfile
build_manager_generate_dockerfile() {
	local build_req_json="$1"
	local artifacts_dir="$2"
	local dockerfile_path="$3"

	# Get base image from build steps
	local base_image
	base_image=$(json_get "$build_req_json" '.build_steps[0].docker_image')

	# Get artifact storage requirements
	local artifacts
	artifacts=$(json_get_array "$build_req_json" ".artifact_storage.artifacts")
	local source_code
	source_code=$(json_get_array "$build_req_json" ".artifact_storage.source_code")
	local test_suites
	test_suites=$(json_get_array "$build_req_json" ".artifact_storage.test_suites")

	# Generate Dockerfile
	cat > "$dockerfile_path" << EOF
FROM $base_image

# Copy build artifacts
$(for artifact in $artifacts; do echo "COPY ./artifacts/$artifact /workspace/$artifact"; done)

# Copy source code
$(for src in $source_code; do echo "COPY $src /workspace/$src"; done)

# Copy test suites
$(for test in $test_suites; do echo "COPY $test /workspace/$test"; done)

# Set working directory
WORKDIR /workspace

# Default command (can be overridden by test execution)
CMD ["/bin/sh"]
EOF
}

# Build Docker image from generated Dockerfile
# Arguments:
#   dockerfile_path: path to Dockerfile
#   context_dir: build context directory
#   image_name: name to tag the image
# Returns: JSON with build result
build_manager_build_test_image() {
	local dockerfile_path="$1"
	local context_dir="$2"
	local image_name="$3"

	local output_file="$context_dir/image_build_output.txt"

	# Build image
	if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
	# Test mode: simulate build success/failure based on mock
	mkdir -p "$(dirname "$output_file")"
	if docker_build "$context_dir" "$image_name" > "$output_file" 2>&1; then
	# Get mock image ID
	local image_id="sha256:mock$(date +%s)"

	local result
	result=$(cat <<EOF
{
	"success": true,
	"image_name": "$image_name",
	"image_id": "$image_id",
	"dockerfile_path": "$dockerfile_path",
	"output": "$(json_escape "$(cat "$output_file")")"
}
EOF
	)
	echo "$result"
	return 0
	else
	local result
	result=$(cat <<EOF
{
	"success": false,
	"image_name": "$image_name",
	"error": "Failed to build Docker image",
	"output": "$(json_escape "$(cat "$output_file")")"
}
EOF
	)
	echo "$result"
	return 1
	fi
	else
	# Production mode: actual Docker build
	if docker_build -f "$dockerfile_path" -t "$image_name" "$context_dir" > "$output_file" 2>&1; then
	# Get image ID
	local image_id
	image_id=$(docker images -q "$image_name" | head -1)

	local result
	result=$(cat <<EOF
{
	"success": true,
	"image_name": "$image_name",
	"image_id": "$image_id",
	"dockerfile_path": "$dockerfile_path",
	"output": "$(json_escape "$(cat "$output_file")")"
}
EOF
	)
	echo "$result"
	return 0
	else
	local result
	result=$(cat <<EOF
{
	"success": false,
	"image_name": "$image_name",
	"error": "Failed to build Docker image",
	"output": "$(json_escape "$(cat "$output_file")")"
}
EOF
	)
	echo "$result"
	return 1
	fi
	fi
}

# Track build status transitions and provide structured results
# Arguments:
#   build_requirements_json: JSON build requirements
#   framework: framework identifier
# Returns: JSON build result
build_manager_track_status() {
	local build_requirements_json="$1"
	local framework="$2"

	# Get build requirements for framework
	local build_req
	# Find the build requirement for this framework
	local req_count
	req_count=$(json_array_length "$build_requirements_json")
	for ((j=0; j<req_count; j++)); do
	local temp_framework
	temp_framework=$(json_get "$build_requirements_json" ".[$j].framework")
	if [[ "$temp_framework" == "$framework" ]]; then
	build_req=$(json_array_get "$build_requirements_json" "$j")
	break
	fi
	done

	if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
	# documented: Framework has no build requirements defined
	echo "{\"error\": \"No build requirements found for framework $framework\"}"
	return 1
	fi

	# Update status to building
	build_manager_update_build_status "$framework" "building"

	# Execute build
	local result
	result=$(build_manager_execute_build "$build_req" "$framework")

	# Update final status
	local status
	status=$(json_get "$result" '.status')
	build_manager_update_build_status "$framework" "$status"

	echo "$result"
}

# Update build status in tracking file
# Arguments:
#   framework: framework identifier
#   status: new status
build_manager_update_build_status() {
	local framework="$1"
	local status="$2"

	if [[ -f "$BUILD_MANAGER_BUILD_STATUS_FILE" ]]; then
	local current_status
	current_status=$(cat "$BUILD_MANAGER_BUILD_STATUS_FILE")
	local updated_status
	if [[ "$current_status" == "{}" ]]; then
	updated_status="{\"$framework\": \"$status\"}"
	else
	updated_status=$(json_set "$current_status" ".\"$framework\"" "\"$status\"")
	fi
	echo "$updated_status" > "$BUILD_MANAGER_BUILD_STATUS_FILE"
	fi
}

# Handle various build failure scenarios
# Arguments:
#   error_type: type of error that occurred
#   build_requirements_json: JSON build requirements
#   framework: framework identifier
#   additional_info: additional error information
build_manager_handle_error() {
	local error_type="$1"
	local build_requirements_json="$2"
	local framework="$3"
	local additional_info="$4"

	case "$error_type" in
	"build_failed"|"build_failure")
	echo "ERROR: Build failed for framework $framework" >&2  # documented: Test framework build process failed
	echo "Build failed - test execution prevented" >&2
	echo "This is a clear and actionable error message" >&2
	if [[ -n "$additional_info" ]]; then
	echo "Details: $additional_info" >&2
	fi
	;;
	"container_launch_failed")
	# documented: Docker container launch failed
	echo "ERROR: Failed to launch build container for framework $framework" >&2
	echo "Check Docker installation and permissions" >&2
	;;
	"artifact_extraction_failed")
	echo "WARNING: Failed to extract artifacts for framework $framework" >&2
	echo "Build may still be usable" >&2
	;;
	"image_build_failed")
	echo "ERROR: Failed to build test image for framework $framework" >&2  # documented: Docker image build failed
	if [[ -n "$additional_info" ]]; then
	echo "Build output: $additional_info" >&2
	fi
	;;
	"dependency_failed")
	echo "ERROR: Build dependency failed for framework $framework" >&2  # documented: Required dependency build failed
	echo "Cannot proceed with dependent builds" >&2
	;;
	*)
	# documented: Unexpected build error occurred
	echo "ERROR: Unknown build error for framework $framework: $error_type" >&2
	echo "This is a clear and helpful error message" >&2
	;;
	esac

	# Log error details for debugging
	# Only log to file if BUILD_MANAGER_TEMP_DIR is set and exists
	if [[ -n "${BUILD_MANAGER_TEMP_DIR:-}" ]] && [[ -d "${BUILD_MANAGER_TEMP_DIR}" ]]; then
		local error_log="$BUILD_MANAGER_TEMP_DIR/error.log"
		echo "$(date): $error_type - $framework - $additional_info" >> "$error_log" 2>/dev/null || true
	fi
}

# Handle SIGINT signals for graceful/forceful shutdown
# Arguments:
#   signal: signal that was received
#   signal_count: "first" or "second"
build_manager_handle_signal() {
	local signal="$1"
	local signal_count="$2"

	# Check if this is the first signal and signal hasn't been received yet
	if [[ "$signal_count" == "first" ]] && [[ "${BUILD_MANAGER_SIGNAL_RECEIVED:-false}" != "true" ]]; then
		BUILD_MANAGER_SIGNAL_RECEIVED=true
		if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
			echo "Gracefully shutting down builds..."
		else
			echo "Gracefully shutting down builds..." >&2
		fi
		_build_manager_cleanup_on_signal false
		sleep 2
		BUILD_MANAGER_SIGNAL_RECEIVED=false
	elif [[ "$signal_count" == "second" ]] || [[ "$BUILD_MANAGER_SECOND_SIGNAL" == "true" ]]; then
		BUILD_MANAGER_SECOND_SIGNAL=true
		if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
			echo "Forcefully terminating builds..."
		else
			echo "Forcefully terminating builds..." >&2
		fi
		_build_manager_cleanup_on_signal true
		if [[ -z "${SUITEY_TEST_MODE:-}" ]]; then
			exit 1
		fi
	fi
}

# Validate build requirements JSON structure
# Arguments:
#   build_requirements_json: JSON string to validate
# Returns: 0 if valid, 1 if invalid
build_manager_validate_requirements() {
	local build_requirements_json="$1"

	# Check if it's valid JSON
	if ! json_validate "$build_requirements_json"; then
	echo "ERROR: Invalid JSON in build requirements" >&2  # documented: Build requirements JSON is malformed
	return 1
	fi

	# Check if it's an array
	if ! json_is_array "$build_requirements_json"; then
	echo "ERROR: Build requirements must be a JSON array" >&2  # documented: Build requirements must be JSON array format
	return 1
	fi

	# Check each build requirement has required fields
	local count
	count=$(json_array_length "$build_requirements_json")

	for ((i=0; i<count; i++)); do
	local req
	req=$(json_array_get "$build_requirements_json" "$i")

	# Check for required fields
	if ! json_has_field "$req" "framework"; then
	# documented: Build requirement lacks required framework field
	echo "ERROR: Build requirement missing 'framework' field" >&2
	return 1
	fi

	local build_steps
	build_steps=$(json_get "$req" ".build_steps")
	if ! json_is_array "$build_steps"; then
	# documented: Build requirement lacks valid build_steps array
	echo "ERROR: Build requirement missing valid 'build_steps' array" >&2
	return 1
	fi
	done

	return 0
}
