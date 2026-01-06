#!/usr/bin/env bats

# Suitey BATS example test suite
# This test suite demonstrates BATS framework detection

@test "example test in tests/bats/" {
  [ true ]
}

@test "another test in tests/bats/" {
  [[ "hello" == "hello" ]]
}

@test "test with command substitution" {
  result="$(echo "world")"
  [ "$result" = "world" ]
}
