#!/usr/bin/env bash
# Helper functions for testing minified suitey.min.sh
# Loads the name mapping from suitey.min.map to allow tests to call minified functions

# Get the path to suitey.min.map
get_minified_map_file() {
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.min.map" ]]; then
    echo "$BATS_TEST_DIRNAME/../../../suitey.min.map"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.min.map" ]]; then
    echo "$BATS_TEST_DIRNAME/../../suitey.min.map"
  else
    echo "$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.min.map"
  fi
}

# Load minified name mappings
# Creates variables like MINIFIED_adapter_registry_initialize="h"
# and MINIFIED_REVERSE_h="adapter_registry_initialize"
load_minified_mappings() {
  local map_file="${1:-$(get_minified_map_file)}"
  
  if [[ ! -f "$map_file" ]]; then
    echo "Error: Mapping file not found: $map_file" >&2
    return 1
  fi
  
  # Load forward mappings (original -> minified)
  while IFS='=' read -r original minified || [[ -n "$original" ]]; do
    # Skip reverse mappings and comments
    [[ "$original" =~ ^# ]] && continue
    [[ -z "$original" ]] && continue
    
    # Create variable: MINIFIED_function_name="minified_name"
    declare -g "MINIFIED_${original}=${minified}"
  done < "$map_file"
  
  # Load reverse mappings (minified -> original)
  while IFS='=' read -r minified original || [[ -n "$minified" ]]; do
    # Only process reverse mappings
    [[ "$minified" =~ ^#REVERSE: ]] || continue
    minified="${minified#\#REVERSE:}"
    
    # Create variable: MINIFIED_REVERSE_minified="original_name"
    declare -g "MINIFIED_REVERSE_${minified}=${original}"
  done < "$map_file"
  
  return 0
}

# Get minified name for an original function/variable name
# Usage: minified_name=$(get_minified_name "adapter_registry_initialize")
get_minified_name() {
  local original_name="$1"
  local var_name="MINIFIED_${original_name}"
  echo "${!var_name}"
}

# Get original name for a minified function/variable name
# Usage: original_name=$(get_original_name "h")
get_original_name() {
  local minified_name="$1"
  local var_name="MINIFIED_REVERSE_${minified_name}"
  echo "${!var_name}"
}

# Call a minified function by its original name
# Usage: call_minified_function "adapter_registry_initialize" "$arg1" "$arg2"
call_minified_function() {
  local original_name="$1"
  shift
  local minified_name
  minified_name=$(get_minified_name "$original_name")
  
  if [[ -z "$minified_name" ]]; then
    echo "Error: No minified name found for '$original_name'" >&2
    return 1
  fi
  
  # Call the minified function
  "$minified_name" "$@"
}

# Source suitey.min.sh and load mappings for testing
setup_minified_suitey() {
  local suitey_script="${1:-$(get_suitey_min_script)}"
  local map_file="${2:-$(get_minified_map_file)}"
  
  # Source the minified script
  if [[ -f "$suitey_script" ]]; then
    source "$suitey_script"
  else
    echo "Error: Minified script not found: $suitey_script" >&2
    return 1
  fi
  
  # Load mappings
  load_minified_mappings "$map_file"
}

# Get the path to suitey.min.sh
get_suitey_min_script() {
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.min.sh" ]]; then
    echo "$BATS_TEST_DIRNAME/../../../suitey.min.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.min.sh" ]]; then
    echo "$BATS_TEST_DIRNAME/../../suitey.min.sh"
  else
    echo "$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.min.sh"
  fi
}


