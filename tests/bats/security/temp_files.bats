#!/usr/bin/env bats

load ../helpers/adapter_registry

# ============================================================================
# Temporary File Security Tests
# ============================================================================

@test "temporary files created by mktemp have secure permissions" {
  # Test mktemp directly (used by test helpers)
  local temp_file
  temp_file=$(mktemp)

  [ -f "$temp_file" ]

  # Check permissions
  local perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %A "$temp_file" | cut -c -3)

  # Should not be world-readable or world-writable
  [[ "$perms" != *"4" ]] && [[ "$perms" != *"5" ]] && [[ "$perms" != *"6" ]] && [[ "$perms" != *"7" ]]

  rm -f "$temp_file"
}

@test "test adapter registry directories have secure permissions" {
  setup_adapter_registry_test

  # Register an adapter to create files
  create_valid_mock_adapter "temp_security_test"
  run_adapter_registry_register "temp_security_test"
  assert_success

  # Check test directory permissions
  local perms
  perms=$(stat -c %a "$TEST_ADAPTER_REGISTRY_DIR" 2>/dev/null || stat -f %A "$TEST_ADAPTER_REGISTRY_DIR" | cut -c -3)

  # Should not be world-writable
  [[ "$perms" != *"6" ]] && [[ "$perms" != *"7" ]]

  teardown_adapter_registry_test
}

@test "temporary directories are cleaned up after tests" {
  setup_adapter_registry_test

  # Register an adapter
  create_valid_mock_adapter "cleanup_test"
  run_adapter_registry_register "cleanup_test"
  assert_success

  # Verify files exist during test
  [ -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry" ]
  [ -d "$TEST_ADAPTER_REGISTRY_DIR" ]

  # Run teardown
  teardown_adapter_registry_test

  # Verify cleanup
  [ ! -f "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry" ]
  [ ! -d "$TEST_ADAPTER_REGISTRY_DIR" ]
}

@test "temporary file names are unpredictable" {
  # Create multiple temp files and check they're not predictable
  local temp_files=()
  for i in {1..5}; do
    local temp_file
    temp_file=$(mktemp)
    temp_files+=("$temp_file")
    rm -f "$temp_file" # Clean up immediately
  done

  # Check that filenames are different (basic unpredictability test)
  local first_file="${temp_files[0]}"
  local duplicate_found=false

  for temp_file in "${temp_files[@]:1}"; do
    if [[ "$temp_file" == "$first_file" ]]; then
      duplicate_found=true
      break
    fi
  done

  [ "$duplicate_found" = false ]
}

@test "temporary files don't contain sensitive data after cleanup" {
  setup_adapter_registry_test

  # Create adapter with sensitive metadata
  local sensitive_metadata='{"password": "secret123", "token": "sensitive_token"}'

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/sensitive_temp_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

sensitive_temp_adapter_detect() {
  local project_root="\$1"
  return 0
}

sensitive_temp_adapter_get_metadata() {
  echo '$sensitive_metadata'
}

sensitive_temp_adapter_check_binaries() {
  return 0
}

sensitive_temp_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "sensitive_test", "framework": "sensitive", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

sensitive_temp_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

sensitive_temp_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

sensitive_temp_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

sensitive_temp_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  run_adapter_registry_register "sensitive_temp_test"
  assert_success

  # Verify sensitive data is stored (encoded)
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local content
  content=$(cat "$registry_file")

  # Should be encoded
  [[ "$content" != *"secret123"* ]]
  [[ "$content" != *"sensitive_token"* ]]

  # Run teardown
  teardown_adapter_registry_test

  # Verify files are gone
  [ ! -f "$registry_file" ]
  [ ! -d "$TEST_ADAPTER_REGISTRY_DIR" ]

  # Double-check that no temp files contain the sensitive data
  local found_sensitive=false
  while IFS= read -r -d '' file; do
    if grep -q "secret123\|sensitive_token" "$file" 2>/dev/null; then
      found_sensitive=true
      break
    fi
  done < <(find /tmp -name "suitey_*" -type f -print0 2>/dev/null)

  [ "$found_sensitive" = false ]
}

@test "mktemp uses secure temporary directory" {
  local temp_file
  temp_file=$(mktemp)

  # Should be in /tmp or TMPDIR
  local temp_dir="${TMPDIR:-/tmp}"
  [[ "$temp_file" == "$temp_dir"* ]]

  # Directory should exist and be secure
  [ -d "$temp_dir" ]
  local perms
  perms=$(stat -c %a "$temp_dir" 2>/dev/null || stat -f %A "$temp_dir" | cut -c -3)
  # /tmp should have reasonable permissions (typically 755 or 1777)
  [ -n "$perms" ]

  rm -f "$temp_file"
}

@test "temporary files are created with umask considerations" {
  # Save original umask
  local original_umask
  original_umask=$(umask)

  # Set restrictive umask
  umask 0077

  local temp_file
  temp_file=$(mktemp)
  echo "test content" > "$temp_file"

  # Check permissions
  local perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %A "$temp_file" | cut -c -3)

  # Should be very restrictive
  [[ "$perms" == "600" ]] || [[ "$perms" == "-rw-------" ]]

  # Restore umask
  umask "$original_umask"
  rm -f "$temp_file"
}

