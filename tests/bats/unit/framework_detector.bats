#!/usr/bin/env bats

load ../helpers/framework_detector
load ../helpers/fixtures

# ============================================================================
# Framework Identification Tests
# ============================================================================

@test "detect BATS framework via .bats file extension" {
  setup_framework_detector_test
  create_project_with_pattern "$TEST_PROJECT_DIR" "bats_extension"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect BATS framework via directory patterns (tests/bats/)" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect BATS framework via directory patterns (test/bats/)" {
  setup_framework_detector_test
  create_bats_alt_dirs_project "$TEST_PROJECT_DIR" "test/bats"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect BATS framework via directory patterns (tests/)" {
  setup_framework_detector_test
  create_bats_alt_dirs_project "$TEST_PROJECT_DIR" "tests"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect BATS framework via shebang patterns" {
  setup_framework_detector_test
  create_bats_shebang_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  teardown_framework_detector_test
}

@test "detect Rust framework via Cargo.toml presence" {
  setup_framework_detector_test
  create_project_with_pattern "$TEST_PROJECT_DIR" "cargo_toml_only"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "detect Rust framework via unit test patterns (#[cfg(test)])" {
  setup_framework_detector_test
  create_project_with_pattern "$TEST_PROJECT_DIR" "rust_cfg_test"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "detect Rust framework via integration test patterns (tests/*.rs)" {
  setup_framework_detector_test
  create_rust_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "detect multiple frameworks in same project" {
  setup_framework_detector_test
  create_multi_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "detect no frameworks in empty project" {
  setup_framework_detector_test
  create_empty_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_not_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "detect no frameworks in project without test indicators" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"
  echo "not a test file" > "$TEST_PROJECT_DIR/random.txt"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_not_detected "$output" "bats"
  assert_framework_not_detected "$output" "rust"
  teardown_framework_detector_test
}

# ============================================================================
# Binary Availability Checking Tests
# ============================================================================

@test "check bats binary availability when present" {
  if is_binary_available "bats"; then
    setup_framework_detector_test
    create_bats_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_framework_detected "$output" "bats"
    assert_binary_available "$output" "bats"
    teardown_framework_detector_test
  else
    skip "bats binary not available for testing"
  fi
}

@test "check bats binary availability when missing" {
  if ! is_binary_available "bats"; then
    setup_framework_detector_test
    create_bats_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_framework_detected "$output" "bats"
    assert_binary_missing "$output" "bats"
    teardown_framework_detector_test
  else
    skip "bats binary is available - cannot test missing binary scenario"
  fi
}

@test "check cargo binary availability when present" {
  if is_binary_available "cargo"; then
    setup_framework_detector_test
    create_rust_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_framework_detected "$output" "rust"
    assert_binary_available "$output" "rust"
    teardown_framework_detector_test
  else
    skip "cargo binary not available for testing"
  fi
}

@test "check cargo binary availability when missing" {
  if ! is_binary_available "cargo"; then
    setup_framework_detector_test
    create_rust_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_framework_detected "$output" "rust"
    assert_binary_missing "$output" "rust"
    teardown_framework_detector_test
  else
    skip "cargo binary is available - cannot test missing binary scenario"
  fi
}

@test "warn when framework detected but binary missing" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  # Mock bats binary as unavailable
  mock_binary_unavailable "bats"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_detected "$output" "bats"
  assert_detection_warning "$output" "bats binary is not available"

  restore_path
  teardown_framework_detector_test
}

@test "do not warn when framework detected and binary present" {
  if is_binary_available "bats"; then
    setup_framework_detector_test
    create_bats_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_framework_detected "$output" "bats"
    # Should not contain warning about missing bats binary
    if echo "$output" | grep -q "bats binary is not available"; then
      echo "ERROR: Should not warn about missing bats when binary is available"
      return 1
    fi

    teardown_framework_detector_test
  else
    skip "bats binary not available for testing"
  fi
}

# ============================================================================
# Detection Confidence Levels Tests
# ============================================================================

@test "assign high confidence with multiple indicators (config + binary + files)" {
  if is_binary_available "bats"; then
    setup_framework_detector_test
    create_bats_framework_project "$TEST_PROJECT_DIR"

    output=$(run_framework_detector "$TEST_PROJECT_DIR")

    assert_confidence_level "$output" "bats" "high"
    teardown_framework_detector_test
  else
    skip "bats binary not available for testing"
  fi
}

@test "assign medium confidence with some indicators (config or files)" {
  setup_framework_detector_test
  create_project_with_pattern "$TEST_PROJECT_DIR" "bats_extension"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_confidence_level "$output" "bats" "medium"
  teardown_framework_detector_test
}

@test "assign low confidence with weak indicators (patterns only)" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR/tests"
  echo "some content" > "$TEST_PROJECT_DIR/tests/some.bats"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_confidence_level "$output" "bats" "low"
  teardown_framework_detector_test
}

# ============================================================================
# Framework Metadata Collection Tests
# ============================================================================

@test "collect BATS framework metadata (name, binaries, patterns)" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_metadata "$output" "bats" "name" "bats"
  assert_framework_metadata "$output" "bats" "binaries" "bats"
  teardown_framework_detector_test
}

@test "collect Rust framework metadata (name, binaries, patterns)" {
  setup_framework_detector_test
  create_rust_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_metadata "$output" "rust" "name" "rust"
  assert_framework_metadata "$output" "rust" "binaries" "cargo"
  teardown_framework_detector_test
}

@test "collect framework version when detectable" {
  # This test would check if framework version is detected and included in metadata
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Version detection might not be implemented initially, so this is more of a placeholder
  assert_framework_metadata "$output" "bats" "version" ""
  teardown_framework_detector_test
}

@test "collect configuration file locations" {
  setup_framework_detector_test
  create_rust_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_metadata "$output" "rust" "config_files" "Cargo.toml"
  teardown_framework_detector_test
}

@test "collect test file patterns for each framework" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_framework_metadata "$output" "bats" "file_patterns" "*.bats"
  teardown_framework_detector_test
}

# ============================================================================
# Detection Result Aggregation Tests
# ============================================================================

@test "aggregate results from multiple adapters" {
  setup_framework_detector_test
  create_multi_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should contain results from both BATS and Rust adapters
  assert_framework_detected "$output" "bats"
  assert_framework_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "structure output with framework list" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_structured_output "$output" "framework_list"
  teardown_framework_detector_test
}

@test "structure output with framework details" {
  setup_framework_detector_test
  create_rust_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_structured_output "$output" "framework_details"
  teardown_framework_detector_test
}

@test "structure output with warnings array" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  mock_binary_unavailable "bats"
  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_structured_output "$output" "warnings"
  restore_path
  teardown_framework_detector_test
}

