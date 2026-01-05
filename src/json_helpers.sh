# ============================================================================
# JSON Helper Functions
# ============================================================================
# Standardized JSON operations using jq, with consistent error handling
# and performance optimizations for repeated use.
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
# Core JSON Access Functions
# ============================================================================

# Extract a value from JSON using a jq path
# Arguments:
#   json: JSON string
#   path: jq path expression (e.g., '.field', '.array[0]')
# Returns:
#   Extracted value as string, or empty string on error
json_get() {
	local json="$1"
	local path="$2"

	# Validate inputs
	if [[ -z "$json" ]] || [[ -z "$path" ]]; then
	return 1
	fi

	# Strip REGISTRY_END and other markers that might pollute JSON output
	json="${json%%REGISTRY_END*}"
	json="${json%%CAPABILITIES_END*}"
	json="${json%%ORDER_END*}"
	json="${json#*REGISTRY_START}"
	json="${json#*CAPABILITIES_START}"
	json="${json#*ORDER_START}"

	echo "$json" | jq -r "$path" 2>/dev/null || return 1
}

# Extract an array from JSON as a newline-separated string
# Arguments:
#   json: JSON string
#   path: jq path to array (e.g., '.items', '.array')
# Returns:
#   Array elements one per line, or empty on error
json_get_array() {
	local json="$1"
	local path="$2"

	if [[ -z "$json" ]] || [[ -z "$path" ]]; then
	return 1
	fi

	# Strip REGISTRY_END and other markers that might pollute JSON output
	json="${json%%REGISTRY_END*}"
	json="${json%%CAPABILITIES_END*}"
	json="${json%%ORDER_END*}"
	json="${json#*REGISTRY_START}"
	json="${json#*CAPABILITIES_START}"
	json="${json#*ORDER_START}"

	echo "$json" | jq -r "$path[]?" 2>/dev/null || return 1
}

# Get the length of a JSON array
# Arguments:
#   json: JSON string
# Returns:
#   Array length as integer, or 0 on error
json_array_length() {
	local json="$1"

	if [[ -z "$json" ]]; then
	echo "0"
	return 1
	fi

	echo "$json" | jq 'length' 2>/dev/null || echo "0"
}

# Get an element from a JSON array by index
# Arguments:
#   json: JSON string
#   index: Array index (0-based)
# Returns:
#   Array element as string, or empty on error
json_array_get() {
	local json="$1"
	local index="$2"

	if [[ -z "$json" ]] || ! [[ "$index" =~ ^[0-9]+$ ]]; then
	return 1
	fi

	echo "$json" | jq -r ".[$index]" 2>/dev/null || return 1
}

# Check if a JSON object has a specific field
# Arguments:
#   json: JSON string
#   field: Field name to check
# Returns:
#   0 if field exists, 1 if not
json_has_field() {
	local json="$1"
	local field="$2"

	if [[ -z "$json" ]] || [[ -z "$field" ]]; then
	return 1
	fi

	# Strip REGISTRY_END and other markers that might pollute JSON output
	json="${json%%REGISTRY_END*}"
	json="${json%%CAPABILITIES_END*}"
	json="${json%%ORDER_END*}"
	json="${json#*REGISTRY_START}"
	json="${json#*CAPABILITIES_START}"
	json="${json#*ORDER_START}"

	echo "$json" | jq -e "has(\"$field\")" >/dev/null 2>&1
}

# ============================================================================
# JSON Modification Functions
# ============================================================================

# Set a value in JSON (creates new JSON with updated value)
# Arguments:
#   json: Original JSON string
#   path: jq path to set
#   value: New value (will be JSON-encoded)
# Returns:
#   Updated JSON string, or original on error
json_set() {
	local json="$1"
	local path="$2"
	local value="$3"

	if [[ -z "$json" ]] || [[ -z "$path" ]]; then
	echo "$json"
	return 1
	fi

	echo "$json" | jq "$path = $value" 2>/dev/null || echo "$json"
}

