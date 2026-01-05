# ============================================================================
# Adapter Registry
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

# Source adapter registry helper functions
if [[ -f "adapter_registry_helpers.sh" ]]; then
	source "adapter_registry_helpers.sh"
elif [[ -f "src/adapter_registry_helpers.sh" ]]; then
	source "src/adapter_registry_helpers.sh"
elif [[ -f "../src/adapter_registry_helpers.sh" ]]; then
	source "../src/adapter_registry_helpers.sh"
fi

# Registry Data Structures
declare -A ADAPTER_REGISTRY                    # Maps adapter identifier -> metadata JSON
declare -A ADAPTER_REGISTRY_CAPABILITIES       # Maps capability -> comma-separated adapter list
ADAPTER_REGISTRY_INITIALIZED=false            # Tracks whether registry has been initialized
ADAPTER_REGISTRY_ORDER=()                     # Preserves registration order

# Registry Persistence (for testing)
# These variables are computed dynamically when needed to avoid race conditions
# in parallel test execution. They should NOT be initialized at module load time
# because TEST_ADAPTER_REGISTRY_DIR may not be set yet.
REGISTRY_BASE_DIR=""
ADAPTER_REGISTRY_FILE=""
ADAPTER_REGISTRY_CAPABILITIES_FILE=""
ADAPTER_REGISTRY_ORDER_FILE=""
ADAPTER_REGISTRY_INIT_FILE=""

# ============================================================================
# Adapter Registry Functions
# ============================================================================

# Save registry state to files (for testing persistence)
adapter_registry_save_state() {
	# Determine base directory for registry files
	local actual_base_dir
	actual_base_dir=$(_adapter_registry_determine_base_dir) || return 1

	# Ensure directory exists and is writable
	_adapter_registry_ensure_directory "$actual_base_dir" || return 1

	# Set file paths based on the actual base directory
	local registry_file="$actual_base_dir/suitey_adapter_registry"
	local capabilities_file="$actual_base_dir/suitey_adapter_capabilities"
	local order_file="$actual_base_dir/suitey_adapter_order"
	local init_file="$actual_base_dir/suitey_adapter_init"

	# Always update global variables to match the actual paths we're using
	# This ensures load_state() uses the same directory as save_state()
	REGISTRY_BASE_DIR="$actual_base_dir"
	ADAPTER_REGISTRY_FILE="$registry_file"
	ADAPTER_REGISTRY_CAPABILITIES_FILE="$capabilities_file"
	ADAPTER_REGISTRY_ORDER_FILE="$order_file"
	ADAPTER_REGISTRY_INIT_FILE="$init_file"

	# Save arrays to files
	_adapter_registry_save_array_to_file "ADAPTER_REGISTRY" "$registry_file" || return 1
	_adapter_registry_save_array_to_file "ADAPTER_REGISTRY_CAPABILITIES" "$capabilities_file" || return 1
	_adapter_registry_save_order "$order_file" || return 1
	_adapter_registry_save_initialized "$init_file" || return 1
}

# Helper: Parse file paths from helper output
_adapter_registry_parse_file_paths() {
	local file_paths="$1"
	echo "$file_paths" | sed -n '1p'
	echo "$file_paths" | sed -n '2p'
	echo "$file_paths" | sed -n '3p'
	echo "$file_paths" | sed -n '4p'
}