@test "structure output with errors array" {
  setup_framework_detector_test
  create_empty_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Errors array should be present even if empty
  assert_structured_output "$output" "errors"
  teardown_framework_detector_test
}

@test "structure output with binary status mapping" {
  setup_framework_detector_test
  create_bats_framework_project "$TEST_PROJECT_DIR"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  assert_structured_output "$output" "binary_status"
  teardown_framework_detector_test
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "handle invalid configuration files gracefully" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create invalid Cargo.toml
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[invalid toml syntax
name = "test"
version = 0.1.0
EOF

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should not crash and should handle the error gracefully
  assert_framework_not_detected "$output" "rust"
  teardown_framework_detector_test
}

@test "handle unreadable files gracefully" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"
  echo "readable file" > "$TEST_PROJECT_DIR/readable.txt"

  # Create a file with no read permissions
  echo "unreadable file" > "$TEST_PROJECT_DIR/unreadable.txt"
  chmod 000 "$TEST_PROJECT_DIR/unreadable.txt"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should not crash due to unreadable file
  [ $? -eq 0 ]

  teardown_framework_detector_test
}

@test "handle permission errors gracefully" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR/subdir"

  # Create a directory with no access permissions
  chmod 000 "$TEST_PROJECT_DIR/subdir"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should not crash due to permission errors
  [ $? -eq 0 ]

  teardown_framework_detector_test
}

@test "handle conflicting framework configurations" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create both Cargo.toml and package.json (conflicting frameworks)
  cat > "$TEST_PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "conflict"
version = "0.1.0"
edition = "2021"
EOF

  cat > "$TEST_PROJECT_DIR/package.json" << 'EOF'
{
  "name": "conflict",
  "version": "1.0.0",
  "scripts": {
    "test": "jest"
  }
}
EOF

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should detect both frameworks without crashing
  # (Future frameworks like JavaScript/TypeScript would be detected here)
  assert_framework_detected "$output" "rust"

  teardown_framework_detector_test
}

@test "handle ambiguous detection results" {
  setup_framework_detector_test
  mkdir -p "$TEST_PROJECT_DIR"

  # Create ambiguous indicators that might match multiple patterns
  echo "#!/usr/bin/env bats" > "$TEST_PROJECT_DIR/ambiguous.bats"
  echo '@test "ambiguous" { [ true ]; }' >> "$TEST_PROJECT_DIR/ambiguous.bats"
  chmod +x "$TEST_PROJECT_DIR/ambiguous.bats"

  # Also create a directory that might confuse detection
  mkdir -p "$TEST_PROJECT_DIR/test"

  output=$(run_framework_detector "$TEST_PROJECT_DIR")

  # Should still correctly identify BATS framework
  assert_framework_detected "$output" "bats"

  teardown_framework_detector_test
}
