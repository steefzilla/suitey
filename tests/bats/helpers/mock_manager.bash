#!/usr/bin/env bash
# Mock Manager System for Build Manager Tests
# Provides intelligent mocking, parameter transformation, and contextual responses

# ============================================================================
# Mock Manager State
# ============================================================================

# Global mock state variables
declare -A MOCK_STATE
declare -A MOCK_CONTEXT
MOCK_INITIALIZED=false
MOCK_TEST_ID=""

# Mock state persistence (for complex multi-step tests)
MOCK_STATE_FILE=""
MOCK_CONTEXT_FILE=""

# ============================================================================
# Mock Manager Core Functions
# ============================================================================

# Initialize the mock manager system
# Sets up state tracking and context management for tests
mock_manager_init() {
  local test_id="${1:-default_test}"

  MOCK_TEST_ID="$test_id"
  MOCK_INITIALIZED=true

  # Create temporary files for state persistence
  MOCK_STATE_FILE="/tmp/suitey_mock_state_${test_id}_$$.json"
  MOCK_CONTEXT_FILE="/tmp/suitey_mock_context_${test_id}_$$.json"

  # Initialize empty state
  echo "{}" > "$MOCK_STATE_FILE"
  echo "{}" > "$MOCK_CONTEXT_FILE"

  # Reset in-memory state
  MOCK_STATE=()
  MOCK_CONTEXT=()

  return 0
}

# Reset mock manager state between tests
# Clears all state and context information
mock_manager_reset() {
  if [[ -n "$MOCK_STATE_FILE" ]] && [[ -f "$MOCK_STATE_FILE" ]]; then
    rm -f "$MOCK_STATE_FILE"
  fi

  if [[ -n "$MOCK_CONTEXT_FILE" ]] && [[ -f "$MOCK_CONTEXT_FILE" ]]; then
    rm -f "$MOCK_CONTEXT_FILE"
  fi

  MOCK_STATE=()
  MOCK_CONTEXT=()
  MOCK_TEST_ID=""
  MOCK_INITIALIZED=false

  return 0
}

# Set test context for contextual mock responses
# Arguments:
#   context_key: Context identifier (e.g., "cpu_test", "artifact_test")
#   context_value: JSON string with context data
mock_manager_set_context() {
  local context_key="$1"
  local context_value="$2"

  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    echo "ERROR: Mock manager not initialized" >&2
    return 1
  fi

  # Store in memory
  MOCK_CONTEXT["$context_key"]="$context_value"

  # Persist to file
  if [[ -n "$MOCK_CONTEXT_FILE" ]]; then
    local current_context
    current_context=$(cat "$MOCK_CONTEXT_FILE" 2>/dev/null || echo "{}")
    local updated_context
    updated_context=$(echo "$current_context" | jq ".\"$context_key\" = $context_value" 2>/dev/null || echo "$current_context")
    echo "$updated_context" > "$MOCK_CONTEXT_FILE"
  fi

  return 0
}

# Get mock state for inspection and assertions
# Arguments:
#   state_key: (optional) Specific state key to retrieve
# Returns: JSON state data or specific value
mock_manager_get_state() {
  local state_key="$1"

  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    echo "ERROR: Mock manager not initialized" >&2
    return 1
  fi

  if [[ -n "$state_key" ]]; then
    # Return specific key value
    if [[ -v MOCK_STATE["$state_key"] ]]; then
      echo "${MOCK_STATE[$state_key]}"
    else
      echo "null"
    fi
  else
    # Return all state as JSON
    local json_state="{"
    local first=true
    for key in "${!MOCK_STATE[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        json_state+=","
      fi
      json_state+="\"$key\":\"${MOCK_STATE[$key]}\""
    done
    json_state+="}"
    echo "$json_state"
  fi
}

# Update mock state (internal function)
# Arguments:
#   key: State key to update
#   value: Value to store
_mock_manager_update_state() {
  local key="$1"
  local value="$2"

  MOCK_STATE["$key"]="$value"

  # Persist to file
  if [[ -n "$MOCK_STATE_FILE" ]]; then
    local current_state
    current_state=$(cat "$MOCK_STATE_FILE" 2>/dev/null || echo "{}")
    local updated_state
    updated_state=$(echo "$current_state" | jq ".\"$key\" = \"$value\"" 2>/dev/null || echo "$current_state")
    echo "$updated_state" > "$MOCK_STATE_FILE"
  fi
}

