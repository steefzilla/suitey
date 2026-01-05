#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:

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

@test "consistent indentation uses single tabs only" {
	local multi_tab_files
	multi_tab_files=$(find src tests \( -name "*.sh" -o -name "*.bats" \) -exec grep -l "^\t\t" {} \; 2>/dev/null || true)

	if [ -n "$multi_tab_files" ]; then
		echo "Multi-tab-indented files found (should use single tabs only): $multi_tab_files"
		false
	fi
}

@test "editor hints present in source files" {
	local missing_hints_files
	missing_hints_files=$(find src tests/bats \( -name "*.sh" -o -name "*.bats" \) -exec sh -c '
		file="$1"
		# Check if file contains vim modeline OR editor hints comment
		if ! head -20 "$file" | grep -q "vim: set tabstop=4 shiftwidth=4 noexpandtab:" && \
		   ! head -20 "$file" | grep -q "Editor hints: Use single-tab indentation"; then
			echo "$file"
		fi
	' _ {} \;)

	if [ -n "$missing_hints_files" ]; then
		echo "Source files missing editor hints (vim/emacs indentation settings): $missing_hints_files"
		false
	fi
}

@test "functions use POSIX-compliant syntax" {
	local non_posix_functions
	non_posix_functions=$(grep -r "^function " src/ | wc -l)

	if [ "$non_posix_functions" -ne 0 ]; then
		echo "Found $non_posix_functions functions using 'function' keyword (should use POSIX syntax: funcname() not function funcname())"
		false
	fi
}

@test "potentially dangerous unquoted variables" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local unquoted_issues=()
	for file in "${shell_files[@]}"; do
		# Check for unquoted variable issues (SC2086, SC2206, SC2207)
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC2086|SC2206|SC2207" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				unquoted_issues+=("$file: $issue")
			done <<< "$issues"
		fi
	done

	if [ ${#unquoted_issues[@]} -ne 0 ]; then
		echo "Found ${#unquoted_issues[@]} unquoted variable issues (shellcheck SC2086/SC2206/SC2207):"
		printf '%s\n' "${unquoted_issues[@]}"
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
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local spacing_issues=()
	for file in "${shell_files[@]}"; do
		# Check for operator spacing issues (SC1007, SC1066, SC1068)
		# SC1007: Remove space after = if trying to assign a value
		# SC1066: Don't use $ on the left side of assignments
		# SC1068: Don't put spaces around the = in assignments
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC1007|SC1066|SC1068" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				spacing_issues+=("$file: $issue")
			done <<< "$issues"
		fi
	done

	if [ ${#spacing_issues[@]} -ne 0 ]; then
		echo "Found ${#spacing_issues[@]} operator spacing issues (shellcheck SC1007/SC1066/SC1068):"
		printf '%s\n' "${spacing_issues[@]}"
		false
	fi
}
