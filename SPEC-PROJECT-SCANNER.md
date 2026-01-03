# Project Scanner Specification

## Overview

The Project Scanner is the primary orchestrator component of Suitey responsible for coordinating project analysis, test suite discovery, and build requirement identification. It orchestrates the workflow: **Framework Detection** → **Test Suite Discovery** → **Build System Detection**. It operates through a combination of heuristics, file system scanning, and coordination with specialized components (Framework Detector, Test Suite Discovery, Build System Detector) to provide zero-configuration test discovery.

## Responsibilities

The Project Scanner is responsible for:

1. **Orchestration**: Coordinating the overall project analysis workflow
2. **Framework Detection Coordination**: Calling Framework Detector to identify which test frameworks are present
3. **Test Suite Discovery**: Orchestrating Test Suite Discovery to find and group test files after frameworks are detected
4. **Build System Detection**: Identifying if and how the project needs to be built before testing
5. **Result Aggregation**: Aggregating results from all sub-components into a unified output

## Architecture Position

The Project Scanner operates as part of the main suitey process:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner (Orchestrator)     │ ← This component
│  ├─ Framework Detector             │
│  │  └─ Adapter Registry            │
│  ├─ Test Suite Discovery           │
│  └─ Build System Detector           │
│  ...                                │
└─────────────────────────────────────┘
```

## Test Suite Discovery

Test Suite Discovery is orchestrated by Project Scanner and operates **after** Framework Detector has identified which test frameworks are present in the project. It uses framework adapters to find test files using framework-specific patterns.

### Discovery Process

The discovery process follows this workflow:

1. **Framework Detection Phase** (performed by Framework Detector):
   - Project Scanner calls Framework Detector to identify which test frameworks are present
   - Framework Detector uses the Adapter Registry to detect frameworks
   - Returns list of detected frameworks with metadata

2. **Test Suite Discovery Phase** (orchestrated by Project Scanner):
   - For each detected framework, Project Scanner uses the framework's adapter to discover test files
   - Each adapter implements framework-specific discovery logic using:
     - Test directory patterns (`./test/`, `./tests/`, `./__tests__/`, `./spec/`, etc.)
     - File naming patterns: `test_*.*`, `*_test.*`, `*_spec.*`, `*-test.*`, `*-spec.*`
     - Framework-specific patterns (e.g., `#[cfg(test)]` for Rust, `@test` for BATS)
   - Test files are grouped into distinct test suites (by framework, directory, or file)

### Framework-Specific Discovery

Each framework adapter implements discovery logic specific to its framework:

- **BATS**: Discovers `.bats` files in common test directories (`./tests/bats/`, `./test/bats/`, etc.)
- **Rust**: Discovers unit tests in `src/` (files with `#[cfg(test)]`) and integration tests in `tests/`
- **JavaScript/TypeScript**: Discovers test files using framework-specific patterns (Jest, Mocha, Vitest, etc.)
- **Python**: Discovers test files using pytest/unittest patterns
- And more as needed

### Framework-Agnostic Approach

The scanner works across multiple languages and frameworks:
- JavaScript/TypeScript (Jest, Mocha, Vitest, Jasmine, etc.)
- Python (pytest, unittest, nose2)
- Go (go test)
- Rust (cargo test)
- Java (JUnit via Maven/Gradle)
- Ruby (RSpec, Minitest)
- Bash/Shell (BATS - Bash Automated Testing System)
- And more as needed

## Framework Detection Coordination

Project Scanner orchestrates Framework Detection by calling the Framework Detector component. Framework Detection happens **before** Test Suite Discovery, as the discovered frameworks inform which adapters to use for test file discovery.

### Workflow

1. **Project Scanner calls Framework Detector**: Framework Detector uses the Adapter Registry to identify which test frameworks are present in the project
2. **Framework Detector returns results**: Returns list of detected frameworks with metadata (confidence levels, binary availability, etc.)
3. **Project Scanner uses results**: The detected frameworks inform:
   - Which adapters to use for Test Suite Discovery
   - Which adapters to use for Build System Detection
   - Framework-specific metadata needed for execution

For detailed information about Framework Detection, see the Framework Detector Specification.

## Build System Detection

### Detection Heuristics

The scanner detects build requirements through:

#### 1. Build Configuration Files
- `Makefile` - Make-based builds
- `CMakeLists.txt` - CMake builds
- `Dockerfile` - Docker-based builds
- `docker-compose.yml` - Multi-container builds
- `build.sh`, `build.bat` - Custom build scripts

#### 2. Package Manager Build Scripts
- `package.json` scripts (e.g., `"build": "tsc"`)
- `Cargo.toml` build configuration
- `go.mod` (Go builds are often implicit in `go test`)
- `pom.xml` Maven build configuration
- `build.gradle` Gradle build configuration

#### 3. Source Code Patterns
- TypeScript files (`.ts`) indicating compilation needs
- Compiled languages requiring build steps
- Transpiled languages (CoffeeScript, Babel, etc.)

### Build Detection Process

1. **Scan for Build Indicators**: Check for build configuration files and patterns
2. **Framework Adapter Analysis**: Each adapter determines if building is required
3. **Build Step Identification**: Determine specific build commands needed
4. **Dependency Analysis**: Identify build dependencies and requirements

### Build Requirements by Framework

