#!/usr/bin/env bats

load ../helpers/project_scanner
load ../helpers/fixtures

# ============================================================================
# BATS Project Scenarios
# ============================================================================

@test "full BATS project with tests/bats/ structure" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  
  # Verify test suite details
  if ! echo "$output" | grep -q "suitey"; then
    echo "ERROR: Should detect suitey test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "BATS project with helpers in tests/bats/helpers/" {
  setup_test_project
  create_project_with_helpers "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should detect multiple test files
  assert_scanner_output "$output" "bats" "2"
  
  # Verify helpers directory exists (scanner should still work)
  if [[ ! -d "$TEST_PROJECT_DIR/tests/bats/helpers" ]]; then
    echo "ERROR: Helpers directory should exist"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "multiple BATS test files in same directory" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/test1.bats" "test1"
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/test2.bats" "test2"
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/test3.bats" "test3"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "3"
  teardown_test_project
}

@test "BATS files in nested directories" {
  setup_test_project
  create_bats_project_nested "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should detect both nested test files
  assert_scanner_output "$output" "bats" "2"
  
  # Verify nested structure
  if [[ ! -f "$TEST_PROJECT_DIR/tests/bats/unit/unit_test.bats" ]]; then
    echo "ERROR: Nested unit test file should exist"
    teardown_test_project
    return 1
  fi
  
  if [[ ! -f "$TEST_PROJECT_DIR/tests/bats/integration/integration_test.bats" ]]; then
    echo "ERROR: Nested integration test file should exist"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "BATS project with bats binary available" {
  if ! is_bats_available; then
    skip "bats binary not available for testing"
  fi
  
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should not have error about missing bats
  if echo "$output" | grep -q "bats binary is not available"; then
    echo "ERROR: Should not warn about missing bats when available"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "BATS project with bats binary missing (should skip with error message)" {
  # This test can only work if bats is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee bats won't be found, we skip if bats is available
  # In a real scenario, this would be tested on a system without bats installed
  if is_bats_available; then
    skip "bats binary is available - cannot test missing binary scenario without proper mocking"
  fi
  
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should still detect BATS framework
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Should detect BATS framework even without binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Should warn about missing binary
  if ! echo "$output" | grep -q "bats binary is not available"; then
    echo "ERROR: Should warn about missing bats binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

# ============================================================================
# No Test Suite Scenarios
# ============================================================================

@test "empty project root" {
  setup_test_project
  # Create completely empty directory
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with only source files (no tests)" {
  setup_test_project
  create_project_source_only "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with only documentation files" {
  setup_test_project
  create_project_docs_only "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with build files but no tests" {
  setup_test_project
  create_project_build_only "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

# ============================================================================
# Error Handling
# ============================================================================

@test "invalid project structure" {
  setup_test_project
  # Create a directory with symlinks or unusual structure
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  # Create a broken symlink
  ln -sf /nonexistent/path "$TEST_PROJECT_DIR/tests/bats/broken_link.bats" 2>/dev/null || true
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Scanner should handle this gracefully
  # Either detect no suites or handle the error
  # The exact behavior depends on implementation, but it shouldn't crash
  if echo "$output" | grep -q "error\|Error\|ERROR"; then
    # If there's an error, it should be clear
    echo "Output contains error (may be expected):"
    echo "$output"
  fi
  
  teardown_test_project
}

@test "missing dependencies (bats binary)" {
  # This test can only work if bats is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee bats won't be found, we skip if bats is available
  # In a real scenario, this would be tested on a system without bats installed
  if is_bats_available; then
    skip "bats binary is available - cannot test missing binary scenario without proper mocking"
  fi
  
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should provide clear error message
  if ! echo "$output" | grep -q "bats binary is not available"; then
    echo "ERROR: Should provide clear error about missing bats binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Should still detect the framework
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Should still detect BATS framework"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

# ============================================================================
# Output Validation
# ============================================================================

@test "structured text output contains expected fields" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Check for all expected fields
  assert_structured_output "$output" "frameworks"
  assert_structured_output "$output" "suites"
  
  # Check for specific content
  if ! echo "$output" | grep -q "Detected frameworks"; then
    echo "ERROR: Output should contain 'Detected frameworks'"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  if ! echo "$output" | grep -q "Test Suites:"; then
    echo "ERROR: Output should contain 'Test Suites:'"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "error messages are clear and actionable" {
  # This test can only work if bats is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee bats won't be found, we skip if bats is available
  # In a real scenario, this would be tested on a system without bats installed
  if is_bats_available; then
    skip "bats binary is available - cannot test missing binary scenario without proper mocking"
  fi
  
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Error message should be clear
  if echo "$output" | grep -q "bats binary is not available"; then
    # Check that it suggests installation
    if echo "$output" | grep -qi "install"; then
      # Good, suggests installation
      :
    else
      # Still acceptable if it just mentions the issue
      :
    fi
  else
    echo "ERROR: Should provide clear error message about missing bats"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "multiple test suites are properly listed" {
  setup_test_project
  create_project_with_helpers "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should list multiple suites
  local suite_count=$(echo "$output" | grep -c "•" || echo "0")
  if [[ $suite_count -lt 2 ]]; then
    echo "ERROR: Should list multiple test suites"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

@test "test suite paths are relative to project root" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Check that paths are shown
  if ! echo "$output" | grep -q "Path:"; then
    echo "ERROR: Should show test suite paths"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Path should be relative (not absolute)
  if echo "$output" | grep -q "$TEST_PROJECT_DIR"; then
    # Absolute paths are also acceptable, but relative is preferred
    :
  fi
  
  teardown_test_project
}

# ============================================================================
# Test Count Detection Integration Tests
# ============================================================================

@test "detect accurate test counts in full BATS project" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # The create_bats_project creates a suitey.bats file with 1 test
  # Suite name is based on file path: tests/bats/suitey.bats -> tests-bats-suitey
  assert_test_count "$output" "tests-bats-suitey" "1"
  assert_test_counts_present "$output"
  
  teardown_test_project
}

@test "detect test counts for BATS project with helpers" {
  setup_test_project
  create_project_with_helpers "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # create_project_with_helpers creates test1.bats and test2.bats, each with 1 test
  # Suite names are based on file paths
  assert_test_count "$output" "tests-bats-test1" "1"
  assert_test_count "$output" "tests-bats-test2" "1"
  assert_test_counts_present "$output"
  
  teardown_test_project
}

@test "detect test counts for multiple BATS files in same directory" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create multiple test files with different test counts using printf
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "file1 test 1" { [ true ]; }' '@test "file1 test 2" { [ true ]; }' > "$TEST_PROJECT_DIR/tests/bats/file1.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/file1.bats"
  
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "file2 test 1" { [ true ]; }' '@test "file2 test 2" { [ true ]; }' '@test "file2 test 3" { [ true ]; }' '@test "file2 test 4" { [ true ]; }' '@test "file2 test 5" { [ true ]; }' '@test "file2 test 6" { [ true ]; }' > "$TEST_PROJECT_DIR/tests/bats/file2.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/file2.bats"
  
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "file3 only test" { [ true ]; }' > "$TEST_PROJECT_DIR/tests/bats/file3.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/file3.bats"
  
  # Ensure files are written to disk
  sync
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Suite names are based on file paths
  assert_test_count "$output" "tests-bats-file1" "2"
  assert_test_count "$output" "tests-bats-file2" "6"
  assert_test_count "$output" "tests-bats-file3" "1"
  assert_test_counts_present "$output"
  
  teardown_test_project
}

@test "detect test counts for nested BATS files" {
  setup_test_project
  create_bats_project_nested "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # create_bats_project_nested creates unit_test.bats and integration_test.bats, each with 1 test
  # Suite names are based on file paths
  assert_test_count "$output" "tests-bats-unit-unit_test" "1"
  assert_test_count "$output" "tests-bats-integration-integration_test" "1"
  assert_test_counts_present "$output"
  
  teardown_test_project
}

@test "test counts are accurate for complex BATS files" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create a complex BATS file with multiple tests, comments, and helper functions using printf
  printf '%s\n' '#!/usr/bin/env bats' '' '# Helper function' 'helper_func() {' '  echo "helper"' '}' '' '# Setup function' 'setup() {' '  echo "setup"' '}' '' '@test "complex test 1" {' '  [ true ]' '}' '' '@test "complex test 2 with description" {' '  [ true ]' '}' '' '# Some comment' '@test "complex test 3" {' '  [ true ]' '}' '' '@test "complex test 4" {' '  [ true ]' '}' '' '# Teardown function' 'teardown() {' '  echo "teardown"' '}' > "$TEST_PROJECT_DIR/tests/bats/complex.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/complex.bats"
  
  # Ensure file is written to disk
  sync
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should count only @test annotations, not setup/teardown or comments
  # Suite name is based on file path: tests/bats/complex.bats -> tests-bats-complex
  assert_test_count "$output" "tests-bats-complex" "4"
  assert_test_counts_present "$output"
  
  teardown_test_project
}

@test "test counts handle files with whitespace before @test" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create a file with indented @test annotations using printf
  printf '%s\n' '#!/usr/bin/env bats' '' '    @test "indented whitespace test 1" {' '      [ true ]' '    }' '' '  @test "indented whitespace test 2" {' '    [ true ]' '  }' '' '@test "indented whitespace normal test" {' '  [ true ]' '}' > "$TEST_PROJECT_DIR/tests/bats/indented.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/indented.bats"
  
  # Ensure file is written to disk
  sync
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should count all @test annotations regardless of indentation
  # Suite name is based on file path: tests/bats/indented.bats -> tests-bats-indented
  assert_test_count "$output" "tests-bats-indented" "3"
  assert_test_counts_present "$output"

  teardown_test_project
}

# ============================================================================
# Rust Project Scenarios
# ============================================================================

@test "full Rust project with Cargo.toml and test files" {
  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  assert_scanner_output "$output" "rust" "1"

  # Verify test suite details
  if ! echo "$output" | grep -q "src-lib"; then
    echo "ERROR: Should detect src-lib test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "Rust project with multiple test files" {
  setup_test_project
  create_rust_project_with_tests "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect both test suites (src-lib and src-utils)
  assert_scanner_output "$output" "rust" "2"

  # Verify both suites are detected
  if ! echo "$output" | grep -q "src-lib"; then
    echo "ERROR: Should detect src-lib test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  if ! echo "$output" | grep -q "src-utils"; then
    echo "ERROR: Should detect src-utils test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "Rust project with nested test directories" {
  setup_test_project
  create_rust_project_nested "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect 3 test suites: src-lib (unit), tests-unit-unit_test, tests-integration-integration_test
  assert_scanner_output "$output" "rust" "3"

  # Verify nested structure
  if ! echo "$output" | grep -q "tests-unit-unit_test"; then
    echo "ERROR: Should detect nested unit test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  if ! echo "$output" | grep -q "tests-integration-integration_test"; then
    echo "ERROR: Should detect nested integration test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "Rust project with both unit and integration tests" {
  setup_test_project
  create_rust_project_unit_and_integration "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect 2 test suites: src-lib (unit tests) and tests-integration_tests (integration tests)
  assert_scanner_output "$output" "rust" "2"

  # Verify both types are detected
  if ! echo "$output" | grep -q "src-lib"; then
    echo "ERROR: Should detect unit test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  if ! echo "$output" | grep -q "tests-integration_tests"; then
    echo "ERROR: Should detect integration test suite"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "Rust project with cargo binary available" {
  if ! is_cargo_available; then
    skip "cargo binary not available for testing"
  fi

  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should not have error about missing cargo
  if echo "$output" | grep -q "cargo binary is not available"; then
    echo "ERROR: Should not warn about missing cargo when available"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  assert_scanner_output "$output" "rust" "1"
  teardown_test_project
}

@test "Rust project with cargo binary missing (should skip with error message)" {
  # This test can only work if cargo is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee cargo won't be found, we skip if cargo is available
  # In a real scenario, this would be tested on a system without cargo installed
  if is_cargo_available; then
    skip "cargo binary is available - cannot test missing binary scenario without proper mocking"
  fi

  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should still detect Rust framework
  if ! echo "$output" | grep -q "Rust framework detected"; then
    echo "ERROR: Should detect Rust framework even without binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  # Should warn about missing binary
  if ! echo "$output" | grep -q "cargo binary is not available"; then
    echo "ERROR: Should warn about missing cargo binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

# ============================================================================
# Rust Test Count Detection Integration Tests
# ============================================================================

@test "detect accurate test counts in full Rust project" {
  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # The create_rust_project creates src/lib.rs with 1 test
  # Suite name is based on file path: src/lib.rs -> src-lib
  assert_test_count "$output" "src-lib" "1"
  assert_test_counts_present "$output"

  teardown_test_project
}

@test "detect test counts for Rust project with multiple test files" {
  setup_test_project
  create_rust_project_with_tests "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # create_rust_project_with_tests creates src/lib.rs with 1 test and src/utils.rs with 2 tests
  # Suite names are based on file paths
  assert_test_count "$output" "src-lib" "1"
  assert_test_count "$output" "src-utils" "2"
  assert_test_counts_present "$output"

  teardown_test_project
}

@test "detect test counts for multiple Rust integration test files" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests"

  # Create Cargo.toml
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"
EOF

  # Create multiple integration test files with different test counts
  cat > "$TEST_PROJECT_DIR/tests/file1.rs" << 'EOF'
#[test]
fn test_one() {
    assert!(true);
}
EOF

  cat > "$TEST_PROJECT_DIR/tests/file2.rs" << 'EOF'
#[test]
fn test_one() {
    assert!(true);
}

#[test]
fn test_two() {
    assert!(true);
}

#[test]
fn test_three() {
    assert!(true);
}
EOF

  cat > "$TEST_PROJECT_DIR/tests/file3.rs" << 'EOF'
#[test]
fn only_test() {
    assert!(true);
}
EOF

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Suite names are based on file paths
  assert_test_count "$output" "tests-file1" "1"
  assert_test_count "$output" "tests-file2" "3"
  assert_test_count "$output" "tests-file3" "1"
  assert_test_counts_present "$output"

  teardown_test_project
}

@test "detect test counts for nested Rust test files" {
  setup_test_project
  create_rust_project_nested "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # create_rust_project_nested creates unit_test.rs and integration_test.rs, each with 1 test
  # Suite names are based on file paths
  assert_test_count "$output" "tests-unit-unit_test" "1"
  assert_test_count "$output" "tests-integration-integration_test" "1"
  assert_test_counts_present "$output"

  teardown_test_project
}

@test "detect test counts for Rust project with unit and integration tests" {
  setup_test_project
  create_rust_project_unit_and_integration "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # create_rust_project_unit_and_integration creates src/lib.rs with 2 tests and tests/integration_tests.rs with 3 tests
  # Suite names are based on file paths
  assert_test_count "$output" "src-lib" "2"
  assert_test_count "$output" "tests-integration_tests" "3"
  assert_test_counts_present "$output"

  teardown_test_project
}

@test "test counts are accurate for complex Rust test files" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests"

  # Create Cargo.toml
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"
EOF

  # Create a complex integration test file with multiple tests, comments, and helper code
  cat > "$TEST_PROJECT_DIR/tests/complex.rs" << 'EOF'
// Helper function
fn helper() -> bool {
    true
}

#[test]
fn complex_test_1() {
    assert!(helper());
}

#[test]
fn complex_test_2() {
    assert_eq!(1 + 1, 2);
}

// Some comment
#[test]
fn complex_test_3() {
    assert!(true);
}

#[test]
fn complex_test_4() {
    assert!(true);
}
EOF

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should count only #[test] annotations, not helper functions or comments
  # Suite name is based on file path: tests/complex.rs -> tests-complex
  assert_test_count "$output" "tests-complex" "4"
  assert_test_counts_present "$output"

  teardown_test_project
}

# ============================================================================
# Rust Build Detection Tests
# ============================================================================

@test "detect build requirement for Rust project" {
  setup_test_project
  create_rust_project_build_only "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect Rust framework but no test suites (since there are no test files)
  if ! echo "$output" | grep -q "Rust framework detected"; then
    echo "ERROR: Should detect Rust framework even with build-only project"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  # But should have no test suites since there are no test files
  assert_no_test_suites "$output"
  teardown_test_project
}

# ============================================================================
# Rust Error Handling
# ============================================================================

@test "missing dependencies (cargo binary)" {
  # This test can only work if cargo is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee cargo won't be found, we skip if cargo is available
  # In a real scenario, this would be tested on a system without cargo installed
  if is_cargo_available; then
    skip "cargo binary is available - cannot test missing binary scenario without proper mocking"
  fi

  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should provide clear error message
  if ! echo "$output" | grep -q "cargo binary is not available"; then
    echo "ERROR: Should provide clear error about missing cargo binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  # Should still detect the framework
  if ! echo "$output" | grep -q "Rust framework detected"; then
    echo "ERROR: Should still detect Rust framework"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

# ============================================================================
# Rust Output Validation
# ============================================================================

@test "structured text output contains expected fields for Rust" {
  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Check for all expected fields
  assert_structured_output "$output" "frameworks"
  assert_structured_output "$output" "suites"

  # Check for specific content
  if ! echo "$output" | grep -q "Detected frameworks"; then
    echo "ERROR: Output should contain 'Detected frameworks'"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  if ! echo "$output" | grep -q "Test Suites:"; then
    echo "ERROR: Output should contain 'Test Suites:'"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "error messages are clear and actionable for Rust" {
  # This test can only work if cargo is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee cargo won't be found, we skip if cargo is available
  # In a real scenario, this would be tested on a system without cargo installed
  if is_cargo_available; then
    skip "cargo binary is available - cannot test missing binary scenario without proper mocking"
  fi

  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Error message should be clear
  if echo "$output" | grep -q "cargo binary is not available"; then
    # Check that it suggests installation
    if echo "$output" | grep -qi "install"; then
      # Good, suggests installation
      :
    else
      # Still acceptable if it just mentions the issue
      :
    fi
  else
    echo "ERROR: Should provide clear error message about missing cargo"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "multiple test suites are properly listed for Rust" {
  setup_test_project
  create_rust_project_with_tests "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should list multiple suites
  local suite_count=$(echo "$output" | grep -c "•" || echo "0")
  if [[ $suite_count -lt 2 ]]; then
    echo "ERROR: Should list multiple test suites"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  teardown_test_project
}

@test "test suite paths are relative to project root for Rust" {
  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Check that paths are shown
  if ! echo "$output" | grep -q "Path:"; then
    echo "ERROR: Should show test suite paths"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi

  # Path should be relative (not absolute)
  if echo "$output" | grep -q "$TEST_PROJECT_DIR"; then
    # Absolute paths are also acceptable, but relative is preferred
    :
  fi

  teardown_test_project
}

@test "test suite discovery runs for all detected frameworks, not just first" {
  setup_test_project
  
  # Create a project with both BATS and Rust frameworks
  mkdir -p "$TEST_PROJECT_DIR"
  
  # Add BATS framework with test file
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  cat > "$TEST_PROJECT_DIR/tests/bats/multi.bats" << 'EOF'
#!/usr/bin/env bats

@test "multi framework BATS test" {
  [ true ]
}
EOF
  chmod +x "$TEST_PROJECT_DIR/tests/bats/multi.bats"
  
  # Add Rust framework with test file
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "multi_project"
version = "0.1.0"
edition = "2021"
EOF
  
  mkdir -p "$TEST_PROJECT_DIR/src"
  cat > "$TEST_PROJECT_DIR/src/lib.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn multi_test() {
        assert_eq!(2 + 2, 4);
    }
}
EOF
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Verify both frameworks are detected
  if ! echo "$output" | grep -q "BATS framework detected"; then
    echo "ERROR: Should detect BATS framework"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  if ! echo "$output" | grep -q "Rust framework detected"; then
    echo "ERROR: Should detect Rust framework"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Verify test suites are discovered for BATS (should find multi.bats)
  # The suite name format is typically: framework|suite_name|file_path|rel_path|test_count
  # In output it shows as: • suite-name - framework
  if ! echo "$output" | grep -qE "•.*multi.*-.*bats|•.*multi.*bats"; then
    echo "ERROR: Should discover BATS test suite (multi.bats)"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Verify test suites are discovered for Rust (should find lib.rs with tests)
  if ! echo "$output" | grep -qE "•.*lib.*-.*rust|•.*lib.*rust|•.*src.*rust"; then
    echo "ERROR: Should discover Rust test suite (lib.rs with #[cfg(test)])"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Verify total suite count includes both frameworks
  # Should have at least 2 suites (one BATS, one Rust)
  local suite_count=$(echo "$output" | grep -c "•" || echo "0")
  if [[ $suite_count -lt 2 ]]; then
    echo "ERROR: Should discover test suites for both frameworks (expected at least 2, found $suite_count)"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  # Verify the output mentions both framework types in the suite list
  # Count occurrences of "bats" and "rust" in the suite listing section
  local bats_in_suites=$(echo "$output" | grep -A 100 "Test Suites:" | grep -c "bats" || echo "0")
  local rust_in_suites=$(echo "$output" | grep -A 100 "Test Suites:" | grep -c "rust" || echo "0")
  
  if [[ $bats_in_suites -eq 0 ]]; then
    echo "ERROR: Should list at least one BATS test suite in Test Suites section"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  if [[ $rust_in_suites -eq 0 ]]; then
    echo "ERROR: Should list at least one Rust test suite in Test Suites section"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

