# ============================================================================
# Framework Detector
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

# Framework Detection State
DETECTED_FRAMEWORKS_JSON=""
FRAMEWORK_DETAILS_JSON=""
BINARY_STATUS_JSON=""
FRAMEWORK_WARNINGS_JSON=""
FRAMEWORK_ERRORS_JSON=""

# Registered Framework Adapters
FRAMEWORK_ADAPTERS=(
	"bats"
	"rust"
)

# ============================================================================
# Framework Adapter Interface
# ============================================================================

# Adapter Interface Functions:
# - {framework}_adapter_detect(project_root) -> 0 if detected, 1 otherwise
# - {framework}_adapter_get_metadata(project_root) -> JSON metadata string
# - {framework}_adapter_check_binaries() -> 0 if available, 1 otherwise
# - {framework}_adapter_get_confidence(project_root) -> "high"|"medium"|"low"

# Helper function to escape JSON strings
json_escape() {
	local string="$1"
	# Escape backslashes first, then quotes
	string="${string//\\/\\\\}"
	string="${string//\"/\\\"}"
	echo "$string"
}

# Helper function to create JSON array from bash array
json_array() {
	local items=("$@")
	local json_items=()
	for item in "${items[@]}"; do
	json_items+=("\"$(json_escape "$item")\"")
	done
	echo "[$(IFS=','; echo "${json_items[*]}")]"
}

# Helper function to create JSON object from key-value pairs
json_object() {
	local pairs=("$@")
	local json_pairs=()
	for ((i=0; i<${#pairs[@]}; i+=2)); do
	local key="${pairs[i]}"
	local value="${pairs[i+1]}"
	json_pairs+=("\"$(json_escape "$key")\":\"$(json_escape "$value")\"")
	done
	echo "{$(IFS=','; echo "${json_pairs[*]}")}"
}

# ============================================================================
# Test Suite Discovery JSON Parsing
# ============================================================================

# Helper: Extract suite name from JSON
_parse_extract_suite_name() {
	local suite_json="$1"
	local framework="$2"

	# Try framework-specific name fields first, then fall back to generic
	local suite_name=""
	case "$framework" in
	"bats")
	suite_name=$(json_get "$suite_json" '.name // .file // empty')
	;;
	"rust")
	suite_name=$(json_get "$suite_json" '.name // .module // empty')
	;;
	*)
	suite_name=$(json_get "$suite_json" '.name // empty')
	;;
	esac

	# If no name found, generate one from path
	if [[ -z "$suite_name" ]] || [[ "$suite_name" == "null" ]]; then
	local file_path
	file_path=$(json_get "$suite_json" '.file // .path // empty')
	if [[ -n "$file_path" ]] && [[ "$file_path" != "null" ]]; then
	suite_name=$(basename "$file_path" | sed 's/\.[^.]*$//')
	fi
	fi

	echo "$suite_name"
}

# Helper: Extract test files from JSON
_parse_extract_test_files() {
	local suite_json="$1"
	local framework="$2"

	local test_files=""
	case "$framework" in
	"bats")
	test_files=$(json_get "$suite_json" '.file // empty')
	;;
	"rust")
	test_files=$(json_get "$suite_json" '.file // .path // empty')
	;;
	*)
	test_files=$(json_get "$suite_json" '.file // .path // empty')
	;;
	esac

	echo "$test_files"
}

# Helper: Count tests in test files
_parse_count_tests() {
	local test_files="$1"
	local framework="$2"
	local project_root="$3"

	local total_tests=0

	# Split test_files if it's a JSON array
	if [[ "$test_files" == "["* ]]; then
	local file_count
	file_count=$(json_array_length "$test_files")
	for ((i=0; i<file_count; i++)); do
	local file_path
	file_path=$(json_get "$test_files" ".[$i]")
	if [[ -n "$file_path" ]] && [[ "$file_path" != "null" ]]; then
	local test_count
	test_count=$(_parse_count_tests_in_file "$file_path" "$framework" "$project_root")
	((total_tests += test_count))
	fi
	done
	else
	# Single file
	local test_count
	test_count=$(_parse_count_tests_in_file "$test_files" "$framework" "$project_root")
	total_tests=$test_count
	fi

	echo "$total_tests"
}

