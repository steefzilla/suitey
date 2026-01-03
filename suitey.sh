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

# Project root directory (default to current directory)
PROJECT_ROOT="${1:-$(pwd)}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# Scanner state
DETECTED_FRAMEWORKS=()
DISCOVERED_SUITES=()
SCAN_ERRORS=()

# ============================================================================
# BATS Detection Functions
# ============================================================================

# Check if bats binary is available
check_bats_binary() {
  if command -v bats >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
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
  local count=0
  
  # Verify file exists and is readable
  if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
    echo "0"
    return
  fi
  
  # Count lines that start with @test (allowing for whitespace)
  # Read file directly line by line - most reliable method across all environments
  count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove leading whitespace and check if line starts with @test
    trimmed_line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed_line" == @test* ]]; then
      ((count++))
    fi
  done < "$file"
  
  echo "$count"
}

# Find all .bats files in a directory (recursively)
find_bats_files() {
  local dir="$1"
  local files=()
  
  if [[ ! -d "$dir" ]]; then
    return 1
  fi
  
  # Use find to locate all .bats files
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
  # Use a more specific approach: only scan each directory once, and avoid duplicates
  for dir in "${test_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local found_files
      found_files=$(find_bats_files "$dir")
      if [[ -n "$found_files" ]]; then
        while IFS= read -r file; do
          if [[ -n "$file" ]]; then
            # Check if we've already seen this file (normalize path)
            local normalized_file
            # Try to get absolute path, fallback to original if not available
            if command -v readlink >/dev/null 2>&1; then
              normalized_file=$(readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file")
            elif command -v realpath >/dev/null 2>&1; then
              normalized_file=$(realpath "$file" 2>/dev/null || echo "$file")
            else
              normalized_file="$file"
            fi
            local is_duplicate=0
            for seen in "${seen_files[@]}"; do
              if [[ "$seen" == "$normalized_file" ]]; then
                is_duplicate=1
                break
              fi
            done
            
            if [[ $is_duplicate -eq 0 ]]; then
              bats_files+=("$file")
              seen_files+=("$normalized_file")
            fi
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
        
        if [[ $skip -eq 0 ]]; then
          local normalized_file
          # Try to get absolute path, fallback to original if not available
          if command -v readlink >/dev/null 2>&1; then
            normalized_file=$(readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file")
          elif command -v realpath >/dev/null 2>&1; then
            normalized_file=$(realpath "$file" 2>/dev/null || echo "$file")
          else
            normalized_file="$file"
          fi
          local is_duplicate=0
          for seen in "${seen_files[@]}"; do
            if [[ "$seen" == "$normalized_file" ]]; then
              is_duplicate=1
              break
            fi
          done
          
          if [[ $is_duplicate -eq 0 ]]; then
            bats_files+=("$file")
            seen_files+=("$normalized_file")
          fi
        fi
      fi
    done <<< "$root_files"
  fi
  
  # Create test suite entries for each .bats file
  for file in "${bats_files[@]}"; do
    local rel_path="${file#$PROJECT_ROOT/}"
    # Ensure rel_path doesn't start with /
    rel_path="${rel_path#/}"
    local suite_name
    local test_count
    
    # Generate suite name from file path
    # Remove .bats extension and replace / with -
    suite_name="${rel_path%.bats}"
    suite_name="${suite_name//\//-}"
    
    # If suite name is empty, use filename
    if [[ -z "$suite_name" ]]; then
      suite_name=$(basename "$file" .bats)
    fi
    
    # Count tests in this BATS file
    # Ensure we have an absolute path for reliable file access
    local abs_file="$file"
    if [[ "$abs_file" != /* ]]; then
      abs_file="$(cd "$(dirname "$abs_file")" && pwd)/$(basename "$abs_file")"
    fi
    test_count=$(count_bats_tests "$abs_file")
    
    # Add suite metadata (format: framework|suite_name|file_path|rel_path|test_count)
    DISCOVERED_SUITES+=("bats|$suite_name|$file|$rel_path|$test_count")
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
# Main Entry Point
# ============================================================================

main() {
  scan_project
  output_results
}

# Run main function
main "$@"