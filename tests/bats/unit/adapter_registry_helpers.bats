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
	decoded=$(_adapter_registry_decode_value "$invalid_input" 2>/dev/null || echo "")

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
	local output
	output=$(_adapter_registry_load_array_from_file "$test_array_name" "$test_file")
	local loaded_count
	loaded_count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		loaded_array["$key"]="$value"
	done < <(echo "$output" | tail -n +2)

	[ "$loaded_count" -eq 2 ]
	[ "${loaded_array[key1]}" = "value1" ]
	[ "${loaded_array[key2]}" = "value2" ]

	teardown_adapter_registry_test
}

@test "_adapter_registry_load_array_from_file returns 0 for non-existent file" {
	local output
	output=$(_adapter_registry_load_array_from_file "test_array" "/non/existent/file")
	local loaded_count
	loaded_count=$(echo "$output" | head -n 1)

	[ "$loaded_count" -eq 0 ]
}

# ============================================================================
# Diagnostic Tests for Array Loading Issue
# ============================================================================

@test "diagnostic: nameref assignment to associative array works" {
	# Test if nameref assignment works at all
	declare -A test_array
	local -n ref="test_array"
	ref["test_key"]="test_value"
	
	[ "${test_array[test_key]}" = "test_value" ]
}

@test "diagnostic: nameref assignment works from function" {
	# Test if nameref assignment works when called from a function
	test_nameref_function() {
		local array_name="$1"
		local -n array_ref="$array_name"
		array_ref["key"]="value"
	}
	
	declare -A test_array
	test_nameref_function "test_array"
	
	[ "${test_array[key]}" = "value" ]
}

@test "diagnostic: decode value works for saved data" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_decode.txt"
	
	# Save a known value
	declare -A test_array=(["key1"]="value1")
	_adapter_registry_save_array_to_file "test_array" "$test_file"
	
	# Read the file and decode manually
	local line
	line=$(head -n 1 "$test_file")
	local encoded_value="${line#*=}"
	
	local decoded
	decoded=$(_adapter_registry_decode_value "$encoded_value" 2>/dev/null || echo "")
	
	[ "$decoded" = "value1" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: file content is correct after save" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_content.txt"
	declare -A test_array=(
		["key1"]="value1"
		["key2"]="value2"
	)
	_adapter_registry_save_array_to_file "test_array" "$test_file"
	
	# Check file has expected format
	[ -f "$test_file" ]
	[ -s "$test_file" ]
	
	# Check it has key1= and key2= lines
	grep -q "^key1=" "$test_file"
	grep -q "^key2=" "$test_file"
	
	teardown_adapter_registry_test
}

