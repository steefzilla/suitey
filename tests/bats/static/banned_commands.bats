#!/usr/bin/env bats

# ============================================================================
# Banned Commands Tests (Requirements-based)
# ============================================================================

# Configurable list of banned commands
# Add new banned commands here as requirements change
declare -a BANNED_COMMANDS=(
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
	local violations=()

	for cmd in "${BANNED_COMMANDS[@]}"; do
		# Find all occurrences of the command
		local found_lines
		mapfile -t found_lines < <(grep -rn "$cmd" src/ | grep -v "# suitey:allow $cmd")

		if [ ${#found_lines[@]} -gt 0 ]; then
			violations+=("Command '$cmd' found without exception:")
			for line in "${found_lines[@]}"; do
				violations+=("  $line")
			done
		fi
	done

	if [ ${#violations[@]} -gt 0 ]; then
		echo "Banned commands found: ${violations[*]}"
		false
	fi
}

@test "banned commands only used with proper exception syntax" {
	for cmd in "${BANNED_COMMANDS[@]}"; do
		# Find lines with banned command but without proper exception
		local bad_exceptions
		bad_exceptions=$(grep -rn "$cmd" src/ | grep -v "# suitey:allow $cmd" | grep "#.*allow" | wc -l)

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
		found=$(grep -r "$pkg_mgr" src/ | grep -v "#.*example\|#.*test\|#.*safe" | wc -l)
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
		found=$(grep -r "$admin_cmd" src/ | grep -v "#.*example\|#.*test\|#.*safe\|#.*justified" | wc -l)
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
