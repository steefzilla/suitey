#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Adapter Registry helper functions

load ../helpers/adapter_registry_helpers
load ../helpers/adapter_registry

# ============================================================================
# Helper Function Tests
# ============================================================================

@test "_adapter_registry_determine_base_dir prioritizes TEST_ADAPTER_REGISTRY_DIR" {
	setup_adapter_registry_test

	local expected_dir="$TEST_ADAPTER_REGISTRY_DIR"
	local actual_dir
	actual_dir=$(_adapter_registry_determine_base_dir)

	[ "$actual_dir" = "$expected_dir" ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_determine_base_dir uses REGISTRY_BASE_DIR when set" {
	setup_adapter_registry_test

	# Temporarily unset TEST_ADAPTER_REGISTRY_DIR to test fallback
	local old_test_dir="$TEST_ADAPTER_REGISTRY_DIR"
	unset TEST_ADAPTER_REGISTRY_DIR

	# Set REGISTRY_BASE_DIR to a valid directory
	local test_dir="/tmp/test_registry"
	mkdir -p "$test_dir"
	REGISTRY_BASE_DIR="$test_dir"

	local actual_dir
	actual_dir=$(_adapter_registry_determine_base_dir)

	[ "$actual_dir" = "$test_dir" ]

	# Restore
	rm -rf "$test_dir"
	REGISTRY_BASE_DIR=""
	teardown_adapter_registry_test
}

@test "_adapter_registry_determine_base_dir falls back to TMPDIR" {
	setup_adapter_registry_test

	# Temporarily unset both test dirs and REGISTRY_BASE_DIR
	local old_test_dir="$TEST_ADAPTER_REGISTRY_DIR"
	local old_registry_base="$REGISTRY_BASE_DIR"
	unset TEST_ADAPTER_REGISTRY_DIR
	unset REGISTRY_BASE_DIR

	local actual_dir
	actual_dir=$(_adapter_registry_determine_base_dir)

	[ "$actual_dir" = "${TMPDIR:-/tmp}" ]

	# Restore
	teardown_adapter_registry_test
}

@test "_adapter_registry_ensure_directory creates missing directory" {
	local test_dir="/tmp/test_ensure_dir"
	rm -rf "$test_dir"

	_adapter_registry_ensure_directory "$test_dir"

	[ -d "$test_dir" ]

	rm -rf "$test_dir"
}

@test "_adapter_registry_ensure_directory fails on permission denied" {
	local test_dir="/root/test_no_permission"
	# This should fail but not crash the test
	run _adapter_registry_ensure_directory "$test_dir"
	[ "$status" -eq 1 ]
}

@test "_adapter_registry_encode_value handles GNU base64" {
	# Test with a simple string that should encode successfully
	local test_value="hello world"
	local encoded
	encoded=$(_adapter_registry_encode_value "$test_value")

	[ -n "$encoded" ]
	[ "$encoded" != "$test_value" ] # Should be different from input

	# Should be able to decode back
	local decoded
	decoded=$(_adapter_registry_decode_value "$encoded")
	[ "$decoded" = "$test_value" ]
}

@test "_adapter_registry_decode_value handles encoded strings" {
	local test_value="test string for encoding"
	local encoded
	encoded=$(_adapter_registry_encode_value "$test_value")

	local decoded
	decoded=$(_adapter_registry_decode_value "$encoded")

	[ "$decoded" = "$test_value" ]
}

@test "_adapter_registry_decode_value fails on invalid input" {
	local invalid_input="not-valid-base64!!!"
	local decoded
	decoded=$(_adapter_registry_decode_value "$invalid_input")

	[ -z "$decoded" ]
}

@test "_adapter_registry_save_array_to_file creates file and writes content" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_array.txt"
	local test_array_name="test_array"

	# Create a test associative array
	declare -A test_array=(
		["key1"]="value1"
		["key2"]="value2"
	)

	_adapter_registry_save_array_to_file "$test_array_name" "$test_file"

	[ -f "$test_file" ]
	[ -s "$test_file" ] # File should not be empty

	# Check file contents contain encoded entries
	local content
	content=$(cat "$test_file")
	echo "$content" | grep -q "key1="
	echo "$content" | grep -q "key2="

	teardown_adapter_registry_test
}

