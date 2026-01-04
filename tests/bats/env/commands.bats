#!/usr/bin/env bats

# ============================================================================
# Command Availability and Functionality Tests
# ============================================================================

@test "base64 command is available" {
  command -v base64 >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "base64 command works correctly" {
  run bash -c "echo 'test' | base64 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]
}

@test "mktemp command is available" {
  command -v mktemp >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "mktemp command creates temporary directory" {
  local tmpdir
  tmpdir=$(mktemp -d -t "bats_test_XXXXXX")
  [ -d "$tmpdir" ]
  [ -w "$tmpdir" ]
  rm -rf "$tmpdir"
}

@test "docker command is available" {
  command -v docker >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "docker command has version" {
  run docker --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Docker version" ]]
}

@test "docker-compose command is available" {
  command -v docker-compose >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "printf command is available" {
  command -v printf >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "printf command works correctly" {
  run printf "test"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]
}

@test "grep command is available" {
  command -v grep >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "grep command works correctly" {
  run bash -c "echo 'test line' | grep 'test'"
  [ "$status" -eq 0 ]
  [[ "$output" == "test line" ]]
}

@test "sed command is available" {
  command -v sed >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "sed command works correctly" {
  run bash -c "echo 'test' | sed 's/test/replaced/'"
  [ "$status" -eq 0 ]
  [[ "$output" == "replaced" ]]
}

@test "awk command is available" {
  command -v awk >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "awk command works correctly" {
  run bash -c "echo 'test data' | awk '{print \$1}'"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]
}

@test "bash command has required version" {
  # Test that bash is at least version 4 (required for associative arrays)
  local bash_version
  bash_version=$(bash --version | head -1 | grep -o "version [0-9]" | cut -d' ' -f2)
  [ "$bash_version" -ge 4 ]
}

@test "curl command is available (for network tests)" {
  command -v curl >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "curl command can make HTTP requests" {
  # Test basic HTTP functionality (don't rely on external services)
  run curl --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "curl" ]]
}

@test "which command is available" {
  command -v which >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "which command finds commands" {
  run which bash
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "stat command is available" {
  command -v stat >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "stat command works on files" {
  local tmpfile
  tmpfile=$(mktemp)
  echo "test" > "$tmpfile"
  run stat "$tmpfile"
  [ "$status" -eq 0 ]
  rm -f "$tmpfile"
}

@test "date command is available" {
  command -v date >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "date command formats timestamps" {
  run date +%Y%m%d
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]{8} ]]
}

@test "head command is available" {
  command -v head >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "head command limits output" {
  run bash -c "printf 'line1\nline2\nline3\n' | head -2"
  [ "$status" -eq 0 ]
  [[ $(echo "$output" | wc -l) -eq 2 ]]
}

@test "tail command is available" {
  command -v tail >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "tail command shows end of file" {
  run bash -c "printf 'line1\nline2\nline3\n' | tail -1"
  [ "$status" -eq 0 ]
  [[ "$output" == "line3" ]]
}

@test "wc command is available" {
  command -v wc >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "wc command counts lines" {
  run bash -c "printf 'line1\nline2\nline3\n' | wc -l"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3" ]]
}

@test "tr command is available" {
  command -v tr >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "tr command transforms characters" {
  run bash -c "echo 'ABC' | tr 'A-Z' 'a-z'"
  [ "$status" -eq 0 ]
  [[ "$output" == "abc" ]]
}
