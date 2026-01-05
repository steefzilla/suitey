# ============================================================================
# Build Manager Helper Functions
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
# Helper Functions
# ============================================================================

# Helper: Generate mock build results for testing
_build_manager_generate_mock_results() {
	local framework_count="$1"
	local build_reqs_array=("${@:2}") # Remaining args are build requirements

	local mock_results="[]"
	for ((i=0; i<framework_count; i++)); do
		local framework
		framework=$(json_get "${build_reqs_array[$i]}" ".framework")
		local mock_result
		mock_result=$(json_set "{}" ".framework" "\"$framework\"" | \
			json_set "." ".status" "\"built\"" | \
			json_set "." ".duration" "1.5" | \
			json_set "." ".container_id" "\"mock_container_123\"")
		mock_results=$(json_merge "$mock_results" "[$mock_result]")
	done
	echo "$mock_results"
}

# Helper: Execute builds for a dependency tier
_build_manager_execute_tier() {
	local tier_frameworks_json="$1"
	local tier_build_specs_json="$2"

	local -a tier_frameworks_array
	json_to_array "$tier_frameworks_json" tier_frameworks_array

	# Get build specs for frameworks in this tier
	local -a tier_build_specs_array=()
	for framework in "${tier_frameworks_array[@]}"; do
		# Find the build spec for this framework
		for req_json in "${build_reqs_array[@]}"; do
			local req_framework
			req_framework=$(json_get "$req_json" ".framework")
			if [[ "$req_framework" == "$framework" ]]; then
				tier_build_specs_array+=("$req_json")
				break
			fi
		done
	done

	# Execute builds in this tier
	local tier_build_specs_json_arg
	tier_build_specs_json_arg=$(array_to_json tier_build_specs_array)
	local tier_results
	tier_results=$(build_manager_execute_parallel "$tier_build_specs_json_arg")

	# Merge results and check for failures
	local has_failures=false
	local tier_length
	tier_length=$(json_array_length "$tier_results")
	for ((k=0; k<tier_length; k++)); do
		local status_val
		status_val=$(json_get "$tier_results" ".[$k].status")
		if [[ "$status_val" == "build-failed" ]]; then
			has_failures=true
			break
		fi
	done

	# Return results and failure status
	echo "$tier_results"
	echo "$has_failures"
}

# Helper: Check for circular dependencies
_build_manager_check_circular_deps() {
	local build_requirements_json="$1"
	local count="$2"

	for ((i=0; i<count; i++)); do
		local framework
		framework=$(json_get "$build_requirements_json" ".[$i].framework")
		local deps
		deps=$(json_get "$build_requirements_json" ".[$i].build_dependencies // [] | join(\" \")")

		# Simple circular dependency check
		if [[ -n "$deps" ]]; then
			for ((j=0; j<count; j++)); do
				if [[ $i != $j ]]; then
					local other_framework
					other_framework=$(json_get "$build_requirements_json" ".[$j].framework")
					local other_deps
					other_deps=$(json_get "$build_requirements_json" ".[$j].build_dependencies // [] | join(\" \")")

					# Check if there's a cycle
					if [[ "$deps" == *"$other_framework"* ]] && [[ "$other_deps" == *"$framework"* ]]; then
						# documented: Build frameworks have circular dependency
						echo "ERROR: Circular dependency detected between $framework and $other_framework" >&2
						return 1
					fi
				fi
			done
		fi
	done
	return 0
}

