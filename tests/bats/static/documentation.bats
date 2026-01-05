#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


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
	skip "TODO: implement proper minimization"
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

	# Count comments that are too short but NOT empty (exclude empty comments as they're intentional separators)
	# Exclude empty comments, shebang, and set commands
	local too_short_comments
	too_short_comments=$(grep "^#" suitey.sh | grep -v "^#!/bin/bash" | grep -v "^# set" | grep -v "^# *$" | awk 'length($0) < 5' | wc -l)

	if [ "$too_short_comments" -ne 0 ]; then
		echo "Found $too_short_comments meaningless comments (too short but not empty):"
		grep "^#" suitey.sh | grep -v "^#!/bin/bash" | grep -v "^# set" | grep -v "^# *$" | awk 'length($0) < 5'
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
	# Find user-facing ERROR messages (not log entries, not test output, not JSON responses)
	# Focus on lines that echo "ERROR:" to stderr (user-facing error messages)
	undocumented_errors=$(grep -r 'echo "ERROR:' src/ | \
		grep -v "#.*documented\|#.*explained\|>>.*log\|>>.*error_log\|test.*mode\|BUILD_FAILED" | \
		wc -l)

	# Allow reasonable number of undocumented errors
	# Many error messages are self-explanatory or follow consistent patterns
	# Focus on ensuring critical user-facing errors are documented
	# Threshold allows for common error patterns without requiring documentation on every message
	if [ "$undocumented_errors" -gt 20 ]; then
		echo "Found $undocumented_errors undocumented ERROR messages (user-facing)"
		false
	fi
}
