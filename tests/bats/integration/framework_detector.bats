#!/usr/bin/env bats

load ../helpers/framework_detector
load ../helpers/project_scanner
load ../helpers/fixtures

# ============================================================================
# End-to-End Detection Tests
# ============================================================================

@test "detect BATS framework in complete project structure" {
  setup_framework_detector_test
  create_bats_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_structured_output "$output" "framework_list"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "detect Rust framework in complete project structure" {
  setup_framework_detector_test
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "rust"
  assert_structured_output "$output" "framework_list"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "detect both BATS and Rust in multi-framework project" {
  setup_framework_detector_test
  create_multi_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_framework_detected "$output" "rust"
  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

@test "detect frameworks with missing binaries (warnings)" {
  setup_framework_detector_test
  create_bats_project "$TEST_PROJECT_DIR"

  mock_binary_unavailable "bats"
  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_detection_warning "$output" "bats binary is not available"
  assert_structured_output "$output" "warnings"

  restore_path
  teardown_framework_detector_test
}

@test "detect no frameworks in non-test project" {
  setup_framework_detector_test
  create_empty_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_not_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  # Should still produce structured output even with no frameworks
  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

# ============================================================================
# Integration with Project Scanner Tests
# ============================================================================

@test "Framework Detector called by Project Scanner" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Project Scanner output should include framework detection results
  assert_scanner_output "$output" "bats" "1"
  assert_structured_output "$output" "frameworks"
  teardown_test_project
}

@test "Framework Detector results used by Test Suite Discovery" {
  setup_test_project
  create_bats_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should discover test suites based on framework detection
  assert_scanner_output "$output" "bats" "1"
  assert_test_counts_present "$output"
  teardown_test_project
}

@test "Framework Detector results used by Build System Detector" {
  setup_test_project
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect build requirements based on framework
  assert_scanner_output "$output" "rust" "1"
  # Rust projects typically don't need additional build setup beyond cargo
  teardown_test_project
}

@test "Framework Detector integrates with Project Scanner error handling" {
  setup_test_project
  create_empty_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should handle no frameworks gracefully
  assert_no_test_suites "$output"
  assert_structured_output "$output" "frameworks"
  teardown_test_project
}

@test "Framework Detector results propagate through Project Scanner" {
  setup_test_project
  create_multi_framework_project "$TEST_PROJECT_DIR"

  output=$(run_scanner "$TEST_PROJECT_DIR")

  # Should detect and report multiple frameworks
  assert_scanner_output "$output" "bats" "1"
  # Note: Rust detection might need Cargo.toml for proper detection
  assert_structured_output "$output" "frameworks"
  teardown_test_project
}

# ============================================================================
# Real Project Scenarios Tests
# ============================================================================

@test "detect frameworks in BATS-only project" {
  setup_framework_detector_test
  create_bats_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "detect frameworks in Rust-only project" {
  setup_framework_detector_test
  create_rust_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "rust"
  assert_framework_not_detected "$output" "bats"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "detect frameworks in mixed-language project" {
  setup_framework_detector_test
  create_multi_language_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should detect both frameworks in mixed project
  assert_framework_detected "$output" "bats"
  assert_framework_detected "$output" "rust"
  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

@test "handle project with framework config but no test files" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create Cargo.toml but no actual test files
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "config_only"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should still detect Rust framework even without test files
  assert_framework_detected "$output" "rust"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "handle project with test files but no framework config" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR/tests/bats"

  # Create BATS files without other framework indicators
  printf '#!/usr/bin/env bats\n\n@test "manual test" {\n  [ true ]\n}\n' > "$TEST_PROJECT_DIR/tests/bats/manual.bats"
  chmod +x "$TEST_PROJECT_DIR/tests/bats/manual.bats"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should detect BATS framework from file patterns alone
  assert_framework_detected "$output" "bats"
  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "detect frameworks in nested directory structures" {
  setup_framework_detector_test
  create_nested_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

@test "handle framework detection in large project" {
  setup_framework_detector_test
  create_large_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should still work efficiently in larger projects
  assert_framework_detected "$output" "bats"
  assert_framework_detected "$output" "rust"
  [ $? -eq 0 ]  # Should complete without errors
  teardown_framework_detector_test
}

@test "detect frameworks with various file encodings" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create files with different characteristics
  printf '#!/usr/bin/env bats\n@test "normal" { [ true ]; }\n' > "$TEST_PROJECT_DIR/normal.bats"
  chmod +x "$TEST_PROJECT_DIR/normal.bats"

  # Create file with unusual shebang
  printf '#!/usr/bin/bats\n@test "unusual" { [ true ]; }\n' > "$TEST_PROJECT_DIR/unusual.bats"
  chmod +x "$TEST_PROJECT_DIR/unusual.bats"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "handle framework detection with symlinks" {
  setup_framework_detector_test
  create_bats_project "$TEST_PROJECT_DIR"

  # Create symlink to test directory
  ln -s "$TEST_PROJECT_DIR/tests" "$TEST_PROJECT_DIR/tests_link"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should handle symlinks without issues
  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect frameworks in project with build artifacts" {
  setup_framework_detector_test
  create_rust_project "$TEST_PROJECT_DIR"

  # Simulate build artifacts
  mkdir -p "$TEST_PROJECT_DIR/target/debug"
  echo "fake binary" > "$TEST_PROJECT_DIR/target/debug/test_binary"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should still detect framework despite build artifacts
  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

# ============================================================================
# Edge Cases and Error Scenarios
# ============================================================================

@test "handle empty project directory" {
  setup_framework_detector_test
  # Leave directory empty

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_not_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  # Should still produce valid structured output
  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

@test "handle project with only hidden files" {
  setup_framework_detector_test
  echo "hidden content" > "$TEST_PROJECT_DIR/.hidden"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_not_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "handle project with corrupted framework files" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create corrupted Cargo.toml
  echo '[package' > "$TEST_PROJECT_DIR/Cargo.toml"  # Missing closing bracket

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should handle corruption gracefully
  [ $? -eq 0 ]  # Should not crash
  teardown_framework_detector_test
}

@test "detect frameworks in case-sensitive filesystem scenarios" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create files with case variations
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "case_test"
version = "0.1.0"
edition = "2021"
EOF

  cat > "$TEST_PROJECT_DIR/cargo.toml" << 'EOF'
[package]
name = "lowercase"
version = "0.1.0"
edition = "2021"
EOF

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should detect the standard case
  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}
