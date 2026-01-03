# Suitey Specification

## Overview

Suitey is a cross-platform tool designed to automatically discover, build (if needed), and run tests locally from any project, regardless of the test framework or build system used. It eliminates the need to know which testing tools a project uses, how to build it, or how to configure them. Simply run `suitey` in any project directory, and it will detect build requirements, execute builds in containerized environments, and run all available test suites in parallel, providing a unified dashboard view of build and test execution status.

Example dashboard display:

```
SUITE            STATUS    TIME      QUEUE   PASS    FAIL    TOTAL
unit             passed    2.3s      0       45      0       45
integration      running   1.1s      0       12      0       45
e2e              pending             50      0       0       50
performance      failed    5.7s      0       8       2       10
```

## Competitive Analysis

### Existing Solutions

Several tools address parts of Suitey's functionality, but none provide the complete zero-config, universal test execution experience:

**Language-Specific Tools** (Tox, pytest, Jest, Mocha, etc.)
- **Limitation**: Work only within their specific language/framework ecosystem
- **Requirement**: Developers must know which tool to use and how to configure it
- **Suitey Advantage**: Automatically detects and uses the appropriate tool for any project

**Build Systems** (Bazel, Make, Gradle, Maven, etc.)
- **Limitation**: Require explicit build file configuration (BUILD files, Makefiles, etc.)
- **Requirement**: Developers must understand the build system and maintain configuration
- **Suitey Advantage**: Automatically detects build requirements and executes builds without configuration

**CI/CD Platforms** (Jenkins, CircleCI, GitHub Actions, etc.)
- **Limitation**: Server-based, require extensive configuration, not designed for local development
- **Requirement**: Complex setup, YAML/config files, remote execution
- **Suitey Advantage**: Local-first, zero-config, works immediately in any project directory

**Task Runners** (Task, Just, npm scripts, etc.)
- **Limitation**: Require manual task definitions, no automatic test discovery
- **Requirement**: Developers must define and maintain task configurations
- **Suitey Advantage**: Discovers and executes tests automatically without any configuration

**Domain-Specific Tools** (Playwright, Selenium, etc.)
- **Limitation**: Focused on specific testing domains (web, browser, etc.)
- **Requirement**: Setup and configuration for each tool
- **Suitey Advantage**: Unified interface for all test types across all domains

### Suitey's Unique Value Proposition

1. **Zero Configuration**: No setup required - works immediately in any project
2. **Universal Discovery**: Automatically detects tests across languages, frameworks, and build systems
3. **Unified Dashboard**: Single interface for all test types, regardless of underlying framework
4. **Automatic Building**: Detects and executes build steps without manual configuration
5. **Containerized Execution**: Consistent, isolated test environments without setup
6. **Local-First**: Designed for developer workflows, not just CI/CD pipelines
7. **Framework Agnostic**: Works with any project without requiring knowledge of its testing stack

### Target Use Cases

- **New Developer Onboarding**: Run `suitey` to immediately see and execute all tests
- **Multi-Language Projects**: Unified test execution across different parts of a monorepo
- **Legacy Projects**: Test execution without understanding historical build/test setup
- **Rapid Prototyping**: Quick test execution without framework setup overhead
- **Code Reviews**: Easy test execution in any project being reviewed

## Requirements

- Docker and docker-compose are required for containerized builds and test execution
- Framework-specific tools are detected and used automatically (e.g., `npm`, `pytest`, `go test`, `cargo test`, `maven`, `gradle`, etc.)
- Build tools are automatically detected and used when projects require building before testing

## Core Functionality

The core functionality follows a clear workflow: **Framework Detection** → **Test Suite Discovery** → **Build System Detection** → **Execution**.

1. **Framework Detection & Adapter System**
   - Automatically detects which test frameworks are present in the project using framework adapters
   - Each framework adapter implements detection logic using heuristics:
     - Package manager files (`package.json`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, etc.)
     - Framework-specific configuration files (`jest.config.js`, `pytest.ini`, `Cargo.toml`, etc.)
     - Directory structure patterns and file extensions
   - Verifies that required framework tools are available (e.g., `bats`, `cargo`, `npm`)
   - Returns a list of detected frameworks with metadata for downstream use
   - Falls back gracefully if framework-specific tools are not available

