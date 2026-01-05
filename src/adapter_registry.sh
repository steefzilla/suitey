# ============================================================================
# Adapter Registry
# ============================================================================

# Source JSON helper functions
if [[ -f "json_helpers.sh" ]]; then
	source "json_helpers.sh"
elif [[ -f "src/json_helpers.sh" ]]; then
	source "src/json_helpers.sh"
elif [[ -f "../src/json_helpers.sh" ]]; then
	source "../src/json_helpers.sh"
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
	# Use existing global variables if set, otherwise re-evaluate based on TEST_ADAPTER_REGISTRY_DIR
	local registry_base_dir
	local registry_file
	local capabilities_file
	local order_file
	local init_file

	# Determine the base directory - prioritize TEST_ADAPTER_REGISTRY_DIR if set
	local actual_base_dir
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
	# TEST_ADAPTER_REGISTRY_DIR takes precedence for test consistency
	actual_base_dir="$TEST_ADAPTER_REGISTRY_DIR"
	elif [[ -n "${REGISTRY_BASE_DIR:-}" ]] && [[ -d "${REGISTRY_BASE_DIR:-}" ]]; then
	# Use existing REGISTRY_BASE_DIR if it's a valid directory
	actual_base_dir="$REGISTRY_BASE_DIR"
	else
	# Fall back to TMPDIR
	actual_base_dir="${TMPDIR:-/tmp}"
	fi

	# Ensure directory exists - create it if it doesn't exist
	if ! mkdir -p "$actual_base_dir" 2>&1; then
		echo "ERROR: Failed to create registry directory: $actual_base_dir" >&2  # documented: Directory creation failed
		return 1
	fi

	# Set file paths based on the actual base directory
	registry_file="$actual_base_dir/suitey_adapter_registry"
	capabilities_file="$actual_base_dir/suitey_adapter_capabilities"
	order_file="$actual_base_dir/suitey_adapter_order"
	init_file="$actual_base_dir/suitey_adapter_init"

	# Always update global variables to match the actual paths we're using
	# This ensures load_state() uses the same directory as save_state()
	REGISTRY_BASE_DIR="$actual_base_dir"
	ADAPTER_REGISTRY_FILE="$registry_file"
	ADAPTER_REGISTRY_CAPABILITIES_FILE="$capabilities_file"
	ADAPTER_REGISTRY_ORDER_FILE="$order_file"
	ADAPTER_REGISTRY_INIT_FILE="$init_file"

	# Save ADAPTER_REGISTRY - verify directory exists and is writable
	if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
	if ! mkdir -p "$actual_base_dir" 2>&1; then
	echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2  # documented: Registry directory not accessible
	return 1
	fi
	fi

	# Create/truncate file with error checking using touch + verify
	if ! touch "$registry_file" 2>&1 || [[ ! -f "$registry_file" ]]; then
	echo "ERROR: Failed to create registry file: $registry_file" >&2  # documented: File creation failed
	return 1
	fi
	# Truncate it
	> "$registry_file"

	for key in "${!ADAPTER_REGISTRY[@]}"; do
	# Base64 encode: try -w 0 (GNU) first, fall back to -b 0 (macOS) or no flag with tr
	encoded_value=""
	if encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 -w 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
	: # Success with -w 0
	elif encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 -b 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
	: # Success with -b 0
	elif encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 | tr -d '\n') && [[ -n "$encoded_value" ]]; then
	: # Success with base64 + tr
	fi

	# Validate we got a non-empty encoded value
	if [[ -z "$encoded_value" ]]; then
	echo "ERROR: Failed to encode value for key '$key'" >&2  # documented: Base64 encoding failed
	return 1
	fi

	echo "$key=$encoded_value" >> "$registry_file"
	done

	# Save ADAPTER_REGISTRY_CAPABILITIES - directory already exists, just verify
	if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
	if ! mkdir -p "$actual_base_dir" 2>&1; then
	echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2  # documented: Registry directory not accessible
	return 1
	fi
	fi

	# Create/truncate file with error checking using touch + verify
	if ! touch "$capabilities_file" 2>&1 || [[ ! -f "$capabilities_file" ]]; then
	echo "ERROR: Failed to create capabilities file: $capabilities_file" >&2  # documented: Capabilities file creation failed
	return 1
	fi
	# Truncate it
	> "$capabilities_file"

	for key in "${!ADAPTER_REGISTRY_CAPABILITIES[@]}"; do
	# Base64 encode: try -w 0 (GNU) first, fall back to -b 0 (macOS) or no flag with tr
	encoded_value=""
	if encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 -w 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
	: # Success with -w 0
	elif encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 -b 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
	: # Success with -b 0
	elif encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 | tr -d '\n') && [[ -n "$encoded_value" ]]; then
	: # Success with base64 + tr
	fi

	# Validate we got a non-empty encoded value
	if [[ -z "$encoded_value" ]]; then
	echo "ERROR: Failed to encode value for key '$key'" >&2
	return 1
	fi

	echo "$key=$encoded_value" >> "$capabilities_file"
	done

	# Save ADAPTER_REGISTRY_ORDER - directory already exists, just verify
	if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
	if ! mkdir -p "$actual_base_dir" 2>&1; then
	echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2  # documented: Registry directory not accessible
	return 1
	fi
	fi

	if ! printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$order_file" 2>&1; then
	echo "ERROR: Failed to write order file: $order_file" >&2  # documented: Order file write failed
	return 1
	fi

	# Save ADAPTER_REGISTRY_INITIALIZED - directory already exists, just verify
	if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
	if ! mkdir -p "$actual_base_dir" 2>&1; then
	echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2  # documented: Registry directory not accessible
	return 1
	fi
	fi

	if ! echo "$ADAPTER_REGISTRY_INITIALIZED" > "$init_file" 2>&1; then
	echo "ERROR: Failed to write init file: $init_file" >&2
	return 1
	fi
}

