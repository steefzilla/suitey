# ============================================================================
# Adapter Registry
# ============================================================================

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
  # Ensure directory exists
  mkdir -p "$(dirname "$ADAPTER_REGISTRY_FILE")"

  # Save ADAPTER_REGISTRY
  > "$ADAPTER_REGISTRY_FILE"
  for key in "${!ADAPTER_REGISTRY[@]}"; do
    echo "$key=${ADAPTER_REGISTRY[$key]}" >> "$ADAPTER_REGISTRY_FILE"
  done

  # Save ADAPTER_REGISTRY_CAPABILITIES
  > "$ADAPTER_REGISTRY_CAPABILITIES_FILE"
  for key in "${!ADAPTER_REGISTRY_CAPABILITIES[@]}"; do
    echo "$key=${ADAPTER_REGISTRY_CAPABILITIES[$key]}" >> "$ADAPTER_REGISTRY_CAPABILITIES_FILE"
  done

  # Save ADAPTER_REGISTRY_ORDER
  > "$ADAPTER_REGISTRY_ORDER_FILE"
  printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$ADAPTER_REGISTRY_ORDER_FILE"

  # Save ADAPTER_REGISTRY_INITIALIZED
  echo "$ADAPTER_REGISTRY_INITIALIZED" > "$ADAPTER_REGISTRY_INIT_FILE"
}

# Load registry state from files (for testing persistence)
adapter_registry_load_state() {
  # Load ADAPTER_REGISTRY
  if [[ -f "$ADAPTER_REGISTRY_FILE" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY["$key"]="$value"
    done < "$ADAPTER_REGISTRY_FILE"
  fi

  # Load ADAPTER_REGISTRY_CAPABILITIES
  if [[ -f "$ADAPTER_REGISTRY_CAPABILITIES_FILE" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
    done < "$ADAPTER_REGISTRY_CAPABILITIES_FILE"
  fi

  # Load ADAPTER_REGISTRY_ORDER
  if [[ -f "$ADAPTER_REGISTRY_ORDER_FILE" ]]; then
    mapfile -t ADAPTER_REGISTRY_ORDER < "$ADAPTER_REGISTRY_ORDER_FILE"
  fi

  # Load ADAPTER_REGISTRY_INITIALIZED
  if [[ -f "$ADAPTER_REGISTRY_INIT_FILE" ]]; then
    ADAPTER_REGISTRY_INITIALIZED=$(<"$ADAPTER_REGISTRY_INIT_FILE")
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

  # Call the adapter's metadata function
  if "$metadata_func" ""; then
    # Function succeeded, metadata was output
    return 0
  else
    echo "ERROR: Failed to extract metadata from adapter '$adapter_identifier'" >&2
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
    if ! echo "$metadata_json" | grep -q "\"$field\""; then
      echo "ERROR: Adapter '$adapter_identifier' metadata is missing required field: $field" >&2
      return 1
    fi
  done

  # Check that identifier matches adapter identifier
  if ! echo "$metadata_json" | grep -q "\"identifier\"[[:space:]]*:[[:space:]]*\"$adapter_identifier\""; then
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
  # This is a simple extraction - look for capabilities array
  local capabilities_part
  capabilities_part=$(echo "$metadata_json" | grep -o '"capabilities"[[:space:]]*:[[:space:]]*\[[^]]*\]' || echo "")

  if [[ -n "$capabilities_part" ]]; then
    # Extract capability names from the array (simplified parsing)
    local capabilities
    capabilities=$(echo "$capabilities_part" | grep -o '"[^"]*"' | sed 's/"//g' | tr '\n' ',' | sed 's/,$//')

    # Index each capability
    IFS=',' read -ra cap_array <<< "$capabilities"
    for cap in "${cap_array[@]}"; do
      if [[ -n "$cap" ]]; then
        # Add adapter to capability index
        if [[ ! -v ADAPTER_REGISTRY_CAPABILITIES["$cap"] ]]; then
          ADAPTER_REGISTRY_CAPABILITIES["$cap"]="$adapter_identifier"
        else
          ADAPTER_REGISTRY_CAPABILITIES["$cap"]="${ADAPTER_REGISTRY_CAPABILITIES["$cap"]},$adapter_identifier"
        fi
      fi
    done
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
    echo "ERROR: Cannot register adapter with null or empty identifier" >&2
    return 1
  fi

  # Check for identifier conflict
  if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
    echo "ERROR: Adapter identifier '$adapter_identifier' is already registered" >&2
    return 1
  fi

  # Validate interface
  if ! adapter_registry_validate_interface "$adapter_identifier"; then
    return 1
  fi

  # Extract and validate metadata
  local metadata_json
  metadata_json=$(adapter_registry_extract_metadata "$adapter_identifier")
  if [[ $? -ne 0 ]] || [[ -z "$metadata_json" ]]; then
    return 1
  fi

  if ! adapter_registry_validate_metadata "$adapter_identifier" "$metadata_json"; then
    return 1
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

  # Register built-in adapters
  local builtin_adapters=("bats" "rust")

  for adapter in "${builtin_adapters[@]}"; do
    if ! adapter_registry_register "$adapter"; then
      echo "ERROR: Failed to register built-in adapter '$adapter'" >&2
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

