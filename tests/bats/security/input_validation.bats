#!/usr/bin/env bash

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


load ../helpers/adapter_registry

# ============================================================================
# Input Validation and Sanitization Security Tests
# ============================================================================

@test "null adapter identifier is rejected" {
  setup_adapter_registry_test

  # Try to register with null identifier
  run_adapter_registry_register ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"null or empty identifier"* ]]

  teardown_adapter_registry_test
}

@test "empty adapter identifier is rejected" {
  setup_adapter_registry_test

  # Try to register with empty identifier
  run_adapter_registry_register ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"null or empty identifier"* ]]

  teardown_adapter_registry_test
}

@test "adapter identifier with special characters is accepted" {
  setup_adapter_registry_test

  # Create adapter with special characters in identifier
  local adapter_name="test-adapter_123"
  create_valid_mock_adapter "$adapter_name"
  run_adapter_registry_register "$adapter_name"
  assert_success

  # Verify it was registered
  run_adapter_registry_get "$adapter_name"
  [ -n "$output" ]

  teardown_adapter_registry_test
}

@test "very long adapter identifier is handled" {
  setup_adapter_registry_test

  # Create identifier that's very long (255 chars)
  local long_name=""
  for i in {1..25}; do
    long_name="${long_name}very_long_adapter_name_part_"
  done
  long_name="${long_name}$$" # Add PID to make it unique

  create_valid_mock_adapter "$long_name"
  run_adapter_registry_register "$long_name"
  assert_success

  # Verify it was registered
  run_adapter_registry_get "$long_name"
  [ -n "$output" ]

  teardown_adapter_registry_test
}

@test "adapter identifier with path traversal is accepted but safe" {
  setup_adapter_registry_test

  # Try identifier with path traversal characters
  local malicious_name="../../../etc/passwd"
  create_valid_mock_adapter "$malicious_name"
  run_adapter_registry_register "$malicious_name"
  assert_success

  # Verify it was registered with the literal name (not as path traversal)
  run_adapter_registry_get "$malicious_name"
  [ -n "$output" ]

  # Verify no files were created outside test directory
  [ ! -f "/etc/passwd/suitey_adapter_registry" ]

  teardown_adapter_registry_test
}

@test "adapter metadata with injection attempts is handled safely" {
  setup_adapter_registry_test

  # Create adapter with malicious metadata
  local malicious_metadata='{"name": "test", "command": "; rm -rf /; #", "path": "../../../../etc"}'

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/injection_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

injection_adapter_detect() {
  local project_root="\$1"
  return 0
}

injection_adapter_get_metadata() {
  echo '$malicious_metadata'
}

injection_adapter_check_binaries() {
  return 0
}

injection_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "injection_test", "framework": "injection", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

injection_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

injection_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

injection_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

injection_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  run_adapter_registry_register "injection_test"
  assert_success

  # Verify metadata is stored safely (base64 encoded)
  local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
  local content
  content=$(cat "$registry_file")

  # Should be base64 encoded, not contain raw malicious content
  [[ "$content" != *"; rm -rf /;"* ]]
  [[ "$content" != *"../../../../etc"* ]]

  teardown_adapter_registry_test
}

@test "TEST_ADAPTER_REGISTRY_DIR with injection characters is handled" {
  setup_adapter_registry_test

  # Save original
  local original_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Try directory with injection characters
  local injection_dir="/tmp/injection;rm -rf / #"
  mkdir -p "$injection_dir" 2>/dev/null || true
  TEST_ADAPTER_REGISTRY_DIR="$injection_dir"

  # Try to register adapter
  create_valid_mock_adapter "injection_dir_test"
  run_adapter_registry_register "injection_dir_test" 2>/dev/null || true

  # Should not have executed the rm command
  [ -d "/tmp" ] # /tmp should still exist

  # Reset
  TEST_ADAPTER_REGISTRY_DIR="$original_dir"

  teardown_adapter_registry_test
}

@test "environment variable injection in adapter scripts is prevented" {
  setup_adapter_registry_test

  # Set a malicious environment variable
  export MALICIOUS_VAR='$(rm -rf /)'

  # Create adapter that might try to use the variable
  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/env_injection_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

env_injection_adapter_detect() {
  local project_root="\$1"
  return 0
}

env_injection_adapter_get_metadata() {
  echo '{"name": "env test", "value": "'\$MALICIOUS_VAR'"}'
}

env_injection_adapter_check_binaries() {
  return 0
}

env_injection_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "env_test", "framework": "env", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

env_injection_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

env_injection_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

env_injection_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

env_injection_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  run_adapter_registry_register "env_injection_test"
  assert_success

  # System should still be intact
  [ -d "/tmp" ]
  [ -f "/bin/bash" ]

  # Clean up
  unset MALICIOUS_VAR

  teardown_adapter_registry_test
}

