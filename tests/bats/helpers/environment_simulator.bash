#!/usr/bin/env bash
# Environment Simulation for Build Manager Tests
# Provides file system mocking, process tracking, and Docker daemon simulation

# ============================================================================
# File System Simulation
# ============================================================================

# Global variables for file system simulation
declare -A MOCK_FILESYSTEM=()
declare -A MOCK_DIRECTORIES=()
MOCK_CWD="/mock/root"

# Initialize mock file system
# Arguments:
#   base_dir: Base directory to simulate
mock_fs_init() {
  local base_dir="$1"

  MOCK_FILESYSTEM=()
  MOCK_DIRECTORIES=()
  MOCK_CWD="$base_dir"

  # Initialize mock manager if needed
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "fs_simulation"
  fi

  # Create basic directory structure
  mock_fs_mkdir "$base_dir"
  mock_fs_mkdir "$base_dir/src"
  mock_fs_mkdir "$base_dir/tests"
  mock_fs_mkdir "$base_dir/target"

  # Update mock state
  _mock_manager_update_state "filesystem_initialized" "true"
}

# Create a mock directory
# Arguments:
#   dir_path: Directory path to create
mock_fs_mkdir() {
  local dir_path="$1"

  # Normalize path
  dir_path=$(mock_fs_normalize_path "$dir_path")

  # Mark as directory
  MOCK_DIRECTORIES["$dir_path"]=1

  # Update mock state
  _mock_manager_update_state "fs_dir_created" "$dir_path"
}

# Create a mock file
# Arguments:
#   file_path: File path to create
#   content: File content (optional)
mock_fs_create_file() {
  local file_path="$1"
  local content="${2:-}"

  # Normalize path
  file_path=$(mock_fs_normalize_path "$file_path")

  # Store file content
  MOCK_FILESYSTEM["$file_path"]="$content"

  # Ensure parent directory exists
  local parent_dir
  parent_dir=$(dirname "$file_path")
  if [[ "$parent_dir" != "/" ]] && [[ ! -v MOCK_DIRECTORIES["$parent_dir"] ]]; then
    mock_fs_mkdir "$parent_dir"
  fi

  # Update mock state
  _mock_manager_update_state "fs_file_created" "$file_path"
}

# Read a mock file
# Arguments:
#   file_path: File path to read
# Returns: File content or error
mock_fs_read_file() {
  local file_path="$1"

  # Normalize path
  file_path=$(mock_fs_normalize_path "$file_path")

  if [[ -v MOCK_FILESYSTEM["$file_path"] ]]; then
    echo "${MOCK_FILESYSTEM[$file_path]}"
    return 0
  else
    echo "ERROR: File not found: $file_path" >&2
    return 1
  fi
}

# Check if mock file exists
# Arguments:
#   file_path: File path to check
# Returns: 0 if exists, 1 if not
mock_fs_file_exists() {
  local file_path="$1"

  # Normalize path
  file_path=$(mock_fs_normalize_path "$file_path")

  [[ -v MOCK_FILESYSTEM["$file_path"] ]]
}

# Check if mock directory exists
# Arguments:
#   dir_path: Directory path to check
# Returns: 0 if exists, 1 if not
mock_fs_dir_exists() {
  local dir_path="$1"

  # Normalize path
  dir_path=$(mock_fs_normalize_path "$dir_path")

  [[ -v MOCK_DIRECTORIES["$dir_path"] ]]
}

# List mock directory contents
# Arguments:
#   dir_path: Directory path to list
# Returns: Space-separated list of files/directories
mock_fs_list_dir() {
  local dir_path="$1"

  # Normalize path
  dir_path=$(mock_fs_normalize_path "$dir_path")

  local results=()

  # Find files in this directory
  for file_path in "${!MOCK_FILESYSTEM[@]}"; do
    if [[ "$(dirname "$file_path")" == "$dir_path" ]]; then
      results+=("$(basename "$file_path")")
    fi
  done

  # Find subdirectories
  for dir in "${!MOCK_DIRECTORIES[@]}"; do
    if [[ "$(dirname "$dir")" == "$dir_path" ]] && [[ "$dir" != "$dir_path" ]]; then
      results+=("$(basename "$dir")/")
    fi
  done

  echo "${results[*]}"
}

# Copy mock files (simulate artifact extraction)
# Arguments:
#   source: Source file path
#   dest: Destination file path
mock_fs_copy() {
  local source="$1"
  local dest="$2"

  # Normalize paths
  source=$(mock_fs_normalize_path "$source")
  dest=$(mock_fs_normalize_path "$dest")

  if [[ -v MOCK_FILESYSTEM["$source"] ]]; then
    MOCK_FILESYSTEM["$dest"]="${MOCK_FILESYSTEM[$source]}"

    # Ensure destination directory exists
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [[ ! -v MOCK_DIRECTORIES["$dest_dir"] ]]; then
      mock_fs_mkdir "$dest_dir"
    fi

    # Update mock state
    _mock_manager_update_state "fs_file_copied" "$source:$dest"
    return 0
  else
    echo "ERROR: Source file not found: $source" >&2
    return 1
  fi
}

