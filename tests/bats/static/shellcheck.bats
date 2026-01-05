#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Shell Script Linting Tests (shellcheck)
# ============================================================================

@test "all shell scripts pass shellcheck with severity=error" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src tests -name "*.sh" -o -name "*.bash" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	for file in "${shell_files[@]}"; do
		run shellcheck --severity=error "$file"
		if [ "$status" -ne 0 ]; then
			echo "shellcheck failed on $file: $output"
			false
		fi
	done
}

@test "all shell scripts pass shellcheck with severity=warning" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src tests -name "*.sh" -o -name "*.bash" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	for file in "${shell_files[@]}"; do
		run shellcheck --severity=warning "$file"
		if [ "$status" -ne 0 ]; then
			echo "shellcheck warnings in $file: $output"
			false
		fi
	done
}

@test "executable scripts use bash shebang" {
	# Only check files that are meant to be executed directly (not sourced)
	local executable_scripts=("suitey.sh" "suitey.min.sh")

	for script in "${executable_scripts[@]}"; do
		if [ -f "$script" ]; then
			local first_line
			first_line=$(head -1 "$script")
			if [[ "$first_line" != "#!/bin/bash" ]]; then
				echo "File $script does not use proper bash shebang: $first_line"
				false
			fi
		fi
	done
}
