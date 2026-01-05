# ============================================================================
# Build Manager Build Execution
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
# Build Execution Functions
# ============================================================================

# Execute multiple builds in parallel with CPU core limits
# Arguments:
#   builds_json: JSON array of build specifications
# Returns: JSON array of build results
build_manager_execute_parallel() {
	local builds_json="$1"

	local results="[]"
	local max_parallel=$(build_manager_get_cpu_cores)
	local active_builds=()
	local build_pids=()

	local build_count
	build_count=$(json_array_length "$builds_json")

	for ((i=0; i<build_count; i++)); do
	local build_spec
	build_spec=$(json_array_get "$builds_json" "$i")

	if [[ -n "$build_spec" ]] && [[ "$build_spec" != "null" ]]; then
	local pid
	if pid=$(_build_manager_setup_async_build "$build_spec" "$max_parallel" "${active_builds[@]}" "${build_pids[@]}"); then
	build_pids+=("$pid")
	active_builds+=("$i")
	else
	wait "${build_pids[0]}"
	unset build_pids[0]
	build_pids=("${build_pids[@]}")
	build_manager_execute_build_async "$build_spec" &
	pid=$!
	build_pids+=("$pid")
	fi
	fi
	done

	for pid in "${build_pids[@]}"; do
	wait "$pid" 2>/dev/null || true
	done

	local result_files=("$BUILD_MANAGER_TEMP_DIR/builds"/*/result.json)
	for result_file in "${result_files[@]}"; do
	if [[ -f "$result_file" ]]; then
	local result
	result=$(cat "$result_file")
	results=$(json_merge "$results" "[$result]")
	fi
	done

	echo "$results"
}

# Execute a single build in a Docker container
# Arguments:
#   build_spec_json: JSON build specification
#   framework: framework identifier
# Returns: JSON build result
build_manager_execute_build() {
	local build_spec_json="$1"
	local framework="$2"

	local build_spec_values
	build_spec_values=$(_build_manager_parse_build_spec "$build_spec_json")
	local docker_image=$(echo "$build_spec_values" | sed -n '1p')
	local build_command=$(echo "$build_spec_values" | sed -n '2p')
	local install_deps_cmd=$(echo "$build_spec_values" | sed -n '3p')
	local working_dir=$(echo "$build_spec_values" | sed -n '4p')
	local cpu_cores=$(echo "$build_spec_values" | sed -n '5p')

	local build_dir="$BUILD_MANAGER_TEMP_DIR/builds/$framework"
	mkdir -p "$build_dir"

	local container_name
	container_name=$(_build_manager_setup_build_container "$framework")

	local full_command=""
	if [[ -n "$install_deps_cmd" ]]; then
		full_command="$install_deps_cmd && $build_command"
	else
		full_command="$build_command"
	fi

	local start_time
	start_time=$(date +%s.%3N)
	local output_file="$build_dir/output.txt"

	local exit_code
	exit_code=$(_build_manager_execute_docker_build "$container_name" "$docker_image" "$full_command" "$output_file")

	local end_time
	end_time=$(date +%s.%3N)

	local result
	result=$(_build_manager_create_result_json \
		"$framework" \
		"$exit_code" \
		"$start_time" \
		"$end_time" \
		"$cpu_cores" \
		"$container_name" \
		"$output_file" \
		"$build_dir")

	echo "$result" > "$build_dir/result.json"
	BUILD_MANAGER_ACTIVE_CONTAINERS=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$container_name/}")

	echo "$result"
}

# Execute a build asynchronously (for parallel execution)
# Arguments:
#   build_spec_json: JSON build specification
build_manager_execute_build_async() {
	local build_spec_json="$1"
	local framework
	framework=$(json_get "$build_spec_json" '.framework')

	build_manager_execute_build "$build_spec_json" "$framework" > /dev/null
}

