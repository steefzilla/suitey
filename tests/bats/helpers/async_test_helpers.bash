#!/usr/bin/env bash
# Async Operation Support for Build Manager Tests
# Provides background execution, signal handling, and cleanup verification

# ============================================================================
# Async Operation Support
# ============================================================================

# Global variables for async operations
declare -a ASYNC_PIDS=()
declare -a ASYNC_OPERATIONS=()
ASYNC_OPERATION_ID=0

# Run an operation asynchronously in the background
# Arguments:
#   operation_name: Name/identifier for the operation
#   command: Command to execute asynchronously
# Returns: Operation ID for tracking
run_async_operation() {
  local operation_name="$1"
  local command="$2"

  # Initialize mock manager if needed
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "async_test"
  fi

  # Generate operation ID
  local operation_id=$((ASYNC_OPERATION_ID++))
  local pid_file="/tmp/async_operation_${operation_id}.pid"
  local status_file="/tmp/async_operation_${operation_id}.status"

  # Store operation info
  ASYNC_OPERATIONS[$operation_id]="$operation_name"
  echo "running" > "$status_file"

  # Execute command in background
  (
    # Run the command
    eval "$command"
    local exit_code=$?

    # Update status
    if [[ $exit_code -eq 0 ]]; then
      echo "completed" > "$status_file"
    else
      echo "failed:$exit_code" > "$status_file"
    fi

    # Clean up PID file
    rm -f "$pid_file"
  ) &
  local pid=$!

  # Store PID
  echo $pid > "$pid_file"
  ASYNC_PIDS[$operation_id]=$pid

  # Update mock state
  _mock_manager_update_state "async_operation_${operation_id}" "running:$pid"

  echo "$operation_id"
}

# Simulate sending a signal to an async operation
# Arguments:
#   operation_id: ID of the operation to signal
#   signal: Signal to send (default: TERM)
# Returns: 0 on success, 1 if operation not found
simulate_signal() {
  local operation_id="$1"
  local signal="${2:-TERM}"

  if [[ ! -v ASYNC_PIDS[$operation_id] ]]; then
    echo "ERROR: Async operation $operation_id not found" >&2
    return 1
  fi

  local pid="${ASYNC_PIDS[$operation_id]}"
  local pid_file="/tmp/async_operation_${operation_id}.pid"

  if [[ -f "$pid_file" ]] && kill -"$signal" "$pid" 2>/dev/null; then
    # Update status to indicate signal was sent
    local status_file="/tmp/async_operation_${operation_id}.status"
    echo "signaled:$signal" > "$status_file"

    # Update mock state
    _mock_manager_update_state "async_operation_${operation_id}" "signaled:$signal"

    return 0
  else
    echo "ERROR: Failed to send signal $signal to operation $operation_id" >&2
    return 1
  fi
}

# Wait for an async operation to complete
# Arguments:
#   operation_id: ID of the operation to wait for
#   timeout: Maximum time to wait in seconds (default: 30)
# Returns: 0 if completed successfully, 1 if failed or timed out
wait_for_operation() {
  local operation_id="$1"
  local timeout="${2:-30}"

  if [[ ! -v ASYNC_PIDS[$operation_id] ]]; then
    echo "ERROR: Async operation $operation_id not found" >&2
    return 1
  fi

  local pid="${ASYNC_PIDS[$operation_id]}"
  local status_file="/tmp/async_operation_${operation_id}.status"
  local start_time=$(date +%s)

  # Wait for completion or timeout
  while [[ $(date +%s) -lt $((start_time + timeout)) ]]; do
    if [[ ! -f "$status_file" ]]; then
      sleep 0.1
      continue
    fi

    local status
    status=$(cat "$status_file")

    case "$status" in
      "completed")
        _mock_manager_update_state "async_operation_${operation_id}" "completed"
        return 0
        ;;
      "failed:"*)
        local exit_code="${status#failed:}"
        _mock_manager_update_state "async_operation_${operation_id}" "failed:$exit_code"
        return 1
        ;;
      "signaled:"*)
        _mock_manager_update_state "async_operation_${operation_id}" "$status"
        return 0  # Signal handling is considered successful completion
        ;;
      *)
        sleep 0.1
        ;;
    esac
  done

  echo "ERROR: Operation $operation_id timed out after ${timeout}s" >&2
  return 1
}

