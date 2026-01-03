#!/usr/bin/env bash
# Test fixture generators for Project Scanner tests

# Create a complete BATS project structure
create_bats_project() {
  local base_dir="$1"
  local project_name="${2:-bats_project}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create tests/bats/ directory structure
  mkdir -p "$base_dir/tests/bats/helpers"
  
  # Create a sample BATS test file
  cat > "$base_dir/tests/bats/suitey.bats" << 'EOF'
#!/usr/bin/env bats

@test "example test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/suitey.bats"
  
  # Create a helper file
  cat > "$base_dir/tests/bats/helpers/helper.bash" << 'EOF'
#!/usr/bin/env bash
# Helper functions for BATS tests

helper_function() {
  echo "helper"
}
EOF
  chmod +x "$base_dir/tests/bats/helpers/helper.bash"
  
  echo "$base_dir"
}

# Create project with no tests
create_empty_project() {
  local base_dir="$1"
  local project_name="${2:-empty_project}"
  
  # Create project root
  mkdir -p "$base_dir"
  mkdir -p "$base_dir/src"
  
  # Create some non-test files
  echo "#!/bin/bash" > "$base_dir/script.sh"
  echo "# Source file" > "$base_dir/src/main.sh"
  echo "# Documentation" > "$base_dir/README.md"
  
  echo "$base_dir"
}

# Create BATS project with helpers
create_project_with_helpers() {
  local base_dir="$1"
  local project_name="${2:-bats_with_helpers}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create tests/bats/ directory with helpers
  mkdir -p "$base_dir/tests/bats/helpers"
  
  # Create multiple test files
  cat > "$base_dir/tests/bats/test1.bats" << 'EOF'
#!/usr/bin/env bats

load helpers/helper.bash

@test "test 1" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/test1.bats"
  
  cat > "$base_dir/tests/bats/test2.bats" << 'EOF'
#!/usr/bin/env bats

load helpers/helper.bash

@test "test 2" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/test2.bats"
  
  # Create helper file
  cat > "$base_dir/tests/bats/helpers/helper.bash" << 'EOF'
#!/usr/bin/env bash
# Helper functions

setup() {
  echo "setup"
}

teardown() {
  echo "teardown"
}
EOF
  chmod +x "$base_dir/tests/bats/helpers/helper.bash"
  
  echo "$base_dir"
}

# Create BATS project with test/bats/ structure (alternative directory)
create_bats_project_alt_dir() {
  local base_dir="$1"
  local project_name="${2:-bats_alt_dir}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create test/bats/ directory structure (alternative)
  mkdir -p "$base_dir/test/bats"
  
  # Create a sample BATS test file
  cat > "$base_dir/test/bats/example.bats" << 'EOF'
#!/usr/bin/env bats

@test "example test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/test/bats/example.bats"
  
  echo "$base_dir"
}

# Create BATS project with tests/ directory (no bats subdirectory)
create_bats_project_tests_dir() {
  local base_dir="$1"
  local project_name="${2:-bats_tests_dir}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create tests/ directory (no bats subdirectory)
  mkdir -p "$base_dir/tests"
  
  # Create a sample BATS test file
  cat > "$base_dir/tests/example.bats" << 'EOF'
#!/usr/bin/env bats

@test "example test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/example.bats"
  
  echo "$base_dir"
}

# Create project with nested BATS files
create_bats_project_nested() {
  local base_dir="$1"
  local project_name="${2:-bats_nested}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create nested directory structure
  mkdir -p "$base_dir/tests/bats/unit"
  mkdir -p "$base_dir/tests/bats/integration"
  
  # Create test files in nested directories
  cat > "$base_dir/tests/bats/unit/unit_test.bats" << 'EOF'
#!/usr/bin/env bats

@test "unit test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/unit/unit_test.bats"
  
  cat > "$base_dir/tests/bats/integration/integration_test.bats" << 'EOF'
#!/usr/bin/env bats

@test "integration test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/integration/integration_test.bats"
  
  echo "$base_dir"
}

# Create project with only source files (no tests)
create_project_source_only() {
  local base_dir="$1"
  local project_name="${2:-source_only}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create source files
  mkdir -p "$base_dir/src"
  echo "#!/bin/bash" > "$base_dir/src/main.sh"
  chmod +x "$base_dir/src/main.sh"
  
  echo "#!/bin/bash" > "$base_dir/script.sh"
  chmod +x "$base_dir/script.sh"
  
  echo "$base_dir"
}

# Create project with only documentation files
create_project_docs_only() {
  local base_dir="$1"
  local project_name="${2:-docs_only}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create documentation files
  echo "# Project Documentation" > "$base_dir/README.md"
  echo "# License" > "$base_dir/LICENSE"
  echo "# Contributing" > "$base_dir/CONTRIBUTING.md"
  
  echo "$base_dir"
}

# Create project with build files but no tests
create_project_build_only() {
  local base_dir="$1"
  local project_name="${2:-build_only}"
  
  # Create project root
  mkdir -p "$base_dir"
  
  # Create build files
  cat > "$base_dir/Makefile" << 'EOF'
.PHONY: build
build:
	echo "Building..."
EOF
  
  cat > "$base_dir/Dockerfile" << 'EOF'
FROM alpine:latest
RUN echo "Build image"
EOF
  
  echo "$base_dir"
}

# Create BATS file with proper shebang
create_bats_file_with_shebang() {
  local file_path="$1"
  local test_name="${2:-test_example}"
  
  mkdir -p "$(dirname "$file_path")"
  
  cat > "$file_path" << EOF
#!/usr/bin/env bats

@test "$test_name" {
  [ true ]
}
EOF
  chmod +x "$file_path"
  echo "$file_path"
}

# Create BATS file without .bats extension but with shebang
create_bats_file_no_extension() {
  local file_path="$1"
  local test_name="${2:-test_example}"
  
  mkdir -p "$(dirname "$file_path")"
  
  cat > "$file_path" << EOF
#!/usr/bin/env bats

@test "$test_name" {
  [ true ]
}
EOF
  chmod +x "$file_path"
  echo "$file_path"
}

