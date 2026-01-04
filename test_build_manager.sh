#!/bin/bash
source suitey.sh

# Mock Docker
build_manager_check_docker() { return 0; }

echo "Testing build_manager_initialize..."
output=$(build_manager_initialize 2>&1)
status=$?
echo "Output: '$output'"
echo "Status: $status"

if [[ $status -eq 0 ]] && echo "$output" | grep -q "initialized"; then
  echo "✓ Test passed"
else
  echo "✗ Test failed"
fi

# Cleanup
if [[ -n "${BUILD_MANAGER_TEMP_DIR:-}" ]]; then
  rm -rf "$BUILD_MANAGER_TEMP_DIR"
fi
