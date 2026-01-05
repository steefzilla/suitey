# ============================================================================
# Adapter Registry Helper Functions
# ============================================================================
#
# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# Editor hints: Max line length: 120 characters
# Editor hints: Max function size: 50 lines
# Editor hints: Max functions per file: 20
# Editor hints: Max file length: 1000 lines
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# ============================================================================
# Helper Functions
# ============================================================================

# ============================================================================
# Return-Data Pattern Helper Function
# ============================================================================
#
# Helper function to populate an associative array from return-data format
# This is a reusable pattern for functions that return data instead of modifying
# arrays directly (to avoid BATS scoping issues).
#
# PATTERN: Return-Data Approach
# This helper implements the "return-data" pattern to avoid BATS scoping issues with
# namerefs/eval. Instead of modifying the caller's array directly, functions return data
# that the caller can use to populate their array.
#
# When to use return-data pattern:
#   - Function needs to populate caller's array
#   - Function is tested in BATS
#   - Function processes data from files/external sources
#   - You want explicit control over array population
#
# When nameref is acceptable:
#   - Function only reads from arrays (not modifies)
#   - Function modifies global arrays directly
#   - Function is not tested in BATS or tests pass
#   - Performance is critical (nameref is slightly faster)
#
# Arguments:
#   array_name: Name of associative array to populate
#   output: Output from a return-data function (first line is count, rest are key=value)
# Returns:
#   Populates the named array and returns the count
#
# Usage example:
#   output=$(_adapter_registry_load_array_from_file "array_name" "$file")
#   count=$(_adapter_registry_populate_array_from_output "array_name" "$output")
_adapter_registry_populate_array_from_output() {
	local array_name="$1"
	local output="$2"
	
	local count
	count=$(echo "$output" | head -n 1)
	
	# Populate array from remaining lines (only if count > 0)
	if [[ "$count" -gt 0 ]]; then
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			[[ -z "$key" ]] && continue
			eval "${array_name}[\"$key\"]=\"$value\""
		done < <(echo "$output" | tail -n +2)
	fi
	
	echo "$count"
	return 0
}

# Helper: Determine the base directory for registry files
_adapter_registry_determine_base_dir() {
	# Determine the base directory - prioritize TEST_ADAPTER_REGISTRY_DIR if set
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
		# TEST_ADAPTER_REGISTRY_DIR takes precedence for test consistency
		echo "$TEST_ADAPTER_REGISTRY_DIR"
	elif [[ -n "${REGISTRY_BASE_DIR:-}" ]] && [[ -d "${REGISTRY_BASE_DIR:-}" ]]; then
		# Use existing REGISTRY_BASE_DIR if it's a valid directory
		echo "$REGISTRY_BASE_DIR"
	else
		# Fall back to TMPDIR
		echo "${TMPDIR:-/tmp}"
	fi
}

# Helper: Ensure directory exists and is writable
_adapter_registry_ensure_directory() {
	local dir="$1"

	if ! mkdir -p "$dir" 2>&1; then
		echo "ERROR: Failed to create registry directory: $dir" >&2  # documented: Directory creation failed
		return 1
	fi
	return 0
}

# Helper: Base64 encode a value with platform fallbacks
_adapter_registry_encode_value() {
	local value="$1"
	local encoded_value=""

	# Base64 encode: try -w 0 (GNU) first, fall back to -b 0 (macOS) or no flag with tr
	if encoded_value=$(echo -n "$value" | base64 -w 0 2>/dev/null) && \
		[[ -n "$encoded_value" ]]; then
		: # Success with -w 0
	elif encoded_value=$(echo -n "$value" | base64 -b 0 2>/dev/null) && \
		[[ -n "$encoded_value" ]]; then
		: # Success with -b 0
	elif encoded_value=$(echo -n "$value" | base64 | tr -d '\n') && \
		[[ -n "$encoded_value" ]]; then
		: # Success with base64 + tr
	fi

	if [[ -z "$encoded_value" ]]; then
		echo "ERROR: Failed to encode value" >&2  # documented: Base64 encoding failed
		return 1
	fi

	echo "$encoded_value"
	return 0
}