# Load registry state from files (for testing persistence)
adapter_registry_load_state() {
	# If TEST_ADAPTER_REGISTRY_DIR is set, always use it (for test consistency)
	local registry_base_dir
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
	registry_base_dir="$TEST_ADAPTER_REGISTRY_DIR"
	else
	# Re-evaluate REGISTRY_BASE_DIR to use current TEST_ADAPTER_REGISTRY_DIR value
	registry_base_dir="${TMPDIR:-/tmp}"
	fi

	local registry_file="$registry_base_dir/suitey_adapter_registry"
	local capabilities_file="$registry_base_dir/suitey_adapter_capabilities"
	local order_file="$registry_base_dir/suitey_adapter_order"
	local init_file="$registry_base_dir/suitey_adapter_init"

	# Ensure directory exists before trying to read files
	mkdir -p "$registry_base_dir"

	# Check if we're switching locations BEFORE updating globals
	# This determines if we need to reload state from a different file location
	local switching_locations=false
	if [[ -n "${ADAPTER_REGISTRY_FILE:-}" ]] && [[ "$registry_file" != "${ADAPTER_REGISTRY_FILE:-}" ]]; then
	switching_locations=true
	fi

	# Always update global variables when TEST_ADAPTER_REGISTRY_DIR is set,
	# or if registry file exists in the new location, or if globals haven't been set yet
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] || [[ -f "$registry_file" ]] || [[ ! -f "${ADAPTER_REGISTRY_FILE:-/nonexistent}" ]]; then
	REGISTRY_BASE_DIR="$registry_base_dir"
	ADAPTER_REGISTRY_FILE="$registry_file"
	ADAPTER_REGISTRY_CAPABILITIES_FILE="$capabilities_file"
	ADAPTER_REGISTRY_ORDER_FILE="$order_file"
	ADAPTER_REGISTRY_INIT_FILE="$init_file"
	fi

	# Use the global variables (which now point to the correct location)
	local actual_registry_file="${ADAPTER_REGISTRY_FILE:-$registry_file}"
	local actual_capabilities_file="${ADAPTER_REGISTRY_CAPABILITIES_FILE:-$capabilities_file}"
	local actual_order_file="${ADAPTER_REGISTRY_ORDER_FILE:-$order_file}"
	local actual_init_file="${ADAPTER_REGISTRY_INIT_FILE:-$init_file}"

	# Reload if the registry file exists (to load latest state from disk),
	# or if we're switching to a different file location
	local should_reload=false
	if [[ -f "$actual_registry_file" ]]; then
	# File exists - reload to get latest state
	should_reload=true
	elif [[ "$switching_locations" == "true" ]]; then
	# Switching locations - clear to start fresh
	should_reload=true
	fi

	if [[ "$should_reload" == "true" ]]; then
	# Clear arrays before loading to ensure clean state from file
	ADAPTER_REGISTRY=()
	# Only clear capabilities if we're going to load from file
	# This prevents losing in-memory state when file doesn't exist
	if [[ -f "$actual_capabilities_file" ]] || [[ "$switching_locations" == "true" ]]; then
	ADAPTER_REGISTRY_CAPABILITIES=()
	fi
	ADAPTER_REGISTRY_ORDER=()

	# Load ADAPTER_REGISTRY
	if [[ -f "$actual_registry_file" ]]; then
	while IFS= read -r line || [[ -n "$line" ]]; do
	# Skip empty lines
	[[ -z "$line" ]] && continue

	# Split on first '=' only (since base64 can contain '=')
	key="${line%%=*}"
	encoded_value="${line#*=}"

	# Skip malformed entries
	if [[ -n "$key" ]] && [[ -n "$encoded_value" ]]; then
	decoded_value=""
	# Try different base64 decoding variants
	if decoded_value=$(echo -n "$encoded_value" | base64 -d 2>/dev/null) && [[ -n "$decoded_value" ]]; then
	: # Success with base64 -d
	elif decoded_value=$(echo -n "$encoded_value" | base64 --decode 2>/dev/null) && [[ -n "$decoded_value" ]]; then
	: # Success with base64 --decode
	fi

	if [[ -n "$decoded_value" ]]; then
	ADAPTER_REGISTRY["$key"]="$decoded_value"
	else
	echo "WARNING: Failed to decode base64 value for key '$key', skipping entry" >&2  # documented: Base64 decode failed, skipping corrupted registry entry
	fi
	fi
	done < "$actual_registry_file"
	fi

	# Load ADAPTER_REGISTRY_CAPABILITIES
	local capabilities_loaded=false
	if [[ -f "$actual_capabilities_file" ]]; then
	while IFS= read -r line || [[ -n "$line" ]]; do
	# Skip empty lines
	[[ -z "$line" ]] && continue

	# Split on first '=' only (since base64 can contain '=')
	key="${line%%=*}"
	encoded_value="${line#*=}"

	# Skip malformed entries
	if [[ -n "$key" ]] && [[ -n "$encoded_value" ]]; then
	decoded_value=""
	# Try different base64 decoding variants
	if decoded_value=$(echo -n "$encoded_value" | base64 -d 2>/dev/null) && [[ -n "$decoded_value" ]]; then
	: # Success with base64 -d
	elif decoded_value=$(echo -n "$encoded_value" | base64 --decode 2>/dev/null) && [[ -n "$decoded_value" ]]; then
	: # Success with base64 --decode
	fi

	if [[ -n "$decoded_value" ]]; then
	ADAPTER_REGISTRY_CAPABILITIES["$key"]="$decoded_value"
	capabilities_loaded=true
	else
	echo "WARNING: Failed to decode base64 value for key '$key', skipping entry" >&2  # documented: Base64 decode failed, skipping corrupted registry entry
	fi
	fi
	done < "$actual_capabilities_file"
	fi

	# Load ADAPTER_REGISTRY_ORDER
	if [[ -f "$actual_order_file" ]]; then
	mapfile -t ADAPTER_REGISTRY_ORDER < "$actual_order_file"
	# Filter out empty lines
	ADAPTER_REGISTRY_ORDER=("${ADAPTER_REGISTRY_ORDER[@]// /}")  # Remove spaces
	ADAPTER_REGISTRY_ORDER=($(printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" | grep -v '^$'))
	fi

	# Rebuild capabilities index from loaded adapters only if:
	# 1. Capabilities file doesn't exist or is empty (capabilities_loaded is false)
	# 2. We're switching locations (need to rebuild from scratch)
	# 3. The capabilities file exists but is empty
	# This prevents unnecessary rebuilds on every load_state() call, but ensures
	# consistency when files are missing or when switching locations
	if [[ ${#ADAPTER_REGISTRY[@]} -gt 0 ]]; then
	local should_rebuild_capabilities=false

	if [[ "$capabilities_loaded" == "false" ]]; then
	# No capabilities file or file is empty - rebuild from adapters
	should_rebuild_capabilities=true
	elif [[ "$switching_locations" == "true" ]]; then
	# Switching locations - rebuild to ensure consistency
	should_rebuild_capabilities=true
	elif [[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]] && [[ -f "$actual_capabilities_file" ]]; then
	# Capabilities file exists but is empty - rebuild
	should_rebuild_capabilities=true
	fi

	if [[ "$should_rebuild_capabilities" == "true" ]]; then
	# Clear and rebuild from scratch
	ADAPTER_REGISTRY_CAPABILITIES=()
	for adapter_id in "${ADAPTER_REGISTRY_ORDER[@]}"; do
	if [[ -v ADAPTER_REGISTRY["$adapter_id"] ]]; then
	adapter_registry_index_capabilities "$adapter_id" "${ADAPTER_REGISTRY["$adapter_id"]}"
	fi
	done
	fi
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
	rm -f "$ADAPTER_REGISTRY_FILE" "$ADAPTER_REGISTRY_CAPABILITIES_FILE" "$ADAPTER_REGISTRY_ORDER_FILE" "$ADAPTER_REGISTRY_INIT_FILE"
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
	echo "ERROR: Adapter '$adapter_identifier' is missing required interface method: $method" >&2  # documented: Required adapter interface method missing
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
	echo "ERROR: Failed to extract metadata from adapter '$adapter_identifier'" >&2  # documented: Adapter metadata function failed or returned empty result
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
	local required_fields=("name" "identifier" "version" "supported_languages" "capabilities" "required_binaries" "configuration_files")

	# Check that each required field is present
	for field in "${required_fields[@]}"; do
	if ! json_has_field "$metadata_json" "$field"; then
	echo "ERROR: Adapter '$adapter_identifier' metadata is missing required field: $field" >&2  # documented: Required metadata field missing
	return 1
	fi
	done

	# Check that identifier matches adapter identifier
	local actual_identifier
	actual_identifier=$(json_get "$metadata_json" ".identifier")
	if [[ "$actual_identifier" != "$adapter_identifier" ]]; then
	echo "ERROR: Adapter '$adapter_identifier' metadata identifier does not match adapter identifier" >&2  # documented: Adapter identifier mismatch in metadata
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
	echo "ERROR: Adapter identifier '$adapter_identifier' is already registered" >&2  # documented: Duplicate adapter identifier
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

