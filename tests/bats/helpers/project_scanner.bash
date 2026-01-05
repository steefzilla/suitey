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

# Run scanner on a project directory and capture output

# Test function for test suite discovery integration tests
test_suite_discovery_with_registry() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"

  # Initialize registry
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi

  # Run scan_project
  scan_project

  # Output results
  output_results
}

# Source all required modules from src/ for project scanner tests
_source_project_scanner_modules() {
  # Find and source json_helpers.sh
  local json_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
  else
    json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
  fi
  source "$json_helpers_script"

  # Find and source adapter_registry_helpers.sh
  local adapter_registry_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
  else
    adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
  fi
  source "$adapter_registry_helpers_script"

  # Find and source adapter_registry.sh
  local adapter_registry_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../src/adapter_registry.sh"
  else
    adapter_registry_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry.sh"
  fi
  source "$adapter_registry_script"

  # Find and source framework_detector.sh
  local framework_detector_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../../src/framework_detector.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../src/framework_detector.sh"
  else
    framework_detector_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/framework_detector.sh"
  fi
  source "$framework_detector_script"

  # Find and source scanner.sh
  local scanner_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/scanner.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../../src/scanner.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/scanner.sh" ]]; then
    scanner_script="$BATS_TEST_DIRNAME/../../src/scanner.sh"
  else
    scanner_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/scanner.sh"
  fi
  source "$scanner_script"

  # Find and source adapters
  local bats_adapter_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../src/adapters/bats.sh"
  else
    bats_adapter_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src/adapters" && pwd)/bats.sh"
  fi
  source "$bats_adapter_script"

  local rust_adapter_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapters/rust.sh" ]]; then
    rust_adapter_script="$BATS_TEST_DIRNAME/../../../src/adapters/rust.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapters/rust.sh" ]]; then
    rust_adapter_script="$BATS_TEST_DIRNAME/../../src/adapters/rust.sh"
  else
    rust_adapter_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src/adapters" && pwd)/rust.sh"
  fi
  source "$rust_adapter_script"
}

# Run test suite discovery with registry integration
run_test_suite_discovery_registry_integration() {
  local project_dir="${1:-$TEST_PROJECT_DIR}"
  local output

  # Source modules from src/
  _source_project_scanner_modules

  # Run test suite discovery and capture both stdout and stderr
  output=$(test_suite_discovery_with_registry "$project_dir" 2>&1) || true
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

