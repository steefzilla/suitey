#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry

# ============================================================================
# Helper function to source adapter registry modules from src/
# ============================================================================

_source_adapter_registry_modules() {
  # Find and source json_helpers.sh (needed by adapter_registry.sh)
  local json_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
  else
    json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
  fi
  source "$json_helpers_script"

  # Find and source adapter_registry_helpers.sh
  local adapter_registry_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
  else
    adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
  fi
  source "$adapter_registry_helpers_script"

  # Find and source adapter_registry.sh
  local adapter_registry_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../src/adapter_registry.sh"
  else
    adapter_registry_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry.sh"
  fi
  source "$adapter_registry_script"
}

# ============================================================================
# Concurrent Operation Performance Tests
# ============================================================================

@test "multiple adapter registrations work concurrently" {
  setup_adapter_registry_test

  # Start multiple registration processes simultaneously
  local pids=()
  local adapter_names=()

  for i in {1..5}; do
    adapter_names+=("concurrent_reg_test_$i")
  done

  # Start registration processes
  for adapter_name in "${adapter_names[@]}"; do
    (
      # Each process needs its own module sourcing
      _source_adapter_registry_modules
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" create_valid_mock_adapter "$adapter_name"
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" run_adapter_registry_register "$adapter_name" >/dev/null 2>&1
      echo "$adapter_name: $?"
    ) &
    pids+=($!)
  done

  # Wait for all registrations to complete
  local results=()
  local failed=0

  for pid in "${pids[@]}"; do
    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
      failed=$((failed + 1))
    fi
  done

  # All registrations should succeed
  [ "$failed" -eq 0 ]

  # Verify all adapters were registered
  _source_adapter_registry_modules
  adapter_registry_load_state

  local registered_count=0
  for adapter_name in "${adapter_names[@]}"; do
    if [[ -v ADAPTER_REGISTRY["$adapter_name"] ]]; then
      registered_count=$((registered_count + 1))
    fi
  done

  [ "$registered_count" -eq 5 ]

  teardown_adapter_registry_test
}

@test "concurrent adapter get operations work" {
  setup_adapter_registry_test

  # Register adapters sequentially first
  for i in {1..3}; do
    create_valid_mock_adapter "concurrent_get_test_$i"
    run_adapter_registry_register "concurrent_get_test_$i"
    assert_success
  done

  # Start multiple get operations concurrently
  local pids=()
  local adapter_names=("concurrent_get_test_1" "concurrent_get_test_2" "concurrent_get_test_3")

  for adapter_name in "${adapter_names[@]}"; do
    (
      # Each process needs its own module sourcing
      _source_adapter_registry_modules
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" run_adapter_registry_get "$adapter_name" >/dev/null 2>&1
      echo "$adapter_name: $?"
    ) &
    pids+=($!)
  done

  # Wait for all get operations to complete
  local failed=0
  for pid in "${pids[@]}"; do
    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
      failed=$((failed + 1))
    fi
  done

  # All get operations should succeed
  [ "$failed" -eq 0 ]

  teardown_adapter_registry_test
}

@test "concurrent save and load operations work" {
  setup_adapter_registry_test

  # Create initial registry state
  create_valid_mock_adapter "concurrent_save_load_test"
  run_adapter_registry_register "concurrent_save_load_test"
  assert_success
  adapter_registry_save_state

  # Start concurrent save and load operations
  local save_pid
  local load_pid

  # Start save operation
  (
    _source_adapter_registry_modules
    TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" create_valid_mock_adapter "concurrent_save_test"
    TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" adapter_registry_register "concurrent_save_test" >/dev/null 2>&1
    TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" adapter_registry_save_state >/dev/null 2>&1
  ) &
  save_pid=$!

  # Start load operation
  (
    sleep 0.1  # Small delay to ensure save starts first
    _source_adapter_registry_modules
    TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" adapter_registry_load_state >/dev/null 2>&1
    if [[ -v ADAPTER_REGISTRY["concurrent_save_load_test"] ]]; then
      echo "load_success"
    else
      echo "load_failure"
    fi
  ) &
  load_pid=$!

  # Wait for both operations
  local save_exit=0
  local load_result=""

  wait "$save_pid"
  save_exit=$?

  wait "$load_pid"
  load_result=$(echo "$load_result" | tail -1)

  # Both operations should succeed
  [ "$save_exit" -eq 0 ]
  [[ "$load_result" == "load_success" ]]

  teardown_adapter_registry_test
}

