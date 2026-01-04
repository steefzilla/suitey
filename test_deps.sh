#!/bin/bash
source suitey.sh

build_requirements='[{"framework": "app", "build_dependencies": ["lib"]}, {"framework": "lib", "build_dependencies": []}]'

# Parse frameworks
frameworks=()
while IFS= read -r framework; do
  frameworks+=("$framework")
  echo "Found framework: $framework"
done < <(echo "$build_requirements" | jq -r '.[].framework' 2>/dev/null)

echo "Frameworks: ${frameworks[@]}"

for framework in "${frameworks[@]}"; do
  echo "Checking framework: $framework"
  # Get dependencies for this framework
  deps_length=$(echo "$build_requirements" | jq "[.[] | select(.framework == \"$framework\") | .build_dependencies // []] | .[0] | length" 2>/dev/null || echo "ERROR")
  echo "Deps length for $framework: $deps_length"
done