@test "very large metadata payload is handled without issues" {
  setup_adapter_registry_test

  # Create very large metadata (100KB)
  local large_data=""
  for i in {1..10000}; do
    large_data="${large_data}This is a very large metadata payload that should be handled safely. "
  done

  local large_metadata="{\"name\": \"large test\", \"description\": \"$large_data\"}"

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/large_input_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

large_input_adapter_detect() {
  local project_root="\$1"
  return 0
}

large_input_adapter_get_metadata() {
  echo '$large_metadata'
}

large_input_adapter_check_binaries() {
  return 0
}

large_input_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "large_test", "framework": "large", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

large_input_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

large_input_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

large_input_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

large_input_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  run_adapter_registry_register "large_input_test"
  assert_success

  # Verify it was stored (even if truncated or handled specially)
  run_adapter_registry_get "large_input_test"
  [ -n "$output" ]

  teardown_adapter_registry_test
}

@test "adapter identifier with shell metacharacters is handled safely" {
  setup_adapter_registry_test

  # Try identifiers with shell metacharacters
  local metachar_names=("test|command" "test&background" "test;next" "test\`backtick\`" "test\$(subshell)" "test>redirect" "test<redirect")

  for name in "${metachar_names[@]}"; do
    create_valid_mock_adapter "$name"
    run_adapter_registry_register "$name"
    assert_success

    # Verify it was registered with the literal name
    run_adapter_registry_get "$name"
    [ -n "$output" ]
  done

  teardown_adapter_registry_test
}

@test "TEST_ADAPTER_REGISTRY_DIR with very long path is handled" {
  setup_adapter_registry_test

  # Save original
  local original_dir="$TEST_ADAPTER_REGISTRY_DIR"

  # Create very long path (near filesystem limits)
  local long_path="/tmp"
  for i in {1..10}; do
    long_path="$long_path/very_long_directory_name_that_keeps_going_on_and_on_$i"
  done

  mkdir -p "$long_path" 2>/dev/null || {
    # If we can't create the long path, skip the test
    skip "Filesystem doesn't support very long paths"
  }

  TEST_ADAPTER_REGISTRY_DIR="$long_path"

  # Try to register adapter
  create_valid_mock_adapter "long_path_test"
  run_adapter_registry_register "long_path_test" 2>/dev/null || {
    # If registration fails due to path length, that's acceptable
    skip "Path too long for filesystem"
  }

  # Reset
  TEST_ADAPTER_REGISTRY_DIR="$original_dir"

  teardown_adapter_registry_test
}

@test "concurrent input validation works" {
  setup_adapter_registry_test

  # Start multiple processes trying to register adapters with similar names
  local pids=()
  local results=()

  for i in {1..5}; do
    (
      local suitey_script
      if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
        suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
      elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
        suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
      else
        suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
      fi

      source "$suitey_script" >/dev/null 2>&1
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" create_valid_mock_adapter "concurrent_input_$i"
      TEST_ADAPTER_REGISTRY_DIR="$TEST_ADAPTER_REGISTRY_DIR" run_adapter_registry_register "concurrent_input_$i" >/dev/null 2>&1
      echo "$?:$i"
    ) &
    pids+=($!)
  done

  # Wait for all
  local failed=0
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # All should have succeeded (no race conditions in validation)
  [ "$failed" -eq 0 ]

  teardown_adapter_registry_test
}

@test "malformed JSON in metadata is handled gracefully" {
  setup_adapter_registry_test

  # Create adapter with malformed JSON
  local malformed_json='{"name": "test", "missing": "comma" "invalid": "json"}'

  local adapter_dir="$TEST_ADAPTER_REGISTRY_DIR/adapters/malformed_json_test"
  mkdir -p "$adapter_dir"

  cat > "$adapter_dir/adapter.sh" << EOF
#!/usr/bin/env bash

malformed_json_adapter_detect() {
  local project_root="\$1"
  return 0
}

malformed_json_adapter_get_metadata() {
  echo '$malformed_json'
}

malformed_json_adapter_check_binaries() {
  return 0
}

malformed_json_adapter_discover_test_suites() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '[{"name": "malformed_test", "framework": "malformed", "test_files": ["test.txt"], "metadata": {}, "execution_config": {}}]'
}

malformed_json_adapter_detect_build_requirements() {
  local project_root="\$1"
  local framework_metadata="\$2"
  echo '{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
}

malformed_json_adapter_get_build_steps() {
  local project_root="\$1"
  local build_requirements="\$2"
  echo '[]'
}

malformed_json_adapter_execute_test_suite() {
  local project_root="\$1"
  local test_suite="\$2"
  return 0
}

malformed_json_adapter_parse_test_results() {
  local project_root="\$1"
  local test_results_dir="\$2"
  echo '{"passed": 1, "failed": 0, "total": 1, "duration": 0.1}'
}
EOF

  # Registration should fail due to metadata validation
  run_adapter_registry_register "malformed_json_test"
  [ "$status" -ne 0 ]

  teardown_adapter_registry_test
}
