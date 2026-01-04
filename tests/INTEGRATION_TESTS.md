# Integration Tests Documentation

## Overview

Suitey integration tests validate the Build Manager functionality with real Docker operations. These tests ensure that the container orchestration, resource management, and Docker API interactions work correctly in production-like environments.

## Prerequisites

### Docker Environment Requirements

#### Minimum Docker Version
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

### Environment Setup

#### 1. Install Docker
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (optional)
sudo usermod -aG docker $USER
```

#### 2. Verify Installation
```bash
# Check Docker version
docker --version

# Check Docker daemon status
docker info

# Test basic functionality
docker run hello-world
```

#### 3. Configure Docker (Optional)
```bash
# Set Docker root directory (if needed)
sudo mkdir -p /custom/docker/root
echo '{"data-root": "/custom/docker/root"}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

## Test Structure

### Test Categories

#### 1. Docker Connectivity Tests (`build_manager.bats`)
- **Docker Daemon Access**: Verifies Docker daemon connectivity
- **API Compatibility**: Tests Docker API version compatibility
- **Resource Validation**: Checks available system resources

#### 2. Container Lifecycle Tests (`build_manager.bats`)
- **Container Creation**: Tests real container launch with proper configuration
- **Resource Management**: Validates CPU, memory, and volume mounting
- **Container Inspection**: Verifies container configuration matches requirements

#### 3. Build and Image Management (`build_manager.bats`)
- **Image Building**: Tests Docker image creation from Dockerfiles
- **Artifact Handling**: Validates build artifact extraction and storage
- **Image Cleanup**: Ensures proper image removal after tests

#### 4. Adapter Registry Integration (`adapter_registry_*.bats`)
- **Framework Detection**: Tests adapter-based framework discovery
- **Project Scanning**: Validates project structure analysis
- **Test Suite Discovery**: Ensures proper test identification

### Test Files
```
tests/bats/integration/
├── build_manager.bats                 # Core Docker operations
├── adapter_registry_framework_detector.bats
├── adapter_registry_project_scanner.bats
└── adapter_registry_test_suite_discovery.bats
```

## Running Integration Tests

### Basic Execution
```bash
# Run all integration tests
bats tests/bats/integration/

# Run specific test file
bats tests/bats/integration/build_manager.bats

# Run specific test
bats tests/bats/integration/build_manager.bats -f "container_creation"
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

### Conditional Execution
```bash
# Skip tests if Docker unavailable
check_docker_available || skip "Docker daemon not available"

# Skip tests if insufficient resources
check_docker_environment || skip "Docker environment not ready"
```

## Test Infrastructure

### Helper Functions

#### Docker Validation
```bash
# Basic availability check
check_docker_available()

# Comprehensive environment validation
check_docker_environment()
```

#### Resource Management
```bash
# Clean up all Docker resources
cleanup_docker_resources()

# Clean up specific resource types
cleanup_docker_containers()
cleanup_docker_images()
cleanup_docker_volumes()
cleanup_docker_networks()
```

#### Test Isolation
```bash
# Setup isolated test environment
setup_test_isolation()

# Generate unique resource names
generate_test_resource_name()

# Cleanup test isolation
cleanup_test_isolation()
```

#### Error Handling
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

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
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

# Run integration tests
make integration-tests

# Or run directly
bats tests/bats/integration/
```

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

## Resource Management

### Automatic Cleanup
Integration tests automatically clean up resources using teardown functions:

```bash
# Called automatically after each test
teardown_build_manager_test() {
  cleanup_test_isolation
  cleanup_docker_resources
}
```

### Manual Cleanup
If tests fail or resources remain:

```bash
# Clean up all Suitey test resources
cleanup_docker_resources "suitey*"

# Aggressive cleanup
docker system prune -a --volumes -f
```

### Resource Monitoring
```bash
# Monitor resource usage during tests
docker system df -v

# Check for orphaned resources
docker ps -a --filter "status=exited"
docker images -f "dangling=true"
docker volume ls -f "dangling=true"
```

## Best Practices

### Test Development
1. **Use unique resource names** to avoid conflicts
2. **Implement proper cleanup** in teardown functions
3. **Handle Docker unavailability** gracefully with skip conditions
4. **Set appropriate timeouts** for long-running operations
5. **Validate test data** before running Docker operations

### CI/CD Considerations
1. **Use Docker-in-Docker** for isolated test environments
2. **Configure resource limits** to prevent CI resource exhaustion
3. **Implement retry logic** for transient Docker failures
4. **Cache Docker images** to reduce pull times
5. **Parallelize tests** when possible

### Maintenance
1. **Regular cleanup** of test Docker resources
2. **Monitor resource usage** trends
3. **Update Docker versions** regularly
4. **Review test timeouts** and adjust as needed
5. **Document environment requirements** clearly

## Performance Optimization

### Test Execution Time
- **Typical runtime**: 2-5 minutes for full integration test suite
- **Bottlenecks**: Image pulls, container startup, build operations
- **Optimization**: Use pre-built images, minimize artifact sizes

### Resource Usage
- **Disk space**: ~500MB for test images and containers
- **Memory**: ~256MB per concurrent test
- **Network**: ~50MB for image pulls

### Parallel Execution
```bash
# Run tests in parallel (if implemented)
bats --jobs 4 tests/bats/integration/

# Or use GNU parallel
find tests/bats/integration/ -name "*.bats" | parallel bats {}
```

## Security Considerations

### Docker Security
- **Run tests in isolated networks** to prevent external access
- **Use minimal base images** to reduce attack surface
- **Avoid privileged containers** unless absolutely necessary
- **Clean up test resources** immediately after use

### CI/CD Security
- **Use trusted base images** from verified registries
- **Implement image scanning** for vulnerabilities
- **Limit Docker daemon access** to CI runners
- **Regular security updates** for Docker and host system

This documentation provides comprehensive guidance for setting up, running, and maintaining Suitey's integration tests with real Docker operations.

