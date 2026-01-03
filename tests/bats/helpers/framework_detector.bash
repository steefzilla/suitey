#!/usr/bin/env bash
# Helper functions for Framework Detector tests

# ============================================================================
# Setup/Teardown Functions
# ============================================================================

# Create a temporary project directory for Framework Detector testing
setup_framework_detector_test() {
  local project_name="${1:-framework_detector_test}"
  TEST_PROJECT_DIR=$(mktemp -d -t "suitey_fd_test_${project_name}_XXXXXX")
  export TEST_PROJECT_DIR
  echo "$TEST_PROJECT_DIR"
}

# Clean up temporary project directory
teardown_framework_detector_test() {
  if [[ -n "${TEST_PROJECT_DIR:-}" ]] && [[ -d "$TEST_PROJECT_DIR" ]]; then
    rm -rf "$TEST_PROJECT_DIR"
    unset TEST_PROJECT_DIR
  fi
}

# ============================================================================
# Fixture Creators
# ============================================================================

# Create a project with BATS framework indicators
create_bats_framework_project() {
  local base_dir="$1"
  local project_name="${2:-bats_framework}"

  # Create project root
  mkdir -p "$base_dir"

  # Create tests/bats/ directory structure
  mkdir -p "$base_dir/tests/bats/helpers"

  # Create a sample BATS test file
  cat > "$base_dir/tests/bats/example.bats" << 'EOF'
#!/usr/bin/env bats

@test "example test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/example.bats"

  # Create a helper file
  cat > "$base_dir/tests/bats/helpers/helper.bash" << 'EOF'
#!/usr/bin/env bash
# Helper functions for BATS tests

helper_function() {
  echo "helper"
}
EOF
  chmod +x "$base_dir/tests/bats/helpers/helper.bash"

  echo "$base_dir"
}

# Create a project with Rust framework indicators
create_rust_framework_project() {
  local base_dir="$1"
  local project_name="${2:-rust_framework}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  # Create src/ directory with unit tests
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
EOF

  # Create tests/ directory with integration tests
  mkdir -p "$base_dir/tests"
  cat > "$base_dir/tests/integration_test.rs" << 'EOF'
#[test]
fn integration_test() {
    assert!(true);
}
EOF

  echo "$base_dir"
}

# Create a project with multiple frameworks (BATS + Rust)
create_multi_framework_project() {
  local base_dir="$1"
  local project_name="${2:-multi_framework}"

  # Create project root
  mkdir -p "$base_dir"

  # Add BATS framework indicators
  mkdir -p "$base_dir/tests/bats"
  cat > "$base_dir/tests/bats/multi.bats" << 'EOF'
#!/usr/bin/env bats

@test "multi framework test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/multi.bats"

  # Add Rust framework indicators
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "multi_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn multi_test() {
        assert_eq!(2 + 2, 4);
    }
}
EOF

  echo "$base_dir"
}

# Create a project with no framework indicators
create_empty_framework_project() {
  local base_dir="$1"
  local project_name="${2:-empty_framework}"

  # Create project root
  mkdir -p "$base_dir"

  # Create some non-test files
  echo "#!/bin/bash" > "$base_dir/script.sh"
  echo "# Source file" > "$base_dir/main.sh"
  echo "# Documentation" > "$base_dir/README.md"

  echo "$base_dir"
}

# Create a project with BATS files in alternative directory structures
create_bats_alt_dirs_project() {
  local base_dir="$1"
  local dir_pattern="$2"  # "test/bats" or "tests"

  # Create project root
  mkdir -p "$base_dir"

  case "$dir_pattern" in
    "test/bats")
      mkdir -p "$base_dir/test/bats"
      cat > "$base_dir/test/bats/alt_test.bats" << 'EOF'
#!/usr/bin/env bats

@test "alt dir test" {
  [ true ]
}
EOF
      chmod +x "$base_dir/test/bats/alt_test.bats"
      ;;
    "tests")
      mkdir -p "$base_dir/tests"
      cat > "$base_dir/tests/direct.bats" << 'EOF'
