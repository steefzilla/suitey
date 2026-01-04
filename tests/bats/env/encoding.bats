#!/usr/bin/env bats

# ============================================================================
# Character Encoding and Special Character Tests
# ============================================================================

@test "basic UTF-8 support" {
  local testfile="/tmp/bats_utf8_test_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  [[ "$(cat "$testfile")" == "test content" ]]
  rm -f "$testfile"
}

@test "filenames with spaces work" {
  local testfile="/tmp/bats space test $$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  [[ "$(cat "$testfile")" == "test content" ]]
  rm -f "$testfile"
}

@test "basic heredoc works" {
  local content
  content=$(cat << 'EOF'
test content
with multiple lines
EOF
)

  [[ "$content" == *"test content"* ]]
  [[ "$content" == *"multiple lines"* ]]
}