# Helper: Base64 decode a value with platform fallbacks
_adapter_registry_decode_value() {
	local encoded_value="$1"
	local decoded_value=""

	# Try different base64 decoding variants
	# Check both exit code and non-empty output
	if decoded_value=$(echo -n "$encoded_value" | base64 -d 2>/dev/null); then
		if [[ -n "$decoded_value" ]]; then
			echo "$decoded_value"
			return 0
		fi
	elif decoded_value=$(echo -n "$encoded_value" | base64 --decode 2>/dev/null); then
		if [[ -n "$decoded_value" ]]; then
			echo "$decoded_value"
			return 0
		fi
	fi

	# All attempts failed
	echo ""
	return 1
}

# Helper: Save an associative array to a file with base64 encoding
_adapter_registry_save_array_to_file() {
	local array_name="$1"
	local file_path="$2"

	# Get the array reference dynamically
	local -n array_ref="$array_name"

	# Create/truncate file with error checking using touch + verify
	if ! touch "$file_path" 2>&1 || [[ ! -f "$file_path" ]]; then
		echo "ERROR: Failed to create file: $file_path" >&2  # documented: File creation failed
		return 1
	fi

	# Truncate it
	> "$file_path"

	for key in "${!array_ref[@]}"; do
		local encoded_value
		if ! encoded_value=$(_adapter_registry_encode_value "${array_ref[$key]}"); then
			return 1
		fi
		echo "$key=$encoded_value" >> "$file_path"
	done

	return 0
}

# Helper: Load an associative array from a file with base64 decoding
#
# PATTERN: Return-Data Approach
# This function uses the "return-data" pattern to avoid BATS scoping issues with
# namerefs/eval. Instead of modifying the caller's array directly, it returns data
# that the caller can use to populate their array.
#
# When to use return-data pattern:
#   - Function needs to populate caller's array
#   - Function is tested in BATS
#   - Function processes data from files/external sources
#   - You want explicit control over array population
#
# When nameref is acceptable:
#   - Function only reads from arrays (not modifies)
#   - Function modifies global arrays directly
#   - Function is not tested in BATS or tests pass
#   - Performance is critical (nameref is slightly faster)
#
# Returns: first line is count, subsequent lines are key=value pairs (decoded)
# Caller should read first line for count, then process remaining lines to populate array
#
# Usage example:
#   output=$(_adapter_registry_load_array_from_file "array_name" "$file")
#   count=$(echo "$output" | head -n 1)
#   if [[ "$count" -gt 0 ]]; then
#     while IFS='=' read -r key value || [[ -n "$key" ]]; do
#       [[ -z "$key" ]] && continue
#       array["$key"]="$value"
#     done < <(echo "$output" | tail -n +2)
#   fi
_adapter_registry_load_array_from_file() {
	local array_name="$1"
	local file_path="$2"

	if [[ ! -f "$file_path" ]]; then
		echo "0"
		return 0
	fi

	local loaded_count=0
	local line_key
	local line_encoded_value
	local output_lines=""
	
	# Process file and build output
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip empty lines
		[[ -z "$line" ]] && continue

		# Split on first '=' only (since base64 can contain '=')
		line_key="${line%%=*}"
		line_encoded_value="${line#*=}"

		# Skip malformed entries
		if [[ -n "$line_key" ]] && [[ -n "$line_encoded_value" ]]; then
			local decoded_value
			local decode_exit
			decoded_value=$(_adapter_registry_decode_value "$line_encoded_value" 2>/dev/null)
			decode_exit=$?
			if [[ $decode_exit -eq 0 ]] && [[ -n "$decoded_value" ]]; then
				# Buffer the output
				output_lines+="${line_key}=${decoded_value}"$'\n'
				loaded_count=$((loaded_count + 1))
			else
				# documented: Base64 decode failed, skipping corrupted registry entry
				echo "WARNING: Failed to decode base64 value for key '$line_key', skipping entry" >&2
			fi
		fi
	done < "$file_path"

	# Output count first, then data
	echo "$loaded_count"
	echo -n "$output_lines"
	return 0
}

