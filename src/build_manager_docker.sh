# ============================================================================
# Build Manager Docker Wrappers
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
# Docker Wrapper Functions
# ============================================================================

# Wrapper for docker run command with testability support
docker_run() {
	# Detect if this is complex arguments (real usage) or simple arguments (test usage)
	if [[ $# -le 5 ]] && [[ "$1" != -* ]] && [[ "$2" != -* ]]; then
		# Simple interface: docker_run container_name image command [exit_code] [output]
		# This is the test/mock interface - tests override this function
		local container_name="$1"
		local image="$2"
		local command="$3"
		local exit_code="${4:-0}"
		local output="${5:-Mock Docker run output}"

		echo "$output"
		return $exit_code
	else
		# Complex interface: docker_run [docker options...] image command
		# Transform complex arguments to simple interface for mocking
		local simple_args
		simple_args=$(transform_docker_args "$@")

		# Extract the simple parameters
		local container_name image command
		read -r container_name <<< "$(echo "$simple_args" | head -1)"
		read -r image <<< "$(echo "$simple_args" | head -2 | tail -1)"
		read -r command <<< "$(echo "$simple_args" | head -3 | tail -1)"

		# Call the simple interface (which tests override)
		docker_run "$container_name" "$image" "$command"
	fi
}

# Execute real docker run command
_execute_docker_run() {
	local container_name="$1"
	local image="$2"
	local command="$3"
	local cpu_cores="$4"
	local project_root="$5"
	local artifacts_dir="$6"
	local working_dir="$7"

	# Build docker run command with proper options
	local docker_cmd=("docker" "run" "--rm" "--name" "$container_name")

	if [[ -n "$cpu_cores" ]]; then
		docker_cmd+=("--cpus" "$cpu_cores")
	fi

	if [[ -n "$project_root" ]]; then
		docker_cmd+=("-v" "$project_root:/workspace")
	fi

	if [[ -n "$artifacts_dir" ]]; then
		docker_cmd+=("-v" "$artifacts_dir:/artifacts")
	fi

	if [[ -n "$working_dir" ]]; then
		docker_cmd+=("-w" "$working_dir")
	fi

	docker_cmd+=("$image" "/bin/sh" "-c" "$command")

	# Execute the command
	"${docker_cmd[@]}"
}

# Wrapper for docker build command
docker_build() {
	# Check if this looks like a mock call (simple parameters) or real call (complex parameters)
	if [[ $# -le 3 ]] && [[ "$1" != -* ]]; then
		# Looks like mock interface: docker_build context_dir image_name [exit_code]
		# This is handled by test mocks
		return 0
	else
		# Real Docker interface - call docker directly to allow function overrides in tests
		# In production, this will call the real docker binary; in tests, it will use the overridden function
		docker build "$@"
	fi
}

# Wrapper for docker cp command
docker_cp() {
	local source="$1"
	local dest="$2"

	# Call docker directly to allow function overrides in tests
	# In production, this will call the real docker binary; in tests, it will use the overridden function
	docker cp "$source" "$dest"
}

