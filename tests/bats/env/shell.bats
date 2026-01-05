#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


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

# ============================================================================
# Advanced Shell Feature Tests (Nameref, Eval, Scope)
# ============================================================================

@test "nameref assignment to associative array" {
  # Test if nameref assignment works at all
  declare -A test_array
  local -n ref="test_array"
  ref["test_key"]="test_value"
  
  [ "${test_array[test_key]}" = "test_value" ]
}

@test "nameref assignment from function" {
  # Test if nameref assignment works when called from a function
  test_nameref_function() {
    local array_name="$1"
    local -n array_ref="$array_name"
    array_ref["key"]="value"
  }
  
  declare -A test_array
  test_nameref_function "test_array"
  
  [ "${test_array[key]}" = "value" ]
}

@test "eval assignment in BATS context" {
  # Test if eval works at all in BATS context
  declare -A test_array
  local array_name="test_array"
  local key="test_key"
  local value="test_value"
  
  eval "${array_name}[\"${key}\"]=\"${value}\""
  
  [ "${test_array[test_key]}" = "test_value" ]
}

@test "eval assignment from sourced function" {
  # Test if eval works when called from a sourced function
  test_eval_func() {
    local array_name="$1"
    local key="$2"
    local value="$3"
    eval "${array_name}[\"${key}\"]=\"${value}\""
  }
  
  declare -A test_array
  test_eval_func "test_array" "test_key" "test_value"
  
  [ "${test_array[test_key]}" = "test_value" ]
}

@test "eval assignment in while loop" {
  # Test if eval works inside a while loop
  declare -A test_array
  local array_name="test_array"
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    local key="${line%%=*}"
    local value="${line#*=}"
    eval "${array_name}[\"${key}\"]=\"${value}\""
  done <<< "key1=value1"
  
  [ "${test_array[key1]}" = "value1" ]
}

@test "eval with printf %q for safe quoting" {
  # Test if eval with printf %q works
  declare -A test_array
  local array_name="test_array"
  local key="key1"
  local value="value1"
  
  local safe_key
  safe_key=$(printf '%q' "$key")
  local safe_value
  safe_value=$(printf '%q' "$value")
  
  eval "${array_name}[${safe_key}]=${safe_value}"
  
  [ "${test_array[key1]}" = "value1" ]
}

@test "eval variable scope from function" {
  # Test if eval can see the array_name variable when called from a function
  declare -A test_array
  local array_name="test_array"
  
  test_eval_func() {
    local arr_name="$1"
    local key="key1"
    local value="test_value"
    local safe_key
    safe_key=$(printf '%q' "$key")
    local safe_value
    safe_value=$(printf '%q' "$value")
    
    # Check if we can see the array from here
    if declare -p "$arr_name" &>/dev/null 2>&1; then
      echo "Array $arr_name exists from function" >&2
    else
      echo "Array $arr_name does NOT exist from function" >&2
    fi
    
    eval "${arr_name}[${safe_key}]=${safe_value}"
    
    # Check again after eval
    if declare -p "$arr_name" &>/dev/null 2>&1; then
      echo "After eval, array $arr_name exists" >&2
    else
      echo "After eval, array $arr_name does NOT exist" >&2
    fi
  }
  
  test_eval_func "$array_name"
  
  [ "${test_array[key1]}" = "test_value" ]
}

@test "array visibility across function scope" {
  # Test array visibility in function vs test scope
  declare -A test_array
  
  # Create a wrapper function that tests array visibility
  test_load_wrapper() {
    local array_name="$1"
    local key="$2"
    local value="$3"
    
    # Check if array exists
    if declare -p "$array_name" &>/dev/null 2>&1; then
      echo "Array $array_name EXISTS in wrapper" >&2
    else
      echo "Array $array_name does NOT exist in wrapper" >&2
    fi
    
    # Assign using eval
    local safe_key
    safe_key=$(printf '%q' "$key")
    local safe_value
    safe_value=$(printf '%q' "$value")
    
    # Check array again right before eval
    if declare -p "$array_name" &>/dev/null 2>&1; then
      echo "Array $array_name EXISTS right before eval" >&2
    else
      echo "Array $array_name does NOT exist right before eval" >&2
    fi
    
    eval "${array_name}[${safe_key}]=${safe_value}"
    
    # Check array right after eval
    if declare -p "$array_name" &>/dev/null 2>&1; then
      echo "Array $array_name EXISTS right after eval" >&2
    else
      echo "Array $array_name does NOT exist right after eval" >&2
    fi
  }
  
  if declare -p "test_array" &>/dev/null 2>&1; then
    echo "Array test_array EXISTS in test" >&2
  else
    echo "Array test_array does NOT exist in test" >&2
  fi
  
  test_load_wrapper "test_array" "key1" "test_value"
  
  if declare -p "test_array" &>/dev/null 2>&1; then
    echo "Array test_array EXISTS in test after call" >&2
  else
    echo "Array test_array does NOT exist in test after call" >&2
  fi
  
  [ "${test_array[key1]}" = "test_value" ]
}

@test "function subshell detection" {
  # Test if functions run in subshells (they shouldn't)
  declare -A test_array
  
  # Set a marker variable
  TEST_MARKER="before_function"
  
  # Check if function can see/modify variables
  test_subshell_check() {
    local array_name="$1"
    TEST_MARKER="inside_function"
    
    # Try to modify the array
    local safe_key
    safe_key=$(printf '%q' "key1")
    local safe_value
    safe_value=$(printf '%q' "test_value")
    eval "${array_name}[${safe_key}]=${safe_value}"
  }
  
  test_subshell_check "test_array"
  
  # If function is in subshell, TEST_MARKER would still be "before_function"
  [ "$TEST_MARKER" = "inside_function" ]
  [ "${test_array[key1]}" = "test_value" ]
}