@test "diagnostic: load function reads file correctly" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_read.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"  # base64 of "test_value"
	
	declare -A loaded_array
	local output
	output=$(_adapter_registry_load_array_from_file "loaded_array" "$test_file")
	local loaded_count
	loaded_count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		loaded_array["$key"]="$value"
	done < <(echo "$output" | tail -n +2)
	
	# Check if count is correct
	[ "$loaded_count" -eq 1 ]
	
	# Check if value was loaded (this is what's currently failing)
	if [ -z "${loaded_array[key1]:-}" ]; then
		echo "ERROR: Array not populated via nameref" >&2
		echo "  loaded_array keys: ${!loaded_array[@]}" >&2
		echo "  loaded_array[key1]: '${loaded_array[key1]:-}'" >&2
		return 1
	fi
	
	[ "${loaded_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: load function with global array" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_global.txt"
	declare -A test_array=(["global_key"]="global_value")
	_adapter_registry_save_array_to_file "test_array" "$test_file"
	
	# Clear and reload using global array name
	unset test_array
	declare -A test_array
	local output
	output=$(_adapter_registry_load_array_from_file "test_array" "$test_file")
	local loaded_count
	loaded_count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		test_array["$key"]="$value"
	done < <(echo "$output" | tail -n +2)
	
	[ "$loaded_count" -eq 1 ]
	[ "${test_array[global_key]}" = "global_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: verify decode exit code capture" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_exit.txt"
	declare -A test_array=(["key1"]="value1")
	_adapter_registry_save_array_to_file "test_array" "$test_file"
	
	# Manually test the decode logic
	local line
	line=$(head -n 1 "$test_file")
	local encoded_value="${line#*=}"
	
	local decoded_value
	local decode_exit
	decoded_value=$(_adapter_registry_decode_value "$encoded_value" 2>/dev/null)
	decode_exit=$?
	
	# Verify decode succeeded
	[ $decode_exit -eq 0 ]
	[ -n "$decoded_value" ]
	[ "$decoded_value" = "value1" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: eval assignment works in BATS test context" {
	# Test if eval works at all in BATS context
	declare -A test_array
	local array_name="test_array"
	local key="test_key"
	local value="test_value"
	
	eval "${array_name}[\"${key}\"]=\"${value}\""
	
	[ "${test_array[test_key]}" = "test_value" ]
}

@test "diagnostic: eval assignment works from sourced function in BATS" {
	# Test if eval works when called from a sourced function
	test_eval_func() {
		local array_name="$1"
		local key="$2"
		local value="$3"
		eval "${array_name}[\"${key}\"]=\"${value}\""
	}
	
	declare -A test_array
	test_eval_func "test_array" "test_key" "test_value"
	
	[ "${test_array[test_key]}" = "test_value" ]
}

@test "diagnostic: eval assignment works in while loop" {
	# Test if eval works inside a while loop
	declare -A test_array
	local array_name="test_array"
	
	while IFS= read -r line || [[ -n "$line" ]]; do
		local key="${line%%=*}"
		local value="${line#*=}"
		eval "${array_name}[\"${key}\"]=\"${value}\""
	done <<< "key1=value1"
	
	[ "${test_array[key1]}" = "value1" ]
}

@test "diagnostic: eval with printf %q works in BATS" {
	# Test if eval with printf %q works
	declare -A test_array
	local array_name="test_array"
	local key="key1"
	local value="value1"
	
	local safe_key
	safe_key=$(printf '%q' "$key")
	local safe_value
	safe_value=$(printf '%q' "$value")
	
	eval "${array_name}[${safe_key}]=${safe_value}"
	
	[ "${test_array[key1]}" = "value1" ]
}

@test "diagnostic: load function called from test vs helper" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_scope.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	# Test calling the function directly from test
	declare -A test_array
	local output
	output=$(_adapter_registry_load_array_from_file "test_array" "$test_file")
	local count
	count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		test_array["$key"]="$value"
	done < <(echo "$output" | tail -n +2)
	
	echo "Count returned: $count" >&2
	echo "test_array keys: ${!test_array[@]}" >&2
	echo "test_array[key1]: '${test_array[key1]:-}'" >&2
	
	[ "$count" -eq 1 ]
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: check if array exists before eval" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_exists.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	local array_name="test_array"
	
	# Check if declare -p works
	if declare -p "$array_name" &>/dev/null; then
		echo "Array exists before load" >&2
	else
		echo "Array does NOT exist before load" >&2
	fi
	
	local output
	output=$(_adapter_registry_load_array_from_file "$array_name" "$test_file")
	local count
	count=$(echo "$output" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		eval "${array_name}[\"$key\"]=\"$value\""
	done < <(echo "$output" | tail -n +2)
	
	# Check again after load
	if declare -p "$array_name" &>/dev/null; then
		echo "Array exists after load" >&2
		declare -p "$array_name" >&2
	else
		echo "Array does NOT exist after load" >&2
	fi
	
	[ "$count" -eq 1 ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: manual eval assignment matches function behavior" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_manual.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	local array_name="test_array"
	
	# Manually do what the function does
	local line
	line=$(head -n 1 "$test_file")
	local key="${line%%=*}"
	local encoded_value="${line#*=}"
	
	local decoded_value
	local decode_exit
	decoded_value=$(_adapter_registry_decode_value "$encoded_value" 2>/dev/null)
	decode_exit=$?
	
	echo "Decode exit: $decode_exit" >&2
	echo "Decoded value: '$decoded_value'" >&2
	
	if [[ $decode_exit -eq 0 ]] && [[ -n "$decoded_value" ]]; then
		local safe_key
		safe_key=$(printf '%q' "$key")
		local safe_value
		safe_value=$(printf '%q' "$decoded_value")
		
		echo "Safe key: $safe_key" >&2
		echo "Safe value: $safe_value" >&2
		
		eval "${array_name}[${safe_key}]=${safe_value}"
		echo "After eval, test_array[key1]: '${test_array[key1]:-}'" >&2
	fi
	
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: exact function replication with file read" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_exact.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	local array_name="test_array"
	local file_path="$test_file"
	
	# Exact replication of function logic
	if [[ ! -f "$file_path" ]]; then
		echo "File not found!" >&2
		return 1
	fi
	
	local loaded_count=0
	local line_key
	local line_encoded_value
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" ]] && continue
		line_key="${line%%=*}"
		line_encoded_value="${line#*=}"
		
		if [[ -n "$line_key" ]] && [[ -n "$line_encoded_value" ]]; then
			local decoded_value
			local decode_exit
			decoded_value=$(_adapter_registry_decode_value "$line_encoded_value" 2>/dev/null)
			decode_exit=$?
			if [[ $decode_exit -eq 0 ]] && [[ -n "$decoded_value" ]]; then
				local safe_key
				safe_key=$(printf '%q' "$line_key")
				local safe_value
				safe_value=$(printf '%q' "$decoded_value")
				echo "About to eval: ${array_name}[${safe_key}]=${safe_value}" >&2
				eval "${array_name}[${safe_key}]=${safe_value}"
				echo "After eval, keys: ${!test_array[@]}" >&2
				echo "After eval, value: ${test_array[key1]:-empty}" >&2
				loaded_count=$((loaded_count + 1))
			fi
		fi
	done < "$file_path"
	
	echo "Final count: $loaded_count" >&2
	echo "Final keys: ${!test_array[@]}" >&2
	echo "Final value: ${test_array[key1]:-empty}" >&2
	
	[ "$loaded_count" -eq 1 ]
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: eval can see array name variable from function" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_eval_scope.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	local array_name="test_array"
	
	# Test if eval can see the array_name variable when called from a function
	test_eval_func() {
		local arr_name="$1"
		local key="key1"
		local value="test_value"
		local safe_key
		safe_key=$(printf '%q' "$key")
		local safe_value
		safe_value=$(printf '%q' "$value")
		
		echo "Inside function, arr_name='$arr_name'" >&2
		echo "Inside function, about to eval: ${arr_name}[${safe_key}]=${safe_value}" >&2
		
		# Check if we can see the array from here
		if declare -p "$arr_name" &>/dev/null 2>&1; then
			echo "Array $arr_name exists from function" >&2
			declare -p "$arr_name" >&2
		else
			echo "Array $arr_name does NOT exist from function" >&2
		fi
		
		eval "${arr_name}[${safe_key}]=${safe_value}"
		
		# Check again after eval
		if declare -p "$arr_name" &>/dev/null 2>&1; then
			echo "After eval, array $arr_name exists" >&2
			declare -p "$arr_name" >&2
		else
			echo "After eval, array $arr_name does NOT exist" >&2
		fi
	}
	
	test_eval_func "$array_name" "$test_file"
	
	echo "After function call, keys: ${!test_array[@]}" >&2
	echo "After function call, value: ${test_array[key1]:-empty}" >&2
	
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: check array visibility in function vs test scope" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_visibility.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	
	# Create a wrapper function that mimics what _adapter_registry_load_array_from_file does
	test_load_wrapper() {
		local array_name="$1"
		local file_path="$2"
		
		echo "=== Inside wrapper function ===" >&2
		echo "array_name='$array_name'" >&2
		echo "file_path='$file_path'" >&2
		
		# Check if array exists
		if declare -p "$array_name" &>/dev/null 2>&1; then
			echo "Array $array_name EXISTS in wrapper" >&2
			declare -p "$array_name" >&2
		else
			echo "Array $array_name does NOT exist in wrapper" >&2
		fi
		
		# Try to read and assign
		local line
		line=$(head -n 1 "$file_path")
		local key="${line%%=*}"
		local encoded_value="${line#*=}"
		
		local decoded_value
		decoded_value=$(_adapter_registry_decode_value "$encoded_value" 2>/dev/null)
		
		if [[ -n "$decoded_value" ]]; then
			local safe_key
			safe_key=$(printf '%q' "$key")
			local safe_value
			safe_value=$(printf '%q' "$decoded_value")
			
			echo "About to eval: ${array_name}[${safe_key}]=${safe_value}" >&2
			
			# Check array again right before eval
			if declare -p "$array_name" &>/dev/null 2>&1; then
				echo "Array $array_name EXISTS right before eval" >&2
			else
				echo "Array $array_name does NOT exist right before eval" >&2
			fi
			
			eval "${array_name}[${safe_key}]=${safe_value}"
			
			# Check array right after eval
			if declare -p "$array_name" &>/dev/null 2>&1; then
				echo "Array $array_name EXISTS right after eval" >&2
				declare -p "$array_name" >&2
			else
				echo "Array $array_name does NOT exist right after eval" >&2
			fi
		fi
		
		echo "=== End wrapper function ===" >&2
	}
	
	echo "=== Before function call ===" >&2
	if declare -p "test_array" &>/dev/null 2>&1; then
		echo "Array test_array EXISTS in test" >&2
		declare -p "test_array" >&2
	else
		echo "Array test_array does NOT exist in test" >&2
	fi
	
	test_load_wrapper "test_array" "$test_file"
	
	echo "=== After function call ===" >&2
	if declare -p "test_array" &>/dev/null 2>&1; then
		echo "Array test_array EXISTS in test after call" >&2
		declare -p "test_array" >&2
	else
		echo "Array test_array does NOT exist in test after call" >&2
	fi
	
	echo "Keys: ${!test_array[@]}" >&2
	echo "Value: ${test_array[key1]:-empty}" >&2
	
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: compare actual function call vs wrapper" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_compare.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	# Test with actual function
	declare -A test_array1
	echo "=== Testing actual function ===" >&2
	export ADAPTER_REGISTRY_DEBUG=1
	local output1
	output1=$(_adapter_registry_load_array_from_file "test_array1" "$test_file")
	local count1
	count1=$(echo "$output1" | head -n 1)
	# Populate array from remaining lines
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		[[ -z "$key" ]] && continue
		test_array1["$key"]="$value"
	done < <(echo "$output1" | tail -n +2)
	unset ADAPTER_REGISTRY_DEBUG
	echo "Function returned count: $count1" >&2
	echo "test_array1 keys: ${!test_array1[@]}" >&2
	echo "test_array1[key1]: '${test_array1[key1]:-empty}'" >&2
	
	# Test with inline replication (like diagnostic test 26)
	declare -A test_array2
	echo "=== Testing inline replication ===" >&2
	local array_name="test_array2"
	local file_path="$test_file"
	local loaded_count=0
	local line_key
	local line_encoded_value
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" ]] && continue
		line_key="${line%%=*}"
		line_encoded_value="${line#*=}"
		if [[ -n "$line_key" ]] && [[ -n "$line_encoded_value" ]]; then
			local decoded_value
			local decode_exit
			decoded_value=$(_adapter_registry_decode_value "$line_encoded_value" 2>/dev/null)
			decode_exit=$?
			if [[ $decode_exit -eq 0 ]] && [[ -n "$decoded_value" ]]; then
				local safe_key
				safe_key=$(printf '%q' "$line_key")
				local safe_value
				safe_value=$(printf '%q' "$decoded_value")
				eval "${array_name}[${safe_key}]=${safe_value}"
				loaded_count=$((loaded_count + 1))
			fi
		fi
	done < "$file_path"
	echo "Inline returned count: $loaded_count" >&2
	echo "test_array2 keys: ${!test_array2[@]}" >&2
	echo "test_array2[key1]: '${test_array2[key1]:-empty}'" >&2
	
	# Compare results
	echo "=== Comparison ===" >&2
	echo "Function: count=$count1, has_key=${test_array1[key1]:+yes}, value='${test_array1[key1]:-empty}'" >&2
	echo "Inline: count=$loaded_count, has_key=${test_array2[key1]:+yes}, value='${test_array2[key1]:-empty}'" >&2
	
	# Both should work
	[ "$count1" -eq 1 ]
	[ "${test_array1[key1]}" = "test_value" ]
	[ "$loaded_count" -eq 1 ]
	[ "${test_array2[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
}

@test "diagnostic: check if function is in subshell" {
	setup_adapter_registry_test
	
	local test_file="$TEST_ADAPTER_REGISTRY_DIR/test_subshell.txt"
	echo "key1=dGVzdF92YWx1ZQ==" > "$test_file"
	
	declare -A test_array
	
	# Set a marker variable
	TEST_MARKER="before_function"
	
	# Check if function can see/modify variables
	test_subshell_check() {
		local array_name="$1"
		TEST_MARKER="inside_function"
		echo "TEST_MARKER in function: $TEST_MARKER" >&2
		
		# Try to modify the array
		local safe_key
		safe_key=$(printf '%q' "key1")
		local safe_value
		safe_value=$(printf '%q' "test_value")
		eval "${array_name}[${safe_key}]=${safe_value}"
	}
	
	test_subshell_check "test_array"
	
	echo "TEST_MARKER after function: $TEST_MARKER" >&2
	echo "test_array keys: ${!test_array[@]}" >&2
	echo "test_array[key1]: '${test_array[key1]:-empty}'" >&2
	
	# If function is in subshell, TEST_MARKER would still be "before_function"
	[ "$TEST_MARKER" = "inside_function" ]
	[ "${test_array[key1]}" = "test_value" ]
	
	teardown_adapter_registry_test
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

	# Set up test data with valid JSON metadata containing capabilities
	local test_metadata='{"name":"Test Adapter","identifier":"test_adapter","capabilities":["parallel","coverage"]}'
	ADAPTER_REGISTRY_ORDER=("test_adapter")
	declare -A ADAPTER_REGISTRY=(["test_adapter"]="$test_metadata")
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
