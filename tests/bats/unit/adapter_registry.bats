#!/usr/bin/env bats

load ../helpers/adapter_registry
load ../helpers/fixtures

# ============================================================================
# Adapter Registration Tests
# ============================================================================

@test "register_adapter with valid adapter succeeds" {
  setup_adapter_registry_test

  # Create a valid mock adapter
  create_valid_mock_adapter "test_adapter"

  # Should succeed
  output=$(run_adapter_registry_register "test_adapter")
  assert_success

  teardown_adapter_registry_test
}

@test "register_adapter with duplicate identifier fails" {
  setup_adapter_registry_test

  # Register first adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Try to register the same adapter again
  run run_adapter_registry_register "test_adapter"
  assert_failure
  assert_adapter_registration_error "$output" "identifier_conflict"

  teardown_adapter_registry_test
}

@test "get_adapter returns registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get the adapter
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_found "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "get_adapter returns null for unregistered adapter" {
  setup_adapter_registry_test

  # Try to get non-existent adapter
  output=$(run_adapter_registry_get "non_existent" 2>&1) || true
  assert_adapter_not_found "$output" "non_existent"

  teardown_adapter_registry_test
}

@test "get_all_adapters returns all registered adapters" {
  setup_adapter_registry_test

  # Register multiple adapters
  create_valid_mock_adapter "adapter1"
  run_adapter_registry_register "adapter1"
  assert_success

  create_valid_mock_adapter "adapter2"
  run_adapter_registry_register "adapter2"
  assert_success

  # Get all adapters
  output=$(run_adapter_registry_get_all)
  assert_all_adapters_returned "$output" "adapter1,adapter2"

  teardown_adapter_registry_test
}

@test "is_registered returns true for registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Check if registered
  output=$(run_adapter_registry_is_registered "test_adapter")
  assert_is_registered "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "is_registered returns false for unregistered adapter" {
  setup_adapter_registry_test

  # Check unregistered adapter
  output=$(run_adapter_registry_is_registered "non_existent")
  assert_is_not_registered "$output" "non_existent"

  teardown_adapter_registry_test
}

@test "get_adapters_by_capability returns matching adapters" {
  setup_adapter_registry_test

  # Register adapters with different capabilities
  create_valid_mock_adapter_with_capability "adapter1" "parallel"
  run_adapter_registry_register "adapter1"
  assert_success

  create_valid_mock_adapter_with_capability "adapter2" "coverage"
  run_adapter_registry_register "adapter2"
  assert_success

  create_valid_mock_adapter_with_capability "adapter3" "parallel"
  run_adapter_registry_register "adapter3"
  assert_success

  # Get adapters by capability
  output=$(run_adapter_registry_get_by_capability "parallel")
  assert_adapters_by_capability "$output" "parallel" "adapter1,adapter3"

  teardown_adapter_registry_test
}

# ============================================================================
# Interface Enforcement Tests
# ============================================================================

@test "register_adapter rejects adapter missing detect method" {
  setup_adapter_registry_test

  # Create invalid adapter missing detect method
  create_invalid_mock_adapter "missing_detect"

  # Should fail
  run run_adapter_registry_register "missing_detect"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter rejects adapter missing discover_test_suites method" {
  setup_adapter_registry_test

  # Create invalid adapter missing discover method
  create_invalid_mock_adapter "missing_discover"

  # Should fail
  run run_adapter_registry_register "missing_discover"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter rejects adapter missing get_metadata method" {
  setup_adapter_registry_test

  # Create invalid adapter missing metadata method
  create_invalid_mock_adapter "missing_metadata"

  # Should fail
  run run_adapter_registry_register "missing_metadata"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_interface"

  teardown_adapter_registry_test
}

@test "register_adapter accepts adapter with complete interface" {
  setup_adapter_registry_test

  # Create adapter with complete interface
  create_complete_mock_adapter "complete_adapter"

  # Should succeed
  output=$(run_adapter_registry_register "complete_adapter")
  assert_success

  teardown_adapter_registry_test
}

# ============================================================================
# Built-in Adapters Tests
# ============================================================================

@test "built-in BATS adapter is registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Check BATS adapter is registered
  output=$(run_adapter_registry_is_registered "bats")
  assert_is_registered "$output" "bats"

  teardown_adapter_registry_test
}

@test "built-in Rust adapter is registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Check Rust adapter is registered
  output=$(run_adapter_registry_is_registered "rust")
  assert_is_registered "$output" "rust"

  teardown_adapter_registry_test
}

@test "all built-in adapters are registered on initialization" {
  setup_adapter_registry_test

  # Initialize registry (should register built-in adapters)
  run_adapter_registry_initialize

  # Get all adapters
  output=$(run_adapter_registry_get_all)
  assert_builtin_adapters_present "$output"

  teardown_adapter_registry_test
}

# ============================================================================
# Metadata Management Tests
# ============================================================================

@test "get_adapter returns correct metadata for registered adapter" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get adapter and check metadata
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_metadata "$output" "test_adapter" "name" "Test Adapter"
  assert_adapter_metadata "$output" "test_adapter" "identifier" "test_adapter"
  assert_adapter_metadata "$output" "test_adapter" "version" "1.0.0"

  teardown_adapter_registry_test
}

