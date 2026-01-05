#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry

# ============================================================================
# File Permission Security Tests
# ============================================================================

@test "registry files have secure permissions" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "permissions_test"
  run_adapter_registry_register "permissions_test"
  assert_success

  # Check registry file permissions
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local perms
  perms=$(stat -c %a "$registry_file" 2>/dev/null || stat -f %A "$registry_file" | cut -c -3)

  # Should not be world-writable (no execute for others, no write for others)
  [[ "$perms" != *"6" ]] && [[ "$perms" != *"7" ]]  # Last digit shouldn't be 6 or 7
}

@test "registry directories have secure permissions" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "dir_permissions_test"
  run_adapter_registry_register "dir_permissions_test"
  assert_success

  # Check test directory permissions
  local perms
  perms=$(stat -c %a "$TEST_ADAPTER_REGISTRY_DIR" 2>/dev/null || stat -f %A "$TEST_ADAPTER_REGISTRY_DIR" | cut -c -3)

  # Directory should be accessible but not world-writable
  [[ "$perms" != *"6" ]] && [[ "$perms" != *"7" ]]  # Last digit shouldn't be 6 or 7
}

@test "adapter script files have appropriate permissions" {
  setup_adapter_registry_test

  # Create and register an adapter
  create_valid_mock_adapter "script_permissions_test"
  run_adapter_registry_register "script_permissions_test"
  assert_success

  # Check adapter script permissions
  local adapter_script="$TEST_ADAPTER_REGISTRY_DIR/adapters/script_permissions_test/adapter.sh"
  [ -f "$adapter_script" ]

  local perms
  perms=$(stat -c %a "$adapter_script" 2>/dev/null || stat -f %A "$adapter_script" | cut -c -3)

  # Should be readable and executable by owner
  [[ "$perms" =~ ^[67][0-7][0-7]$ ]] || [[ "$perms" =~ ^[67][0-7][0-7]$ ]]
}

@test "registry files are owned by current user" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "ownership_test"
  run_adapter_registry_register "ownership_test"
  assert_success

  # Check file ownership
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local file_owner
  file_owner=$(stat -c %U "$registry_file" 2>/dev/null || stat -f %Su "$registry_file")

  local current_user
  current_user=$(whoami)

  [[ "$file_owner" == "$current_user" ]]
}

