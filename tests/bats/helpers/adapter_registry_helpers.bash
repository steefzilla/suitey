#!/usr/bin/env bash
# Helper functions for Adapter Registry Helpers tests

# ============================================================================
# Source the adapter registry helpers module
# ============================================================================

# Find and source adapter_registry_helpers.sh
adapter_registry_helpers_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
  adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
  adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
else
  adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
fi

source "$adapter_registry_helpers_script"

# ============================================================================
# JSON Helper Functions (for test assertions)
# ============================================================================

# Test-local JSON helper functions (wrappers around jq for now)
json_test_get() {
  local json="$1"
  local path="$2"
  echo "$json" | jq -r "$path" 2>/dev/null || return 1
}

json_test_has_field() {
  local json="$1"
  local field="$2"
  echo "$json" | jq -e "has(\"$field\")" >/dev/null 2>&1
}

# ============================================================================
# Setup/Teardown Functions
# ============================================================================

# Create a temporary directory for Adapter Registry Helpers testing
setup_adapter_registry_helpers_test() {
  local test_name="${1:-adapter_registry_helpers_test}"
  TEST_ADAPTER_REGISTRY_DIR=$(mktemp -d -t "suitey_adapter_helpers_test_${test_name}_XXXXXX")
  export TEST_ADAPTER_REGISTRY_DIR
  echo "$TEST_ADAPTER_REGISTRY_DIR"
}

# Clean up temporary directory
teardown_adapter_registry_helpers_test() {
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -d "$TEST_ADAPTER_REGISTRY_DIR" ]]; then
    rm -rf "$TEST_ADAPTER_REGISTRY_DIR"
    unset TEST_ADAPTER_REGISTRY_DIR
  fi

  # Clean up registry state files
  rm -f /tmp/suitey_adapter_registry /tmp/suitey_adapter_capabilities /tmp/suitey_adapter_order /tmp/suitey_adapter_init
  # Clean up any test directories that might be left
  find /tmp -maxdepth 1 -name "suitey_adapter_helpers_test_*" -type d -exec rm -rf {} + 2>/dev/null || true
}

# ============================================================================
# Test Helper Functions
# ============================================================================

# Run a helper function and capture output
run_helper_function() {
  local function_name="$1"
  shift
  local args=("$@")

  # Capture both stdout and stderr
  local output
  output=$("$function_name" "${args[@]}" 2>&1)
  local exit_code=$?

  echo "$output"
  return $exit_code
}

# Assert that a base64 value can be encoded and decoded
assert_base64_roundtrip() {
  local original_value="$1"
  local encoded_value
  local decoded_value

  encoded_value=$(_adapter_registry_encode_value "$original_value")
  [[ $? -eq 0 ]] || {
    echo "ERROR: Failed to encode value: $original_value"
    return 1
  }

  decoded_value=$(_adapter_registry_decode_value "$encoded_value")
  [[ $? -eq 0 ]] || {
    echo "ERROR: Failed to decode value: $encoded_value"
    return 1
  }

  [[ "$decoded_value" == "$original_value" ]] || {
    echo "ERROR: Roundtrip failed. Original: '$original_value', Decoded: '$decoded_value'"
    return 1
  }

  return 0
}

# Assert that a file contains expected base64 encoded data
assert_file_contains_encoded_data() {
  local file_path="$1"
  local key="$2"
  local expected_value="$3"

  [[ -f "$file_path" ]] || {
    echo "ERROR: File does not exist: $file_path"
    return 1
  }

  local encoded_value
  encoded_value=$(grep "^$key=" "$file_path" | cut -d'=' -f2)
  [[ -n "$encoded_value" ]] || {
    echo "ERROR: Key '$key' not found in file: $file_path"
    return 1
  }

  local decoded_value
  decoded_value=$(_adapter_registry_decode_value "$encoded_value")
  [[ $? -eq 0 ]] || {
    echo "ERROR: Failed to decode value from file: $encoded_value"
    return 1
  }

  [[ "$decoded_value" == "$expected_value" ]] || {
    echo "ERROR: Decoded value mismatch. Expected: '$expected_value', Got: '$decoded_value'"
    return 1
  }

  return 0
}

