#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Code Complexity Analysis Tests
# ============================================================================

@test "functions are not too long (max 50 lines)" {
	local long_functions
	long_functions=$(find src -name "*.sh" -exec awk '
		function should_skip_line(line) {
			# Remove leading/trailing whitespace for checking
			trimmed = line
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", trimmed)
			
			# Skip blank lines and comments
			if (trimmed == "" || trimmed ~ /^[[:space:]]*#/) {
				return 1
			}
			
			# Check for pure informational output: echo/print/debug that only outputs to stdout/stderr
			# Exclude if line has pipes or file redirection (functional uses)
			if (line ~ /^[[:space:]]*echo[[:space:]]+/ || line ~ /^[[:space:]]*print[[:space:]]+/ || line ~ /^[[:space:]]*debug[[:space:]]+/) {
				# If it has pipes or file redirection, it is functional (do not skip)
				if (line ~ /\|/ || line ~ />[[:space:]]*[^&]/ || line ~ />>[[:space:]]*[^&]/ || line ~ /2>&1/) {
					return 0
				}
				# Otherwise it is just informational output (skip it)
				return 1
			}
			
			return 0
		}
		
		/^function / {
			func_line = NR
			func_name = $2
			sub(/\(\)/, "", func_name)
			line_count = 0
		}
		/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
			func_line = NR
			func_name = $1
			sub(/\(\)/, "", func_name)
			line_count = 0
		}
		/^}/ {
			if (line_count > 50) {
				print FILENAME ":" func_name ":" line_count
			}
			line_count = 0
		}
		{
			# Skip blank lines, comment-only lines, and informational-only lines
			if (!should_skip_line($0)) {
				line_count++
			}
		}
	' {} \;)

	if [ -n "$long_functions" ]; then
		echo "Functions too long (>50 lines): $long_functions"
		false
	fi
}

@test "files don't have too many functions (max 20)" {
	local complex_files
	complex_files=$(find src -name "*.sh" -exec sh -c '
		funcs=$(grep -c "^function \|^[a-zA-Z_].*() " "$1")
		if [ "$funcs" -gt 20 ]; then
			echo "$1: $funcs functions"
		fi
	' _ {} \;)

	if [ -n "$complex_files" ]; then
		echo "Files with too many functions: $complex_files"
		false
	fi
}

@test "no excessive nesting depth (max 4 levels)" {
	local nested_files
	nested_files=$(find src -name "*.sh" -exec awk '
		BEGIN { max_depth = 4 }
		/^{/ { depth++ }
		/^}/ { depth-- }
		depth > max_depth {
			print FILENAME ":" NR ": nesting depth " depth
			found = 1
		}
		END { if (found) exit 1 }
	' {} \;)

	if [ -n "$nested_files" ]; then
		echo "Excessive nesting found: $nested_files"
		false
	fi
}

@test "no extremely long lines (max 120 characters)" {
	local long_lines
	long_lines=$(find src -name "*.sh" -exec awk '
		length($0) > 120 {
			print FILENAME ":" NR ": " length($0) " chars"
		}
	' {} \;)

	if [ -n "$long_lines" ]; then
		echo "Extremely long lines found: $long_lines"
		false
	fi
}

@test "reasonable file sizes (max 1000 lines)" {
	local large_files
	large_files=$(find src -name "*.sh" -exec awk '
		function should_skip_line(line) {
			# Remove leading/trailing whitespace for checking
			trimmed = line
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", trimmed)
			
			# Skip blank lines and comments
			if (trimmed == "" || trimmed ~ /^[[:space:]]*#/) {
				return 1
			}
			
			# Check for pure informational output: echo/print/debug that only outputs to stdout/stderr
			# Exclude if line has pipes or file redirection (functional uses)
			if (line ~ /^[[:space:]]*echo[[:space:]]+/ || line ~ /^[[:space:]]*print[[:space:]]+/ || line ~ /^[[:space:]]*debug[[:space:]]+/) {
				# If it has pipes or file redirection, it is functional (do not skip)
				if (line ~ /\|/ || line ~ />[[:space:]]*[^&]/ || line ~ />>[[:space:]]*[^&]/ || line ~ /2>&1/) {
					return 0
				}
				# Otherwise it is just informational output (skip it)
				return 1
			}
			
			return 0
		}
		
		BEGIN { line_count = 0 }
		{
			# Skip blank lines, comment-only lines, and informational-only lines
			if (!should_skip_line($0)) {
				line_count++
			}
		}
		END {
			if (line_count > 1000) {
				print FILENAME ": " line_count " lines"
			}
		}
	' {} \;)

	if [ -n "$large_files" ]; then
		echo "Files too large (>1000 lines): $large_files"
		false
	fi
}