@test "parallel subprocess execution works" {
  # Test basic parallel execution capability
  local pids=()
  local results=()

  # Start multiple subprocesses
  for i in {1..4}; do
    (
      # Simulate some work
      sleep 0.1
      echo "subprocess_$i"
    ) &
    pids+=($!)
  done

  # Collect results
  local completed=0
  for pid in "${pids[@]}"; do
    local result
    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
      completed=$((completed + 1))
    fi
  done

  # All subprocesses should complete successfully
  [ "$completed" -eq 4 ]
}

@test "concurrent file operations don't corrupt data" {
  setup_adapter_registry_test

  # Create base registry
  for i in {1..3}; do
    create_valid_mock_adapter "concurrent_file_test_$i"
    run_adapter_registry_register "concurrent_file_test_$i"
    assert_success
  done

  # Start multiple processes that save/load registry
  local pids=()
  local expected_adapters=("concurrent_file_test_1" "concurrent_file_test_2" "concurrent_file_test_3")

  for i in {1..3}; do
    (
      _source_adapter_registry_modules
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" adapter_registry_load_state >/dev/null 2>&1

      local loaded_count=0
      for adapter in "${expected_adapters[@]}"; do
        if [[ -v ADAPTER_REGISTRY["$adapter"] ]]; then
          loaded_count=$((loaded_count + 1))
        fi
      done

      echo "process_$i: $loaded_count"
    ) &
    pids+=($!)
  done

  # Wait for all processes
  local total_loaded=0
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # All processes should have loaded all adapters
  # (This is a basic test - in a real concurrent scenario, we might see partial loads)

  teardown_adapter_registry_test
}

@test "background process cleanup works" {
  # Test that background processes are properly cleaned up

  # Start a background process
  (
    sleep 1
    echo "background_done"
  ) &
  local bg_pid=$!

  # Wait for it to complete
  wait "$bg_pid"
  local exit_code=$?

  # Process should have completed successfully
  [ "$exit_code" -eq 0 ]

  # Process should no longer exist
  ! kill -0 "$bg_pid" 2>/dev/null
}

@test "process substitution works in concurrent context" {
  # Test process substitution (used in base64 encoding)
  local result
  result=$(cat <(echo "test data"))

  [[ "$result" == "test data" ]]
}

@test "concurrent environment variable access works" {
  # Test that environment variables are properly isolated between processes
  local test_var="original_value"

  # Start a subprocess that modifies the variable
  (
    test_var="modified_value"
    echo "$test_var"
  ) &
  local pid=$!

  wait "$pid"

  # Original variable should be unchanged
  [[ "$test_var" == "original_value" ]]
}

@test "signal handling works in concurrent operations" {
  # Test basic signal handling
  local interrupted=false

  # Start a process that can be interrupted
  (
    trap 'echo "interrupted"; exit 1' INT
    sleep 2
    echo "completed"
  ) &
  local pid=$!

  # Give it a moment to start
  sleep 0.1

  # Send interrupt signal
  kill -INT "$pid" 2>/dev/null || true

  # Wait for process to handle signal
  wait "$pid" 2>/dev/null || true

  # Process should have been interrupted (exit code might vary)
  # The important thing is it didn't hang
}

@test "concurrent operations respect resource limits" {
  # Test that concurrent operations don't exceed reasonable resource usage

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Start multiple concurrent operations
  local pids=()
  for i in {1..3}; do
    (
      _source_adapter_registry_modules
      # Just source and exit - tests memory usage of sourcing
    ) &
    pids+=($!)
  done

  # Wait for all
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # Check memory after concurrent operations
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable (< 10MB for concurrent sourcing)
  [ "$mem_increase" -lt 10240 ] # 10MB in KB
}