@test "temporary files created during tests are cleaned up" {
  setup_adapter_registry_test

  # Register multiple adapters to trigger file creation
  for i in {1..3}; do
    create_valid_mock_adapter "cleanup_test_$i"
    run_adapter_registry_register "cleanup_test_$i"
    assert_success
  done

  # Force save operations
  adapter_registry_save_state

  # Check that files exist during test
  [ -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry" ]
  [ -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities" ]
  [ -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order" ]

  # Teardown should clean up
  teardown_adapter_registry_test

  # Files should be gone after teardown
  [ ! -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry" ]
  [ ! -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities" ]
  [ ! -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order" ]
  [ ! -d "$TEST_ADAPTER_REGISTRY_DIR" ]
}

@test "registry files don't contain sensitive information in filenames" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "sensitive_filename_test"
  run_adapter_registry_register "sensitive_filename_test"
  assert_success

  # Check that no filenames contain sensitive patterns
  local files
  mapfile -t files < <(find "$TEST_ADAPTER_REGISTRY_DIR" -type f -name "*" 2>/dev/null)

  for file in "${files[@]}"; do
    # Filenames should not contain passwords, keys, secrets, etc.
    [[ "$(basename "$file")" != *"password"* ]]
    [[ "$(basename "$file")" != *"secret"* ]]
    [[ "$(basename "$file")" != *"key"* ]]
    [[ "$(basename "$file")" != *"token"* ]]
  done

  teardown_adapter_registry_test
}

@test "registry data is not exposed in file metadata" {
  setup_adapter_registry_test

  # Register an adapter with sensitive-looking metadata
  local sensitive_metadata='{"password": "secret123", "token": "abc123def", "key": "private_key_data"}'

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/sensitive_metadata_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

sensitive_metadata_adapter_detect() {
  local project_root="\$1"
  return 0
}

sensitive_metadata_adapter_get_metadata() {
  echo '$sensitive_metadata'
}

sensitive_metadata_adapter_check_binaries() {
  return 0
}

sensitive_metadata_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "sensitive_test", "framework": "sensitive", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

sensitive_metadata_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

sensitive_metadata_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

sensitive_metadata_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

sensitive_metadata_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  run_adapter_registry_register "sensitive_metadata_test"
  assert_success

  # Get file contents
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local content
  content=$(cat "$registry_file")

  # Content should be base64 encoded (not plain text)
  [[ "$content" == *"="* ]] || [[ "$content" =~ ^[A-Za-z0-9+/]+$ ]]

  # Raw sensitive data should not be visible
  [[ "$content" != *"password"* ]]
  [[ "$content" != *"secret123"* ]]
  [[ "$content" != *"token"* ]]
  [[ "$content" != *"private_key_data"* ]]

  teardown_adapter_registry_test
}

@test "directory permissions prevent unauthorized access" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "dir_access_test"
  run_adapter_registry_register "dir_access_test"
  assert_success

  # Check that registry directory is not world-readable/writable
  local dir_perms
  dir_perms=$(stat -c %a "$TEST_ADAPTER_REGISTRY_DIR" 2>/dev/null || stat -f %A "$TEST_ADAPTER_REGISTRY_DIR" | cut -c -3)

  # Should not be world-readable or world-writable
  [[ "$dir_perms" != *"6" ]] && [[ "$dir_perms" != *"7" ]] && [[ "$dir_perms" != *"4" ]] && [[ "$dir_perms" != *"5" ]]

  teardown_adapter_registry_test
}

@test "adapter subdirectories have secure permissions" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "subdir_permissions_test"
  run_adapter_registry_register "subdir_permissions_test"
  assert_success

  # Check adapter subdirectory permissions
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/subdir_permissions_test"
  [ -d "$adapter_dir" ]

  local perms
  perms=$(stat -c %a "$adapter_dir" 2>/dev/null || stat -f %A "$adapter_dir" | cut -c -3)

  # Should not be world-writable
  [[ "$perms" != *"6" ]] && [[ "$perms" != *"7" ]]

  teardown_adapter_registry_test
}

@test "file permissions are consistent across registry files" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "consistent_permissions_test"
  run_adapter_registry_register "consistent_permissions_test"
  assert_success

  # Get permissions of all registry files
  local files=("$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
               "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities"
               "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order")

  local first_perms=""
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      local perms
      perms=$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file" | cut -c -3)

      if [ -z "$first_perms" ]; then
        first_perms="$perms"
      else
        # All files should have same permissions
        [[ "$perms" == "$first_perms" ]]
      fi
    fi
  done

  teardown_adapter_registry_test
}

@test "registry files don't have execute permissions" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "no_execute_test"
  run_adapter_registry_register "no_execute_test"
  assert_success

  # Check that registry files don't have execute permissions
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local perms
  perms=$(stat -c %a "$registry_file" 2>/dev/null || stat -f %A "$registry_file")

  # Should not have execute permissions for user, group, or others
  [[ ! "$perms" =~ [1357].. ]] && [[ ! "$perms" =~ .[1357]. ]] && [[ ! "$perms" =~ ..[1357] ]]

  teardown_adapter_registry_test
}

@test "UMASK is respected during file creation" {
  setup_adapter_registry_test

  # Save original umask
  local original_umask
  original_umask=$(umask)

  # Set restrictive umask
  umask 0077

  # Register an adapter
  create_valid_mock_adapter "umask_test"
  run_adapter_registry_register "umask_test"
  assert_success

  # Check file permissions
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local perms
  perms=$(stat -c %a "$registry_file" 2>/dev/null || stat -f %A "$registry_file" | cut -c -3)

  # Should be very restrictive (0600 or similar)
  [[ "$perms" == "600" ]] || [[ "$perms" == "-rw-------" ]]

  # Restore original umask
  umask "$original_umask"

  teardown_adapter_registry_test
}