# Get test context (internal function)
# Arguments:
#   context_key: Context key to retrieve
# Returns: Context value or empty string
_mock_manager_get_context() {
  local context_key="$1"

  if [[ -v MOCK_CONTEXT["$context_key"] ]]; then
    echo "${MOCK_CONTEXT[$context_key]}"
  else
    echo ""
  fi
}

# Load persisted state from files (for complex tests)
_mock_manager_load_state() {
  if [[ -f "$MOCK_STATE_FILE" ]]; then
    # Load state from file (simplified - would need jq parsing)
    local file_state
    file_state=$(cat "$MOCK_STATE_FILE")
    # Parse and load into MOCK_STATE (implementation would go here)
  fi

  if [[ -f "$MOCK_CONTEXT_FILE" ]]; then
    # Load context from file
    local file_context
    file_context=$(cat "$MOCK_CONTEXT_FILE")
    # Parse and load into MOCK_CONTEXT (implementation would go here)
  fi
}

# ============================================================================
# Parameter Transformation System
# ============================================================================

# Transform complex Docker arguments to simple mock parameters
# Arguments:
#   args: Array of docker command arguments
# Returns: Simple mock parameters (container_name, image, command)
transform_docker_args() {
  local args=("$@")
  local container_name=""
  local image=""
  local command=""
  local cpu_cores=""
  local volumes=()
  local env_vars=()
  local working_dir=""

  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --name)
        ((i++))
        container_name="${args[$i]}"
        ;;
      --cpus)
        ((i++))
        cpu_cores="${args[$i]}"
        ;;
      -v)
        ((i++))
        volumes+=("${args[$i]}")
        ;;
      -e)
        ((i++))
        env_vars+=("${args[$i]}")
        ;;
      -w)
        ((i++))
        working_dir="${args[$i]}"
        ;;
      -*)
        # Skip other flags
        ;;
      *)
        # If we don't have image yet and it looks like an image name
        if [[ -z "$image" ]] && [[ "${args[$i]}" == *"/"* ]]; then
          image="${args[$i]}"
          ((i++))
          # Everything after image is command
          command="${args[$i]}"
          break
        fi
        ;;
    esac
    ((i++))
  done

  # Store extracted info in mock context
  local context="{\"container_name\":\"$container_name\",\"image\":\"$image\",\"command\":\"$command\",\"cpu_cores\":\"$cpu_cores\",\"volumes\":[\"${volumes[*]}\"],\"env_vars\":[\"${env_vars[*]}\"],\"working_dir\":\"$working_dir\"}"
  mock_manager_set_context "docker_args" "$context"

  # Return simple parameters for mock
  echo "$container_name"
  echo "$image"
  echo "$command"
}

