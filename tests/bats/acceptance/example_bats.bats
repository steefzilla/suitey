#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

# Acceptance test for BATS example project framework detection

# Build suitey.sh before running acceptance tests
setup_file() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

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
# Acceptance Tests for BATS Example Projects
# ============================================================================

@test "Acceptance: suitey.sh detects BATS framework and test suites in example/bats" {
  # Get absolute path to example project
  local example_project_dir="/home/steef/workspace/suitey/example/bats"
  local suitey_script="/home/steef/workspace/suitey/suitey.sh"

  # Verify example project and suitey.sh exist
  [[ -d "$example_project_dir" ]] || skip "Example BATS project not found at $example_project_dir"
  [[ -f "$example_project_dir/tests/bats/suitey.bats" ]] || skip "suitey.bats not found in example project"
  [[ -f "$suitey_script" ]] || skip "suitey.sh not found at $suitey_script"

  # Run suitey.sh on the example project
  local output exit_code
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

  # Verify BATS framework is detected
  echo "$output" | grep -q "BATS framework detected" || {
    echo "ERROR: BATS framework not detected in output"
    echo "Output: $output"
    return 1
  }

  # Verify test suites are discovered
  echo "$output" | grep -q "✓ Discovered.*test suite" || {
    echo "ERROR: Test suites not discovered"
    echo "Output: $output"
    return 1
  }

  # Verify that multiple test suites are listed (at least 3)
  local suite_count
  suite_count=$(echo "$output" | grep -c " - bats")
  [[ $suite_count -ge 3 ]] || {
    echo "ERROR: Expected at least 3 BATS test suites, found $suite_count"
    echo "Output: $output"
    return 1
  }

  # Verify test counts are shown
  echo "$output" | grep -q "Tests: [1-9]" || {
    echo "ERROR: Expected test counts not found"
    echo "Output: $output"
    return 1
  }

  return 0
}

@test "Acceptance: BATS example project structure is valid" {
  # Get absolute path to example project
  local example_project_dir="/home/steef/workspace/suitey/example/bats"

  # Verify basic project structure
  [[ -d "$example_project_dir" ]] || skip "Example BATS project not found at $example_project_dir"

  # Verify test directories exist
  [[ -d "$example_project_dir/tests/bats" ]] || skip "tests/bats/ directory not found"
  [[ -d "$example_project_dir/test/bats" ]] || skip "test/bats/ directory not found"
  [[ -d "$example_project_dir/tests/bats/helpers" ]] || skip "helpers directory not found"

  # Verify test files exist and are executable
  [[ -x "$example_project_dir/tests/bats/suitey.bats" ]] || skip "suitey.bats not executable"
  [[ -x "$example_project_dir/test/bats/integration.bats" ]] || skip "integration.bats not executable"
  [[ -x "$example_project_dir/tests/bats/with_helpers.bats" ]] || skip "with_helpers.bats not executable"
  [[ -x "$example_project_dir/tests/bats/helpers/test_helper.bash" ]] || skip "test_helper.bash not executable"

  # Verify test files contain proper BATS shebang
  local files=("$example_project_dir/tests/bats/suitey.bats"
               "$example_project_dir/test/bats/integration.bats"
               "$example_project_dir/tests/bats/with_helpers.bats")

  for file in "${files[@]}"; do
    local first_line
    first_line=$(head -n 1 "$file")
    [[ "$first_line" == "#!/usr/bin/env bats" ]] || {
      echo "ERROR: $file does not have proper BATS shebang"
      return 1
    }
  done

  # Verify test files contain @test annotations
  for file in "${files[@]}"; do
    grep -q "@test" "$file" || {
      echo "ERROR: $file does not contain @test annotations"
      return 1
    }
  done

  # Verify helper file exists and is executable
  [[ -f "$example_project_dir/tests/bats/helpers/test_helper.bash" ]] || {
    echo "ERROR: Helper file not found"
    return 1
  }

  return 0
}