@test "_adapter_registry_load_array_from_file loads saved data" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_array.txt"
	local test_array_name="loaded_array"

	# Create and save test data
	declare -A original_array=(
		["key1"]="value1"
		["key2"]="value2"
	)
	_adapter_registry_save_array_to_file "original_array" "$test_file"

	# Clear and reload
	unset original_array
	declare -A loaded_array
	local loaded_count
	loaded_count=$(_adapter_registry_load_array_from_file "$test_array_name" "$test_file")

	[ "$loaded_count" -eq 2 ]
	[ "${loaded_array[key1]}" = "value1" ]
	[ "${loaded_array[key2]}" = "value2" ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_load_array_from_file returns 0 for non-existent file" {
	local loaded_count
	loaded_count=$(_adapter_registry_load_array_from_file "test_array" "/non/existent/file")

	[ "$loaded_count" -eq 0 ]
}

@test "_adapter_registry_save_order writes array to file" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_order.txt"
	local test_order=("item1" "item2" "item3")

	# Temporarily set the global array
	local old_order=("${ADAPTER_REGISTRY_ORDER[@]}")
	ADAPTER_REGISTRY_ORDER=("${test_order[@]}")

	_adapter_registry_save_order "$test_file"

	[ -f "$test_file" ]

	# Check file contents
	local content
	content=$(cat "$test_file")
	[ "$content" = "item1"$'\n'"item2"$'\n'"item3" ]

	# Restore
	ADAPTER_REGISTRY_ORDER=("${old_order[@]}")
	teardown_adapter_registry_test
}

@test "_adapter_registry_save_initialized writes boolean to file" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_init.txt"

	# Test with true
	local old_init="$ADAPTER_REGISTRY_INITIALIZED"
	ADAPTER_REGISTRY_INITIALIZED=true

	_adapter_registry_save_initialized "$test_file"

	local content
	content=$(cat "$test_file")
	[ "$content" = "true" ]

	# Test with false
	ADAPTER_REGISTRY_INITIALIZED=false
	_adapter_registry_save_initialized "$test_file"

	content=$(cat "$test_file")
	[ "$content" = "false" ]

	# Restore
	ADAPTER_REGISTRY_INITIALIZED="$old_init"
	teardown_adapter_registry_test
}

@test "_adapter_registry_determine_file_locations uses TEST_ADAPTER_REGISTRY_DIR" {
	setup_adapter_registry_test

	local old_test_dir="$TEST_ADAPTER_REGISTRY_DIR"
	local file_paths
	file_paths=$(_adapter_registry_determine_file_locations)

	local registry_file=$(echo "$file_paths" | sed -n '1p')
	local capabilities_file=$(echo "$file_paths" | sed -n '2p')
	local order_file=$(echo "$file_paths" | sed -n '3p')
	local init_file=$(echo "$file_paths" | sed -n '4p')

	[[ "$registry_file" == "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry" ]]
	[[ "$capabilities_file" == "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities" ]]
	[[ "$order_file" == "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order" ]]
	[[ "$init_file" == "$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_init" ]]

	teardown_adapter_registry_test
}

@test "_adapter_registry_should_reload returns true when file exists" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_file"
	touch "$test_file"

	local result
	result=$(_adapter_registry_should_reload "$test_file" "/nonexistent" "false")

	[ "$result" = "true" ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_should_reload returns true when switching locations" {
	local result
	result=$(_adapter_registry_should_reload "/nonexistent" "/nonexistent" "true")

	[ "$result" = "true" ]
}

@test "_adapter_registry_should_reload returns false when no conditions met" {
	local result
	result=$(_adapter_registry_should_reload "/nonexistent" "/nonexistent" "false")

	[ "$result" = "false" ]
}

