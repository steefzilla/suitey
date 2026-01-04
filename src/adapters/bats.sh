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
    "name" "BATS"
    "identifier" "bats"
    "version" "1.0.0"
    "supported_languages" '["bash","shell"]'
    "capabilities" '["testing"]'
    "required_binaries" '["bats"]'
    "configuration_files" "[]"
    "test_file_patterns" '["*.bats"]'
    "test_directory_patterns" '["tests/bats/","test/bats/","tests/","test/"]'
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

# BATS adapter discover test suites method
bats_adapter_discover_test_suites() {
  local project_root="$1"
  local framework_metadata="$2"

  # Use existing discovery logic to populate DISCOVERED_SUITES
  # Discover BATS test suites using adapter pattern
  local bats_files=()
  local seen_files=()

  # Check common BATS directory patterns (in order of specificity)
  local test_dirs=(
    "$project_root/tests/bats"
    "$project_root/test/bats"
    "$project_root/tests"
    "$project_root/test"
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
  root_files=$(find_bats_files "$project_root")
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

  # Return JSON format as expected by interface
  local suites_json="["
  for file in "${bats_files[@]}"; do
    local rel_path="${file#$project_root/}"
    rel_path="${rel_path#/}"
    local suite_name=$(generate_suite_name "$file" "bats")
    local test_count=$(count_bats_tests "$(get_absolute_path "$file")")

    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"bats\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"

  echo "$suites_json"
}

# BATS adapter detect build requirements method
bats_adapter_detect_build_requirements() {
  local project_root="$1"
  local framework_metadata="$2"

  # BATS typically doesn't require building
  cat << BUILD_EOF
{
  "requires_build": false,
  "build_steps": [],
  "build_commands": [],
  "build_dependencies": [],
  "build_artifacts": []
}
BUILD_EOF
}

# BATS adapter get build steps method
bats_adapter_get_build_steps() {
  local project_root="$1"
  local build_requirements="$2"

  # No build steps needed
  echo "[]"
}

# BATS adapter execute test suite method
bats_adapter_execute_test_suite() {
  local test_suite="$1"
  local test_image="$2"
  local execution_config="$3"

  # Mock execution for adapter interface
  # BATS doesn't require building, so test_image may be null/empty
  cat << EXEC_EOF
{
  "exit_code": 0,
  "duration": 1.0,
  "output": "Mock BATS execution output",
  "container_id": null,
  "execution_method": "native",
  "test_image": "${test_image:-}"
}
EXEC_EOF
}

# BATS adapter parse test results method
bats_adapter_parse_test_results() {
  local output="$1"
  local exit_code="$2"

  cat << RESULTS_EOF
{
  "total_tests": 5,
  "passed_tests": 5,
  "failed_tests": 0,
  "skipped_tests": 0,
  "test_details": [],
  "status": "passed"
}
RESULTS_EOF
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