# Normalize file paths for mock filesystem
# Arguments:
#   path: Path to normalize
# Returns: Normalized path
mock_fs_normalize_path() {
  local path="$1"

  # Remove leading slash if present
  path="${path#/}"

  # Add mock root
  echo "$MOCK_CWD/$path"
}

# Reset mock file system
mock_fs_reset() {
  MOCK_FILESYSTEM=()
  MOCK_DIRECTORIES=()
  MOCK_CWD="/mock/root"
}

# ============================================================================
# Process Tracking Simulation
# ============================================================================

# Global variables for process simulation
declare -A MOCK_PROCESSES=()
MOCK_PROCESS_ID=1

# Start a mock process
# Arguments:
#   command: Command to "execute"
#   background: Whether to run in background (default: false)
# Returns: Process ID
mock_process_start() {
  local command="$1"
  local background="${2:-false}"

  local pid=$MOCK_PROCESS_ID
  ((MOCK_PROCESS_ID++))

  MOCK_PROCESSES["$pid"]="running:$command:$(date +%s)"

  # Update mock state
  _mock_manager_update_state "process_started" "$pid:$command"

  if [[ "$background" == "true" ]]; then
    # Simulate background process
    (
      sleep 1  # Simulate some execution time
      MOCK_PROCESSES["$pid"]="completed:$command:$(date +%s)"
      _mock_manager_update_state "process_completed" "$pid"
    ) &
  fi

  echo "$pid"
}

# Check if mock process is running
# Arguments:
#   pid: Process ID to check
# Returns: 0 if running, 1 if not
mock_process_running() {
  local pid="$1"

  if [[ -v MOCK_PROCESSES["$pid"] ]]; then
    local status="${MOCK_PROCESSES[$pid]%%:*}"
    [[ "$status" == "running" ]]
  else
    return 1
  fi
}

# Kill a mock process
# Arguments:
#   pid: Process ID to kill
#   signal: Signal to send (default: TERM)
# Returns: 0 on success, 1 if process not found
mock_process_kill() {
  local pid="$1"
  local signal="${2:-TERM}"

  if [[ -v MOCK_PROCESSES["$pid"] ]]; then
    MOCK_PROCESSES["$pid"]="killed:$signal:$(date +%s)"
    _mock_manager_update_state "process_killed" "$pid:$signal"
    return 0
  else
    return 1
  fi
}

# Wait for mock process completion
# Arguments:
#   pid: Process ID to wait for
#   timeout: Timeout in seconds (default: 10)
# Returns: 0 if completed, 1 if timed out
mock_process_wait() {
  local pid="$1"
  local timeout="${2:-10}"

  local start_time=$(date +%s)

  while [[ $(date +%s) -lt $((start_time + timeout)) ]]; do
    if [[ -v MOCK_PROCESSES["$pid"] ]]; then
      local status="${MOCK_PROCESSES[$pid]%%:*}"
      if [[ "$status" == "completed" ]] || [[ "$status" == "killed" ]]; then
        return 0
      fi
    fi
    sleep 0.1
  done

  return 1
}

# Get mock process status
# Arguments:
#   pid: Process ID to check
# Returns: Process status string
mock_process_status() {
  local pid="$1"

  if [[ -v MOCK_PROCESSES["$pid"] ]]; then
    echo "${MOCK_PROCESSES[$pid]}"
  else
    echo "not_found"
  fi
}

# Reset mock process tracking
mock_process_reset() {
  MOCK_PROCESSES=()
  MOCK_PROCESS_ID=1
}

# ============================================================================
# Docker Daemon State Simulation
# ============================================================================

# Global variables for Docker daemon simulation
MOCK_DOCKER_RUNNING=false
MOCK_DOCKER_VERSION="20.10.0"
declare -A MOCK_DOCKER_IMAGES=()
declare -A MOCK_DOCKER_CONTAINERS=()

# Initialize Docker daemon simulation
mock_docker_init() {
  MOCK_DOCKER_RUNNING=true

  # Initialize mock manager if needed
  if [[ "$MOCK_INITIALIZED" != "true" ]]; then
    mock_manager_init "docker_simulation"
  fi

  # Add some default images
  MOCK_DOCKER_IMAGES["rust:latest"]="sha256:rust123"
  MOCK_DOCKER_IMAGES["node:latest"]="sha256:node456"
  MOCK_DOCKER_IMAGES["python:latest"]="sha256:python789"

  _mock_manager_update_state "docker_initialized" "true"
}

# Check if mock Docker daemon is running
# Returns: 0 if running, 1 if not
mock_docker_running() {
  [[ "$MOCK_DOCKER_RUNNING" == "true" ]]
}

# Get mock Docker version
# Returns: Version string
mock_docker_version() {
  echo "$MOCK_DOCKER_VERSION"
}

