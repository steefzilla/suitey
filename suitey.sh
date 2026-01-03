#!/bin/bash

set -euo pipefail

# Project Scanner for Suitey
# Implements BATS project detection and test suite discovery

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

# ============================================================================
# Framework Detector
# ============================================================================

# Framework Detection State
DETECTED_FRAMEWORKS_JSON=""
FRAMEWORK_DETAILS_JSON=""
BINARY_STATUS_JSON=""
FRAMEWORK_WARNINGS_JSON=""
FRAMEWORK_ERRORS_JSON=""

# Registered Framework Adapters
FRAMEWORK_ADAPTERS=(
  "bats"
  "rust"
)

# ============================================================================
# Framework Adapter Interface
# ============================================================================

# Adapter Interface Functions:
# - {framework}_adapter_detect(project_root) -> 0 if detected, 1 otherwise
# - {framework}_adapter_get_metadata(project_root) -> JSON metadata string
# - {framework}_adapter_check_binaries() -> 0 if available, 1 otherwise
# - {framework}_adapter_get_confidence(project_root) -> "high"|"medium"|"low"

# Helper function to escape JSON strings
json_escape() {
  local string="$1"
  # Escape backslashes first, then quotes
  string="${string//\\/\\\\}"
  string="${string//\"/\\\"}"
  echo "$string"
}

# Helper function to create JSON array from bash array
json_array() {
  local items=("$@")
  local json_items=()
  for item in "${items[@]}"; do
    json_items+=("\"$(json_escape "$item")\"")
  done
  echo "[$(IFS=','; echo "${json_items[*]}")]"
}

# Helper function to create JSON object from key-value pairs
json_object() {
  local pairs=("$@")
  local json_pairs=()
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    local key="${pairs[i]}"
    local value="${pairs[i+1]}"
    json_pairs+=("\"$(json_escape "$key")\":\"$(json_escape "$value")\"")
  done
  echo "{$(IFS=','; echo "${json_pairs[*]}")}"
}

# ============================================================================
# BATS Framework Adapter
# ============================================================================

