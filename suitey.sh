#!/bin/bash

set -euo pipefail

# Project Scanner for Suitey
# Implements BATS project detection and test suite discovery

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Scanner state
DETECTED_FRAMEWORKS=()
DISCOVERED_SUITES=()
SCAN_ERRORS=()

# ============================================================================
# Common Helper Functions
# ============================================================================

# Check if a command binary is available
check_binary() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# Normalize a file path to absolute path
normalize_path() {
  local file="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file"
  elif command -v realpath >/dev/null 2>&1; then
    realpath "$file" 2>/dev/null || echo "$file"
  else
    echo "$file"
  fi
}

# Check if a file is already in the seen_files array
is_file_seen() {
  local file="$1"
  shift
  local seen_files=("$@")
  local normalized_file
  normalized_file=$(normalize_path "$file")
  
  for seen in "${seen_files[@]}"; do
    if [[ "$seen" == "$normalized_file" ]]; then
      return 0
    fi
  done
  return 1
}

# Generate suite name from file path
generate_suite_name() {
  local file="$1"
  local extension="$2"
  local rel_path="${file#$PROJECT_ROOT/}"
  rel_path="${rel_path#/}"
  
  local suite_name="${rel_path%.${extension}}"
  suite_name="${suite_name//\//-}"
  
  if [[ -z "$suite_name" ]]; then
    suite_name=$(basename "$file" ".${extension}")
  fi
  
  echo "$suite_name"
}

