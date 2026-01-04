#!/usr/bin/env bats

# ============================================================================
# Source/Include Analysis Tests
# ============================================================================

@test "all sourced files exist" {
	local missing_files=()

	while IFS= read -r file; do
		# Extract source commands
		local sources
		mapfile -t sources < <(grep -h "^source \|^\\. " "$file" | sed 's/^source //' | sed 's/^\. //' | tr -d '"'\''')

		for source_file in "${sources[@]}"; do
			# Skip if it's a variable or command substitution
			if [[ "$source_file" =~ \$ ]] || [[ "$source_file" =~ \` ]] || [[ "$source_file" =~ \$ ]]; then
				continue
			fi

			# Check absolute paths
			if [[ "$source_file" == /* ]]; then
				if [[ ! -f "$source_file" ]]; then
					missing_files+=("$file sources missing: $source_file")
				fi
			else
				# Check relative to file directory
				local file_dir
				file_dir=$(dirname "$file")
				local full_path="$file_dir/$source_file"
				if [[ ! -f "$full_path" ]]; then
					# Also check relative to project root
					local root_path="$source_file"
					if [[ ! -f "$root_path" ]]; then
						missing_files+=("$file sources missing: $source_file")
					fi
				fi
			fi
		done
	done < <(find src tests -name "*.sh" | grep -v ".git")

	if [ ${#missing_files[@]} -gt 0 ]; then
		echo "Missing sourced files: ${missing_files[*]}"
		false
	fi
}

@test "no circular dependencies in includes" {
	# This is complex to detect statically, so we'll do a basic check
	local circular_patterns
	circular_patterns=$(find src -name "*.sh" -exec sh -c '
		file="$1"
		# Get all files this file sources
		sources=$(grep "^source \|^\\. " "$file" | sed "s/^source //" | sed "s/^\. //" | tr -d "\"'\''" | grep -v "\\$")

		for source in $sources; do
			# Check if the sourced file sources this file back
			if [ -f "$source" ]; then
				if grep -q "^source $file\|^\\. $file" "$source" 2>/dev/null; then
					echo "$file <-> $source"
				fi
			fi
		done
	' _ {} \;)

	if [ -n "$circular_patterns" ]; then
		echo "Circular dependencies detected: $circular_patterns"
		false
	fi
}

@test "source commands use proper syntax" {
	local bad_sources
	bad_sources=$(grep -r "^source[^ ]\|^\\.[^ ]" src/ | grep -v "#.*example\|#.*test" | wc -l)

	if [ "$bad_sources" -ne 0 ]; then
		echo "Found $bad_sources source commands without proper spacing"
		false
	fi
}

@test "no source loops (file sourcing itself)" {
	local self_sources
	self_sources=$(find src -name "*.sh" -exec sh -c '
		file="$1"
		basename_file=$(basename "$file")

		if grep "^source .*$basename_file\|^\\. .*$basename_file" "$file" >/dev/null 2>&1; then
			echo "$file"
		fi
	' _ {} \;)

	if [ -n "$self_sources" ]; then
		echo "Files sourcing themselves: $self_sources"
		false
	fi
}

@test "source commands are at top of files" {
	local misplaced_sources
	misplaced_sources=$(find src -name "*.sh" -exec awk '
		BEGIN { source_count = 0; non_comment_count = 0 }
		/^source / || /^\. / {
			if (non_comment_count > 0) {
				print FILENAME ": source command after non-comment line"
				found = 1
			}
			source_count++
		}
		/^[^#]/ && !/^$/ && !/^source / && !/^\. / {
			non_comment_count++
		}
		END { if (found) exit 1 }
	' {} \;)

	if [ -n "$misplaced_sources" ]; then
		echo "Misplaced source commands: $misplaced_sources"
		false
	fi
}
