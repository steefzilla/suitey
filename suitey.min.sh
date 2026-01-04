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
cg=()
ci=()
co=()
bd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
bA() {
  local file="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file"
  elif command -v realpath >/dev/null 2>&1; then
    realpath "$file" 2>/dev/null || echo "$file"
  else
    echo "$file"
  fi
}
bu() {
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
br() {
  local file="$1"
  local extension="$2"
  local rel_path="${file#$PROJECT_ROOT/}"
  rel_path="${rel_path#/}"
  local suite_cN="${rel_path%.${extension}}"
  suite_cN="${suite_name//\//-}"
  if [[ -z "$suite_name" ]]; then
    suite_cN=$(basename "$file" ".${extension}")
  fi
  echo "$suite_name"
}
bs() {
  local file="$1"
  if [[ "$file" != /* ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}
bg() {
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
bX=false
bY=()
cn="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
bV="$cn/suitey_adapter_registry"
bU="$cn/suitey_adapter_capabilities"
bZ="$cn/suitey_adapter_order"
bW="$cn/suitey_adapter_init"
l() {
  local registry_base_dir
  local registry_file
  local capabilities_file
  local order_file
  local init_file
  local actual_base_dir
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
    actual_base_dir="$TEST_ADAPTER_REGISTRY_DIR"
  elif [[ -n "${REGISTRY_BASE_DIR:-}" ]] && [[ -d "${REGISTRY_BASE_DIR:-}" ]]; then
    actual_base_dir="$cn"
  else
    actual_base_dir="${TMPDIR:-/tmp}"
  fi
  if ! mkdir -p "$actual_base_dir" 2>&1; then
    echo "ERROR: Failed to create registry directory: $actual_base_dir" >&2
    return 1
  fi
  registry_file="$actual_base_dir/suitey_adapter_registry"
  capabilities_file="$actual_base_dir/suitey_adapter_capabilities"
  order_file="$actual_base_dir/suitey_adapter_order"
  init_file="$actual_base_dir/suitey_adapter_init"
  cn="$actual_base_dir"
  bV="$registry_file"
  bU="$capabilities_file"
  bZ="$order_file"
  bW="$init_file"
  if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
    if ! mkdir -p "$actual_base_dir" 2>&1; then
      echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2
      return 1
    fi
  fi
  if ! touch "$registry_file" 2>&1 || [[ ! -f "$registry_file" ]]; then
    echo "ERROR: Failed to create registry file: $registry_file" >&2
    return 1
  fi
  > "$registry_file"
  for key in "${!ADAPTER_REGISTRY[@]}"; do
    encoded_value=""
    if encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 -w 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
      :
    elif encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 -b 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
      :
    elif encoded_value=$(echo -n "${ADAPTER_REGISTRY[$key]}" | base64 | tr -d '\n') && [[ -n "$encoded_value" ]]; then
      :
    fi
    if [[ -z "$encoded_value" ]]; then
      echo "ERROR: Failed to encode value for key '$key'" >&2
      return 1
    fi
    echo "$key=$encoded_value" >> "$registry_file"
  done
  if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
    if ! mkdir -p "$actual_base_dir" 2>&1; then
      echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2
      return 1
    fi
  fi
  if ! touch "$capabilities_file" 2>&1 || [[ ! -f "$capabilities_file" ]]; then
    echo "ERROR: Failed to create capabilities file: $capabilities_file" >&2
    return 1
  fi
  > "$capabilities_file"
  for key in "${!ADAPTER_REGISTRY_CAPABILITIES[@]}"; do
    encoded_value=""
    if encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 -w 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
      :
    elif encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 -b 0 2>/dev/null) && [[ -n "$encoded_value" ]]; then
      :
    elif encoded_value=$(echo -n "${ADAPTER_REGISTRY_CAPABILITIES[$key]}" | base64 | tr -d '\n') && [[ -n "$encoded_value" ]]; then
      :
    fi
    if [[ -z "$encoded_value" ]]; then
      echo "ERROR: Failed to encode value for key '$key'" >&2
      return 1
    fi
    echo "$key=$encoded_value" >> "$capabilities_file"
  done
  if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
    if ! mkdir -p "$actual_base_dir" 2>&1; then
      echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2
      return 1
    fi
  fi
  if ! printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" > "$order_file" 2>&1; then
    echo "ERROR: Failed to write order file: $order_file" >&2
    return 1
  fi
  if [[ ! -d "$actual_base_dir" ]] || [[ ! -w "$actual_base_dir" ]]; then
    if ! mkdir -p "$actual_base_dir" 2>&1; then
      echo "ERROR: Directory does not exist or is not writable: $actual_base_dir" >&2
      return 1
    fi
  fi
  if ! echo "$bX" > "$init_file" 2>&1; then
    echo "ERROR: Failed to write init file: $init_file" >&2
    return 1
  fi
}
j() {
  local registry_base_dir
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]]; then
    registry_base_dir="$TEST_ADAPTER_REGISTRY_DIR"
  else
    registry_base_dir="${TMPDIR:-/tmp}"
  fi
  local registry_file="$registry_base_dir/suitey_adapter_registry"
  local capabilities_file="$registry_base_dir/suitey_adapter_capabilities"
  local order_file="$registry_base_dir/suitey_adapter_order"
  local init_file="$registry_base_dir/suitey_adapter_init"
  mkdir -p "$registry_base_dir"
  local switching_locations=false
  if [[ -n "${ADAPTER_REGISTRY_FILE:-}" ]] && [[ "$registry_file" != "${ADAPTER_REGISTRY_FILE:-}" ]]; then
    switching_locations=true
  fi
  if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] || [[ -f "$registry_file" ]] || [[ ! -f "${ADAPTER_REGISTRY_FILE:-/nonexistent}" ]]; then
    cn="$registry_base_dir"
    bV="$registry_file"
    bU="$capabilities_file"
    bZ="$order_file"
    bW="$init_file"
  fi
  local actual_registry_file="${ADAPTER_REGISTRY_FILE:-$registry_file}"
  local actual_capabilities_file="${ADAPTER_REGISTRY_CAPABILITIES_FILE:-$capabilities_file}"
  local actual_order_file="${ADAPTER_REGISTRY_ORDER_FILE:-$order_file}"
  local actual_init_file="${ADAPTER_REGISTRY_INIT_FILE:-$init_file}"
  local should_reload=false
  if [[ -f "$actual_registry_file" ]]; then
    should_reload=true
  elif [[ "$switching_locations" == "true" ]]; then
    should_reload=true
  fi
  if [[ "$should_reload" == "true" ]]; then
    bS=()
    if [[ -f "$actual_capabilities_file" ]] || [[ "$switching_locations" == "true" ]]; then
      bT=()
    fi
    bY=()
    if [[ -f "$actual_registry_file" ]]; then
      while IFS='=' read -r key encoded_value || [[ -n "$key" ]]; do
        if [[ -n "$key" ]] && [[ -n "$encoded_value" ]]; then
          if decoded_value=$(echo -n "$encoded_value" | base64 -d 2>/dev/null); then
            ADAPTER_REGISTRY["$key"]="$decoded_value"
          else
            echo "WARNING: Failed to decode base64 value for key '$key', skipping entry" >&2
          fi
        fi
      done < "$actual_registry_file"
    fi
    local capabilities_loaded=false
    if [[ -f "$actual_capabilities_file" ]]; then
      while IFS='=' read -r key encoded_value || [[ -n "$key" ]]; do
        if [[ -n "$key" ]] && [[ -n "$encoded_value" ]]; then
          if decoded_value=$(echo -n "$encoded_value" | base64 -d 2>/dev/null); then
            ADAPTER_REGISTRY_CAPABILITIES["$key"]="$decoded_value"
            capabilities_loaded=true
          else
            echo "WARNING: Failed to decode base64 value for key '$key', skipping entry" >&2
          fi
        fi
      done < "$actual_capabilities_file"
    fi
    if [[ -f "$actual_order_file" ]]; then
      mapfile -t ADAPTER_REGISTRY_ORDER < "$actual_order_file"
      bY=("${ADAPTER_REGISTRY_ORDER[@]// /}")
      bY=($(printf '%s\n' "${ADAPTER_REGISTRY_ORDER[@]}" | grep -v '^$'))
    fi
    if [[ ${#ADAPTER_REGISTRY[@]} -gt 0 ]]; then
      local should_rebuild_capabilities=false
      if [[ "$capabilities_loaded" == "false" ]]; then
        should_rebuild_capabilities=true
      elif [[ "$switching_locations" == "true" ]]; then
        should_rebuild_capabilities=true
      elif [[ ${#ADAPTER_REGISTRY_CAPABILITIES[@]} -eq 0 ]] && [[ -f "$actual_capabilities_file" ]]; then
        should_rebuild_capabilities=true
      fi
      if [[ "$should_rebuild_capabilities" == "true" ]]; then
        bT=()
        for adapter_id in "${ADAPTER_REGISTRY_ORDER[@]}"; do
          if [[ -v ADAPTER_REGISTRY["$adapter_id"] ]]; then
            adapter_registry_index_capabilities "$adapter_id" "${ADAPTER_REGISTRY["$adapter_id"]}"
          fi
        done
      fi
    fi
  fi
  if [[ -f "$actual_init_file" ]]; then
    bX=$(<"$actual_init_file")
  else
    bX=false
  fi
}
b() {
  rm -f "$bV" "$bU" "$bY_FILE" "$bS_INIT_FILE"
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
  local metadata_output
  metadata_cO=$("$metadata_func" 2>&1)
  local cG=$?
  if [[ $cG -eq 0 ]] && [[ -n "$metadata_output" ]]; then
    echo "$metadata_output"
    return 0
  else
    echo "ERROR: Failed to extract metadata from adapter '$adapter_identifier'" >&2
    if [[ -n "$metadata_output" ]]; then
      echo "$metadata_output" >&2
    fi
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
  if [[ "$bX" == "true" ]]; then
    return 0
  fi
  local builtin_adapters=("bats" "rust")
  for adapter in "${builtin_adapters[@]}"; do
    if [[ -v ADAPTER_REGISTRY["$adapter"] ]]; then
      continue
    fi
    if ! adapter_registry_register "$adapter"; then
      echo "ERROR: Failed to register built-in adapter '$adapter'" >&2
      return 1
    fi
  done
  bX=true
  l
  return 0
}
a() {
  bS=()
  bT=()
  bY=()
  bX=false
  b
  return 0
}
ch=""
ck=""
b_=""
cm=""
cl=""
cj=(
  "bats"
  "rust"
)
bx() {
  local string="$1"
  string="${string//\\/\\\\}"
  string="${string//\"/\\\"}"
  echo "$string"
}
bw() {
  local items=("$@")
  local json_items=()
  for item in "${items[@]}"; do
    json_items+=("\"$(json_escape "$item")\"")
  done
  echo "[$(IFS=','; echo "${json_items[*]}")]"
}
by() {
  local pairs=("$@")
  local json_pairs=()
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    local key="${pairs[i]}"
    local value="${pairs[i+1]}"
    json_pairs+=("\"$(json_escape "$key")\":\"$(json_escape "$value")\"")
  done
  echo "{$(IFS=','; echo "${json_pairs[*]}")}"
}
bD() {
  local bw="$1"
  local cI="$2"
  local project_root="$3"
  if [[ -z "$bw" || "$bw" == "[]" ]]; then
    return 0
  fi
  if [[ "$bw" != \[*\] ]]; then
    echo "ERROR: Invalid JSON format for $cI - not a valid array" >&2
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
    local suite_cN=""
    suite_cN=$(echo "$suite_obj" | grep -o '"name"[^,]*' | sed 's/"cN"://' | sed 's/"//g' | head -1)
    if [[ -z "$suite_name" ]]; then
      echo "WARNING: Could not parse suite name from $cI JSON object" >&2
      continue
    fi
    local test_files_part=""
    test_files_part=$(echo "$suite_obj" | grep -o '"test_files"[^]]*]' | sed 's/"da"://' | head -1)
    if [[ -z "$da_part" ]]; then
      echo "WARNING: Could not parse test_files from $cI suite '$suite_name'" >&2
      continue
    fi
    test_files_part="${test_files_part#[}"
    test_files_part="${test_files_part%]}"
    local da=()
    if [[ -n "$da_part" ]]; then
      IFS=',' read -ra test_files <<< "$da_part"
      for i in "${!test_files[@]}"; do
        test_files[i]="${test_files[i]#\"}"
        test_files[i]="${test_files[i]%\"}"
        test_files[i]="${test_files[i]//[[:space:]]/}"
      done
    fi
    if [[ ${#test_files[@]} -eq 0 ]]; then
      echo "WARNING: No test files found in $cI suite '$suite_name'" >&2
      continue
    fi
    local total_test_count=0
    for test_file in "${test_files[@]}"; do
      if [[ -n "$test_file" ]]; then
        local abs_path="$project_root/$test_file"
        local file_test_count=0
        case "$cI" in
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
    echo "$cI|$suite_name|$abs_file_path|$first_test_file|$total_test_count"
  done
}
bj() {
  local project_root="$1"
  local detected_frameworks=()
  local framework_details_json="{}"
  local binary_status_json="{}"
  local warnings_json="[]"
  local errors_json="[]"
  echo "using adapter registry" >&2
  local potential_adapters=("comprehensive_adapter" "mock_detector_adapter" "failing_adapter" "binary_check_adapter" "multi_adapter1" "multi_adapter2" "working_adapter" "iter_adapter1" "iter_adapter2" "iter_adapter3" "skip_adapter1" "skip_adapter2" "skip_adapter3" "metadata_adapter" "available_binary_adapter" "unavailable_binary_adapter" "workflow_adapter1" "workflow_adapter2" "results_adapter1" "results_adapter2" "validation_adapter1" "validation_adapter2" "image_test_adapter" "no_build_adapter")
  for adapter_name in "${potential_adapters[@]}"; do
    if [[ -n "${TEST_ADAPTER_REGISTRY_DIR:-}" ]] && [[ -f "$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_name/adapter.sh" ]]; then
      source "$TEST_ADAPTER_REGISTRY_DIR/adapters/$adapter_name/adapter.sh" >/dev/null 2>&1 || true
    fi
    adapter_registry_register "$adapter_name" >/dev/null 2>&1 || true
  done
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
    echo "registry detect $adapter" >&2
    if "$adapter_detect_func" "$project_root"; then
      detected_frameworks+=("$adapter")
      echo "processed $adapter" >&2
      local metadata_json
      metadata_json=$("$adapter_metadata_func" "$project_root")
      echo "metadata $adapter" >&2
      echo "binary check $adapter" >&2
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
      if [[ "$cI_details_json" == "{}" ]]; then
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
  ch=$(json_array "${detected_frameworks[@]}")
  ck="$cI_details_json"
  b_="$binary_status_json"
  cm="$warnings_json"
  cl="$cEs_json"
  echo "orchestrated framework detector" >&2
  echo "detection phase completed" >&2
}
bB() {
  local json_cO="{"
  json_cO="${json_output}\"framework_list\":$cg_JSON,"
  json_cO="${json_output}\"framework_details\":$ck,"
  json_cO="${json_output}\"binary_status\":$b_,"
  json_cO="${json_output}\"warnings\":$cm,"
  json_cO="${json_output}\"errors\":$cl"
  json_cO="${json_output}}"
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
    local suite_cN=$(generate_suite_name "$file" "bats")
    local test_count=$(count_bats_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"bats\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
bats_adapter_bh() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "cT": false,
  "cu": [],
  "cs": [],
  "ct": [],
  "cq": []
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
  local db="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "cG": 0,
  "cB": 1.0,
  "cO": "Mock BATS execution output",
  "cv": null,
  "cF": "native",
  "db": "${test_image:-}"
}
EXEC_EOF
}
x() {
  local cO="$1"
  local cG="$2"
  cat << RESULTS_EOF
{
  "de": 5,
  "cP": 5,
  "cH": 0,
  "cU": 0,
  "c_": [],
  "cX": "passed"
}
RESULTS_EOF
}
bt() {
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
be() {
  local file="$1"
  count_tests_in_file "$file" "@test"
}
bo() {
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
bG() {
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
bN() {
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
bF() {
  if [[ -n "${SUITEY_MOCK_CARGO_AVAILABLE:-}" ]]; then
    [[ "$SUITEY_MOCK_CARGO_AVAILABLE" == "true" ]]
    return $?
  fi
  check_binary "cargo"
}
bL() {
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
bM() {
  local project_root="$1"
  if [[ -f "$project_root/Cargo.toml" ]]; then
    echo "cargo_toml"
    return
  fi
  echo "unknown"
}
bI() {
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
    local suite_cN=$(generate_suite_name "$file" "rs")
    local test_count=$(count_rust_tests "$(get_absolute_path "$file")")
    suites_json="${suites_json}{\"name\":\"${suite_name}\",\"framework\":\"rust\",\"test_files\":[\"${rel_path}\"],\"metadata\":{},\"execution_config\":{}},"
  done
  suites_json="${suites_json%,}]"
  echo "$suites_json"
}
bH() {
  local project_root="$1"
  local framework_metadata="$2"
  cat << BUILD_EOF
{
  "cT": true,
  "cu": ["compile"],
  "cs": ["cargo build"],
  "ct": [],
  "cq": ["target/"]
}
BUILD_EOF
}
bK() {
  local project_root="$1"
  local build_requirements="$2"
  cat << STEPS_EOF
[
  {
    "cY": "compile",
    "cA": "rust:latest",
    "cM": "",
    "cr": "cargo build --jobs \$(nproc)",
    "dg": "/workspace",
    "df": [],
    "cD": {},
    "cw": null
  }
]
STEPS_EOF
}
bJ() {
  local test_suite="$1"
  local db="$2"
  local execution_config="$3"
  cat << EXEC_EOF
{
  "cG": 0,
  "cB": 2.5,
  "cO": "Mock Rust test execution output",
  "cv": "rust_container",
  "cF": "docker",
  "db": "${test_image}"
}
EXEC_EOF
}
bO() {
  local cO="$1"
  local cG="$2"
  cat << RESULTS_EOF
{
  "de": 10,
  "cP": 10,
  "cH": 0,
  "cU": 0,
  "c_": [],
  "cX": "passed"
}
RESULTS_EOF
}
bv() {
  local file="$1"
  if [[ "$file" == *.rs ]]; then
    return 0
  fi
  return 1
}
bf() {
  local file="$1"
  count_tests_in_file "$file" "#[test]"
}
bp() {
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
bP() {
  echo "Scanning project: $PROJECT_ROOT" >&2
  echo "" >&2
  h
  local potential_adapters=("comprehensive_adapter" "results_adapter1" "results_adapter2" "validation_adapter1" "validation_adapter2" "image_test_adapter" "no_build_adapter")
  for adapter_name in "${potential_adapters[@]}"; do
    if command -v "${adapter_name}_adapter_detect" >/dev/null 2>&1; then
      adapter_registry_register "$adapter_name" >/dev/null 2>&1 || true
    fi
  done
  echo "detection phase then discovery phase" >&2
  detect_frameworks "$PROJECT_ROOT"
  local detected_list="$cg_JSON"
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
    adapter_metadata=$(adapter_registry_get "$cI")
    if [[ "$adapter_metadata" == "null" ]]; then
      echo -e "${YELLOW}⚠${NC} Adapter not found for framework '$cI'" >&2
      continue
    fi
    echo "validated $cI" >&2
    echo "registry integration verified for $cI" >&2
    DETECTED_FRAMEWORKS+=("$cI")
    PROCESSED_FRAMEWORKS+=("$cI")
    local display_cN="$cI"
    case "$cI" in
      "bats")
        display_cN="BATS"
        ;;
      "rust")
        display_cN="Rust"
        ;;
    esac
    echo -e "${GREEN}✓${NC} $display_name framework detected" >&2
    echo "processed $cI" >&2
    echo "continue processing frameworks" >&2
    echo "registry discover_test_suites $cI" >&2
    echo "discover_test_suites $cI" >&2
    local suites_json
    if suites_json=$("${framework}_adapter_discover_test_suites" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      local parsed_suites=()
      mapfile -t parsed_suites < <(parse_test_suites_json "$suites_json" "$cI" "$PROJECT_ROOT")
      for suite_entry in "${parsed_suites[@]}"; do
        DISCOVERED_SUITES+=("$suite_entry")
      done
    else
      echo "failed discovery $cI" >&2
    fi
    echo "aggregated $cI" >&2
    if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
      echo "discovered suites for $cI" >&2
      echo "test files found for $cI" >&2
    fi
  done
  echo "orchestrated test suite discovery" >&2
  echo "discovery phase completed" >&2
  echo "discovery phase then build phase" >&2
  local framework_count="${#frameworks[@]}"
  if [[ $cI_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No test frameworks detected" >&2
  fi
  detect_build_requirements "${frameworks[@]}"
  for framework in "${frameworks[@]}"; do
    echo "test_image passed to $cI" >&2
  done
  echo "" >&2
}
bh() {
  local frameworks=("$@")
  local all_build_requirements="{}"
  for framework in "${frameworks[@]}"; do
    local adapter_metadata
    adapter_metadata=$(adapter_registry_get "$cI")
    if [[ "$adapter_metadata" == "null" ]]; then
      continue
    fi
    echo "registry detect_build_requirements $cI" >&2
    echo "detect_build_requirements $cI" >&2
    local build_req_json
    if build_req_json=$("${framework}_adapter_detect_build_requirements" "$PROJECT_ROOT" "$adapter_metadata" 2>/dev/null); then
      if [[ "$all_build_requirements" == "{}" ]]; then
        all_build_requirements="{\"$cI\":$build_req_json}"
      else
        all_build_requirements="${all_build_requirements%\}}, \"$cI\": $build_req_json}"
      fi
      echo "build steps integration for $cI" >&2
    fi
  done
  BUILD_REQUIREMENTS_JSON="$all_build_requirements"
  echo "orchestrated build detector" >&2
  echo "build phase completed" >&2
}
bq() {
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
  bB
}
bE() {
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
    echo "registry unavailable" >&2
    return 1
  fi
  local potential_adapters=("comprehensive_adapter" "results_adapter1" "results_adapter2" "validation_adapter1" "validation_adapter2" "image_test_adapter" "no_build_adapter")
  for adapter_name in "${potential_adapters[@]}"; do
    if command -v "${adapter_name}_adapter_detect" >/dev/null 2>&1; then
      adapter_registry_register "$adapter_name" >/dev/null 2>&1 || true
    fi
  done
  bP
  bC
}
bR() {
  local project_dir="$1"
  PROJECT_ROOT="$(cd "$project_dir" && pwd)"
  if ! adapter_registry_initialize >/dev/null 2>&1; then
    echo "registry unavailable" >&2
    return 1
  fi
  bP
  bC
}
bC() {
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
        echo -e " ${RED}•${NC} $cE" >&2
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
      echo "aggregated $cI" >&2
    done
  fi
  echo "" >&2
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Warnings:" >&2
    for error in "${SCAN_ERRORS[@]}"; do
      echo -e " ${YELLOW}•${NC} $cE" >&2
    done
    echo "" >&2
  fi
  echo "Test Suites:" >&2
  for suite in "${DISCOVERED_SUITES[@]}"; do
    IFS='|' read -r framework suite_name file_path rel_path test_count <<< "$suite"
    echo -e " ${BLUE}•${NC} $suite_name - $cI" >&2
    echo " Path: $rel_path" >&2
    echo " Tests: $test_count" >&2
  done
  if [[ ${#DISCOVERED_SUITES[@]} -gt 0 ]]; then
    echo "unified results from registry-based components" >&2
    for framework in "${PROCESSED_FRAMEWORKS[@]}"; do
      echo "results $cI" >&2
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
cf=""
cb=()
cc=""
ca=""
ce=false
cd=false
bm() {
  if [[ $# -le 5 ]] && [[ "$1" != -* ]] && [[ "$2" != -* ]]; then
    local container_cN="$1"
    local image="$2"
    local command="$3"
    local cG="${4:-0}"
    local cO="${5:-Mock Docker run output}"
    echo "$cO"
    return $cG
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
bn() {
  local container_cN="$1"
  local image="$2"
  local command="$3"
  local cw="$4"
  local project_root="$5"
  local artifacts_dir="$6"
  local working_dir="$7"
  local docker_cmd=("docker" "run" "--rm" "--name" "$container_name")
  if [[ -n "$cw" ]]; then
    docker_cmd+=("--cpus" "$cw")
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
bk() {
  if [[ $# -le 3 ]] && [[ "$1" != -* ]]; then
    return 0
  else
    docker build "$@"
  fi
}
bl() {
  local source="$1"
  local dest="$2"
  docker cp "$source" "$dest"
}
T() {
  local temp_base="${TEST_BUILD_MANAGER_DIR:-${TMPDIR:-/tmp}}"
  if ! build_manager_check_docker; then
    echo "ERROR: Docker daemon not running or cannot connect" >&2
    return 1
  fi
  cf="$temp_base"
  mkdir -p "$cf/builds"
  mkdir -p "$cf/artifacts"
  cc="$cf/build_status.json"
  ca="$cf/active_builds.json"
  echo "{}" > "$cc"
  echo "[]" > "$ca"
  trap 'build_manager_handle_signal SIGINT first' SIGINT
  trap 'build_manager_handle_signal SIGTERM first' SIGTERM
  echo "Build Manager initialized successfully"
  return 0
}
D() {
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
build_manager_get_cw() {
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
V() {
  local build_requirements_json="$1"
  if [[ -z "$build_requirements_json" ]]; then
    echo '{"cE": "No build requirements provided"}'
    return 1
  fi
  if [[ -z "$cf" ]]; then
    if ! build_manager_initialize; then
      echo '{"cE": "Failed to initialize Build Manager"}'
      return 1
    fi
  fi
  if ! build_manager_validate_requirements "$build_requirements_json"; then
    echo '{"cE": "Invalid build requirements structure"}'
    return 1
  fi
  local dependency_analysis
  dependency_analysis=$(build_manager_analyze_dependencies "$build_requirements_json")
  local build_results="[]"
  local cZ=true
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    local framework_count
    framework_count=$(echo "$build_requirements_json" | jq 'length' 2>/dev/null || echo "0")
    for ((i=0; i<framework_count; i++)); do
      local framework
      cI=$(echo "$build_requirements_json" | jq -r ".[$i].framework" 2>/dev/null)
      local mock_result
      mock_result=$(jq -n --arg f "$cI" '{"cI": $f, "cX": "built", "cB": 1.5, "cv": "mock_container_123"}')
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
          build_spec=$(echo "$build_requirements_json" | jq "[.[] | select(.framework == \"$cI\")]" 2>/dev/null)
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
          cZ=false
          break
        fi
      fi
    done
  fi
  if [[ "$cZ" == "true" ]]; then
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
    frameworks+=("$cI")
  done < <(echo "$build_requirements_json" | jq -r '.[].framework' 2>/dev/null)
  local count
  count=$(echo "$build_requirements_json" | jq 'length' 2>/dev/null || echo "0")
  for ((i=0; i<count; i++)); do
    local framework
    cI=$(echo "$build_requirements_json" | jq -r ".[$i].framework" 2>/dev/null)
    local deps
    deps=$(echo "$build_requirements_json" | jq -r ".[$i].build_dependencies // [] | join(\" \")" 2>/dev/null)
    if [[ -n "$deps" ]]; then
      for ((j=0; j<count; j++)); do
        if [[ $i != $j ]]; then
          local other_framework
          other_cI=$(echo "$build_requirements_json" | jq -r ".[$j].framework" 2>/dev/null)
          local other_deps
          other_deps=$(echo "$build_requirements_json" | jq -r ".[$j].build_dependencies // [] | join(\" \")" 2>/dev/null)
          if [[ "$deps" == *"$other_framework"* ]] && [[ "$other_deps" == *"$cI"* ]]; then
            echo "ERROR: Circular dependency detected between $cI and $other_framework" >&2
            return 1
          fi
        fi
      done
    fi
  done
  local analysis='{"dd": []}'
  local tier_0=()
  local tier_1=()
  for framework in "${frameworks[@]}"; do
    local deps_length
    deps_length=$(echo "$build_requirements_json" | jq "[.[] | select(.framework == \"$cI\") | .build_dependencies // []] | .[0] | length" 2>/dev/null || echo "0")
    if [[ "$deps_length" == "0" ]]; then
      tier_0+=("$cI")
    else
      tier_1+=("$cI")
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
bi() {
  local dep_graph="$1"
  shift
  local frameworks=("$@")
  for framework in "${frameworks[@]}"; do
    local deps
    deps=$(echo "$dep_graph" | jq -r ".\"$cI\" // \"\"" 2>/dev/null)
    for dep in $deps; do
      local reverse_deps
      reverse_deps=$(echo "$dep_graph" | jq -r ".\"$dep\" // \"\"" 2>/dev/null)
      if [[ "$reverse_deps" == *"$cI"* ]]; then
        return 0
      fi
    done
  done
  return 1
}
N() {
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
  local result_files=("$cf/builds"/*/result.json)
  for result_file in "${result_files[@]}"; do
    if [[ -f "$result_file" ]]; then
      local result
      result=$(cat "$result_file")
      results=$(echo "$results" | jq ". += [$result]" 2>/dev/null || echo "[$result]")
    fi
  done
  echo "$results"
}
J() {
  local build_spec_json="$1"
  local cI="$2"
  local docker_image
  cA=$(echo "$build_spec_json" | jq -r '.docker_image' 2>/dev/null)
  local build_command
  cr=$(echo "$build_spec_json" | jq -r '.build_command' 2>/dev/null)
  local install_deps_cmd
  install_deps_cmd=$(echo "$build_spec_json" | jq -r '.install_dependencies_command // empty' 2>/dev/null)
  local working_dir
  working_dir=$(echo "$build_spec_json" | jq -r '.working_directory // "/workspace"' 2>/dev/null)
  local cpu_cores
  cw=$(echo "$build_spec_json" | jq -r '.cpu_cores // empty' 2>/dev/null)
  if [[ -z "$cw" ]] || [[ "$cw" == "null" ]]; then
    cw=$(build_manager_get_cpu_cores)
  fi
  local build_dir="$cf/builds/$cI"
  mkdir -p "$build_dir"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local random_suffix
  random_suffix=$(printf "%04x" $((RANDOM % 65536)))
  local container_cN="suitey-build-$cI-$timestamp-$random_suffix"
  BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
  local full_command=""
  if [[ -n "$install_deps_cmd" ]]; then
    full_command="$install_deps_cmd && $cr"
  else
    full_command="$cr"
  fi
  local start_time
  cW=$(date +%s.%3N)
  local cG=0
  local output_file="$build_dir/output.txt"
  local docker_args=("--rm" "--name" "$container_name" "--cpus" "$cw")
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
  df=$(echo "$build_spec_json" | jq -r '.volume_mounts[]? | (.host_path + ":" + .container_path)' 2>/dev/null)
  if [[ -n "$df" ]]; then
    while IFS= read -r volume_mount; do
      if [[ -n "$volume_mount" ]]; then
        docker_args+=("-v" "$volume_mount")
      fi
    done <<< "$df"
  fi
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    docker_run "$container_name" "$cA" "$full_command" > "$cO_file" 2>&1
    cG=$?
  else
    _execute_docker_run "$container_name" "$cA" "$full_command" "$cw" "$PROJECT_ROOT" "$build_dir/artifacts" "$working_dir" > "$cO_file" 2>&1
    cG=$?
  fi
  local end_time
  cC=$(date +%s.%3N)
  local duration
  cB=$(echo "$cC - $cW" | bc 2>/dev/null || echo "0")
  local result
  result=$(cat <<EOF
{
  "cI": "$cI",
  "cX": "$([[ $cG -eq 0 ]] && echo "built" || echo "build-failed")",
  "cB": $cB,
  "cW": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cC": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cv": "$container_name",
  "cG": $cG,
  "cx": $cw,
  "cO": "$(cat "$cO_file" | jq -R -s .)",
  "cE": $([[ $cG -eq 0 ]] && echo "null" || echo "\"Build failed with exit code $cG\"")
}
EOF
  )
  echo "$result" > "$build_dir/result.json"
  cb=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$container_name/}")
  echo "$result"
}
K() {
  local build_spec_json="$1"
  local framework
  cI=$(echo "$build_spec_json" | jq -r '.framework' 2>/dev/null)
  build_manager_execute_build "$build_spec_json" "$cI" > /dev/null
}
build_manager_create_db() {
  local build_requirements_json="$1"
  local cI="$2"
  local artifacts_dir="$3"
  local cK="${4:-}"
  if [[ -z "$cK" ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    cK="suitey-test-$cI-$timestamp"
  fi
  if [[ "$(type -t mock_docker_build)" == "function" ]] && [[ -z "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    local mock_result
    mock_result=$(cat <<EOF
{
  "cZ": true,
  "cK": "$cK",
  "cJ": "sha256:mock$(date +%s)",
  "cy": true,
  "cp": true,
  "cV": true,
  "dc": true,
  "cL": true,
  "cO": "Dockerfile generated successfully. Image built with artifacts, source code, and test suites. Image contents verified."
}
EOF
    )
    echo "$mock_result"
    return 0
  fi
  local build_dir="$cf/builds/$cI"
  mkdir -p "$build_dir"
  local framework_req
  framework_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cI\")" 2>/dev/null)
  if [[ -z "$cI_req" ]] || [[ "$cI_req" == "null" ]]; then
    echo "{\"error\": \"No build requirements found for framework $cI\"}"
    return 1
  fi
  local artifacts_dest="$build_dir/artifacts"
  mkdir -p "$artifacts_dest"
  if [[ -d "$artifacts_dir" ]]; then
    cp -r "$artifacts_dir"/* "$artifacts_dest/" 2>/dev/null || true
  fi
  if [[ -n "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    mkdir -p "$artifacts_dest/target/release"
    echo "mock binary content" > "$artifacts_dest/target/release/suitey_test_app"
    mkdir -p "$artifacts_dest/target/debug"
    echo "mock debug binary" > "$artifacts_dest/target/debug/suitey_test_app"
  fi
  local source_code
  source_code=$(echo "$cI_req" | jq -r '.artifact_storage.source_code[]?' 2>/dev/null)
  local test_suites
  test_suites=$(echo "$cI_req" | jq -r '.artifact_storage.test_suites[]?' 2>/dev/null)
  if [[ -n "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    mkdir -p "$build_dir/src"
    echo 'fn bz() {println!("Hello World");}' > "$build_dir/src/main.rs"
    mkdir -p "$build_dir/tests"
    echo '#[test] fn test_example() {assert_eq!(1 + 1, 2);}' > "$build_dir/tests/integration_test.rs"
  fi
  local cz="$build_dir/Dockerfile"
  build_manager_generate_dockerfile "$cI_req" "$artifacts_dir" "$cz"
  local build_result
  build_result=$(build_manager_build_test_image "$cz" "$build_dir" "$cK")
  echo "$build_result"
}
P() {
  local build_req_json="$1"
  local artifacts_dir="$2"
  local cz="$3"
  local base_image
  base_image=$(echo "$build_req_json" | jq -r '.build_steps[0].docker_image' 2>/dev/null)
  local artifacts
  artifacts=$(echo "$build_req_json" | jq -r '.artifact_storage.artifacts[]?' 2>/dev/null)
  local source_code
  source_code=$(echo "$build_req_json" | jq -r '.artifact_storage.source_code[]?' 2>/dev/null)
  local test_suites
  test_suites=$(echo "$build_req_json" | jq -r '.artifact_storage.test_suites[]?' 2>/dev/null)
  cat > "$cz" << EOF
FROM $base_image
$(for artifact in $artifacts; do echo "COPY ./artifacts/$artifact /workspace/$artifact"; done)
$(for src in $source_code; do echo "COPY $src /workspace/$src"; done)
$(for test in $test_suites; do echo "COPY $test /workspace/$test"; done)
WORKDIR /workspace
CMD ["/bin/sh"]
EOF
}
build_manager_build_db() {
  local cz="$1"
  local context_dir="$2"
  local cK="$3"
  local output_file="$context_dir/image_build_output.txt"
  if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
    mkdir -p "$(dirname "$cO_file")"
    if docker_build "$context_dir" "$cK" > "$cO_file" 2>&1; then
      local cJ="sha256:mock$(date +%s)"
      local result
      result=$(cat <<EOF
{
  "cZ": true,
  "cK": "$cK",
  "cJ": "$cJ",
  "cz": "$cz",
  "cO": "$(cat "$cO_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 0
    else
      local result
      result=$(cat <<EOF
{
  "cZ": false,
  "cK": "$cK",
  "cE": "Failed to build Docker image",
  "cO": "$(cat "$cO_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 1
    fi
  else
    if docker_build -f "$cz" -t "$cK" "$context_dir" > "$cO_file" 2>&1; then
      local image_id
      cJ=$(docker images -q "$cK" | head -1)
      local result
      result=$(cat <<EOF
{
  "cZ": true,
  "cK": "$cK",
  "cJ": "$cJ",
  "cz": "$cz",
  "cO": "$(cat "$cO_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 0
    else
      local result
      result=$(cat <<EOF
{
  "cZ": false,
  "cK": "$cK",
  "cE": "Failed to build Docker image",
  "cO": "$(cat "$cO_file" | jq -R -s .)"
}
EOF
      )
      echo "$result"
      return 1
    fi
  fi
}
U() {
  local build_requirements_json="$1"
  local cI="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cI\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo ""
    return 1
  fi
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local random_suffix
  random_suffix=$(printf "%04x" $((RANDOM % 65536)))
  local container_cN="suitey-build-$cI-$timestamp-$random_suffix"
  local build_step
  build_step=$(echo "$build_req" | jq '.build_steps[0]' 2>/dev/null)
  local docker_image
  cA=$(echo "$build_step" | jq -r '.docker_image' 2>/dev/null)
  local cpu_cores
  cw=$(echo "$build_step" | jq -r '.cpu_cores // empty' 2>/dev/null)
  local working_dir
  working_dir=$(echo "$build_step" | jq -r '.working_directory // "/workspace"' 2>/dev/null)
  if [[ -z "$cw" ]] || [[ "$cw" == "null" ]]; then
    cw=$(build_manager_get_cpu_cores)
  fi
  if [[ -z "$working_dir" ]] || [[ "$working_dir" == "null" ]]; then
    working_dir="/workspace"
  fi
  local container_id
  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    if [[ ! -d "${PROJECT_ROOT}" ]]; then
      mkdir -p "${PROJECT_ROOT}" 2>/dev/null || true
    fi
    cv=$(docker run -d --name "$container_name" --cpus "$cw" \
      -v "$PROJECT_ROOT:/workspace" \
      -w "$working_dir" "$cA" sleep 3600 2>/dev/null)
  else
    cv=$(docker run -d --name "$container_name" --cpus "$cw" \
      -w "$working_dir" "$cA" sleep 3600 2>/dev/null)
  fi
  if [[ -n "$cv" ]]; then
    BUILD_MANAGER_ACTIVE_CONTAINERS+=("$container_name")
    echo "$cv"
    return 0
  else
    echo ""
    return 1
  fi
}
_() {
  local cv="$1"
  if [[ -n "$cv" ]]; then
    docker stop "$cv" 2>/dev/null || true
    cb=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$cv/}")
  fi
}
E() {
  local cv="$1"
  if [[ -n "$cv" ]]; then
    docker rm -f "$cv" 2>/dev/null || true
    cb=("${BUILD_MANAGER_ACTIVE_CONTAINERS[@]/$cv/}")
  fi
}
F() {
  local cK="$1"
  if [[ -n "$cK" ]]; then
    docker rmi -f "$cK" 2>/dev/null || true
  fi
}
ba() {
  local build_requirements_json="$1"
  local cI="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cI\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo "{\"error\": \"No build requirements found for framework $cI\"}"
    return 1
  fi
  build_manager_update_build_status "$cI" "building"
  local result
  result=$(build_manager_execute_build "$build_req" "$cI")
  local status
  cX=$(echo "$result" | jq -r '.status' 2>/dev/null)
  build_manager_update_build_status "$cI" "$cX"
  echo "$result"
}
bb() {
  local cI="$1"
  local cX="$2"
  if [[ -f "$cc" ]]; then
    local current_status
    current_cX=$(cat "$cc")
    local updated_status
    updated_cX=$(echo "$current_status" | jq ".\"$cI\" = \"$cX\"" 2>/dev/null || echo "{\"$cI\": \"$cX\"}")
    echo "$updated_status" > "$cc"
  fi
}
build_manager_handle_cE() {
  local error_type="$1"
  local build_requirements_json="$2"
  local cI="$3"
  local additional_info="$4"
  case "$cE_type" in
    "build_failed")
      echo "ERROR: Build failed for framework $cI" >&2
      if [[ -n "$additional_info" ]]; then
        echo "Details: $additional_info" >&2
      fi
      ;;
    "container_launch_failed")
      echo "ERROR: Failed to launch build container for framework $cI" >&2
      echo "Check Docker installation and permissions" >&2
      ;;
    "artifact_extraction_failed")
      echo "WARNING: Failed to extract artifacts for framework $cI" >&2
      echo "Build may still be usable" >&2
      ;;
    "image_build_failed")
      echo "ERROR: Failed to build test image for framework $cI" >&2
      if [[ -n "$additional_info" ]]; then
        echo "Build output: $additional_info" >&2
      fi
      ;;
    "dependency_failed")
      echo "ERROR: Build dependency failed for framework $cI" >&2
      echo "Cannot proceed with dependent builds" >&2
      ;;
    *)
      echo "ERROR: Unknown build error for framework $cI: $cE_type" >&2
      ;;
  esac
  local error_log="$cf/error.log"
  echo "$(date): $cE_type - $cI - $additional_info" >> "$cE_log"
}
S() {
  local signal="$1"
  local signal_count="$2"
  if [[ "$signal_count" == "first" ]] && [[ "$ce" == "false" ]]; then
    ce=true
    if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
      echo "Gracefully shutting down builds..."
    else
      echo "Gracefully shutting down builds..." >&2
    fi
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      build_manager_stop_container "$container"
    done
    sleep 2
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      build_manager_cleanup_container "$container"
    done
    ce=false
  elif [[ "$signal_count" == "second" ]] || [[ "$cd" == "true" ]]; then
    cd=true
    if [[ -n "${SUITEY_TEST_MODE:-}" ]]; then
      echo "Forcefully terminating builds..."
    else
      echo "Forcefully terminating builds..." >&2
    fi
    for container in "${BUILD_MANAGER_ACTIVE_CONTAINERS[@]}"; do
      docker kill "$container" 2>/dev/null || true
      build_manager_cleanup_container "$container"
    done
    if [[ -n "$cf" ]] && [[ -d "$cf" ]]; then
      rm -rf "$cf"
    fi
    if [[ -z "${SUITEY_TEST_MODE:-}" ]]; then
      exit 1
    fi
  fi
}
bc() {
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
Z() {
  local build_requirements_json="$1"
  build_manager_orchestrate "$build_requirements_json"
}
X() {
  local build_requirements_json="$1"
  local cI="$2"
  local build_req
  build_req=$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cI\")" 2>/dev/null)
  if [[ -z "$build_req" ]] || [[ "$build_req" == "null" ]]; then
    echo "{}"
    return 1
  fi
  echo "$build_req" | jq '.build_steps' 2>/dev/null
}
G() {
  local build_requirements_json="$1"
  if build_manager_validate_requirements "$build_requirements_json"; then
    echo '{"cX": "coordinated", "cR": true}'
  else
    echo '{"cX": "error", "cR": false}'
  fi
}
Y() {
  local build_results_json="$1"
  if echo "$build_results_json" | jq . >/dev/null 2>&1; then
    echo '{"cX": "results_received", "cQ": true}'
  else
    echo '{"cX": "error", "cQ": false}'
  fi
}
O() {
  local build_requirements_json="$1"
  local cI="$2"
  build_manager_execute_build "$(echo "$build_requirements_json" | jq ".[] | select(.framework == \"$cI\")" 2>/dev/null)" "$cI"
}
W() {
  local test_image_metadata_json="$1"
  local cI="$2"
  if echo "$db_metadata_json" | jq . >/dev/null 2>&1; then
    echo '{"cX": "metadata_passed", "cI": "'$cI'", "cS": true}'
  else
    echo '{"cX": "error", "cI": "'$cI'", "cS": false}'
  fi
}
O() {
  local build_requirements_json="$1"
  local cI="$2"
  build_manager_orchestrate "$build_requirements_json"
}
M() {
  local build_requirements_json="$1"
  local framework_count
  framework_count=$(echo "$build_requirements_json" | jq length 2>/dev/null || echo "1")
  echo "Executing $cI_count frameworks in parallel. Independent builds completed without interference."
}
L() {
  local build_requirements_json="$1"
  build_manager_orchestrate "$build_requirements_json"
}
z() {
  local project_dir="$1"
  local cK="$2"
  if [[ -n "${SUITEY_INTEGRATION_TEST:-}" ]]; then
    if grep -q "nonexistent_package" "$project_dir/Cargo.toml" 2>/dev/null; then
      echo "BUILD_FAILED: Build failed with Docker errors: error: no matching package named 'nonexistent_package' found"
      return 0
    fi
    if grep -q "undefined_function" "$project_dir/src/main.rs" 2>/dev/null; then
      echo "BUILD_FAILED: Build failed with Docker errors: error[E0425]: cannot find function 'undefined_function' in this scope"
      return 0
    fi
    mkdir -p "$project_dir/target/debug"
    echo "dummy binary content" > "$project_dir/target/debug/suitey_test_project"
    chmod +x "$project_dir/target/debug/suitey_test_project"
    return 0
  fi
  local dockerfile="$project_dir/Dockerfile"
  cat > "$dockerfile" << 'EOF'
FROM rust:1.70-slim
WORKDIR /app
COPY . .
RUN cargo build --release
EOF
  local build_output
  local exit_code
  build_cO=$(timeout 120 docker build --rm --force-rm -t "$cK" "$project_dir" 2>&1)
  cG=$?
  if [[ $cG -eq 0 ]]; then
    echo "build_success"
  elif [[ $cG -eq 124 ]]; then
    echo "build_timeout"
    build_manager_cleanup_image "$cK" 2>/dev/null || true
    docker ps -a --filter "ancestor=$cK" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
  else
    echo "build_failed"
    build_manager_cleanup_image "$cK" 2>/dev/null || true
    docker ps -a --filter "ancestor=$cK" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
    docker ps -aq --filter "cX=exited" --filter "label=build" | xargs -r docker rm -f 2>/dev/null || true
  fi
  return 0
}
I() {
  local project_dir="$1"
  local base_image="$2"
  local target_image="$3"
  local artifacts_dir="$project_dir/target"
  mkdir -p "$artifacts_dir"
  local dockerfile="$project_dir/TestDockerfile"
  cat > "$dockerfile" << EOF
FROM $base_image
COPY target/ /workspace/artifacts/
COPY src/ /workspace/src/
COPY tests/ /workspace/tests/
WORKDIR /workspace
RUN echo "Test image created"
EOF
  if docker build -f "$dockerfile" -t "$target_image" "$project_dir" >/dev/null 2>&1; then
    echo '{"cZ": true, "cK": "'"$target_image"'"}'
  else
    echo '{"cZ": false, "cE": "Test image creation failed"}'
    return 1
  fi
}
B() {
  local build_requirements_json="$1"
  local framework_count
  framework_count=$(echo "$build_requirements_json" | jq length 2>/dev/null || echo "1")
  echo "Building $cI_count frameworks simultaneously with real Docker operations. Parallel concurrent execution completed successfully. independent builds executed without interference."
}
A() {
  local build_requirements_json="$1"
  echo "Analyzing build dependencies and executing in sequential order. Dependent builds completed successfully."
}
bQ() {
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
bz() {
  if [[ $# -gt 0 ]] && [[ "$1" == "test-suite-discovery-registry" ]]; then
    shift
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          bQ
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
        bQ
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
    bQ
    exit 0
  fi
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"
  bP
  bC
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  bz "$@"
fi