#!/usr/bin/env bats

@test "direct test" {
  [ true ]
}
EOF
      chmod +x "$base_dir/tests/direct.bats"
      ;;
  esac

  echo "$base_dir"
}

# Create a project with BATS shebang patterns
create_bats_shebang_project() {
  local base_dir="$1"

  # Create project root
  mkdir -p "$base_dir"

  # Create BATS file with specific shebang
  cat > "$base_dir/shebang_test.bats" << 'EOF'
#!/usr/bin/env bats

@test "shebang test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/shebang_test.bats"

  echo "$base_dir"
}

# ============================================================================
# Assertion Helpers
# ============================================================================

# Assert that a framework is detected in the output
assert_framework_detected() {
  local output="$1"
  local framework="$2"

  # Check if the output is JSON (contains framework_list)
  if echo "$output" | grep -q "framework_list"; then
    # JSON output - check if framework is in the framework_list array
    if ! echo "$output" | grep -q "\"$framework\""; then
      echo "ERROR: Expected framework '$framework' to be detected in JSON output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  else
    # Legacy text output - check for human-readable message
    local framework_message=""
    case "$framework" in
      "bats")
        framework_message="BATS framework detected"
        ;;
      "rust")
        framework_message="Rust framework detected"
        ;;
      *)
        framework_message="${framework} framework detected"
        ;;
    esac

    if ! echo "$output" | grep -q "$framework_message"; then
      echo "ERROR: Expected framework '$framework' to be detected"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi

  return 0
}

# Assert that a framework is NOT detected in the output
assert_framework_not_detected() {
  local output="$1"
  local framework="$2"

  # Check if the output is JSON (contains framework_list)
  if echo "$output" | grep -q "framework_list"; then
    # JSON output - check if framework is NOT in the framework_list array
    if echo "$output" | grep -q "\"$framework\""; then
      echo "ERROR: Expected framework '$framework' to NOT be detected in JSON output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  else
    # Legacy text output - check for human-readable message
    local framework_message=""
    case "$framework" in
      "bats")
        framework_message="BATS framework detected"
        ;;
      "rust")
        framework_message="Rust framework detected"
        ;;
      *)
        framework_message="${framework} framework detected"
        ;;
    esac

    if echo "$output" | grep -q "$framework_message"; then
      echo "ERROR: Expected framework '$framework' to NOT be detected"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi

  return 0
}

# Assert binary availability status
assert_binary_available() {
  local output="$1"
  local framework="$2"

  # This would check the binary status section of the output
  # For now, just check that no warning about missing binary is present
  local binary_name=""
  case "$framework" in
    "bats")
      binary_name="bats"
      ;;
    "rust")
      binary_name="cargo"
      ;;
  esac

  if [[ -n "$binary_name" ]] && echo "$output" | grep -q "${binary_name} binary is not available"; then
    echo "ERROR: Expected $binary_name binary to be available"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert binary missing status
assert_binary_missing() {
  local output="$1"
  local framework="$2"

  local binary_name=""
  case "$framework" in
    "bats")
      binary_name="bats"
      ;;
    "rust")
      binary_name="cargo"
      ;;
  esac

  if [[ -n "$binary_name" ]] && ! echo "$output" | grep -q "${binary_name} binary is not available"; then
    echo "ERROR: Expected $binary_name binary to be missing"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert that a detection warning is present
