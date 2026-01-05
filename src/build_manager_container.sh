# ============================================================================
# Build Manager Container Management
# ============================================================================
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

# ============================================================================
# Container Management Functions
# ============================================================================

# Launch a container for build execution
# Arguments:
#   build_requirements_json: JSON build requirements
#   framework: framework identifier
# Returns: container ID on success, empty string on failure
build_manager_launch_container() {
	local build_requirements_json="$1"
	local framework="$2"

	local build_req
	! build_req=$(_build_manager_find_framework_req "$build_requirements_json" "$framework") && echo "" && return 1

	local timestamp=$(date +%Y%m%d-%H%M%S)
	local random_suffix=$(printf "%04x" $((RANDOM % 65536)))
	local container_name="suitey-build-$framework-$timestamp-$random_suffix"

	local build_step=$(json_get "$build_req" '.build_steps[0]')
	local docker_image=$(json_get "$build_step" '.docker_image')
	local cpu_cores=$(json_get "$build_step" '.cpu_cores // empty')
	local working_dir=$(json_get "$build_step" '.working_directory // "/workspace"')

	[[ -z "$cpu_cores" || "$cpu_cores" == "null" ]] && cpu_cores=$(build_manager_get_cpu_cores)
	[[ -z "$working_dir" || "$working_dir" == "null" ]] && working_dir="/workspace"

	local container_id
	if [[ -n "${PROJECT_ROOT:-}" ]]; then
		[[ ! -d "${PROJECT_ROOT}" ]] && mkdir -p "${PROJECT_ROOT}" 2>/dev/null
		container_id=$(docker run -d --name "$container_name" --cpus "$cpu_cores" \
			-v "$PROJECT_ROOT:/workspace" -w "$working_dir" "$docker_image" \
			sleep 3600 2>/dev/null)
	else
		container_id=$(docker run -d --name "$container_name" --cpus "$cpu_cores" \
			-w "$working_dir" "$docker_image" sleep 3600 2>/dev/null)
	fi

	if [[ -n "$container_id" ]]; then
		BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
		echo "$container_id"
	else
		echo ""
		return 1
	fi
}

# Stop a running container gracefully
# Arguments:
#   container_id: Docker container ID or name
build_manager_stop_container() {
	local container_id="$1"

	if [[ -n "$container_id" ]]; then
	docker stop "$container_id" 2>/dev/null || true
	BUILD_MANAGER_ACTIVE_CONTAINERS=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$container_id/}")
	fi
}

# Remove a container and clean up resources
# Arguments:
#   container_id: Docker container ID or name
build_manager_cleanup_container() {
	local container_id="$1"

	if [[ -n "$container_id" ]]; then
	docker rm -f "$container_id" 2>/dev/null || true
	BUILD_MANAGER_ACTIVE_CONTAINERS=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$container_id/}")
	fi
}

# Remove a Docker image
# Arguments:
#   image_name: Docker image name or ID
build_manager_cleanup_image() {
	local image_name="$1"

	if [[ -n "$image_name" ]]; then
	docker rmi -f "$image_name" 2>/dev/null || true
	fi
}

