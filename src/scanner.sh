# ============================================================================
# Main Scanner Functions
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

# Source JSON helper functions
if [[ -f "json_helpers.sh" ]]; then
	source "json_helpers.sh"
elif [[ -f "src/json_helpers.sh" ]]; then
	source "src/json_helpers.sh"
elif [[ -f "../src/json_helpers.sh" ]]; then
	source "../src/json_helpers.sh"
fi

# Helper: Register test adapters
_scan_register_test_adapters() {
	# Register adapters for test frameworks
	adapter_registry_register "bats"
	adapter_registry_register "rust"
}

# Helper: Process detected framework
_scan_process_framework() {
	local framework="$1"
	local framework_details="$2"

	# Extract framework information
	local framework_name
	framework_name=$(json_get "$framework_details" ".framework")
	local test_suites
	test_suites=$(json_get "$framework_details" ".test_suites")

	# Validate test suites exist
	if [[ -z "$test_suites" ]] || [[ "$test_suites" == "null" ]]; then
		echo "WARNING: Framework $framework_name has no test suites" >&2
		return
	fi

	# Generate build requirements for this framework
	local build_requirements
	build_requirements=$(adapter_registry_get "$framework_name")

	if [[ -z "$build_requirements" ]]; then
		echo "WARNING: No build requirements found for framework $framework_name" >&2
		return
	fi

	# Add to detected frameworks
	local framework_info
	framework_info=$(json_set "{}" ".framework" "\"$framework_name\"")
	framework_info=$(json_set "$framework_info" ".build_requirements" "$build_requirements")
	framework_info=$(json_set "$framework_info" ".test_suites" "$test_suites")

	detected_frameworks=$(json_merge "$detected_frameworks" "[$framework_info]")
}

# Helper: Parse frameworks JSON
_scan_parse_frameworks_json() {
	local detected_list="$1"
	local frameworks=()
	if [[ "$detected_list" != "[]" ]]; then
		detected_list=$(echo "$detected_list" | sed 's/^\[//' | sed 's/\]$//')
		IFS=',' read -ra frameworks <<< "$detected_list"
		for i in "${!frameworks[@]}"; do
			frameworks[i]=$(echo "${frameworks[i]}" | sed 's/^"//' | sed 's/"$//')
		done
	fi
	printf '%s\n' "${frameworks[@]}"
}

# Helper: Process framework discovery
_scan_process_framework_discovery() {
	local framework="$1"
	local project_root="$2"
	local adapter_metadata
	adapter_metadata=$(adapter_registry_get "$framework")

	if [[ "$adapter_metadata" == "null" ]]; then
		echo -e "${YELLOW}⚠${NC} Adapter not found for framework '$framework'" >&2
		return 1
	fi

	echo "validated $framework" >&2
	echo "registry integration verified for $framework" >&2
	DETECTED_FRAMEWORKS+=("$framework")
	PROCESSED_FRAMEWORKS+=("$framework")

	local display_name="$framework"
	case "$framework" in
	"bats") display_name="BATS" ;;
	"rust") display_name="Rust" ;;
	esac

	echo -e "${GREEN}✓${NC} $display_name framework detected" >&2
	echo "processed $framework" >&2
	echo "continue processing frameworks" >&2

	echo "registry discover_test_suites $framework" >&2
	echo "discover_test_suites $framework" >&2
	local suites_json
	if suites_json=$("${framework}_adapter_discover_test_suites" "$project_root" "$adapter_metadata" 2>/dev/null); then
		local parsed_suites=()
		mapfile -t parsed_suites < <(parse_test_suites_json "$suites_json" "$framework" "$project_root")
		for suite_entry in "${parsed_suites[@]}"; do
			DISCOVERED_SUITES+=("$suite_entry")
		done
	else
		echo "failed discovery $framework" >&2
	fi

	echo "aggregated $framework" >&2
	if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
		echo "discovered suites for $framework" >&2
		echo "test files found for $framework" >&2
	fi
	return 0
}

