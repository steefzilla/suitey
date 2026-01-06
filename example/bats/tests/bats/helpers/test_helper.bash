#!/usr/bin/env bash

# Helper functions for BATS tests
# This file demonstrates helper usage in BATS projects

# Setup function for tests
setup() {
  export TEST_TMPDIR="/tmp/suitey_bats_test_$$"
  mkdir -p "$TEST_TMPDIR"
}

# Teardown function for tests
teardown() {
  if [[ -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

# Helper function to create test files
create_test_file() {
  local filename="$1"
  local content="$2"
  echo "$content" > "$TEST_TMPDIR/$filename"
}

# Helper function to check if file exists
file_exists() {
  local filename="$1"
  [[ -f "$TEST_TMPDIR/$filename" ]]
}

# Helper function for assertions
assert_string_equals() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]]
}
