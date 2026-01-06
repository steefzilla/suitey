#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

# Acceptance test for Rust example project framework detection

# Build suitey.sh before running acceptance tests
setup_file() {
  local project_root
  project_root="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../" && pwd)"

  # Build suitey.sh to ensure it's up to date
  cd "$project_root" || return 1
  if [[ -f "build.sh" ]]; then
    ./build.sh || {
      echo "ERROR: Failed to build suitey.sh"
      return 1
    }
  fi
}

# Source all required modules from src/ for acceptance tests
_source_acceptance_modules() {
  # Find and source common.sh first (provides check_binary function)
  local common_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/common.sh" ]]; then
    common_script="$BATS_TEST_DIRNAME/../../../src/common.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/common.sh" ]]; then
    common_script="$BATS_TEST_DIRNAME/../../src/common.sh"
  else
    common_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/common.sh"
  fi
  source "$common_script"

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

_source_acceptance_modules

# ============================================================================
# Acceptance Tests for Example Projects
# ============================================================================

@test "Acceptance: suitey.sh detects Rust framework and test suites in example/rust" {
  # Get absolute path to example project
  local example_project_dir="/home/steef/workspace/suitey/example/rust"
  local suitey_script="/home/steef/workspace/suitey/suitey.sh"

  # Verify example project and suitey.sh exist
  [[ -d "$example_project_dir" ]] || skip "Example Rust project not found at $example_project_dir"
  [[ -f "$example_project_dir/Cargo.toml" ]] || skip "Cargo.toml not found in example project"

  # Ensure suitey.sh exists and is executable (rebuild if needed)
  if [[ ! -x "$suitey_script" ]]; then
    echo "Rebuilding suitey.sh..."
    (cd "$(dirname "$suitey_script")" && ./build.sh) || skip "Failed to build suitey.sh"
  fi
  [[ -f "$suitey_script" ]] || skip "suitey.sh not found at $suitey_script"

  # Run suitey.sh on the example project
  local output exit_code
  echo "Running: $suitey_script $example_project_dir" >&2
  if output="$("$suitey_script" "$example_project_dir" 2>&1)"; then
    exit_code=0
  else
    exit_code=$?
  fi

  # suitey.sh should exit successfully
  [[ $exit_code -eq 0 ]] || {
    echo "ERROR: suitey.sh failed with exit code $exit_code"
    echo "Output: $output"
    return 1
  }

  # Verify Rust framework is detected
  echo "$output" | grep -q "✓ Rust framework detected" || {
    echo "ERROR: Rust framework not detected in output"
    echo "Output: $output"
    return 1
  }

  # Verify test suites are discovered
  echo "$output" | grep -q "✓ Discovered.*test suite" || {
    echo "ERROR: Test suites not discovered"
    echo "Output: $output"
    return 1
  }

  # Verify specific test suites are listed
  echo "$output" | grep -q "src-lib - rust" || {
    echo "ERROR: Unit test suite 'src-lib' not found"
    echo "Output: $output"
    return 1
  }

  echo "$output" | grep -q "tests-integration_test - rust" || {
    echo "ERROR: Integration test suite 'tests-integration_test' not found"
    echo "Output: $output"
    return 1
  }

  # Verify test counts are shown
  echo "$output" | grep -q "Tests: 3" || {
    echo "ERROR: Expected test counts not found"
    echo "Output: $output"
    return 1
  }

  return 0
}

@test "Acceptance: Rust example project structure is valid" {
  # Get absolute path to example project
  local example_project_dir
  if [[ -d "$BATS_TEST_DIRNAME/../../../example/rust" ]]; then
    example_project_dir="$BATS_TEST_DIRNAME/../../../example/rust"
  elif [[ -d "$BATS_TEST_DIRNAME/../../example/rust" ]]; then
    example_project_dir="$BATS_TEST_DIRNAME/../../example/rust"
  else
    example_project_dir="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../example/rust" && pwd)"
  fi

  # Verify basic project structure
  [[ -d "$example_project_dir" ]] || skip "Example Rust project not found at $example_project_dir"
  [[ -f "$example_project_dir/Cargo.toml" ]] || skip "Cargo.toml not found"
  [[ -d "$example_project_dir/src" ]] || skip "src/ directory not found"
  [[ -f "$example_project_dir/src/lib.rs" ]] || skip "src/lib.rs not found"

  # Verify Cargo.toml has package section
  grep -q '^\[package\]' "$example_project_dir/Cargo.toml" || {
    echo "ERROR: Cargo.toml missing [package] section"
    return 1
  }

  # Verify lib.rs contains unit tests
  grep -q '#\[cfg(test)\]' "$example_project_dir/src/lib.rs" || {
    echo "ERROR: lib.rs missing #[cfg(test)] module"
    return 1
  }

  grep -q '#\[test\]' "$example_project_dir/src/lib.rs" || {
    echo "ERROR: lib.rs missing #[test] functions"
    return 1
  }

  # Verify integration tests exist
  [[ -d "$example_project_dir/tests" ]] || skip "tests/ directory not found"
  [[ -f "$example_project_dir/tests/integration_test.rs" ]] || skip "integration test file not found"

  return 0
}
