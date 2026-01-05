#!/usr/bin/env bats

# BATS test that uses helpers
# This demonstrates helper loading and usage

load helpers/test_helper

@test "test using helper functions" {
  # Create a test file using helper
  create_test_file "test.txt" "hello world"

  # Check file exists using helper
  file_exists "test.txt"

  # Read file content
  content=$(cat "$TEST_TMPDIR/test.txt")
  assert_string_equals "hello world" "$content"
}

@test "test helper setup/teardown" {
  # The setup() function should have created TEST_TMPDIR
  [ -d "$TEST_TMPDIR" ]

  # Create another file
  echo "test content" > "$TEST_TMPDIR/another.txt"
  file_exists "another.txt"
}

@test "test multiple helper calls" {
  create_test_file "file1.txt" "content1"
  create_test_file "file2.txt" "content2"

  file_exists "file1.txt"
  file_exists "file2.txt"

  content1=$(cat "$TEST_TMPDIR/file1.txt")
  content2=$(cat "$TEST_TMPDIR/file2.txt")

  assert_string_equals "content1" "$content1"
  assert_string_equals "content2" "$content2"
}
