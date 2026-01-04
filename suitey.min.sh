#!/bin/bash
set -euo pipefail
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
bq=()
bs=()
by=()
y() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
Q() {
  local file="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file"
  elif command -v realpath >/dev/null 2>&1; then
    realpath "$file" 2>/dev/null || echo "$file"
  else
    echo "$file"
  fi
}
K() {
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
H() {
  local file="$1"
  local extension="$2"
  local rel_path="${file#$PROJECT_ROOT/}"
  rel_path="${rel_path#/}"
  local suite_bL="${rel_path%.${extension}}"
  suite_bL="${suite_name//\//-}"
  if [[ -z "$suite_name" ]]; then
    suite_bL=$(basename "$file" ".${extension}")
  fi
  echo "$suite_name"
}
I() {
  local file="$1"
  if [[ "$file" != /* ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}
B() {
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
declare -A ADAPTER_REGISTRY
declare -A ADAPTER_REGISTRY_CAPABILITIES
bm=false
bn=()
bx="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
bk="$bx/suitey_adapter_registry"
bj="$bx/suitey_adapter_capabilities"
bo="$bx/suitey_adapter_order"
bl="$bx/suitey_adapter_init"
l() {
  mkdir -p "$(dirname "$bk")"
  > "$bk"
  for key in "${!ADAPTER_REGISTRY[@]}"; do
    echo "$key=${ADAPTER_REGISTRY[$key]}" >> "$bk"
  done
  > "$bj"
  for key in "${!ADAPTER_REGISTRY_CAPABILITIES[@]}"; do
    echo "$key=${ADAPTER_REGISTRY_CAPABILITIES[$key]}" >> "$bj"
  done
  > "$bn_FILE"
  printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$bn_FILE"
  echo "$bm" > "$bh_INIT_FILE"
}
j() {
  if [[ -f "$bk" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY["$key"]="$value"
    done < "$bk"
  fi
  if [[ -f "$bj" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
    done < "$bj"
  fi
  if [[ -f "$bn_FILE" ]]; then
    mapfile -t ADAPTER_REGISTRY_ORDER < "$bn_FILE"
  fi
  if [[ -f "$bh_INIT_FILE" ]]; then
    bm=$(<"$bh_INIT_FILE")
  fi
}
b() {
  rm -f "$bk" "$bj" "$bn_FILE" "$bh_INIT_FILE"
}
m() {
  j
  local adapter_identifier="$1"
  local required_methods=(
    "${adapter_identifier}_adapter_detect"
    "${adapter_identifier}_adapter_get_metadata"
    "${adapter_identifier}_adapter_check_binaries"
    "${adapter_identifier}_adapter_discover_test_suites"
    "${adapter_identifier}_adapter_detect_build_requirements"
    "${adapter_identifier}_adapter_get_build_steps"
    "${adapter_identifier}_adapter_execute_test_suite"
    "${adapter_identifier}_adapter_parse_test_results"
  )
  for method in "${required_methods[@]}"; do
    if ! command -v "$method" >/dev/null 2>&1; then
      echo "ERROR: Adapter '$adapter_identifier' is missing required interface method: $method" >&2
      return 1
    fi
  done
  return 0
}
c() {
  local adapter_identifier="$1"
  local metadata_func="${adapter_identifier}_adapter_get_metadata"
  if "$metadata_func" ""; then
    return 0
  else
    echo "ERROR: Failed to extract metadata from adapter '$adapter_identifier'" >&2
    return 1
  fi
}
n() {
  local adapter_identifier="$1"
  local metadata_json="$2"
  local required_fields=("name" "identifier" "version" "supported_languages" "capabilities" "required_binaries" "configuration_files")
  for field in "${required_fields[@]}"; do
    if ! echo "$metadata_json" | grep -q "\"$field\""; then
      echo "ERROR: Adapter '$adapter_identifier' metadata is missing required field: $field" >&2
      return 1
    fi
  done
  if ! echo "$metadata_json" | grep -q "\"identifier\"[[:space:]]*:[[:space:]]*\"$adapter_identifier\""; then
    echo "ERROR: Adapter '$adapter_identifier' metadata identifier does not match adapter identifier" >&2
    return 1
  fi
  return 0
}
g() {
  local adapter_identifier="$1"
  local metadata_json="$2"
  local capabilities_part
  capabilities_part=$(echo "$metadata_json" | grep -o '"capabilities"[[:space:]]*:[[:space:]]*\[[^]]*\]' || echo "")
  if [[ -n "$capabilities_part" ]]; then
    local capabilities
    capabilities=$(echo "$capabilities_part" | grep -o '"[^"]*"' | sed 's/"//g' | tr '\n' ',' | sed 's/,$//')
    IFS=',' read -ra cap_array <<< "$capabilities"
    for cap in "${cap_array[@]}"; do
      if [[ -n "$cap" ]]; then
        if [[ ! -v ADAPTER_REGISTRY_CAPABILITIES["$cap"] ]]; then
          ADAPTER_REGISTRY_CAPABILITIES["$cap"]="$adapter_identifier"
        else
          ADAPTER_REGISTRY_CAPABILITIES["$cap"]="${ADAPTER_REGISTRY_CAPABILITIES["$cap"]},$adapter_identifier"
        fi
      fi
    done
  fi
}
k() {
  local adapter_identifier="$1"
  j
  if [[ -z "$adapter_identifier" ]]; then
    echo "ERROR: Cannot register adapter with null or empty identifier" >&2
    return 1
  fi
  if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
    echo "ERROR: Adapter identifier '$adapter_identifier' is already registered" >&2
    return 1
  fi
  if ! adapter_registry_validate_interface "$adapter_identifier"; then
    return 1
  fi
  local metadata_json
  metadata_json=$(adapter_registry_extract_metadata "$adapter_identifier")
  if [[ $? -ne 0 ]] || [[ -z "$metadata_json" ]]; then
    return 1
  fi
  if ! adapter_registry_validate_metadata "$adapter_identifier" "$metadata_json"; then
    return 1
  fi
  ADAPTER_REGISTRY["$adapter_identifier"]="$metadata_json"
  adapter_registry_index_capabilities "$adapter_identifier" "$metadata_json"
  ADAPTER_REGISTRY_ORDER+=("$adapter_identifier")
  l
  return 0
}
d() {
  local adapter_identifier="$1"
  j
  if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
    echo "${ADAPTER_REGISTRY["$adapter_identifier"]}"
  else
    echo "null"
  fi
}
f() {
  j
  local identifiers=()
  for identifier in "${ADAPTER_REGISTRY_ORDER[@]}"; do
    identifiers+=("\"$identifier\"")
  done
  local joined
  joined=$(IFS=','; echo "${identifiers[*]}")
  echo "[$joined]"
}
e() {
  j
  local capability="$1"
  if [[ -v ADAPTER_REGISTRY_CAPABILITIES["$capability"] ]]; then
    local adapters="${ADAPTER_REGISTRY_CAPABILITIES["$capability"]}"
    local identifiers=()
    IFS=',' read -ra adapter_array <<< "$adapters"
    for adapter in "${adapter_array[@]}"; do
      identifiers+=("\"$adapter\"")
    done
    local joined
    joined=$(IFS=','; echo "${identifiers[*]}")
    echo "[$joined]"
  else
    echo "[]"
  fi
}
i() {
  j
  if [[ -v ADAPTER_REGISTRY["$adapter_identifier"] ]]; then
    echo "true"
  else
    echo "false"
  fi
}
h() {
  j
  if [[ "$bm" == "true" ]]; then
    return 0
  fi
  local builtin_adapters=("bats" "rust")
  for adapter in "${builtin_adapters[@]}"; do
    if ! adapter_registry_register "$adapter"; then
      echo "ERROR: Failed to register built-in adapter '$adapter'" >&2
      return 1
    fi
  done
  bm=true
  l
  return 0
}
a() {
  bh=()
  bi=()
  bn=()
  bm=false
  b
  return 0
}
br=""
bu=""
bp=""
bw=""
bv=""
bt=(
  "bats"
  "rust"
)
N() {
  local string="$1"
  string="${string//\\/\\\\}"
  string="${string//\"/\\\"}"
  echo "$string"
}
M() {
  local items=("$@")
  local json_items=()
  for item in "${items[@]}"; do
    json_items+=("\"$(json_escape "$item")\"")
  done
  echo "[$(IFS=','; echo "${json_items[*]}")]"
}
O() {
  local pairs=("$@")
  local json_pairs=()
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    local key="${pairs[i]}"
    local value="${pairs[i+1]}"
    json_pairs+=("\"$(json_escape "$key")\":\"$(json_escape "$value")\"")
  done
  echo "{$(IFS=','; echo "${json_pairs[*]}")}"
}
T() {
  local M="$1"
  local framework="$2"
  local project_root="$3"
  if [[ -z "$M" || "$M" == "[]" ]]; then
    return 0
  fi
  if [[ "$M" != \[*\] ]]; then
    echo "ERROR: Invalid JSON format for $framework - not a valid array" >&2
    return 1
  fi
  local json_content="${json_array#[}"
  json_content="${json_content%]}"
  if [[ -z "$json_content" ]]; then
    return 0
  fi
  local suite_objects
  if [[ "$json_content" == *"},{"* ]]; then
    suite_objects=()
    while IFS= read -r line; do
      suite_objects+=("$line")
    done < <(echo "$json_content" | sed 's/},{/}\n{/g')
  else
    suite_objects=("$json_content")
  fi
  for suite_obj in "${suite_objects[@]}"; do
    suite_obj="${suite_obj#\{}"
    suite_obj="${suite_obj%\}}"
    if [[ -z "$suite_obj" ]]; then
      continue
    fi
    local suite_bL=""
    suite_bL=$(echo "$suite_obj" | grep -o '"name"[^,]*' | sed 's/"bL"://' | sed 's/"//g' | head -1)
    if [[ -z "$suite_name" ]]; then
      echo "WARNING: Could not parse suite name from $framework JSON object" >&2
      continue
    fi
    local test_files_part=""
    test_files_part=$(echo "$suite_obj" | grep -o '"test_files"[^]]*]' | sed 's/"bT"://' | head -1)
    if [[ -z "$bT_part" ]]; then
      echo "WARNING: Could not parse test_files from $framework suite '$suite_name'" >&2
      continue
    fi
    test_files_part="${test_files_part#[}"
    test_files_part="${test_files_part%]}"
    local bT=()
    if [[ -n "$bT_part" ]]; then
      IFS=',' read -ra test_files <<< "$bT_part"
      for i in "${!test_files[@]}"; do
        test_files[i]="${test_files[i]#\"}"
        test_files[i]="${test_files[i]%\"}"
        test_files[i]="${test_files[i]//[[:space:]]/}"
      done
    fi
    if [[ ${#test_files[@]} -eq 0 ]]; then
      echo "WARNING: No test files found in $framework suite '$suite_name'" >&2
      continue
    fi
    local total_test_count=0
    for test_file in "${test_files[@]}"; do
      if [[ -n "$test_file" ]]; then
        local abs_path="$project_root/$test_file"
        local file_test_count=0
        case "$framework" in
          "bats")
            file_test_count=$(count_bats_tests "$abs_path")
            ;;
          "rust")
            file_test_count=$(count_rust_tests "$abs_path")
            ;;
          *)
            file_test_count=0
            ;;
        esac
        total_test_count=$((total_test_count + file_test_count))
      fi
    done
    local first_test_file="${test_files[0]}"
    local abs_file_path="$project_root/$first_test_file"
    echo "$framework|$suite_name|$abs_file_path|$first_test_file|$total_test_count"
  done
}
D() {
  local project_root="$1"
  local detected_frameworks=()
  local framework_details_json="{}"
  local binary_status_json="{}"
  local warnings_json="[]"
  local errors_json="[]"
  echo "using adapter registry" >&2
  local adapters_json
  adapters_json=$(adapter_registry_get_all)
  local adapters=()
  if [[ "$adapters_json" != "[]" ]]; then
    adapters_json=$(echo "$adapters_json" | sed 's/^\[//' | sed 's/\]$//' | sed 's/"//g')
    IFS=',' read -ra adapters <<< "$adapters_json"
  fi
  if [[ ${#adapters[@]} -eq 0 ]]; then
    echo "no adapters" >&2
  fi
  for adapter in "${adapters[@]}"; do
    local adapter_detect_func="${adapter}_adapter_detect"
    local adapter_metadata_func="${adapter}_adapter_get_metadata"
    local adapter_binary_func="${adapter}_adapter_check_binaries"
    if ! command -v "$adapter_detect_func" >/dev/null 2>&1; then
      continue
    fi
    echo "detected $adapter" >&2
    if [[ "$adapter" == "bats" ]] || [[ "$adapter" == "rust" ]]; then
      echo "registry $adapter" >&2
    fi
    if "$adapter_detect_func" "$project_root"; then
      detected_frameworks+=("$adapter")
      echo "processed $adapter" >&2
      local metadata_json
      metadata_json=$("$adapter_metadata_func" "$project_root")
      echo "check_binaries $adapter" >&2
      local binary_available=false
      if "$adapter_binary_func"; then
        binary_available=true
      fi
      if [[ "$binary_status_json" == "{}" ]]; then
        binary_status_json="{\"$adapter\": \"$binary_available\"}"
      else
        binary_status_json="${binary_status_json%\}}, \"$adapter\": \"$binary_available\"}"
      fi
      if [[ "$framework_details_json" == "{}" ]]; then
        framework_details_json="{\"$adapter\": $metadata_json}"
      else
        framework_details_json="${framework_details_json%\}}, \"$adapter\": $metadata_json}"
      fi
      if [[ "$binary_available" == "false" ]]; then
        local warning_msg="$adapter binary is not available"
        if [[ "$warnings_json" == "[]" ]]; then
          warnings_json="[\"$warning_msg\"]"
        else
          warnings_json="${warnings_json%\]}, \"$warning_msg\"]"
        fi
      fi
    else
      echo "skipped $adapter" >&2
    fi
  done
  br=$(json_array "${detected_frameworks[@]}")
  bu="$framework_details_json"
  bp="$binary_status_json"
  bw="$warnings_json"
  bv="$errors_json"
  echo "orchestrated framework detector" >&2
  echo "detection phase completed" >&2
}
R() {
  local json_bM="{"
  json_bM="${json_output}\"framework_list\":$bq_JSON,"
  json_bM="${json_output}\"framework_details\":$bu,"
  json_bM="${json_output}\"binary_status\":$bp,"
  json_bM="${json_output}\"warnings\":$bw,"
  json_bM="${json_output}\"errors\":$bv"
  json_bM="${json_output}}"
  echo "$json_output"
}
p() {
  local project_root="$1"
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    return 0
  fi
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats" "$project_root/tests" "$project_root/test")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      return 0
    fi
  done
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        return 0
      fi
    fi
  done < <(find "$project_root" -type f \(-name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)
  return 1
}
w() {
  local project_root="$1"
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
o() {
  if [[ -n "${SUITEY_MOCK_BATS_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_BATS_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "bats"
}
u() {
  local project_root="$1"
  local indicators=0
  local has_files=0
  local has_dirs=0
  local has_binary=0
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    ((indicators++))
    has_files=1
  fi
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      ((indicators++))
      has_dirs=1
      break
    fi
  done
  if bats_adapter_check_binaries; then
    ((indicators++))
    has_binary=1
  fi
  if [[ $indicators -ge 3 ]]; then
    echo "high"
  elif [[ $indicators -ge 1 ]]; then
    echo "medium"
  else
    echo "low"
  fi
}
v() {
  local project_root="$1"
  if find "$project_root" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
    echo "file_extension"
    return
  fi
  local bats_dirs=("$project_root/tests/bats" "$project_root/test/bats")
  for dir in "${bats_dirs[@]}"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*.bats" -type f 2>/dev/null | head -1 | read -r; then
      echo "directory_pattern"
      return
    fi
  done
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -r "$file" ]]; then
      local first_line
      first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
      if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
        echo "shebang_pattern"
        return
      fi
    fi
  done < <(find "$project_root" -type f \(-name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)
  echo "unknown"
}
r() {
  local project_root="$1"
  local framework_metadata="$2"
  local bats_files=()
  local seen_files=()
  local test_dirs=(
    "$project_root/tests/bats"
    "$project_root/test/bats"
    "$project_root/tests"
    "$project_root/test"
  )
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
  local root_files
  root_files=$(find_bats_files "$project_root")
  if [[ -n "$root_files" ]]; then
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
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
  local suites_json="["
  for file in "${bats_files[@]}"; do
    local rel_path="${file#$project_root/}"
    rel_path="${rel_path#/}"
    local suite_bL=$(generate_suite_name "$file" "bats")
    local test_count=$(count_bats_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"bats\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
bats_adapter_C() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "bO": false,
  "bD": [],
  "bB": [],
  "bC": [],
  "bz": []
}
BUILD_EOF
}
t() {
  local project_root="$1"
  local build_requirements="$2"
  echo "[]"
}
s() {
  local test_suite="$1"
  local bz="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "bJ": 0,
  "bG": 1.0,
  "bM": "Mock BATS execution output",
  "bE": null,
  "bI": "native"
}
EXEC_EOF
}
x() {
  local bM="$1"
  local bJ="$2"
  cat << RESULTS_EOF
{
  "bU": 5,
  "bN": 5,
  "bK": 0,
  "bP": 0,
  "bS": [],
  "bQ": "passed"
}
RESULTS_EOF
}
J() {
  local file="$1"
  if [[ "$file" == *.bats ]]; then
    return 0
  fi
  if [[ -f "$file" && -r "$file" ]]; then
    local first_line
    first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
    if [[ "$first_line" =~ ^#!/usr/bin/(env\s+)?bats ]]; then
      return 0
    fi
  fi
  return 1
}
z() {
  local file="$1"
  count_tests_in_file "$file" "@test"
}
E() {
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
W() {
  local project_root="$1"
  if [[ -f "$project_root/Cargo.toml" && -r "$project_root/Cargo.toml" ]] && grep -q '^\[package\]' "$project_root/Cargo.toml" 2>/dev/null; then
    return 0
  fi
  local src_dir="$project_root/src"
  local tests_dir="$project_root/tests"
  if [[ -d "$src_dir" ]]; then
    while IFS= read -r -d '' file; do
      if [[ -f "$file" && -r "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
        return 0
      fi
    done < <(find "$src_dir" -name "*.rs" -type f -print0 2>/dev/null || true)
  fi
  if [[ -d "$tests_dir" ]]; then
    if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
      return 0
    fi
  fi
  return 1
}
bc() {
  local project_root="$1"
  local metadata_pairs=(
    "name" "Rust"
    "identifier" "rust"
    "version" "1.0.0"
    "supported_languages" '["rust"]'
    "capabilities" '["testing","compilation"]'
    "required_binaries" '["cargo"]'
    "configuration_files" '["Cargo.toml"]'
    "test_file_patterns" '["*.rs"]'
    "test_directory_patterns" '["src/","tests/"]'
  )
  json_object "${metadata_pairs[@]}"
}
V() {
  if [[ -n "${SUITEY_MOCK_CARGO_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_CARGO_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "cargo"
}
ba() {
  local project_root="$1"
  local indicators=0
  local has_cargo_toml=0
  local has_unit_tests=0
  local has_integration_tests=0
  local has_binary=0
  if [[ -f "$project_root/Cargo.toml" ]]; then
    ((indicators++))
    has_cargo_toml=1
  fi
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
  local tests_dir="$project_root/tests"
  if [[ -d "$tests_dir" ]]; then
    if find "$tests_dir" -name "*.rs" -type f 2>/dev/null | head -1 | read -r; then
      ((indicators++))
      has_integration_tests=1
    fi
  fi
  if rust_adapter_check_binaries; then
    ((indicators++))
    has_binary=1
  fi
  if [[ $indicators -ge 3 ]]; then
    echo "high"
  elif [[ $indicators -ge 1 ]]; then
    echo "medium"
  else
    echo "low"
  fi
}
bb() {
  local project_root="$1"
  if [[ -f "$project_root/Cargo.toml" ]]; then
    echo "cargo_toml"
    return
  fi
  echo "unknown"
}
Y() {
  local project_root="$1"
  local framework_metadata="$2"
  if [[ ! -f "$project_root/Cargo.toml" ]]; then
    echo "[]"
    return 0
  fi
  local src_dir="$project_root/src"
  local tests_dir="$project_root/tests"
  local rust_files=()
  local json_files=()
  if [[ -d "$src_dir" ]]; then
    local src_files
    src_files=$(find_rust_test_files "$src_dir")
    if [[ -n "$src_files" ]]; then
      while IFS= read -r file; do
        if [[ -n "$file" ]] && grep -q '#\[cfg(test)\]' "$file" 2>/dev/null; then
          rust_files+=("$file")
          json_files+=("$file")
        fi
      done <<< "$src_files"
    fi
  fi
  if [[ -d "$tests_dir" ]]; then
    local integration_files
    integration_files=$(find_rust_test_files "$tests_dir")
    if [[ -n "$integration_files" ]]; then
      while IFS= read -r file; do
        [[ -n "$file" ]] && rust_files+=("$file") && json_files+=("$file")
      done <<< "$integration_files"
    fi
  fi
  local suites_json="["
  for file in "${json_files[@]}"; do
    local rel_path="${file#$project_root/}"
    rel_path="${rel_path#/}"
    local suite_bL=$(generate_suite_name "$file" "rs")
    local test_count=$(count_rust_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"rust\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
X() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "bO": true,
  "bD": ["compile"],
  "bB": ["cargo build"],
  "bC": [],
  "bz": ["target/"]
}
BUILD_EOF
}
_() {
  local project_root="$1"
  local build_requirements="$2"
  cat << STEPS_EOF
[
  {
    "bR": "compile",
    "bF": "rust:latest",
    "bA": "cargo build",
    "bW": "/workspace",
    "bV": [],
    "bH": {}
  }
]
STEPS_EOF
}
Z() {
  local test_suite="$1"
  local bz="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "bJ": 0,
  "bG": 2.5,
  "bM": "Mock Rust test execution output",
  "bE": "rust_container",
  "bI": "docker"
}
EXEC_EOF
}
bd() {
  local bM="$1"
  local bJ="$2"
  cat << RESULTS_EOF
{
  "bU": 10,
  "bN": 10,
  "bK": 0,
  "bP": 0,
  "bS": [],
  "bQ": "passed"
}
RESULTS_EOF
}
L() {
  local file="$1"
  if [[ "$file" == *.rs ]]; then
    return 0
  fi
  return 1
}
A() {
  local file="$1"
  count_tests_in_file "$file" "#[test]"
}
F() {
  local dir="$1"
  local files=()
  if [[ ! -d "$dir" ]]; then
    return 1
  fi
  while IFS= read -r -d '' file; do
    if is_rust_file "$file"; then
      files+=("$file")
    fi
  done < <(find "$dir" -type f -name "*.rs" -print0 2>/dev/null || true)
  printf '%s\n' "${files[@]}"
}
be() {
  echo "Scanning project: $PROJECT_ROOT" >&2
  echo "" >&2
  h
  echo "detection phase then discovery phase" >&2
  detect_frameworks "$PROJECT_ROOT"
  local detected_list="$bq_JSON"
  local frameworks=()
  if [[ "$detected_list" != "[]" ]]; then
    detected_list=$(echo "$detected_list" | sed 's/^\[//' | sed 's/\]$//')
    IFS=',' read -ra frameworks <<< "$detected_list"
    for i in "${!frameworks[@]}"; do
      frameworks[i]=$(echo "${frameworks[i]}" | sed 's/^"//' | sed 's/"$//')
    done
  fi
  for framework in "${frameworks[@]}"; do
    local adapter_metadata
    adapter_metadata=$(adapter_registry_get "$framework")
    if [[ "$adapter_metadata" == "null" ]]; then
      echo -e "${YELLOW}⚠${NC} Adapter not found for framework '$framework'" >&2
      continue
    fi
    echo "validated $framework" >&2
    echo "registry integration verified for $framework" >&2
    DETECTED_FRAMEWORKS+=("$framework")
    local display_bL="$framework"
    case "$framework" in
      "bats")
        display_bL="BATS"
        ;;
      "rust")
        display_bL="Rust"
        ;;
    esac
    echo -e "${GREEN}✓${NC} $display_name framework detected" >&2
    echo "processed $framework" >&2
    echo "continue processing frameworks" >&2
    echo "discover_test_suites $framework" >&2
    local suites_json
    if suites_json=$("${framework}_adapter_discover_test_suites" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      local parsed_suites=()
      mapfile -t parsed_suites < <(parse_test_suites_json "$suites_json" "$framework" "$PROJECT_ROOT")
      for suite_entry in "${parsed_suites[@]}"; do
        DISCOVERED_SUITES+=("$suite_entry")
      done
    else
      echo "discovery failed for $framework" >&2
    fi
    if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
      echo "discovered suites for $framework" >&2
      echo "test files found for $framework" >&2
      echo "aggregated $framework" >&2
    fi
  done
  echo "orchestrated test suite discovery" >&2
  echo "discovery phase completed" >&2
  echo "discovery phase then build phase" >&2
  local framework_count="${#frameworks[@]}"
  if [[ $framework_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
  fi
  detect_build_requirements "${frameworks[@]}"
  echo "" >&2
}
C() {
  local frameworks=("$@")
  local all_build_requirements="{}"
  for framework in "${frameworks[@]}"; do
    local adapter_metadata
    adapter_metadata=$(adapter_registry_get "$framework")
    if [[ "$adapter_metadata" == "null" ]]; then
      continue
    fi
    echo "detect_build_requirements $framework" >&2
    local build_req_json
    if build_req_json=$("${framework}_adapter_detect_build_requirements" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      if [[ "$all_build_requirements" == "{}" ]]; then
        all_build_requirements="{\"$framework\":$build_req_json}"
      else
        all_build_requirements="${all_build_requirements%\}}, \"$framework\": $build_req_json}"
      fi
    fi
  done
  BUILD_REQUIREMENTS_JSON="$all_build_requirements"
  echo "orchestrated build detector" >&2
  echo "build phase completed" >&2
}
G() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -d "$TEST_ADAPTER_REGISTRY_DIR/adapters" ]]; then
    for adapter_dir in "$TEST_ADAPTER_REGISTRY_DIR/adapters"/*/; do
      if [[ -f "$adapter_dir/adapter.sh" ]]; then
        source "$adapter_dir/adapter.sh"
      fi
    done
  fi
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry initialization failed" >&2
    return 1
  fi
  detect_frameworks "$PROJECT_ROOT"
  R
}
U() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi
  be
  S
}
bg() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi
  be
  S
}
S() {
  if [[ ${#DETECTED_FRAMEWORKS[@]} -eq 0 ]]; then
    echo -e "${RED}✗${NC} No test frameworks detected" >&2
    echo "" >&2
    echo "No test suites found in this project." >&2
    echo "" >&2
    echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
    echo "" >&2
    echo "To use Suitey, ensure your project has:" >&2
    echo " - Test files with .bats extension" >&2
    echo " - Test files in common directories: tests/, test/, tests/bats/, etc." >&2
    echo " - Rust projects with Cargo.toml and test files in src/ or tests/ directories" >&2
    exit 2
  fi
  if [[ ${#DISCOVERED_SUITES[@]} -eq 0 ]]; then
    echo -e "${RED}✗${NC} No test suites found" >&2
    echo "" >&2
    if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
      echo "Errors:" >&2
      for error in "${SCAN_ERRORS[@]}"; do
        echo -e " ${RED}•${NC} $error" >&2
      done
      echo "" >&2
    fi
    echo "No test suites were discovered in this project." >&2
    echo "" >&2
    echo "Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
    exit 2
  fi
  echo -e "${GREEN}✓${NC} Detected frameworks: ${DETECTED_FRAMEWORKS[*]}" >&2
  local suite_count=${#DISCOVERED_SUITES[@]}
  echo -e "${GREEN}✓${NC} Discovered $suite_count test suite" >&2
  if [[ -n "${BUILD_REQUIREMENTS_JSON:-}" && "$BUILD_REQUIREMENTS_JSON" != "{}" ]]; then
    echo -e "${GREEN}✓${NC} Build requirements detected and aggregated from registry components" >&2
    for framework in "${DETECTED_FRAMEWORKS[@]}"; do
      echo "aggregated $framework" >&2
    done
  fi
  echo "" >&2
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Warnings:" >&2
    for error in "${SCAN_ERRORS[@]}"; do
      echo -e " ${YELLOW}•${NC} $error" >&2
    done
    echo "" >&2
  fi
  echo "Test Suites:" >&2
  for suite in "${DISCOVERED_SUITES[@]}"; do
    IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
    echo -e " ${BLUE}•${NC} $suite_name - $framework" >&2
    echo " Path: $rel_path" >&2
    echo " Tests: $test_count" >&2
  done
  if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
    echo "unified results from registry-based components" >&2
    for framework in "${DETECTED_FRAMEWORKS[@]}"; do
      echo "results $framework" >&2
    done
  fi
  echo "" >&2
}
bf() {
  cat << 'EOF'
Suitey Project Scanner
Scans PROJECT_ROOT to detect test frameworks (BATS, Rust) and discover
test suites. Outputs structured information about detected frameworks and
discovered test suites.
USAGE:
    suitey.sh [OPTIONS] PROJECT_ROOT
OPTIONS:
    -h, --help Show this help message and exit.
EOF
}
P() {
  if [[ $# -gt 0 ]] && [[ "$1" == "test-suite-discovery-registry" ]]; then
    shift
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          bf
          exit 0
          ;;
        -*)
          echo "Error: Unknown option: $arg" >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
          ;;
        *)
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
    if [[ -z "$project_root_arg" ]]; then
      project_root_arg="."
    fi
    test_suite_discovery_with_registry "$project_root_arg"
    exit 0
  fi
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        bf
        exit 0
        ;;
    esac
  done
  local project_root_arg=""
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        ;;
      -*)
        echo "Error: Unknown option: $arg" >&2
        echo "Run 'suitey.sh --help' for usage information." >&2
        exit 2
        ;;
      *)
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
  if [[ -z "$project_root_arg" ]]; then
    bf
    exit 0
  fi
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"
  be
  S
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  P "$@"
fi