# Helper: Load order array from file with filtering
_adapter_registry_load_order_array() {
	local order_file="$1"
	if [[ -f "$order_file" ]]; then
		mapfile -t ADAPTER_REGISTRY_ORDER < "$order_file"
		# Filter out empty lines
		ADAPTER_REGISTRY_ORDER=("${ADAPTER_REGISTRY_ORDER[@]// /}")  # Remove spaces
		ADAPTER_REGISTRY_ORDER=($(printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" | grep -v '^$'))
	fi
}

# Helper: Perform reload operations (returns data instead of populating arrays)
# Returns: registry_output, capabilities_output, order_output, capabilities_loaded flag
# Format: Line 1 = capabilities_loaded (true/false), Line 2 = switching_locations (true/false),
#         Then registry_output (count + key=value pairs), then capabilities_output, then order_output
_adapter_registry_perform_reload() {
	local actual_registry_file="$1"
	local actual_capabilities_file="$2"
	local actual_order_file="$3"
	local switching_locations="$4"

	# Load data from files using return-data pattern
	local registry_output
	registry_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY" "$actual_registry_file")
	
	local capabilities_output=""
	local capabilities_loaded=false
	if [[ -f "$actual_capabilities_file" ]]; then
		capabilities_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY_CAPABILITIES" "$actual_capabilities_file")
		local loaded_count
		loaded_count=$(echo "$capabilities_output" | head -n 1)
		[[ "$loaded_count" -gt 0 ]] && capabilities_loaded=true
	fi
	
	local order_output=""
	if [[ -f "$actual_order_file" ]]; then
		# Load order file content
		order_output=$(cat "$actual_order_file" 2>/dev/null || echo "")
	fi
	
	# Return data: capabilities_loaded flag, switching_locations flag, then outputs
	# Use a delimiter to separate sections
	echo "CAPABILITIES_LOADED:$capabilities_loaded"
	echo "SWITCHING_LOCATIONS:$switching_locations"
	echo "REGISTRY_START"
	echo -n "$registry_output"
	echo "REGISTRY_END"
	echo "CAPABILITIES_START"
	echo -n "$capabilities_output"
	echo "CAPABILITIES_END"
	echo "ORDER_START"
	echo -n "$order_output"
	echo "ORDER_END"
	return 0
}

# Load registry state from files (for testing persistence)
adapter_registry_load_state() {
	# Determine file locations and update globals
	local file_paths
	file_paths=$(_adapter_registry_determine_file_locations)
	local file_paths_array
	mapfile -t file_paths_array < <(_adapter_registry_parse_file_paths "$file_paths")
	local actual_registry_file="${file_paths_array[0]}"
	local actual_capabilities_file="${file_paths_array[1]}"
	local actual_order_file="${file_paths_array[2]}"
	local actual_init_file="${file_paths_array[3]}"

	# Check if we're switching locations BEFORE updating globals (this was done in the helper)
	local switching_locations=false
	if [[ -n "${ADAPTER_REGISTRY_FILE:-}" ]] && [[ "$actual_registry_file" != "${ADAPTER_REGISTRY_FILE:-}" ]]; then
		switching_locations=true
	fi

	# Determine if state should be reloaded
	local should_reload
	should_reload=$(_adapter_registry_should_reload \
		"$actual_registry_file" \
		"$actual_capabilities_file" \
		"$switching_locations")

	if [[ "$should_reload" == "true" ]]; then
		# Get reload data from helper
		local reload_data
		reload_data=$(_adapter_registry_perform_reload \
			"$actual_registry_file" \
			"$actual_capabilities_file" \
			"$actual_order_file" \
			"$switching_locations")
		
		# Parse reload data
		local capabilities_loaded
		capabilities_loaded=$(echo "$reload_data" | grep "^CAPABILITIES_LOADED:" | cut -d: -f2)
		local switching
		switching=$(echo "$reload_data" | grep "^SWITCHING_LOCATIONS:" | cut -d: -f2)
		
		# Extract registry output (between REGISTRY_START and REGISTRY_END)
		local registry_output
		registry_output=$(echo "$reload_data" | sed -n '/^REGISTRY_START$/,/^REGISTRY_END$/p' | sed -e '1d' -e '$d')
		
		# Extract capabilities output (between CAPABILITIES_START and CAPABILITIES_END)
		local capabilities_output
		capabilities_output=$(echo "$reload_data" | sed -n '/^CAPABILITIES_START$/,/^CAPABILITIES_END$/p' | sed -e '1d' -e '$d')
		
		# Extract order output (between ORDER_START and ORDER_END)
		local order_output
		order_output=$(echo "$reload_data" | sed -n '/^ORDER_START$/,/^ORDER_END$/p' | sed -e '1d' -e '$d')
		
		# Ensure arrays are declared as global before populating (BATS compatibility)
		# Unset first to ensure clean state
		eval "unset ADAPTER_REGISTRY 2>/dev/null || true"
		# Declare as associative array (global scope)
		declare -g -A ADAPTER_REGISTRY
		# Clear the array (this preserves the associative type)
		ADAPTER_REGISTRY=()
		
		# Always ensure ADAPTER_REGISTRY_CAPABILITIES is declared (BATS compatibility)
			eval "unset ADAPTER_REGISTRY_CAPABILITIES 2>/dev/null || true"
			eval "declare -g -A ADAPTER_REGISTRY_CAPABILITIES"
			ADAPTER_REGISTRY_CAPABILITIES=()
		
		eval "unset ADAPTER_REGISTRY_ORDER 2>/dev/null || true"
		eval "declare -g -a ADAPTER_REGISTRY_ORDER"
		ADAPTER_REGISTRY_ORDER=()
		
		# Populate registry array from output
		local registry_count
		registry_count=$(echo "$registry_output" | head -n 1)
		# Validate that registry_count is a valid number
		if [[ "$registry_count" =~ ^[0-9]+$ ]] && [[ "$registry_count" -gt 0 ]]; then
			while IFS='=' read -r key value || [[ -n "$key" ]]; do
				[[ -z "$key" ]] && continue
				# Skip if key looks like a delimiter or is invalid
				[[ "$key" == "REGISTRY_START" ]] && continue
				[[ "$key" == "REGISTRY_END" ]] && continue
				[[ "$key" == "CAPABILITIES_START" ]] && continue
				[[ "$key" == "CAPABILITIES_END" ]] && continue
				[[ "$key" == "ORDER_START" ]] && continue
				[[ "$key" == "ORDER_END" ]] && continue
				# Skip if key is purely numeric (likely a count line that wasn't filtered)
				[[ "$key" =~ ^[0-9]+$ ]] && continue
				
				# Clean the value - remove any trailing delimiter strings that might have been included
				value="${value%%CAPABILITIES_END*}"
				value="${value%%REGISTRY_END*}"
				value="${value%%ORDER_END*}"
				# Trim trailing whitespace
				value="${value%"${value##*[![:space:]]}"}"
				
				ADAPTER_REGISTRY["$key"]="$value"
			done < <(echo "$registry_output" | tail -n +2)
		fi

		# Populate capabilities array from output
		if [[ -n "$capabilities_output" ]]; then
			local loaded_count
			loaded_count=$(echo "$capabilities_output" | head -n 1)
			if [[ "$loaded_count" =~ ^[0-9]+$ ]] && [[ "$loaded_count" -gt 0 ]]; then
				while IFS='=' read -r key value || [[ -n "$key" ]]; do
					[[ -z "$key" ]] && continue
					# Skip if key looks like a delimiter or is invalid
					[[ "$key" == "REGISTRY_START" ]] && continue
					[[ "$key" == "REGISTRY_END" ]] && continue
					[[ "$key" == "CAPABILITIES_START" ]] && continue
					[[ "$key" == "CAPABILITIES_END" ]] && continue
					[[ "$key" == "ORDER_START" ]] && continue
					[[ "$key" == "ORDER_END" ]] && continue
					# Skip if key is purely numeric (likely a count line that wasn't filtered)
					[[ "$key" =~ ^[0-9]+$ ]] && continue
					
					# Clean the value - remove any trailing delimiter strings that might have been included
					value="${value%%CAPABILITIES_END*}"
					value="${value%%REGISTRY_END*}"
					value="${value%%ORDER_END*}"
					# Trim trailing whitespace
					value="${value%"${value##*[![:space:]]}"}"
					
					ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
				done < <(echo "$capabilities_output" | tail -n +2)
			fi
		fi
		
		# Populate order array from output
		if [[ -n "$order_output" ]]; then
			# Filter out empty lines and delimiter strings
			local filtered_array=()
			local element
			while IFS= read -r element || [[ -n "$element" ]]; do
				# Trim leading/trailing spaces
				local trimmed="${element#"${element%%[![:space:]]*}"}"
				trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
				# Skip empty lines and delimiter strings
				[[ -z "$trimmed" ]] && continue
				[[ "$trimmed" == "REGISTRY_START" ]] && continue
				[[ "$trimmed" == "REGISTRY_END" ]] && continue
				[[ "$trimmed" == "CAPABILITIES_START" ]] && continue
				[[ "$trimmed" == "CAPABILITIES_END" ]] && continue
				[[ "$trimmed" == "ORDER_START" ]] && continue
				[[ "$trimmed" == "ORDER_END" ]] && continue
				filtered_array+=("$trimmed")
			done < <(echo "$order_output")
			ADAPTER_REGISTRY_ORDER=("${filtered_array[@]}")
		fi
		
		_adapter_registry_rebuild_capabilities "$capabilities_loaded" "$switching" "$actual_capabilities_file"
		
		# Ensure ADAPTER_REGISTRY_FILE is set for duplicate detection
		ADAPTER_REGISTRY_FILE="$actual_registry_file"
	fi
	
	# Always ensure ADAPTER_REGISTRY_FILE is set (even if we didn't reload)
	if [[ -z "${ADAPTER_REGISTRY_FILE:-}" ]]; then
		ADAPTER_REGISTRY_FILE="$actual_registry_file"
	fi

	# Always ensure ADAPTER_REGISTRY_ORDER is declared (BATS compatibility)
	# This is necessary because in subshell contexts, arrays don't persist
	if ! declare -p ADAPTER_REGISTRY_ORDER 2>/dev/null | grep -q '\-a'; then
		eval "unset ADAPTER_REGISTRY_ORDER 2>/dev/null || true"
		declare -g -a ADAPTER_REGISTRY_ORDER
		ADAPTER_REGISTRY_ORDER=()
	fi

	# Always load order array if file exists (using return-data pattern)
	# This ensures it works in subshell contexts where arrays don't persist
	# and ensures order is loaded even if should_reload was false or reload didn't populate it correctly
	# We always reload from file to ensure we have the latest state
	if [[ -f "$actual_order_file" ]]; then
		local order_data
		order_data=$(_adapter_registry_load_order_from_file "$actual_order_file")
		local order_count
		order_count=$(echo "$order_data" | head -n 1)
		
		if [[ "$order_count" =~ ^[0-9]+$ ]] && [[ "$order_count" -gt 0 ]]; then
			# Populate array from returned data (always reload to ensure latest state)
			mapfile -t ADAPTER_REGISTRY_ORDER < <(echo "$order_data" | tail -n +2)
		fi
	fi

	# Always ensure ADAPTER_REGISTRY_CAPABILITIES is declared (BATS compatibility)
	# This is necessary because in subshell contexts, arrays don't persist
	if ! declare -p ADAPTER_REGISTRY_CAPABILITIES 2>/dev/null | grep -q '\-A'; then
		eval "unset ADAPTER_REGISTRY_CAPABILITIES 2>/dev/null || true"
		declare -g -A ADAPTER_REGISTRY_CAPABILITIES
		ADAPTER_REGISTRY_CAPABILITIES=()
	fi

	# Always load capabilities array if file exists (using return-data pattern)
	# This ensures it works in subshell contexts where arrays don't persist
	# and ensures capabilities are loaded even if should_reload was false or reload didn't populate it correctly
	# We always reload from file to ensure we have the latest state
	# Only load if array is empty or if we didn't reload (to avoid overwriting in-memory state unnecessarily)
	if [[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]] && [[ -f "$actual_capabilities_file" ]]; then
		local capabilities_data
		capabilities_data=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY_CAPABILITIES" "$actual_capabilities_file")
		local capabilities_count
		capabilities_count=$(echo "$capabilities_data" | head -n 1)
		
		if [[ "$capabilities_count" =~ ^[0-9]+$ ]] && [[ "$capabilities_count" -gt 0 ]]; then
			# Populate array from returned data (always reload to ensure latest state)
			while IFS='=' read -r key value || [[ -n "$key" ]]; do
				[[ -z "$key" ]] && continue
				# Skip if key looks like a delimiter or is invalid
				[[ "$key" == "REGISTRY_START" ]] && continue
				[[ "$key" == "REGISTRY_END" ]] && continue
				[[ "$key" == "CAPABILITIES_START" ]] && continue
				[[ "$key" == "CAPABILITIES_END" ]] && continue
				[[ "$key" == "ORDER_START" ]] && continue
				[[ "$key" == "ORDER_END" ]] && continue
				# Skip if key is purely numeric (likely a count line that wasn't filtered)
				[[ "$key" =~ ^[0-9]+$ ]] && continue
				
				# Clean the value - remove any trailing delimiter strings that might have been included
				value="${value%%CAPABILITIES_END*}"
				value="${value%%REGISTRY_END*}"
				value="${value%%ORDER_END*}"
				# Trim trailing whitespace
				value="${value%"${value##*[![:space:]]}"}"
				
				ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
			done < <(echo "$capabilities_data" | tail -n +2)
		fi
	fi

	# Always try to load ADAPTER_REGISTRY_INITIALIZED if file exists
	if [[ -f "$actual_init_file" ]]; then
		ADAPTER_REGISTRY_INITIALIZED=$(<"$actual_init_file")
	else
		ADAPTER_REGISTRY_INITIALIZED=false
	fi
}

# Clean up registry state files
adapter_registry_cleanup_state() {
	# Compute file paths dynamically to avoid using stale values from module load time
	local file_paths
	file_paths=$(_adapter_registry_determine_file_locations)
	local file_paths_array
	mapfile -t file_paths_array < <(_adapter_registry_parse_file_paths "$file_paths")
	local registry_file="${file_paths_array[0]}"
	local capabilities_file="${file_paths_array[1]}"
	local order_file="${file_paths_array[2]}"
	local init_file="${file_paths_array[3]}"
	
	rm -f "$registry_file" \
		"$capabilities_file" \
		"$order_file" \
		"$init_file"
}

# Initialize/load registry state
# Validate that an adapter implements the required interface
# Arguments:
#   adapter_identifier: The identifier of the adapter to validate
# Returns:
#   0 if valid, 1 if invalid (with error message to stderr)
adapter_registry_validate_interface() {
	adapter_registry_load_state
	local adapter_identifier="$1"

	# List of required interface methods
	local required_methods=(
	"${adapter_identifier}_adapter_detect"
	"${adapter_identifier}_adapter_get_metadata"
	"${adapter_identifier}_adapter_check_binaries"
	"${adapter_identifier}_adapter_discover_test_suites"
	"${adapter_identifier}_adapter_detect_build_requirements"
	"${adapter_identifier}_adapter_get_build_steps"
	"${adapter_identifier}_adapter_execute_test_suite"
	"${adapter_identifier}_adapter_parse_test_results"
	)

	# Check that each required method exists
	for method in "${required_methods[@]}"; do
	if ! command -v "$method" >/dev/null 2>&1; then
	# documented: Required adapter interface method missing
	echo "ERROR: Adapter '$adapter_identifier' is missing required interface method: $method" >&2
	return 1
	fi
	done

	return 0
}

# Extract metadata from an adapter
# Arguments:
#   adapter_identifier: The identifier of the adapter
# Returns:
#   JSON metadata string, or empty string on error
adapter_registry_extract_metadata() {
	local adapter_identifier="$1"
	local metadata_func="${adapter_identifier}_adapter_get_metadata"

	# Call the adapter's metadata function and capture output
	# The function should output JSON metadata to stdout
	# For adapter registration, we call without project_root (general adapter info)
	local metadata_output
	metadata_output=$("$metadata_func" 2>&1)
	local exit_code=$?

	if [[ $exit_code -eq 0 ]] && [[ -n "$metadata_output" ]]; then
	# Function succeeded and produced output, trim trailing newlines
	metadata_output=$(echo -n "$metadata_output" | sed 's/[[:space:]]*$//')
	echo "$metadata_output"
	return 0
	else
	# documented: Adapter metadata function failed or returned empty result
	echo "ERROR: Failed to extract metadata from adapter '$adapter_identifier'" >&2
	if [[ -n "$metadata_output" ]]; then
	echo "$metadata_output" >&2
	fi
	return 1
	fi
}

# Validate adapter metadata structure
# Arguments:
#   adapter_identifier: The identifier of the adapter
#   metadata_json: The JSON metadata string to validate
# Returns:
#   0 if valid, 1 if invalid (with error message to stderr)
adapter_registry_validate_metadata() {
	local adapter_identifier="$1"
	local metadata_json="$2"


	# Required fields that must be present in metadata
	local required_fields=(
		"name" "identifier" "version" "supported_languages"
		"capabilities" "required_binaries" "configuration_files"
	)

	# Check that each required field is present
	for field in "${required_fields[@]}"; do
	if ! json_has_field "$metadata_json" "$field"; then
	# documented: Required metadata field missing
	echo "ERROR: Adapter '$adapter_identifier' metadata is missing required field: $field" >&2
	return 1
	fi
	done

	# Check that identifier matches adapter identifier
	local actual_identifier
	actual_identifier=$(json_get "$metadata_json" ".identifier")
	if [[ "$actual_identifier" != "$adapter_identifier" ]]; then
	# documented: Adapter identifier mismatch in metadata
	echo "ERROR: Adapter '$adapter_identifier' metadata identifier does not match adapter identifier" >&2
	return 1
	fi

	return 0
}

# Index adapter capabilities for efficient lookup
# Arguments:
#   adapter_identifier: The identifier of the adapter
#   metadata_json: The JSON metadata containing capabilities
adapter_registry_index_capabilities() {
	local adapter_identifier="$1"
	local metadata_json="$2"

	# Extract capabilities from metadata JSON
	local capabilities
	capabilities=$(json_get_array "$metadata_json" ".capabilities")

	if [[ -n "$capabilities" ]]; then
	# Split capabilities by newline and index each capability
	while IFS= read -r cap; do
	if [[ -n "$cap" ]]; then
	# Add adapter to capability index
	if [[ ! -v ADAPTER_REGISTRY_CAPABILITIES["$cap"] ]]; then
	ADAPTER_REGISTRY_CAPABILITIES["$cap"]="$adapter_identifier"
	else
	ADAPTER_REGISTRY_CAPABILITIES["$cap"]="${ADAPTER_REGISTRY_CAPABILITIES["$cap"]},$adapter_identifier"
	fi
	fi
	done <<< "$capabilities"
	fi
}

# Register an adapter in the registry
# Arguments:
#   adapter_identifier: The identifier of the adapter to register
# Returns:
#   0 on success, 1 on error (with error message to stderr)
adapter_registry_register() {
	local adapter_identifier="$1"

	# Load existing state
	adapter_registry_load_state

	# Validate input
	if [[ -z "$adapter_identifier" ]]; then
	echo "ERROR: Cannot register adapter with null or empty identifier" >&2  # documented: Adapter identifier is required
	return 1
	fi

	# Check for identifier conflict
	# Check both in-memory array and file directly (for BATS compatibility)
	# In BATS subshells, arrays may not persist, so always check file (most reliable)
	local identifier_exists=false
	
	# Determine the registry file path - prioritize TEST_ADAPTER_REGISTRY_DIR for reliability in tests
	local actual_registry_file=""
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
		# Use TEST_ADAPTER_REGISTRY_DIR directly (most reliable in BATS tests)
		actual_registry_file="${TEST_ADAPTER_REGISTRY_DIR}/suitey_adapter_registry"
	elif [[ -n "${ADAPTER_REGISTRY_FILE:-}" ]]; then
		# Use ADAPTER_REGISTRY_FILE if set (from load_state)
		actual_registry_file="${ADAPTER_REGISTRY_FILE}"
	else
		# Fallback: determine file locations
		local file_paths
		file_paths=$(_adapter_registry_determine_file_locations)
		local file_paths_array
		mapfile -t file_paths_array < <(_adapter_registry_parse_file_paths "$file_paths")
		actual_registry_file="${file_paths_array[0]}"
	fi
	
	# Check file first (most reliable in BATS subshells)
	if [[ -n "$actual_registry_file" ]] && [[ -f "$actual_registry_file" ]]; then
			# Check if identifier exists in file (key is before first '=')
		# Use grep with -E for regex to properly anchor to start of line
		# Escape the identifier to avoid regex special characters
		local escaped_identifier
		escaped_identifier=$(printf '%s\n' "$adapter_identifier" | sed 's/[[\.*^$()+?{|]/\\&/g')
		if grep -Eq "^${escaped_identifier}=" "$actual_registry_file" 2>/dev/null; then
				identifier_exists=true
			fi
		fi
	
	# Also check in-memory array (in case file check didn't find it but array has it)
	if [[ "$identifier_exists" != "true" ]] && [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
		identifier_exists=true
	fi
	
	if [[ "$identifier_exists" == "true" ]]; then
		# documented: Duplicate adapter identifier
		echo "ERROR: Adapter identifier '$adapter_identifier' is already registered" >&2
		return 1
	fi

	# Validate interface
	if ! adapter_registry_validate_interface "$adapter_identifier"; then
	return 1  # documented: Interface validation failed - missing required functions
	fi

	# Extract and validate metadata
	local metadata_json
	metadata_json=$(adapter_registry_extract_metadata "$adapter_identifier")
	if [[ $? -ne 0 ]] || [[ -z "$metadata_json" ]]; then
	return 1  # documented: Metadata extraction failed - adapter function error
	fi

	if ! adapter_registry_validate_metadata "$adapter_identifier" "$metadata_json"; then
	return 1  # documented: Metadata validation failed - invalid adapter metadata
	fi

	# Store adapter metadata
	# Ensure ADAPTER_REGISTRY is declared as associative array (BATS compatibility)
	# This is necessary because load_state might have cleared it, and in some contexts
	# the array type might not be preserved
	if ! declare -p ADAPTER_REGISTRY 2>/dev/null | grep -q '\-A'; then
		# Array is not associative or doesn't exist, declare it
		eval "unset ADAPTER_REGISTRY 2>/dev/null || true"
		declare -g -A ADAPTER_REGISTRY
	fi
	
	ADAPTER_REGISTRY["$adapter_identifier"]="$metadata_json"

	# Index capabilities
	adapter_registry_index_capabilities "$adapter_identifier" "$metadata_json"

	# Add to order array
	ADAPTER_REGISTRY_ORDER+=("$adapter_identifier")

	# Save state
	adapter_registry_save_state

	return 0
}

# Get adapter metadata by identifier
# Arguments:
#   adapter_identifier: The identifier of the adapter to retrieve
# Returns:
#   JSON metadata string, or "null" if not found
adapter_registry_get() {
	local adapter_identifier="$1"
	adapter_registry_load_state

	if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
	echo "${ADAPTER_REGISTRY["$adapter_identifier"]}"
	else
	echo "null"
	fi
}

# Get all registered adapter identifiers
# Returns:
#   JSON array of adapter identifiers
adapter_registry_get_all() {
	adapter_registry_load_state

	local identifiers=()

	# Return identifiers in registration order
	for identifier in "${ADAPTER_REGISTRY_ORDER[@]}"; do
	identifiers+=("\"$identifier\"")
	done

	# Join with commas
	local joined
	joined=$(IFS=','; echo "${identifiers[*]}")

	echo "[$joined]"
}

# Get adapters by capability
# Arguments:
#   capability: The capability to search for
# Returns:
#   JSON array of adapter identifiers with the capability
adapter_registry_get_adapters_by_capability() {
	adapter_registry_load_state

	local capability="$1"

	if [[ -v ADAPTER_REGISTRY_CAPABILITIES["$capability"] ]]; then
	# Split comma-separated list and format as JSON array
	local adapters="${ADAPTER_REGISTRY_CAPABILITIES["$capability"]}"
	local identifiers=()

	IFS=',' read -ra adapter_array <<< "$adapters"
	for adapter in "${adapter_array[@]}"; do
	identifiers+=("\"$adapter\"")
	done

	local joined
	joined=$(IFS=','; echo "${identifiers[*]}")

	echo "[$joined]"
	else
	echo "[]"
	fi
}

# Check if an adapter is registered
# Arguments:
#   adapter_identifier: The identifier to check
# Returns:
#   "true" if registered, "false" otherwise
adapter_registry_is_registered() {
	adapter_registry_load_state

	if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
	echo "true"
	else
	echo "false"
	fi
}

# Initialize the adapter registry
# Registers built-in adapters (BATS and Rust)
# Returns:
#   0 on success, 1 on error (with error message to stderr)
adapter_registry_initialize() {
	adapter_registry_load_state

	# Determine the actual init file path for THIS test's directory
	# This ensures each test checks its own initialization state, not a shared global
	local file_paths
	file_paths=$(_adapter_registry_determine_file_locations)
	local file_paths_array
	mapfile -t file_paths_array < <(_adapter_registry_parse_file_paths "$file_paths")
	local actual_init_file="${file_paths_array[3]}"

	# Check initialization status from THIS test's file, not global variable
	# This prevents parallel tests from seeing each other's initialization state
	local is_initialized=false
	if [[ -f "$actual_init_file" ]]; then
		local init_status
		init_status=$(<"$actual_init_file" 2>/dev/null || echo "false")
		[[ "$init_status" == "true" ]] && is_initialized=true
	fi

	# Also check if adapters are already registered (defensive check)
	# This handles the case where adapters were registered but init file wasn't written
	if [[ "$is_initialized" != "true" ]]; then
		local adapters_registered=0
		for adapter in "bats" "rust"; do
			if [[ -v ADAPTER_REGISTRY["$adapter"] ]]; then
				adapters_registered=$((adapters_registered + 1))
			fi
		done
		# If both adapters are registered, consider it initialized
		if [[ $adapters_registered -eq 2 ]]; then
			is_initialized=true
		fi
	fi

	if [[ "$is_initialized" == "true" ]]; then
		# Update global variable to match file state (for consistency)
		ADAPTER_REGISTRY_INITIALIZED=true
	return 0
	fi

	# Register built-in adapters (only if not already registered)
	local builtin_adapters=("bats" "rust")

	for adapter in "${builtin_adapters[@]}"; do
	# Check if adapter is already registered before trying to register
	if [[ -v ADAPTER_REGISTRY["$adapter"] ]]; then
	continue  # Skip if already registered
	fi
	if ! adapter_registry_register "$adapter"; then
	echo "ERROR: Failed to register built-in adapter '$adapter'" >&2  # documented: Built-in adapter registration failed
	# Continue with other adapters but return error
	return 1
	fi
	done

	# Write initialization status to THIS test's init file
	# This ensures each test has its own initialization state
	ADAPTER_REGISTRY_INITIALIZED=true
	adapter_registry_save_state
	return 0
}

# Clean up the adapter registry
# Clears all registered adapters and resets state
# Returns:
#   0 on success
adapter_registry_cleanup() {
	# Clear all registry data
	ADAPTER_REGISTRY=()
	ADAPTER_REGISTRY_CAPABILITIES=()
	ADAPTER_REGISTRY_ORDER=()
	ADAPTER_REGISTRY_INITIALIZED=false

	# Clean up state files
	adapter_registry_cleanup_state

	return 0
}

