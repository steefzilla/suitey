#!/bin/bash

# Build script for Suitey
# Compiles all source modules into a single suitey.sh file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
MINIFY=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--minify)
      MINIFY=true
      shift
      ;;
    -h|--help)
      cat << EOF
Usage: $0 [OPTIONS]

Build suitey.sh from source modules.

OPTIONS:
    -m, --minify    Create minified version (outputs to suitey.min.sh)
    -h, --help      Show this help message

EOF
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      echo "Run '$0 --help' for usage information." >&2
      exit 1
      ;;
  esac
done

# Set output file based on minify option
if [[ "$MINIFY" == "true" ]]; then
  OUTPUT_FILE="$SCRIPT_DIR/suitey.min.sh"
  MAP_FILE="$SCRIPT_DIR/suitey.min.map"
else
  OUTPUT_FILE="$SCRIPT_DIR/suitey.sh"
  MAP_FILE=""
fi

# Colors for output
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  NC=''
fi

# Name mapping for minification
declare -A NAME_MAP
declare -A REVERSE_MAP
NAME_COUNTER=0
VALID_CHARS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"

# Extract all names that need to be minified
extract_names() {
  local src_dir="$1"
  local names_file="$2"
  
  > "$names_file"
  
  # Find all function definitions
  while IFS= read -r file; do
    # Extract function names: function_name() {
    grep -hE '^[a-z_][a-z0-9_]*\(\)[[:space:]]*\{' "$file" 2>/dev/null | sed 's/().*$//' || true
    # Extract function names: function function_name {
    grep -hE '^function[[:space:]]+[a-z_][a-z0-9_]*' "$file" 2>/dev/null | sed 's/^function[[:space:]]*//' | sed 's/[[:space:]].*$//' || true
  done < <(find "$src_dir" -name "*.sh" -type f) | sort -u >> "$names_file"
  
  # Find all variable declarations (declare, local, export, readonly, etc.)
  while IFS= read -r file; do
    # Extract variable names from declarations
    grep -hE '^(declare|local|export|readonly)[[:space:]]+-[a-zA-Z]*[[:space:]]*[a-z_][a-z0-9_]*' "$file" 2>/dev/null | sed -E 's/^(declare|local|export|readonly)[[:space:]]+-[a-zA-Z]*[[:space:]]*//' | sed 's/[=[:space:]].*$//' || true
    grep -hE '^(declare|local|export|readonly)[[:space:]]+[a-z_][a-z0-9_]*' "$file" 2>/dev/null | sed -E 's/^(declare|local|export|readonly)[[:space:]]+//' | sed 's/[=[:space:]].*$//' || true
  done < <(find "$src_dir" -name "*.sh" -type f) | sort -u >> "$names_file"
  
  # Find all array/associative array declarations
  while IFS= read -r file; do
    grep -hE '^declare[[:space:]]+-[aA][[:space:]]+[A-Z_][A-Z0-9_]*' "$file" 2>/dev/null | sed -E 's/^declare[[:space:]]+-[aA][[:space:]]+//' | sed 's/[=[:space:]].*$//' || true
  done < <(find "$src_dir" -name "*.sh" -type f) | sort -u >> "$names_file"
  
  # Find all regular variable assignments (uppercase variables)
  while IFS= read -r file; do
    grep -hE '^[A-Z_][A-Z0-9_]*=' "$file" 2>/dev/null | sed 's/=.*$//' || true
  done < <(find "$src_dir" -name "*.sh" -type f) | sort -u >> "$names_file"
  
  # Find string keys in JSON (like "name", "identifier", etc.)
  while IFS= read -r file; do
    # Extract quoted keys from JSON-like structures
    grep -hEo '"[a-z_][a-z0-9_]*"[[:space:]]*:' "$file" 2>/dev/null | sed 's/"//g' | sed 's/[[:space:]]*://g' || true
  done < <(find "$src_dir" -name "*.sh" -type f) | sort -u >> "$names_file"
}

