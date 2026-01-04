#!/usr/bin/env bats

# ============================================================================
# Banned Commands Tests (Requirements-based)
# ============================================================================

# Configurable list of banned commands
# Add new banned commands here as requirements change
BANNED_COMMANDS=(
	"jq"        # Explicitly banned per requirements
	"python"    # Creates unwanted Python dependency
	"node"      # Creates unwanted Node.js dependency
	"npm"       # Creates unwanted npm dependency
	"yarn"      # Creates unwanted yarn dependency
	"pip"       # Creates unwanted Python pip dependency
	"gem"       # Creates unwanted Ruby dependency
	"composer"  # Creates unwanted PHP dependency
	"docker-compose"  # May not be available on all systems
	"kubectl"   # Creates unwanted Kubernetes dependency
	"terraform" # Creates unwanted infrastructure dependency
	"ansible"   # Creates unwanted configuration management dependency
)

@test "no banned commands used without explicit exceptions" {
	# Find src directory - use current working directory (BATS runs from project root)
	local src_dir="$(pwd)/src"
	
	# Verify src directory exists
	if [[ ! -d "$src_dir" ]]; then
		echo "ERROR: Cannot find src/ directory at $src_dir (PWD: $(pwd))" >&2
		return 1
	fi

	for cmd in "${BANNED_COMMANDS[@]}"; do
		# Find all occurrences of the command
		# Use -w for word boundaries to avoid false positives and ensure accurate detection
		local grep_output
		grep_output=$(grep -rnw "$cmd" "$src_dir/" 2>/dev/null | grep -v "# suitey:allow $cmd")
		local found_count
		found_count=$(echo "$grep_output" | wc -l | tr -d ' ')

		# Fail immediately if found (use arithmetic comparison)
		if (( found_count > 0 )); then
			echo "Command '$cmd' found without exception ($found_count occurrences):" >&2
			# Show first few examples
			echo "$grep_output" | head -5 | while IFS= read -r line; do
				echo "  $line" >&2
			done
			# Use explicit failure
			return 1
		fi
	done
}

@test "banned commands only used with proper exception syntax" {
	# Find project root (where src/ directory is located)
	local project_root
	if [[ -n "$BATS_TEST_DIRNAME" ]] && [[ -d "$BATS_TEST_DIRNAME/../../../src" ]]; then
		project_root=$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)
	elif [[ -d "src" ]]; then
		project_root="$(pwd)"
	else
		echo "ERROR: Cannot find project root (src/ directory)" >&2
		false
		return
	fi

	for cmd in "${BANNED_COMMANDS[@]}"; do
		# Find lines with banned command but without proper exception
		local bad_exceptions
		# Use -w for word boundaries to avoid false positives
		bad_exceptions=$(grep -rnw "$cmd" "$project_root/src/" 2>/dev/null | grep -v "# suitey:allow $cmd" | grep "#.*allow" | wc -l)

		if [ "$bad_exceptions" -ne 0 ]; then
			echo "Found $bad_exceptions improper exception comments for '$cmd'"
			false
		fi
	done
}

@test "no external package managers used" {
	local package_managers=("apt" "yum" "dnf" "pacman" "brew" "snap" "flatpak")
	local violations=()

	for pkg_mgr in "${package_managers[@]}"; do
		local found
		# Use -w flag for word boundaries to avoid false positives (e.g., "adapter" matching "apt")
		found=$(grep -rw "$pkg_mgr" src/ | grep -v "#.*example\|#.*test\|#.*safe" | wc -l)
		if [ "$found" -gt 0 ]; then
			violations+=("$pkg_mgr ($found occurrences)")
		fi
	done

	if [ ${#violations[@]} -gt 0 ]; then
		echo "External package managers used: ${violations[*]}"
		false
	fi
}

@test "no system administration commands without justification" {
	local admin_cmds=("systemctl" "service" "chkconfig" "update-rc.d" "mount" "umount" "fsck" "mkfs")
	local violations=()

	for admin_cmd in "${admin_cmds[@]}"; do
		local found
		# Use -w for word boundaries to avoid false positives (e.g., "volume_mount" matching "mount")
		# Exclude Docker volume mount contexts, variable names, JSON keys, and comments
		found=$(grep -rw "$admin_cmd" src/ | \
			grep -v "#.*example\|#.*test\|#.*safe\|#.*justified\|volume.*mount\|bind.*mount\|_mount\|mounts\|Mount.*to\|Launch.*mount\|volume_mount" | \
			wc -l)
		if [ "$found" -gt 0 ]; then
			violations+=("$admin_cmd ($found occurrences)")
		fi
	done

	if [ ${#violations[@]} -gt 0 ]; then
		echo "System administration commands used without justification: ${violations[*]}"
		false
	fi
}

@test "no network tools that create external dependencies" {
	local network_tools=("curl" "wget" "ssh" "scp" "rsync" "ftp" "sftp")
	local allowed_contexts=("command -v" "#.*check\|#.*detect\|#.*optional")

	for tool in "${network_tools[@]}"; do
		local found
		found=$(grep -r "$tool" src/ | grep -v "$allowed_contexts" | wc -l)

		# Allow some basic network checks but flag extensive usage
		if [ "$found" -gt 2 ]; then
			echo "Excessive use of network tool '$tool' ($found occurrences)"
			false
		fi
	done
}
