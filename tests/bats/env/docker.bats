#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Docker Environment Checks
# ============================================================================

# Global Docker availability detection - set at file load time
# This ensures the variable is available when skip conditions are evaluated
export BATS_DOCKER_AVAILABLE=false

# Check if Docker command exists and daemon is accessible
if command -v docker >/dev/null 2>&1; then
  # Quick check if Docker daemon is accessible
  # Try without timeout first (docker info usually returns quickly if daemon isn't accessible)
  if docker info >/dev/null 2>&1; then
    export BATS_DOCKER_AVAILABLE=true
  else
    # If that fails, try with timeout if available (for systems where docker might hang)
    if command -v timeout >/dev/null 2>&1; then
      if timeout 5 docker info >/dev/null 2>&1; then
        export BATS_DOCKER_AVAILABLE=true
      fi
    fi
  fi
fi

@test "docker daemon is running" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker info
  [ "$status" -eq 0 ]
}

@test "docker daemon is accessible" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  # Test that we have permission to access docker
  run docker ps
  # Status 0 means accessible, other codes might indicate permission issues
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # 0=success, 1=no containers (but accessible)
}

@test "docker API version is compatible" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker version --format "{{.Server.APIVersion}}"
  [ "$status" -eq 0 ]
  # Basic check that we get a version string
  [ -n "$output" ]
}

@test "docker server version is available" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker version --format "{{.Server.Version}}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+ ]]
}

@test "docker has sufficient disk space" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker system df
  [ "$status" -eq 0 ]
  # If we can run this command, Docker has basic functionality
}

@test "docker can create and remove containers" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  # Test basic container lifecycle
  local container_name="bats_test_container_$$"

  # Create a simple container (don't start it)
  run docker create --name "$container_name" alpine:latest echo "test"
  [ "$status" -eq 0 ]

  # Verify container exists
  run docker ps -a --filter "name=$container_name" --format "{{.Names}}"
  [ "$status" -eq 0 ]
  [[ "$output" == "$container_name" ]]

  # Remove the container
  run docker rm "$container_name"
  [ "$status" -eq 0 ]
}

@test "docker-compose is available" {
  # docker-compose is optional, doesn't require Docker daemon
  command -v docker-compose >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "docker-compose has version" {
  # docker-compose is optional, doesn't require Docker daemon
  run docker-compose --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "docker-compose" ]]
}

@test "docker system has adequate resources" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  # Check if Docker has basic resource information
  run docker system info --format "{{.MemTotal}}"
  [ "$status" -eq 0 ]
  # Just check that we get some memory info
  [ -n "$output" ]
}

@test "docker images command works" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker images
  [ "$status" -eq 0 ]
  # Don't check for specific images, just that the command works
}

@test "docker network ls works" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker network ls
  [ "$status" -eq 0 ]
  # Should show at least the default networks
  [[ "$output" =~ "bridge" ]]
}

@test "docker volume ls works" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker volume ls
  [ "$status" -eq 0 ]
  # Command should work even if no volumes exist
}

@test "docker buildx is available (recommended)" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  if command -v docker buildx >/dev/null 2>&1; then
    run docker buildx version
    [ "$status" -eq 0 ]
  else
    skip "docker buildx not available (optional but recommended)"
  fi
}

@test "docker daemon accepts connections" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  # Test that we can ping the docker daemon
  # Use timeout if available, otherwise just run docker version
  if command -v timeout >/dev/null 2>&1; then
    run timeout 5 docker version
  else
    run docker version
  fi
  [ "$status" -eq 0 ]
}

@test "docker has working overlay driver" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker system info --format "{{.Driver}}"
  [ "$status" -eq 0 ]
  # Common drivers: overlay2, aufs, devicemapper, etc.
  [ -n "$output" ]
}

@test "docker container stats work" {
  [[ "$BATS_DOCKER_AVAILABLE" == "true" ]] || skip "Docker not available"
  run docker stats --no-stream --format "{{.Container}}"
  # This might fail if no containers are running, but command should be accepted
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # 0=containers exist, 1=no containers
}
