#!/usr/bin/env bats

load helpers/project_scanner

# Get the path to suitey.sh
get_suitey_script() {
  if [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    echo "$BATS_TEST_DIRNAME/../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../suitey.sh" ]]; then
    echo "$BATS_TEST_DIRNAME/../suitey.sh"
  else
    echo "$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)/suitey.sh"
  fi
}

@test "suitey.sh exists" {
  [ -f "$(get_suitey_script)" ]
}

@test "suitey.sh --help shows help text" {
  local script
  script=$(get_suitey_script)
  
  run "$script" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Suitey Project Scanner"* ]]
  [[ "$output" == *"USAGE:"* ]]
  [[ "$output" == *"OPTIONS:"* ]]
  [[ "$output" == *"--help"* ]]
}

@test "suitey.sh -h shows help text" {
  local script
  script=$(get_suitey_script)
  
  run "$script" -h
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Suitey Project Scanner"* ]]
  [[ "$output" == *"USAGE:"* ]]
  [[ "$output" == *"OPTIONS:"* ]]
  [[ "$output" == *"-h"* ]]
}

@test "help text contains usage information" {
  local script
  script=$(get_suitey_script)
  
  run "$script" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"suitey.sh [OPTIONS] [PROJECT_ROOT]"* ]]
}

@test "help text does not contain verbose sections" {
  local script
  script=$(get_suitey_script)
  
  run "$script" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" != *"EXAMPLES:"* ]]
  [[ "$output" != *"DETECTED FRAMEWORKS:"* ]]
  [[ "$output" != *"OUTPUT:"* ]]
  [[ "$output" != *"EXIT CODES:"* ]]
}

@test "unknown option shows error and suggests help" {
  local script
  script=$(get_suitey_script)
  
  run "$script" --unknown-option
  
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option"* ]]
  [[ "$output" == *"--help"* ]]
}

@test "multiple project root arguments shows error" {
  local script
  script=$(get_suitey_script)
  
  run "$script" /tmp /var
  
  [ "$status" -eq 2 ]
  [[ "$output" == *"Multiple project root arguments"* ]]
  [[ "$output" == *"--help"* ]]
}

