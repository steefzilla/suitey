#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# ============================================================================
# Shell Compatibility and Feature Tests
# ============================================================================

@test "bash version is at least 4.0" {
  local major_version
  major_version=$(bash --version | head -1 | grep -o "version [0-9]" | cut -d' ' -f2)
  [ "$major_version" -ge 4 ]
}

@test "bash supports associative arrays" {
  # Test declare -A syntax
  run bash -c "declare -A test_array; test_array[key]='value'; echo \${test_array[key]}"
  [ "$status" -eq 0 ]
  [[ "$output" == "value" ]]
}

@test "bash associative arrays work in current shell" {
  declare -A test_array
  test_array["test_key"]="test_value"
  [[ "${test_array["test_key"]}" == "test_value" ]]
}

@test "bash supports mapfile/readarray" {
  # Test mapfile command
  run bash -c "
    mapfile -t lines <<< \$'line1\nline2\nline3'
    echo \"\${lines[0]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "line1" ]]
}

@test "bash supports readarray" {
  # Test readarray command (alias for mapfile)
  run bash -c "
    readarray -t lines <<< \$'line1\nline2\nline3'
    echo \"\${lines[1]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "line2" ]]
}

@test "bash supports set -euo pipefail" {
  # Test that set -euo pipefail works
  run bash -c "set -euo pipefail; echo 'test'"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]
}

@test "bash set -e fails on command failure" {
  # Test that set -e causes exit on command failure
  run -1 bash -c "set -e; false; echo 'should not reach here'"
  [ "$status" -ne 0 ]
  [[ "$output" != *"should not reach here"* ]]
}

@test "bash set -u prevents unbound variables" {
  # Test that set -u prevents unbound variable access
  run -127 bash -c "set -u; echo \$undefined_variable"
  [ "$status" -ne 0 ]
}

@test "bash supports parameter expansion" {
  # Test various parameter expansion features
  run bash -c "var='test'; echo \${var:-default}"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]
}

@test "bash supports parameter expansion with defaults" {
  # Test default value expansion
  run bash -c "unset var; echo \${var:-default}"
  [ "$status" -eq 0 ]
  [[ "$output" == "default" ]]
}

@test "bash supports parameter expansion with assignment" {
  # Test := expansion
  run bash -c "unset var; echo \${var:=assigned}; echo \$var"
  [ "$status" -eq 0 ]
  [[ "$output" == $'assigned\nassigned' ]]
}

@test "bash supports substring expansion" {
  # Test substring operations
  run bash -c "var='hello world'; echo \${var:0:5}"
  [ "$status" -eq 0 ]
  [[ "$output" == "hello" ]]
}

@test "bash supports pattern substitution" {
  # Test pattern replacement
  run bash -c "var='hello world'; echo \${var/world/universe}"
  [ "$status" -eq 0 ]
  [[ "$output" == "hello universe" ]]
}

@test "bash supports array operations" {
  # Test array operations
  run bash -c "array=(one two three); echo \${array[0]} \${#array[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == "one 3" ]]
}

@test "bash supports indirect variable expansion" {
  # Test indirect expansion
  run bash -c "var='value'; ref='var'; echo \${!ref}"
  [ "$status" -eq 0 ]
  [[ "$output" == "value" ]]
}

@test "bash supports command substitution" {
  # Test command substitution
  run bash -c "echo \$(echo 'nested command')"
  [ "$status" -eq 0 ]
  [[ "$output" == "nested command" ]]
}

@test "bash supports process substitution" {
  # Test process substitution (if supported)
  run bash -c "diff <(echo 'a') <(echo 'a')"
  [ "$status" -eq 0 ]
}

@test "bash supports extended globbing" {
  # Test extended globbing
  run bash -c "shopt -s extglob; var='test'; [[ \$var == @(test|other) ]] && echo 'matched'"
  [ "$status" -eq 0 ]
  [[ "$output" == "matched" ]]
}

@test "bash supports here strings" {
  # Test here strings
  run bash -c "read var <<< 'test input'; echo \$var"
  [ "$status" -eq 0 ]
  [[ "$output" == "test input" ]]
}

@test "bash supports here documents" {
  # Test here documents
  run bash -c "cat << EOF
test
content
EOF"
  [ "$status" -eq 0 ]
  [[ "$output" == $'test\ncontent' ]]
}

@test "bash supports coprocesses" {
  # Test coprocess support (bash 4.0+)
  run bash -c "coproc test_proc { echo 'coprocess output'; }; read -r output <&\"\${test_proc[0]}\"; echo \"\$output\""
  [ "$status" -eq 0 ]
  [[ "$output" == "coprocess output" ]]
}

@test "bash supports namerefs" {
  # Test nameref variables (bash 4.3+)
  run bash -c "declare -n ref='var'; var='value'; echo \$ref"
  [ "$status" -eq 0 ]
  [[ "$output" == "value" ]]
}

@test "bash arithmetic expansion works" {
  # Test arithmetic expansion
  run bash -c "echo \$((2 + 2))"
  [ "$status" -eq 0 ]
  [[ "$output" == "4" ]]
}

@test "bash supports brace expansion" {
  # Test brace expansion
  run bash -c "echo {a,b,c}"
  [ "$status" -eq 0 ]
  [[ "$output" == "a b c" ]]
}

@test "bash supports tilde expansion" {
  # Test tilde expansion
  run bash -c "echo ~"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