# BATS adapter detection function
bats_adapter_detect() {
  local project_root="$1"

  # Check for BATS framework indicators

  # 1. File extension: .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    return 0
  fi

  # 2. Directory patterns with .bats files
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats" "$project_root/tests" "$project_root/test")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      return 0
    fi
  done

  # 3. Check for shebang patterns in any shell scripts
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        return 0
      fi
    fi
  done < <(find "$project_root" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

  return 1
}

# BATS adapter metadata function
bats_adapter_get_metadata() {
  local project_root="$1"

  # Build metadata JSON object
  local metadata_pairs=(
    "name" "bats"
    "binaries" "bats"
    "file_patterns" "*.bats"
    "directory_patterns" "tests/bats/,test/bats/,tests/,test/"
    "config_files" ""
    "version" ""
    "confidence" "$(bats_adapter_get_confidence "$project_root")"
    "detection_method" "$(bats_adapter_get_detection_method "$project_root")"
  )

  json_object "${metadata_pairs[@]}"
}

# BATS adapter binary checking function
bats_adapter_check_binaries() {
  # Allow overriding for testing
  if [[ -n "${SUITEY_MOCK_BATS_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_BATS_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "bats"
}

# BATS adapter confidence calculation
bats_adapter_get_confidence() {
  local project_root="$1"

  local indicators=0
  local has_files=0
  local has_dirs=0
  local has_binary=0

  # Check for .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    ((indicators++))
    has_files=1
  fi

  # Check for directory patterns
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      ((indicators++))
      has_dirs=1
      break
    fi
  done

  # Check for binary availability
  if bats_adapter_check_binaries; then
    ((indicators++))
    has_binary=1
  fi

  # Determine confidence level
  if [[ $indicators -ge 3 ]]; then
    echo "high"
  elif [[ $indicators -ge 1 ]]; then
    echo "medium"
  else
    echo "low"
  fi
}

# BATS adapter detection method
bats_adapter_get_detection_method() {
  local project_root="$1"

  # Check for .bats files
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    echo "file_extension"
    return
  fi

  # Check for directory patterns
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      echo "directory_pattern"
      return
    fi
  done

  # Check for shebang patterns
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        echo "shebang_pattern"
        return
      fi
    fi
  done < <(find "$project_root" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

  echo "unknown"
}

# ============================================================================
# Rust Framework Adapter
# ============================================================================

# Rust adapter detection function
rust_adapter_detect() {
  local project_root="$1"

  # Check for valid Cargo.toml in project root
  if [[ -f "$project_root/Cargo.toml" && -r "$project_root/Cargo.toml" ]] && grep -q '^\[package\]' "$project_root/Cargo.toml" 2>/dev/null; then
    return 0
  fi

  # Also check for Rust test files in src/ and tests/ directories (for framework detection)
  local src_dir="$project_root/src"
  local tests_dir="$project_root/tests"

  # Look for unit test files in src/ (files containing #[cfg(test)] mods)
  if [[ -d "$src_dir" ]]; then
    while IFS= read -r -d '' file; do
      if [[ -f "$file" && -r "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
        return 0
      fi
    done < <(find "$src_dir" -name "*.rs" -type f -print0 2>/dev/null || true)
  fi

  # Look for integration test files in tests/
  if [[ -d "$tests_dir" ]]; then
    if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
      return 0
    fi
  fi

  return 1
}

# Rust adapter metadata function
rust_adapter_get_metadata() {
  local project_root="$1"

  # Build metadata JSON object
  local metadata_pairs=(
    "name" "rust"
    "binaries" "cargo"
    "file_patterns" "*.rs"
    "directory_patterns" "src/,tests/"
    "config_files" "Cargo.toml"
    "version" ""
    "confidence" "$(rust_adapter_get_confidence "$project_root")"
    "detection_method" "$(rust_adapter_get_detection_method "$project_root")"
  )

  json_object "${metadata_pairs[@]}"
}

# Rust adapter binary checking function
rust_adapter_check_binaries() {
  # Allow overriding for testing
  if [[ -n "${SUITEY_MOCK_CARGO_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_CARGO_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "cargo"
}

# Rust adapter confidence calculation
rust_adapter_get_confidence() {
  local project_root="$1"

  local indicators=0
  local has_cargo_toml=0
  local has_unit_tests=0
  local has_integration_tests=0
  local has_binary=0

  # Check for Cargo.toml
  if [[ -f "$project_root/Cargo.toml" ]]; then
    ((indicators++))
    has_cargo_toml=1
  fi

  # Check for unit tests in src/
  local src_dir="$project_root/src"
  if [[ -d "$src_dir" ]]; then
    while IFS= read -r -d '' file; do
      if [[ -f "$file" && -r "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
        ((indicators++))
        has_unit_tests=1
        break
      fi
    done < <(find "$src_dir" -name "*.rs" -type f -print0 2>/dev/null || true)
  fi

  # Check for integration tests in tests/
  local tests_dir="$project_root/tests"
  if [[ -d "$tests_dir" ]]; then
    if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
      ((indicators++))
      has_integration_tests=1
    fi
  fi

  # Check for binary availability
  if rust_adapter_check_binaries; then
    ((indicators++))
    has_binary=1
  fi

  # Determine confidence level
  if [[ $indicators -ge 3 ]]; then
    echo "high"
  elif [[ $indicators -ge 1 ]]; then
    echo "medium"
  else
    echo "low"
  fi
}

# Rust adapter detection method
rust_adapter_get_detection_method() {
  local project_root="$1"

  # Check for Cargo.toml
  if [[ -f "$project_root/Cargo.toml" ]]; then
    echo "cargo_toml"
    return
  fi

  echo "unknown"
}

# ============================================================================
# Framework Detection Core
# ============================================================================

# Core framework detection function
detect_frameworks() {
  local project_root="$1"

  # Initialize result arrays
  local detected_frameworks=()
  local framework_details_json="{}"
  local binary_status_json="{}"
  local warnings_json="[]"
  local errors_json="[]"

  # Iterate through registered adapters
  for adapter in "${FRAMEWORK_ADAPTERS[@]}"; do
    local adapter_detect_func="${adapter}_adapter_detect"
    local adapter_metadata_func="${adapter}_adapter_get_metadata"
    local adapter_binary_func="${adapter}_adapter_check_binaries"

    # Check if adapter detection function exists
    if ! command -v "$adapter_detect_func" >/dev/null 2>&1; then
      continue
    fi

    # Run detection
    if "$adapter_detect_func" "$project_root"; then
      # Framework detected, add to list
      detected_frameworks+=("$adapter")

      # Get framework metadata
      local metadata_json
      metadata_json=$("$adapter_metadata_func" "$project_root")

      # Check binary availability
      local binary_available=false
      if "$adapter_binary_func"; then
        binary_available=true
      fi

      # Add to binary status
      if [[ "$binary_status_json" == "{}" ]]; then
        binary_status_json="{\"$adapter\": \"$binary_available\"}"
      else
        # Remove trailing } and add comma
        binary_status_json="${binary_status_json%\} }, \"$adapter\": \"$binary_available\"}"
      fi

      # Add to framework details
      if [[ "$framework_details_json" == "{}" ]]; then
        framework_details_json="{\"$adapter\": $metadata_json}"
      else
        # Remove trailing } and add comma
        framework_details_json="${framework_details_json%\} }, \"$adapter\": $metadata_json}"
      fi

      # Generate warning if binary is not available
      if [[ "$binary_available" == "false" ]]; then
        local warning_msg="$adapter binary is not available"
        if [[ "$warnings_json" == "[]" ]]; then
          warnings_json="[\"$warning_msg\"]"
        else
          # Remove trailing ] and add comma
          warnings_json="${warnings_json%\] }, \"$warning_msg\"]"
        fi
      fi
    fi
  done

  # Store results in global variables
  DETECTED_FRAMEWORKS_JSON=$(json_array "${detected_frameworks[@]}")
  FRAMEWORK_DETAILS_JSON="$framework_details_json"
  BINARY_STATUS_JSON="$binary_status_json"
  FRAMEWORK_WARNINGS_JSON="$warnings_json"
  FRAMEWORK_ERRORS_JSON="$errors_json"
}

# Output framework detection results as JSON
output_framework_detection_results() {
  # Build the complete JSON output
  local json_output="{"
  json_output="${json_output}\"framework_list\":$DETECTED_FRAMEWORKS_JSON,"
  json_output="${json_output}\"framework_details\":$FRAMEWORK_DETAILS_JSON,"
  json_output="${json_output}\"binary_status\":$BINARY_STATUS_JSON,"
  json_output="${json_output}\"warnings\":$FRAMEWORK_WARNINGS_JSON,"
  json_output="${json_output}\"errors\":$FRAMEWORK_ERRORS_JSON"
  json_output="${json_output}}"

  echo "$json_output"
}

# ============================================================================
# BATS Detection Functions
# ============================================================================

# Check if a file is a BATS test file
is_bats_file() {
  local file="$1"
  
  # Check file extension
  if [[ "$file" == *.bats ]]; then
    return 0
  fi
  
  # Check shebang if file exists and is readable
  if [[ -f "$file" && -r "$file" ]]; then
    local first_line
    first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
    if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
      return 0
    fi
  fi
  
  return 1
}

# Count the number of @test annotations in a BATS file
count_bats_tests() {
  local file="$1"
  count_tests_in_file "$file" "@test"
}

# Find all .bats files in a directory (recursively)
find_bats_files() {
  local dir="$1"
  local files=()
  
  if [[ ! -d "$dir" ]]; then
    return 1
  fi
  
  while IFS= read -r -d '' file; do
    if is_bats_file "$file"; then
      files+=("$file")
    fi
  done < <(find "$dir" -type f -name "*.bats" -print0 2>/dev/null || true)
  
  printf '%s\n' "${files[@]}"
}

# Discover BATS test suites
discover_bats_suites() {
  local bats_files=()
  local seen_files=()
  
  # Check common BATS directory patterns (in order of specificity)
  local test_dirs=(
    "$PROJECT_ROOT/tests/bats"
    "$PROJECT_ROOT/test/bats"
    "$PROJECT_ROOT/tests"
    "$PROJECT_ROOT/test"
  )
  
  # Scan for .bats files in common directories
  for dir in "${test_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local found_files
      found_files=$(find_bats_files "$dir")
      if [[ -n "$found_files" ]]; then
        while IFS= read -r file; do
          if [[ -n "$file" ]] && ! is_file_seen "$file" "${seen_files[@]}"; then
            bats_files+=("$file")
            seen_files+=("$(normalize_path "$file")")
          fi
        done <<< "$found_files"
      fi
    fi
  done
  
  # Also scan project root for .bats files (but exclude files already found in test dirs)
  local root_files
  root_files=$(find_bats_files "$PROJECT_ROOT")
  if [[ -n "$root_files" ]]; then
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        # Skip if file is in a test directory we already scanned
        local skip=0
        for test_dir in "${test_dirs[@]}"; do
          if [[ "$file" == "$test_dir"/* ]]; then
            skip=1
            break
          fi
        done
        
        if [[ $skip -eq 0 ]] && ! is_file_seen "$file" "${seen_files[@]}"; then
          bats_files+=("$file")
          seen_files+=("$(normalize_path "$file")")
        fi
      fi
    done <<< "$root_files"
  fi
  
  # Create test suite entries for each .bats file
  for file in "${bats_files[@]}"; do
    local rel_path="${file#$PROJECT_ROOT/}"
    rel_path="${rel_path#/}"
    local suite_name
    local test_count
    
    suite_name=$(generate_suite_name "$file" "bats")
    test_count=$(count_bats_tests "$(get_absolute_path "$file")")
    
    # Add suite metadata (format: framework|suite_name|file_path|rel_path|test_count)
    DISCOVERED_SUITES+=("bats|$suite_name|$file|$rel_path|$test_count")
  done
}

# ============================================================================
# Rust Detection Functions
# ============================================================================

# Check if a file is a Rust source file
is_rust_file() {
  local file="$1"

  # Check file extension
  if [[ "$file" == *.rs ]]; then
    return 0
  fi

  return 1
}

# Count the number of #[test] annotations in a Rust file
count_rust_tests() {
  local file="$1"
  count_tests_in_file "$file" "#[test]"
}

# Find all Rust test files in a directory
find_rust_test_files() {
  local dir="$1"
  local files=()

  if [[ ! -d "$dir" ]]; then
    return 1
  fi

  # Use find to locate all .rs files
  while IFS= read -r -d '' file; do
    if is_rust_file "$file"; then
      files+=("$file")
    fi
  done < <(find "$dir" -type f -name "*.rs" -print0 2>/dev/null || true)

  printf '%s\n' "${files[@]}"
}

# Discover Rust test suites
discover_rust_suites() {
  # Only discover Rust test suites if Cargo.toml exists
  if [[ ! -f "$PROJECT_ROOT/Cargo.toml" ]]; then
    return
  fi

  local src_dir="$PROJECT_ROOT/src"
  local tests_dir="$PROJECT_ROOT/tests"
  local rust_files=()

  # Discover unit tests in src/ directory
  if [[ -d "$src_dir" ]]; then
    local src_files
    src_files=$(find_rust_test_files "$src_dir")
    if [[ -n "$src_files" ]]; then
      while IFS= read -r file; do
        if [[ -n "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
          rust_files+=("$file")
        fi
      done <<< "$src_files"
    fi
  fi

  # Discover integration tests in tests/ directory
  if [[ -d "$tests_dir" ]]; then
    local integration_files
    integration_files=$(find_rust_test_files "$tests_dir")
    if [[ -n "$integration_files" ]]; then
      while IFS= read -r file; do
        [[ -n "$file" ]] && rust_files+=("$file")
      done <<< "$integration_files"
    fi
  fi

  # Create test suite entries for each Rust test file
  for file in "${rust_files[@]}"; do
    local rel_path="${file#$PROJECT_ROOT/}"
    rel_path="${rel_path#/}"
    local suite_name
    local test_count

    suite_name=$(generate_suite_name "$file" "rs")
    test_count=$(count_rust_tests "$(get_absolute_path "$file")")

    # Add suite metadata (format: framework|suite_name|file_path|rel_path|test_count)
    DISCOVERED_SUITES+=("rust|$suite_name|$file|$rel_path|$test_count")
  done
}

# ============================================================================
# Main Scanner Functions
# ============================================================================

# Scan project for test frameworks and suites
scan_project() {
  echo "Scanning project: $PROJECT_ROOT" >&2
  echo "" >&2

  # Use Framework Detector to detect frameworks
  detect_frameworks "$PROJECT_ROOT"

  # Parse detected frameworks from JSON and discover suites
  # Extract framework list from JSON (simple parsing for backward compatibility)
  local detected_list="$DETECTED_FRAMEWORKS_JSON"
  local frameworks=()
  if [[ "$detected_list" != "[]" ]]; then
    # Remove brackets and split by comma using sed
    detected_list=$(echo "$detected_list" | sed 's/^\[//' | sed 's/\]$//')
    # Split by comma and remove quotes
    IFS=',' read -ra frameworks <<< "$detected_list"
    for i in "${!frameworks[@]}"; do
      frameworks[i]=$(echo "${frameworks[i]}" | sed 's/^"//' | sed 's/"$//')
    done
  fi

  for framework in "${frameworks[@]}"; do
    case "$framework" in
      "bats")
        echo -e "${GREEN}✓${NC} BATS framework detected" >&2
        DETECTED_FRAMEWORKS+=("bats")
        discover_bats_suites
        ;;
      "rust")
        echo -e "${GREEN}✓${NC} Rust framework detected" >&2
        DETECTED_FRAMEWORKS+=("rust")
        discover_rust_suites
        ;;
      *)
        # Unknown framework detected - skip for backward compatibility
        ;;
    esac
  done

  # Check if any frameworks were detected
  local framework_count="${#frameworks[@]}"
  if [[ $framework_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
  fi

  echo "" >&2
}

# Output scan results
output_results() {
  # Output detected frameworks
  if [[ ${#DETECTED_FRAMEWORKS[@]} -eq 0 ]]; then
    echo -e "${RED}✗${NC} No test frameworks detected" >&2
    echo "" >&2
    echo "No test suites found in this project." >&2
    echo "" >&2
    echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
    echo "" >&2
    echo "To use Suitey, ensure your project has:" >&2
    echo "  - Test files with .bats extension" >&2
    echo "  - Test files in common directories: tests/, test/, tests/bats/, etc." >&2
    echo "  - Rust projects with Cargo.toml and test files in src/ or tests/ directories" >&2
    exit 2
  fi
  
  # Output discovered test suites
  if [[ ${#DISCOVERED_SUITES[@]} -eq 0 ]]; then
    echo -e "${RED}✗${NC} No test suites found" >&2
    echo "" >&2
    
    if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
      echo "Errors:" >&2
      for error in "${SCAN_ERRORS[@]}"; do
        echo -e "  ${RED}•${NC} $error" >&2
      done
      echo "" >&2
    fi
    
    echo "No test suites were discovered in this project." >&2
    echo "" >&2
    echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
    exit 2
  fi
  
  # Output scan summary
  echo -e "${GREEN}✓${NC} Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
  local suite_count=${#DISCOVERED_SUITES[@]}
  echo -e "${GREEN}✓${NC} Discovered $suite_count test suite" >&2
  echo "" >&2
  
  # Output errors if any
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Warnings:" >&2
    for error in "${SCAN_ERRORS[@]}"; do
      echo -e "  ${YELLOW}•${NC} $error" >&2
    done
    echo "" >&2
  fi
  
  # Output discovered test suites
  echo "Test Suites:" >&2
  for suite in "${DISCOVERED_SUITES[@]}"; do
    IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
    echo -e "  ${BLUE}•${NC} $suite_name - $framework" >&2
    echo "    Path: $rel_path" >&2
    echo "    Tests: $test_count" >&2
  done
  echo "" >&2
}

# ============================================================================
# Help Text
# ============================================================================

show_help() {
  cat << 'EOF'
Suitey Project Scanner

Scans PROJECT_ROOT to detect test frameworks (BATS, Rust) and discover
test suites. Outputs structured information about detected frameworks and
discovered test suites.

USAGE:
    suitey.sh [OPTIONS] PROJECT_ROOT

OPTIONS:
    -h, --help      Show this help message and exit.
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
  # Check for subcommands
  if [[ $# -gt 0 ]] && [[ "$1" == "detect-frameworks" ]]; then
    shift
    # Process PROJECT_ROOT argument (first non-flag argument)
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          show_help
          exit 0
          ;;
        -*)
          # Unknown option
          echo "Error: Unknown option: $arg" >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
          ;;
        *)
          # First non-flag argument is PROJECT_ROOT
          if [[ -z "$project_root_arg" ]]; then
            project_root_arg="$arg"
          else
            echo "Error: Multiple project root arguments specified." >&2
            echo "Run 'suitey.sh --help' for usage information." >&2
            exit 2
          fi
          ;;
      esac
    done

    # If no PROJECT_ROOT argument provided, use current directory
    if [[ -z "$project_root_arg" ]]; then
      project_root_arg="."
    fi

    # Set PROJECT_ROOT and run framework detection
    PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"
    detect_frameworks "$PROJECT_ROOT"
    output_framework_detection_results
    exit 0
  fi

  # Check for help flags
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        show_help
        exit 0
        ;;
    esac
  done

  # Process PROJECT_ROOT argument (first non-flag argument)
  local project_root_arg=""
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        # Already handled above
        ;;
      -*)
        # Unknown option
        echo "Error: Unknown option: $arg" >&2
        echo "Run 'suitey.sh --help' for usage information." >&2
        exit 2
        ;;
      *)
        # First non-flag argument is PROJECT_ROOT
        if [[ -z "$project_root_arg" ]]; then
          project_root_arg="$arg"
        else
          echo "Error: Multiple project root arguments specified." >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
        fi
        ;;
    esac
  done

  # If no PROJECT_ROOT argument provided, show help
  if [[ -z "$project_root_arg" ]]; then
    show_help
    exit 0
  fi

  # Set PROJECT_ROOT
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"

  scan_project
  output_results
}

# Run main function
main "$@"