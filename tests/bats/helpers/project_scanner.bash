#!/usr/bin/env bash
# Helper functions for Project Scanner tests

# Create a temporary project directory
setup_test_project() {
  local project_name="${1:-test_project}"
  TEST_PROJECT_DIR=$(mktemp -d -t "suitey_test_${project_name}_XXXXXX")
  export TEST_PROJECT_DIR
  echo "$TEST_PROJECT_DIR"
}

# Clean up temporary project directory
teardown_test_project() {
  if [[ -n "${TEST_PROJECT_DIR:-}" ]] && [[ -d "$TEST_PROJECT_DIR" ]]; then
    rm -rf "$TEST_PROJECT_DIR"
    unset TEST_PROJECT_DIR
  fi
}

# Create a .bats test file with proper structure
create_bats_test_file() {
  local file_path="$1"
  local test_name="${2:-test_example}"
  local content="${3:-}"
  
  # Ensure directory exists
  mkdir -p "$(dirname "$file_path")"
  
  # Default content if not provided
  if [[ -z "$content" ]]; then
    content="@test \"$test_name\" {
  [ true ]
}
"
  fi
  
  # Write file with shebang if it doesn't start with one
  if [[ ! "$content" =~ ^#!/ ]]; then
    echo "#!/usr/bin/env bats" > "$file_path"
    echo "" >> "$file_path"
    echo "$content" >> "$file_path"
  else
    echo "$content" > "$file_path"
  fi
  
  chmod +x "$file_path"
  echo "$file_path"
}

# Create test directory structure
create_test_directory() {
  local base_dir="$1"
  local dir_path="$2"
  
  mkdir -p "$base_dir/$dir_path"
  echo "$base_dir/$dir_path"
}

# Assert scanner output format and content
assert_scanner_output() {
  local output="$1"
  local expected_framework="${2:-}"
  local expected_suite_count="${3:-}"
  
  # Check if output contains framework detection
  if [[ -n "$expected_framework" ]]; then
    local framework_message=""
    case "$expected_framework" in
      "bats")
        framework_message="BATS framework detected"
        ;;
      "rust")
        framework_message="Rust framework detected"
        ;;
      *)
        framework_message="${expected_framework} framework detected"
        ;;
    esac
    if ! echo "$output" | grep -q "$framework_message"; then
      echo "ERROR: Expected $expected_framework framework detection in output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi
  
  # Check if output contains suite count
  if [[ -n "$expected_suite_count" ]]; then
    if ! echo "$output" | grep -q "Discovered $expected_suite_count test suite"; then
      echo "ERROR: Expected $expected_suite_count test suite(s) in output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi
  
  return 0
}

# Assert no test suites found
assert_no_test_suites() {
  local output="$1"
  
  if ! echo "$output" | grep -q "No test suites found"; then
    echo "ERROR: Expected 'No test suites found' message"
    echo "Output was:"
    echo "$output"
    return 1
  fi
  
  return 0
}

# Assert structured text output contains expected fields
assert_structured_output() {
  local output="$1"
  local field="${2:-}"
  
  case "$field" in
    "frameworks")
      if ! echo "$output" | grep -q "Detected frameworks"; then
        echo "ERROR: Expected 'Detected frameworks' in output"
        return 1
      fi
      ;;
    "suites")
      if ! echo "$output" | grep -q "Test Suites:"; then
        echo "ERROR: Expected 'Test Suites:' in output"
        return 1
      fi
      ;;
    "errors")
      if ! echo "$output" | grep -qE "(Warnings:|Errors:)"; then
        # Errors/warnings are optional, so this is just a check
        return 0
      fi
      ;;
  esac
  
  return 0
}

# Assert test count for a specific suite
assert_test_count() {
  local output="$1"
  local suite_name="$2"
  local expected_count="$3"
  
  # Extract the test count for the specified suite
  # The output format is:
  #   • suite-name (framework)
  #     Path: path/to/file.bats
  #     Tests: X
  #
  # We need to find the suite name, then look for "Tests: X" on the next lines
  
  # Use a simpler approach: find the suite block with grep -A and extract the test count
  local suite_block
  suite_block=$(echo "$output" | grep -A 3 "•.*$suite_name")
  
  if [[ -z "$suite_block" ]]; then
    echo "ERROR: Could not find suite '$suite_name' in output"
    echo "Output was:"
    echo "$output"
    return 1
  fi
  
  # Extract the test count from the suite block
  local actual_count
  actual_count=$(echo "$suite_block" | grep "Tests:" | grep -oE "[0-9]+" | head -1)
  
  if [[ -z "$actual_count" ]]; then
    echo "ERROR: Could not find test count for suite '$suite_name'"
    echo "Suite block was:"
    echo "$suite_block"
    echo "Full output was:"
    echo "$output"
    return 1
  fi
  
  if [[ "$actual_count" != "$expected_count" ]]; then
    echo "ERROR: Expected $expected_count test(s) for suite '$suite_name', but found $actual_count"
    echo "Suite block was:"
    echo "$suite_block"
    echo "Full output was:"
    echo "$output"
    return 1
  fi
  
  return 0
}