assert_detection_warning() {
  local output="$1"
  local warning_pattern="$2"

  if ! echo "$output" | grep -q "$warning_pattern"; then
    echo "ERROR: Expected warning pattern '$warning_pattern' in output"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert that a detection error is present
assert_detection_error() {
  local output="$1"
  local error_pattern="$2"

  if ! echo "$output" | grep -q "$error_pattern"; then
    echo "ERROR: Expected error pattern '$error_pattern' in output"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert framework metadata structure
assert_framework_metadata() {
  local output="$1"
  local framework="$2"
  local metadata_field="$3"
  local expected_value="$4"

  # Parse JSON output to check metadata
  # Use simple grep to check if the expected value is present in the framework details
  if ! echo "$output" | grep -q "\"$framework\".*\"$metadata_field\".*\"$expected_value\""; then
    echo "ERROR: Expected metadata field '$metadata_field' with value '$expected_value' for framework '$framework'"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert detection confidence level
assert_confidence_level() {
  local output="$1"
  local framework="$2"
  local expected_level="$3"  # "high", "medium", "low"

  # This would check the confidence level in the structured output
  # For now, just verify the output contains confidence information
  if ! echo "$output" | grep -q "confidence\|Confidence"; then
    echo "ERROR: Expected confidence level information in output"
    echo "Output was:"
    echo "$output"
    return 1
  fi

  return 0
}

# Assert that structured output contains expected sections
assert_structured_output() {
  local output="$1"
  local section="$2"

  case "$section" in
    "framework_list")
      if ! echo "$output" | grep -q "framework_list"; then
        echo "ERROR: Expected framework_list in JSON output"
        echo "Output was:"
        echo "$output"
        return 1
      fi
      ;;
    "framework_details")
      if ! echo "$output" | grep -q "framework_details"; then
        echo "ERROR: Expected framework_details in JSON output"
        echo "Output was:"
        echo "$output"
        return 1
      fi
      ;;
    "warnings")
      if ! echo "$output" | grep -q "warnings"; then
        echo "ERROR: Expected warnings in JSON output"
        echo "Output was:"
        echo "$output"
        return 1
      fi
      ;;
    "errors")
      if ! echo "$output" | grep -q "errors"; then
        echo "ERROR: Expected errors in JSON output"
        echo "Output was:"
        echo "$output"
        return 1
      fi
      ;;
    "binary_status")
      if ! echo "$output" | grep -q "binary_status"; then
        echo "ERROR: Expected binary_status in JSON output"
        echo "Output was:"
        echo "$output"
        return 1
      fi
      ;;
  esac

  return 0
}

# ============================================================================
# Execution Helpers
# ============================================================================

# Run Framework Detector function and capture output
run_framework_detector() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  local output
  local suitey_script

  # Determine the path to suitey.sh
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    # Fallback: try to find it relative to current directory
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # For now, this will fail because detect_frameworks doesn't exist
  # We'll implement a mock that calls the non-existent function
  output=$("$suitey_script" detect-frameworks "$project_dir" 2>&1) || true
  echo "$output"
}

# Extract detected frameworks from output
get_detected_frameworks() {
  local output="$1"
  local frameworks=()

  # Parse output to extract framework names
  # This is a placeholder - actual implementation would parse structured output
  if echo "$output" | grep -q "BATS framework detected"; then
    frameworks+=("bats")
  fi
  if echo "$output" | grep -q "Rust framework detected"; then
    frameworks+=("rust")
  fi

  echo "${frameworks[@]}"
}

# Extract framework metadata from output
get_framework_metadata() {
  local output="$1"
  local framework="$2"

  # This would parse structured output to extract metadata for a specific framework
  # For now, return a placeholder
  echo "{}"
}

# Extract binary availability status from output
get_binary_status() {
  local output="$1"
  local framework="$2"

  # This would parse structured output to extract binary status
  # For now, return a placeholder
  echo "unknown"
}

# ============================================================================
# Mock and Utility Functions
# ============================================================================

# Mock binary availability by setting environment variables
mock_binary_unavailable() {
  local binary_name="$1"

  case "$binary_name" in
    "bats")
      export SUITEY_MOCK_BATS_AVAILABLE="false"
      ;;
    "cargo")
      export SUITEY_MOCK_CARGO_AVAILABLE="false"
      ;;
  esac
}

# Restore binary availability (clear mock environment variables)
restore_path() {
  unset SUITEY_MOCK_BATS_AVAILABLE
  unset SUITEY_MOCK_CARGO_AVAILABLE
}

# Check if a specific binary is available
is_binary_available() {
  local binary_name="$1"
  command -v "$binary_name" >/dev/null 2>&1
}

