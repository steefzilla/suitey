#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Framework Detector helper functions

# Source framework detector modules from src/
_source_framework_detector_modules() {
  # Find and source json_helpers.sh (needed by framework_detector.sh)
  local json_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../../src/json_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/json_helpers.sh" ]]; then
    json_helpers_script="$BATS_TEST_DIRNAME/../../src/json_helpers.sh"
  else
    json_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/json_helpers.sh"
  fi
  source "$json_helpers_script"

  # Find and source adapter_registry_helpers.sh (needed by adapter_registry.sh)
  local adapter_registry_helpers_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry_helpers.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh" ]]; then
    adapter_registry_helpers_script="$BATS_TEST_DIRNAME/../../src/adapter_registry_helpers.sh"
  else
    adapter_registry_helpers_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry_helpers.sh"
  fi
  source "$adapter_registry_helpers_script"

  # Find and source adapter_registry.sh (needed by framework_detector.sh)
  local adapter_registry_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../../src/adapter_registry.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapter_registry.sh" ]]; then
    adapter_registry_script="$BATS_TEST_DIRNAME/../../src/adapter_registry.sh"
  else
    adapter_registry_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/adapter_registry.sh"
  fi
  source "$adapter_registry_script"

  # Find and source framework_detector.sh
  local framework_detector_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../../src/framework_detector.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/framework_detector.sh" ]]; then
    framework_detector_script="$BATS_TEST_DIRNAME/../../src/framework_detector.sh"
  else
    framework_detector_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src" && pwd)/framework_detector.sh"
  fi
  source "$framework_detector_script"
}

_source_framework_detector_modules

# Mock helper functions for testing
count_bats_tests() {
	echo "2"
}

count_rust_tests() {
	echo "3"
}

# ============================================================================
# Helper Function Tests
# ============================================================================

@test "_parse_split_json_array splits single object JSON" {
	local json_array='[{"name":"test","files":["test.bats"]}]'
	local result
	result=$(_parse_split_json_array "$json_array")

	[[ "$result" == *"test"* ]]
	[[ "$result" == *"test.bats"* ]]
}

@test "_parse_split_json_array splits multiple object JSON" {
	local json_array='[{"name":"test1","files":["test1.bats"]},{"name":"test2","files":["test2.bats"]}]'
	local result
	result=$(_parse_split_json_array "$json_array")

	local object_count=0
	while IFS= read -r line; do
		if [[ "$line" == *"name"* ]]; then
			((++object_count))  # Use pre-increment to avoid 0 evaluation issue with set -e
		fi
	done <<< "$result"

	[ "$object_count" -eq 2 ]
}

@test "_parse_split_json_array handles empty array" {
	local json_array='[]'
	local result
	result=$(_parse_split_json_array "$json_array")

	[ -z "$result" ]
}

@test "_parse_extract_suite_data extracts valid suite data" {
	local suite_obj='{"name":"test_suite","test_files":["test1.bats","test2.bats"]}'
	local framework="bats"

	local result
	result=$(_parse_extract_suite_data "$suite_obj" "$framework")

	# Should output suite name first
	local suite_name=$(echo "$result" | head -1)
	[ "$suite_name" = "test_suite" ]

	# Should output test files
	local files_found=0
	while IFS= read -r line; do
		if [[ "$line" == "test1.bats" ]] || [[ "$line" == "test2.bats" ]]; then
			((++files_found))  # Use pre-increment to avoid 0 evaluation issue with set -e
		fi
	done < <(echo "$result" | tail -n +2)

	[ "$files_found" -eq 2 ]
}

@test "_parse_extract_suite_data fails on invalid suite" {
	local suite_obj='{"invalid":"data"}'
	local framework="bats"

	run _parse_extract_suite_data "$suite_obj" "$framework"

	[ "$status" -eq 1 ]
}

@test "_parse_count_tests_in_suite counts bats tests correctly" {
	local framework="bats"
	local project_root="/test/project"
	local test_files=("test1.bats" "test2.bats")

	local result
	result=$(_parse_count_tests_in_suite "$framework" "$project_root" "${test_files[@]}")

	[ "$result" -eq 4 ]  # 2 files * 2 tests each (from mock)
}

@test "_parse_count_tests_in_suite counts rust tests correctly" {
	local framework="rust"
	local project_root="/test/project"
	local test_files=("test1.rs" "test2.rs")

	local result
	result=$(_parse_count_tests_in_suite "$framework" "$project_root" "${test_files[@]}")

	[ "$result" -eq 6 ]  # 2 files * 3 tests each (from mock)
}