@test "adapter metadata includes required fields" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "test_adapter"
  run_adapter_registry_register "test_adapter"
  assert_success

  # Get adapter and check required metadata fields
  output=$(run_adapter_registry_get "test_adapter")
  assert_adapter_metadata_structure "$output" "test_adapter"

  teardown_adapter_registry_test
}

@test "adapter metadata includes capabilities array" {
  setup_adapter_registry_test

  # Register an adapter with capabilities
  create_valid_mock_adapter_with_capability "capability_adapter" "parallel"
  run_adapter_registry_register "capability_adapter"
  assert_success

  # Check capabilities metadata
  output=$(run_adapter_registry_get "capability_adapter")
  assert_adapter_capabilities "$output" "capability_adapter" "parallel"

  teardown_adapter_registry_test
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "register_adapter with invalid metadata fails gracefully" {
  setup_adapter_registry_test

  # Create adapter with invalid metadata
  create_invalid_metadata_adapter "bad_metadata"

  # Should fail
  run run_adapter_registry_register "bad_metadata"
  assert_failure
  assert_adapter_registration_error "$output" "invalid_metadata"

  teardown_adapter_registry_test
}

@test "get_adapter handles adapter not found gracefully" {
  setup_adapter_registry_test

  # Try to get non-existent adapter
  output=$(run_adapter_registry_get "does_not_exist" 2>&1) || true
  assert_adapter_not_found "$output" "does_not_exist"

  teardown_adapter_registry_test
}

@test "register_adapter with null adapter fails gracefully" {
  setup_adapter_registry_test

  # Try to register null adapter
  run run_adapter_registry_register ""
  assert_failure
  assert_adapter_registration_error "$output" "null_adapter"

  teardown_adapter_registry_test
}

@test "register_adapter with existing identifier fails gracefully" {
  setup_adapter_registry_test

  # Register first adapter
  create_valid_mock_adapter "duplicate_test"
  run_adapter_registry_register "duplicate_test"
  assert_success

  # Try to register the same adapter again
  run run_adapter_registry_register "duplicate_test"
  assert_failure
  assert_adapter_registration_error "$output" "identifier_conflict"

  teardown_adapter_registry_test
}

# ============================================================================
# Lifecycle Tests
# ============================================================================

@test "adapter registry initializes successfully" {
  setup_adapter_registry_test

  # Initialize registry
  output=$(run_adapter_registry_initialize)
  assert_success
  assert_registry_initialized "$output"

  teardown_adapter_registry_test
}

@test "adapter registry cleanup removes all registered adapters" {
  setup_adapter_registry_test

  # Register some adapters
  create_valid_mock_adapter "cleanup_test1"
  run_adapter_registry_register "cleanup_test1"
  assert_success

  create_valid_mock_adapter "cleanup_test2"
  run_adapter_registry_register "cleanup_test2"
  assert_success

  # Cleanup registry
  run_adapter_registry_cleanup
  assert_success

  # Verify adapters are removed
  output=$(run_adapter_registry_get_all)
  assert_no_adapters_registered "$output"

  teardown_adapter_registry_test
}

@test "adapter registry handles multiple initialize calls" {
  setup_adapter_registry_test

  # Initialize multiple times
  run_adapter_registry_initialize
  assert_success

  run_adapter_registry_initialize
  assert_success

  # Should still have built-in adapters
  output=$(run_adapter_registry_is_registered "bats")
  assert_is_registered "$output" "bats"

  teardown_adapter_registry_test
}

# ============================================================================
# Performance and Edge Case Tests
# ============================================================================

@test "adapter registry handles large number of adapters" {
  setup_adapter_registry_test

  # Register many adapters (simulate large registry)
  for i in {1..10}; do
    create_valid_mock_adapter "adapter_$i"
    run_adapter_registry_register "adapter_$i"
    assert_success
  done

  # Verify all are registered
  output=$(run_adapter_registry_get_all)
  assert_adapter_count "$output" "10"

  teardown_adapter_registry_test
}

@test "adapter registry handles concurrent registration attempts" {
  setup_adapter_registry_test

  # Simulate concurrent registration (sequential for now, but tests the logic)
  create_valid_mock_adapter "concurrent1"
  create_valid_mock_adapter "concurrent2"

  run_adapter_registry_register "concurrent1"
  assert_success

  run_adapter_registry_register "concurrent2"
  assert_success

  # Both should be registered
  output=$(run_adapter_registry_get_all)
  assert_all_adapters_returned "$output" "concurrent1,concurrent2"

  teardown_adapter_registry_test
}

@test "adapter registry preserves adapter order" {
  setup_adapter_registry_test

  # Register adapters in specific order
  create_valid_mock_adapter "first"
  run_adapter_registry_register "first"
  assert_success

  create_valid_mock_adapter "second"
  run_adapter_registry_register "second"
  assert_success

  create_valid_mock_adapter "third"
  run_adapter_registry_register "third"
  assert_success

  # Verify order is preserved
  output=$(run_adapter_registry_get_all)
  assert_adapter_order "$output" "first,second,third"

  teardown_adapter_registry_test
}