# Helper: Count tests in a single file
_parse_count_tests_in_file() {
	local file_path="$1"
	local framework="$2"
	local project_root="$3"

	if [[ ! -f "$file_path" ]]; then
	echo "0"
	return
	fi

	case "$framework" in
	"bats")
	# Count @test lines
	grep -c '^@test' "$file_path" 2>/dev/null || echo "0"
	;;
	"rust")
	# Count #[test] attributes
	grep -c '#\[test\]' "$file_path" 2>/dev/null || echo "0"
	;;
	*)
	# Default: count lines that look like test functions
	grep -c '^test\|^fn test' "$file_path" 2>/dev/null || echo "0"
	;;
	esac
}

# Helper: Register test adapters
_detect_register_test_adapters() {
	# Register adapters for test frameworks
	adapter_registry_register "bats"
	adapter_registry_register "rust"
}

# Helper: Process adapter detection
_detect_process_adapter() {
	local adapter="$1"

	# Check if adapter detection function exists
	if command -v "${adapter}_adapter_detect" >/dev/null 2>&1; then
	# Call detection function
	local detection_result
	if detection_result=$("${adapter}_adapter_detect" "$PROJECT_ROOT" 2>/dev/null); then
	# Parse detection result (should be JSON)
	local detected
	detected=$(json_get "$detection_result" '.detected // false')
	if [[ "$detected" == "true" ]]; then
	local framework_info
	framework_info=$(json_get "$detection_result" '.framework_info // {}')
	DETECTED_FRAMEWORKS+=("$adapter")
	echo "detected $adapter" >&2
	return 0
	fi
	fi
	fi
	return 1
}

# Helper: Process framework metadata
_detect_process_framework_metadata() {
	local adapter="$1"
	local project_root="$2"
	local adapter_metadata_func="${adapter}_adapter_get_metadata"
	local adapter_binary_func="${adapter}_adapter_check_binaries"

	local metadata_json
	metadata_json=$("$adapter_metadata_func" "$project_root")
	echo "metadata $adapter" >&2

	echo "binary check $adapter" >&2
	echo "check_binaries $adapter" >&2
	local binary_available=false
	if "$adapter_binary_func"; then
		binary_available=true
	fi

	echo "$metadata_json"
	echo "$binary_available"
}

# Helper: Store detection results
_detect_store_results() {
	local detected_frameworks=("$@")

	# Convert to JSON array
	local json_array="[]"
	for framework in "${detected_frameworks[@]}"; do
	json_array=$(json_merge "$json_array" "[\"$framework\"]")
	done

	DETECTED_FRAMEWORKS_JSON="$json_array"
}

# Helper: Split JSON array into individual objects
_parse_split_json_array() {
	local json_array="$1"

	# Normalize JSON by removing newlines and extra whitespace for easier parsing
	# Use jq to compact the JSON, which also validates it
	local normalized_json
	normalized_json=$(echo "$json_array" | jq -c . 2>/dev/null || echo "$json_array")
	
	# Remove outer brackets and split by "},{" to get individual objects
	# Remove leading "[" and trailing "]"
	local json_content="${normalized_json#[}"
	json_content="${json_content%]}"

	# If no content left, return empty
	if [[ -z "$json_content" ]]; then
		return 0
	fi

	# Split by "},{" to get individual suite objects
	# Normalize whitespace first to handle cases with spaces around the delimiter
	json_content=$(echo "$json_content" | tr -d '\n' | sed 's/[[:space:]]*},{[[:space:]]*/},{/g')
	
	if [[ "$json_content" == *"},{"* ]]; then
		# Multiple objects - use sed to split properly
		while IFS= read -r line; do
			[[ -n "$line" ]] && echo "$line"
		done < <(echo "$json_content" | sed 's/},{/}\n{/g')
	else
		# Single object
		echo "$json_content"
	fi
}

