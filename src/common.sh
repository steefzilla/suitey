# ============================================================================
# Common Helper Functions and State
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

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[1;33m'
	BLUE='\033[0;34m'
	NC='\033[0m' # No Color
else
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	NC=''
fi

# Scanner state
DETECTED_FRAMEWORKS=()
DISCOVERED_SUITES=()
SCAN_ERRORS=()

# ============================================================================
# Common Helper Functions
# ============================================================================

# Check if a command binary is available
check_binary() {
	local cmd="$1"
	command -v "$cmd" >/dev/null 2>&1
}

# Normalize a file path to absolute path
normalize_path() {
	local file="$1"
	if command -v readlink >/dev/null 2>&1; then
	readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file"
	elif command -v realpath >/dev/null 2>&1; then
	realpath "$file" 2>/dev/null || echo "$file"
	else
	echo "$file"
	fi
}

# Check if a file is already in the seen_files array
is_file_seen() {
	local file="$1"
	shift
	local seen_files=("$@")
	local normalized_file
	normalized_file=$(normalize_path "$file")

	for seen in "${seen_files[@]}"; do
	if [[ "$seen" == "$normalized_file" ]]; then
	return 0
	fi
	done
	return 1
}

# Generate suite name from file path
generate_suite_name() {
	local file="$1"
	local extension="$2"
	local rel_path="${file#$PROJECT_ROOT/}"
	rel_path="${rel_path#/}"

	local suite_name="${rel_path%.${extension}}"
	suite_name="${suite_name//\//-}"

	if [[ -z "$suite_name" ]]; then
	suite_name=$(basename "$file" ".${extension}")
	fi

	echo "$suite_name"
}

# Get absolute path for a file
get_absolute_path() {
	local file="$1"
	if [[ "$file" != /* ]]; then
	echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
	else
	echo "$file"
	fi
}

# Count test annotations in a file
count_tests_in_file() {
	local file="$1"
	local pattern="$2"
	local count=0

	if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
	echo "0"
	return
	fi

	while IFS= read -r line || [[ -n "$line" ]]; do
	trimmed_line="${line#"${line%%[![:space:]]*}"}"
	if [[ "$trimmed_line" == "$pattern"* ]]; then
	((count++))
	fi
	done < "$file"

	echo "$count"
}

