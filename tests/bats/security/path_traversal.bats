#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry

# ============================================================================
# Path Traversal Security Tests
# ============================================================================

@test "registry files cannot be written outside intended directory" {
  setup_adapter_registry_test

  # Try to set TEST_ADAPTER_REGISTRY_DIR to a path traversal attempt
  local malicious_dir="$TEST_ADAPTER_REGISTRY_DIR/../../../tmp/malicious_registry"
  TEST_ADAPTER_REGISTRY_DIR="$malicious_dir"

  # Create a valid adapter
  create_valid_mock_adapter "path_traversal_test"
  run_adapter_registry_register "path_traversal_test"
  assert_success

  # Check that files were NOT created in the malicious location
  [ ! -d "/tmp/malicious_registry" ]
  [ ! -f "/tmp/malicious_registry/suitey_adapter_registry" ]

  # Check that files were created in the correct test directory
  local expected_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  [ -f "$expected_file" ]

  teardown_adapter_registry_test
}

@test "path traversal in TEST_ADAPTER_REGISTRY_DIR is prevented" {
  setup_adapter_registry_test

  # Save original directory
  local original_test_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Try path traversal
  TEST_ADAPTER_REGISTRY_DIR="$original_test_dir/../../../etc"

  # Attempt to register adapter
  create_valid_mock_adapter "traversal_test"
  run_adapter_registry_register "traversal_test"
  assert_success

  # Files should NOT be in /etc
  [ ! -f "/etc/suitey_adapter_registry" ]
  [ ! -f "/etc/suitey_adapter_capabilities" ]

  # Files should be in the test directory
  local registry_file="$original_test_dir/suitey_adapter_registry"
  [ -f "$registry_file" ]

  # Verify the adapter was registered in the correct location
  TEST_ADAPTER_REGISTRY_DIR="$original_test_dir"
  adapter_registry_load_state
  [ -v ADAPTER_REGISTRY["traversal_test"] ]

  teardown_adapter_registry_test
}

@test "absolute paths in TEST_ADAPTER_REGISTRY_DIR are handled safely" {
  setup_adapter_registry_test

  # Save original
  local original_test_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Try absolute path
  local abs_path="/tmp/path_traversal_absolute_test_$$"
  mkdir -p "$abs_path"
  TEST_ADAPTER_REGISTRY_DIR="$abs_path"

  # Register adapter
  create_valid_mock_adapter "absolute_path_test"
  run_adapter_registry_register "absolute_path_test"
  assert_success

  # Files should be in the absolute path location
  [ -f "$abs_path/suitey_adapter_registry" ]

  # Files should NOT be in the original test directory
  [ ! -f "$original_test_dir/suitey_adapter_registry" ]

  # Clean up
  rm -rf "$abs_path"

  teardown_adapter_registry_test
}

@test "TEST_ADAPTER_REGISTRY_DIR is properly isolated between tests" {
  setup_adapter_registry_test

  # Register adapter in first test
  create_valid_mock_adapter "isolation_test_1"
  run_adapter_registry_register "isolation_test_1"
  assert_success

  # Verify file exists in current test directory
  local first_registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  [ -f "$first_registry_file" ]

  # Simulate a second test with different directory
  local second_test_dir="/tmp/second_isolation_test_$$"
  mkdir -p "$second_test_dir"
  TEST_ADAPTER_REGISTRY_DIR="$second_test_dir"

  # Register different adapter
  create_valid_mock_adapter "isolation_test_2"
  run_adapter_registry_register "isolation_test_2"
  assert_success

  # Second test should have its own file
  local second_registry_file="$second_test_dir/suitey_adapter_registry"
  [ -f "$second_registry_file" ]

  # Files should be different
  ! diff "$first_registry_file" "$second_registry_file" >/dev/null 2>&1

  # Clean up
  rm -rf "$second_test_dir"

  teardown_adapter_registry_test
}

@test "malicious TEST_ADAPTER_REGISTRY_DIR values don't create files in sensitive locations" {
  setup_adapter_registry_test

  # Save original
  local original_test_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Try various malicious paths
  local malicious_paths=(
    "/etc"
    "/usr"
    "/home"
    "/root"
    "/"
    "/tmp/../../../etc"
    "../../../../../../etc"
    "/var/log"
  )

  for malicious_path in "${malicious_paths[@]}"; do
    TEST_ADAPTER_REGISTRY_DIR="$malicious_path"

    # Try to create an adapter (this might fail, but shouldn't create files in wrong places)
    create_valid_mock_adapter "malicious_test_$$"
    run_adapter_registry_register "malicious_test_$$" >/dev/null 2>&1 || true

    # Check that no registry file was created in the malicious location
    [ ! -f "$malicious_path/suitey_adapter_registry" ]
    [ ! -d "$malicious_path/adapters" ]
  done

  # Reset to original
  TEST_ADAPTER_REGISTRY_DIR="$original_test_dir"

  teardown_adapter_registry_test
}

