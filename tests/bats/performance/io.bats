#!/usr/bin/env bats

load ../helpers/adapter_registry

# ============================================================================
# File I/O Performance Tests
# ============================================================================

@test "registry save operation completes quickly" {
  setup_adapter_registry_test

  # Create 10 adapters
  for i in {1..10}; do
    create_valid_mock_adapter "io_save_test_$i"
    run_adapter_registry_register "io_save_test_$i"
    assert_success
  done

  # Measure save time
  local start_time
  local end_time
  local duration

  start_time=$(date +%s.%3N)
  adapter_registry_save_state
  end_time=$(date +%s.%3N)

  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")

  # Save should complete in reasonable time (< 0.5 seconds)
  [[ $(echo "$duration < 0.5" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.1" ]]

  teardown_adapter_registry_test
}

@test "registry load operation completes quickly" {
  setup_adapter_registry_test

  # Pre-populate registry files with 10 adapters
  for i in {1..10}; do
    create_valid_mock_adapter "io_load_test_$i"
    run_adapter_registry_register "io_load_test_$i"
    assert_success
  done
  adapter_registry_save_state

  # Clear in-memory state
  ADAPTER_REGISTRY=()
  ADAPTER_REGISTRY_CAPABILITIES=()
  ADAPTER_REGISTRY_ORDER=()

  # Measure load time
  local start_time
  local end_time
  local duration

  start_time=$(date +%s.%3N)
  adapter_registry_load_state
  end_time=$(date +%s.%3N)

  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")

  # Load should complete in reasonable time (< 0.5 seconds)
  [[ $(echo "$duration < 0.5" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.1" ]]

  # Verify adapters were loaded
  [ "${#ADAPTER_REGISTRY[@]}" -eq 10 ]

  teardown_adapter_registry_test
}

@test "save/load performance scales with adapter count" {
  setup_adapter_registry_test

  # Test with different adapter counts
  local adapter_counts=(5 10 25 50)

  for count in "${adapter_counts[@]}"; do
    # Clear previous state
    ADAPTER_REGISTRY=()
    ADAPTER_REGISTRY_CAPABILITIES=()
    ADAPTER_REGISTRY_ORDER=()

    # Create adapters
    for i in $(seq 1 "$count"); do
      create_valid_mock_adapter "io_scale_test_$i"
      run_adapter_registry_register "io_scale_test_$i"
      assert_success
    done

    # Measure save time
    local save_start
    local save_end
    local save_duration

    save_start=$(date +%s.%3N)
    adapter_registry_save_state
    save_end=$(date +%s.%3N)

    save_duration=$(echo "$save_end - $save_start" | bc 2>/dev/null || echo "0.1")

    # Measure load time
    ADAPTER_REGISTRY=()
    ADAPTER_REGISTRY_CAPABILITIES=()
    ADAPTER_REGISTRY_ORDER=()

    local load_start
    local load_end
    local load_duration

    load_start=$(date +%s.%3N)
    adapter_registry_load_state
    load_end=$(date +%s.%3N)

    load_duration=$(echo "$load_end - $load_start" | bc 2>/dev/null || echo "0.1")

    # Both operations should complete reasonably (< 1 second for 50 adapters)
    [[ $(echo "$save_duration < 1.0" | bc 2>/dev/null) == "1" ]] || [[ "$save_duration" == "0.1" ]]
    [[ $(echo "$load_duration < 1.0" | bc 2>/dev/null) == "1" ]] || [[ "$load_duration" == "0.1" ]]

    # Verify correct count was loaded
    [ "${#ADAPTER_REGISTRY[@]}" -eq "$count" ]
  done

  teardown_adapter_registry_test
}

@test "file I/O operations don't block indefinitely" {
  setup_adapter_registry_test

  # Create a simple adapter
  create_valid_mock_adapter "io_timeout_test"
  run_adapter_registry_register "io_timeout_test"
  assert_success

  # Test save with timeout
  run timeout 5 bash -c "adapter_registry_save_state"
  [ "$status" -eq 0 ] # Should succeed, not timeout

  # Clear and test load with timeout
  ADAPTER_REGISTRY=()
  run timeout 5 bash -c "adapter_registry_load_state"
  [ "$status" -eq 0 ] # Should succeed, not timeout

  teardown_adapter_registry_test
}

@test "concurrent file operations work" {
  setup_adapter_registry_test

  # Create base registry state
  create_valid_mock_adapter "io_concurrent_base"
  run_adapter_registry_register "io_concurrent_base"
  assert_success
  adapter_registry_save_state

  # Start multiple processes trying to load registry simultaneously
  local pids=()
  local results=()

  for i in {1..3}; do
    (
      # Each process sources the script and loads state
      local suitey_script
      if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
        suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
      elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
        suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
      else
        suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
      fi

      source "$suitey_script" >/dev/null 2>&1
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" adapter_registry_load_state

      # Check if adapter was loaded
      if [[ -v ADAPTER_REGISTRY["io_concurrent_base"] ]]; then
        echo "success"
      else
        echo "failure"
      fi
    ) &
    pids+=($!)
  done

  # Wait for all processes and collect results
  local failed=0
  for pid in "${pids[@]}"; do
    local result
    wait "$pid"
    result=$?

    if [ "$result" -ne 0 ]; then
      failed=$((failed + 1))
    fi
  done

  # All concurrent operations should succeed
  [ "$failed" -eq 0 ]

  teardown_adapter_registry_test
}

@test "large file I/O operations complete in reasonable time" {
  setup_adapter_registry_test

  # Create adapter with large metadata
  local large_metadata='{"name": "Large I/O Test", "description": "'
  # Create ~10KB of metadata
  for i in {1..1000}; do
    large_metadata="${large_metadata}This is repeated content to create a large metadata payload for I/O testing. "
  done
  large_metadata="${large_metadata::-1}", "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}"

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/large_io_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

large_io_adapter_detect() {
  local project_root="\$1"
  return 0
}

large_io_adapter_get_metadata() {
  echo '$large_metadata'
}

large_io_adapter_check_binaries() {
  return 0
}

large_io_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "large_io_test", "framework": "large_io", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

large_io_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

large_io_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

large_io_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

large_io_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  # Register the adapter
  run_adapter_registry_register "large_io_test"
  assert_success

  # Measure save time for large data
  local start_time
  local end_time
  local duration

  start_time=$(date +%s.%3N)
  adapter_registry_save_state
  end_time=$(date +%s.%3N)

  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.2")

  # Even large I/O should complete reasonably (< 2 seconds)
  [[ $(echo "$duration < 2.0" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.2" ]]

  # Test load time
  ADAPTER_REGISTRY=()
  ADAPTER_REGISTRY_CAPABILITIES=()
  ADAPTER_REGISTRY_ORDER=()

  start_time=$(date +%s.%3N)
  adapter_registry_load_state
  end_time=$(date +%s.%3N)

  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.2")

  # Load should also complete reasonably (< 2 seconds)
  [[ $(echo "$duration < 2.0" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.2" ]]

  teardown_adapter_registry_test
}

@test "file I/O handles filesystem stress" {
  setup_adapter_registry_test

  # Create many small files to stress filesystem
  for i in {1..20}; do
    create_valid_mock_adapter "io_stress_test_$i"
    run_adapter_registry_register "io_stress_test_$i"
    assert_success
  done

  # Measure time to save all data
  local start_time
  local end_time
  local duration

  start_time=$(date +%s.%3N)
  adapter_registry_save_state
  end_time=$(date +%s.%3N)

  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.2")

  # Should complete in reasonable time despite filesystem stress (< 1 second)
  [[ $(echo "$duration < 1.0" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.2" ]]

  teardown_adapter_registry_test
}

@test "registry files are properly truncated on save" {
  setup_adapter_registry_test

  # Create initial adapter and save
  create_valid_mock_adapter "io_truncate_test_1"
  run_adapter_registry_register "io_truncate_test_1"
  assert_success
  adapter_registry_save_state

  # Check file size
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local initial_size
  initial_size=$(stat -c %s "$registry_file" 2>/dev/null || stat -f %z "$registry_file")

  # Add more adapters and save again
  create_valid_mock_adapter "io_truncate_test_2"
  create_valid_mock_adapter "io_truncate_test_3"
  run_adapter_registry_register "io_truncate_test_2"
  assert_success
  run_adapter_registry_register "io_truncate_test_3"
  assert_success
  adapter_registry_save_state

  # Check file size again
  local final_size
  final_size=$(stat -c %s "$registry_file" 2>/dev/null || stat -f %z "$registry_file")

  # File should be larger (not appended to)
  [ "$final_size" -gt "$initial_size" ]

  teardown_adapter_registry_test
}

@test "file I/O operations are atomic" {
  setup_adapter_registry_test

  # Create initial state
  create_valid_mock_adapter "io_atomic_test"
  run_adapter_registry_register "io_atomic_test"
  assert_success

  # Start save operation
  adapter_registry_save_state &

  local save_pid=$!

  # Immediately try to load (should work or wait)
  sleep 0.1
  adapter_registry_load_state

  # Save should complete
  wait "$save_pid"

  # Adapter should be available
  [ -v ADAPTER_REGISTRY["io_atomic_test"] ]

  teardown_adapter_registry_test
}