- **TypeScript/JavaScript**: `npm run build`, `yarn build`, `tsc`, etc.
- **Go**: `go build` (often implicit in `go test`)
- **Rust**: `cargo build` (often implicit in `cargo test`)
- **Java**: `mvn compile`, `gradle build`
- **C/C++**: `make`, `cmake`, custom build scripts
- **BATS**: Typically no build required (bash scripts are interpreted), but may need `bats` binary installation
- And more as needed

## Integration with Adapter System

The Project Scanner works in conjunction with the Framework Adapter System through the following workflow:

1. **Framework Detection**: Project Scanner calls Framework Detector, which uses the Adapter Registry to identify which frameworks are present
2. **Test Suite Discovery**: For each detected framework, Project Scanner uses the framework's adapter to discover test files using framework-specific patterns
3. **Build System Detection**: Project Scanner uses framework adapters to determine build requirements per framework
4. **Result Aggregation**: Project Scanner aggregates results from all phases (framework detection, test suite discovery, build detection) into a unified output

The Adapter Registry provides a consistent interface for all framework-specific operations (detection, discovery, build detection, execution, and parsing).

## Output

The Project Scanner produces aggregated results from all orchestrated components:

1. **Detected Frameworks** (from Framework Detector):
   - List of frameworks found in the project
   - Framework metadata (confidence levels, binary availability, etc.)

2. **Test Suites** (from Test Suite Discovery):
   - Collection of discovered test suites with metadata:
     - Suite name/identifier
     - Framework type
     - Test files included
     - Test counts
     - Execution metadata

3. **Build Requirements** (from Build System Detector):
   - List of build steps needed before testing
   - Build commands per framework
   - Build dependencies

4. **Project Structure**: Understanding of project organization

## Error Handling

The scanner handles:

- **No Test Directories**: Projects without test directories
- **No Test Suites Found**: Projects with no discoverable tests
- **Missing Framework Tools**: Frameworks detected but tools not available (e.g., `bats` command not found)
- **Invalid Project Structure**: Malformed or unusual project layouts
- **Conflicting Frameworks**: Multiple frameworks detected in same project
- **Missing Dependencies**: Framework-specific dependencies not available (e.g., BATS binary not installed)

All errors are reported with clear, actionable messages indicating:
- Which frameworks were detected
- Which test suites were found
- Which frameworks were skipped and why
- What build steps are required
- What dependencies need to be installed (e.g., `bats` for BATS projects)

## Performance Considerations

- **Efficient Scanning**: Uses optimized directory traversal
- **Parallel Detection**: Framework detection can occur in parallel where possible
- **Caching Opportunities**: Results can be cached for repeated scans
- **Minimal I/O**: Reduces file system operations where possible

## Implementation Notes

### Scanning Strategy

1. **Top-Down Approach**: Start from project root and scan recursively
2. **Early Termination**: Stop scanning subdirectories when framework is identified
3. **Pattern Matching**: Use efficient pattern matching for file names
4. **Configuration Parsing**: Parse configuration files to extract test locations

### Cross-Platform Considerations

- Use cross-platform file system APIs
- Handle different path separators (`/` vs `\`)
- Respect case-sensitive vs case-insensitive file systems
- Handle symbolic links appropriately

### Extensibility

The scanner is designed to be extensible:
- New framework adapters can be added without modifying core scanner logic
- New heuristics can be added for additional project types
- Custom discovery patterns can be registered
- Framework-specific discovery logic is isolated in adapters

## BATS-Specific Considerations

### BATS Detection

BATS (Bash Automated Testing System) is a testing framework for bash scripts. The scanner detects BATS projects through:

1. **File Extension**: Presence of `.bats` files in the project
2. **Directory Patterns**: Common BATS test directory structures:
   - `./tests/bats/` - Common pattern for BATS test organization
   - `./test/bats/` - Alternative directory structure
   - `./tests/` - May contain `.bats` files directly
3. **Binary Detection**: Checks for `bats` command availability in the system
4. **Shebang Patterns**: Files with `#!/usr/bin/env bats` or `#!/usr/bin/bats` shebang

### BATS Test File Structure

BATS test files typically:
- Have `.bats` extension
- Start with `#!/usr/bin/env bats` shebang
- Contain `@test` annotations for test cases
- May include helper files in `helpers/` subdirectories

### BATS Execution Requirements

- **No Build Step**: BATS tests are bash scripts and typically don't require compilation
- **Binary Dependency**: Requires `bats` binary to be installed (can be installed via package managers or from source)
- **Helper Support**: BATS projects may use helper files in `tests/bats/helpers/` or similar directories
- **Test Discovery**: All `.bats` files in detected test directories are considered test suites

### BATS Adapter Considerations

The BATS adapter should:
- Detect `.bats` files and `bats` binary availability
- Discover all `.bats` files in test directories
- Handle helper file dependencies (may need to be available in test execution context)
- Execute tests using `bats <test-file>` or `bats <test-directory>`
- Parse BATS output to extract test results (pass/fail counts, test names)
- Support parallel execution of multiple BATS test files
- Handle cases where `bats` binary is not available (skip with clear error message)

### BATS Project Patterns

Common BATS project structures:
```
project/
├── tests/
│   └── bats/
│       ├── helpers/
│       │   └── helper.bash
│       ├── suitey.bats
│       └── utils.bats
└── suitey.sh
```

The scanner should recognize these patterns and group BATS files appropriately, potentially treating each `.bats` file as a separate test suite or grouping them by directory.

