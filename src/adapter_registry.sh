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
# Use test directory if available, otherwise use tmp
REGISTRY_BASE_DIR="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
ADAPTER_REGISTRY_FILE="$REGISTRY_BASE_DIR/suitey_adapter_registry"
ADAPTER_REGISTRY_CAPABILITIES_FILE="$REGISTRY_BASE_DIR/suitey_adapter_capabilities"
ADAPTER_REGISTRY_ORDER_FILE="$REGISTRY_BASE_DIR/suitey_adapter_order"
ADAPTER_REGISTRY_INIT_FILE="$REGISTRY_BASE_DIR/suitey_adapter_init"

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

# Helper: Perform reload operations
_adapter_registry_perform_reload() {
	local actual_registry_file="$1"
	local actual_capabilities_file="$2"
	local actual_order_file="$3"
	local switching_locations="$4"

	# Clear arrays before loading to ensure clean state from file
	ADAPTER_REGISTRY=()
	# Only clear capabilities if we're going to load from file
	# This prevents losing in-memory state when file doesn't exist
	if [[ -f "$actual_capabilities_file" ]] || [[ "$switching_locations" == "true" ]]; then
		ADAPTER_REGISTRY_CAPABILITIES=()
	fi
	ADAPTER_REGISTRY_ORDER=()

	# Load arrays from files using return-data pattern (manual population for BATS compatibility)
	local registry_output
	registry_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY" "$actual_registry_file")
	local registry_count
	registry_count=$(echo "$registry_output" | head -n 1)
	# Manually populate registry array from output
	if [[ "$registry_count" -gt 0 ]]; then
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			[[ -z "$key" ]] && continue
			ADAPTER_REGISTRY["$key"]="$value"
		done < <(echo "$registry_output" | tail -n +2)
	fi

	local capabilities_loaded=false
	if [[ -f "$actual_capabilities_file" ]]; then
		local capabilities_output
		capabilities_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY_CAPABILITIES" "$actual_capabilities_file")
		local loaded_count
		loaded_count=$(echo "$capabilities_output" | head -n 1)
		# Manually populate capabilities array from output
		if [[ "$loaded_count" -gt 0 ]]; then
			while IFS='=' read -r key value || [[ -n "$key" ]]; do
				[[ -z "$key" ]] && continue
				ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
			done < <(echo "$capabilities_output" | tail -n +2)
		fi
		[[ "$loaded_count" -gt 0 ]] && capabilities_loaded=true
	fi

	_adapter_registry_load_order_array "$actual_order_file"
	_adapter_registry_rebuild_capabilities "$capabilities_loaded" "$switching_locations" "$actual_capabilities_file"
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
		_adapter_registry_perform_reload \
			"$actual_registry_file" \
			"$actual_capabilities_file" \
			"$actual_order_file" \
			"$switching_locations"
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
	rm -f "$ADAPTER_REGISTRY_FILE" \
		"$ADAPTER_REGISTRY_CAPABILITIES_FILE" \
		"$ADAPTER_REGISTRY_ORDER_FILE" \
		"$ADAPTER_REGISTRY_INIT_FILE"
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
	if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
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

	# Check if already initialized
	if [[ "$ADAPTER_REGISTRY_INITIALIZED" == "true" ]]; then
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

