#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

# ============================================================================
# Array Pattern Enforcement Tests
# ============================================================================
# Static tests to enforce array handling patterns and detect violations

@test "functions that modify arrays via nameref must be documented" {
	# Find functions with local -n that modify arrays (arr[=], arr+=, arr=())
	# These should be documented with pattern comments
	local violations=()
	local files
	mapfile -t files < <(find src -name "*.sh" | grep -v ".backup" | grep -v ".git")

	for file in "${files[@]}"; do
		# Check for nameref usage
		if grep -q "local -n.*=" "$file"; then
			# Check if it modifies arrays
			if grep -qE "arr\[.*\]=" "$file" || grep -qE "arr\+=" "$file" || grep -qE "arr=\(\)" "$file"; then
				# Check for pattern documentation
				if ! grep -qE "# PATTERN:.*Return-Data|# PATTERN:.*Nameref Modify|# PATTERN:.*Read-Only" "$file"; then
					violations+=("$file: Function modifies array via nameref without documentation")
				fi
			fi
		fi
	done

	if [ ${#violations[@]} -ne 0 ]; then
		echo "Array pattern violations found:"
		printf '  %s\n' "${violations[@]}"
		echo ""
		echo "Functions that modify arrays via nameref should be documented with:"
		echo "  - # PATTERN: Return-Data Approach (for return-data functions)"
		echo "  - # PATTERN: Nameref Modify (migration candidate) (for nameref modify)"
		echo "  - # PATTERN: Read-Only Nameref (acceptable) (for read-only nameref)"
		false
	fi
}

@test "return-data functions must have pattern documentation" {
	# Find functions that return count + data pattern
	local undocumented=()
	local files
	mapfile -t files < <(find src -name "*.sh" | grep -v ".backup" | grep -v ".git")

	for file in "${files[@]}"; do
		# Look for return-data pattern: echo count, then echo data
		if grep -q "echo.*\$loaded_count" "$file" && grep -q "echo.*\$count" "$file"; then
			if ! grep -q "# PATTERN: Return-Data" "$file"; then
				undocumented+=("$file: Return-data function missing pattern documentation")
			fi
		fi
	done

	if [ ${#undocumented[@]} -ne 0 ]; then
		echo "Undocumented return-data functions:"
		printf '  %s\n' "${undocumented[@]}"
		false
	fi
}

@test "functions tested in BATS should use return-data pattern" {
	# Find functions that are tested in BATS and use nameref to modify arrays
	local migration_candidates=()
	local test_files
	mapfile -t test_files < <(find tests/bats/unit -name "*.bats" | grep -v ".backup")

	for test_file in "${test_files[@]}"; do
		# Extract function names from test calls
		local functions_called
		mapfile -t functions_called < <(grep -oE '[a-zA-Z_][a-zA-Z0-9_]*\(' "$test_file" | sed 's/(//' | sort -u)

		for func in "${functions_called[@]}"; do
			# Find the function definition
			local func_file
			func_file=$(grep -rl "^$func()" src/ 2>/dev/null | head -1)
			if [[ -n "$func_file" ]]; then
				# Check if function uses nameref to modify arrays
				if grep -q "local -n.*=" "$func_file" && \
				   (grep -qE "arr\[.*\]=" "$func_file" || grep -qE "arr\+=" "$func_file" || grep -qE "arr=\(\)" "$func_file"); then
					# Check if it's documented as read-only
					if ! grep -q "# PATTERN:.*Read-Only" "$func_file"; then
						migration_candidates+=("$func_file:$func - Tested in BATS, uses nameref modify")
					fi
				fi
			fi
		done
	done

	if [ ${#migration_candidates[@]} -ne 0 ]; then
		echo "Migration candidates (functions tested in BATS using nameref modify):"
		printf '  %s\n' "${migration_candidates[@]}"
		echo ""
		echo "Consider migrating these functions to return-data pattern."
		# Don't fail the test - just report candidates
	fi
}

@test "callers should use helper function when available" {
	# Find manual return-data processing that should use helper functions
	local manual_implementations=()
	local files
	mapfile -t files < <(find src -name "*.sh" | grep -v ".backup" | grep -v ".git")

	for file in "${files[@]}"; do
		# Skip helper function definitions themselves
		if [[ "$file" == *"adapter_registry_helpers.sh" ]] && grep -q "^_adapter_registry_populate_array_from_output()" "$file"; then
			continue
		fi
		if [[ "$file" == *"json_helpers.sh" ]] && grep -q "^json_populate_array_from_output()" "$file"; then
			continue
		fi

		# Look for manual return-data processing pattern:
		# head -n 1 ... && tail -n +2 ... && while read
		if grep -q "head -n 1" "$file" && grep -q "tail -n +2" "$file" && grep -q "while.*read" "$file"; then
			# Check if helper function is available in the same file or imported
			if grep -q "_adapter_registry_populate_array_from_output" "$file" || grep -q "json_populate_array_from_output" "$file"; then
				manual_implementations+=("$file: Manual return-data processing when helper available")
			fi
		fi
	done

	if [ ${#manual_implementations[@]} -ne 0 ]; then
		echo "Manual return-data processing when helper available:"
		printf '  %s\n' "${manual_implementations[@]}"
		echo ""
		echo "Consider using helper functions like:"
		echo "  - _adapter_registry_populate_array_from_output() for adapter registry data"
		echo "  - json_populate_array_from_output() for JSON array data"
		false
	fi
}

@test "detect migration candidates" {
	# Functions using nameref to modify arrays without read-only documentation
	local migration_candidates=()
	local files
	mapfile -t files < <(find src -name "*.sh" | grep -v ".backup" | grep -v ".git")

	for file in "${files[@]}"; do
		if grep -q "local -n.*=" "$file"; then
			if grep -qE "arr\[.*\]=" "$file" || grep -qE "arr\+=" "$file" || grep -qE "arr=\(\)" "$file"; then
				if ! grep -q "# PATTERN:.*Read-Only" "$file"; then
					local func_name
					func_name=$(grep -oE "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$file" | head -1 | sed 's/()//')
					if [[ -n "$func_name" ]]; then
						migration_candidates+=("$file:$func_name")
					fi
				fi
			fi
		fi
	done

	if [ ${#migration_candidates[@]} -ne 0 ]; then
		echo "Functions that modify arrays via nameref (migration candidates):"
		printf '  %s\n' "${migration_candidates[@]}"
		echo ""
		echo "Consider migrating these to return-data pattern:"
		echo "  1. Change function to return data (first line count, rest key=value)"
		echo "  2. Update callers to use helper function to populate arrays"
		echo "  3. Update tests accordingly"
		# Don't fail - just report candidates
	fi
}
