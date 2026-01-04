#!/usr/bin/env bats

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
	local unsafe_eval
	unsafe_eval=$(grep -r "eval.*\$" src/ | grep -v "#.*safe\|#.*test" | wc -l)

	if [ "$unsafe_eval" -ne 0 ]; then
		echo "Potentially unsafe eval usage with variables"
		false
	fi
}

@test "no dangerous command substitution in eval" {
	local dangerous_eval
	dangerous_eval=$(grep -r "eval.*\`\|\$\(" src/ | grep -v "#.*safe\|#.*test" | wc -l)

	if [ "$dangerous_eval" -ne 0 ]; then
		echo "Dangerous command substitution in eval"
		false
	fi
}

@test "no unquoted variable expansion in file operations" {
	local unquoted_files
	unquoted_files=$(grep -r "rm.*\$[^\"]\|mv.*\$[^\"]\|cp.*\$[^\"]\|chmod.*\$[^\"]" src/ | grep -v "#.*safe\|#.*test" | wc -l)

	if [ "$unquoted_files" -ne 0 ]; then
		echo "Unquoted variables in file operations"
		false
	fi
}

@test "no path traversal in file operations" {
	local path_traversal
	path_traversal=$(grep -r "\.\./\|\.\.\\\|\.\.\/" src/ | grep -v "#.*example\|#.*test\|#.*safe" | wc -l)

	if [ "$path_traversal" -ne 0 ]; then
		echo "Potential path traversal sequences"
		false
	fi
}

@test "no shell injection in command substitution" {
	local shell_injection
	shell_injection=$(grep -r "\$\([^)]*\$[^)]*\)" src/ | grep -v "#.*safe\|#.*test" | wc -l)

	if [ "$shell_injection" -ne 0 ]; then
		echo "Potential shell injection in command substitution"
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