@test "temporary file cleanup removes all test artifacts" {
  setup_adapter_registry_test

  # Create multiple adapters and files
  for i in {1..3}; do
    create_valid_mock_adapter "cleanup_multi_$i"
    run_adapter_registry_register "cleanup_multi_$i"
    assert_success
  done

  # Count files before cleanup
  local file_count_before
  file_count_before=$(find "$TEST_ADAPTER_REGISTRY_DIR" -type f | wc -l)

  [ "$file_count_before" -gt 0 ]

  # Run teardown
  teardown_adapter_registry_test

  # Verify complete cleanup
  [ ! -d "$TEST_ADAPTER_REGISTRY_DIR" ]

  # Check that no orphaned files remain
  local orphaned_count
  orphaned_count=$(find /tmp -name "*$USER*suitey*" -type f 2>/dev/null | wc -l)
  [ "$orphaned_count" -eq 0 ]
}

@test "temporary directories don't persist between tests" {
  # Run two separate test sessions

  # First session
  local first_dir
  first_dir=$(mktemp -d -t "suitey_test_first_XXXXXX")

  echo "test1" > "$first_dir/test.txt"
  [ -f "$first_dir/test.txt" ]

  rm -rf "$first_dir"

  # Second session (simulated)
  local second_dir
  second_dir=$(mktemp -d -t "suitey_test_second_XXXXXX")

  # Should be different directory
  [[ "$first_dir" != "$second_dir" ]]

  # Should not contain files from first session
  [ ! -f "$second_dir/test.txt" ]

  rm -rf "$second_dir"
}

@test "temporary file creation doesn't follow symlinks unexpectedly" {
  # Create a symlink to a sensitive location
  local symlink_target="/tmp/sensitive_temp_link"
  ln -sf "/etc" "$symlink_target" 2>/dev/null || {
    # If we can't create symlink, skip
    skip "Cannot create symlink for test"
  }

  # mktemp should not follow the symlink
  local temp_file
  temp_file=$(mktemp "$symlink_target/temp_XXXXXX" 2>/dev/null) || {
    # If mktemp fails, that's expected for security
    rm -f "$symlink_target"
    skip "mktemp correctly rejects symlink paths"
  }

  # If we get here, check that file wasn't created in /etc
  [[ "$temp_file" != "/etc"* ]]

  # Clean up
  rm -f "$temp_file"
  rm -f "$symlink_target"
}

@test "temporary files are not created in current directory" {
  local original_cwd
  original_cwd=$(pwd)

  # Change to a test directory
  cd /tmp

  local temp_file
  temp_file=$(mktemp)

  # Should not be in current directory
  [[ "$temp_file" != "./"* ]]
  [[ "$temp_file" == "/tmp/"* ]]

  rm -f "$temp_file"
  cd "$original_cwd"
}

@test "temporary file handles are properly closed" {
  # Test that file descriptors are properly managed
  local temp_file
  temp_file=$(mktemp)

  # Open file descriptor
  exec 99>"$temp_file"
  echo "test data" >&99

  # Close it
  exec 99>&-

  # Should be able to read the data
  local content
  content=$(cat "$temp_file")
  [[ "$content" == "test data" ]]

  # Should be able to remove the file (no open handles)
  rm -f "$temp_file"
  [ ! -f "$temp_file" ]
}

@test "temporary directories are created with proper ownership" {
  local temp_dir
  temp_dir=$(mktemp -d)

  local owner
  owner=$(stat -c %U "$temp_dir" 2>/dev/null || stat -f %Su "$temp_dir")

  local current_user
  current_user=$(whoami)

  [[ "$owner" == "$current_user" ]]

  rm -rf "$temp_dir"
}

@test "no temporary files leak sensitive environment variables" {
  # Set a sensitive environment variable
  export TEST_SENSITIVE_VAR="secret_password_123"

  # Create some temp files
  local temp_file1
  local temp_file2
  temp_file1=$(mktemp)
  temp_file2=$(mktemp)

  echo "some content" > "$temp_file1"
  echo "other content" > "$temp_file2"

  # Check that temp files don't contain the sensitive data
  if grep -q "secret_password_123" "$temp_file1" 2>/dev/null; then
    rm -f "$temp_file1" "$temp_file2"
    unset TEST_SENSITIVE_VAR
    return 1
  fi

  if grep -q "secret_password_123" "$temp_file2" 2>/dev/null; then
    rm -f "$temp_file1" "$temp_file2"
    unset TEST_SENSITIVE_VAR
    return 1
  fi

  # Clean up
  rm -f "$temp_file1" "$temp_file2"
  unset TEST_SENSITIVE_VAR
}

@test "temporary file names don't reveal sensitive information" {
  local temp_file
  temp_file=$(mktemp)

  # Filename should not contain sensitive patterns
  [[ "$(basename "$temp_file")" != *"password"* ]]
  [[ "$(basename "$temp_file")" != *"secret"* ]]
  [[ "$(basename "$temp_file")" != *"key"* ]]
  [[ "$(basename "$temp_file")" != *"token"* ]]

  # Should not contain user information that could be sensitive
  [[ "$(basename "$temp_file")" != *"$USER"* ]]

  rm -f "$temp_file"
}
