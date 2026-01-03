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

# Create project with specific pattern for adapter testing
create_project_with_pattern() {
  local base_dir="$1"
  local pattern="$2"

  # Create project root
  mkdir -p "$base_dir"

  # Create a file that matches the pattern for testing
  case "$pattern" in
    "mock_pattern")
      echo "# Mock pattern file" > "$base_dir/mock_pattern.txt"
      ;;
    *)
      echo "# Generic pattern file for $pattern" > "$base_dir/$pattern.txt"
      ;;
  esac

  echo "$base_dir"
}

# Create multi-framework project for testing
create_multi_framework_project() {
  local base_dir="$1"

  # Create project root
  mkdir -p "$base_dir"

  # Create BATS test structure
  mkdir -p "$base_dir/tests/bats"
  cat > "$base_dir/tests/bats/multi.bats" << 'EOF'
#!/usr/bin/env bats

@test "multi-framework test" {
  [ true ]
}
EOF
  chmod +x "$base_dir/tests/bats/multi.bats"

  # Create Rust project structure
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "multi_framework_test"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn example() -> String {
    "example".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example() {
        assert_eq!(example(), "example");
    }
}
EOF

  echo "$base_dir"
}

# ============================================================================
# Rust Project Fixtures
# ============================================================================

# Create a complete Rust project structure
create_rust_project() {
  local base_dir="$1"
  local project_name="${2:-rust_project}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  # Create src directory with lib.rs containing unit tests
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
EOF

  echo "$base_dir"
}

# Create Rust project with multiple test files
create_rust_project_with_tests() {
  local base_dir="$1"
  local project_name="${2:-rust_with_tests}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  # Create src directory with lib.rs
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
    }
}
EOF

  # Create utils.rs with its own tests
  cat > "$base_dir/src/utils.rs" << 'EOF'
pub fn multiply(x: i32, y: i32) -> i32 {
    x * y
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_multiply() {
        assert_eq!(multiply(3, 4), 12);
    }

    #[test]
    fn test_multiply_zero() {
        assert_eq!(multiply(5, 0), 0);
    }
}
EOF

  echo "$base_dir"
}

# Create Rust project with nested test directories
create_rust_project_nested() {
  local base_dir="$1"
  local project_name="${2:-rust_nested}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  # Create src directory
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
EOF

  # Create nested test directory structure
  mkdir -p "$base_dir/tests/unit"
  mkdir -p "$base_dir/tests/integration"

  # Create unit test file
  cat > "$base_dir/tests/unit/unit_test.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn unit_test_example() {
        assert!(true);
    }
}
EOF

  # Create integration test file
  cat > "$base_dir/tests/integration/integration_test.rs" << 'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn integration_test_example() {
        assert!(true);
    }
}
EOF

  echo "$base_dir"
}

# Create Rust project with both unit and integration tests
create_rust_project_unit_and_integration() {
  local base_dir="$1"
  local project_name="${2:-rust_mixed_tests}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

  # Create src directory with unit tests
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unit_test_one() {
        assert_eq!(add(2, 2), 4);
    }

    #[test]
    fn unit_test_two() {
        assert_eq!(add(0, 0), 0);
    }
}
EOF

  # Create tests directory with integration tests
  mkdir -p "$base_dir/tests"
  cat > "$base_dir/tests/integration_tests.rs" << 'EOF'
#[test]
fn integration_test_one() {
    assert!(true);
}

#[test]
fn integration_test_two() {
    assert_eq!(1 + 1, 2);
}

#[test]
fn integration_test_three() {
    assert_eq!(2 * 3, 6);
}
EOF

  echo "$base_dir"
}

# Create Rust project with Cargo.toml but no tests
create_rust_project_build_only() {
  local base_dir="$1"
  local project_name="${2:-rust_build_only}"

  # Create project root
  mkdir -p "$base_dir"

  # Create Cargo.toml
  cat > "$base_dir/Cargo.toml" << 'EOF'
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
EOF

  # Create minimal src directory
  mkdir -p "$base_dir/src"
  cat > "$base_dir/src/lib.rs" << 'EOF'
pub fn example() -> String {
    "Hello, World!".to_string()
}
EOF

  echo "$base_dir"
}

# Create a single Rust test file
create_rust_test_file() {
  local file_path="$1"
  local test_name="${2:-test_example}"
  local additional_tests="${3:-}"

  # Ensure directory exists
  mkdir -p "$(dirname "$file_path")"

  # Default test content
  local test_content=""
  if [[ -z "$additional_tests" ]]; then
    test_content="#[test]
fn $test_name() {
    assert!(true);
}"
  else
    test_content="#[test]
fn $test_name() {
    assert!(true);
}

$additional_tests"
  fi

  # Write file
  cat > "$file_path" << EOF
#[cfg(test)]
mod tests {
    $test_content
}
EOF

  echo "$file_path"
}

# Create integration test file (tests/*.rs)
create_rust_integration_test_file() {
  local file_path="$1"
  local test_name="${2:-integration_test}"
  local additional_tests="${3:-}"

  mkdir -p "$(dirname "$file_path")"

  local test_content="#[test]
fn $test_name() {
    assert!(true);
}"

  if [[ -n "$additional_tests" ]]; then
    test_content="$test_content

$additional_tests"
  fi

  cat > "$file_path" << EOF
$test_content
EOF

  echo "$file_path"
}

