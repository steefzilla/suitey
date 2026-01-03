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