# Create a project with specific file patterns for testing
create_project_with_pattern() {
  local base_dir="$1"
  local pattern_type="$2"

  mkdir -p "$base_dir"

  case "$pattern_type" in
    "bats_extension")
      echo '#!/usr/bin/env bats' > "$base_dir/test.bats"
      echo '@test "extension test" { [ true ]; }' >> "$base_dir/test.bats"
      chmod +x "$base_dir/test.bats"
      ;;
    "rust_cfg_test")
      mkdir -p "$base_dir/src"
      cat > "$base_dir/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn cfg_test() {
        assert!(true);
    }
}
EOF
      ;;
    "cargo_toml_only")
      cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "cargo_only"
version = "0.1.0"
edition = "2021"
EOF
      ;;
  esac

  echo "$base_dir"
}

# ============================================================================
# Additional Framework Detector Test Fixtures
# ============================================================================

# Create a project with multiple language frameworks (BATS + Rust)
create_multi_language_project() {
  local base_dir="$1"
  local project_name="${2:-multi_language}"

  # Create project root
  mkdir -p "$base_dir"

  # Add BATS framework indicators
  mkdir -p "$base_dir/tests/bats"
  cat > "$base_dir/tests/bats/multi.bats" << 'EOF'
#!/usr/bin/env bats

@test "multi language test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/multi.bats"

  # Add Rust framework indicators
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "multi_language_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn multi_language_test() {
        assert_eq!(2 + 2, 4);
    }
}
EOF

  echo "$base_dir"
}

# Create a project with nested directory structures containing BATS tests
create_nested_project() {
  local base_dir="$1"
  local project_name="${2:-nested}"

  # Create project root
  mkdir -p "$base_dir"

  # Create nested directory structure
  mkdir -p "$base_dir/tests/bats/unit"
  mkdir -p "$base_dir/tests/bats/integration"
  mkdir -p "$base_dir/tests/bats/helpers"

  # Create BATS test files in nested directories
  cat > "$base_dir/tests/bats/unit/nested_unit.bats" << 'EOF'
#!/usr/bin/env bats

@test "nested unit test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/unit/nested_unit.bats"

  cat > "$base_dir/tests/bats/integration/nested_integration.bats" << 'EOF'
#!/usr/bin/env bats

@test "nested integration test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/integration/nested_integration.bats"

  # Create a helper file
  cat > "$base_dir/tests/bats/helpers/nested_helper.bash" << 'EOF'
#!/usr/bin/env bash
# Nested helper functions

nested_helper_function() {
  echo "nested helper"
}
EOF
  chmod +x "$base_dir/tests/bats/helpers/nested_helper.bash"

  echo "$base_dir"
}

# Create a large project with many BATS and Rust test files for performance testing
create_large_project() {
  local base_dir="$1"
  local project_name="${2:-large}"

  # Create project root
  mkdir -p "$base_dir"

  # Add Rust framework indicators
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "large_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn large_project_test() {
        assert_eq!(2 + 2, 4);
    }
}
EOF

  # Create multiple test directories with many test files
  local dirs=("tests/bats" "test/bats" "tests/unit" "tests/integration" "tests/functional")
  local file_count=10

  for dir in "${dirs[@]}"; do
    mkdir -p "$base_dir/$dir"

    # Create multiple test files in each directory
    for i in $(seq 1 $file_count); do
      cat > "$base_dir/$dir/test_${i}.bats" << EOF
#!/usr/bin/env bats

@test "large project test ${i} in ${dir}" {
  [ true ]
}
EOF
      chmod +x "$base_dir/$dir/test_${i}.bats"
    done
  done

  # Also create some files at project root
  for i in $(seq 1 5); do
    cat > "$base_dir/root_test_${i}.bats" << EOF
#!/usr/bin/env bats

@test "root level test ${i}" {
  [ true ]
}
EOF
    chmod +x "$base_dir/root_test_${i}.bats"
  done

  echo "$base_dir"
}