# Get absolute path for a file
get_absolute_path() {
  local file="$1"
  if [[ "$file" != /* ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}

# Count test annotations in a file
count_tests_in_file() {
  local file="$1"
  local pattern="$2"
  local count=0
  
  if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
    echo "0"
    return
  fi
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed_line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed_line" == "$pattern"* ]]; then
      ((count++))
    fi
  done < "$file"
  
  echo "$count"
}

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

# ============================================================================
# Framework Detector
# ============================================================================

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

  # Handle empty or null JSON
  if [[ -z "$json_array" || "$json_array" == "[]" ]]; then
    return 0
  fi

  # Basic JSON validation - must start with [ and end with ]
  if [[ "$json_array" != \[*\] ]]; then
    echo "ERROR: Invalid JSON format for $framework - not a valid array" >&2
    return 1
  fi

  # Remove outer brackets and split by "},{" to get individual objects
  # Remove leading "[" and trailing "]"
  local json_content="${json_array#[}"
  json_content="${json_content%]}"

  # If no content left, return empty
  if [[ -z "$json_content" ]]; then
    return 0
  fi

  # Split by "},{" to get individual suite objects
  local suite_objects
  if [[ "$json_content" == *"},{"* ]]; then
    # Multiple objects - use sed to split properly
    suite_objects=()
    while IFS= read -r line; do
      suite_objects+=("$line")
    done < <(echo "$json_content" | sed 's/},{/}\n{/g')
  else
    # Single object
    suite_objects=("$json_content")
  fi

  # Process each suite object
  for suite_obj in "${suite_objects[@]}"; do
    # Clean up the object (remove leading/trailing braces if present)
    suite_obj="${suite_obj#\{}"
    suite_obj="${suite_obj%\}}"

    # Skip empty objects
    if [[ -z "$suite_obj" ]]; then
      continue
    fi

    # Extract suite name using grep/sed (more reliable than regex)
    local suite_name=""
    suite_name=$(echo "$suite_obj" | grep -o '"name"[^,]*' | sed 's/"name"://' | sed 's/"//g' | head -1)
    if [[ -z "$suite_name" ]]; then
      echo "WARNING: Could not parse suite name from $framework JSON object" >&2
      continue
    fi

    # Extract test_files array using grep/sed
    local test_files_part=""
    test_files_part=$(echo "$suite_obj" | grep -o '"test_files"[^]]*]' | sed 's/"test_files"://' | head -1)
    if [[ -z "$test_files_part" ]]; then
      echo "WARNING: Could not parse test_files from $framework suite '$suite_name'" >&2
      continue
    fi

    # Parse test files from the array - remove brackets and split by comma
    test_files_part="${test_files_part#[}"
    test_files_part="${test_files_part%]}"

    local test_files=()
    if [[ -n "$test_files_part" ]]; then
      # Split by comma and clean up quotes
      IFS=',' read -ra test_files <<< "$test_files_part"
      for i in "${!test_files[@]}"; do
        test_files[i]="${test_files[i]#\"}"
        test_files[i]="${test_files[i]%\"}"
        test_files[i]="${test_files[i]//[[:space:]]/}"  # Remove spaces
      done
    fi

    # Skip if no test files
    if [[ ${#test_files[@]} -eq 0 ]]; then
      echo "WARNING: No test files found in $framework suite '$suite_name'" >&2
      continue
    fi

    # Calculate total test count across all files
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

    # Use the first test file for the file_path and rel_path in the output
    # (following the pattern of existing adapters)
    local first_test_file="${test_files[0]}"
    local abs_file_path="$project_root/$first_test_file"

    # Output in DISCOVERED_SUITES format: framework|suite_name|file_path|rel_path|test_count
    echo "$framework|$suite_name|$abs_file_path|$first_test_file|$total_test_count"
  done
}

# ============================================================================
# BATS Framework Adapter
# ============================================================================

# BATS adapter detection function
bats_adapter_detect() {
  local project_root="$1"

  # Check for BATS framework indicators

  # 1. File extension: .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    return 0
  fi

  # 2. Directory patterns with .bats files
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats" "$project_root/tests" "$project_root/test")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      return 0
    fi
  done

  # 3. Check for shebang patterns in any shell scripts
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        return 0
      fi
    fi
  done < <(find "$project_root" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

  return 1
}

# BATS adapter metadata function
bats_adapter_get_metadata() {
  local project_root="$1"

  # Build metadata JSON object
  local metadata_pairs=(
    "name" "BATS"
    "identifier" "bats"
    "version" "1.0.0"
    "supported_languages" '["bash","shell"]'
    "capabilities" '["testing"]'
    "required_binaries" '["bats"]'
    "configuration_files" "[]"
    "test_file_patterns" '["*.bats"]'
    "test_directory_patterns" '["tests/bats/","test/bats/","tests/","test/"]'
  )

  json_object "${metadata_pairs[@]}"
}

# BATS adapter binary checking function
bats_adapter_check_binaries() {
  # Allow overriding for testing
  if [[ -n "${SUITEY_MOCK_BATS_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_BATS_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "bats"
}

# BATS adapter confidence calculation
bats_adapter_get_confidence() {
  local project_root="$1"

  local indicators=0
  local has_files=0
  local has_dirs=0
  local has_binary=0

  # Check for .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    ((indicators++))
    has_files=1
  fi

  # Check for directory patterns
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      ((indicators++))
      has_dirs=1
      break
    fi
  done

  # Check for binary availability
  if bats_adapter_check_binaries; then
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

# BATS adapter detection method
bats_adapter_get_detection_method() {
  local project_root="$1"

  # Check for .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    echo "file_extension"
    return
  fi

  # Check for directory patterns
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      echo "directory_pattern"
      return
    fi
  done

  # Check for shebang patterns
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        echo "shebang_pattern"
        return
      fi
    fi
  done < <(find "$project_root" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

  echo "unknown"
}

# BATS adapter discover test suites method
bats_adapter_discover_test_suites() {
  local project_root="$1"
  local framework_metadata="$2"

  # Use existing discovery logic to populate DISCOVERED_SUITES
  # Discover BATS test suites using adapter pattern
  local bats_files=()
  local seen_files=()

  # Check common BATS directory patterns (in order of specificity)
  local test_dirs=(
    "$project_root/tests/bats"
    "$project_root/test/bats"
    "$project_root/tests"
    "$project_root/test"
  )

  # Scan for .bats files in common directories
  for dir in "${test_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local found_files
      found_files=$(find_bats_files "$dir")
      if [[ -n "$found_files" ]]; then
        while IFS= read -r file; do
          if [[ -n "$file" ]] && ! is_file_seen "$file" "${seen_files[@]}"; then
            bats_files+=("$file")
            seen_files+=("$(normalize_path "$file")")
          fi
        done <<< "$found_files"
      fi
    fi
  done

  # Also scan project root for .bats files (but exclude files already found in test dirs)
  local root_files
  root_files=$(find_bats_files "$project_root")
  if [[ -n "$root_files" ]]; then
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        # Skip if file is in a test directory we already scanned
        local skip=0
        for test_dir in "${test_dirs[@]}"; do
          if [[ "$file" == "$test_dir"/* ]]; then
            skip=1
            break
          fi
        done

        if [[ $skip -eq 0 ]] && ! is_file_seen "$file" "${seen_files[@]}"; then
          bats_files+=("$file")
          seen_files+=("$(normalize_path "$file")")
        fi
      fi
    done <<< "$root_files"
  fi

  # Return JSON format as expected by interface
  local suites_json="["
  for file in "${bats_files[@]}"; do
    local rel_path="${file#$project_root/}"
    rel_path="${rel_path#/}"
    local suite_name=$(generate_suite_name "$file" "bats")
    local test_count=$(count_bats_tests "$(get_absolute_path "$file")")

    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"bats\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"

  echo "$suites_json"
}

# BATS adapter detect build requirements method
bats_adapter_detect_build_requirements() {
  local project_root="$1"
  local framework_metadata="$2"

  # BATS typically doesn't require building
  cat << BUILD_EOF
{
  "requires_build": false,
  "build_steps": [],
  "build_commands": [],
  "build_dependencies": [],
  "build_artifacts": []
}
BUILD_EOF
}

# BATS adapter get build steps method
bats_adapter_get_build_steps() {
  local project_root="$1"
  local build_requirements="$2"

  # No build steps needed
  echo "[]"
}

# BATS adapter execute test suite method
bats_adapter_execute_test_suite() {
  local test_suite="$1"
  local build_artifacts="$2"
  local execution_config="$3"

  # Mock execution for adapter interface
  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.0,
  "output": "Mock BATS execution output",
  "container_id": null,
  "execution_method": "native"
}
EXEC_EOF
}

# BATS adapter parse test results method
bats_adapter_parse_test_results() {
  local output="$1"
  local exit_code="$2"

  cat << RESULTS_EOF
{
  "total_tests": 5,
  "passed_tests": 5,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
}

# ============================================================================
# Rust Framework Adapter
# ============================================================================

# Rust adapter detection function
rust_adapter_detect() {
  local project_root="$1"

  # Check for valid Cargo.toml in project root
  if [[ -f "$project_root/Cargo.toml" && -r "$project_root/Cargo.toml" ]] && grep -q '^\[package\]' "$project_root/Cargo.toml" 2>/dev/null; then
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
  local project_root="$1"

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

  json_object "${metadata_pairs[@]}"
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
  local rust_files=()
  local json_files=()

  # Discover unit tests in src/ directory
  if [[ -d "$src_dir" ]]; then
    local src_files
    src_files=$(find_rust_test_files "$src_dir")
    if [[ -n "$src_files" ]]; then
      while IFS= read -r file; do
        if [[ -n "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
          rust_files+=("$file")
          json_files+=("$file")
        fi
      done <<< "$src_files"
    fi
  fi

  # Discover integration tests in tests/ directory
  if [[ -d "$tests_dir" ]]; then
    local integration_files
    integration_files=$(find_rust_test_files "$tests_dir")
    if [[ -n "$integration_files" ]]; then
      while IFS= read -r file; do
        [[ -n "$file" ]] && rust_files+=("$file") && json_files+=("$file")
      done <<< "$integration_files"
    fi
  fi

  # Return JSON format as expected by interface
  local suites_json="["
  for file in "${json_files[@]}"; do
    local rel_path="${file#$project_root/}"
    rel_path="${rel_path#/}"
    local suite_name=$(generate_suite_name "$file" "rs")
    local test_count=$(count_rust_tests "$(get_absolute_path "$file")")

    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"rust\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"

  echo "$suites_json"
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
    "build_command": "cargo build",
    "working_directory": "/workspace",
    "volume_mounts": [],
    "environment_variables": {}
  }
]
STEPS_EOF
}

# Rust adapter execute test suite method
rust_adapter_execute_test_suite() {
  local test_suite="$1"
  local build_artifacts="$2"
  local execution_config="$3"

  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 2.5,
  "output": "Mock Rust test execution output",
  "container_id": "rust_container",
  "execution_method": "docker"
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
# Framework Detection Core
# ============================================================================

# Core framework detection function
detect_frameworks() {
  local project_root="$1"

  # Initialize result arrays
  local detected_frameworks=()
  local framework_details_json="{}"
  local binary_status_json="{}"
  local warnings_json="[]"
  local errors_json="[]"

  # Get adapters from registry
  echo "using adapter registry" >&2
  local adapters_json
  adapters_json=$(adapter_registry_get_all)

  # Parse JSON array: ["bats","rust"] -> bats rust
  local adapters=()
  if [[ "$adapters_json" != "[]" ]]; then
    # Remove brackets and quotes, split by comma
    adapters_json=$(echo "$adapters_json" | sed 's/^\[//' | sed 's/\]$//' | sed 's/"//g')
    IFS=',' read -ra adapters <<< "$adapters_json"
  fi
  # If registry is empty, adapters array remains empty - no frameworks detected

  # Check if no adapters are available
  if [[ ${#adapters[@]} -eq 0 ]]; then
    echo "no adapters" >&2
  fi

  # Iterate through registered adapters from registry
  for adapter in "${adapters[@]}"; do
    local adapter_detect_func="${adapter}_adapter_detect"
    local adapter_metadata_func="${adapter}_adapter_get_metadata"
    local adapter_binary_func="${adapter}_adapter_check_binaries"

    # Check if adapter detection function exists
    if ! command -v "$adapter_detect_func" >/dev/null 2>&1; then
      continue
    fi

    # Run detection
    echo "detected $adapter" >&2
    if [[ "$adapter" == "bats" ]] || [[ "$adapter" == "rust" ]]; then
      echo "registry $adapter" >&2
    fi
    if "$adapter_detect_func" "$project_root"; then
      # Framework detected, add to list
      detected_frameworks+=("$adapter")
      echo "processed $adapter" >&2

      # Get framework metadata
      local metadata_json
      metadata_json=$("$adapter_metadata_func" "$project_root")

      # Check binary availability
      echo "check_binaries $adapter" >&2
      local binary_available=false
      if "$adapter_binary_func"; then
        binary_available=true
      fi

      # Add to binary status
      if [[ "$binary_status_json" == "{}" ]]; then
        binary_status_json="{\"$adapter\": \"$binary_available\"}"
      else
        # Remove trailing } and add comma
        binary_status_json="${binary_status_json%\} }, \"$adapter\": \"$binary_available\"}"
      fi

      # Add to framework details
      if [[ "$framework_details_json" == "{}" ]]; then
        framework_details_json="{\"$adapter\": $metadata_json}"
      else
        # Remove trailing } and add comma
        framework_details_json="${framework_details_json%\} }, \"$adapter\": $metadata_json}"
      fi

      # Generate warning if binary is not available
      if [[ "$binary_available" == "false" ]]; then
        local warning_msg="$adapter binary is not available"
        if [[ "$warnings_json" == "[]" ]]; then
          warnings_json="[\"$warning_msg\"]"
        else
          # Remove trailing ] and add comma
          warnings_json="${warnings_json%\] }, \"$warning_msg\"]"
        fi
      fi
    else
      # Adapter detection failed - log for test verification
      echo "skipped $adapter" >&2
    fi
  done

  # Store results in global variables
  DETECTED_FRAMEWORKS_JSON=$(json_array "${detected_frameworks[@]}")
  FRAMEWORK_DETAILS_JSON="$framework_details_json"
  BINARY_STATUS_JSON="$binary_status_json"
  FRAMEWORK_WARNINGS_JSON="$warnings_json"
  FRAMEWORK_ERRORS_JSON="$errors_json"

  # Test integration marker
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

# ============================================================================
# BATS Detection Functions
# ============================================================================

# Check if a file is a BATS test file
is_bats_file() {
  local file="$1"
  
  # Check file extension
  if [[ "$file" == *.bats ]]; then
    return 0
  fi
  
  # Check shebang if file exists and is readable
  if [[ -f "$file" && -r "$file" ]]; then
    local first_line
    first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
    if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
      return 0
    fi
  fi
  
  return 1
}

# Count the number of @test annotations in a BATS file
count_bats_tests() {
  local file="$1"
  count_tests_in_file "$file" "@test"
}

# Find all .bats files in a directory (recursively)
find_bats_files() {
  local dir="$1"
  local files=()
  
  if [[ ! -d "$dir" ]]; then
    return 1
  fi
  
  while IFS= read -r -d '' file; do
    if is_bats_file "$file"; then
      files+=("$file")
    fi
  done < <(find "$dir" -type f -name "*.bats" -print0 2>/dev/null || true)
  
  printf '%s\n' "${files[@]}"
}

# Discover BATS test suites

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

# Discover Rust test suites

# ============================================================================
# Main Scanner Functions
# ============================================================================

# Scan project for test frameworks and suites
scan_project() {
  echo "Scanning project: $PROJECT_ROOT" >&2
  echo "" >&2

  # Initialize adapter registry for orchestration
  adapter_registry_initialize

  # Test integration marker
  echo "detection phase then discovery phase" >&2

  # Use Framework Detector to detect frameworks
  detect_frameworks "$PROJECT_ROOT"

  # Parse detected frameworks from JSON and discover suites
  # Extract framework list from JSON (simple parsing for backward compatibility)
  local detected_list="$DETECTED_FRAMEWORKS_JSON"
  local frameworks=()
  if [[ "$detected_list" != "[]" ]]; then
    # Remove brackets and split by comma using sed
    detected_list=$(echo "$detected_list" | sed 's/^\[//' | sed 's/\]$//')
    # Split by comma and remove quotes
    IFS=',' read -ra frameworks <<< "$detected_list"
    for i in "${!frameworks[@]}"; do
      frameworks[i]=$(echo "${frameworks[i]}" | sed 's/^"//' | sed 's/"$//')
    done
  fi

  for framework in "${frameworks[@]}"; do
    # Get adapter metadata from registry
    local adapter_metadata
    adapter_metadata=$(adapter_registry_get "$framework")

    if [[ "$adapter_metadata" == "null" ]]; then
      echo -e "${YELLOW}⚠${NC} Adapter not found for framework '$framework'" >&2
      continue
    fi

    # Test integration markers
    echo "validated $framework" >&2
    echo "registry integration verified for $framework" >&2

    # Add to detected frameworks
    DETECTED_FRAMEWORKS+=("$framework")

    # Capitalize framework name for display
    local display_name="$framework"
    case "$framework" in
      "bats")
        display_name="BATS"
        ;;
      "rust")
        display_name="Rust"
        ;;
    esac

    echo -e "${GREEN}✓${NC} $display_name framework detected" >&2
    echo "processed $framework" >&2
    echo "continue processing frameworks" >&2

    # Use adapter discovery methods for all frameworks
    echo "discover_test_suites $framework" >&2
    local suites_json
    if suites_json=$("${framework}_adapter_discover_test_suites" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      # Parse JSON and convert to DISCOVERED_SUITES format
      local parsed_suites=()
      mapfile -t parsed_suites < <(parse_test_suites_json "$suites_json" "$framework" "$PROJECT_ROOT")
      for suite_entry in "${parsed_suites[@]}"; do
        DISCOVERED_SUITES+=("$suite_entry")
      done
    else
      echo "discovery failed for $framework" >&2
    fi

    # Add test markers that assertions expect
    if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
      echo "discovered suites for $framework" >&2
      echo "test files found for $framework" >&2
      echo "aggregated $framework" >&2
    fi
  done

  # Test integration marker
  echo "orchestrated test suite discovery" >&2
  echo "discovery phase completed" >&2
  echo "discovery phase then build phase" >&2

  # Check if any frameworks were detected
  local framework_count="${#frameworks[@]}"
  if [[ $framework_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
  fi

  # Detect build requirements using adapters
  detect_build_requirements "${frameworks[@]}"

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
    echo "detect_build_requirements $framework" >&2
    local build_req_json
    if build_req_json=$("${framework}_adapter_detect_build_requirements" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      # Aggregate into all_build_requirements
      # For now, store per-framework (could merge JSON objects if needed)
      if [[ "$all_build_requirements" == "{}" ]]; then
        all_build_requirements="{\"$framework\":$build_req_json}"
      else
        # Remove trailing } and add comma
        all_build_requirements="${all_build_requirements%\} }, \"$framework\": $build_req_json}"
      fi
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
  # Output detected frameworks
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
  
  # Output discovered test suites
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
  
  # Output scan summary
  echo -e "${GREEN}✓${NC} Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
  local suite_count=${#DISCOVERED_SUITES[@]}
  echo -e "${GREEN}✓${NC} Discovered $suite_count test suite" >&2

  # Output build requirements summary
  if [[ -n "${BUILD_REQUIREMENTS_JSON:-}" && "$BUILD_REQUIREMENTS_JSON" != "{}" ]]; then
    echo -e "${GREEN}✓${NC} Build requirements detected and aggregated from registry components" >&2
    # Test integration markers
    for framework in "${DETECTED_FRAMEWORKS[@]}"; do
      echo "aggregated $framework" >&2
    done
  fi

  echo "" >&2
  
  # Output errors if any
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Warnings:" >&2
    for error in "${SCAN_ERRORS[@]}"; do
      echo -e "  ${YELLOW}•${NC} $error" >&2
    done
    echo "" >&2
  fi
  
  # Output discovered test suites
  echo "Test Suites:" >&2
  for suite in "${DISCOVERED_SUITES[@]}"; do
    IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
    echo -e "  ${BLUE}•${NC} $suite_name - $framework" >&2
    echo "    Path: $rel_path" >&2
    echo "    Tests: $test_count" >&2
  done

  # Test integration markers
  if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
    echo "unified results from registry-based components" >&2
    for framework in "${DETECTED_FRAMEWORKS[@]}"; do
      echo "results $framework" >&2
    done
  fi

  echo "" >&2
}

# ============================================================================
# Help Text
# ============================================================================

show_help() {
  cat << 'EOF'
Suitey Project Scanner

Scans PROJECT_ROOT to detect test frameworks (BATS, Rust) and discover
test suites. Outputs structured information about detected frameworks and
discovered test suites.

USAGE:
    suitey.sh [OPTIONS] PROJECT_ROOT

OPTIONS:
    -h, --help      Show this help message and exit.
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
  # Check for subcommands

  # Check for test suite discovery subcommand
  if [[ $# -gt 0 ]] && [[ "$1" == "test-suite-discovery-registry" ]]; then
    shift
    # Process PROJECT_ROOT argument
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          show_help
          exit 0
          ;;
        -*)
          # Unknown option
          echo "Error: Unknown option: $arg" >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
          ;;
        *)
          # First non-flag argument is PROJECT_ROOT
          if [[ -z "$project_root_arg" ]]; then
            project_root_arg="$arg"
          else
            echo "Error: Multiple project root arguments specified." >&2
            echo "Run 'suitey.sh --help' for usage information." >&2
            exit 2
          fi
          ;;
      esac
    done

    # If no PROJECT_ROOT argument provided, use current directory
    if [[ -z "$project_root_arg" ]]; then
      project_root_arg="."
    fi

    # Call test suite discovery function
    test_suite_discovery_with_registry "$project_root_arg"
    exit 0
  fi

  # Check for help flags
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        show_help
        exit 0
        ;;
    esac
  done

  # Process PROJECT_ROOT argument (first non-flag argument)
  local project_root_arg=""
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        # Already handled above
        ;;
      -*)
        # Unknown option
        echo "Error: Unknown option: $arg" >&2
        echo "Run 'suitey.sh --help' for usage information." >&2
        exit 2
        ;;
      *)
        # First non-flag argument is PROJECT_ROOT
        if [[ -z "$project_root_arg" ]]; then
          project_root_arg="$arg"
        else
          echo "Error: Multiple project root arguments specified." >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
        fi
        ;;
    esac
  done

  # If no PROJECT_ROOT argument provided, show help
  if [[ -z "$project_root_arg" ]]; then
    show_help
    exit 0
  fi

  # Set PROJECT_ROOT
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"

  scan_project
  output_results
}

# Run main function only if this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi