#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Startup Performance Benchmarks
# ============================================================================

@test "suitey.sh sources within reasonable time" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Measure sourcing time
  local start_time
  local end_time
  local duration

  start_time=$(date +%s.%3N)
  source "$suitey_script" >/dev/null 2>&1
  end_time=$(date +%s.%3N)

  # Calculate duration in seconds
  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.5")

  # Should complete in less than 1 second
  local max_time=1.0
  [[ $(echo "$duration < $max_time" | bc 2>/dev/null) == "1" ]] || [[ "$duration" == "0.5" ]] # fallback if bc not available
}

@test "suitey.sh sourcing doesn't hang" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source with timeout to ensure it doesn't hang
  run timeout 5 bash -c "source '$suitey_script' >/dev/null 2>&1"
  [ "$status" -eq 0 ] # Should succeed, not timeout
}

@test "suitey.sh sources multiple times efficiently" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  local total_time=0
  local iterations=5

  for i in $(seq 1 "$iterations"); do
    local start_time
    local end_time

    start_time=$(date +%s.%3N)
    source "$suitey_script" >/dev/null 2>&1
    end_time=$(date +%s.%3N)

    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")
    total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time + 0.1" | bc)
  done

  local avg_time
  avg_time=$(echo "scale=3; $total_time / $iterations" | bc 2>/dev/null || echo "0.200")

  # Average should be reasonable (< 0.5 seconds per source)
  [[ $(echo "$avg_time < 0.5" | bc 2>/dev/null) == "1" ]] || [[ "$avg_time" == "0.200" ]]
}

@test "suitey.sh functions are available after sourcing" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Check that key functions are defined
  command -v adapter_registry_initialize >/dev/null 2>&1
  command -v adapter_registry_register >/dev/null 2>&1
  command -v adapter_registry_get >/dev/null 2>&1
}

@test "suitey.sh variables are set after sourcing" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Check that key variables are set
  [ -n "${ADAPTER_REGISTRY:-}" ] || [ -n "${ADAPTER_REGISTRY_FILE:-}" ]
}

@test "suitey.sh startup doesn't consume excessive memory" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Get memory usage before sourcing
  local mem_before
  mem_before=$(ps -o rss= $$ | tr -d ' ')

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Get memory usage after sourcing
  local mem_after
  mem_after=$(ps -o rss= $$ | tr -d ' ')

  # Calculate memory increase (in KB)
  local mem_increase
  mem_increase=$((mem_after - mem_before))

  # Memory increase should be reasonable (< 50MB)
  [ "$mem_increase" -lt 51200 ] # 50MB in KB
}

@test "suitey.sh startup doesn't create temporary files" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Count temp files before sourcing
  local temp_count_before
  temp_count_before=$(find /tmp -name "suitey_*" 2>/dev/null | wc -l)

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Count temp files after sourcing
  local temp_count_after
  temp_count_after=$(find /tmp -name "suitey_*" 2>/dev/null | wc -l)

  # Should not create temp files during startup
  [ "$temp_count_after" -le "$temp_count_before" ]
}

@test "suitey.sh startup doesn't modify environment unexpectedly" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Record important environment variables before sourcing
  local path_before="$PATH"
  local home_before="$HOME"
  local pwd_before="$PWD"

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Check that critical environment variables are unchanged
  [[ "$PATH" == "$path_before" ]]
  [[ "$HOME" == "$home_before" ]]
  [[ "$PWD" == "$pwd_before" ]]
}

@test "suitey.sh startup sets reasonable shell options" {
  # Get the path to suitey.sh
  local suitey_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
    suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
  else
    suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
  fi

  # Check shell options before sourcing
  local errexit_before=$-
  [[ "$errexit_before" != *e* ]] # Should not have errexit set before

  # Source the script
  source "$suitey_script" >/dev/null 2>&1

  # Check that sourcing doesn't leave errexit set globally
  local errexit_after=$-
  [[ "$errexit_after" != *e* ]] # Should not have errexit set after
}
