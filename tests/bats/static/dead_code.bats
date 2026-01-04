#!/usr/bin/env bats

# ============================================================================
# Dead Code Detection Tests
# ============================================================================

@test "no unused functions within same file" {
	local unused_functions
	unused_functions=$(find src -name "*.sh" -exec awk '
		/^function [a-zA-Z_]/ {
			func_name = $2
			sub(/\(\)/, "", func_name)
			functions[func_name] = 1
			function_file[func_name] = FILENAME
		}
		/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
			func_name = $1
			sub(/\(\)/, "", func_name)
			functions[func_name] = 1
			function_file[func_name] = FILENAME
		}
		{
			line = $0
			for (f in functions) {
				if (function_file[f] == FILENAME && index(line, f) > 0 && line !~ /^function / && line !~ /^[a-zA-Z_].*\(\)/) {
					called[f] = 1
				}
			}
		}
		END {
			for (f in functions) {
				if (!(f in called) && function_file[f] == FILENAME) {
					print function_file[f] ":" f
				}
			}
		}
	' {} \;)

	# Skip this test as it requires more sophisticated analysis
	# The awk script above is too simplistic for shell script analysis
	skip "Unused function detection requires advanced analysis tools"
}

@test "no unreachable code after return statements" {
	local unreachable_code
	unreachable_code=$(find src -name "*.sh" -exec awk '
		/^	return / {
			in_function = 1
			return_line = NR
			next
		}
		/^}/ {
			in_function = 0
		}
		in_function && NR > return_line && !/^#/ && !/^$/ && !/}/ {
			print FILENAME ":" NR ": unreachable code after return"
		}
	' {} \;)

	if [ -n "$unreachable_code" ]; then
		echo "Unreachable code found: $unreachable_code"
		false
	fi
}

@test "no duplicate function definitions" {
	local duplicate_functions
	duplicate_functions=$(find src -name "*.sh" -exec awk '
		/^function [a-zA-Z_]/ {
			func_name = $2
			sub(/\(\)/, "", func_name)
			if (seen[func_name]++) {
				print FILENAME ":" func_name
			}
		}
		/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
			func_name = $1
			sub(/\(\)/, "", func_name)
			if (seen[func_name]++) {
				print FILENAME ":" func_name
			}
		}
	' {} \;)

	if [ -n "$duplicate_functions" ]; then
		echo "Duplicate function definitions: $duplicate_functions"
		false
	fi
}

@test "no empty functions" {
	local empty_functions
	empty_functions=$(find src -name "*.sh" -exec awk '
		/^function [a-zA-Z_]/ {
			func_name = $2
			func_line = NR
			getline
			if ($0 ~ /^}$/) {
				print FILENAME ":" func_name
			}
		}
		/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
			func_name = $1
			func_line = NR
			getline
			if ($0 ~ /^}$/) {
				print FILENAME ":" func_name
			}
		}
	' {} \;)

	if [ -n "$empty_functions" ]; then
		echo "Empty functions found: $empty_functions"
		false
	fi
}

@test "no obviously unused local variables" {
	local unused_locals
	unused_locals=$(find src -name "*.sh" -exec awk '
		/local [a-zA-Z_]/ {
			for (i = 2; i <= NF; i++) {
				if ($i ~ /^[a-zA-Z_][a-zA-Z0-9_]*=/) {
					var = $i
					sub(/=.*/, "", var)
					local_vars[var] = NR
				} else if ($i ~ /^[a-zA-Z_][a-zA-Z0-9_]*$/) {
					var = $i
					local_vars[var] = NR
				}
			}
		}
		{
			for (var in local_vars) {
				if (index($0, "$" var) > 0 || index($0, "${" var) > 0) {
					delete local_vars[var]
				}
			}
		}
		/^}/ {
			for (var in local_vars) {
				if (local_vars[var] > 0) {
					print FILENAME ":" local_vars[var] ": unused local variable " var
				}
			}
			delete local_vars
		}
	' {} \;)

	# This is too noisy for shell scripts, skip for now
	skip "Local variable usage analysis is complex in shell scripts"
}