# Create name mapping
create_name_mapping() {
  local names_file="$1"
  local map_file="$2"
  
  if [[ ! -f "$names_file" ]] || [[ ! -s "$names_file" ]]; then
    echo "Warning: No names found to map" >&2
    > "$map_file"
    return 0
  fi
  
  > "$map_file"
  NAME_COUNTER=0
  
  # Reserved names to skip
  local reserved="if then else fi case esac for while until do done function local declare export readonly return echo printf test true false"
  
  # Read names and create mappings
  while IFS= read -r name || [[ -n "$name" ]]; do
    # Skip empty lines
    [[ -z "$name" ]] && continue
    
    # Skip reserved/bash built-in names
    echo "$reserved" | grep -qw "$name" && continue
    
    # Skip if already mapped
    [[ -v NAME_MAP["$name"] ]] && continue
    
    # Skip single character names (already minified or could conflict with flags)
    [[ ${#name} -eq 1 ]] && continue
    
    # Skip names that are common bash flags/options to avoid conflicts
    if [[ "$name" =~ ^-[a-zA-Z]$ ]] || [[ "$name" =~ ^[a-zA-Z]$ ]]; then
      continue
    fi
    
    # Generate single character name
    local char_index=$((NAME_COUNTER % ${#VALID_CHARS}))
    local minified_name="${VALID_CHARS:$char_index:1}"
    
    # If single char is taken, use two chars
    if [[ -v REVERSE_MAP["$minified_name"] ]] && [[ "${REVERSE_MAP["$minified_name"]}" != "$name" ]]; then
      # Use two characters
      local first_char_index=$((NAME_COUNTER / ${#VALID_CHARS}))
      local second_char_index=$((NAME_COUNTER % ${#VALID_CHARS}))
      if [[ $first_char_index -lt ${#VALID_CHARS} ]]; then
        minified_name="${VALID_CHARS:$first_char_index:1}${VALID_CHARS:$second_char_index:1}"
      else
        # Fallback: use underscore prefix
        minified_name="_${VALID_CHARS:$second_char_index:1}"
      fi
    fi
    
    # Store mapping
    NAME_MAP["$name"]="$minified_name"
    REVERSE_MAP["$minified_name"]="$name"
    
    # Write to map file (original=minified and minified=original for reverse lookup)
    echo "$name=$minified_name" >> "$map_file"
    echo "#REVERSE:$minified_name=$name" >> "$map_file"
    
    NAME_COUNTER=$((NAME_COUNTER + 1))
  done < "$names_file"
  
  return 0
}

# Apply name mapping to a line (simplified, faster version)
apply_name_mapping() {
  local line="$1"
  local result="$line"
  
  # Only apply if we have mappings
  if [[ ${#NAME_MAP[@]} -eq 0 ]]; then
    echo "$result"
    return 0
  fi
  
  # Apply mappings one at a time, but limit to avoid performance issues
  # Sort by length (longest first) to avoid partial matches
  local sorted_names
  sorted_names=$(printf '%s\n' "${!NAME_MAP[@]}" | awk '{print length($0), $0}' | sort -rn | cut -d' ' -f2- | head -200)
  
  while IFS= read -r original_name || [[ -n "$original_name" ]]; do
    [[ -z "$original_name" ]] && continue
    local minified_name="${NAME_MAP[$original_name]}"
    [[ -z "$minified_name" ]] && continue
    
    # Simple string replacements (faster than regex for most cases)
    # Replace function calls: function_name( -> minified_name(
    result="${result//${original_name}(/${minified_name}(}"
    
    # Replace variable references: $variable_name -> $minified_name  
    result="${result//\$${original_name}/\$${minified_name}}"
    
    # Replace variable assignments: variable_name= -> minified_name=
    result="${result//${original_name}=/${minified_name}=}"
    
    # Replace string keys in JSON: "original_name": -> "minified_name":
    result="${result//\"${original_name}\":/\"${minified_name}\":}"
  done <<< "$sorted_names"
  
  echo "$result"
}

# Minification function with name mangling
minify_script() {
  local input_file="$1"
  local in_heredoc=0
  local heredoc_tag=""
  local last_was_empty=0
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Track heredoc start - check for << pattern
    if echo "$line" | grep -qE '^[[:space:]]*<<[-]?['\''"]?[A-Za-z_][A-Za-z0-9_]*['\''"]?$'; then
      heredoc_tag=$(echo "$line" | sed -E 's/^[[:space:]]*<<[-]?['\''"]?([A-Za-z_][A-Za-z0-9_]*)['\''"]?$/\1/')
      in_heredoc=1
      last_was_empty=0
      echo "$line"
      continue
    fi
    
    # Track heredoc end
    if [[ $in_heredoc -eq 1 ]] && echo "$line" | grep -qE "^[[:space:]]*${heredoc_tag}[[:space:]]*$"; then
      in_heredoc=0
      heredoc_tag=""
      last_was_empty=0
      echo "$line"
      continue
    fi
    
    # If in heredoc, output as-is
    if [[ $in_heredoc -eq 1 ]]; then
      echo "$line"
      continue
    fi
    
    # Skip empty lines completely (aggressive minification)
    if echo "$line" | grep -qE '^[[:space:]]*$'; then
      last_was_empty=1
      continue
    fi
    last_was_empty=0
    
    # Skip comment-only lines (but preserve shebang and set commands)
    if echo "$line" | grep -qE '^[[:space:]]*#' && \
       ! echo "$line" | grep -qE '^[[:space:]]*#!/' && \
       ! echo "$line" | grep -qE '^[[:space:]]*set[[:space:]]'; then
      continue
    fi
    
    # Remove inline comments (simplified - may not handle all edge cases)
    local processed_line="$line"
    
    # Use sed to remove trailing comments (but be conservative)
    processed_line=$(echo "$processed_line" | sed -E 's/([^"'"'"'\\])[[:space:]]+#.*$/\1/')
    
    # Remove trailing whitespace
    processed_line=$(echo "$processed_line" | sed 's/[[:space:]]*$//')
    
    # Additional minification optimizations
    if [[ "$processed_line" =~ ^[[:space:]]*\;[[:space:]]*$ ]]; then
      continue
    fi
    if ! echo "$processed_line" | grep -qE ';;'; then
      processed_line=$(echo "$processed_line" | sed 's/;[[:space:]]*$//')
    fi
    
    # Compress multiple spaces to single space (but preserve indentation)
    local indent=""
    if [[ "$processed_line" =~ ^([[:space:]]*) ]]; then
      indent="${BASH_REMATCH[1]}"
    fi
    local content="${processed_line#$indent}"
    content=$(echo "$content" | sed -E 's/[[:space:]]{2,}/ /g')
    
    # Optimize common patterns
    content=$(echo "$content" | sed 's/ ;/;/g')
    content=$(echo "$content" | sed 's/{ /{/g')
    content=$(echo "$content" | sed 's/ }/}/g')
    content=$(echo "$content" | sed 's/( /(/g')
    content=$(echo "$content" | sed 's/ )/)/g')
    
    # Optimize assignments (but not in conditionals)
    if ! echo "$content" | grep -qE '(^|[[:space:]])(if|\[\[|\[|while|until|case)[[:space:]]'; then
      content=$(echo "$content" | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)\[?\]? = /\1=/g')
      content=$(echo "$content" | sed -E 's/(local|declare|export|readonly)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\[?\]? = /\1 \2=/g')
    fi
    
    # Name mapping will be applied to entire file later (more efficient)
    
    # Reconstruct line with preserved indentation
    processed_line="${indent}${content}"
    
    # Output non-empty lines
    if [[ -n "$processed_line" ]]; then
      echo "$processed_line"
    fi
  done < "$input_file"
}

# Create temporary file for building
TEMP_FILE=$(mktemp)
CLEANUP_FILES=("$TEMP_FILE")

if [[ "$MINIFY" == "true" ]]; then
  echo -e "${GREEN}Building minified suitey.min.sh from source modules...${NC}"
  
  # Extract names and create mapping
  echo -e "${YELLOW}  Extracting names for minification...${NC}"
  NAMES_FILE=$(mktemp)
  CLEANUP_FILES+=("$NAMES_FILE")
  
  if ! extract_names "$SRC_DIR" "$NAMES_FILE"; then
    echo "Error: Failed to extract names" >&2
    exit 1
  fi
  
  if ! create_name_mapping "$NAMES_FILE" "$MAP_FILE"; then
    echo "Error: Failed to create name mapping" >&2
    exit 1
  fi
  
  if [[ -f "$MAP_FILE" ]]; then
    map_count=$(grep -v '^#REVERSE:' "$MAP_FILE" | grep -v '^$' | wc -l)
    echo -e "${YELLOW}  Created name mapping: $MAP_FILE (${map_count} mappings)${NC}"
  else
    echo "Warning: Mapping file was not created" >&2
  fi
else
  echo -e "${GREEN}Building suitey.sh from source modules...${NC}"
fi

# Set up cleanup trap
cleanup() {
  for file in "${CLEANUP_FILES[@]}"; do
    rm -f "$file"
  done
}
trap cleanup EXIT

# Start with shebang and set options
if [[ "$MINIFY" == "true" ]]; then
  cat > "$TEMP_FILE" << 'HEADER'
#!/bin/bash
set -euo pipefail
HEADER
else
  cat > "$TEMP_FILE" << 'HEADER'
#!/bin/bash

set -euo pipefail

# ============================================================================
# Suitey - Project Scanner and Test Framework Detector
# ============================================================================
# Description: Suitey is a project scanner that detects test frameworks (BATS, Rust)
# and discovers test suites within project directories. It provides structured
# output about detected frameworks and their test suites for automated testing
# workflows.
# Purpose: Enables automated detection and execution of tests across multiple
# testing frameworks without manual configuration or framework-specific logic.
# Usage: suitey.sh [OPTIONS] [PROJECT_ROOT]
# This file is auto-generated by build.sh - do not edit manually
# ============================================================================

HEADER
fi

# Add source files in dependency order
if [[ "$MINIFY" == "true" ]]; then
  echo -e "${YELLOW}  Adding and minifying common.sh...${NC}"
  minify_script "$SRC_DIR/common.sh" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding and minifying adapter_registry.sh...${NC}"
  minify_script "$SRC_DIR/adapter_registry.sh" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding and minifying framework_detector.sh...${NC}"
  minify_script "$SRC_DIR/framework_detector.sh" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding and minifying adapters/bats.sh...${NC}"
  minify_script "$SRC_DIR/adapters/bats.sh" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding and minifying adapters/rust.sh...${NC}"
  minify_script "$SRC_DIR/adapters/rust.sh" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding and minifying scanner.sh...${NC}"
  minify_script "$SRC_DIR/scanner.sh" >> "$TEMP_FILE"

  echo -e "${YELLOW}  Adding and minifying build_manager.sh...${NC}"
  minify_script "$SRC_DIR/build_manager.sh" >> "$TEMP_FILE"

  echo -e "${YELLOW}  Adding and minifying main.sh...${NC}"
  minify_script "$SRC_DIR/main.sh" >> "$TEMP_FILE"
  
  # Apply name mapping line by line to avoid multi-line issues
  echo -e "${YELLOW}  Applying name mappings...${NC}"
  MAPPED_FILE=$(mktemp)
  CLEANUP_FILES+=("$MAPPED_FILE")
  
  # Process line by line to avoid multi-line replacement issues
  while IFS= read -r line || [[ -n "$line" ]]; do
    processed_line="$line"
    
    # Apply each mapping to the line
    for original_name in "${!NAME_MAP[@]}"; do
      [[ ${#original_name} -le 1 ]] && continue
      minified_name="${NAME_MAP[$original_name]}"
      
      # Function calls with parentheses
      processed_line="${processed_line//${original_name}(/${minified_name}(}"
      
      # Standalone function calls (whole line, preserve indentation)
      if [[ "$processed_line" =~ ^([[:space:]]*)${original_name}[[:space:]]*$ ]]; then
        processed_line="${BASH_REMATCH[1]}${minified_name}"
      fi
      
      # Function calls with arguments
      processed_line="${processed_line//${original_name} \"\$@\"/${minified_name} \"\$@\"}"
      
      # Variable references
      processed_line="${processed_line//\$${original_name}/\$${minified_name}}"
      
      # Variable assignments (but not in flags)
      processed_line="${processed_line//${original_name}=/${minified_name}=}"
      
      # JSON string keys
      processed_line="${processed_line//\"${original_name}\":/\"${minified_name}\":}"
    done
    
    echo "$processed_line" >> "$MAPPED_FILE"
  done < "$TEMP_FILE"
  
  mv "$MAPPED_FILE" "$TEMP_FILE"
else
  echo -e "${YELLOW}  Adding common.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/common.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/common.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding adapter_registry.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/adapter_registry.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/adapter_registry.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding framework_detector.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/framework_detector.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/framework_detector.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding adapters/bats.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/adapters/bats.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/adapters/bats.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding adapters/rust.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/adapters/rust.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/adapters/rust.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  
  echo -e "${YELLOW}  Adding scanner.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/scanner.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/scanner.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"

  echo -e "${YELLOW}  Adding build_manager.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/build_manager.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/build_manager.sh" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"

  echo -e "${YELLOW}  Adding main.sh...${NC}"
  echo "# ============================================================================" >> "$TEMP_FILE"
  echo "# Source: src/main.sh" >> "$TEMP_FILE"
  echo "# ============================================================================" >> "$TEMP_FILE"
  cat "$SRC_DIR/main.sh" >> "$TEMP_FILE"
fi

# Move temp file to output
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Make the output file executable
chmod +x "$OUTPUT_FILE"

echo -e "${GREEN}✓ Build complete: $OUTPUT_FILE${NC}"
if [[ "$MINIFY" == "true" ]] && [[ -n "$MAP_FILE" ]]; then
  echo -e "${GREEN}✓ Mapping file: $MAP_FILE${NC}"
fi
