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
# BATS Detection Functions
# ============================================================================

# Check if bats binary is available
check_bats_binary() {
  check_binary "bats"
}

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

# Detect BATS framework in project
detect_bats_framework() {
  local bats_files=()
  local bats_dirs=()
  
  # Check common BATS directory patterns
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
          [[ -n "$file" ]] && bats_files+=("$file")
        done <<< "$found_files"
        bats_dirs+=("$dir")
      fi
    fi
  done
  
  # Also scan project root for .bats files
  local root_files
  root_files=$(find_bats_files "$PROJECT_ROOT")
  if [[ -n "$root_files" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && bats_files+=("$file")
    done <<< "$root_files"
  fi
  
  # If we found .bats files, BATS framework is detected
  if [[ ${#bats_files[@]} -gt 0 ]]; then
    DETECTED_FRAMEWORKS+=("bats")
    
    # Check if bats binary is available
    if ! check_bats_binary; then
      SCAN_ERRORS+=("BATS framework detected but 'bats' binary is not available. Install BATS to run tests.")
    fi
    
    return 0
  fi
  
  return 1
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

# Check if cargo binary is available
check_cargo_binary() {
  check_binary "cargo"
}

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

# Detect Rust framework in project
detect_rust_framework() {
  # Check for Cargo.toml in project root
  if [[ ! -f "$PROJECT_ROOT/Cargo.toml" ]]; then
    return 1
  fi

  # Check for Rust test files in src/ and tests/ directories
  local src_dir="$PROJECT_ROOT/src"
  local tests_dir="$PROJECT_ROOT/tests"

  # Look for unit test files in src/ (files containing #[cfg(test)] mods)
  local has_unit_tests=false
  if [[ -d "$src_dir" ]]; then
    local src_files
    src_files=$(find_rust_test_files "$src_dir")
    if [[ -n "$src_files" ]]; then
      while IFS= read -r file; do
        if [[ -n "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
          has_unit_tests=true
          break
        fi
      done <<< "$src_files"
    fi
  fi

  # Look for integration test files in tests/
  local has_integration_tests=false
  if [[ -d "$tests_dir" ]]; then
    local integration_files
    integration_files=$(find_rust_test_files "$tests_dir")
    if [[ -n "$integration_files" ]]; then
      has_integration_tests=true
    fi
  fi

  # If we found Rust test files, Rust framework is detected
  if [[ "$has_unit_tests" == true ]] || [[ "$has_integration_tests" == true ]]; then
    DETECTED_FRAMEWORKS+=("rust")

    # Check if cargo binary is available
    if ! check_cargo_binary; then
      SCAN_ERRORS+=("Rust framework detected but 'cargo' binary is not available. Install Rust to run tests.")
    fi

    return 0
  fi

  return 1
}

# Discover Rust test suites
discover_rust_suites() {
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

  # Detect BATS framework
  if detect_bats_framework; then
    echo -e "${GREEN}✓${NC} BATS framework detected" >&2
    discover_bats_suites
  else
    echo -e "${YELLOW}⚠${NC} No BATS framework detected" >&2
  fi

  # Detect Rust framework
  if detect_rust_framework; then
    echo -e "${GREEN}✓${NC} Rust framework detected" >&2
    discover_rust_suites
  else
    echo -e "${YELLOW}⚠${NC} No Rust framework detected" >&2
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
    echo "To use Suitey, ensure your project has:" >&2
    echo "  - Test files with .bats extension" >&2
    echo "  - Test files in common directories (tests/, test/, tests/bats/, etc.)" >&2
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
  echo -e "${GREEN}✓${NC} Discovered ${#DISCOVERED_SUITES[@]} test suite(s)" >&2
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
    echo -e "  ${BLUE}•${NC} $suite_name ($framework)" >&2
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