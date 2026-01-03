#!/usr/bin/env bats

@test "suitey.sh exists" {
  [ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]
}