# Verify cleanup of async operations and resources
# Arguments:
#   operation_id: ID of the operation to verify cleanup for
# Returns: 0 if properly cleaned up, 1 if resources still exist
verify_cleanup() {
  local operation_id="$1"

  local pid_file="/tmp/async_operation_${operation_id}.pid"
  local status_file="/tmp/async_operation_${operation_id}.status"
  local log_file="/tmp/async_operation_${operation_id}.log"

  local cleanup_status=0

  # Check if PID file still exists
  if [[ -f "$pid_file" ]]; then
    echo "ERROR: PID file still exists: $pid_file" >&2
    cleanup_status=1
  fi

  # Check if status file still exists
  if [[ -f "$status_file" ]]; then
    echo "ERROR: Status file still exists: $status_file" >&2
    cleanup_status=1
  fi

  # Check if log file exists (should be cleaned up)
  if [[ -f "$log_file" ]]; then
    echo "ERROR: Log file still exists: $log_file" >&2
    cleanup_status=1
  fi

  # Check if process is still running
  if [[ -v ASYNC_PIDS[$operation_id] ]]; then
    local pid="${ASYNC_PIDS[$operation_id]}"
    if kill -0 "$pid" 2>/dev/null; then
      echo "ERROR: Process $pid is still running" >&2
      cleanup_status=1
    fi
  fi

  # Update mock state
  if [[ $cleanup_status -eq 0 ]]; then
    _mock_manager_update_state "async_cleanup_${operation_id}" "clean"
  else
    _mock_manager_update_state "async_cleanup_${operation_id}" "incomplete"
  fi

  return $cleanup_status
}

# Clean up all async operation resources
# Should be called in teardown
cleanup_async_operations() {
  # Kill any remaining processes
  for pid in "${ASYNC_PIDS[@]}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
      sleep 0.1
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  # Clean up temporary files
  rm -f /tmp/async_operation_*.pid
  rm -f /tmp/async_operation_*.status
  rm -f /tmp/async_operation_*.log

  # Reset arrays
  ASYNC_PIDS=()
  ASYNC_OPERATIONS=()
  ASYNC_OPERATION_ID=0
}

# ============================================================================
# Signal Handling Simulation
# ============================================================================

# Simulate build interruption scenario
# Arguments:
#   operation_id: ID of operation to interrupt
#   interrupt_delay: Seconds to wait before sending interrupt (default: 1)
simulate_build_interruption() {
  local operation_id="$1"
  local interrupt_delay="${2:-1}"

  # Start the operation
  echo "Starting build operation..."

  # Wait a bit, then interrupt
  (
    sleep "$interrupt_delay"
    echo "Sending interrupt signal..."
    simulate_signal "$operation_id" "INT"
  ) &

  # Return operation ID
  echo "$operation_id"
}

# Simulate graceful shutdown scenario
# Arguments:
#   operation_ids: Array of operation IDs to shut down gracefully
simulate_graceful_shutdown() {
  local operation_ids=("$@")

  echo "Initiating graceful shutdown..."

  # Send TERM signal to all operations
  for operation_id in "${operation_ids[@]}"; do
    simulate_signal "$operation_id" "TERM"
  done

  # Wait for completion
  local all_completed=true
  for operation_id in "${operation_ids[@]}"; do
    if ! wait_for_operation "$operation_id" 5; then
      all_completed=false
    fi
  done

  if [[ "$all_completed" == "true" ]]; then
    echo "Graceful shutdown completed"
    return 0
  else
    echo "Some operations did not shut down gracefully"
    return 1
  fi
}

# Simulate forceful termination scenario
# Arguments:
#   operation_ids: Array of operation IDs to terminate forcefully
simulate_forceful_termination() {
  local operation_ids=("$@")

  echo "Initiating forceful termination..."

  # Send KILL signal to all operations
  for operation_id in "${operation_ids[@]}"; do
    simulate_signal "$operation_id" "KILL"
  done

  # Verify all processes are gone
  sleep 0.5

  local all_terminated=true
  for operation_id in "${operation_ids[@]}"; do
    if [[ -v ASYNC_PIDS[$operation_id] ]]; then
      local pid="${ASYNC_PIDS[$operation_id]}"
      if kill -0 "$pid" 2>/dev/null; then
        all_terminated=false
      fi
    fi
  done

  if [[ "$all_terminated" == "true" ]]; then
    echo "Forceful termination completed"
    return 0
  else
    echo "Some processes could not be terminated"
    return 1
  fi
}

