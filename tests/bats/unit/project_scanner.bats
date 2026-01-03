#!/usr/bin/env bats

load ../helpers/project_scanner
load ../helpers/fixtures

# ============================================================================
# BATS Detection Tests
# ============================================================================

@test "detect .bats files in tests/bats/ directory" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "detect .bats files in test/bats/ directory" {
  setup_test_project
  create_bats_project_alt_dir "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "detect .bats files in tests/ directory" {
  setup_test_project
  create_bats_project_tests_dir "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "detect BATS files with proper shebang" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create file with shebang
  create_bats_file_with_shebang "$TEST_PROJECT_DIR/tests/bats/test.bats" "shebang test"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "detect bats binary availability" {
  if is_bats_available; then
    setup_test_project
    create_bats_project "$TEST_PROJECT_DIR"
    
    output=$(run_scanner "$TEST_PROJECT_DIR")
    
    # Should not have error about missing bats binary
    if echo "$output" | grep -q "bats binary is not available"; then
      echo "ERROR: Should detect bats binary when available"
      echo "Output: $output"
      return 1
    fi
    
    teardown_test_project
  else
    skip "bats binary not available for testing"
  fi
}

@test "handle missing bats binary gracefully" {
  # This test can only work if bats is actually unavailable or if we can properly mock it
  # Since mocking PATH doesn't guarantee bats won't be found, we skip if bats is available
  # In a real scenario, this would be tested on a system without bats installed
  if is_bats_available; then
    skip "bats binary is available - cannot test missing binary scenario without proper mocking"
  fi
  
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should detect BATS but warn about missing binary
  if ! echo "$output" | grep -q "bats binary is not available"; then
    echo "ERROR: Should warn about missing bats binary"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

# ============================================================================
# File Pattern Matching Tests
# ============================================================================

@test "match *.bats file extension" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/test.bats" "test_pattern"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_scanner_output "$output" "bats" "1"
  teardown_test_project
}

@test "match files in common test directories" {
  setup_test_project
  
  # Test tests/bats/
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/test1.bats"
  
  # Test test/bats/
  mkdir -p "$TEST_PROJECT_DIR/test/bats"
  create_bats_test_file "$TEST_PROJECT_DIR/test/bats/test2.bats"
  
  # Test tests/
  mkdir -p "$TEST_PROJECT_DIR/tests"
  create_bats_test_file "$TEST_PROJECT_DIR/tests/test3.bats"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should detect all three test files
  assert_scanner_output "$output" "bats" "3"
  teardown_test_project
}

@test "handle nested directory structures" {
  setup_test_project
  create_bats_project_nested "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Should detect both nested test files
  assert_scanner_output "$output" "bats" "2"
  teardown_test_project
}

# ============================================================================
# No Test Suite Tests
# ============================================================================

@test "empty project directory" {
  setup_test_project
  # Create empty directory
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with no test directories" {
  setup_test_project
  create_empty_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with no test files" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  # Create non-test file
  echo "not a test" > "$TEST_PROJECT_DIR/tests/bats/not_a_test.sh"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

@test "project with non-test files only" {
  setup_test_project
  create_project_source_only "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  assert_no_test_suites "$output"
  teardown_test_project
}

# ============================================================================
# Output Format Tests
# ============================================================================

@test "default structured text output format" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Check for structured output elements
  assert_structured_output "$output" "frameworks"
  assert_structured_output "$output" "suites"
  
  teardown_test_project
}

@test "validate structured text contains expected fields" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Check for detected frameworks field
  assert_structured_output "$output" "frameworks"
  
  # Check for test suites field
  assert_structured_output "$output" "suites"
  
  # Check that output contains framework name
  if ! echo "$output" | grep -q "bats"; then
    echo "ERROR: Output should contain framework name 'bats'"
    echo "Output: $output"
    return 1
  fi
  
  teardown_test_project
}

@test "validate structured text contains test suite paths" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Check that output contains path information
  if ! echo "$output" | grep -q "Path:"; then
    echo "ERROR: Output should contain test suite paths"
    echo "Output: $output"
    return 1
  fi
  
  teardown_test_project
}