# Simulate Docker info command
# Returns: Mock Docker info output
mock_docker_info() {
  if [[ "$MOCK_DOCKER_RUNNING" == "true" ]]; then
    echo "Mock Docker daemon running"
    echo "Version: $MOCK_DOCKER_VERSION"
    echo "Images: ${#MOCK_DOCKER_IMAGES[@]}"
    echo "Containers: ${#MOCK_DOCKER_CONTAINERS[@]}"
    return 0
  else
    echo "ERROR: Docker daemon not running" >&2
    return 1
  fi
}

# Create a mock Docker image
# Arguments:
#   image_name: Name of image to create
#   base_image: Base image (optional)
mock_docker_create_image() {
  local image_name="$1"
  local base_image="${2:-}"

  local image_id="sha256:mock$(date +%s | md5sum | cut -c1-8)"

  MOCK_DOCKER_IMAGES["$image_name"]="$image_id"

  # Update mock state
  _mock_manager_update_state "docker_image_created" "$image_name:$image_id"

  echo "$image_id"
}

# Check if mock Docker image exists
# Arguments:
#   image_name: Name of image to check
# Returns: 0 if exists, 1 if not
mock_docker_image_exists() {
  local image_name="$1"

  [[ -v MOCK_DOCKER_IMAGES["$image_name"] ]]
}

# List mock Docker images
# Returns: Space-separated list of image names
mock_docker_list_images() {
  echo "${!MOCK_DOCKER_IMAGES[*]}"
}

# Create a mock Docker container
# Arguments:
#   container_name: Name of container to create
#   image_name: Image to use
mock_docker_create_container() {
  local container_name="$1"
  local image_name="$2"

  if [[ -v MOCK_DOCKER_IMAGES["$image_name"] ]]; then
    local container_id="mock_container_$(date +%s | md5sum | cut -c1-8)"
    MOCK_DOCKER_CONTAINERS["$container_name"]="created:$image_name:$(date +%s)"

    # Update mock state
    _mock_manager_update_state "docker_container_created" "$container_name:$container_id"

    echo "$container_id"
    return 0
  else
    echo "ERROR: Image not found: $image_name" >&2
    return 1
  fi
}

# Start a mock Docker container
# Arguments:
#   container_name: Name of container to start
mock_docker_start_container() {
  local container_name="$1"

  if [[ -v MOCK_DOCKER_CONTAINERS["$container_name"] ]]; then
    MOCK_DOCKER_CONTAINERS["$container_name"]="running:$(echo "${MOCK_DOCKER_CONTAINERS[$container_name]}" | cut -d: -f2-):$(date +%s)"
    _mock_manager_update_state "docker_container_started" "$container_name"
    return 0
  else
    echo "ERROR: Container not found: $container_name" >&2
    return 1
  fi
}

# Stop a mock Docker container
# Arguments:
#   container_name: Name of container to stop
mock_docker_stop_container() {
  local container_name="$1"

  if [[ -v MOCK_DOCKER_CONTAINERS["$container_name"] ]]; then
    MOCK_DOCKER_CONTAINERS["$container_name"]="stopped:$(echo "${MOCK_DOCKER_CONTAINERS[$container_name]}" | cut -d: -f2-):$(date +%s)"
    _mock_manager_update_state "docker_container_stopped" "$container_name"
    return 0
  else
    echo "ERROR: Container not found: $container_name" >&2
    return 1
  fi
}

# Remove a mock Docker container
# Arguments:
#   container_name: Name of container to remove
mock_docker_remove_container() {
  local container_name="$1"

  if [[ -v MOCK_DOCKER_CONTAINERS["$container_name"] ]]; then
    unset MOCK_DOCKER_CONTAINERS["$container_name"]
    _mock_manager_update_state "docker_container_removed" "$container_name"
    return 0
  else
    echo "ERROR: Container not found: $container_name" >&2
    return 1
  fi
}

# Reset mock Docker daemon state
mock_docker_reset() {
  MOCK_DOCKER_RUNNING=false
  MOCK_DOCKER_IMAGES=()
  MOCK_DOCKER_CONTAINERS=()
}

# ============================================================================
# Integration Setup
# ============================================================================

# Initialize complete environment simulation
# Should be called at the start of complex tests
init_environment_simulation() {
  # Initialize all simulation components
  mock_fs_init "/mock/project"
  mock_process_reset
  mock_docker_init

  # Set up initial project structure
  mock_fs_create_file "/mock/project/Cargo.toml" '[package]\nname = "test-project"\nversion = "0.1.0"'
  mock_fs_create_file "/mock/project/src/main.rs" 'fn main() { println!("Hello"); }'
  mock_fs_create_file "/mock/project/tests/test.rs" '#[test] fn test() { assert!(true); }'

  # Update mock state
  _mock_manager_update_state "environment_initialized" "true"
}

# Clean up environment simulation
# Should be called in teardown
cleanup_environment_simulation() {
  mock_fs_reset
  mock_process_reset
  mock_docker_reset
}

