#!/usr/bin/env bats

load ../helpers/adapter_registry

# ============================================================================
# Memory Usage Performance Tests
# ============================================================================

@test "memory usage with single adapter is reasonable" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Register a single adapter
  create_valid_mock_adapter "memory_test_single"
  run_adapter_registry_register "memory_test_single"
  assert_success

  # Check memory after registration
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable (< 5MB)
  [ "$mem_increase" -lt 5120 ] # 5MB in KB

  teardown_adapter_registry_test
}

@test "memory usage scales reasonably with multiple adapters" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Register 10 adapters
  for i in {1..10}; do
    create_valid_mock_adapter "memory_test_multi_$i"
    run_adapter_registry_register "memory_test_multi_$i"
    assert_success
  done

  # Check memory after registration
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable (< 10MB for 10 adapters)
  [ "$mem_increase" -lt 10240 ] # 10MB in KB

  teardown_adapter_registry_test
}

@test "memory usage with 50 adapters stays within bounds" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Register 50 adapters
  for i in {1..50}; do
    create_valid_mock_adapter "memory_test_50_$i"
    run_adapter_registry_register "memory_test_50_$i"
    assert_success
  done

  # Check memory after registration
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable (< 25MB for 50 adapters)
  [ "$mem_increase" -lt 25600 ] # 25MB in KB

  teardown_adapter_registry_test
}

@test "memory is properly freed when adapters are cleared" {
  setup_adapter_registry_test

  # Register several adapters
  for i in {1..20}; do
    create_valid_mock_adapter "memory_clear_test_$i"
    run_adapter_registry_register "memory_clear_test_$i"
    assert_success
  done

  # Get memory with adapters loaded
  local mem_with_adapters
  mem_with_adapters=$(ps -o rss= $$ | tr -d ' ')

  # Clear the registry (simulate cleanup)
  ADAPTER_REGISTRY=()
  ADAPTER_REGISTRY_CAPABILITIES=()
  ADAPTER_REGISTRY_ORDER=()

  # Get memory after clearing
  local mem_after_clear
  mem_after_clear=$(ps -o rss= $$ | tr -d ' ')

  # Memory should decrease or stay roughly the same
  local mem_decrease
  mem_decrease=$((mem_with_adapters - mem_after_clear))

  # Should not have increased significantly (allow for some variance)
  [ "$mem_decrease" -ge -1024 ] # Allow 1MB variance

  teardown_adapter_registry_test
}

@test "memory usage doesn't grow with repeated operations" {
  setup_adapter_registry_test

  local mem_measurements=()
  local iterations=5

  # Perform repeated register/get cycles
  for i in {1..5}; do
    # Register adapter
    create_valid_mock_adapter "memory_cycle_test_$i"
    run_adapter_registry_register "memory_cycle_test_$i"
    assert_success

    # Get adapter
    run_adapter_registry_get "memory_cycle_test_$i"
    assert_success

    # Measure memory
    local current_mem
    current_mem=$(ps -o rss= $$ | tr -d ' ')
    mem_measurements+=("$current_mem")

    # Clear for next iteration
    ADAPTER_REGISTRY=()
    ADAPTER_REGISTRY_CAPABILITIES=()
    ADAPTER_REGISTRY_ORDER=()
  done

  # Check that memory usage doesn't consistently grow
  local first_measurement="${mem_measurements[0]}"
  local last_measurement="${mem_measurements[-1]}"

  local mem_growth
  mem_growth=$((last_measurement - first_measurement))

  # Memory growth should be minimal (< 2MB over 5 iterations)
  [ "$mem_growth" -lt 2048 ] # 2MB in KB

  teardown_adapter_registry_test
}

@test "large JSON metadata doesn't cause excessive memory usage" {
  setup_adapter_registry_test

  # Create adapter with large metadata
  local large_metadata='{"name": "Large Metadata Test", "description": "'
  # Add ~1KB of content
  for i in {1..100}; do
    large_metadata="${large_metadata}This is some repeated content to make the metadata larger. "
  done
  large_metadata="${large_metadata::-1}", "capabilities": ["test"], "required_binaries": ["test"], "configuration_files": ["test.json"], "test_file_patterns": ["test_*"], "test_directory_patterns": ["tests/"]}"

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/large_metadata_test"
  mkdir -p "$adapter_dir"

  # Create adapter with large metadata
  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

large_metadata_adapter_detect() {
  local project_root="\$1"
  return 0
}

large_metadata_adapter_get_metadata() {
  echo '$large_metadata'
}

large_metadata_adapter_check_binaries() {
  return 0
}

large_metadata_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "large_test", "framework": "large_metadata", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

large_metadata_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

large_metadata_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

large_metadata_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

large_metadata_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Register the adapter
  run_adapter_registry_register "large_metadata_test"
  assert_success

  # Check memory after registration
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable even with large metadata (< 10MB)
  [ "$mem_increase" -lt 10240 ] # 10MB in KB

  teardown_adapter_registry_test
}

@test "memory usage with associative arrays is efficient" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Create many entries in associative arrays
  for i in {1..100}; do
    ADAPTER_REGISTRY["test_key_$i"]="test_value_$i"
    ADAPTER_REGISTRY_CAPABILITIES["capability_$i"]="adapter_$i"
  done

  # Check memory after creating arrays
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory for 200 associative array entries should be reasonable (< 5MB)
  [ "$mem_increase" -lt 5120 ] # 5MB in KB

  teardown_adapter_registry_test
}

@test "memory usage doesn't leak with error conditions" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Attempt operations that might fail
  for i in {1..10}; do
    # Try to register without creating adapter (should fail)
    run_adapter_registry_register "nonexistent_adapter_$i"
    # Don't assert - we expect this to fail

    # Try to get non-existent adapter
    run_adapter_registry_get "nonexistent_adapter_$i"
    # Don't assert - we expect this to fail
  done

  # Check memory after error conditions
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory should not grow significantly due to error handling (< 2MB)
  [ "$mem_increase" -lt 2048 ] # 2MB in KB

  teardown_adapter_registry_test
}

@test "memory usage with file operations is reasonable" {
  setup_adapter_registry_test

  # Get baseline memory
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Perform file operations (save/load state)
  for i in {1..10}; do
    create_valid_mock_adapter "file_memory_test_$i"
    run_adapter_registry_register "file_memory_test_$i"
    assert_success
  done

  # Force save/load operations
  adapter_registry_save_state
  adapter_registry_load_state

  # Check memory after file operations
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory should remain reasonable (< 15MB total for 10 adapters + file ops)
  [ "$mem_increase" -lt 15360 ] # 15MB in KB

  teardown_adapter_registry_test
}