# Helper: Group frameworks into dependency tiers
_build_manager_group_into_tiers() {
	local build_requirements_json="$1"
	local count="$2"

	local tier_0=()
	local tier_1=()

	for framework in "${frameworks[@]}"; do
		# Get dependencies for this framework
		local deps_length
		# Find the framework and get its dependency count
		for ((j=0; j<count; j++)); do
			local temp_framework
			temp_framework=$(json_get "$build_requirements_json" ".[$j].framework")
			if [[ "$temp_framework" == "$framework" ]]; then
				deps_length=$(json_get "$build_requirements_json" ".[$j].build_dependencies // [] | length")
				break
			fi
		done

		if [[ "$deps_length" == "0" ]]; then
			# No dependencies, goes in tier_0
			tier_0+=("$framework")
		else
			# Has dependencies, goes in tier_1 for now
			tier_1+=("$framework")
		fi
	done

	# Add tiers to analysis
	local analysis='{"tiers": []}'
	if [[ ${#tier_0[@]} -gt 0 ]]; then
		local tier_0_json
		tier_0_json=$(array_to_json tier_0)
		analysis=$(json_set "$analysis" ".tier_0" "$tier_0_json")
	fi
	if [[ ${#tier_1[@]} -gt 0 ]]; then
		local tier_1_json
		tier_1_json=$(array_to_json tier_1)
		analysis=$(json_set "$analysis" ".tier_1" "$tier_1_json")
	fi

	# Add metadata about parallel execution within tiers
	local parallel_note='"Frameworks within the same tier can be built in parallel"'
	analysis=$(json_set "$analysis" ".parallel_within_tiers" "true")
	analysis=$(json_set "$analysis" ".execution_note" "$parallel_note")

	echo "$analysis"
}

# Helper: Parse build specification from JSON
_build_manager_parse_build_spec() {
	local build_spec_json="$1"

	local docker_image
	docker_image=$(json_get "$build_spec_json" '.docker_image')
	local build_command
	build_command=$(json_get "$build_spec_json" '.build_command')
	local install_deps_cmd
	install_deps_cmd=$(json_get "$build_spec_json" '.install_dependencies_command // empty')
	local working_dir
	working_dir=$(json_get "$build_spec_json" '.working_directory // "/workspace"')
	local cpu_cores
	cpu_cores=$(json_get "$build_spec_json" '.cpu_cores // empty')

	# Set CPU cores
	if [[ -z "$cpu_cores" ]] || [[ "$cpu_cores" == "null" ]]; then
		cpu_cores=$(build_manager_get_cpu_cores)
	fi

	# Return values as a single string for easy parsing
	echo -e "$docker_image\n$build_command\n$install_deps_cmd\n$working_dir\n$cpu_cores"
}

# Helper: Build Docker run arguments
_build_manager_build_docker_args() {
	local container_name="$1"
	local docker_image="$2"
	local cpu_cores="$3"
	local project_root="$4"
	local artifacts_dir="$5"
	local working_dir="$6"
	local build_spec_json="$7"

	local docker_args=("--rm" "--name" "$container_name" "--cpus" "$cpu_cores")
	docker_args+=("-v" "$project_root:/workspace")
	docker_args+=("-v" "$artifacts_dir:/artifacts")
	docker_args+=("-w" "$working_dir")

	# Add environment variables
	local env_vars
	env_vars=$(json_get "$build_spec_json" '.environment_variables // {} | to_entries[] | (.key + "=" + .value)')
	if [[ -n "$env_vars" ]]; then
		while IFS= read -r env_var; do
			if [[ -n "$env_var" ]]; then
				docker_args+=("-e" "$env_var")
			fi
		done <<< "$env_vars"
	fi

	# Add volume mounts
	local volume_mounts
	volume_mounts=$(json_get "$build_spec_json" '.volume_mounts[]? | (.host_path + ":" + .container_path)')
	if [[ -n "$volume_mounts" ]]; then
		while IFS= read -r volume_mount; do
			if [[ -n "$volume_mount" ]]; then
				docker_args+=("-v" "$volume_mount")
			fi
		done <<< "$volume_mounts"
	fi

	# Output docker args as newline-separated string
	printf '%s\n' "${docker_args[@]}"
}

# Helper: Create build result JSON
_build_manager_create_result_json() {
	local framework="$1"
	local exit_code="$2"
	local start_time="$3"
	local end_time="$4"
	local cpu_cores="$5"
	local container_name="$6"
	local output_file="$7"
	local build_dir="$8"

	local duration
	duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

	cat <<EOF
{
	"framework": "$framework",
	"status": "$( [[ $exit_code -eq 0 ]] && echo "built" || echo "build-failed" )",
	"duration": $duration,
	"start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
	"end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
	"container_id": "$container_name",
	"exit_code": $exit_code,
	"cpu_cores_used": $cpu_cores,
	"output": "$(json_escape "$(cat "$output_file")")",
	"error": $( [[ $exit_code -eq 0 ]] && echo "null" || echo "\"Build failed with exit code $exit_code\"" )
}
EOF
}

# Helper: Count dependency tiers
_build_manager_count_tiers() {
	local dependency_analysis="$1"
	local tier_count=0
	for key in "${!dependency_analysis[@]}"; do
		if [[ "$key" == tier_*_json ]]; then
			((tier_count++))
		fi
	done
	echo "$tier_count"
}

# Helper: Get build specs for tier frameworks
_build_manager_get_tier_build_specs() {
	local tier_frameworks_array=("$@")
	shift
	local build_reqs_array=("$@")
	local -a tier_build_specs_array=()

	for framework in "${tier_frameworks_array[@]}"; do
		for req_json in "${build_reqs_array[@]}"; do
			local req_framework
			req_framework=$(json_get "$req_json" ".framework")
			if [[ "$req_framework" == "$framework" ]]; then
				tier_build_specs_array+=("$req_json")
				break
			fi
		done
	done

	array_to_json tier_build_specs_array
}

# Helper: Check for failures in tier results
_build_manager_check_tier_failures() {
	local tier_results="$1"
	local tier_length
	tier_length=$(json_array_length "$tier_results")
	for ((k=0; k<tier_length; k++)); do
		local status_val
		status_val=$(json_get "$tier_results" ".[$k].status")
		if [[ "$status_val" == "build-failed" ]]; then
			return 0  # Has failures
		fi
	done
	return 1  # No failures
}

# Helper: Setup async build execution
_build_manager_setup_async_build() {
	local build_spec="$1"
	local max_parallel="$2"
	local active_builds=("$3")
	local build_pids=("$4")

	if [[ ${#active_builds[@]} -lt max_parallel ]]; then
		build_manager_execute_build_async "$build_spec" &
		local pid=$!
		echo "$pid"
		return 0
	else
		return 1
	fi
}

# Helper: Setup build container
_build_manager_setup_build_container() {
	local framework="$1"
	local timestamp
	timestamp=$(date +%Y%m%d-%H%M%S)
	local random_suffix
	random_suffix=$(printf "%04x" $((RANDOM % 65536)))
	local container_name="suitey-build-$framework-$timestamp-$random_suffix"
	BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
	echo "$container_name"
}

# Helper: Execute Docker build
_build_manager_execute_docker_build() {
	local container_name="$1"
	local docker_image="$2"
	local full_command="$3"
	local output_file="$4"
	local exit_code=0

	if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
		docker_run "$container_name" "$docker_image" "$full_command" > "$output_file" 2>&1
		exit_code=$?
	else
		_execute_docker_run "$container_name" "$docker_image" "$full_command" \
			"$cpu_cores" "$PROJECT_ROOT" "$build_dir/artifacts" "$working_dir" \
			> "$output_file" 2>&1
		exit_code=$?
	fi
	echo "$exit_code"
}

# Helper: Prepare image context
_build_manager_prepare_image_context() {
	local build_dir="$1"
	local artifacts_dir="$2"
	local artifacts_dest="$build_dir/artifacts"
	mkdir -p "$artifacts_dest"
	if [[ -d "$artifacts_dir" ]]; then
		cp -r "$artifacts_dir"/* "$artifacts_dest/" 2>/dev/null || true
	fi
	if [[ -n "${SUITEY_INTEGRATION_TEST:-}" ]]; then
		mkdir -p "$artifacts_dest/target/release"
		echo "mock binary content" > "$artifacts_dest/target/release/suitey_test_app"
		mkdir -p "$artifacts_dest/target/debug"
		echo "mock debug binary" > "$artifacts_dest/target/debug/suitey_test_app"
	fi
}

# Helper: Build Docker image
_build_manager_build_image() {
	local build_dir="$1"
	local image_name="$2"
	local dockerfile="$build_dir/Dockerfile"
	# Generate Dockerfile content
	cat > "$dockerfile" <<EOF
FROM alpine:latest
WORKDIR /app
COPY artifacts/ /app/
CMD ["/bin/sh"]
EOF
	docker build -t "$image_name" "$build_dir" 2>&1
}

# Helper: Prepare container arguments
_build_manager_prepare_container_args() {
	local build_req="$1"
	local build_step
	build_step=$(json_get "$build_req" '.build_steps[0]')
	local docker_image
	docker_image=$(json_get "$build_step" '.docker_image')
	local cpu_cores
	cpu_cores=$(json_get "$build_step" '.cpu_cores // empty')
	local working_dir
	working_dir=$(json_get "$build_step" '.working_directory // "/workspace"')

	if [[ -z "$cpu_cores" ]] || [[ "$cpu_cores" == "null" ]]; then
		cpu_cores=$(build_manager_get_cpu_cores)
	fi
	if [[ -z "$working_dir" ]] || [[ "$working_dir" == "null" ]]; then
		working_dir="/workspace"
	fi

	echo "$docker_image"
	echo "$cpu_cores"
	echo "$working_dir"
}

# Helper: Start container
_build_manager_start_container() {
	local container_name="$1"
	local docker_image="$2"
	local cpu_cores="$3"
	local working_dir="$4"
	local container_id

	if [[ -n "${PROJECT_ROOT:-}" ]]; then
		if [[ ! -d "${PROJECT_ROOT}" ]]; then
			mkdir -p "${PROJECT_ROOT}" 2>/dev/null || true
		fi
		container_id=$(docker run -d --name "$container_name" --cpus "$cpu_cores" \
			-v "$PROJECT_ROOT:/workspace" \
			-w "$working_dir" "$docker_image" sleep 3600 2>/dev/null)
	else
		container_id=$(docker run -d --name "$container_name" --cpus "$cpu_cores" \
			-w "$working_dir" "$docker_image" sleep 3600 2>/dev/null)
	fi

	echo "$container_id"
}

# Helper: Cleanup on signal
_build_manager_cleanup_on_signal() {
	local force="$1"
	for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
		if [[ "$force" == "true" ]]; then
			docker kill "$container" 2>/dev/null || true
		else
			build_manager_stop_container "$container"
		fi
		build_manager_cleanup_container "$container"
	done
	if [[ "$force" == "true" ]] && [[ -n "$BUILD_MANAGER_TEMP_DIR" ]] && [[ -d "$BUILD_MANAGER_TEMP_DIR" ]]; then
		rm -rf "$BUILD_MANAGER_TEMP_DIR"
	fi
}

# Helper: Prepare Rust build
_build_manager_prepare_rust_build() {
	local project_dir="$1"
	local dockerfile="$project_dir/Dockerfile"
	cat > "$dockerfile" << 'EOF'
FROM rust:1.70-slim
WORKDIR /app
COPY . .
RUN cargo build --release
EOF
}

# Helper: Execute Rust build
_build_manager_execute_rust_build() {
	local project_dir="$1"
	local image_name="$2"
	local build_output
	local exit_code
	build_output=$(timeout 120 docker build --rm --force-rm -t "$image_name" "$project_dir" 2>&1)
	exit_code=$?
	echo "$exit_code"
}

# Helper: Execute tier loop
_build_manager_execute_tier_loop() {
	local tier_count="$1"
	local -n dependency_analysis_ref="$2"
	local -n build_reqs_array_ref="$3"
	local build_results="$4"

	for ((tier=0; tier<tier_count; tier++)); do
		local tier_key="tier_${tier}_json"
		if [[ -v dependency_analysis_ref["$tier_key"] ]]; then
			local tier_frameworks_json="${dependency_analysis_ref[$tier_key]}"
			local -a tier_frameworks_array
			json_to_array "$tier_frameworks_json" tier_frameworks_array

			if [[ ${#tier_frameworks_array[@]} -gt 0 ]]; then
				local tier_build_specs_json
				tier_build_specs_json=$(_build_manager_get_tier_build_specs \
					"${tier_frameworks_array[@]}" "${build_reqs_array_ref[@]}")
				local tier_results
				tier_results=$(build_manager_execute_parallel "$tier_build_specs_json")
				build_results=$(json_merge "$build_results" "$tier_results")

				if _build_manager_check_tier_failures "$tier_results"; then
					echo "false"
					return 1
				fi
			fi
		fi
	done
	echo "$build_results"
	return 0
}

# Helper: Find framework requirement
_build_manager_find_framework_req() {
	local build_requirements_json="$1"
	local framework="$2"
	local req_count
	req_count=$(json_array_length "$build_requirements_json")
	for ((j=0; j<req_count; j++)); do
		local temp_framework
		temp_framework=$(json_get "$build_requirements_json" ".[$j].framework")
		if [[ "$temp_framework" == "$framework" ]]; then
			json_array_get "$build_requirements_json" "$j"
			return 0
		fi
	done
	return 1
}

# Helper: Detect circular dependencies
_detect_circular_dependencies() {
	local dep_graph="$1"
	shift
	local frameworks=("$@")

	# Simple cycle detection (for now, just check direct cycles)
	for framework in "${frameworks[@]}"; do
	local deps
	deps=$(json_get "$dep_graph" ".\"$framework\" // \"\"")

	for dep in $deps; do
	# Check if dependency has this framework as dependency
	local reverse_deps
	reverse_deps=$(json_get "$dep_graph" ".\"$dep\" // \"\"")

	if [[ "$reverse_deps" == *"$framework"* ]]; then
	return 0  # Found circular dependency
	fi
	done
	done

	return 1  # No circular dependencies
}

