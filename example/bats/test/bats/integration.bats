#!/usr/bin/env bats

# Integration tests for BATS example
# Located in test/bats/ directory

@test "integration test in test/bats/" {
  # Test basic arithmetic
  result=$((2 + 2))
  [ "$result" -eq 4 ]
}

@test "test with setup and teardown" {
  # This would normally have setup/teardown
  [ -n "test" ]
}

@test "test with multiple assertions" {
  [ "hello" = "hello" ]
  [[ 5 -gt 3 ]]
  [ ! -z "non-empty" ]
}
