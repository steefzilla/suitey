#!/usr/bin/env bats

# ============================================================================
# Documentation Completeness Tests
# ============================================================================

@test "suitey.sh has file-level documentation" {
	[ -f "suitey.sh" ] || skip "suitey.sh not found"

	local has_header_docs
	has_header_docs=$(head -20 suitey.sh | grep -c "^#.*[dD]escription\|^#.*[pP]urpose\|^#.*[oO]verview\|^#.*[uU]sage\|^#.*[aA]uthor")

	if [ "$has_header_docs" -le 0 ]; then
		echo "suitey.sh missing file-level documentation comments"
		false
	fi
}

@test "suitey.sh functions have documentation" {
	[ -f "suitey.sh" ] || skip "suitey.sh not found"

	local undocumented_functions
	undocumented_functions=$(awk '
		/^function [a-zA-Z_]/ {
			func_name = $2
			func_line = NR

			# Check if previous lines have comments
			has_comment = 0
			for (i = func_line - 1; i > func_line - 5 && i > 0; i--) {
				if (lines[i] ~ /^#/) {
					has_comment = 1
					break
				}
			}
			if (!has_comment) {
				print func_name
			}
		}
		{
			lines[NR] = $0
		}
	' suitey.sh)

	if [ -n "$undocumented_functions" ]; then
		echo "suitey.sh functions without documentation: $undocumented_functions"
		false
	fi
}

@test "suitey.min.sh has NO comments (except shebang and set)" {
	[ -f "suitey.min.sh" ] || skip "suitey.min.sh not found"

	# Count total comment lines (excluding shebang and set commands)
	local comment_lines
	comment_lines=$(grep "^#" suitey.min.sh | grep -v "^#!/bin/bash" | grep -v "^# set -" | wc -l)

	if [ "$comment_lines" -ne 0 ]; then
		echo "suitey.min.sh contains $comment_lines comment lines (should have none except shebang/set)"
		false
	fi
}

@test "suitey.min.sh has only essential shebang and set commands" {
	[ -f "suitey.min.sh" ] || skip "suitey.min.sh not found"

	local first_two_lines
	first_two_lines=$(head -2 suitey.min.sh)

	if [[ "$first_two_lines" != "#!/bin/bash"* ]]; then
		echo "suitey.min.sh does not start with proper shebang"
		false
	fi

	# Check second line contains set command
	local second_line
	second_line=$(sed -n '2p' suitey.min.sh)
	if [[ "$second_line" != "# set "* ]]; then
		echo "suitey.min.sh second line is not a set command: $second_line"
		false
	fi
}

@test "documentation comments are meaningful" {
	[ -f "suitey.sh" ] || skip "suitey.sh not found"

	local empty_comments
	empty_comments=$(grep -c "^# *$" suitey.sh)

	local too_short_comments
	too_short_comments=$(grep "^#" suitey.sh | grep -v "^#!/bin/bash" | grep -v "^# set" | awk 'length($0) < 5' | wc -l)

	local total_meaningless=$((empty_comments + too_short_comments))
	if [ "$total_meaningless" -ne 0 ]; then
		echo "Found $total_meaningless meaningless comments (empty or too short)"
		false
	fi
}

@test "no TODO or FIXME comments in production code" {
	local todo_comments
	todo_comments=$(grep -r -i "todo\|fixme\|hack\|xxx" src/ | grep -v "#.*test\|#.*example" | wc -l)

	if [ "$todo_comments" -ne 0 ]; then
		echo "Found $todo_comments TODO/FIXME comments in production code"
		false
	fi
}

@test "error messages are documented" {
	local undocumented_errors
	undocumented_errors=$(grep -r "echo.*error\|echo.*Error\|echo.*ERROR" src/ | grep -v "#.*documented\|#.*explained" | wc -l)

	# Allow some error messages but flag excessive undocumented ones
	if [ "$undocumented_errors" -gt 5 ]; then
		echo "Found $undocumented_errors undocumented error messages"
		false
	fi
}
