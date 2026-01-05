#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for BATS Adapter helper functions

# Source BATS adapter from src/
_source_bats_adapter() {
  # Find and source adapters/bats.sh
  local bats_adapter_script
  if [[ -f "$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../../src/adapters/bats.sh"
  elif [[ -f "$BATS_TEST_DIRNAME/../../src/adapters/bats.sh" ]]; then
    bats_adapter_script="$BATS_TEST_DIRNAME/../../src/adapters/bats.sh"
  else
    bats_adapter_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../../../src/adapters" && pwd)/bats.sh"
  fi
  source "$bats_adapter_script"
}

_source_bats_adapter

# Mock helper functions for testing
find_bats_files() {
	local dir="$1"
	if [[ "$dir" == "/test/project/tests/bats" ]]; then
		echo "/test/project/tests/bats/test1.bats"
		echo "/test/project/tests/bats/test2.bats"
	elif [[ "$dir" == "/test/project/test/bats" ]]; then
		echo "/test/project/test/bats/test3.bats"
	elif [[ "$dir" == "/test/project" ]]; then
		echo "/test/project/root_test.bats"
	fi
}

is_file_seen() {
	local file="$1"
	shift
	local seen_files=("$@")
	for seen in "${seen_files[@]}"; do
		if [[ "$file" == "$seen" ]]; then
			return 0
		fi
	done
	return 1
}

normalize_path() {
	echo "$1"
}

generate_suite_name() {
	local file="$1"
	local framework="$2"
	basename "$file" .bats
}

count_bats_tests() {
	echo "3"  # Mock: return 3 tests
}

get_absolute_path() {
	echo "$1"
}

# ============================================================================
# Helper Function Tests
# ============================================================================

@test "_bats_discover_test_directories finds files in test directories" {
	# Create temporary directories for the test
	local tmp_dir=$(mktemp -d)
	local project_root="$tmp_dir/test/project"
	mkdir -p "$project_root/tests/bats"
	mkdir -p "$project_root/test/bats"
	mkdir -p "$project_root/tests"
	mkdir -p "$project_root/test"
	
	# Override find_bats_files globally to use the temp directory
	find_bats_files() {
		local dir="$1"
		if [[ "$dir" == "$project_root/tests/bats" ]]; then
			echo "$project_root/tests/bats/test1.bats"
			echo "$project_root/tests/bats/test2.bats"
		elif [[ "$dir" == "$project_root/test/bats" ]]; then
			echo "$project_root/test/bats/test3.bats"
		fi
	}
	
	local result
	result=$(_bats_discover_test_directories "$project_root")

	# Should output files first, then seen files
	local files_found=0
	local seen_found=0
	local line_count=0
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Trim whitespace
		line="${line%"${line##*[![:space:]]}"}"
		line="${line#"${line%%[![:space:]]*}"}"
		if [[ -n "$line" ]]; then
			line_count=$((line_count + 1))
			# First 3 lines should be the actual files
			if [[ $line_count -le 3 ]]; then
				if [[ "$line" == "$project_root/tests/bats/test1.bats" ]] ||
				   [[ "$line" == "$project_root/tests/bats/test2.bats" ]] ||
				   [[ "$line" == "$project_root/test/bats/test3.bats" ]]; then
					files_found=$((files_found + 1))
				fi
			fi
			# Lines 4-6 are the seen_files section
			if [[ $line_count -gt 3 ]] && [[ "$line" == *".bats"* ]]; then
				seen_found=$((seen_found + 1))
			fi
		fi
	done <<< "$result"

	# Restore original mock
	find_bats_files() {
		local dir="$1"
		if [[ "$dir" == "/test/project/tests/bats" ]]; then
			echo "/test/project/tests/bats/test1.bats"
			echo "/test/project/tests/bats/test2.bats"
		elif [[ "$dir" == "/test/project/test/bats" ]]; then
			echo "/test/project/test/bats/test3.bats"
		elif [[ "$dir" == "/test/project" ]]; then
			echo "/test/project/root_test.bats"
		fi
	}

	# Cleanup
	rm -rf "$tmp_dir"

	[ "$files_found" -eq 3 ]
	[ "$seen_found" -eq 3 ]
}

@test "_bats_discover_root_files excludes files from test directories" {
	# Create temporary directory for the test
	local tmp_dir=$(mktemp -d)
	local project_root="$tmp_dir/test/project"
	mkdir -p "$project_root"
	
	# Override find_bats_files globally to use the temp directory
	find_bats_files() {
		local dir="$1"
		if [[ "$dir" == "$project_root" ]]; then
			echo "$project_root/root_test.bats"
		fi
	}
	
	local test_dirs=("$project_root/tests/bats" "$project_root/test/bats" "$project_root/tests" "$project_root/test")
	local seen_files=("$project_root/tests/bats/test1.bats" "$project_root/tests/bats/test2.bats")

	local result
	result=$(_bats_discover_root_files "$project_root" "${test_dirs[@]}" "${seen_files[@]}")

	local root_files_found=0
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Trim whitespace
		line="${line%"${line##*[![:space:]]}"}"
		line="${line#"${line%%[![:space:]]*}"}"
		if [[ -n "$line" ]] && [[ "$line" == "$project_root/root_test.bats" ]]; then
			root_files_found=$((root_files_found + 1))
		fi
	done <<< "$result"

	# Restore original mock
	find_bats_files() {
		local dir="$1"
		if [[ "$dir" == "/test/project/tests/bats" ]]; then
			echo "/test/project/tests/bats/test1.bats"
			echo "/test/project/tests/bats/test2.bats"
		elif [[ "$dir" == "/test/project/test/bats" ]]; then
			echo "/test/project/test/bats/test3.bats"
		elif [[ "$dir" == "/test/project" ]]; then
			echo "/test/project/root_test.bats"
		fi
	}

	# Cleanup
	rm -rf "$tmp_dir"

	[ "$root_files_found" -eq 1 ]
}

@test "_bats_build_suites_json builds proper JSON structure" {
	local project_root="/test/project"
	local bats_files=("/test/project/tests/test1.bats" "/test/project/tests/test2.bats")

	local result
	result=$(_bats_build_suites_json "$project_root" "${bats_files[@]}")

	# Should be a valid JSON array
	[[ "$result" == "["*"]" ]]

	# Should contain the expected structure
	[[ "$result" == *"\"name\":\"test1\""* ]]
	[[ "$result" == *"\"name\":\"test2\""* ]]
	[[ "$result" == *"\"framework\":\"bats\""* ]]
	[[ "$result" == *"\"test_files\":[\"tests/test1.bats\"]"* ]]
}

@test "_bats_build_suites_json returns empty array when no files" {
	local project_root="/test/project"
	local bats_files=()

	local result
	result=$(_bats_build_suites_json "$project_root")

	[ "$result" = "[]" ]
}