2. **Test Suite Discovery**
   - After frameworks are detected, discovers test files and groups them into test suites
   - Uses framework adapters to find test files through framework-specific heuristics:
     - Test directory patterns (`./test/`, `./tests/`, `./__tests__/`, `./spec/`, etc.)
     - File naming patterns: `test_*.*`, `*_test.*`, `*_spec.*`, `*-test.*`, `*-spec.*`
     - Framework-specific patterns (e.g., `#[cfg(test)]` for Rust, `@test` for BATS)
   - Each test suite is identifiable as a distinct unit (by framework, directory, or file)
   - Framework-agnostic: works with JavaScript/TypeScript, Python, Go, Rust, Java, Ruby, and more

3. **Build System Detection & Automation**
   - Automatically detects if a project requires building before tests can run
   - Uses framework adapters to determine build requirements per framework:
     - Build configuration files (`Makefile`, `CMakeLists.txt`, `Dockerfile`, `docker-compose.yml`, etc.)
     - Package manager build scripts (`package.json` scripts, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, etc.)
     - Source code patterns indicating compilation needs (TypeScript, compiled languages, etc.)
   - Automatically executes build steps in containerized environments before running tests
   - Build artifacts are preserved and made available to test execution containers
   - Build steps run in parallel when multiple independent builds are detected
   - Build failures are reported clearly and prevent test execution

4. **Test Execution**
   - Uses framework adapters to execute tests with appropriate test runners:
     - JavaScript/TypeScript: `npm test`, `yarn test`, `pnpm test`, `jest`, `mocha`, `vitest`, etc.
     - Python: `pytest`, `unittest`, `nose2`, etc.
     - Go: `go test` (may include build step)
     - Rust: `cargo test` (includes build step)
     - Java: `mvn test`, `gradle test` (includes compile step)
     - Ruby: `rspec`, `minitest`
     - And more as needed

5. **Parallel Execution**
   - Runs all discovered test suites in parallel by default
   - Manages concurrent execution of multiple test processes
   - Handles process lifecycle and cleanup
   - Limits number of processes by number of CPU cores available
   - Each suite runs in isolation (native process or Docker container as appropriate)

6. **Single Suite Execution**
   - Option to run a single test suite
   - Validates that the specified suite exists before execution

7. **Output Modes**

   Both modes use the same execution engine and structured data collection. The difference is only in how results are presented.

   **Dashboard Mode (Default)**
   - Displays a real-time dashboard view when verbose is not specified
   - Dashboard shows:
     - Build status (when builds are in progress): `building`, `built`, `build-failed`
     - All test suites being executed
     - Current status of each suite (`pending`, `loading`, `running`, `passed`, `failed`, `error`)
     - Total number of tests in each suite
     - Number of tests queued
     - Number of tests passed
     - Number of tests failed
     - Total number of tests
   - Provides a summary at the end including build and test results

   **Verbose Mode**
   - Streams raw output from all test suites directly to stdout/stderr
   - Shows full test output without dashboard formatting
   - Useful for debugging and detailed inspection
   - Output is interleaved as test suites run in parallel (includes suite identification prefixes)
   - Interleaving is buffered by test suite and only output when a block is detected, with a fallback to output a whole buffer every 100ms. This is done to improve readability.

8. **Report Generation & Local Hosting**
   - After test execution completes, automatically generates a comprehensive HTML report
   - Report includes:
     - Summary statistics (total tests, passed, failed, duration)
     - Build status and results (if builds were executed)
     - Detailed results for each test suite (status, duration, test counts)
     - Individual test results with pass/fail status
     - Test output and error messages for failed tests
     - Framework and adapter information
   - Report is served using a Docker container running nginx (or similar lightweight web server)
   - Uses a common Docker image (e.g., `nginx:alpine`) to host the report
   - Container mounts the report directory and serves it on a local port (default: 8080)
   - Displays a clickable link in the terminal (e.g., `http://localhost:8080/2024-01-15-14-30-45`)
   - Report container runs until user stops it (Ctrl+C) or explicitly terminates it
   - Report files are saved to a local directory (e.g., `./suitey-reports/`) for later viewing
   - Reports are timestamped and can be archived for historical comparison
   - If port is already in use, automatically selects the next available port

## Architecture