# Assert that a directory exists and is writable
assert_directory_writable() {
  local dir_path="$1"

  [[ -d "$dir_path" ]] || {
    echo "ERROR: Directory does not exist: $dir_path"
    return 1
  }

  # Try to create a test file
  local test_file="$dir_path/.test_write"
  touch "$test_file" 2>/dev/null
  local touch_exit=$?

  # Clean up
  rm -f "$test_file" 2>/dev/null

  [[ $touch_exit -eq 0 ]] || {
    echo "ERROR: Directory is not writable: $dir_path"
    return 1
  }

  return 0
}

# Assert that file location determination works correctly
assert_file_locations_determined() {
  local expected_base_dir="$1"

  # Mock TEST_ADAPTER_REGISTRY_DIR for testing
  export TEST_ADAPTER_REGISTRY_DIR="$expected_base_dir"

  local file_paths
  file_paths=$(_adapter_registry_determine_file_locations)

  # Parse the file paths
  local registry_file capabilities_file order_file init_file
  registry_file=$(echo "$file_paths" | sed -n '1p')
  capabilities_file=$(echo "$file_paths" | sed -n '2p')
  order_file=$(echo "$file_paths" | sed -n '3p')
  init_file=$(echo "$file_paths" | sed -n '4p')

  # Check that files are in the expected directory
  [[ "$registry_file" == "$expected_base_dir/suitey_adapter_registry" ]] || {
    echo "ERROR: Registry file path incorrect. Expected: $expected_base_dir/suitey_adapter_registry, Got: $registry_file"
    return 1
  }

  [[ "$capabilities_file" == "$expected_base_dir/suitey_adapter_capabilities" ]] || {
    echo "ERROR: Capabilities file path incorrect. Expected: $expected_base_dir/suitey_adapter_capabilities, Got: $capabilities_file"
    return 1
  }

  [[ "$order_file" == "$expected_base_dir/suitey_adapter_order" ]] || {
    echo "ERROR: Order file path incorrect. Expected: $expected_base_dir/suitey_adapter_order, Got: $order_file"
    return 1
  }

  [[ "$init_file" == "$expected_base_dir/suitey_adapter_init" ]] || {
    echo "ERROR: Init file path incorrect. Expected: $expected_base_dir/suitey_adapter_init, Got: $init_file"
    return 1
  }

  return 0
}

# Assert that reload decision is correct
assert_reload_decision() {
  local registry_file="$1"
  local capabilities_file="$2"
  local switching_locations="$3"
  local expected_decision="$4"

  local actual_decision
  actual_decision=$(_adapter_registry_should_reload "$registry_file" "$capabilities_file" "$switching_locations")

  [[ "$actual_decision" == "$expected_decision" ]] || {
    echo "ERROR: Reload decision incorrect. Expected: '$expected_decision', Got: '$actual_decision'"
    echo "  Registry file: $registry_file"
    echo "  Capabilities file: $capabilities_file"
    echo "  Switching locations: $switching_locations"
    return 1
  }

  return 0
}

# Assert that order array is loaded correctly
assert_order_array_loaded() {
  local order_file="$1"
  local expected_orders=("${@:2}")

  # Clear any existing order
  ADAPTER_REGISTRY_ORDER=()

  _adapter_registry_load_order_array "$order_file"

  local expected_count="${#expected_orders[@]}"
  local actual_count="${#ADAPTER_REGISTRY_ORDER[@]}"

  [[ $actual_count -eq $expected_count ]] || {
    echo "ERROR: Order array length mismatch. Expected: $expected_count, Got: $actual_count"
    return 1
  }

  for ((i=0; i<expected_count; i++)); do
    [[ "${ADAPTER_REGISTRY_ORDER[$i]}" == "${expected_orders[$i]}" ]] || {
      echo "ERROR: Order array element $i mismatch. Expected: '${expected_orders[$i]}', Got: '${ADAPTER_REGISTRY_ORDER[$i]}'"
      return 1
    }
  done

  return 0
}
