#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Framework Detector helper functions

# Find and source suitey.sh to get the helper functions
suitey_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
else
  suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
fi

source "$suitey_script"

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
			((object_count++))
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
			((files_found++))
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