# Extract container metadata from docker arguments
# Arguments:
#   args: Array of docker command arguments
# Returns: JSON with extracted container information
extract_container_info() {
  local args=("$@")
  local info="{}"

  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --name)
        ((i++))
        info=$(echo "$info" | jq ".container_name = \"${args[$i]}\"")
        ;;
      --cpus)
        ((i++))
        info=$(echo "$info" | jq ".cpu_cores = \"${args[$i]}\"")
        ;;
      -v)
        ((i++))
        local volume="${args[$i]}"
        info=$(echo "$info" | jq ".volumes += [\"$volume\"]")
        ;;
      -e)
        ((i++))
        local env_var="${args[$i]}"
        info=$(echo "$info" | jq ".env_vars += [\"$env_var\"]")
        ;;
      -w)
        ((i++))
        info=$(echo "$info" | jq ".working_dir = \"${args[$i]}\"")
        ;;
      -*)
        # Skip other flags
        ;;
      *)
        # If it looks like an image name
        if [[ "${args[$i]}" == *"/"* ]] || [[ "${args[$i]}" == *":"* ]]; then
          info=$(echo "$info" | jq ".image = \"${args[$i]}\"")
          ((i++))
          # Everything after is command
          local cmd=""
          for ((j=i; j<${#args[@]}; j++)); do
            if [[ -n "$cmd" ]]; then
              cmd="$cmd "
            fi
            cmd="$cmd${args[$j]}"
          done
          info=$(echo "$info" | jq ".command = \"$cmd\"")
          break
        fi
        ;;
    esac
    ((i++))
  done

  echo "$info"
}

# Normalize mock parameters to simple interface
# Arguments:
#   complex_args: Complex docker arguments
# Returns: Simple mock parameters
normalize_mock_params() {
  local complex_args=("$@")

  # Extract essential information
  local container_info
  container_info=$(extract_container_info "${complex_args[@]}")

  local container_name
  container_name=$(echo "$container_info" | jq -r '.container_name // "mock_container"')

  local image
  image=$(echo "$container_info" | jq -r '.image // "mock_image:latest"')

  local command
  command=$(echo "$container_info" | jq -r '.command // "mock command"')

  # Return normalized parameters
  echo "$container_name"
  echo "$image"
  echo "$command"
}

# Preserve test context for assertions
# Arguments:
#   test_name: Name of the test
#   context_data: Context data to preserve
preserve_test_context() {
  local test_name="$1"
  local context_data="$2"

  mock_manager_set_context "$test_name" "$context_data"
}

# ============================================================================
# Contextual Response Generator
# ============================================================================

# Generate CPU allocation response based on test context
# Returns: Mock response that includes CPU core information
generate_cpu_response() {
  local cpu_cores="${1:-1}"

  # Check if this is a CPU allocation test
  local context
  context=$(_mock_manager_get_context "cpu_test")

  if [[ -n "$context" ]]; then
    echo "Mock Docker run output with $cpu_cores CPU cores allocated"
  else
    echo "Mock Docker run output"
  fi
}

# Generate artifact operation response
# Arguments:
#   operation: Type of operation (extract, copy, etc.)
#   paths: Paths involved in operation
# Returns: Contextual response for artifact operations
generate_artifact_response() {
  local operation="$1"
  local paths="$2"

  # Check if this is an artifact test
  local context
  context=$(_mock_manager_get_context "artifact_test")

  if [[ -n "$context" ]]; then
    case "$operation" in
      "extract")
        echo "Artifacts extracted from container to $paths"
        ;;
      "copy")
        echo "Files copied to $paths"
        ;;
      "verify")
        echo "Artifact verification completed for $paths"
        ;;
      *)
        echo "Mock Docker copy output for $paths"
        ;;
    esac
  else
    echo "Mock Docker copy output"
  fi
}

# Generate timing information response
# Arguments:
#   duration: Expected duration in seconds
# Returns: Response with timing information
generate_duration_response() {
  local duration="${1:-1}"

  # Check if this is a duration test
  local context
  context=$(_mock_manager_get_context "duration_test")

  if [[ -n "$context" ]]; then
    echo "Operation completed in ${duration}s"
  else
    echo "Mock Docker run output"
  fi
}

# Generate error response based on test context
# Arguments:
#   error_type: Type of error (build_fail, container_fail, etc.)
# Returns: Appropriate error message
generate_error_response() {
  local error_type="$1"

  # Check if this is an error test
  local context
  context=$(_mock_manager_get_context "error_test")

  if [[ -n "$context" ]]; then
    case "$error_type" in
      "build_fail")
        echo "ERROR: Build failed with exit code 1"
        return 1
        ;;
      "container_fail")
        echo "ERROR: Container launch failed"
        return 1
        ;;
      "artifact_fail")
        echo "ERROR: Artifact extraction failed"
        return 1
        ;;
      "image_build_fail")
        echo "ERROR: Failed to build Docker image"
        return 1
        ;;
      *)
        echo "ERROR: Unknown error type: $error_type"
        return 1
        ;;
    esac
  else
    echo "Mock Docker run output"
    return 0
  fi
}

# Generate parallel execution response
# Arguments:
#   operation_count: Number of parallel operations
# Returns: Response indicating parallel execution
generate_parallel_response() {
  local operation_count="${1:-1}"

  # Check if this is a parallel test
  local context
  context=$(_mock_manager_get_context "parallel_test")

  if [[ -n "$context" ]]; then
    echo "Executed $operation_count operations in parallel"
  else
    echo "Mock Docker run output"
  fi
}

# Generate status tracking response
# Arguments:
#   status: Current status (building, built, failed)
# Returns: Status-aware response
generate_status_response() {
  local status="$1"

  # Check if this is a status test
  local context
  context=$(_mock_manager_get_context "status_test")

  if [[ -n "$context" ]]; then
    echo "Build status: $status"
  else
    echo "Mock Docker run output"
  fi
}
