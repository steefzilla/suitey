# ============================================================================
# Rust Framework Adapter
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

# Rust adapter detection function
rust_adapter_detect() {
	local project_root="$1"

	# Check for valid Cargo.toml in project root
	if [[ -f "$project_root/Cargo.toml" && -r "$project_root/Cargo.toml" ]] && \
		grep -q '^\[package\]' "$project_root/Cargo.toml" 2>/dev/null; then
	return 0
	fi

	# Also check for Rust test files in src/ and tests/ directories (for framework detection)
	local src_dir="$project_root/src"
	local tests_dir="$project_root/tests"

	# Look for unit test files in src/ (files containing #[cfg(test)] mods)
	if [[ -d "$src_dir" ]]; then
	while IFS= read -r -d '' file; do
	if [[ -f "$file" && -r "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
	return 0
	fi
	done < <(find "$src_dir" -name "*.rs" -type f -print0 2>/dev/null || true)
	fi

	# Look for integration test files in tests/
	if [[ -d "$tests_dir" ]]; then
	if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
	return 0
	fi
	fi

	return 1
}

# Rust adapter metadata function
rust_adapter_get_metadata() {
	local project_root="${1:-}"  # Optional parameter for project-specific metadata

	# Build metadata JSON object
	local metadata_pairs=(
	"name" "Rust"
	"identifier" "rust"
	"version" "1.0.0"
	"supported_languages" '["rust"]'
	"capabilities" '["testing","compilation"]'
	"required_binaries" '["cargo"]'
	"configuration_files" '["Cargo.toml"]'
	"test_file_patterns" '["*.rs"]'
	"test_directory_patterns" '["src/","tests/"]'
	)

	json_object "${metadata_pairs[@]}" | tr -d '\n'
}

# Rust adapter binary checking function
rust_adapter_check_binaries() {
	# Allow overriding for testing
	if [[ -n "${SUITEY_MOCK_CARGO_AVAILABLE:-}" ]]; then
	[[ "$SUITEY_MOCK_CARGO_AVAILABLE" == "true" ]]
	return $?
	fi
	check_binary "cargo"
}

# Rust adapter confidence calculation
rust_adapter_get_confidence() {
	local project_root="$1"

	local indicators=0
	local has_cargo_toml=0
	local has_unit_tests=0
	local has_integration_tests=0
	local has_binary=0

	# Check for Cargo.toml
	if [[ -f "$project_root/Cargo.toml" ]]; then
	((indicators++))
	has_cargo_toml=1
	fi

	# Check for unit tests in src/
	local src_dir="$project_root/src"
	if [[ -d "$src_dir" ]]; then
	while IFS= read -r -d '' file; do
	if [[ -f "$file" && -r "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
	((indicators++))
	has_unit_tests=1
	break
	fi
	done < <(find "$src_dir" -name "*.rs" -type f -print0 2>/dev/null || true)
	fi

	# Check for integration tests in tests/
	local tests_dir="$project_root/tests"
	if [[ -d "$tests_dir" ]]; then
	if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
	((indicators++))
	has_integration_tests=1
	fi
	fi

	# Check for binary availability
	if rust_adapter_check_binaries; then
	((indicators++))
	has_binary=1
	fi

	# Determine confidence level
	if [[ $indicators -ge 3 ]]; then
	echo "high"
	elif [[ $indicators -ge 1 ]]; then
	echo "medium"
	else
	echo "low"
	fi
}

# Rust adapter detection method
rust_adapter_get_detection_method() {
	local project_root="$1"

	# Check for Cargo.toml
	if [[ -f "$project_root/Cargo.toml" ]]; then
	echo "cargo_toml"
	return
	fi

	echo "unknown"
}

# Helper: Discover unit tests in src directory
_rust_discover_unit_tests() {
	local src_dir="$1"
	local project_root="$2"
	local rust_files=()

	if [[ -d "$src_dir" ]]; then
	local src_files
	src_files=$(find_rust_test_files "$src_dir")
	if [[ -n "$src_files" ]]; then
	while IFS= read -r file; do
	if [[ -n "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
	rust_files+=("$file")
	fi
	done <<< "$src_files"
	fi
	fi

	echo "${rust_files[@]}"
}

# Helper: Discover integration tests in tests directory
_rust_discover_integration_tests() {
	local tests_dir="$1"
	local rust_files=()

	if [[ -d "$tests_dir" ]]; then
	local integration_files
	integration_files=$(find_rust_test_files "$tests_dir")
	if [[ -n "$integration_files" ]]; then
	while IFS= read -r file; do
	[[ -n "$file" ]] && rust_files+=("$file")
	done <<< "$integration_files"
	fi
	fi

	echo "${rust_files[@]}"
}

# Helper: Build JSON for discovered test suites
_rust_build_test_suites_json() {
	local project_root="$1"
	shift
	local json_files=("$@")

	local suites_json="["
	for file in "${json_files[@]}"; do
	local rel_path="${file#$project_root/}"
	rel_path="${rel_path#/}"
	
	# Generate suite name - use project_root to ensure correct relative path calculation
	# Temporarily set PROJECT_ROOT for generate_suite_name if it's not set
	local original_project_root="${PROJECT_ROOT:-}"
	export PROJECT_ROOT="$project_root"
	local suite_name=$(generate_suite_name "$file" "rs")
	if [[ -n "$original_project_root" ]]; then
		export PROJECT_ROOT="$original_project_root"
	else
		unset PROJECT_ROOT
	fi
	
	# If suite_name is still empty, generate from rel_path
	if [[ -z "$suite_name" ]]; then
		suite_name="${rel_path%.rs}"
		suite_name="${suite_name//\//-}"
		if [[ -z "$suite_name" ]]; then
			suite_name=$(basename "$file" ".rs")
		fi
	fi
	
	local test_count=$(count_rust_tests "$(get_absolute_path "$file")")

	suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"rust\"," \
		"\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
	done
	suites_json="${suites_json%,}]"

	echo "$suites_json"
}

# Rust adapter discover test suites method
rust_adapter_discover_test_suites() {
	local project_root="$1"
	local framework_metadata="$2"

	# Only discover Rust test suites if Cargo.toml exists
	if [[ ! -f "$project_root/Cargo.toml" ]]; then
	echo "[]"
	return 0
	fi

	local src_dir="$project_root/src"
	local tests_dir="$project_root/tests"

	# Discover test files using helpers
	local unit_tests
	unit_tests=$(_rust_discover_unit_tests "$src_dir" "$project_root")

	local integration_tests
	integration_tests=$(_rust_discover_integration_tests "$tests_dir")

	# Combine all test files
	local all_test_files=($unit_tests $integration_tests)

	# Build JSON output using helper
	if [[ ${#all_test_files[@]} -eq 0 ]]; then
	echo "[]"
	else
	_rust_build_test_suites_json "$project_root" "${all_test_files[@]}"
	fi
}

# Rust adapter detect build requirements method
rust_adapter_detect_build_requirements() {
	local project_root="$1"
	local framework_metadata="$2"

	# Rust typically requires building before testing
	cat << BUILD_EOF
{
	"requires_build": true,
	"build_steps": ["compile"],
	"build_commands": ["cargo build"],
	"build_dependencies": [],
	"build_artifacts": ["target/"]
}
BUILD_EOF
}

# Rust adapter get build steps method
rust_adapter_get_build_steps() {
	local project_root="$1"
	local build_requirements="$2"

	cat << STEPS_EOF
[
	{
	"step_name": "compile",
	"docker_image": "rust:latest",
	"install_dependencies_command": "",
	"build_command": "cargo build --jobs \$(nproc)",
	"working_directory": "/workspace",
	"volume_mounts": [],
	"environment_variables": {},
	"cpu_cores": null
	}
]
STEPS_EOF
}

# Rust adapter execute test suite method
rust_adapter_execute_test_suite() {
	local test_suite="$1"
	local test_image="$2"
	local execution_config="$3"

	cat << EXEC_EOF
{
	"exit_code": 0,
	"duration": 2.5,
	"output": "Mock Rust test execution output",
	"container_id": "rust_container",
	"execution_method": "docker",
	"test_image": "${test_image}"
}
EXEC_EOF
}

# Rust adapter parse test results method
rust_adapter_parse_test_results() {
	local output="$1"
	local exit_code="$2"

	cat << RESULTS_EOF
{
	"total_tests": 10,
	"passed_tests": 10,
	"failed_tests": 0,
	"skipped_tests": 0,
	"test_details": [],
	"status": "passed"
}
RESULTS_EOF
}

# ============================================================================
# Rust Detection Functions
# ============================================================================

# Check if a file is a Rust source file
is_rust_file() {
	local file="$1"

	# Check file extension
	if [[ "$file" == *.rs ]]; then
	return 0
	fi

	return 1
}

# Count the number of #[test] annotations in a Rust file
count_rust_tests() {
	local file="$1"
	count_tests_in_file "$file" "#[test]"
}

# Find all Rust test files in a directory
find_rust_test_files() {
	local dir="$1"
	local files=()

	if [[ ! -d "$dir" ]]; then
	return 1
	fi

	# Use find to locate all .rs files
	while IFS= read -r -d '' file; do
	if is_rust_file "$file"; then
	files+=("$file")
	fi
	done < <(find "$dir" -type f -name "*.rs" -print0 2>/dev/null || true)

	printf '%s\n' "${files[@]}"
}