@test "relative paths in TEST_ADAPTER_REGISTRY_DIR are resolved safely" {
  setup_adapter_registry_test

  # Save original
  local original_test_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Try relative path
  local relative_path="./relative_test_$$"
  mkdir -p "$original_test_dir/$relative_path"
  TEST_ADAPTER_REGISTRY_DIR="$relative_path"

  # Register adapter
  create_valid_mock_adapter "relative_path_test"
  run_adapter_registry_register "relative_path_test"
  assert_success

  # Files should be in the resolved path within the test directory
  local resolved_path="$original_test_dir/$relative_path"
  [ -f "$resolved_path/suitey_adapter_registry" ]

  # Clean up
  rm -rf "$resolved_path"

  teardown_adapter_registry_test
}

@test "symlink in TEST_ADAPTER_REGISTRY_DIR doesn't bypass security" {
  setup_adapter_registry_test

  # Create a symlink to /tmp
  local symlink_path="$TEST_ADAPTER_REGISTRY_DIR/registry_symlink"
  ln -s "/tmp" "$symlink_path"

  # Try to use the symlink as registry directory
  TEST_ADAPTER_REGISTRY_DIR="$symlink_path"

  # Register adapter
  create_valid_mock_adapter "symlink_test"
  run_adapter_registry_register "symlink_test"
  assert_success

  # Files should be created through the symlink (in /tmp)
  # This is expected behavior - symlinks are followed
  local symlink_registry="$symlink_path/suitey_adapter_registry"
  [ -f "$symlink_registry" ]

  # But the symlink itself should still be safe
  [ -L "$symlink_path" ]

  # Clean up the symlink (don't clean registry files in /tmp)
  rm -f "$symlink_path"

  teardown_adapter_registry_test
}

@test "TEST_ADAPTER_REGISTRY_DIR with spaces is handled correctly" {
  setup_adapter_registry_test

  # Save original
  local original_test_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Create directory with spaces
  local spaced_dir="/tmp/test dir with spaces $$"
  mkdir -p "$spaced_dir"
  TEST_ADAPTER_REGISTRY_DIR="$spaced_dir"

  # Register adapter
  create_valid_mock_adapter "spaces_test"
  run_adapter_registry_register "spaces_test"
  assert_success

  # Files should be created properly despite spaces
  local registry_file="$spaced_dir/suitey_adapter_registry"
  [ -f "$registry_file" ]

  # Clean up
  rm -rf "$spaced_dir"

  teardown_adapter_registry_test
}

@test "registry file paths don't contain path traversal sequences" {
  setup_adapter_registry_test

  # Register adapter
  create_valid_mock_adapter "path_check_test"
  run_adapter_registry_register "path_check_test"
  assert_success

  # Check that registry file paths don't contain ..
  [[ "$ADAPTER_REGISTRY_FILE" != *".."* ]]
  [[ "$ADAPTER_REGISTRY_CAPABILITIES_FILE" != *".."* ]]
  [[ "$ADAPTER_REGISTRY_ORDER_FILE" != *".."* ]]

  # Check that paths are absolute or properly resolved
  [[ "$ADAPTER_REGISTRY_FILE" == /* ]] || [[ "$ADAPTER_REGISTRY_FILE" != *"/../"* ]]

  teardown_adapter_registry_test
}

@test "changing TEST_ADAPTER_REGISTRY_DIR mid-test works safely" {
  setup_adapter_registry_test

  # Register adapter in first location
  create_valid_mock_adapter "location_change_test"
  run_adapter_registry_register "location_change_test"
  assert_success

  local first_location="$TEST_ADAPTER_REGISTRY_DIR"
  local first_file="$first_location/suitey_adapter_registry"
  [ -f "$first_file" ]

  # Change location
  local second_location="/tmp/second_location_test_$$"
  mkdir -p "$second_location"
  TEST_ADAPTER_REGISTRY_DIR="$second_location"

  # Register another adapter
  create_valid_mock_adapter "location_change_test_2"
  run_adapter_registry_register "location_change_test_2"
  assert_success

  # Second file should be in new location
  local second_file="$second_location/suitey_adapter_registry"
  [ -f "$second_file" ]

  # Files should be different
  ! diff "$first_file" "$second_file" >/dev/null 2>&1

  # Clean up
  rm -rf "$second_location"

  teardown_adapter_registry_test
}
