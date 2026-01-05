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

# Helper: Execute Docker build

# Helper: Prepare image context

# Helper: Build Docker image

# Helper: Prepare container arguments

# Helper: Start container

# Helper: Cleanup on signal

# Helper: Prepare Rust build

# Helper: Execute Rust build

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