# Assert that test counts are present in output
assert_test_counts_present() {
  local output="$1"
  
  # Check that "Tests:" appears in the output
  if ! echo "$output" | grep -q "Tests:"; then
    echo "ERROR: Expected 'Tests:' to appear in output for each suite"
    echo "Output was:"
    echo "$output"
    return 1
  fi
  
  return 0
}

# Run scanner on a project directory and capture output
run_scanner() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  local output
  local scanner_script
  
  # Determine the path to suitey.sh
  # BATS_TEST_DIRNAME points to the directory containing the test file
  # From tests/bats/unit/ or tests/bats/integration/, we need to go up to project root
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    # Fallback: try to find it relative to current directory
    scanner_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi
  
  # Run scanner and capture both stdout and stderr
  output=$("$scanner_script" "$project_dir" 2>&1) || true
  echo "$output"
}

# Check if bats binary is available (for mocking purposes)
is_bats_available() {
  command -v bats >/dev/null 2>&1
}

# Mock bats binary availability by modifying PATH
# Note: This is a best-effort mock. For more reliable testing,
# tests should be run on systems where bats is actually unavailable,
# or use a more sophisticated mocking approach.
mock_bats_unavailable() {
  # Save original PATH
  ORIGINAL_PATH="$PATH"
  
  # Create a temporary directory and prepend it to PATH
  # This directory will be checked first, and since it doesn't contain bats,
  # command -v should not find it (unless it's later in PATH)
  MOCK_PATH_DIR=$(mktemp -d)
  export PATH="$MOCK_PATH_DIR:$PATH"
  
  # Note: This doesn't guarantee bats won't be found if it exists elsewhere in PATH
  # For a true mock, you'd need to remove all bats from PATH or use a wrapper script
}

# Restore original PATH
restore_path() {
  if [[ -n "${ORIGINAL_PATH:-}" ]]; then
    export PATH="$ORIGINAL_PATH"
    unset ORIGINAL_PATH
  fi
  if [[ -n "${MOCK_PATH_DIR:-}" ]]; then
    rm -rf "$MOCK_PATH_DIR"
    unset MOCK_PATH_DIR
  fi
}

# ============================================================================
# Rust-Specific Helper Functions
# ============================================================================

# Check if cargo binary is available
is_cargo_available() {
  command -v cargo >/dev/null 2>&1
}

# Count the number of #[test] annotations in a Rust test file
count_rust_tests() {
  local file="$1"
  local count=0

  # Verify file exists and is readable
  if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
    echo "0"
    return
  fi

  # Count lines that contain #[test] (allowing for whitespace)
  # Read file directly line by line - most reliable method across all environments
  count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove leading whitespace and check if line starts with #[test]
    trimmed_line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed_line" == '#[test]'* ]]; then
      ((count++))
    fi
  done < "$file"

  echo "$count"
}

# Update assert_scanner_output to support Rust framework
assert_scanner_output() {
  local output="$1"
  local expected_framework="${2:-}"
  local expected_suite_count="${3:-}"

  # Check if output contains framework detection
  if [[ -n "$expected_framework" ]]; then
    local framework_message=""
    case "$expected_framework" in
      "bats")
        framework_message="BATS framework detected"
        ;;
      "rust")
        framework_message="Rust framework detected"
        ;;
      *)
        framework_message="${expected_framework} framework detected"
        ;;
    esac

    if ! echo "$output" | grep -q "$framework_message"; then
      echo "ERROR: Expected $expected_framework framework detection in output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi

  # Check if output contains suite count
  if [[ -n "$expected_suite_count" ]]; then
    if ! echo "$output" | grep -q "Discovered $expected_suite_count test suite"; then
      echo "ERROR: Expected $expected_suite_count test suite(s) in output"
      echo "Output was:"
      echo "$output"
      return 1
    fi
  fi

  return 0
}

# Mock cargo binary availability by modifying PATH (similar to bats mocking)
mock_cargo_unavailable() {
  # Save original PATH
  ORIGINAL_PATH="$PATH"

  # Create a temporary directory and prepend it to PATH
  # This directory will be checked first, and since it doesn't contain cargo,
  # command -v should not find it (unless it's later in PATH)
  MOCK_PATH_DIR=$(mktemp -d)
  export PATH="$MOCK_PATH_DIR:$PATH"

  # Note: This doesn't guarantee cargo won't be found if it exists elsewhere in PATH
  # For a true mock, you'd need to remove all cargo from PATH or use a wrapper script
}