# Helper: Save order array to file
_adapter_registry_save_order() {
	local file_path="$1"

	if ! printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$file_path" 2>&1; then
		echo "ERROR: Failed to write order file: $file_path" >&2  # documented: Order file write failed
		return 1
	fi
	return 0
}

# Helper: Save initialized flag to file
_adapter_registry_save_initialized() {
	local file_path="$1"

	if ! echo "$ADAPTER_REGISTRY_INITIALIZED" > "$file_path" 2>&1; then
		echo "ERROR: Failed to write init file: $file_path" >&2
		return 1
	fi
	return 0
}

# Helper: Determine file locations and update globals
_adapter_registry_determine_file_locations() {
	# If TEST_ADAPTER_REGISTRY_DIR is set, always use it (for test consistency)
	local registry_base_dir
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
		registry_base_dir="$TEST_ADAPTER_REGISTRY_DIR"
	else
		# Re-evaluate REGISTRY_BASE_DIR to use current TEST_ADAPTER_REGISTRY_DIR value
		registry_base_dir="${TMPDIR:-/tmp}"
	fi

	local registry_file="$registry_base_dir/suitey_adapter_registry"
	local capabilities_file="$registry_base_dir/suitey_adapter_capabilities"
	local order_file="$registry_base_dir/suitey_adapter_order"
	local init_file="$registry_base_dir/suitey_adapter_init"

	# Ensure directory exists before trying to read files
	mkdir -p "$registry_base_dir"

	# Check if we're switching locations BEFORE updating globals
	local switching_locations=false
	if [[ -n "${ADAPTER_REGISTRY_FILE:-}" ]] && [[ "$registry_file" != "${ADAPTER_REGISTRY_FILE:-}" ]]; then
		switching_locations=true
	fi

	# Always update global variables when TEST_ADAPTER_REGISTRY_DIR is set,
	# or if registry file exists in the new location, or if globals haven't been set yet
	if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] || \
		[[ -f "$registry_file" ]] || \
		[[ ! -f "${ADAPTER_REGISTRY_FILE:-/nonexistent}" ]]; then
		REGISTRY_BASE_DIR="$registry_base_dir"
		ADAPTER_REGISTRY_FILE="$registry_file"
		ADAPTER_REGISTRY_CAPABILITIES_FILE="$capabilities_file"
		ADAPTER_REGISTRY_ORDER_FILE="$order_file"
		ADAPTER_REGISTRY_INIT_FILE="$init_file"
	fi

	# Return the actual file paths
	echo "$registry_file"
	echo "$capabilities_file"
	echo "$order_file"
	echo "$init_file"
}

# Helper: Determine if state should be reloaded
_adapter_registry_should_reload() {
	local registry_file="$1"
	local capabilities_file="$2"
	local switching_locations="$3"

	# Reload if the registry file exists (to load latest state from disk),
	# or if we're switching to a different file location
	if [[ -f "$registry_file" ]]; then
		# File exists - reload to get latest state
		echo "true"
	elif [[ "$switching_locations" == "true" ]]; then
		# Switching locations - clear to start fresh
		echo "true"
	else
		echo "false"
	fi
}