@test "_adapter_registry_rebuild_capabilities rebuilds when capabilities_loaded is false" {
	setup_adapter_registry_test

	# Set up test data
	ADAPTER_REGISTRY_ORDER=("test_adapter")
	declare -A ADAPTER_REGISTRY=(["test_adapter"]="test_metadata")
	declare -A ADAPTER_REGISTRY_CAPABILITIES=()

	_adapter_registry_rebuild_capabilities "false" "false" "/nonexistent"

	# Should have rebuilt capabilities
	[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -gt 0 ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_rebuild_capabilities skips when no adapters loaded" {
	setup_adapter_registry_test

	# Clear adapters
	ADAPTER_REGISTRY=()
	declare -A ADAPTER_REGISTRY_CAPABILITIES=()

	_adapter_registry_rebuild_capabilities "false" "false" "/nonexistent"

	# Should not have rebuilt (no adapters)
	[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_parse_file_paths parses multiline output correctly" {
	local test_output="file1.txt
file2.txt
file3.txt
file4.txt"

	local file1 file2 file3 file4
	file1=$(_adapter_registry_parse_file_paths "$test_output" | sed -n '1p')
	file2=$(_adapter_registry_parse_file_paths "$test_output" | sed -n '2p')
	file3=$(_adapter_registry_parse_file_paths "$test_output" | sed -n '3p')
	file4=$(_adapter_registry_parse_file_paths "$test_output" | sed -n '4p')

	[ "$file1" = "file1.txt" ]
	[ "$file2" = "file2.txt" ]
	[ "$file3" = "file3.txt" ]
	[ "$file4" = "file4.txt" ]
}

@test "_adapter_registry_load_order_array loads and filters order file" {
	setup_adapter_registry_test

	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_order.txt"
	cat > "$test_file" << 'EOF'
item1
item2

item3
  item4
EOF

	_adapter_registry_load_order_array "$test_file"

	[ ${#ADAPTER_REGISTRY_ORDER[@]} -eq 4 ]
	[ "${ADAPTER_REGISTRY_ORDER[0]}" = "item1" ]
	[ "${ADAPTER_REGISTRY_ORDER[1]}" = "item2" ]
	[ "${ADAPTER_REGISTRY_ORDER[2]}" = "item3" ]
	[ "${ADAPTER_REGISTRY_ORDER[3]}" = "item4" ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_load_order_array handles non-existent file gracefully" {
	setup_adapter_registry_test

	_adapter_registry_load_order_array "/non/existent/file.txt"

	[ ${#ADAPTER_REGISTRY_ORDER[@]} -eq 0 ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_perform_reload clears arrays and loads from files" {
	setup_adapter_registry_test

	# Create test files with some data
	local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
	local capabilities_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities"
	local order_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order"

	# Save some test data to files
	declare -A test_registry=(["test_adapter"]="test_metadata")
	declare -A test_capabilities=(["test_capability"]="test_value")
	local test_order=("item1" "item2")

	_adapter_registry_save_array_to_file "test_registry" "$registry_file"
	_adapter_registry_save_array_to_file "test_capabilities" "$capabilities_file"
	_adapter_registry_save_order "$order_file"

	# Set up some existing data in memory (should be cleared)
	ADAPTER_REGISTRY=(["old_adapter"]="old_metadata")
	ADAPTER_REGISTRY_CAPABILITIES=(["old_capability"]="old_value")
	ADAPTER_REGISTRY_ORDER=("old_item")

	# Perform reload
	_adapter_registry_perform_reload "$registry_file" "$capabilities_file" "$order_file" "false"

	# Verify arrays were cleared and reloaded
	[ ${#ADAPTER_REGISTRY[@]} -gt 0 ]
	[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -gt 0 ]
	[ ${#ADAPTER_REGISTRY_ORDER[@]} -gt 0 ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_perform_reload skips capabilities when switching locations" {
	setup_adapter_registry_test

	# Create registry file but no capabilities file
	local registry_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_registry"
	local capabilities_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_capabilities"
	local order_file="$TEST_ADAPTER_REGISTRY_DIR/suitey_adapter_order"

	# Save test registry data
	declare -A test_registry=(["test_adapter"]="test_metadata")
	_adapter_registry_save_array_to_file "test_registry" "$registry_file"

	# Set up existing capabilities in memory
	ADAPTER_REGISTRY_CAPABILITIES=(["existing_capability"]="existing_value")

	# Perform reload with switching locations (should clear capabilities)
	_adapter_registry_perform_reload "$registry_file" "$capabilities_file" "$order_file" "true"

	# Verify capabilities were cleared (since switching locations)
	[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]

	teardown_adapter_registry_test
}
