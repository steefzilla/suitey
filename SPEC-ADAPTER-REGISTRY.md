# Adapter Registry Specification

## Overview

The Adapter Registry is a shared component of Suitey responsible for maintaining a centralized registry of framework adapters and providing a consistent interface for framework-specific operations. It serves as the foundation for Suitey's framework-agnostic architecture, enabling automatic detection, discovery, build detection, and execution of tests across multiple testing frameworks without hardcoding framework-specific logic. The Adapter Registry is used by Framework Detector, Test Suite Discovery, Build System Detector, and the execution system to coordinate framework-specific operations.

## Responsibilities

The Adapter Registry is responsible for:

1. **Adapter Registration**: Maintaining a registry of all available framework adapters
2. **Adapter Access**: Providing access to registered adapters for framework-specific operations
3. **Interface Enforcement**: Ensuring all adapters implement the required interface
4. **Adapter Lifecycle Management**: Managing adapter initialization, validation, and cleanup
5. **Adapter Discovery**: Enabling discovery of available adapters at runtime
6. **Metadata Management**: Storing and providing access to adapter metadata (name, version, capabilities, etc.)
7. **Error Handling**: Managing adapter-related errors and providing graceful degradation

## Architecture Position

The Adapter Registry operates as a shared component within the main suitey process:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner (Orchestrator)     │
│  ├─ Framework Detector              │
│  │  └─ Adapter Registry             │ ← This component
│  ├─ Test Suite Discovery            │
│  │  └─ Adapter Registry             │ ← Used here too
│  └─ Build System Detector           │
│     └─ Adapter Registry             │ ← And here
│  Build Manager                      │
│  Parallel Execution Manager         │
│     └─ Adapter Registry             │ ← And here
└─────────────────────────────────────┘
```

### Relationship to Other Components

- **Framework Detector**: Uses the Adapter Registry to access framework-specific detection logic. Framework Detector coordinates adapter-based detection by calling detection methods on registered adapters.
- **Test Suite Discovery**: Uses the Adapter Registry to access framework-specific discovery logic. Test Suite Discovery uses adapters to find test files using framework-specific patterns.
- **Build System Detector**: Uses the Adapter Registry to access framework-specific build detection logic. Build System Detector uses adapters to determine build requirements per framework.
- **Execution System**: Uses the Adapter Registry to access framework-specific execution and parsing logic. The execution system uses adapters to run tests and extract structured results.
- **Project Scanner**: Orchestrates components that use the Adapter Registry, but does not directly access it.

## Adapter Interface

All framework adapters must implement a consistent interface that defines the contract for framework-specific operations. The interface consists of the following methods:

### Core Interface Methods

#### 1. Detection Methods

- **`detect(project_root: string) -> DetectionResult`**
  - Determines if this framework is present in the project
  - Uses framework-specific heuristics (config files, package manager files, directory patterns, etc.)
  - Returns a `DetectionResult` containing:
    - `detected: boolean` - Whether the framework is present
    - `confidence: string` - Confidence level (`high`, `medium`, `low`)
    - `indicators: array` - List of indicators that led to detection
    - `metadata: object` - Framework metadata (name, version, etc.)

- **`check_binaries(project_root: string) -> BinaryStatus`**
  - Verifies that required framework tools are available
  - Checks for framework executables in PATH or containers
  - Returns a `BinaryStatus` containing:
    - `available: boolean` - Whether required binaries are available
    - `binaries: array` - List of required binaries with availability status
    - `versions: object` - Binary versions (if detectable)
    - `container_check: boolean` - Whether to check in containers

#### 2. Discovery Methods

- **`discover_test_suites(project_root: string, framework_metadata: object) -> TestSuite[]`**
  - Finds test files/suites for this framework using framework-specific patterns
  - Uses framework-specific heuristics (directory patterns, file naming conventions, etc.)
  - Returns an array of `TestSuite` objects containing:
    - `name: string` - Suite identifier/name
    - `framework: string` - Framework identifier
    - `test_files: array` - List of test file paths
    - `metadata: object` - Suite-specific metadata
    - `execution_config: object` - Execution configuration

#### 3. Build Detection Methods

- **`detect_build_requirements(project_root: string, framework_metadata: object) -> BuildRequirements`**
  - Determines if building is required before testing
  - Analyzes build configuration files, package manager scripts, source code patterns
  - Returns a `BuildRequirements` object containing:
    - `requires_build: boolean` - Whether building is required
    - `build_steps: array` - List of build steps needed
    - `build_commands: array` - Specific build commands
    - `build_dependencies: array` - Build dependencies
    - `build_artifacts: array` - Expected build artifacts

- **`get_build_steps(project_root: string, build_requirements: BuildRequirements) -> BuildStep[]`**
  - Specifies how to build the project in a containerized environment
  - Returns an array of `BuildStep` objects containing:
    - `step_name: string` - Build step identifier
    - `docker_image: string` - Docker image to use
    - `build_command: string` - Build command to execute
    - `working_directory: string` - Working directory in container
    - `volume_mounts: array` - Volume mounts for build artifacts
    - `environment_variables: object` - Environment variables

#### 4. Execution Methods

- **`execute_test_suite(test_suite: TestSuite, build_artifacts: BuildArtifacts, execution_config: object) -> ExecutionResult`**
  - Runs tests using the framework's native tools in containers
  - Handles Docker container creation, execution, and cleanup
  - Returns an `ExecutionResult` containing:
    - `exit_code: number` - Exit code from test runner
    - `duration: number` - Execution time in seconds
    - `output: string` - Raw stdout/stderr output
    - `container_id: string` - Docker container ID (if used)
    - `execution_method: string` - Execution method used (`docker`, `docker-compose`, `native`)

#### 5. Parsing Methods

- **`parse_test_results(output: string, exit_code: number) -> ParsedResults`**
  - Extracts test results (counts, status, output) from framework output
  - Parses framework-specific output patterns
  - Returns a `ParsedResults` object containing:
    - `total_tests: number` - Total number of tests
    - `passed_tests: number` - Number of passed tests
    - `failed_tests: number` - Number of failed tests
    - `skipped_tests: number` - Number of skipped tests (if applicable)
    - `test_details: array` - Individual test results (if parseable)
    - `status: string` - Overall status (`passed`, `failed`, `error`)

#### 6. Metadata Methods

- **`get_metadata() -> AdapterMetadata`**
  - Returns adapter metadata
  - Returns an `AdapterMetadata` object containing:
    - `name: string` - Framework name
    - `identifier: string` - Framework identifier (unique)
    - `version: string` - Adapter version
    - `supported_languages: array` - Supported languages
    - `capabilities: array` - Adapter capabilities
    - `required_binaries: array` - Required binaries
    - `configuration_files: array` - Configuration file patterns

### Interface Compliance

- All adapters must implement all interface methods
- Methods may return empty/null values when not applicable (e.g., `requires_build: false` when no build is needed)
- Methods should handle errors gracefully and return appropriate error indicators
- Adapters should validate inputs and provide clear error messages

## Registration System

The Adapter Registry maintains a registry of all available framework adapters. Adapters can be registered in several ways:

### 1. Built-in Adapters

Built-in adapters are registered automatically when the Adapter Registry is initialized. These include:

- **BATS** - Bash Automated Testing System
- **Rust** - cargo test
- **JavaScript/TypeScript** - Jest, Mocha, Vitest, Jasmine, etc.
- **Python** - pytest, unittest, nose2
- **Go** - go test
- **Java** - JUnit (via Maven/Gradle)
- **Ruby** - RSpec, Minitest
- And more as needed

### 2. Registration Process

1. **Adapter Initialization**: Adapter is instantiated and validated
2. **Interface Validation**: Registry verifies adapter implements required interface
3. **Metadata Extraction**: Registry extracts adapter metadata
4. **Registration**: Adapter is added to registry with unique identifier
5. **Capability Registration**: Adapter capabilities are registered

### 3. Adapter Identifiers

Each adapter has a unique identifier used for:
- Registry lookup
- Framework identification
- Error reporting
- Logging

Identifiers should be:
- Lowercase
- Hyphen-separated (e.g., `bats`, `rust`, `jest`, `pytest`)
- Descriptive and framework-specific

### 4. Registration API

The registry provides methods for adapter registration:

- **`register_adapter(adapter: Adapter) -> void`**
  - Registers a new adapter
  - Validates interface compliance
  - Throws error if adapter is invalid or identifier conflicts

- **`get_adapter(identifier: string) -> Adapter | null`**
  - Retrieves adapter by identifier
  - Returns `null` if adapter not found

- **`get_all_adapters() -> Adapter[]`**
  - Returns all registered adapters

- **`get_adapters_by_capability(capability: string) -> Adapter[]`**
  - Returns adapters with specific capability

- **`is_registered(identifier: string) -> boolean`**
  - Checks if adapter is registered

## Adapter Lifecycle

### 1. Initialization

- Adapters are initialized when the Adapter Registry is created
- Initialization may include:
  - Loading adapter code
  - Validating adapter interface
  - Extracting adapter metadata
  - Checking adapter dependencies

### 2. Validation

- Adapters are validated to ensure they implement the required interface
- Validation checks:
  - All required methods are present
  - Method signatures match expected interface
  - Metadata is complete and valid
  - Required binaries are specified

### 3. Registration

- Validated adapters are registered in the registry
- Registration includes:
  - Storing adapter instance
  - Indexing by identifier
  - Storing metadata
  - Registering capabilities

### 4. Usage

- Adapters are accessed through the registry
- Methods are called on adapter instances
- Results are returned to calling components

### 5. Cleanup

- Adapters may require cleanup after use
- Cleanup may include:
  - Releasing resources
  - Closing connections
  - Cleaning up temporary files

## Supported Frameworks

The Adapter Registry supports adapters for multiple test frameworks:

### JavaScript/TypeScript
- Jest
- Mocha
- Vitest
- Jasmine
- And more as needed

### Python
- pytest
- unittest
- nose2
- And more as needed

### Go
- go test (standard library testing)

### Rust
- cargo test (standard library testing)

### Java
- JUnit (via Maven/Gradle)

### Ruby
- RSpec
- Minitest

### Bash/Shell
- BATS (Bash Automated Testing System)

### Future Frameworks
- Additional frameworks can be added through adapter registration

## Adapter Metadata

Each adapter provides metadata that describes its capabilities and requirements:

### Metadata Structure

```typescript
{
  name: string,                    // Human-readable framework name
  identifier: string,              // Unique identifier (e.g., "bats", "jest")
  version: string,                 // Adapter version
  supported_languages: string[],  // Languages supported (e.g., ["bash", "shell"])
  capabilities: string[],          // Capabilities (e.g., ["parallel", "coverage"])
  required_binaries: string[],     // Required binaries (e.g., ["bats"])
  configuration_files: string[],   // Config file patterns (e.g., ["*.bats"])
  test_file_patterns: string[],    // Test file patterns (e.g., ["*.bats"])
  test_directory_patterns: string[] // Test directory patterns (e.g., ["tests/bats"])
}
```

### Metadata Usage

Metadata is used for:
- Framework identification
- Capability checking
- Error reporting
- Documentation generation
- Adapter discovery

## Error Handling

The Adapter Registry handles various error scenarios:

### 1. Adapter Registration Errors

- **Invalid Interface**: Adapter doesn't implement required interface
  - Error: Clear message indicating missing methods
  - Action: Reject registration, log error

- **Identifier Conflict**: Adapter identifier already registered
  - Error: Clear message indicating conflict
  - Action: Reject registration, suggest alternative identifier

- **Invalid Metadata**: Adapter metadata is incomplete or invalid
  - Error: Clear message indicating missing/invalid fields
  - Action: Reject registration, log error

### 2. Adapter Access Errors

- **Adapter Not Found**: Requested adapter not registered
  - Error: Clear message indicating adapter not found
  - Action: Return null, log warning

- **Adapter Initialization Failure**: Adapter fails to initialize
  - Error: Clear message indicating initialization failure
  - Action: Skip adapter, continue with others

### 3. Adapter Execution Errors

- **Method Call Failure**: Adapter method throws exception
  - Error: Clear message with exception details
  - Action: Return error result, log error

- **Invalid Return Value**: Adapter returns invalid result structure
  - Error: Clear message indicating invalid structure
  - Action: Return error result, log warning

### 4. Graceful Degradation

- If an adapter fails, the registry should:
  - Log the error clearly
  - Continue with other adapters
  - Report which adapters were skipped and why
  - Provide actionable error messages

## Performance Considerations

### 1. Lazy Loading

- Adapters can be loaded lazily (on first use) to improve startup time
- Only load adapters that are needed for the current project

### 2. Caching

- Cache adapter instances to avoid repeated instantiation
- Cache adapter metadata to avoid repeated extraction
- Cache detection results when appropriate

### 3. Parallel Execution

- Adapter methods can be called in parallel when independent
- Registry should support parallel adapter operations

### 4. Efficient Lookup

- Use efficient data structures for adapter lookup (hash maps, indexes)
- Index adapters by identifier, capability, language, etc.

## Implementation Notes

### 1. Registry Initialization

The registry should be initialized early in the suitey process:

1. Load built-in adapters
2. Validate all adapters
3. Register all adapters
4. Index adapters for efficient lookup

### 2. Adapter Discovery

Adapters can be discovered through:

- **Built-in List**: Hardcoded list of built-in adapters
- **Plugin System**: Dynamic loading of adapter plugins (future)
- **Configuration**: Adapters specified in configuration (future)

### 3. Cross-Platform Considerations

- Adapters should work across platforms (Linux, macOS, Windows)
- Binary detection should account for platform differences
- Path handling should be cross-platform

### 4. Extensibility

The registry is designed to be extensible:

- New adapters can be added without modifying core registry logic
- Adapter interface can be extended (with backward compatibility)
- Custom adapters can be registered (future)

### 5. Testing

The registry should be testable:

- Mock adapters for testing
- Test adapter registration and lookup
- Test error handling
- Test interface compliance

## Adapter Examples

### BATS Adapter

The BATS adapter implements:

- **Detection**: Detects `.bats` files, `bats` binary, directory patterns
- **Discovery**: Finds `.bats` files in test directories
- **Build Detection**: Typically no build required
- **Execution**: Runs `bats <test-file>` in Docker container
- **Parsing**: Parses BATS output to extract test counts

### Rust Adapter

The Rust adapter implements:

- **Detection**: Detects `Cargo.toml`, `cargo` binary, test file patterns
- **Discovery**: Finds unit tests in `src/` and integration tests in `tests/`
- **Build Detection**: May require `cargo build` before testing
- **Execution**: Runs `cargo test` in Docker container
- **Parsing**: Parses cargo test output to extract test counts

### Future Adapters

Additional adapters will follow the same interface pattern:

- **Jest Adapter**: Detects Jest config, discovers test files, executes `npm test` or `jest`
- **pytest Adapter**: Detects pytest config, discovers test files, executes `pytest`
- **Go Adapter**: Detects `go.mod`, discovers test files, executes `go test`
- And more as needed

## Integration Points

The Adapter Registry integrates with:

1. **Framework Detector**: Provides adapters for framework detection
2. **Test Suite Discovery**: Provides adapters for test file discovery
3. **Build System Detector**: Provides adapters for build requirement detection
4. **Execution System**: Provides adapters for test execution and result parsing
5. **Error Reporting**: Provides adapter metadata for error messages
6. **Report Generation**: Provides adapter information for reports

## Future Considerations

- **Plugin System**: Dynamic loading of adapter plugins
- **Adapter Versioning**: Support for multiple versions of same adapter
- **Adapter Configuration**: Per-adapter configuration options
- **Custom Adapters**: User-defined adapters for custom frameworks
- **Adapter Marketplace**: Shared repository of community adapters
- **Adapter Testing**: Testing framework for adapter development
- **Adapter Documentation**: Auto-generated documentation from adapter metadata