# Helper: Rebuild capabilities index from loaded adapters
_adapter_registry_rebuild_capabilities() {
	local capabilities_loaded="$1"
	local switching_locations="$2"
	local capabilities_file="$3"

	# Rebuild capabilities index from loaded adapters only if:
	# 1. Capabilities file doesn't exist or is empty (capabilities_loaded is false)
	# 2. We're switching locations (need to rebuild from scratch)
	# 3. The capabilities file exists but is empty
	# This prevents unnecessary rebuilds on every load_state() call, but ensures
	# consistency when files are missing or when switching locations
	if [[ ${#ADAPTER_REGISTRY[@]} -gt 0 ]]; then
		local should_rebuild_capabilities=false

		if [[ "$capabilities_loaded" == "false" ]]; then
			# No capabilities file or file is empty - rebuild from adapters
			should_rebuild_capabilities=true
		elif [[ "$switching_locations" == "true" ]]; then
			# Switching locations - rebuild to ensure consistency
			should_rebuild_capabilities=true
		elif [[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]] && [[ -f "$capabilities_file" ]]; then
			# Capabilities file exists but is empty - rebuild
			should_rebuild_capabilities=true
		fi

		if [[ "$should_rebuild_capabilities" == "true" ]]; then
			# Clear and rebuild from scratch
			ADAPTER_REGISTRY_CAPABILITIES=()
			for adapter_id in "${ADAPTER_REGISTRY_ORDER[@]}"; do
				if [[ -v ADAPTER_REGISTRY["$adapter_id"] ]]; then
					adapter_registry_index_capabilities "$adapter_id" "${ADAPTER_REGISTRY["$adapter_id"]}"
				fi
			done
		fi
	fi
}

# Helper: Parse file paths from helper output
_adapter_registry_parse_file_paths() {
	local file_paths="$1"
	echo "$file_paths" | sed -n '1p'
	echo "$file_paths" | sed -n '2p'
	echo "$file_paths" | sed -n '3p'
	echo "$file_paths" | sed -n '4p'
}

# Helper: Load order array from file with filtering
_adapter_registry_load_order_array() {
	local order_file="$1"
	if [[ -f "$order_file" ]]; then
		mapfile -t ADAPTER_REGISTRY_ORDER < "$order_file"
		# Filter out empty lines and trim spaces (avoid command substitution for BATS compatibility)
		local filtered_array=()
		local element
		for element in "${ADAPTER_REGISTRY_ORDER[@]}"; do
			# Trim leading/trailing spaces
			local trimmed="${element#"${element%%[![:space:]]*}"}"  # Remove leading spaces
			trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"  # Remove trailing spaces
			# Only add non-empty elements
			[[ -n "$trimmed" ]] && filtered_array+=("$trimmed")
		done
		ADAPTER_REGISTRY_ORDER=("${filtered_array[@]}")
	fi
}

# Helper: Perform reload operations
_adapter_registry_perform_reload() {
	local actual_registry_file="$1"
	local actual_capabilities_file="$2"
	local actual_order_file="$3"
	local switching_locations="$4"

	# Clear arrays before loading to ensure clean state from file
	ADAPTER_REGISTRY=()
	# Only clear capabilities if we're going to load from file
	# This prevents losing in-memory state when file doesn't exist
	if [[ -f "$actual_capabilities_file" ]] || [[ "$switching_locations" == "true" ]]; then
		ADAPTER_REGISTRY_CAPABILITIES=()
	fi
	ADAPTER_REGISTRY_ORDER=()

	# Load arrays from files using return-data pattern (manual population for BATS compatibility)
	local registry_output
	registry_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY" "$actual_registry_file")
	local registry_count
	registry_count=$(echo "$registry_output" | head -n 1)
	# Manually populate registry array from output
	if [[ "$registry_count" -gt 0 ]]; then
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			[[ -z "$key" ]] && continue
			ADAPTER_REGISTRY["$key"]="$value"
		done < <(echo "$registry_output" | tail -n +2)
	fi

	local capabilities_loaded=false
	if [[ -f "$actual_capabilities_file" ]]; then
		local capabilities_output
		capabilities_output=$(_adapter_registry_load_array_from_file "ADAPTER_REGISTRY_CAPABILITIES" "$actual_capabilities_file")
		local loaded_count
		loaded_count=$(echo "$capabilities_output" | head -n 1)
		# Manually populate capabilities array from output
		if [[ "$loaded_count" -gt 0 ]]; then
			while IFS='=' read -r key value || [[ -n "$key" ]]; do
				[[ -z "$key" ]] && continue
				ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
			done < <(echo "$capabilities_output" | tail -n +2)
		fi
		[[ "$loaded_count" -gt 0 ]] && capabilities_loaded=true
	fi

	_adapter_registry_load_order_array "$actual_order_file"
	_adapter_registry_rebuild_capabilities "$capabilities_loaded" "$switching_locations" "$actual_capabilities_file"
}