@test "_parse_format_suite_output formats output correctly" {
	local framework="bats"
	local suite_name="test_suite"
	local project_root="/test/project"
	local first_test_file="tests/test.bats"
	local total_test_count="5"

	local result
	result=$(_parse_format_suite_output "$framework" "$suite_name" "$project_root" "$first_test_file" "$total_test_count")

	[[ "$result" == "bats|test_suite|/test/project/tests/test.bats|tests/test.bats|5" ]]
}

@test "_detect_process_framework_metadata processes framework metadata" {
	# Mock adapter functions
	bats_adapter_get_metadata() {
		echo '{"name":"BATS","version":"1.0"}'
	}

	bats_adapter_check_binaries() {
		return 0  # Available
	}

	local adapter="bats"
	local project_root="/test/project"

	local result
	result=$(_detect_process_framework_metadata "$adapter" "$project_root")

	local metadata=$(echo "$result" | head -1)
	local binary_available=$(echo "$result" | tail -1)

	[[ "$metadata" == *"BATS"* ]]
	[ "$binary_available" = "true" ]

	# Clean up mocks
	unset -f bats_adapter_get_metadata bats_adapter_check_binaries
}

@test "_detect_process_framework_metadata handles unavailable binary" {
	# Mock adapter functions
	rust_adapter_get_metadata() {
		echo '{"name":"Rust","version":"1.0"}'
	}

	rust_adapter_check_binaries() {
		return 1  # Not available
	}

	local adapter="rust"
	local project_root="/test/project"

	local result
	result=$(_detect_process_framework_metadata "$adapter" "$project_root")

	local binary_available=$(echo "$result" | tail -1)

	[ "$binary_available" = "false" ]

	# Clean up mocks
	unset -f rust_adapter_get_metadata rust_adapter_check_binaries
}

@test "parse_test_suites_json handles JSON captured via command substitution" {
	# Test that JSON captured via command substitution (as in scanner.sh) works correctly
	# This simulates: suites_json=$("${framework}_adapter_discover_test_suites" ...)
	
	mock_adapter_output() {
		echo '[{"name":"suitey","framework":"bats","test_files":["tests/bats/suitey.bats"],"metadata":{},"execution_config":{}}]'
	}
	
	# Capture output via command substitution (as scanner.sh does)
	local suites_json
	suites_json=$(mock_adapter_output)
	
	# Verify it's captured correctly
	[ -n "$suites_json" ]
	
	# Test parsing
	local project_root="/test/project"
	local result
	result=$(parse_test_suites_json "$suites_json" "bats" "$project_root")
	
	[ -n "$result" ]
	local suite_entry=$(echo "$result" | head -1)
	IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite_entry"
	
	[ "$framework" = "bats" ]
	[ "$suite_name" = "suitey" ]
	
	unset -f mock_adapter_output
}

@test "_parse_split_json_array handles JSON with trailing newlines or whitespace" {
	# Test edge case: JSON might have trailing newlines from command substitution
	local json_with_newline='[{"name":"test","test_files":["test.bats"]}]'$'\n'
	
	local result
	result=$(_parse_split_json_array "$json_with_newline")
	
	[ -n "$result" ]
	# Each line should be valid JSON
	while IFS= read -r line; do
		if [[ -n "$line" ]]; then
			echo "$line" | jq . >/dev/null 2>&1
		fi
	done <<< "$result"
}

@test "_parse_extract_suite_data handles JSON objects from _parse_split_json_array output" {
	# Test the actual output format from _parse_split_json_array
	local json_array='[{"name":"suitey","framework":"bats","test_files":["tests/bats/suitey.bats"],"metadata":{},"execution_config":{}}]'
	
	# Split it as the real code does
	local split_output
	split_output=$(_parse_split_json_array "$json_array")
	
	# Test each split object
	local count=0
	while IFS= read -r suite_obj; do
		if [[ -n "$suite_obj" ]]; then
			((++count))
			
			# Verify it's valid JSON
			echo "$suite_obj" | jq . >/dev/null 2>&1
			
			# Test extraction
			run _parse_extract_suite_data "$suite_obj" "bats"
			
			[ "$status" -eq 0 ]
			[ -n "$output" ]
			
			local suite_name=$(echo "$output" | head -1)
			[ "$suite_name" = "suitey" ]
		fi
	done <<< "$split_output"
	
	[ "$count" -eq 1 ]
}
