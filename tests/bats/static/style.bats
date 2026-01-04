#!/usr/bin/env bats

# ============================================================================
# Code Style Consistency Tests
# ============================================================================

@test "consistent indentation uses tabs, not spaces" {
	local space_indented_files
	space_indented_files=$(find src -name "*.sh" -exec grep -l "^[ ]" {} \;)

	if [ -n "$space_indented_files" ]; then
		echo "Space-indented files found (should use tabs): $space_indented_files"
		false
	fi
}

@test "functions use proper naming convention" {
	local bad_names
	bad_names=$(grep -r "^[a-zA-Z_][a-zA-Z0-9_]*()" src/ | grep -v "function " | wc -l)

	if [ "$bad_names" -ne 0 ]; then
		echo "Found $bad_names functions without 'function' keyword"
		false
	fi
}

@test "potentially dangerous unquoted variables" {
	local unquoted
	unquoted=$(grep -r '\$[a-zA-Z_][a-zA-Z0-9_]*[^"]' src/ | grep -v "#" | grep -v "echo" | grep -v "printf" | wc -l)

	if [ "$unquoted" -ne 0 ]; then
		echo "Found $unquoted potentially unquoted variables in dangerous contexts"
		false
	fi
}

@test "line endings are Unix (LF, not CRLF)" {
	local crlf_files
	crlf_files=$(find src -name "*.sh" -exec grep -l $'\r' {} \;)

	if [ -n "$crlf_files" ]; then
		echo "Files with CRLF line endings: $crlf_files"
		false
	fi
}

@test "no trailing whitespace" {
	local trailing_ws
	trailing_ws=$(find src -name "*.sh" -exec grep -l '[[:space:]]$' {} \;)

	if [ -n "$trailing_ws" ]; then
		echo "Files with trailing whitespace: $trailing_ws"
		false
	fi
}

@test "consistent spacing around operators" {
	local bad_spacing
	bad_spacing=$(grep -r "=[[:space:]]*\|[[:space:]]*=[[:space:]]*" src/ | grep -v "#" | grep -v "==" | grep -v "!=" | grep -v "<=" | grep -v ">=" | wc -l)

	if [ "$bad_spacing" -ne 0 ]; then
		echo "Found $bad_spacing inconsistent operator spacing"
		false
	fi
}