# Append a value to a JSON array
# Arguments:
#   json: JSON array string
#   value: Value to append (will be JSON-encoded)
# Returns:
#   Updated JSON array, or original on error
json_array_append() {
	local json="$1"
	local value="$2"

	if [[ -z "$json" ]]; then
	echo "[$value]"
	return
	fi

	echo "$json" | jq ". += [$value]" 2>/dev/null || echo "$json"
}

# Merge two JSON objects or arrays
# Arguments:
#   json1: First JSON string
#   json2: Second JSON string
# Returns:
#   Merged JSON, or json1 on error
json_merge() {
	local json1="$1"
	local json2="$2"

	if [[ -z "$json1" ]]; then
	echo "$json2"
	return
	fi

	if [[ -z "$json2" ]]; then
	echo "$json1"
	return
	fi

	echo "$json1 $json2" | jq -s '.[0] + .[1]' 2>/dev/null || echo "$json1"
}

# ============================================================================
# JSON Validation Functions
# ============================================================================

# Validate that a string is valid JSON
# Arguments:
#   json: String to validate
# Returns:
#   0 if valid JSON, 1 if invalid
json_validate() {
	local json="$1"

	if [[ -z "$json" ]]; then
	return 1
	fi

	echo "$json" | jq . >/dev/null 2>&1
}

# Check if JSON represents an array
# Arguments:
#   json: JSON string
# Returns:
#   0 if array, 1 if not
json_is_array() {
	local json="$1"

	if [[ -z "$json" ]]; then
	return 1
	fi

	echo "$json" | jq -e 'type == "array"' >/dev/null 2>&1
}

# Check if JSON represents an object
# Arguments:
#   json: JSON string
# Returns:
#   0 if object, 1 if not
json_is_object() {
	local json="$1"

	if [[ -z "$json" ]]; then
	return 1
	fi

	echo "$json" | jq -e 'type == "object"' >/dev/null 2>&1
}

# ============================================================================
# Array ↔ JSON Conversion Functions
# ============================================================================

# Convert a JSON array to a Bash array
# Arguments:
#   json: JSON array string
# Returns:
#   Returns: first line = count, subsequent lines = array elements (one per line)
#
# PATTERN: Return-Data Approach
# This function uses the return-data pattern to avoid BATS scoping issues with
# namerefs/eval. Instead of modifying the caller's array directly, it returns data
# that the caller can use to populate their array using json_populate_array_from_output().
#
# Usage example:
#   output=$(json_to_array "$json")
#   count=$(json_populate_array_from_output "my_array" "$output")
json_to_array() {
	local json="$1"

	if [[ -z "$json" ]]; then
		echo "0"
		return 1
	fi

	# Validate input and get elements
	local elements
	if ! elements=$(echo "$json" | jq -r '.[]' 2>/dev/null); then
		echo "0"
		return 1
	fi

	# Count elements (handle empty case - jq returns nothing, echo adds newline)
	local count
	if [[ -z "$elements" ]]; then
		count=0
	else
		count=$(echo "$elements" | wc -l | tr -d ' ')
	fi

	# Output count first, then elements
	echo "$count"
	echo "$elements"

	return 0
}

# Convert a Bash array to JSON array
# Arguments:
#   var_name: Name of Bash array variable
# Returns:
#   JSON array string
#
# PATTERN: Read-Only Nameref (acceptable)
# This function uses nameref only to read array values, not to modify them.
# Read-only nameref is acceptable and does not cause scoping issues.
array_to_json() {
	local var_name="$1"

	if [[ -z "$var_name" ]]; then
	echo "[]"
	return 1
	fi

	local -n arr="$var_name"
	local json_items=()

	for item in "${arr[@]}"; do
	# Escape the item for JSON
	local escaped_item
	escaped_item=$(json_escape "$item")
	json_items+=("\"$escaped_item\"")
	done

	local joined
	joined=$(IFS=','; echo "${json_items[*]}")
	echo "[$joined]"
}

