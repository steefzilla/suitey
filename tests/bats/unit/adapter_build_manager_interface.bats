#!/usr/bin/env bats

load ../helpers/adapter_registry
load ../helpers/fixtures

# ============================================================================
# Build Manager Interface Tests
# ============================================================================

# ============================================================================
# get_build_steps() Interface Tests
# ============================================================================

@test "rust_adapter_get_build_steps returns install_dependencies_command field" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create a temporary project root
  local temp_project=$(mktemp -d)
  echo "[]" > "$temp_project/Cargo.toml" # Mock Cargo.toml

  # Call rust_adapter_get_build_steps
  local build_requirements='{"requires_build": true, "build_steps": ["compile"], "build_commands": ["cargo build"], "build_dependencies": [], "build_artifacts": ["target/"]}'
  local build_steps
  build_steps=$(rust_adapter_get_build_steps "$temp_project" "$build_requirements")

  # Should contain install_dependencies_command field
  assert_build_steps_has_install_dependencies "$build_steps"

  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "rust_adapter_get_build_steps returns cpu_cores field" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create a temporary project root
  local temp_project=$(mktemp -d)
  echo "[]" > "$temp_project/Cargo.toml" # Mock Cargo.toml

  # Call rust_adapter_get_build_steps
  local build_requirements='{"requires_build": true, "build_steps": ["compile"], "build_commands": ["cargo build"], "build_dependencies": [], "build_artifacts": ["target/"]}'
  local build_steps
  build_steps=$(rust_adapter_get_build_steps "$temp_project" "$build_requirements")

  # Should contain cpu_cores field (can be null)
  assert_build_steps_has_cpu_cores "$build_steps"

  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "rust_adapter_get_build_steps returns parallel build_command" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create a temporary project root
  local temp_project=$(mktemp -d)
  echo "[]" > "$temp_project/Cargo.toml" # Mock Cargo.toml

  # Call rust_adapter_get_build_steps
  local build_requirements='{"requires_build": true, "build_steps": ["compile"], "build_commands": ["cargo build"], "build_dependencies": [], "build_artifacts": ["target/"]}'
  local build_steps
  build_steps=$(rust_adapter_get_build_steps "$temp_project" "$build_requirements")

  # Should contain parallel build command with --jobs $(nproc)
  assert_build_command_parallel "$build_steps"

  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "bats_adapter_get_build_steps returns empty array" {
  setup_adapter_registry_test

  # Source the bats adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create a temporary project root
  local temp_project=$(mktemp -d)

  # Call bats_adapter_get_build_steps
  local build_requirements='{"requires_build": false, "build_steps": [], "build_commands": [], "build_dependencies": [], "build_artifacts": []}'
  local build_steps
  build_steps=$(bats_adapter_get_build_steps "$temp_project" "$build_requirements")

  # Should return empty array
  assert_build_steps_empty_array "$build_steps"

  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

# ============================================================================
# execute_test_suite() Interface Tests
# ============================================================================

@test "rust_adapter_execute_test_suite accepts test_image parameter" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image
  local test_suite='{"name": "test_suite", "framework": "rust", "test_files": ["src/main.rs"], "metadata": {}, "execution_config": {}}'
  local test_image="rust_test_image:latest"
  local execution_config='{"timeout": 30}'

  # Call rust_adapter_execute_test_suite with test_image parameter
  local result
  result=$(rust_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should succeed (not fail with parameter error)
  assert_execution_succeeded "$result"

  teardown_adapter_registry_test
}

@test "rust_adapter_execute_test_suite returns test_image in result" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image
  local test_suite='{"name": "test_suite", "framework": "rust", "test_files": ["src/main.rs"], "metadata": {}, "execution_config": {}}'
  local test_image="rust_test_image:latest"
  local execution_config='{"timeout": 30}'

  # Call rust_adapter_execute_test_suite
  local result
  result=$(rust_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should contain test_image field in result
  assert_execution_result_has_test_image "$result"

  # Should NOT contain build_artifacts field
  assert_execution_result_no_build_artifacts "$result"

  teardown_adapter_registry_test
}

@test "bats_adapter_execute_test_suite accepts test_image parameter" {
  setup_adapter_registry_test

  # Source the bats adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image (can be empty for BATS)
  local test_suite='{"name": "test_suite", "framework": "bats", "test_files": ["test.bats"], "metadata": {}, "execution_config": {}}'
  local test_image=""  # BATS doesn't require building
  local execution_config='{"timeout": 30}'

  # Call bats_adapter_execute_test_suite with test_image parameter
  local result
  result=$(bats_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should succeed (not fail with parameter error)
  assert_execution_succeeded "$result"

  teardown_adapter_registry_test
}

@test "bats_adapter_execute_test_suite returns test_image in result" {
  setup_adapter_registry_test

  # Source the bats adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image (can be empty for BATS)
  local test_suite='{"name": "test_suite", "framework": "bats", "test_files": ["test.bats"], "metadata": {}, "execution_config": {}}'
  local test_image=""  # BATS doesn't require building
  local execution_config='{"timeout": 30}'

  # Call bats_adapter_execute_test_suite
  local result
  result=$(bats_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should contain test_image field in result (even if empty)
  assert_execution_result_has_test_image "$result"

  # Should NOT contain build_artifacts field
  assert_execution_result_no_build_artifacts "$result"

  teardown_adapter_registry_test
}

# ============================================================================
# JSON Structure Validation Tests
# ============================================================================

@test "rust_adapter_get_build_steps returns valid JSON structure" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create a temporary project root
  local temp_project=$(mktemp -d)
  echo "[]" > "$temp_project/Cargo.toml" # Mock Cargo.toml

  # Call rust_adapter_get_build_steps
  local build_requirements='{"requires_build": true, "build_steps": ["compile"], "build_commands": ["cargo build"], "build_dependencies": [], "build_artifacts": ["target/"]}'
  local build_steps
  build_steps=$(rust_adapter_get_build_steps "$temp_project" "$build_requirements")

  # Should be valid JSON with required fields
  assert_build_steps_valid_json "$build_steps"

  rm -rf "$temp_project"
  teardown_adapter_registry_test
}

@test "rust_adapter_execute_test_suite returns valid JSON structure" {
  setup_adapter_registry_test

  # Source the rust adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image
  local test_suite='{"name": "test_suite", "framework": "rust", "test_files": ["src/main.rs"], "metadata": {}, "execution_config": {}}'
  local test_image="rust_test_image:latest"
  local execution_config='{"timeout": 30}'

  # Call rust_adapter_execute_test_suite
  local result
  result=$(rust_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should be valid JSON with required fields
  assert_execution_result_valid_json "$result"

  teardown_adapter_registry_test
}

@test "bats_adapter_execute_test_suite returns valid JSON structure" {
  setup_adapter_registry_test

  # Source the bats adapter
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  source "$suitey_script"

  # Create mock test suite and test image (can be empty for BATS)
  local test_suite='{"name": "test_suite", "framework": "bats", "test_files": ["test.bats"], "metadata": {}, "execution_config": {}}'
  local test_image=""  # BATS doesn't require building
  local execution_config='{"timeout": 30}'

  # Call bats_adapter_execute_test_suite
  local result
  result=$(bats_adapter_execute_test_suite "$test_suite" "$test_image" "$execution_config")

  # Should be valid JSON with required fields
  assert_execution_result_valid_json "$result"

  teardown_adapter_registry_test
}

