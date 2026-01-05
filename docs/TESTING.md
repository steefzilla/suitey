# Suitey Testing Documentation

## Overview

Suitey's test suite provides comprehensive coverage of all components through unit tests (with intelligent mocking) and integration tests (with real Docker operations). The test framework is designed to be safe for parallel execution, maintainable, and easy to extend.

## Table of Contents

- [Test Structure](#test-structure)
- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
- [Test Guidelines for Parallel Execution](#test-guidelines-for-parallel-execution)
- [Coding Patterns for Testability](#coding-patterns-for-testability)
- [Mock System for Unit Tests](#mock-system-for-unit-tests)
- [Integration Tests](#integration-tests)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

## Test Structure

### Test Categories

#### Unit Tests (`tests/bats/unit/`)
- **Adapter Registry Tests**: Adapter registration, metadata management, capability indexing
- **Build Manager Tests**: Docker orchestration, container management, build execution (with mocking)
- **Framework Detector Tests**: Framework detection logic
- **Project Scanner Tests**: Project structure analysis
- **JSON Helper Tests**: JSON manipulation utilities
- **Performance Tests**: Concurrency, I/O, memory, startup
- **Security Tests**: Input validation, path traversal, permissions, temp files
- **Static Analysis Tests**: Code quality, complexity, dead code detection

#### Integration Tests (`tests/bats/integration/`)
- **Build Manager Integration**: Real Docker operations, container lifecycle, image building
- **Adapter Registry Integration**: Framework detection, project scanning, test suite discovery
- **End-to-End Workflows**: Complete test execution flows

### Test Files Organization

```
tests/bats/
├── unit/                    # Unit tests with mocking
│   ├── adapter_registry.bats
│   ├── build_manager.bats
│   ├── framework_detector.bats
│   └── ...
├── integration/            # Integration tests with real Docker
│   ├── build_manager.bats
│   ├── adapter_registry_framework_detector.bats
│   └── ...
├── performance/            # Performance benchmarks
├── security/              # Security validation
├── static/                # Static analysis
└── helpers/               # Test helper functions
    ├── common_teardown.bash
    ├── adapter_registry.bash
    ├── build_manager.bash
    └── ...
```

## Prerequisites

### Basic Requirements

- **BATS**: Bash Automated Testing System
  ```bash
  # Install BATS
  git clone https://github.com/bats-core/bats-core.git
  cd bats-core
  ./install.sh /usr/local
  ```

- **jq**: JSON processor (for test assertions)
  ```bash
  sudo apt-get install jq
  ```

- **Bash**: Version 4.0+ (for associative arrays)

### Integration Test Requirements

#### Docker Environment

- **Docker Engine**: 20.10.0+
- **Docker API**: Compatible with installed engine
- **Buildx**: Recommended for advanced build features

#### System Resources

- **Disk Space**: Minimum 1GB available in Docker root directory
- **Memory**: At least 512MB available for Docker operations
- **Network**: Internet access for image pulls

#### Permissions

- Docker daemon access (typically requires `docker` group membership or root)
- Write access to Docker root directory
- Network access for container communication

#### Docker Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (optional)
sudo usermod -aG docker $USER
```

#### Verify Docker Installation

```bash
# Check Docker version
docker --version

# Check Docker daemon status
docker info

# Test basic functionality
docker run hello-world
```

## Running Tests

### Unit Tests

```bash
# Run all unit tests
bats tests/bats/unit/

# Run specific test file
bats tests/bats/unit/adapter_registry.bats

# Run specific test
bats tests/bats/unit/adapter_registry.bats -f "register_adapter with valid adapter succeeds"

# Run in parallel (recommended for faster execution)
bats -rj 16 tests/bats/unit/adapter_registry.bats

# Run serially (for debugging)
bats -r tests/bats/unit/adapter_registry.bats
```

### Integration Tests

```bash
# Run all integration tests
bats tests/bats/integration/

# Run specific test file
bats tests/bats/integration/build_manager.bats

# Run specific test
bats tests/bats/integration/build_manager.bats -f "container_creation"

# Skip if Docker unavailable
check_docker_available || skip "Docker daemon not available"
```

### Environment Variables

```bash
# Enable verbose output
export BATS_VERBOSE_RUN=1

# Set custom Docker socket (if needed)
export DOCKER_HOST=unix:///var/run/docker.sock

# Set custom test timeout
export BATS_TEST_TIMEOUT=300
```

### Parallel Execution

```bash
# Run tests in parallel (16 jobs)
bats -rj 16 tests/bats/unit/

# Run integration tests in parallel (if safe)
bats -rj 4 tests/bats/integration/

# Compare with serial execution
bats -r tests/bats/unit/
```

**Note**: Always verify tests work in parallel. If tests pass serially but fail in parallel, see [Test Guidelines for Parallel Execution](#test-guidelines-for-parallel-execution).

## Test Guidelines for Parallel Execution

This section provides guidelines for writing tests that are safe for parallel execution using BATS' `-j` flag.

### Teardown Best Practices

#### ✅ DO: Clean up only your test's directory

Each test should only clean up resources it created. Use the test directory variable that was set during setup:

```bash
teardown_my_test() {
  if [[ -n "${TEST_MY_DIR:-}" ]] && [[ -d "$TEST_MY_DIR" ]]; then
    rm -rf "$TEST_MY_DIR"
    unset TEST_MY_DIR
  fi
  
  # Clean up additional files specific to this test
  rm -f /tmp/suitey_my_test_* 2>/dev/null || true
}
```

#### ❌ DON'T: Delete all matching directories

**NEVER** use `find` to delete all directories matching a pattern in teardown:

```bash
# WRONG - Causes race conditions in parallel execution
teardown_my_test() {
  # This will delete directories from OTHER parallel tests!
  find /tmp -maxdepth 1 -name "suitey_*_test_*" -type d -exec rm -rf {} + 2>/dev/null || true
}
```

**Why this is dangerous:**
- In parallel execution, multiple tests run simultaneously
- One test's teardown can delete directories that other tests are still using
- This causes "No such file or directory" errors
- Tests fail intermittently and unpredictably

#### ✅ DO: Use common teardown utilities

Use the standardized functions from `common_teardown.bash`:

```bash
# In your helper file
source "$BATS_TEST_DIRNAME/common_teardown.bash"

teardown_adapter_registry_test() {
  safe_teardown_adapter_registry
}
```

Or create a custom teardown using the utility function:

```bash
source "$BATS_TEST_DIRNAME/common_teardown.bash"

teardown_my_custom_test() {
  safe_teardown_test_directory "TEST_MY_DIR" \
    "/tmp/suitey_my_file1" \
    "/tmp/suitey_my_file2"
}
```

### File Operations

#### ✅ DO: Use atomic file writes

When writing files that may be read by other processes, use atomic writes:

```bash
# Write to temp file first, then atomically rename
temp_file=$(mktemp -p "$dir_path" "file.tmp.XXXXXX")
echo "data" > "$temp_file"
mv "$temp_file" "$final_file"  # Atomic on most filesystems
```

#### ✅ DO: Compute file paths dynamically

Don't initialize file paths at module load time. Compute them when needed:

```bash
# WRONG - Initialized at module load time
REGISTRY_FILE="${TEST_ADAPTER_REGISTRY_DIR:-/tmp}/registry"

# RIGHT - Computed dynamically when needed
get_registry_file() {
  local base_dir="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"
  echo "$base_dir/registry"
}
```

### Global Variable Initialization

#### ✅ DO: Use lazy initialization

Initialize global variables that depend on test-specific environment variables lazily:

```bash
# WRONG - Initialized before TEST_ADAPTER_REGISTRY_DIR is set
REGISTRY_BASE_DIR="${TEST_ADAPTER_REGISTRY_DIR:-${TMPDIR:-/tmp}}"

# RIGHT - Initialized as empty, computed when needed
REGISTRY_BASE_DIR=""
# Then compute it in functions that use it
```

#### ❌ DON'T: Initialize at module load time

If your module is sourced before test setup runs, global variables will have wrong values:

```bash
# This will use /tmp for all tests if sourced before setup
REGISTRY_FILE="${TEST_ADAPTER_REGISTRY_DIR:-/tmp}/registry"
```

### Common Patterns

#### Pattern 1: Test Directory Setup

```bash
setup_my_test() {
  local test_name="${1:-my_test}"
  TEST_MY_DIR=$(mktemp -d -t "suitey_my_test_${test_name}_XXXXXX")
  export TEST_MY_DIR
  echo "$TEST_MY_DIR"
}
```

#### Pattern 2: Safe Teardown

```bash
teardown_my_test() {
  # Only clean up THIS test's directory
  if [[ -n "${TEST_MY_DIR:-}" ]] && [[ -d "$TEST_MY_DIR" ]]; then
    rm -rf "$TEST_MY_DIR" 2>/dev/null || true
    unset TEST_MY_DIR
  fi
  
  # Clean up test-specific files (not directories!)
  rm -f /tmp/suitey_my_test_* 2>/dev/null || true
}
```

#### Pattern 3: Dynamic Path Computation

```bash
get_my_test_file() {
  local base_dir="${TEST_MY_DIR:-${TMPDIR:-/tmp}}"
  echo "$base_dir/my_file"
}

# Use it in functions
my_function() {
  local file_path
  file_path=$(get_my_test_file)
  # Use file_path...
}
```

### Using Common Teardown Utilities

The project provides standardized teardown utilities in `tests/bats/helpers/common_teardown.bash`.

#### Available Functions

1. **`safe_teardown_test_directory`** - Generic safe teardown function
2. **`safe_teardown_adapter_registry`** - Pre-configured for adapter registry tests
3. **`safe_teardown_build_manager`** - Pre-configured for build manager tests
4. **`safe_teardown_framework_detector`** - Pre-configured for framework detector tests

#### Example Usage

```bash
#!/usr/bin/env bash
# My test helper

# Source common teardown utilities
common_teardown_script=""
if [[ -f "$BATS_TEST_DIRNAME/common_teardown.bash" ]]; then
  common_teardown_script="$BATS_TEST_DIRNAME/common_teardown.bash"
elif [[ -f "$(dirname "$BATS_TEST_DIRNAME")/helpers/common_teardown.bash" ]]; then
  common_teardown_script="$(dirname "$BATS_TEST_DIRNAME")/helpers/common_teardown.bash"
else
  common_teardown_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/helpers" && pwd)/common_teardown.bash"
fi
if [[ -f "$common_teardown_script" ]]; then
  source "$common_teardown_script"
fi

# Use pre-configured teardown
teardown_adapter_registry_test() {
  safe_teardown_adapter_registry
}

# Or create custom teardown
teardown_my_custom_test() {
  safe_teardown_test_directory "TEST_MY_DIR" \
    "/tmp/suitey_custom_file1" \
    "/tmp/suitey_custom_file2"
}
```

### Testing Parallel Execution

To test that your tests work in parallel:

```bash
# Run tests in parallel (16 jobs)
bats -rj 16 ./tests/bats/unit/my_tests.bats

# Compare with serial execution
bats -r ./tests/bats/unit/my_tests.bats
```

If tests pass serially but fail in parallel, check for:
- Aggressive teardown cleanup
- Shared global state
- Non-atomic file operations
- Module-load-time initialization

## Coding Patterns for Testability

This section covers coding patterns that make code easier to test, particularly in BATS test environments.

### Return-Data Pattern for Array Population

The return-data pattern is a methodology for functions that need to populate caller's arrays, especially when those functions are tested in BATS. This pattern avoids scoping issues that can occur with namerefs and eval in BATS test contexts.

#### Problem

When functions use namerefs or eval to modify caller's arrays in BATS tests, they can encounter scoping issues where:
- Arrays appear to be populated inside the function
- But are empty after the function returns
- This is due to BATS running tests in subshells with different scoping rules

#### Solution: Return-Data Pattern

Instead of modifying the caller's array directly, functions:
1. Process the data
2. Return it in a structured format (first line = count, subsequent lines = key=value pairs)
3. Let the caller populate their own array from the returned data

#### When to Use

**Use return-data pattern when:**
- Function needs to populate caller's array
- Function is tested in BATS
- Function processes data from files/external sources
- You want explicit control over array population

**Nameref is acceptable when:**
- Function only reads from arrays (not modifies)
- Function modifies global arrays directly
- Function is not tested in BATS or tests pass
- Performance is critical (nameref is slightly faster)

#### Implementation

##### Function Signature

```bash
# Function returns: first line is count, subsequent lines are key=value pairs
function_name() {
    local array_name="$1"  # For documentation, not used for modification
    local file_path="$2"
    
    # Process data and build output
    local count=0
    local output_lines=""
    
    while IFS= read -r line; do
        # Process line
        output_lines+="${key}=${value}"$'\n'
        count=$((count + 1))
    done < "$file_path"
    
    # Output count first, then data
    echo "$count"
    echo -n "$output_lines"
    return 0
}
```

##### Caller Usage

```bash
# Option 1: Manual processing
output=$(function_name "array_name" "$file")
count=$(echo "$output" | head -n 1)
if [[ "$count" -gt 0 ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" ]] && continue
        array["$key"]="$value"
    done < <(echo "$output" | tail -n +2)
fi

# Option 2: Using helper function
output=$(function_name "array_name" "$file")
count=$(_adapter_registry_populate_array_from_output "array_name" "$output")
```

#### Helper Function

A reusable helper function `_adapter_registry_populate_array_from_output()` is available in `adapter_registry_helpers.sh`:

```bash
# Populates an associative array from return-data format
# Arguments:
#   array_name: Name of associative array to populate
#   output: Output from a return-data function
# Returns:
#   The count (first line of output)
count=$(_adapter_registry_populate_array_from_output "array_name" "$output")
```

#### Examples

##### Current Implementation

- `_adapter_registry_load_array_from_file()` - Uses return-data pattern
- `json_to_array()` - Uses nameref (works, no BATS issues)
- `build_requirements_json_to_array()` - Uses nameref (works, no BATS issues)

##### Migration Example

**Before (nameref - can fail in BATS):**
```bash
load_array() {
    local array_name="$1"
    local -n arr="$array_name"
    arr["key"]="value"
}
```

**After (return-data - works in BATS):**
```bash
load_array() {
    local array_name="$1"
    echo "1"
    echo "key=value"
}

# Caller:
output=$(load_array "my_array")
count=$(_adapter_registry_populate_array_from_output "my_array" "$output")
```

#### Benefits

1. **Avoids BATS scoping issues** - No eval/nameref scoping problems
2. **Clearer separation** - Function returns data, caller populates
3. **Easier to test** - Caller controls array population
4. **More flexible** - Caller can transform data before populating
5. **Better error handling** - Caller can validate before populating

#### Testing

Functions using return-data pattern should be tested to verify:
1. Correct count is returned
2. Data format is correct (key=value pairs)
3. Caller can successfully populate array
4. Empty/non-existent file cases are handled

See `tests/bats/unit/adapter_registry_helpers.bats` for examples.

## Mock System for Unit Tests

The Build Manager test framework provides comprehensive mocking capabilities for unit testing complex Docker orchestration logic without requiring real Docker operations.

### Architecture

#### Core Components

1. **Mock Manager** (`mock_manager.bash`)
   - Central state management for test contexts
   - Context preservation across test operations
   - State persistence and retrieval

2. **Parameter Transformation** (`mock_manager.bash`)
   - Intelligent parsing of complex Docker arguments
   - Conversion between production and test interfaces
   - Container metadata extraction

3. **Contextual Responses** (`mock_manager.bash`)
   - Context-aware mock response generation
   - CPU allocation, artifact, duration, and error responses
   - Adaptive responses based on test scenarios

4. **Async Support** (`async_test_helpers.bash`)
   - Background operation simulation
   - Signal handling and interruption testing
   - Resource cleanup verification

5. **Environment Simulation** (`environment_simulator.bash`)
   - File system mocking and operations
   - Process lifecycle management
   - Docker daemon state simulation

### Usage Patterns

#### Basic Test Structure

```bash
@test "example test" {
  setup_build_manager_test "test_name"

  # Set up mocks if needed
  docker_run() { mock_docker_run "$@"; }

  # Execute function under test
  result=$(function_under_test)

  # Assert success
  [ $? -eq 0 ]

  teardown_build_manager_test
}
```

#### Context-Aware Testing

```bash
@test "contextual test" {
  setup_build_manager_test "context_test"

  # Set test context for specific behavior
  mock_manager_set_context "cpu_test" "true"

  # Execute with contextual responses
  result=$(build_manager_execute_build "$spec" "framework")

  # Verify context-aware behavior
  [ $? -eq 0 ]

  teardown_build_manager_test
}
```

#### Async Operation Testing

```bash
@test "async test" {
  setup_build_manager_test "async_test"

  # Mock async operations
  run_async_operation() { echo "mock_operation"; }
  wait_for_operation() { return 0; }

  # Test async functionality
  result=$(async_function)

  [ $? -eq 0 ]

  teardown_build_manager_test
}
```

### Key Features

#### Intelligent Mocking
- Automatic detection of test vs production environments
- Parameter transformation between interfaces
- Context-aware response generation

#### Comprehensive Coverage
- Docker operations (run, build, copy)
- File system operations
- Process management
- Async execution patterns
- Signal handling

#### State Management
- Persistent context across operations
- Mock state tracking and inspection
- Environment simulation

#### Easy Integration
- Backward compatible with existing tests
- Automatic mock detection
- Minimal test code changes required

### Test Categories (Build Manager Unit Tests)

1. **Initialization Tests** (6 tests)
   - Build manager setup and teardown
   - Docker availability checking
   - Directory structure creation

2. **Dependency Analysis Tests** (5 tests)
   - Circular dependency detection
   - Tier grouping and ordering
   - Sequential execution planning

3. **Orchestration Tests** (4 tests)
   - Build requirements validation
   - Empty requirements handling
   - Multi-framework coordination

4. **Build Execution Tests** (8 tests)
   - Container launch and configuration
   - CPU core allocation
   - Dependency installation
   - Artifact extraction

5. **Image Creation Tests** (8 tests)
   - Dockerfile generation
   - Artifact inclusion
   - Build verification
   - Error handling

6. **Parallel Execution Tests** (4 tests)
   - Concurrent build execution
   - CPU-based limiting
   - Tier completion waiting
   - Failure handling

7. **Status Tracking Tests** (5 tests)
   - Status transitions
   - Real-time updates
   - Result data structure
   - Duration tracking

8. **Error Handling Tests** (7 tests)
   - Build failures
   - Container failures
   - Artifact failures
   - Resource cleanup

9. **Signal Handling Tests** (3 tests)
   - Graceful termination
   - Forceful interruption
   - Resource cleanup

### Implementation Notes

#### Test Mode Detection
Functions automatically detect test environments by checking for mock function availability, eliminating the need for manual test mode flags.

#### Parameter Transformation
Complex Docker command arguments are automatically parsed and transformed to simple mock interfaces, maintaining compatibility between production and test code.

#### Contextual Intelligence
Mock responses adapt based on test context, providing appropriate outputs for different testing scenarios (CPU allocation, artifact operations, error conditions, etc.).

#### Async Simulation
Background operations, signals, and cleanup are fully simulated, enabling comprehensive testing of interruption and resource management logic.

### Success Metrics

- ✅ 50/50 unit tests passing (100% coverage)
- ✅ Intelligent mocking with contextual responses
- ✅ Full async operation support
- ✅ Comprehensive environment simulation
- ✅ Maintainable and extensible architecture

## Integration Tests

Integration tests validate Build Manager functionality with real Docker operations, ensuring that container orchestration, resource management, and Docker API interactions work correctly in production-like environments.

### Test Categories

#### 1. Docker Connectivity Tests
- **Docker Daemon Access**: Verifies Docker daemon connectivity
- **API Compatibility**: Tests Docker API version compatibility
- **Resource Validation**: Checks available system resources

#### 2. Container Lifecycle Tests
- **Container Creation**: Tests real container launch with proper configuration
- **Resource Management**: Validates CPU, memory, and volume mounting
- **Container Inspection**: Verifies container configuration matches requirements

#### 3. Build and Image Management
- **Image Building**: Tests Docker image creation from Dockerfiles
- **Artifact Handling**: Validates build artifact extraction and storage
- **Image Cleanup**: Ensures proper image removal after tests

#### 4. Adapter Registry Integration
- **Framework Detection**: Tests adapter-based framework discovery
- **Project Scanning**: Validates project structure analysis
- **Test Suite Discovery**: Ensures proper test identification

### Test Infrastructure

#### Helper Functions

##### Docker Validation
```bash
# Basic availability check
check_docker_available()

# Comprehensive environment validation
check_docker_environment()
```

##### Resource Management
```bash
# Clean up all Docker resources
cleanup_docker_resources()

# Clean up specific resource types
cleanup_docker_containers()
cleanup_docker_images()
cleanup_docker_volumes()
cleanup_docker_networks()
```

##### Test Isolation
```bash
# Setup isolated test environment
setup_test_isolation()

# Generate unique resource names
generate_test_resource_name()

# Cleanup test isolation
cleanup_test_isolation()
```

##### Error Handling
```bash
# Safe Docker operations with timeout
safe_docker_operation "docker run image command" 300
```

### Test Data Setup

#### Mock Build Requirements
```json
{
  "framework": "rust",
  "build_steps": [
    {
      "docker_image": "rust:latest",
      "build_command": "cargo build --release",
      "working_directory": "/workspace"
    }
  ],
  "artifact_storage": {
    "artifacts": ["target/"],
    "source_code": ["src/"],
    "test_suites": ["tests/"]
  }
}
```

#### Test Project Structure
```
test_project/
├── src/
│   └── main.rs
├── tests/
│   └── integration_test.rs
├── Cargo.toml
└── Dockerfile
```

### Resource Management

#### Automatic Cleanup
Integration tests automatically clean up resources using teardown functions:

```bash
# Called automatically after each test
teardown_build_manager_test() {
  cleanup_test_isolation
  cleanup_docker_resources
}
```

#### Manual Cleanup
If tests fail or resources remain:

```bash
# Clean up all Suitey test resources
cleanup_docker_resources "suitey*"

# Aggressive cleanup
docker system prune -a --volumes -f
```

#### Resource Monitoring
```bash
# Monitor resource usage during tests
docker system df -v

# Check for orphaned resources
docker ps -a --filter "status=exited"
docker images -f "dangling=true"
docker volume ls -f "dangling=true"
```

### Performance Optimization

#### Test Execution Time
- **Typical runtime**: 2-5 minutes for full integration test suite
- **Bottlenecks**: Image pulls, container startup, build operations
- **Optimization**: Use pre-built images, minimize artifact sizes

#### Resource Usage
- **Disk space**: ~500MB for test images and containers
- **Memory**: ~256MB per concurrent test
- **Network**: ~50MB for image pulls

#### Parallel Execution
```bash
# Run tests in parallel (if implemented)
bats --jobs 4 tests/bats/integration/

# Or use GNU parallel
find tests/bats/integration/ -name "*.bats" | parallel bats {}
```

### Security Considerations

#### Docker Security
- **Run tests in isolated networks** to prevent external access
- **Use minimal base images** to reduce attack surface
- **Avoid privileged containers** unless absolutely necessary
- **Clean up test resources** immediately after use

#### CI/CD Security
- **Use trusted base images** from verified registries
- **Implement image scanning** for vulnerabilities
- **Limit Docker daemon access** to CI runners
- **Regular security updates** for Docker and host system

## Best Practices

### Test Development

1. **Use unique resource names** to avoid conflicts
2. **Implement proper cleanup** in teardown functions using `common_teardown.bash` utilities
3. **Handle Docker unavailability** gracefully with skip conditions
4. **Set appropriate timeouts** for long-running operations
5. **Validate test data** before running Docker operations
6. **Use atomic file operations** for shared state
7. **Compute paths dynamically** - don't initialize at module load time
8. **Test in parallel** - always verify tests work with `-j` flag

### CI/CD Considerations

1. **Use Docker-in-Docker** for isolated test environments
2. **Configure resource limits** to prevent CI resource exhaustion
3. **Implement retry logic** for transient Docker failures
4. **Cache Docker images** to reduce pull times
5. **Parallelize tests** when possible (using `-j` flag)
6. **Use common teardown utilities** to prevent race conditions

### Maintenance

1. **Regular cleanup** of test Docker resources
2. **Monitor resource usage** trends
3. **Update Docker versions** regularly
4. **Review test timeouts** and adjust as needed
5. **Document environment requirements** clearly
6. **Follow parallel execution guidelines** to prevent regressions

## Troubleshooting

### Common Issues

#### Docker Not Available
```
ERROR: Docker daemon not accessible
```
**Solution**: Ensure Docker daemon is running and accessible
```bash
sudo systemctl status docker
sudo systemctl start docker
```

#### Insufficient Resources
```
ERROR: Insufficient disk space for Docker operations
```
**Solution**: Free up disk space or configure alternative Docker root
```bash
# Check disk usage
df -h /var/lib/docker

# Clean up Docker resources
docker system prune -a --volumes
```

#### Permission Issues
```
ERROR: Got permission denied while trying to connect to the Docker daemon
```
**Solution**: Add user to docker group or run with sudo
```bash
sudo usermod -aG docker $USER
# Logout and login again, or run: newgrp docker
```

#### Network Issues
```
ERROR: Cannot pull Docker images
```
**Solution**: Check network connectivity and DNS
```bash
ping registry-1.docker.io
docker pull hello-world
```

#### Parallel Execution Failures
```
ERROR: No such file or directory
ERROR: Directory does not exist
```
**Solution**: Check for aggressive teardown cleanup or shared global state
- Verify teardown functions use `common_teardown.bash` utilities
- Ensure no `find` commands delete multiple directories
- Check for module-load-time initialization of paths
- Verify atomic file operations are used

### Debug Commands

#### Check Docker Status
```bash
# Docker daemon status
docker info

# Docker version info
docker version

# Available resources
docker system df

# Running containers
docker ps

# Available images
docker images
```

#### Test Specific Components
```bash
# Test Docker connectivity
docker run --rm hello-world

# Test build functionality
docker build -t test-image .

# Test volume mounting
docker run --rm -v /tmp:/test alpine ls /test
```

#### Verify Test Setup
```bash
# Check BATS installation
bats --version

# Check helper functions are available
source tests/bats/helpers/common_teardown.bash
declare -f safe_teardown_test_directory

# Verify test directory isolation
bats -rj 16 tests/bats/unit/adapter_registry.bats
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq bats

      - name: Run unit tests
        run: |
          bats -rj 16 tests/bats/unit/

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker
        run: |
          sudo apt-get update
          sudo apt-get install -y docker.io
          sudo systemctl start docker

      - name: Run integration tests
        run: |
          export BATS_TEST_TIMEOUT=600
          bats tests/bats/integration/
```

### Docker-in-Docker Setup

```yaml
name: Docker Integration Tests
on: [push, pull_request]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:dind
        options: --privileged

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker CLI
        run: |
          sudo apt-get update
          sudo apt-get install -y docker.io

      - name: Run integration tests
        run: |
          export DOCKER_HOST=tcp://localhost:2376
          export DOCKER_TLS_VERIFY=0
          bats tests/bats/integration/
```

### Local Development Setup

```bash
# Start Docker daemon
sudo systemctl start docker

# Run unit tests
bats -rj 16 tests/bats/unit/

# Run integration tests
bats tests/bats/integration/

# Run all tests
bats -rj 16 tests/bats/unit/
bats tests/bats/integration/
```

## Summary

### Key Principles

1. **Each test only cleans up its own directory** - Never use `find` to delete multiple directories
2. **Use common teardown utilities** - Standardized, tested, and safe for parallel execution
3. **Compute paths dynamically** - Don't initialize at module load time
4. **Use atomic file operations** - Write to temp file, then rename
5. **Test in parallel** - Always verify tests work with `-j` flag
6. **Use mocking for unit tests** - Avoid real Docker operations in unit tests
7. **Use real Docker for integration tests** - Validate actual Docker behavior

### Resources

- **Common Teardown Utilities**: `tests/bats/helpers/common_teardown.bash`
- **Test Guidelines**: This document
- **Mock System**: `tests/bats/helpers/mock_manager.bash`
- **Test Helpers**: `tests/bats/helpers/`

For questions or issues, see the implementation in the helper files or review existing tests that follow these patterns.