# Convert an associative array to JSON object
# Arguments:
#   var_name: Name of Bash associative array variable
# Returns:
#   JSON object string
#
# PATTERN: Read-Only Nameref (acceptable)
# This function uses nameref only to read associative array values, not to modify them.
# Read-only nameref is acceptable and does not cause scoping issues.
assoc_array_to_json() {
	local var_name="$1"

	if [[ -z "$var_name" ]]; then
	echo "{}"
	return 1
	fi

	local -n assoc_arr="$var_name"
	local json_pairs=()

	for key in "${!assoc_arr[@]}"; do
	local escaped_key
	escaped_key=$(json_escape "$key")
	local escaped_value
	escaped_value=$(json_escape "${assoc_arr[$key]}")
	json_pairs+=("\"$escaped_key\":\"$escaped_value\"")
	done

	local joined
	joined=$(IFS=','; echo "${json_pairs[*]}")
	echo "{$joined}"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Escape a string for use in JSON
# Arguments:
#   string: String to escape
# Returns:
#   Escaped string
json_escape() {
	local string="$1"

	# Escape backslashes first, then quotes
	string="${string//\\/\\\\}"
	string="${string//\"/\\\"}"
	string="${string//$'\n'/\\n}"
	string="${string//$'\r'/\\r}"
	string="${string//$'\t'/\\t}"

	echo "$string"
}

# ============================================================================
# Specialized Conversion Functions (for Suitey data structures)
# ============================================================================

# Convert build requirements JSON to Bash array structure
# Arguments:
#   json: Build requirements JSON array
# Returns:
#   Returns: first line = count, subsequent lines = JSON requirement strings
#
# PATTERN: Return-Data Approach
# This function uses the return-data pattern to avoid BATS scoping issues with
# namerefs/eval. Instead of modifying the caller's array directly, it returns data
# that the caller can use to populate their array using json_populate_array_from_output().
#
# Usage example:
#   output=$(build_requirements_json_to_array "$json")
#   count=$(json_populate_array_from_output "my_array" "$output")
build_requirements_json_to_array() {
	local json="$1"

	if [[ -z "$json" ]]; then
		echo "0"
		return 1
	fi

	# Validate input
	if ! json_validate "$json" || ! json_is_array "$json"; then
		echo "0"
		return 1
	fi

	# Get array length
	local total_count
	total_count=$(json_array_length "$json")

	# Count and output non-null requirements
	local count=0
	for ((i=0; i<total_count; i++)); do
		local req_json
		req_json=$(json_array_get "$json" "$i")
		if [[ -n "$req_json" ]] && [[ "$req_json" != "null" ]]; then
			((++count))  # Use pre-increment to avoid 0 evaluation issue with set -e
		fi
	done

	# Output count first
	echo "$count"

	# Extract each requirement and output (compacted to single line)
	for ((i=0; i<total_count; i++)); do
		local req_json
		req_json=$(json_array_get "$json" "$i")
		if [[ -n "$req_json" ]] && [[ "$req_json" != "null" ]]; then
			# Compact JSON to single line for easier parsing
			echo "$req_json" | jq -c .
		fi
	done

	return 0
}

# ============================================================================
# Return-Data Pattern Helper Function
# ============================================================================
#
# Helper function to populate a Bash array from return-data format
# This is a reusable pattern for functions that return data instead of modifying
# arrays directly (to avoid BATS scoping issues).
#
# Arguments:
#   array_name: Name of Bash array variable to populate
#   output: Output from a return-data function (first line is count, rest are array elements)
# Returns:
#   Populates the named array and returns the count
#
# Usage example:
#   output=$(_json_to_array_return_data "$json")
#   count=$(json_populate_array_from_output "my_array" "$output")
json_populate_array_from_output() {
	local array_name="$1"
	local output="$2"

	local count
	count=$(echo "$output" | head -n 1)

	# Populate array from remaining lines (only if count > 0)
	if [[ "$count" -gt 0 ]]; then
		# Unset any local declaration first, then declare as global
		# This allows us to modify arrays even if caller declared them locally
		eval "unset ${array_name} 2>/dev/null || true"
		eval "declare -g -a ${array_name}"
		# Populate using eval (to avoid BATS scoping issues with nameref)
		# Use printf %q for safe quoting (matches pattern from shell.bats tests)
		local idx=0
		while IFS= read -r element; do
			[[ -z "$element" ]] && continue
			local safe_element
			safe_element=$(printf '%q' "$element")
			# For indexed arrays, use numeric index (no quotes needed) and safe_element
			eval "${array_name}[$idx]=$safe_element"
			((++idx))  # Use pre-increment to avoid 0 evaluation issue with set -e
		done < <(echo "$output" | tail -n +2)
	fi

	echo "$count"
	return 0
}

# Convert dependency analysis associative array to JSON
# Arguments:
#   var_name: Name of associative array variable
# Returns:
#   JSON object with tier information
#
# PATTERN: Read-Only Nameref (acceptable)
# This function uses nameref only to read associative array values, not to modify them.
# Read-only nameref is acceptable and does not cause scoping issues.
dependency_analysis_array_to_json() {
	local var_name="$1"

	if [[ -z "$var_name" ]]; then
	echo "{}"
	return 1
	fi

	local -n analysis="$var_name"
	local json="{"

	# Add each key-value pair
	local first=true
	for key in "${!analysis[@]}"; do
	if [[ "$first" == "true" ]]; then
	first=false
	else
	json="${json},"
	fi

	local escaped_key
	escaped_key=$(json_escape "$key")
	local escaped_value
	escaped_value=$(json_escape "${analysis[$key]}")

	json="${json}\"$escaped_key\":\"$escaped_value\""
	done

	json="${json}}"
	echo "$json"
}

# Convert framework detection results to JSON (used by detect_frameworks)
# Arguments:
#   frameworks_array: Array of detected framework names
#   details_map: Associative array of framework details
#   binary_map: Associative array of binary status
#   warnings_array: Array of warning messages
#   errors_array: Array of error messages
# Returns:
#   Complete JSON detection results object
framework_detection_results_to_json() {
	local frameworks_array="$1"
	local details_map="$2"
	local binary_map="$3"
	local warnings_array="$4"
	local errors_array="$5"

	local frameworks_json
	frameworks_json=$(array_to_json "$frameworks_array")

	local details_json
	details_json=$(assoc_array_to_json "$details_map")

	local binary_json
	binary_json=$(assoc_array_to_json "$binary_map")

	local warnings_json
	warnings_json=$(array_to_json "$warnings_array")

	local errors_json
	errors_json=$(array_to_json "$errors_array")

	# documented: Outputting framework detection results as JSON
	echo "{\"framework_list\":$frameworks_json,\"framework_details\":$details_json," \
		"\"binary_status\":$binary_json,\"warnings\":$warnings_json,\"errors\":$errors_json}"
}

# ============================================================================
# Caching and Performance Functions (Phase 4)
# ============================================================================

# Cache for frequently accessed JSON values
declare -A JSON_CACHE=()

# Get a cached JSON value
# Arguments:
#   cache_key: Unique key for this JSON+path combination
#   json: JSON string
#   path: jq path
# Returns:
#   Cached value if available, otherwise computed value
json_get_cached() {
	local cache_key="$1"
	local json="$2"
	local path="$3"

	# Check cache first
	if [[ -v JSON_CACHE["$cache_key"] ]]; then
	echo "${JSON_CACHE["$cache_key"]}"
	return 0
	fi

	# Compute and cache
	local value
	value=$(json_get "$json" "$path")
	local exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
	JSON_CACHE["$cache_key"]="$value"
	fi

	echo "$value"
	return $exit_code
}

# Clear the JSON cache (useful for memory management)
json_clear_cache() {
	JSON_CACHE=()
}
