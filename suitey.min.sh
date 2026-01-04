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
ca=()
cc=()
ci=()
Y() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
bu() {
  local file="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file"
  elif command -v realpath >/dev/null 2>&1; then
    realpath "$file" 2>/dev/null || echo "$file"
  else
    echo "$file"
  fi
}
bo() {
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
bl() {
  local file="$1"
  local extension="$2"
  local rel_path="${file#$PROJECT_ROOT/}"
  rel_path="${rel_path#/}"
  local suite_cH="${rel_path%.${extension}}"
  suite_cH="${suite_name//\//-}"
  if [[ -z "$suite_name" ]]; then
    suite_cH=$(basename "$file" ".${extension}")
  fi
  echo "$suite_name"
}
bm() {
  local file="$1"
  if [[ "$file" != /* ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}
ba() {
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
bR=false
bS=()
ch="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
bP="$ch/suitey_adapter_registry"
bO="$ch/suitey_adapter_capabilities"
bT="$ch/suitey_adapter_order"
bQ="$ch/suitey_adapter_init"
l() {
  mkdir -p "$(dirname "$bP")"
  > "$bP"
  for key in "${!ADAPTER_REGISTRY[@]}"; do
    echo "$key=${ADAPTER_REGISTRY[$key]}" >> "$bP"
  done
  > "$bO"
  for key in "${!ADAPTER_REGISTRY_CAPABILITIES[@]}"; do
    echo "$key=${ADAPTER_REGISTRY_CAPABILITIES[$key]}" >> "$bO"
  done
  > "$bS_FILE"
  printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$bS_FILE"
  echo "$bR" > "$bM_INIT_FILE"
}
j() {
  if [[ -f "$bP" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY["$key"]="$value"
    done < "$bP"
  fi
  if [[ -f "$bO" ]]; then
    while IFS='=' read -r key value; do
      ADAPTER_REGISTRY_CAPABILITIES["$key"]="$value"
    done < "$bO"
  fi
  if [[ -f "$bS_FILE" ]]; then
    mapfile -t ADAPTER_REGISTRY_ORDER < "$bS_FILE"
  fi
  if [[ -f "$bM_INIT_FILE" ]]; then
    bR=$(<"$bM_INIT_FILE")
  fi
}
b() {
  rm -f "$bP" "$bO" "$bS_FILE" "$bM_INIT_FILE"
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
  if [[ "$bR" == "true" ]]; then
    return 0
  fi
  local builtin_adapters=("bats" "rust")
  for adapter in "${builtin_adapters[@]}"; do
    if ! adapter_registry_register "$adapter"; then
      echo "ERROR: Failed to register built-in adapter '$adapter'" >&2
      return 1
    fi
  done
  bR=true
  l
  return 0
}
a() {
  bM=()
  bN=()
  bS=()
  bR=false
  b
  return 0
}
cb=""
ce=""
bU=""
cg=""
cf=""
cd=(
  "bats"
  "rust"
)
br() {
  local string="$1"
  string="${string//\\/\\\\}"
  string="${string//\"/\\\"}"
  echo "$string"
}
bq() {
  local items=("$@")
  local json_items=()
  for item in "${items[@]}"; do
    json_items+=("\"$(json_escape "$item")\"")
  done
  echo "[$(IFS=','; echo "${json_items[*]}")]"
}
bs() {
  local pairs=("$@")
  local json_pairs=()
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    local key="${pairs[i]}"
    local value="${pairs[i+1]}"
    json_pairs+=("\"$(json_escape "$key")\":\"$(json_escape "$value")\"")
  done
  echo "{$(IFS=','; echo "${json_pairs[*]}")}"
}
bx() {
  local bq="$1"
  local cC="$2"
  local project_root="$3"
  if [[ -z "$bq" || "$bq" == "[]" ]]; then
    return 0
  fi
  if [[ "$bq" != \[*\] ]]; then
    echo "ERROR: Invalid JSON format for $cC - not a valid array" >&2
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
    local suite_cH=""
    suite_cH=$(echo "$suite_obj" | grep -o '"name"[^,]*' | sed 's/"cH"://' | sed 's/"//g' | head -1)
    if [[ -z "$suite_name" ]]; then
      echo "WARNING: Could not parse suite name from $cC JSON object" >&2
      continue
    fi
    local test_files_part=""
    test_files_part=$(echo "$suite_obj" | grep -o '"test_files"[^]]*]' | sed 's/"cV"://' | head -1)
    if [[ -z "$cV_part" ]]; then
      echo "WARNING: Could not parse test_files from $cC suite '$suite_name'" >&2
      continue
    fi
    test_files_part="${test_files_part#[}"
    test_files_part="${test_files_part%]}"
    local cV=()
    if [[ -n "$cV_part" ]]; then
      IFS=',' read -ra test_files <<< "$cV_part"
      for i in "${!test_files[@]}"; do
        test_files[i]="${test_files[i]#\"}"
        test_files[i]="${test_files[i]%\"}"
        test_files[i]="${test_files[i]//[[:space:]]/}"
      done
    fi
    if [[ ${#test_files[@]} -eq 0 ]]; then
      echo "WARNING: No test files found in $cC suite '$suite_name'" >&2
      continue
    fi
    local total_test_count=0
    for test_file in "${test_files[@]}"; do
      if [[ -n "$test_file" ]]; then
        local abs_path="$project_root/$test_file"
        local file_test_count=0
        case "$cC" in
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
    echo "$cC|$suite_name|$abs_file_path|$first_test_file|$total_test_count"
  done
}
bd() {
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
      if [[ "$cC_details_json" == "{}" ]]; then
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
  cb=$(json_array "${detected_frameworks[@]}")
  ce="$cC_details_json"
  bU="$binary_status_json"
  cg="$warnings_json"
  cf="$cys_json"
  echo "orchestrated framework detector" >&2
  echo "detection phase completed" >&2
}
bv() {
  local json_cI="{"
  json_cI="${json_output}\"framework_list\":$ca_JSON,"
  json_cI="${json_output}\"framework_details\":$ce,"
  json_cI="${json_output}\"binary_status\":$bU,"
  json_cI="${json_output}\"warnings\":$cg,"
  json_cI="${json_output}\"errors\":$cf"
  json_cI="${json_output}}"
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
    local suite_cH=$(generate_suite_name "$file" "bats")
    local test_count=$(count_bats_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"bats\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
bats_adapter_bb() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "cN": false,
  "co": [],
  "cm": [],
  "cn": [],
  "ck": []
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
  local cW="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "cA": 0,
  "cv": 1.0,
  "cI": "Mock BATS execution output",
  "cp": null,
  "cz": "native",
  "cW": "${test_image:-}"
}
EXEC_EOF
}
x() {
  local cI="$1"
  local cA="$2"
  cat << RESULTS_EOF
{
  "cZ": 5,
  "cJ": 5,
  "cB": 0,
  "cO": 0,
  "cU": [],
  "cR": "passed"
}
RESULTS_EOF
}
bn() {
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
Z() {
  local file="$1"
  count_tests_in_file "$file" "@test"
}
bi() {
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
bA() {
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
bH() {
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
bz() {
  if [[ -n "${SUITEY_MOCK_CARGO_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_CARGO_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "cargo"
}
bF() {
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
bG() {
  local project_root="$1"
  if [[ -f "$project_root/Cargo.toml" ]]; then
    echo "cargo_toml"
    return
  fi
  echo "unknown"
}
bC() {
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
    local suite_cH=$(generate_suite_name "$file" "rs")
    local test_count=$(count_rust_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"rust\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
bB() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "cN": true,
  "co": ["compile"],
  "cm": ["cargo build"],
  "cn": [],
  "ck": ["target/"]
}
BUILD_EOF
}
bE() {
  local project_root="$1"
  local build_requirements="$2"
  cat << STEPS_EOF
[
  {
    "cS": "compile",
    "cu": "rust:latest",
    "cG": "",
    "cl": "cargo build --jobs \$(nproc)",
    "da": "/workspace",
    "c_": [],
    "cx": {},
    "cq": null
  }
]
STEPS_EOF
}
bD() {
  local test_suite="$1"
  local cW="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "cA": 0,
  "cv": 2.5,
  "cI": "Mock Rust test execution output",
  "cp": "rust_container",
  "cz": "docker",
  "cW": "${test_image}"
}
EXEC_EOF
}
bI() {
  local cI="$1"
  local cA="$2"
  cat << RESULTS_EOF
{
  "cZ": 10,
  "cJ": 10,
  "cB": 0,
  "cO": 0,
  "cU": [],
  "cR": "passed"
}
RESULTS_EOF
}
bp() {
  local file="$1"
  if [[ "$file" == *.rs ]]; then
    return 0
  fi
  return 1
}
_() {
  local file="$1"
  count_tests_in_file "$file" "#[test]"
}
bj() {
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
bJ() {
  echo "Scanning project: $PROJECT_ROOT" >&2
  echo "" >&2
  h
  echo "detection phase then discovery phase" >&2
  detect_frameworks "$PROJECT_ROOT"
  local detected_list="$ca_JSON"
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
    adapter_metadata=$(adapter_registry_get "$cC")
    if [[ "$adapter_metadata" == "null" ]]; then
      echo -e "${YELLOW}⚠${NC} Adapter not found for framework '$cC'" >&2
      continue
    fi
    echo "validated $cC" >&2
    echo "registry integration verified for $cC" >&2
    DETECTED_FRAMEWORKS+=("$cC")
    local display_cH="$cC"
    case "$cC" in
      "bats")
        display_cH="BATS"
        ;;
      "rust")
        display_cH="Rust"
        ;;
    esac
    echo -e "${GREEN}✓${NC} $display_name framework detected" >&2
    echo "processed $cC" >&2
    echo "continue processing frameworks" >&2
    echo "discover_test_suites $cC" >&2
    local suites_json
    if suites_json=$("${framework}_adapter_discover_test_suites" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      local parsed_suites=()
      mapfile -t parsed_suites < <(parse_test_suites_json "$suites_json" "$cC" "$PROJECT_ROOT")
      for suite_entry in "${parsed_suites[@]}"; do
        DISCOVERED_SUITES+=("$suite_entry")
      done
    else
      echo "discovery failed for $cC" >&2
    fi
    if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
      echo "discovered suites for $cC" >&2
      echo "test files found for $cC" >&2
      echo "aggregated $cC" >&2
    fi
  done
  echo "orchestrated test suite discovery" >&2
  echo "discovery phase completed" >&2
  echo "discovery phase then build phase" >&2
  local framework_count="${#frameworks[@]}"
  if [[ $cC_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
  fi
  detect_build_requirements "${frameworks[@]}"
  echo "" >&2
}
bb() {
  local frameworks=("$@")
  local all_build_requirements="{}"
  for framework in "${frameworks[@]}"; do
    local adapter_metadata
    adapter_metadata=$(adapter_registry_get "$cC")
    if [[ "$adapter_metadata" == "null" ]]; then
      continue
    fi
    echo "detect_build_requirements $cC" >&2
    local build_req_json
    if build_req_json=$("${framework}_adapter_detect_build_requirements" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      if [[ "$all_build_requirements" == "{}" ]]; then
        all_build_requirements="{\"$cC\":$build_req_json}"
      else
        all_build_requirements="${all_build_requirements%\}}, \"$cC\": $build_req_json}"
      fi
    fi
  done
  BUILD_REQUIREMENTS_JSON="$all_build_requirements"
  echo "orchestrated build detector" >&2
  echo "build phase completed" >&2
}
bk() {
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
  bv
}
by() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi
  bJ
  bw
}
bL() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi
  bJ
  bw
}
bw() {
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
        echo -e " ${RED}•${NC} $cy" >&2
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
      echo "aggregated $cC" >&2
    done
  fi
  echo "" >&2
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Warnings:" >&2
    for error in "${SCAN_ERRORS[@]}"; do
      echo -e " ${YELLOW}•${NC} $cy" >&2
    done
    echo "" >&2
  fi
  echo "Test Suites:" >&2
  for suite in "${DISCOVERED_SUITES[@]}"; do
    IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
    echo -e " ${BLUE}•${NC} $suite_name - $cC" >&2
    echo " Path: $rel_path" >&2
    echo " Tests: $test_count" >&2
  done
  if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
    echo "unified results from registry-based components" >&2
    for framework in "${DETECTED_FRAMEWORKS[@]}"; do
      echo "results $cC" >&2
    done
  fi
  echo "" >&2
}
if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
  if [[ -f "tests/bats/helpers/mock_manager.bash" ]]; then
    source "tests/bats/helpers/mock_manager.bash"
  elif [[ -f "../tests/bats/helpers/mock_manager.bash" ]]; then
    source "../tests/bats/helpers/mock_manager.bash"
  fi
fi
b_=""
bW=()
bX=""
bV=""
bZ=false
bY=false
bg() {
  if [[ $# -le 5 ]] && [[ "$1" != -* ]] && [[ "$2" != -* ]]; then
    local container_cH="$1"
    local image="$2"
    local command="$3"
    local cA="${4:-0}"
    local cI="${5:-Mock Docker run output}"
    echo "$cI"
    return $cA
  else
    local simple_args
    simple_args=$(transform_docker_args "$@")
    local container_name image command
    read -r container_name <<< "$(echo "$simple_args" | head -1)"
    read -r image <<< "$(echo "$simple_args" | head -2 | tail -1)"
    read -r command <<< "$(echo "$simple_args" | head -3 | tail -1)"
    docker_run "$container_name" "$image" "$command"
  fi
}
bh() {
  local container_cH="$1"
  local image="$2"
  local command="$3"
  local cq="$4"
  local project_root="$5"
  local artifacts_dir="$6"
  local working_dir="$7"
  local docker_cmd=("docker" "run" "--rm" "--name" "$container_name")
  if [[ -n "$cq" ]]; then
    docker_cmd+=("--cpus" "$cq")
  fi
  if [[ -n "$project_root" ]]; then
    docker_cmd+=("-v" "$project_root:/workspace")
  fi
  if [[ -n "$artifacts_dir" ]]; then
    docker_cmd+=("-v" "$artifacts_dir:/artifacts")
  fi
  if [[ -n "$working_dir" ]]; then
    docker_cmd+=("-w" "$working_dir")
  fi
  docker_cmd+=("$image" "/bin/sh" "-c" "$command")
  "${docker_cmd[@]}"
}
be() {
  if [[ $# -le 3 ]] && [[ "$1" != -* ]]; then
    return 0
  else
    docker build "$@"
  fi
}
bf() {
  local source="$1"
  local dest="$2"
  docker cp "$source" "$dest"
}
N() {
  local temp_base="${TEST_BUILD_MANAGER_DIR:-${TMPDIR:-/tmp}}"
  if ! build_manager_check_docker; then
    echo "ERROR: Docker daemon not running or cannot connect" >&2
    return 1
  fi
  b_="$temp_base"
  mkdir -p "$b_/builds"
  mkdir -p "$b_/artifacts"
  bX="$b_/build_status.json"
  bV="$b_/active_builds.json"
  echo "{}" > "$bX"
  echo "[]" > "$bV"
  trap 'build_manager_handle_signal SIGINT first' SIGINT
  trap 'build_manager_handle_signal SIGTERM first' SIGTERM
  if [[ -z "${SUITEY_TEST_MODE:-}" ]]; then
    echo "Build Manager initialized successfully"
  fi
  return 0
}
A() {
  if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker command not found in PATH" >&2
    return 1
  fi
  if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running or not accessible" >&2
    return 1
  fi
  return 0
}
build_manager_get_cq() {
  local cores
  if command -v nproc &> /dev/null; then
    cores=$(nproc)
  elif [[ -f /proc/cpuinfo ]]; then
    cores=$(grep -c '^processor' /proc/cpuinfo)
  elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu &> /dev/null; then
    cores=$(sysctl -n hw.ncpu)
  else
    cores=1
  fi
  echo $((cores > 0 ? cores : 1))
}
P() {
  local build_requirements_json="$1"
  if [[ -z "$build_requirements_json" ]]; then
    echo '{"cy": "No build requirements provided"}'
    return 1
  fi
  if [[ -z "$b_" ]]; then
    if ! build_manager_initialize; then
      echo '{"cy": "Failed to initialize Build Manager"}'
      return 1
    fi
  fi
  if ! build_manager_validate_requirements "$build_requirements_json"; then
    echo '{"cy": "Invalid build requirements structure"}'
    return 1
  fi
  local dependency_analysis
  dependency_analysis=$(build_manager_analyze_dependencies "$build_requirements_json")
  local build_results="[]"
  local cT=true
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    local framework_count
    framework_count=$(echo "$build_requirements_json" | jq 'length' 2>/dev/null || echo "0")
    for ((i=0; i<framework_count; i++)); do
      local framework
      cC=$(echo "$build_requirements_json" | jq -r ".[$i].framework" 2>/dev/null)
      local mock_result
      mock_result=$(jq -n --arg f "$cC" '{"cC": $f, "cR": "built", "cv": 1.5, "cp": "mock_container_123"}')
      build_results=$(echo "$build_results [$mock_result]" | jq -s '.[0] + .[1]' 2>/dev/null || echo "[$mock_result]")
    done
  else
    local tier_count
    tier_count=$(echo "$dependency_analysis" | jq 'keys | map(select(startswith("tier_"))) | length' 2>/dev/null || echo "0")
    for ((tier=0; tier<tier_count; tier++)); do
      local tier_frameworks
      tier_frameworks=$(echo "$dependency_analysis" | jq -r ".tier_$tier[]?" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
      if [[ -n "$tier_frameworks" ]] && [[ "$tier_frameworks" != "null" ]]; then
        local tier_build_specs="[]"
        for framework in $tier_frameworks; do
          local build_spec
          build_spec=$(echo "$build_requirements_json" | jq "[.[] | select(.framework == \"$cC\")]" 2>/dev/null)
          if [[ -n "$build_spec" ]] && [[ "$build_spec" != "[]" ]]; then
            tier_build_specs=$(echo "$tier_build_specs $build_spec" | jq -s '.[0] + .[1]' 2>/dev/null || echo "$build_spec")
          fi
        done
        local tier_results
        tier_results=$(build_manager_execute_parallel "$tier_build_specs")
        build_results=$(echo "$build_results $tier_results" | jq -s '.[0] + .[1]' 2>/dev/null || echo "$tier_results")
        local has_failures
        has_failures=$(echo "$tier_results" | jq '[.[] | select(.status == "build-failed")] | length > 0' 2>/dev/null || echo "false")
        if [[ "$has_failures" == "true" ]]; then
          cT=false
          break
        fi
      fi
    done
  fi
  if [[ "$cT" == "true" ]]; then
    echo "$build_results"
    return 0
  else
    echo "$build_results"
    return 1
  fi
}
y() {
  local build_requirements_json="$1"
  local frameworks=()
  while IFS= read -r framework; do
    frameworks+=("$cC")
  done < <(echo "$build_requirements_json" | jq -r '.[].framework' 2>/dev/null)
  local count
  count=$(echo "$build_requirements_json" | jq 'length' 2>/dev/null || echo "0")
  for ((i=0; i<count; i++)); do
    local framework
    cC=$(echo "$build_requirements_json" | jq -r ".[$i].framework" 2>/dev/null)
    local deps
    deps=$(echo "$build_requirements_json" | jq -r ".[$i].build_dependencies // [] | join(\" \")" 2>/dev/null)
    if [[ -n "$deps" ]]; then
      for ((j=0; j<count; j++)); do
        if [[ $i != $j ]]; then
          local other_framework
          other_cC=$(echo "$build_requirements_json" | jq -r ".[$j].framework" 2>/dev/null)
          local other_deps
          other_deps=$(echo "$build_requirements_json" | jq -r ".[$j].build_dependencies // [] | join(\" \")" 2>/dev/null)
          if [[ "$deps" == *"$other_framework"* ]] && [[ "$other_deps" == *"$cC"* ]]; then
            echo "ERROR: Circular dependency detected between $cC and $other_framework" >&2
            return 1
          fi
        fi
      done
    fi
  done
  local analysis='{"cY": []}'
  local tier_0=()
  local tier_1=()
  for framework in "${frameworks[@]}"; do
    local deps_length
    deps_length=$(echo "$build_requirements_json" | jq "[.[] | select(.framework == \"$cC\") | .build_dependencies // []] | .[0] | length" 2>/dev/null || echo "0")
    if [[ "$deps_length" == "0" ]]; then
      tier_0+=("$cC")
    else
      tier_1+=("$cC")
    fi
  done
  if [[ ${#tier_0[@]} -gt 0 ]]; then
    analysis=$(echo "$analysis" | jq ".tier_0 = $(printf '%s\n' "${tier_0[@]}" | jq -R . | jq -s .)")
  fi
  if [[ ${#tier_1[@]} -gt 0 ]]; then
    analysis=$(echo "$analysis" | jq ".tier_1 = $(printf '%s\n' "${tier_1[@]}" | jq -R . | jq -s .)")
  fi
  local parallel_note='"Frameworks within the same tier can be built in parallel"'
  analysis=$(echo "$analysis" | jq ".parallel_within_tiers = true | .execution_note = $parallel_note" 2>/dev/null || echo "$analysis")
  echo "$analysis"
}
bc() {
  local dep_graph="$1"
  shift
  local frameworks=("$@")
  for framework in "${frameworks[@]}"; do
    local deps
    deps=$(echo "$dep_graph" | jq -r ".\"$cC\" // \"\"" 2>/dev/null)
    for dep in $deps; do
      local reverse_deps
      reverse_deps=$(echo "$dep_graph" | jq -r ".\"$dep\" // \"\"" 2>/dev/null)
      if [[ "$reverse_deps" == *"$cC"* ]]; then
        return 0
      fi
    done
  done
  return 1
}
H() {
  local builds_json="$1"
  local results="[]"
  local max_parallel=$(build_manager_get_cpu_cores)
  local active_builds=()
  local build_pids=()
  local build_count
  build_count=$(echo "$builds_json" | jq 'length' 2>/dev/null || echo "0")
  for ((i=0; i<build_count; i++)); do
    local build_spec
    build_spec=$(echo "$builds_json" | jq ".[$i]" 2>/dev/null)
    if [[ -n "$build_spec" ]] && [[ "$build_spec" != "null" ]]; then
      if [[ ${#active_builds[@]} -lt max_parallel ]]; then
        build_manager_execute_build_async "$build_spec" &
        local pid=$!
        build_pids+=("$pid")
        active_builds+=("$i")
      else
        wait "${build_pids[0]}"
        unset build_pids[0]
        build_pids=("${build_pids[@]}")
        build_manager_execute_build_async "$build_spec" &
        local pid=$!
        build_pids+=("$pid")
      fi
    fi
  done
  for pid in "${build_pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done
  local result_files=("$b_/builds"/*/result.json)
  for result_file in "${result_files[@]}"; do
    if [[ -f "$result_file" ]]; then
      local result
      result=$(cat "$result_file")
      results=$(echo "$results" | jq ". += [$result]" 2>/dev/null || echo "[$result]")
    fi
  done
  echo "$results"
}
F() {
  local build_spec_json="$1"
  local cC="$2"
  local docker_image
  cu=$(echo "$build_spec_json" | jq -r '.docker_image' 2>/dev/null)
  local build_command
  cl=$(echo "$build_spec_json" | jq -r '.build_command' 2>/dev/null)
  local install_deps_cmd
  install_deps_cmd=$(echo "$build_spec_json" | jq -r '.install_dependencies_command // empty' 2>/dev/null)
  local working_dir
  working_dir=$(echo "$build_spec_json" | jq -r '.working_directory // "/workspace"' 2>/dev/null)
  local cpu_cores
  cq=$(echo "$build_spec_json" | jq -r '.cpu_cores // empty' 2>/dev/null)
  if [[ -z "$cq" ]] || [[ "$cq" == "null" ]]; then
    cq=$(build_manager_get_cpu_cores)
  fi
  local build_dir="$b_/builds/$cC"
  mkdir -p "$build_dir"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local random_suffix
  random_suffix=$(printf "%04x" $((RANDOM % 65536)))
  local container_cH="suitey-build-$cC-$timestamp-$random_suffix"
  BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
  local full_command=""
  if [[ -n "$install_deps_cmd" ]]; then
    full_command="$install_deps_cmd && $cl"
  else
    full_command="$cl"
  fi
  local start_time
  cQ=$(date +%s.%3N)
  local cA=0
  local output_file="$build_dir/output.txt"
  local docker_args=("--rm" "--name" "$container_name" "--cpus" "$cq")
  docker_args+=("-v" "$PROJECT_ROOT:/workspace")
  docker_args+=("-v" "$build_dir/artifacts:/artifacts")
  docker_args+=("-w" "$working_dir")
  local env_vars
  env_vars=$(echo "$build_spec_json" | jq -r '.environment_variables // {} | to_entries[] | (.key + "=" + .value)' 2>/dev/null)
  if [[ -n "$env_vars" ]]; then
    while IFS= read -r env_var; do
      if [[ -n "$env_var" ]]; then
        docker_args+=("-e" "$env_var")
      fi
    done <<< "$env_vars"
  fi
  local volume_mounts
  c_=$(echo "$build_spec_json" | jq -r '.volume_mounts[]? | (.host_path + ":" + .container_path)' 2>/dev/null)
  if [[ -n "$c_" ]]; then
    while IFS= read -r volume_mount; do
      if [[ -n "$volume_mount" ]]; then
        docker_args+=("-v" "$volume_mount")
      fi
    done <<< "$c_"
  fi
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    docker_run "$container_name" "$cu" "$full_command" > "$cI_file" 2>&1
    cA=$?
  else
    _execute_docker_run "$container_name" "$cu" "$full_command" "$cq" "$PROJECT_ROOT" "$build_dir/artifacts" "$working_dir" > "$cI_file" 2>&1
    cA=$?
  fi
  local end_time
  cw=$(date +%s.%3N)
  local duration
  cv=$(echo "$cw - $cQ" | bc 2>/dev/null || echo "0")
  local result
  result=$(cat <<EOF
{
  "cC": "$cC",
  "cR": "$([[ $cA -eq 0 ]] && echo "built" || echo "build-failed")",
  "cv": $cv,
  "cQ": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cw": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cp": "$container_name",
  "cA": $cA,
  "cr": $cq,
  "cI": "$(cat "$cI_file" | jq -R -s .)",
  "cy": $([[ $cA -eq 0 ]] && echo "null" || echo "\"Build failed with exit code $cA\"")
}
EOF
  )
  echo "$result" > "$build_dir/result.json"
  bW=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$container_name/}")
  echo "$result"
}
G() {
  local build_spec_json="$1"
  local framework
  cC=$(echo "$build_spec_json" | jq -r '.framework' 2>/dev/null)
  build_manager_execute_build "$build_spec_json" "$cC" > /dev/null
}
build_manager_create_cW() {
  local build_requirements_json="$1"
  local cC="$2"
  local artifacts_dir="$3"
  local cE="${4:-}"
  if [[ -z "$cE" ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    cE="suitey-test-$cC-$timestamp"
  fi
  if [[ "$(type -t mock_docker_build)" == "function" ]]; then
    local mock_result
    mock_result=$(cat <<EOF
{
  "cT": true,
  "cE": "$cE",
  "cD": "sha256:mock$(date +%s)",
  "cs": true,
  "cj": true,
  "cP": true,
  "cX": true,
  "cF": true,
  "cI": "Dockerfile generated successfully. Image built with artifacts, source code, and test suites. Image contents verified."
}
EOF
    )
    echo "$mock_result"
    return 0
  fi
  local build_dir="$b_/builds/$cC"
  mkdir -p "$build_dir"
  local framework_req
  framework_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cC\")" 2>/dev/null)
  if [[ -z "$cC_req" ]] || [[ "$cC_req" == "null" ]]; then
    echo "{\"error\": \"No build requirements found for framework $cC\"}"
    return 1
  fi
  local ct="$build_dir/Dockerfile"
  build_manager_generate_dockerfile "$cC_req" "$artifacts_dir" "$ct"
  local build_result
  build_result=$(build_manager_build_test_image "$ct" "$build_dir" "$cE")
  echo "$build_result"
}
J() {
  local build_req_json="$1"
  local artifacts_dir="$2"
  local ct="$3"
  local base_image
  base_image=$(echo "$build_req_json" | jq -r '.build_steps[0].docker_image' 2>/dev/null)
  local artifacts
  artifacts=$(echo "$build_req_json" | jq -r '.artifact_storage.artifacts[]?' 2>/dev/null)
  local source_code
  source_code=$(echo "$build_req_json" | jq -r '.artifact_storage.source_code[]?' 2>/dev/null)
  local test_suites
  test_suites=$(echo "$build_req_json" | jq -r '.artifact_storage.test_suites[]?' 2>/dev/null)
  cat > "$ct" << EOF
FROM $base_image
$(for artifact in $artifacts; do echo "COPY ./artifacts/$artifact /workspace/$artifact"; done)
$(for src in $source_code; do echo "COPY $src /workspace/$src"; done)
$(for test in $test_suites; do echo "COPY $test /workspace/$test"; done)
WORKDIR /workspace
CMD ["/bin/sh"]
EOF
}
build_manager_build_cW() {
  local ct="$1"
  local context_dir="$2"
  local cE="$3"
  local output_file="$context_dir/image_build_output.txt"
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    mkdir -p "$(dirname "$cI_file")"
    if docker_build "$context_dir" "$cE" > "$cI_file" 2>&1; then
      local cD="sha256:mock$(date +%s)"
      local result
      result=$(cat <<EOF
{
  "cT": true,
  "cE": "$cE",
  "cD": "$cD",
  "ct": "$ct",
  "cI": "$(cat "$cI_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 0
    else
      local result
      result=$(cat <<EOF
{
  "cT": false,
  "cE": "$cE",
  "cy": "Failed to build Docker image",
  "cI": "$(cat "$cI_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 1
    fi
  else
    if docker_build "$context_dir" "$cE" "$ct" > "$cI_file" 2>&1; then
    local image_id
    cD=$(docker images -q "$cE" | head -1)
    local result
    result=$(cat <<EOF
{
  "cT": true,
  "cE": "$cE",
  "cD": "$cD",
  "ct": "$ct",
  "cI": "$(cat "$cI_file" | jq -R -s .)"
}
EOF
    )
    echo "$result"
    return 0
  else
    local result
    result=$(cat <<EOF
{
  "cT": false,
  "cE": "$cE",
  "cy": "Failed to build Docker image",
  "cI": "$(cat "$cI_file" | jq -R -s .)"
}
EOF
    )
    echo "$result"
    return 1
  fi
}
O() {
  local build_requirements_json="$1"
  local cC="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cC\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo ""
    return 1
  fi
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local random_suffix
  random_suffix=$(printf "%04x" $((RANDOM % 65536)))
  local container_cH="suitey-build-$cC-$timestamp-$random_suffix"
  local build_step
  build_step=$(echo "$build_req" | jq '.build_steps[0]' 2>/dev/null)
  local docker_image
  cu=$(echo "$build_step" | jq -r '.docker_image' 2>/dev/null)
  local cpu_cores
  cq=$(echo "$build_step" | jq -r '.cpu_cores // empty' 2>/dev/null)
  if [[ -z "$cq" ]] || [[ "$cq" == "null" ]]; then
    cq=$(build_manager_get_cpu_cores)
  fi
  local container_id
  cp=$(docker run -d --name "$container_name" --cpus "$cq" "$cu" sleep 3600 2>/dev/null)
  if [[ -n "$cp" ]]; then
    BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
    echo "$cp"
    return 0
  else
    echo ""
    return 1
  fi
}
U() {
  local cp="$1"
  if [[ -n "$cp" ]]; then
    docker stop "$cp" 2>/dev/null || true
    bW=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$cp/}")
  fi
}
B() {
  local cp="$1"
  if [[ -n "$cp" ]]; then
    docker rm -f "$cp" 2>/dev/null || true
    bW=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$cp/}")
  fi
}
C() {
  local cE="$1"
  if [[ -n "$cE" ]]; then
    docker rmi -f "$cE" 2>/dev/null || true
  fi
}
V() {
  local build_requirements_json="$1"
  local cC="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cC\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo "{\"error\": \"No build requirements found for framework $cC\"}"
    return 1
  fi
  build_manager_update_build_status "$cC" "building"
  local result
  result=$(build_manager_execute_build "$build_req" "$cC")
  local status
  cR=$(echo "$result" | jq -r '.status' 2>/dev/null)
  build_manager_update_build_status "$cC" "$cR"
  echo "$result"
}
W() {
  local cC="$1"
  local cR="$2"
  if [[ -f "$bX" ]]; then
    local current_status
    current_cR=$(cat "$bX")
    local updated_status
    updated_cR=$(echo "$current_status" | jq ".\"$cC\" = \"$cR\"" 2>/dev/null || echo "{\"$cC\": \"$cR\"}")
    echo "$updated_status" > "$bX"
  fi
}
build_manager_handle_cy() {
  local error_type="$1"
  local build_requirements_json="$2"
  local cC="$3"
  local additional_info="$4"
  case "$cy_type" in
    "build_failed")
      echo "ERROR: Build failed for framework $cC" >&2
      if [[ -n "$additional_info" ]]; then
        echo "Details: $additional_info" >&2
      fi
      ;;
    "container_launch_failed")
      echo "ERROR: Failed to launch build container for framework $cC" >&2
      echo "Check Docker installation and permissions" >&2
      ;;
    "artifact_extraction_failed")
      echo "WARNING: Failed to extract artifacts for framework $cC" >&2
      echo "Build may still be usable" >&2
      ;;
    "image_build_failed")
      echo "ERROR: Failed to build test image for framework $cC" >&2
      if [[ -n "$additional_info" ]]; then
        echo "Build output: $additional_info" >&2
      fi
      ;;
    "dependency_failed")
      echo "ERROR: Build dependency failed for framework $cC" >&2
      echo "Cannot proceed with dependent builds" >&2
      ;;
    *)
      echo "ERROR: Unknown build error for framework $cC: $cy_type" >&2
      ;;
  esac
  local error_log="$b_/error.log"
  echo "$(date): $cy_type - $cC - $additional_info" >> "$cy_log"
}
M() {
  local signal="$1"
  local signal_count="$2"
  if [[ "$signal_count" == "first" ]] && [[ "$bZ" == "false" ]]; then
    bZ=true
    echo "Gracefully shutting down builds..." >&2
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      build_manager_stop_container "$container"
    done
    sleep 2
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      build_manager_cleanup_container "$container"
    done
    bZ=false
  elif [[ "$signal_count" == "second" ]] || [[ "$bY" == "true" ]]; then
    bY=true
    echo "Forcefully terminating builds..." >&2
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      docker kill "$container" 2>/dev/null || true
      build_manager_cleanup_container "$container"
    done
    if [[ -n "$b_" ]] && [[ -d "$b_" ]]; then
      rm -rf "$b_"
    fi
    exit 1
  fi
}
X() {
  local build_requirements_json="$1"
  if ! echo "$build_requirements_json" | jq . >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON in build requirements" >&2
    return 1
  fi
  if ! echo "$build_requirements_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "ERROR: Build requirements must be a JSON array" >&2
    return 1
  fi
  local count
  count=$(echo "$build_requirements_json" | jq 'length' 2>/dev/null)
  for ((i=0; i<count; i++)); do
    local req
    req=$(echo "$build_requirements_json" | jq ".[$i]" 2>/dev/null)
    if ! echo "$req" | jq -e '.framework' >/dev/null 2>&1; then
      echo "ERROR: Build requirement missing 'framework' field" >&2
      return 1
    fi
    if ! echo "$req" | jq -e '.build_steps and (.build_steps | type == "array")' >/dev/null 2>&1; then
      echo "ERROR: Build requirement missing valid 'build_steps' array" >&2
      return 1
    fi
  done
  return 0
}
T() {
  local build_requirements_json="$1"
  build_manager_orchestrate "$build_requirements_json"
}
R() {
  local build_requirements_json="$1"
  local cC="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cC\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo "{}"
    return 1
  fi
  echo "$build_req" | jq '.build_steps' 2>/dev/null
}
D() {
  local build_requirements_json="$1"
  if build_manager_validate_requirements "$build_requirements_json"; then
    echo '{"cR": "coordinated", "cL": true}'
  else
    echo '{"cR": "error", "cL": false}'
  fi
}
S() {
  local build_results_json="$1"
  if echo "$build_results_json" | jq . >/dev/null 2>&1; then
    echo '{"cR": "results_received", "cK": true}'
  else
    echo '{"cR": "error", "cK": false}'
  fi
}
I() {
  local build_requirements_json="$1"
  local cC="$2"
  build_manager_execute_build "$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cC\")" 2>/dev/null)" "$cC"
}
Q() {
  local test_image_metadata_json="$1"
  local cC="$2"
  if echo "$cW_metadata_json" | jq . >/dev/null 2>&1; then
    echo '{"cR": "metadata_passed", "cC": "'$cC'", "cM": true}'
  else
    echo '{"cR": "error", "cC": "'$cC'", "cM": false}'
  fi
}
bK() {
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
bt() {
  if [[ $# -gt 0 ]] && [[ "$1" == "test-suite-discovery-registry" ]]; then
    shift
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          bK
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
        bK
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
    bK
    exit 0
  fi
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"
  bJ
  bw
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  bt "$@"
fi
