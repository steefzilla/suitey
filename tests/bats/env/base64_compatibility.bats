#!/usr/bin/env bats

# ============================================================================
# Base64 Compatibility and Variant Tests
# ============================================================================

# Global platform detection - set at file load time (not in setup_file)
# This ensures the variable is available when skip conditions are evaluated
if [[ "$OSTYPE" == "darwin"* ]]; then
  export BATS_PLATFORM="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux-musl"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
  export BATS_PLATFORM="linux"
elif [[ -n "${OS:-}" ]] && [[ "$OS" == "Windows_NT" ]]; then
  export BATS_PLATFORM="windows"
else
  # Fallback to uname if OSTYPE isn't set
  uname_os=$(uname -s 2>/dev/null || echo "unknown")
  case "$uname_os" in
    Darwin) export BATS_PLATFORM="macos" ;;
    Linux) export BATS_PLATFORM="linux" ;;
    *) export BATS_PLATFORM="unknown" ;;
  esac
fi

@test "base64 supports GNU-style -w 0 option" {
  run bash -c "echo 'test' | base64 -w 0"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "base64 GNU -w 0 round-trip works" {
  run bash -c "echo 'test data' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "test data" ]]
}

@test "base64 macOS -b 0 round-trip works" {
  [[ "$BATS_PLATFORM" == "macos" ]] || skip "macOS-style base64 not available on $BATS_PLATFORM"

  run bash -c "echo 'test data' | base64 -b 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "test data" ]]
}

@test "base64 fallback with tr works" {
  run bash -c "echo 'test data' | base64 | tr -d '\n' | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "test data" ]]
}

@test "base64 handles empty input" {
  run bash -c "echo -n '' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "base64 handles simple text" {
  local input="Hello, World!"
  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles JSON data" {
  local input='{"name": "test", "value": 123}'
  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles special characters" {
  local input='special chars: !@#$%^&*()[]{}|;:,.<>?`~'
  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles unicode characters" {
  local input='unicode: ñáéíóú 中文 🚀'
  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles newlines in input" {
  local input=$'line1\nline2\nline3'
  run bash -c "printf '%s' '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles binary-like data" {
  # Create some "binary-like" data with null bytes and control chars
  local input=$'\x00\x01\x02\x03\x04\x05\xff\xfe\xfd'
  run bash -c "printf '%s' '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles large input (1KB)" {
  # Create a 1KB string
  local input=""
  for i in {1..128}; do
    input="${input}This is a test string that will be repeated. "
  done
  input="${input:0:1024}" # Truncate to exactly 1KB

  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 handles very large input (10KB)" {
  # Create a ~10KB string
  local input=""
  for i in {1..1280}; do
    input="${input}This is a test string that will be repeated to create a large input. "
  done
  input="${input:0:10240}" # Truncate to exactly 10KB

  run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}

@test "base64 round-trip with all variants" {
  local input='Test data with special chars: {"json": "value"} ñáéíóú'

  # Test GNU style (Linux/default)
  local encoded_gnu
  encoded_gnu=$(echo -n "$input" | base64 -w 0)
  local decoded_gnu
  decoded_gnu=$(echo -n "$encoded_gnu" | base64 -d)
  [[ "$decoded_gnu" == "$input" ]]

  # Test macOS style only on macOS
  if [[ "$BATS_PLATFORM" == "macos" ]]; then
    local encoded_macos
    encoded_macos=$(echo -n "$input" | base64 -b 0)
    local decoded_macos
    decoded_macos=$(echo -n "$encoded_macos" | base64 -d)
    [[ "$decoded_macos" == "$input" ]]
  fi

  # Test fallback style (works everywhere)
  local encoded_fallback
  encoded_fallback=$(echo -n "$input" | base64 | tr -d '\n')
  local decoded_fallback
  decoded_fallback=$(echo -n "$encoded_fallback" | base64 -d)
  [[ "$decoded_fallback" == "$input" ]]
}

@test "base64 encoding produces valid base64" {
  local input="test input data"
  local encoded
  encoded=$(echo -n "$input" | base64 -w 0)

  # Basic validation: only contains valid base64 chars
  [[ "$encoded" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]
}

@test "base64 handles input with padding requirements" {
  # Test inputs that require different amounts of padding
  local inputs=("a" "ab" "abc" "abcd")

  for input in "${inputs[@]}"; do
    run bash -c "echo -n '$input' | base64 -w 0 | base64 -d"
    [ "$status" -eq 0 ]
    [[ "$output" == "$input" ]]
  done
}

@test "base64 encoding is deterministic" {
  local input="consistent test data"
  local encoded1
  local encoded2

  encoded1=$(echo -n "$input" | base64 -w 0)
  encoded2=$(echo -n "$input" | base64 -w 0)

  [[ "$encoded1" == "$encoded2" ]]
}

@test "base64 decoding handles malformed input gracefully" {
  # Test with invalid base64 (should fail)
  run bash -c "echo 'invalid!!!' | base64 -d"
  [ "$status" -ne 0 ]
}

@test "base64 handles input with embedded newlines" {
  local input=$'line 1\n{"json": "data"}\nline 3'
  run bash -c "printf '%s' '$input' | base64 -w 0 | base64 -d"
  [ "$status" -eq 0 ]
  [[ "$output" == "$input" ]]
}
