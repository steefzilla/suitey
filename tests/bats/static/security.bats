#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Security Vulnerability Scanning Tests
# ============================================================================

@test "no hardcoded passwords or secrets" {
	local secrets_found
	secrets_found=$(grep -r -i "password\|secret\|token\|key.*123\|admin.*admin\|apikey\|api_key" src/ | grep -v "#.*example\|#.*test\|#.*placeholder" | wc -l)

	if [ "$secrets_found" -ne 0 ]; then
		echo "Potential hardcoded secrets found"
		false
	fi
}

@test "no unsafe eval usage with variables" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	# Find files that contain eval statements
	local eval_files
	mapfile -t eval_files < <(grep -r -l "eval" src/ --include="*.sh" 2>/dev/null | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$" || true)

	if [ ${#eval_files[@]} -eq 0 ]; then
		# No eval usage found, test passes
		return 0
	fi

	local eval_issues=()
	for file in "${eval_files[@]}"; do
		# Check for unsafe eval usage patterns
		# SC2086: Double quote to prevent globbing and word splitting (unquoted variables)
		# SC2046: Quote this to prevent word splitting
		# SC2294: eval negates the benefits of arrays
		# Check if warnings are on lines containing eval
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC2086|SC2046|SC2294" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				# Extract line number from gcc format: file:line:column:severity:code:message
				local line_num
				line_num=$(echo "$issue" | cut -d: -f2)
				if [ -n "$line_num" ] && [ "$line_num" -gt 0 ] 2>/dev/null; then
					# Check if this line or nearby lines contain eval
					local line_content
					line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")
					if echo "$line_content" | grep -q "eval"; then
						eval_issues+=("$file: $issue")
					fi
				fi
			done <<< "$issues"
		fi
	done

	if [ ${#eval_issues[@]} -ne 0 ]; then
		echo "Found ${#eval_issues[@]} unsafe eval usage issues (shellcheck SC2086/SC2046/SC2294):"
		printf '%s\n' "${eval_issues[@]}"
		false
	fi
}

@test "no dangerous command substitution in eval" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local dangerous_eval_issues=()
	for file in "${shell_files[@]}"; do
		# Check for deprecated backticks in eval statements (SC2006)
		# SC2006: Use $(...) instead of deprecated `...`
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep "SC2006" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				# Extract line number from gcc format: file:line:column:severity:code:message
				local line_num
				line_num=$(echo "$issue" | cut -d: -f2)
				if [ -n "$line_num" ] && [ "$line_num" -gt 0 ] 2>/dev/null; then
					# Check if this line contains eval
					local line_content
					line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")
					if echo "$line_content" | grep -q "eval"; then
						dangerous_eval_issues+=("$file: $issue")
					fi
				fi
			done <<< "$issues"
		fi
	done

	if [ ${#dangerous_eval_issues[@]} -ne 0 ]; then
		echo "Found ${#dangerous_eval_issues[@]} dangerous command substitution in eval issues (shellcheck SC2006):"
		printf '%s\n' "${dangerous_eval_issues[@]}"
		false
	fi
}

@test "no unquoted variable expansion in file operations" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local unquoted_issues=()
	for file in "${shell_files[@]}"; do
		# Check for unquoted variables in file operations (SC2086)
		# SC2086: Double quote to prevent globbing and word splitting
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC2086" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				local line_num
				line_num=$(echo "$issue" | cut -d: -f2)
				if [ -n "$line_num" ] && [ "$line_num" -gt 0 ] 2>/dev/null; then
					local line_content
					line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")
					# Check if this line contains file operations (rm, mv, cp, chmod, chown, mkdir, rmdir, touch, ln)
					if echo "$line_content" | grep -qE '\b(rm|mv|cp|chmod|chown|mkdir|rmdir|touch|ln)\s+'; then
						unquoted_issues+=("$file: $issue")
					fi
				fi
			done <<< "$issues"
		fi
	done

	if [ ${#unquoted_issues[@]} -ne 0 ]; then
		echo "Found ${#unquoted_issues[@]} unquoted variables in file operations (shellcheck SC2086):"
		printf '%s\n' "${unquoted_issues[@]}"
		false
	fi
}

@test "no path traversal in file operations" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local traversal_issues=()
	for file in "${shell_files[@]}"; do
		# Check for unquoted variables in file operations (SC2086)
		# SC2086: Double quote to prevent globbing and word splitting
		# This catches cases where variables containing ../ might be used unsafely in file operations
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC2086" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				local line_num
				line_num=$(echo "$issue" | cut -d: -f2)
				if [ -n "$line_num" ] && [ "$line_num" -gt 0 ] 2>/dev/null; then
					local line_content
					line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")
					# Check if this line contains file operations (rm, mv, cp, cat, chmod, chown, mkdir, rmdir, touch, ln, read, write, exec, source, .)
					# Exclude hardcoded paths like "../src/file.sh" which are safe
					if echo "$line_content" | grep -qE '\b(rm|mv|cp|cat|chmod|chown|mkdir|rmdir|touch|ln|read|write|exec|source|\.)\s+' && \
					   ! echo "$line_content" | grep -qE '"(\.\./|\.\.\\)|'\''(\.\./|\.\.\\)'; then
						traversal_issues+=("$file: $issue")
					fi
				fi
			done <<< "$issues"
		fi
	done

	if [ ${#traversal_issues[@]} -ne 0 ]; then
		echo "Found ${#traversal_issues[@]} potential path traversal risks (unquoted variables in file operations):"
		printf '%s\n' "${traversal_issues[@]}"
		false
	fi
}

@test "no shell injection in command substitution" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck command not available"
	fi

	local shell_files
	mapfile -t shell_files < <(find src -name "*.sh" | grep -v ".git" | grep -v "\.backup" | grep -v "\.bak$")

	local injection_issues=()
	for file in "${shell_files[@]}"; do
		# Check for unquoted variables in command substitution (SC2086)
		# SC2086: Double quote to prevent globbing and word splitting
		# SC2028: echo may not expand escape sequences (can indicate unsafe string handling)
		# SC2090: Quotes/backslashes in array assignment may be escaped
		# This detects actual shell injection risks, not just variable usage
		local issues
		issues=$(shellcheck --format=gcc --severity=warning "$file" 2>/dev/null | grep -E "SC2086|SC2028|SC2090" || true)
		if [ -n "$issues" ]; then
			while IFS= read -r issue; do
				# Extract line number from gcc format: file:line:column:severity:code:message
				local line_num
				line_num=$(echo "$issue" | cut -d: -f2)
				if [ -n "$line_num" ] && [ "$line_num" -gt 0 ] 2>/dev/null; then
					# Check if this line contains command substitution
					local line_content
					line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")
					if echo "$line_content" | grep -q '\$('; then
						injection_issues+=("$file: $issue")
					fi
				fi
			done <<< "$issues"
		fi
	done

	if [ ${#injection_issues[@]} -ne 0 ]; then
		echo "Found ${#injection_issues[@]} shell injection risks in command substitution (shellcheck SC2086/SC2028/SC2090):"
		printf '%s\n' "${injection_issues[@]}"
		false
	fi
}

@test "no dangerous use of su or sudo" {
	local dangerous_su
	dangerous_su=$(grep -r "su \|sudo " src/ | grep -v "#.*example\|#.*test\|#.*safe" | wc -l)

	if [ "$dangerous_su" -ne 0 ]; then
		echo "Dangerous use of su or sudo"
		false
	fi
}

@test "no hardcoded URLs with credentials" {
	local credential_urls
	credential_urls=$(grep -r "https*://[^@]*@\|http*://[^@]*@" src/ | grep -v "#.*example\|#.*test\|#.*placeholder" | wc -l)

	if [ "$credential_urls" -ne 0 ]; then
		echo "Hardcoded URLs with credentials"
		false
	fi
}