# Helper: Extract suite data from JSON object
_parse_extract_suite_data() {
	local suite_obj="$1"
	local framework="$2"

	# Use the suite_obj directly - _parse_split_json_array already returns valid JSON objects
	# But ensure it has braces (it should, but be defensive)
	local json_obj="$suite_obj"
	if [[ "$json_obj" != \{* ]]; then
		# Missing opening brace - add it
		json_obj="{$json_obj}"
	fi
	if [[ "$json_obj" != *\} ]]; then
		# Missing closing brace - add it
		json_obj="${json_obj}}"
	fi

	# Use jq-based parsing instead of fragile regex
	local suite_name
	# Validate JSON first
	if ! echo "$json_obj" | jq . >/dev/null 2>&1; then
		echo "WARNING: Invalid JSON object for $framework: $json_obj" >&2
		return 1
	fi
	suite_name=$(json_get "$json_obj" '.name' 2>/dev/null || echo "")
	
	# Try framework-specific name fields if generic name is empty
	if [[ -z "$suite_name" ]] || [[ "$suite_name" == "null" ]]; then
		case "$framework" in
		"bats")
			suite_name=$(json_get "$json_obj" '.name // .file // empty' 2>/dev/null || echo "")
			;;
		"rust")
			suite_name=$(json_get "$json_obj" '.name // .module // empty' 2>/dev/null || echo "")
			;;
		*)
			suite_name=$(json_get "$json_obj" '.name // empty' 2>/dev/null || echo "")
			;;
		esac
	fi

	# If still no name, try to generate from file path
	if [[ -z "$suite_name" ]] || [[ "$suite_name" == "null" ]]; then
		local file_path
		file_path=$(json_get "$json_obj" '.file // .path // empty' 2>/dev/null || echo "")
		if [[ -n "$file_path" ]] && [[ "$file_path" != "null" ]]; then
			suite_name=$(basename "$file_path" | sed 's/\.[^.]*$//')
		fi
	fi

	[[ -z "$suite_name" ]] && echo "WARNING: Could not parse suite name from $framework JSON object" >&2 && return 1

	# Extract test_files array using jq
	local test_files=()
	local test_files_json
	test_files_json=$(json_get_array "$json_obj" '.test_files' 2>/dev/null || echo "")
	
	if [[ -z "$test_files_json" ]]; then
		# Try framework-specific test_files fields
		case "$framework" in
		"bats")
			test_files_json=$(json_get "$json_obj" '.file // empty' 2>/dev/null || echo "")
			;;
		"rust")
			test_files_json=$(json_get "$json_obj" '.file // .path // empty' 2>/dev/null || echo "")
			;;
		*)
			test_files_json=$(json_get "$json_obj" '.file // .path // empty' 2>/dev/null || echo "")
			;;
		esac
		
		# If we got a single file path, convert to array format
		if [[ -n "$test_files_json" ]] && [[ "$test_files_json" != "null" ]]; then
			test_files=("$test_files_json")
		fi
	else
		# Parse array output (one file per line)
		while IFS= read -r file; do
			[[ -n "$file" ]] && test_files+=("$file")
		done <<< "$test_files_json"
	fi

	[[ ${#test_files[@]} -eq 0 ]] && \
		echo "WARNING: Could not parse test_files from $framework suite '$suite_name'" >&2 && return 1

	[[ ${#test_files[@]} -eq 0 ]] && echo "WARNING: No test files found in $framework suite '$suite_name'" >&2 && return 1

	echo "$suite_name"
	printf '%s\n' "${test_files[@]}"
}

# Helper: Count tests in suite
_parse_count_tests_in_suite() {
	local framework="$1"
	local project_root="$2"
	shift 2
	local test_files=("$@")

	local total_test_count=0
	for test_file in "${test_files[@]}"; do
		if [[ -n "$test_file" ]]; then
			local abs_path="$project_root/$test_file"
			local file_test_count=0

			# Call framework-specific counting function
			case "$framework" in
			"bats")
			file_test_count=$(count_bats_tests "$abs_path")
			;;
			"rust")
			file_test_count=$(count_rust_tests "$abs_path")
			;;
			*)
			# Default: assume no tests
			file_test_count=0
			;;
			esac

			total_test_count=$((total_test_count + file_test_count))
		fi
	done

	echo "$total_test_count"
}

# Helper: Format suite output
_parse_format_suite_output() {
	local framework="$1"
	local suite_name="$2"
	local project_root="$3"
	local first_test_file="$4"
	local total_test_count="$5"

	local abs_file_path="$project_root/$first_test_file"

	# Output in DISCOVERED_SUITES format: framework|suite_name|file_path|rel_path|test_count
	echo "$framework|$suite_name|$abs_file_path|$first_test_file|$total_test_count"
}

# Parse JSON array of test suites and convert to DISCOVERED_SUITES format
# Arguments:
#   json_array: JSON array string containing test suite objects
#   framework: Framework identifier (e.g., "bats", "rust")
#   project_root: Absolute path to project root
# Returns:
#   Array of suite entries in format: framework|suite_name|file_path|rel_path|test_count
#   Each entry is output on a separate line, can be read with mapfile or similar
parse_test_suites_json() {
	local json_array="$1"
	local framework="$2"
	local project_root="$3"

	if [[ -z "$json_array" || "$json_array" == "[]" ]]; then
		return 0
	fi

	if [[ "$json_array" != \[*\] ]]; then
		echo "ERROR: Invalid JSON format for $framework - not a valid array" >&2
		return 1
	fi

	local suite_objects
	suite_objects=$(_parse_split_json_array "$json_array")

	while IFS= read -r suite_obj; do
		if [[ -z "$suite_obj" ]]; then
			continue
		fi
		local suite_data
		suite_data=$(_parse_extract_suite_data "$suite_obj" "$framework")
		if [[ $? -ne 0 ]]; then
			continue
		fi

		local suite_name=$(echo "$suite_data" | head -1)
		local test_files=()
		mapfile -t test_files < <(echo "$suite_data" | tail -n +2)

		local total_test_count
		total_test_count=$(_parse_count_tests_in_suite "$framework" "$project_root" "${test_files[@]}")
		_parse_format_suite_output "$framework" "$suite_name" "$project_root" "${test_files[0]}" "$total_test_count"
	done <<< "$suite_objects"
}

# ============================================================================
# Framework Detection Core
# ============================================================================

# Core framework detection function
detect_frameworks() {
	local project_root="$1"
	local -a detected_frameworks_array=()
	local -A framework_details_map=()
	local -A binary_status_map=()
	local -a warnings_array=()
	local -a errors_array=()

	echo "using adapter registry" >&2
	_detect_register_test_adapters

	local adapters_json=$(adapter_registry_get_all)
	local adapters=()
	if [[ "$adapters_json" != "[]" ]]; then
		adapters_json=$(echo "$adapters_json" | sed 's/^\[//' | sed 's/\]$//' | sed 's/"//g')
		IFS=',' read -ra adapters <<< "$adapters_json"
	fi

	[[ ${#adapters[@]} -eq 0 ]] && echo "no adapters" >&2

	for adapter in "${adapters[@]}"; do
		local adapter_detect_func="${adapter}_adapter_detect"
		! command -v "$adapter_detect_func" >/dev/null 2>&1 && continue

		echo "detected $adapter" >&2
		echo "registry detect $adapter" >&2
		if "$adapter_detect_func" "$project_root"; then
			detected_frameworks_array+=("$adapter")
			echo "processed $adapter" >&2

			local metadata_result=$(_detect_process_framework_metadata "$adapter" "$project_root")
			local metadata_json=$(echo "$metadata_result" | head -1)
			local binary_available=$(echo "$metadata_result" | tail -1)

			framework_details_map["$adapter"]="$metadata_json"
			binary_status_map["$adapter"]="$binary_available"

			[[ "$binary_available" == "false" ]] && warnings_array+=("$adapter binary is not available")
		else
			echo "skipped $adapter" >&2
		fi
	done

	DETECTED_FRAMEWORKS_JSON=$(array_to_json detected_frameworks_array)
	FRAMEWORK_DETAILS_JSON=$(assoc_array_to_json framework_details_map)
	BINARY_STATUS_JSON=$(assoc_array_to_json binary_status_map)
	FRAMEWORK_WARNINGS_JSON=$(array_to_json warnings_array)
	FRAMEWORK_ERRORS_JSON=$(array_to_json errors_array)
	echo "orchestrated framework detector" >&2
	echo "detection phase completed" >&2
}

# Output framework detection results as JSON
output_framework_detection_results() {
	# Build the complete JSON output
	local json_output="{"
	json_output="${json_output}\"framework_list\":$DETECTED_FRAMEWORKS_JSON,"
	json_output="${json_output}\"framework_details\":$FRAMEWORK_DETAILS_JSON,"
	json_output="${json_output}\"binary_status\":$BINARY_STATUS_JSON,"
	json_output="${json_output}\"warnings\":$FRAMEWORK_WARNINGS_JSON,"
	json_output="${json_output}\"errors\":$FRAMEWORK_ERRORS_JSON"
	json_output="${json_output}}"

	echo "$json_output"
}