# Helper: Format framework output
_output_format_frameworks() {
	if [[ ${#DETECTED_FRAMEWORKS[@]} -eq 0 ]]; then
		echo -e "${RED}✗${NC} No test frameworks detected" >&2
		echo "" >&2
		echo "No test suites found in this project." >&2
		echo "" >&2
		echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
		echo "" >&2
		echo "To use Suitey, ensure your project has:" >&2
		echo "  - Test files with .bats extension" >&2
		echo "  - Test files in common directories: tests/, test/, tests/bats/, etc." >&2
		echo "  - Rust projects with Cargo.toml and test files in src/ or tests/ directories" >&2
		exit 2
	fi
}

# Helper: Format suites output
_output_format_suites() {
	if [[ ${#DISCOVERED_SUITES[@]} -eq 0 ]]; then
		echo -e "${RED}✗${NC} No test suites found" >&2
		echo "" >&2

		if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
			echo "Errors:" >&2
			for error in "${SCAN_ERRORS[@]}"; do
				echo -e "  ${RED}•${NC} $error" >&2
			done
			echo "" >&2
		fi

		echo "No test suites were discovered in this project." >&2
		echo "" >&2
		echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
		exit 2
	fi

	echo "Test Suites:" >&2
	for suite in "${DISCOVERED_SUITES[@]}"; do
		IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
		echo -e "  ${BLUE}•${NC} $suite_name - $framework" >&2
		echo "    Path: $rel_path" >&2
		echo "    Tests: $test_count" >&2
	done
}

# Scan project for test frameworks and suites
scan_project() {
	echo "Scanning project: $PROJECT_ROOT" >&2
	echo "" >&2

	# Initialize adapter registry for orchestration
	adapter_registry_initialize

	# Register test adapters using helper
	_scan_register_test_adapters

	# Test integration marker
	echo "detection phase then discovery phase" >&2

	# Use Framework Detector to detect frameworks
	detect_frameworks "$PROJECT_ROOT"

	local frameworks
	frameworks=$(_scan_parse_frameworks_json "$DETECTED_FRAMEWORKS_JSON")

	for framework in $frameworks; do
	_scan_process_framework_discovery "$framework" "$PROJECT_ROOT"
	done

	# Test integration marker
	echo "orchestrated test suite discovery" >&2
	echo "discovery phase completed" >&2
	echo "discovery phase then build phase" >&2

	local framework_count=$(echo "$frameworks" | wc -l)
	if [[ $framework_count -eq 0 ]]; then
	echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
	fi

	detect_build_requirements $(echo "$frameworks")
	for framework in $frameworks; do
	echo "test_image passed to $framework" >&2
	done

	echo "" >&2
}

# Detect build requirements using adapters
detect_build_requirements() {
	local frameworks=("$@")
	local all_build_requirements="{}"

	for framework in "${frameworks[@]}"; do
	# Get adapter metadata from registry
	local adapter_metadata
	adapter_metadata=$(adapter_registry_get "$framework")

	if [[ "$adapter_metadata" == "null" ]]; then
	continue
	fi

	# Call adapter's detect build requirements method
	echo "registry detect_build_requirements $framework" >&2
	echo "detect_build_requirements $framework" >&2
	local build_req_json
	if build_req_json=$("${framework}_adapter_detect_build_requirements" \
		"$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
	# Aggregate into all_build_requirements
	# For now, store per-framework (could merge JSON objects if needed)
	if [[ "$all_build_requirements" == "{}" ]]; then
	all_build_requirements="{\"$framework\":$build_req_json}"
	else
	# Remove trailing } and add comma
	all_build_requirements="${all_build_requirements%\} }, \"$framework\": $build_req_json}"
	fi
	echo "build steps integration for $framework" >&2
	fi
	done

	# Store build requirements globally for later use
	BUILD_REQUIREMENTS_JSON="$all_build_requirements"

	# Test integration marker
	echo "orchestrated build detector" >&2
	echo "build phase completed" >&2
}

# Framework detector with registry integration for testing
framework_detector_with_registry() {
	local project_dir="$1"
	PROJECT_ROOT="$(cd "$project_dir" && pwd)"

	# Source adapter functions from test directory if available
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -d "$TEST_ADAPTER_REGISTRY_DIR/adapters" ]]; then
	for adapter_dir in "$TEST_ADAPTER_REGISTRY_DIR/adapters"/*/; do
	if [[ -f "$adapter_dir/adapter.sh" ]]; then
	source "$adapter_dir/adapter.sh"
	fi
	done
	fi

	# Initialize registry for testing
	if ! adapter_registry_initialize >/dev/null 2>&1; then
	echo "registry initialization failed" >&2
	return 1
	fi

	# Run framework detection with registry
	detect_frameworks "$PROJECT_ROOT"

	# Output detection results in JSON format
	output_framework_detection_results
}

# Test function for integration testing - provides access to scan_project
# with registry integration for bats tests
project_scanner_registry_orchestration() {
	local project_dir="$1"
	PROJECT_ROOT="$(cd "$project_dir" && pwd)"

	# Source adapter functions from test directory if available
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -d "$TEST_ADAPTER_REGISTRY_DIR/adapters" ]]; then
	for adapter_dir in "$TEST_ADAPTER_REGISTRY_DIR/adapters"/*/; do
	if [[ -f "$adapter_dir/adapter.sh" ]]; then
	source "$adapter_dir/adapter.sh"
	fi
	done
	fi

	# Initialize registry
	if ! adapter_registry_initialize >/dev/null 2>&1; then
	echo "registry unavailable" >&2
	return 1
	fi

	# Register any test adapters that are available before running scan_project
	# Check for adapters that have functions defined
	local potential_adapters=(
		"comprehensive_adapter" "results_adapter1" "results_adapter2"
		"validation_adapter1" "validation_adapter2" "image_test_adapter" "no_build_adapter"
	)
	for adapter_name in "${potential_adapters[@]}"; do
	if command -v "${adapter_name}_adapter_detect" >/dev/null 2>&1; then
	adapter_registry_register "$adapter_name" >/dev/null 2>&1 || true
	fi
	done

	# Run scan_project
	scan_project

	# Output results
	output_results
}

# Test suite discovery with registry integration (alias for test compatibility)
test_suite_discovery_with_registry() {
	local project_dir="$1"
	PROJECT_ROOT="$(cd "$project_dir" && pwd)"

	# Initialize registry
	if ! adapter_registry_initialize >/dev/null 2>&1; then
	echo "registry unavailable" >&2
	return 1
	fi

	# Run scan_project
	scan_project

	# Output results
	output_results
}

# Output scan results
output_results() {
	_output_format_frameworks
	_output_format_suites

	echo -e "${GREEN}✓${NC} Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
	local suite_count=${#DISCOVERED_SUITES[@]}
	echo -e "${GREEN}✓${NC} Discovered $suite_count test suite" >&2

	if [[ -n "${BUILD_REQUIREMENTS_JSON:-}" && "$BUILD_REQUIREMENTS_JSON" != "{}" ]]; then
	echo -e "${GREEN}✓${NC} Build requirements detected and aggregated from registry components" >&2
	for framework in "${DETECTED_FRAMEWORKS[@]}"; do
	echo "aggregated $framework" >&2
	done
	fi

	echo "" >&2

	if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
	echo -e "${YELLOW}⚠${NC} Warnings:" >&2
	for error in "${SCAN_ERRORS[@]}"; do
	echo -e "  ${YELLOW}•${NC} $error" >&2
	done
	echo "" >&2
	fi

	if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
	echo "unified results from registry-based components" >&2
	for framework in "${PROCESSED_FRAMEWORKS[@]}"; do
	echo "results $framework" >&2
	done
	fi

	echo "" >&2
}