Suitey follows a **single-process architecture** with framework detection and adapter system:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner (Orchestrator)     │
│  ├─ Framework Detector              │
│  ├─ Test Suite Discovery            │
│  └─ Build System Detector           │
│  Build Manager                      │
│  Parallel Execution Manager         │
│  Result Collector (structured data) │
│  Report Generator                   │
│  Report Server Manager              │
├─────────────────────────────────────┤
│  Shared Components:                 │
│  • Adapter Registry                 │
├─────────────────────────────────────┤
│  Presentation Layer:                │
│  • Dashboard Formatter              │
│  • Verbose Formatter                │
└─────────────────────────────────────┘
```

### Component Relationships

The architecture follows a hierarchical orchestration pattern:

1. **Project Scanner** is the primary orchestrator component responsible for:
   - Coordinating overall project analysis
   - Calling Framework Detector to identify test frameworks
   - Performing Test Suite Discovery to find and group test files
   - Performing Build System Detection to identify build requirements
   - Aggregating results from all sub-components

2. **Framework Detector** is a specialized component called by Project Scanner:
   - Identifies which test frameworks are present in the project
   - Uses the Adapter Registry to access framework-specific detection logic
   - Returns framework detection results to Project Scanner
   - Framework detection results inform both Test Suite Discovery and Build System Detection

3. **Adapter Registry** is a shared component:
   - Maintains a registry of framework adapters (BATS, Rust, Jest, pytest, etc.)
   - Provides framework-specific detection, discovery, and execution logic
   - Used by Framework Detector, Project Scanner and Build System Detector to coordinate adapter-based detection
   - Each adapter implements detection, discovery, build detection, and execution methods

4. **Test Suite Discovery** is a component orchestrated by Project Scanner:
   - Operates after Framework Detector has identified available frameworks
   - Uses framework adapters (via Adapter Registry) to find test files using framework-specific patterns
   - Groups test files into distinct test suites
   - Returns discovered test suites with metadata to Project Scanner

5. **Build System Detector** is a responsibility of Project Scanner:
   - Identifies if and how the project needs to be built before testing
   - Uses framework adapters to determine build requirements per framework
   - May use Framework Detector results to inform build detection
   - Returns build requirements to Project Scanner for coordination with Build Manager

### Key Architectural Principles

1. **Single Process**: The main suitey process directly manages all test execution.

2. **Cross-Platform**: An implementation uses platform-specific process management, file I/O, and terminal interaction.

3. **Framework-Agnostic**: Suitey doesn't depend on any specific test framework. It detects what's available and uses the appropriate tools.

4. **Adapter Pattern**: Framework adapters provide a consistent interface for framework-specific operations (detection, discovery, build detection, execution, and parsing). This enables Suitey to work with any test framework without hardcoding framework-specific logic. See Framework Adapters in Technical Considerations for details.

5. **Graceful Degradation**: If a framework's tools aren't available, Suitey skips that framework and continues with others.

6. **Containerized Execution**: Docker and docker-compose are used for:
   - Building projects in isolated, reproducible environments
   - Running tests in containers with consistent dependencies
   - Ensuring cross-platform compatibility
   - Isolating build artifacts and test outputs

7. **Structured Data Collection**: Test results are collected as structured data internally (status, test counts, execution time, output streams), not by parsing text output.

8. **Separation of Concerns**: Execution logic is separate from presentation logic. The same execution engine feeds both dashboard and verbose modes.

9. **Real-time Updates**: Results are collected and displayed as tests execute, not after completion.

## Dependencies

### External Dependencies

- **Docker**: Required for containerized builds and test execution. Must be installed and available.
- **docker-compose**: Required for multi-container builds and complex test environments. Must be installed and available.
- **Framework-Specific Tools**: Detected automatically and used within containers as needed (e.g., `npm`, `pytest`, `go`, `cargo`, `maven`, `gradle`, etc.)

### Implementation Dependencies

- **Standard Library Preferred**: The implementation should prefer standard library features where possible
- **Minimal External Dependencies**: External libraries should be kept to a minimum and only used when necessary for cross-platform compatibility or framework detection
- The tool should be distributable as a single executable or self-contained script

## Technical Considerations

### Execution Workflow

The execution follows a sequential workflow orchestrated by Project Scanner:

1. **Framework Detection Phase**: Project Scanner calls Framework Detector, which uses the Adapter Registry to identify which test frameworks are present in the project. Each adapter implements framework-specific detection logic using heuristics (package manager files, configuration files, directory patterns, etc.).

2. **Test Suite Discovery Phase**: For each detected framework, Project Scanner uses the framework's adapter to discover test files. Each adapter knows how to find test files for its framework using framework-specific patterns (directory structures, file naming conventions, etc.). Test files are grouped into distinct test suites.

3. **Build System Detection Phase**: Project Scanner uses framework adapters to determine if building is required before testing. Each adapter implements build detection logic and specifies build commands if needed. Build requirements are determined per framework.

4. **Build Phase** (if needed): Build steps execute in Docker containers to ensure consistent, isolated environments. Build artifacts are stored in volumes and made available to test containers. Build steps can run in parallel when multiple independent builds are detected.

5. **Execution Phase**: Test suites run in Docker containers using their native test runners. Each framework adapter determines the execution method (Docker container, docker-compose orchestration, etc.) and parses output to extract structured results.

### Framework Adapters

Framework adapters are the core abstraction that enables framework-agnostic test execution. Each adapter implements a consistent interface:

- **Detection**: Determines if this framework is present in the project using framework-specific heuristics
- **Discovery**: Finds test files/suites for this framework using framework-specific patterns
- **Build Detection**: Determines if building is required before testing
- **Build Steps**: Specifies how to build the project (if needed) in a containerized environment
- **Execution**: Runs tests using the framework's native tools in containers
- **Parsing**: Extracts test results (counts, status, output) from framework output

Supported frameworks (examples, expandable):
- JavaScript/TypeScript: Jest, Mocha, Vitest, Jasmine, etc.
- Python: pytest, unittest, nose2
- Go: go test
- Rust: cargo test
- Java: JUnit (via Maven/Gradle)
- Ruby: RSpec, Minitest
- Bash/Shell: BATS
- And more as needed

### Containerized Execution

- Test suites run in Docker containers using their native test runners (e.g., `npm test`, `pytest`, `go test`)
- Builds execute in Docker containers to ensure:
  - Consistent build environments across platforms
  - Proper dependency isolation
  - Reproducible builds
- Execution returns structured data:
  - Exit code (from test runner)
  - Test counts (total, passed, failed) - extracted from test framework output
  - Execution time
  - Output stream (stdout/stderr captured from container)
- Results are collected as tests execute, not after completion
- Framework-specific tools are detected at runtime within containers; missing tools result in skipped frameworks with clear error messages

### Error Handling

- Handle cases where no test directories exist
- Handle cases where no test suites are found
- Handle cases where `--suite` specifies a non-existent suite
- Handle build failures gracefully with clear error messages
- Handle test suite execution failures gracefully
- Handle cases where framework-specific tools are not available in containers
- Handle cases where Docker is not installed (required dependency)
- Handle Docker daemon connectivity issues
- Handle cases where build dependencies are missing
- Handle cases where report directory cannot be created or written to
- Handle cases where report server container cannot be started (fallback to console output only)
- Handle cases where report server port is already in use (automatically select next available port)
- Provide clear error messages indicating:
  - Which frameworks were detected
  - Which builds were attempted and their status
  - Which test suites were skipped and why
  - Build errors with actionable information
  - Report generation failures (with fallback to console output only)

### Signal Handling

- When a Control+C (SIGINT) signal is received during execution:
  - **First Control+C**: 
    - Abort all running test suites (send termination signals to all test containers)
    - Wait for all test suites to terminate gracefully (with a reasonable timeout)
    - Clean up all Docker containers (test containers, build containers, and any related containers)
    - Display a message indicating graceful shutdown is in progress
    - Exit with appropriate exit code based on partial results (if any)
  - **Second Control+C** (if received during graceful shutdown):
    - Immediately force-terminate all remaining containers using `docker kill`
    - Force-remove all containers without waiting
    - Display a message indicating forceful termination
    - Exit immediately
- Signal handling applies to all phases of execution:
  - During build phase: abort builds, clean up build containers
  - During test execution: abort tests, clean up test containers
  - During report generation: abort report generation, clean up any containers
  - During report server hosting: stop report server container and exit
- Graceful termination timeout should be reasonable (e.g., 10-30 seconds) to prevent indefinite waiting
- All Docker containers created by suitey should be tracked and cleaned up on interruption

### Exit Codes

- `0`: All test suites passed
- `1`: One or more test suites failed
- `2`: Error in suitey itself (e.g., invalid arguments, no tests found)

## Implementation Notes

### Data Collection Strategy

The tool collects structured data from test executions using temporary files.

#### Temporary Files

Each test suite writes its results to temporary files in a dedicated temp directory:

- **Output file**: Raw test output (stdout/stderr) for verbose mode
- **Result file**: Structured data (exit code, test counts, execution time)

#### Data Extraction

Each framework adapter implements parsing logic to extract test results from framework output. Test counts are extracted by parsing framework-specific output patterns (e.g., "✓ 5 passed, ✗ 2 failed", "Tests: 10 passed, 2 failed"). Exit codes determine overall pass/fail status. This adapter-based parsing approach supports multiple test frameworks with different output formats.

### Report Generation & Hosting

#### Report Format

Reports are generated as standalone HTML files with embedded CSS and JavaScript for portability:
- **Summary Section**: Overall statistics, build status, execution time
- **Test Suites Section**: Detailed breakdown per suite with expandable sections
- **Individual Test Results**: Pass/fail status, duration, error messages
- **Timeline Visualization**: Visual representation of test execution order and duration
- **Framework Information**: Which adapters were used, detected frameworks
- **Build Information**: Build steps executed, build artifacts, build duration

#### Report Storage

- Reports are saved to `./suitey-reports/` directory (created if it doesn't exist)
- Filename format: `report-YYYY-MM-DD-HH-MM-SS.html` (timestamped)
- Previous reports are preserved for historical comparison
- Reports are self-contained (no external dependencies)

#### Docker-Based Report Hosting

- After report generation, launches a Docker container using a common web server image (e.g., `nginx:alpine`)
- Container mounts the `./suitey-reports/` directory and serves it via HTTP
- Server runs on localhost only (127.0.0.1) for security
- Default port is 8080, automatically selects next available port if in use
- Container runs in detached mode and continues until explicitly stopped
- Terminal displays clickable link (if supported) or plain URL for easy access
- Container ID is tracked for cleanup on exit (if user stops suitey)
- Uses minimal resource footprint with alpine-based images

### Parallel Execution Pattern

1. **Initialization**: 
   - Create a temporary directory for storing results and build artifacts using cross-platform temp directory APIs and register cleanup on exit
   - Project Scanner orchestrates Framework Detection, Test Suite Discovery, and Build System Detection (see Technical Considerations above)

2. **Build Phase**:
   - For each framework that requires building:
     - Determine build steps using framework adapter
     - Launch build containers in parallel (when builds are independent)
     - Track build progress and collect build artifacts
     - Store build artifacts in shared volumes for test containers
   - Wait for all required builds to complete before proceeding
   - Report build failures immediately and abort test execution

3. **Discovery**: 
   - For each detected framework, use its adapter to discover test suites
   - Collect all discovered suites with their execution metadata
   - Link test suites to their corresponding build artifacts (if any)

4. **Parallel Launch**: 
   - Launch all test suites in parallel, tracking their container IDs
   - Each suite execution:
     - Records start time
     - Mounts build artifacts (if available) into test container
     - Executes using framework adapter's execution method (Docker container, docker-compose, etc.)
     - Captures exit code from container
     - Calculates duration
     - Extracts test counts from output (using adapter's parser)
     - Writes structured results to a suite-specific result file

5. **Result Monitoring**:
   - **Verbose mode**: Stream output directly from temporary output files as builds and tests run
   - **Dashboard mode**: Poll the temporary directory, reading result files as they become available and updating the display until all containers complete
   - Show build status in dashboard when builds are in progress

6. **Completion**: 
   - Generate comprehensive HTML report from collected test results
   - Save report to `./suitey-reports/` directory with timestamp
   - Launch Docker container with nginx (or similar) to serve the report
   - Container mounts report directory and serves on available port (default: 8080)
   - Display final summary in terminal including:
     - Overall test results
     - Link to view detailed report (e.g., `View report: http://localhost:8080/report/2024-01-15-14-30-45`)
     - Instructions to stop the report server (Ctrl+C or `docker stop <container-id>`)
   - Clean up temporary files and build artifacts (test/build containers are cleaned up, but report container and files persist)
   - Report container continues running until user stops it, allowing report viewing after execution completes

## Future Considerations

- Test suite configuration files (`.suiteyrc`, `suitey.toml`)
- Filtering tests within suites
- Watch mode (re-run on file changes)
- Test coverage reporting
- Custom test runners and adapters
- CI/CD integration modes
- JSON output mode for programmatic consumption
- Framework-specific optimizations and caching