# ============================================================================
# Test Count Detection Tests
# ============================================================================

@test "detect test count for suite with single test" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  create_bats_test_file "$TEST_PROJECT_DIR/tests/bats/single.bats" "single_test" "@test \"single test\" {
  [ true ]
}
"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Suite name is based on file path: tests/bats/single.bats -> tests-bats-single
  assert_test_count "$output" "tests-bats-single" "1"
  assert_test_counts_present "$output"
  teardown_test_project
}

@test "detect test count for suite with multiple tests" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create file using printf to avoid BATS parsing heredoc content
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "multiple test 1" {' '  [ true ]' '}' '' '@test "multiple test 2" {' '  [ true ]' '}' '' '@test "multiple test 3" {' '  [ true ]' '}' '' '@test "multiple test 4" {' '  [ true ]' '}' '' '@test "multiple test 5" {' '  [ true ]' '}' > "$TEST_PROJECT_DIR/tests/bats/multiple.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/multiple.bats"
  
  # Ensure file is written to disk
  sync
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Suite name is based on file path: tests/bats/multiple.bats -> tests-bats-multiple
  assert_test_count "$output" "tests-bats-multiple" "5"
  assert_test_counts_present "$output"
  teardown_test_project
}

@test "detect test count for suite with no tests" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  cat > "$TEST_PROJECT_DIR/tests/bats/empty.bats" << 'EOF'
#!/usr/bin/env bats

# This file has no @test annotations
EOF
  chmod +x "$TEST_PROJECT_DIR/tests/bats/empty.bats"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Suite name is based on file path: tests/bats/empty.bats -> tests-bats-empty
  assert_test_count "$output" "tests-bats-empty" "0"
  assert_test_counts_present "$output"
  teardown_test_project
}

@test "detect different test counts for multiple suites" {
  setup_test_project
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"
  
  # Create suite with 2 tests using printf to avoid BATS parsing
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "suite1 test 1" {' '  [ true ]' '}' '' '@test "suite1 test 2" {' '  [ true ]' '}' > "$TEST_PROJECT_DIR/tests/bats/suite1.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/suite1.bats"
  
  # Create suite with 7 tests
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "suite2 test 1" { [ true ]; }' '@test "suite2 test 2" { [ true ]; }' '@test "suite2 test 3" { [ true ]; }' '@test "suite2 test 4" { [ true ]; }' '@test "suite2 test 5" { [ true ]; }' '@test "suite2 test 6" { [ true ]; }' '@test "suite2 test 7" { [ true ]; }' > "$TEST_PROJECT_DIR/tests/bats/suite2.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/suite2.bats"
  
  # Create suite with 1 test
  printf '%s\n' '#!/usr/bin/env bats' '' '@test "suite3 only test" {' '  [ true ]' '}' > "$TEST_PROJECT_DIR/tests/bats/suite3.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/suite3.bats"
  
  # Ensure files are written to disk
  sync
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Suite names are based on file paths
  assert_test_count "$output" "tests-bats-suite1" "2"
  assert_test_count "$output" "tests-bats-suite2" "7"
  assert_test_count "$output" "tests-bats-suite3" "1"
  assert_test_counts_present "$output"
  teardown_test_project
}

@test "test counts appear in output for all suites" {
  setup_test_project
  create_project_with_helpers "$TEST_PROJECT_DIR"
  
  output=$(run_scanner "$TEST_PROJECT_DIR")
  
  # Verify that test counts are present
  assert_test_counts_present "$output"
  
  # Count how many "Tests:" lines appear (should match number of suites)
  local test_count_lines
  test_count_lines=$(echo "$output" | grep -c "Tests:" || echo "0")
  
  if [[ $test_count_lines -lt 2 ]]; then
    echo "ERROR: Expected at least 2 test count lines (one per suite)"
    echo "Found: $test_count_lines"
    echo "Output: $output"
    teardown_test_project
    return 1
  fi
  
  teardown_test_project
}

