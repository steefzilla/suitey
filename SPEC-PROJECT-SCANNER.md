# Project Scanner Specification

## Overview

The Project Scanner is a core component of Suitey responsible for automatically discovering test suites, detecting test frameworks, and identifying build requirements in any project directory. It operates through a combination of heuristics, file system scanning, and framework-specific detection logic to provide zero-configuration test discovery.

## Responsibilities

The Project Scanner is responsible for:

1. **Test Suite Discovery**: Identifying all test files and test suites in the project
2. **Framework Detection**: Determining which test frameworks are present and available
3. **Build System Detection**: Identifying if and how the project needs to be built before testing
4. **Project Structure Analysis**: Understanding the project's organization and test layout

## Architecture Position

The Project Scanner operates as part of the main suitey process:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner                    │ ← This component
│  Framework Detector                 │
│  Test Suite Discovery               │
│  Build System Detector              │
│  Adapter Registry                   │
│  ...                                │
└─────────────────────────────────────┘
```

## Test Suite Discovery

### Heuristics

The scanner uses multiple heuristics to identify test suites:

#### 1. Package Manager Files

Detects project type through package manager configuration files:
- `package.json` - JavaScript/TypeScript (Node.js)
- `Cargo.toml` - Rust
- `go.mod` - Go
- `pom.xml` - Java (Maven)
- `build.gradle` - Java (Gradle)
- `requirements.txt`, `setup.py`, `pyproject.toml` - Python
- `Gemfile` - Ruby
- And more as needed

#### 2. Test Directory Patterns

Scans for common test directory patterns:
- `./test/`
- `./tests/`
- `./__tests__/`
- `./spec/`
- `./specs/`
- Framework-specific patterns (e.g., `./src/test/` for Java, `./tests/bats/` for BATS)

#### 3. File Naming Patterns

Identifies test files through naming conventions:
- `test_*.*` (e.g., `test_user.py`, `test_utils.js`)
- `*_test.*` (e.g., `user_test.go`, `utils_test.rs`)
- `*_spec.*` (e.g., `user_spec.rb`, `utils_spec.js`)
- `*-test.*` (e.g., `user-test.ts`)
- `*-spec.*` (e.g., `utils-spec.js`)
- `*.bats` - BATS test files (e.g., `suitey.bats`, `utils.bats`)

#### 4. Framework-Specific Configuration Files

Detects framework presence through configuration files:
- `jest.config.js`, `jest.config.ts` - Jest
- `pytest.ini`, `setup.cfg`, `pyproject.toml` - pytest
- `vitest.config.*` - Vitest
- `mocha.opts`, `.mocharc.*` - Mocha
- `tsconfig.json` - TypeScript projects
- `.bats` file extension - BATS (Bash Automated Testing System)
- `bats` binary presence - BATS framework availability
- And more as needed

### Discovery Process

1. **Initial Scan**: Walk the project directory structure
2. **Pattern Matching**: Apply naming and directory pattern heuristics
3. **Framework Detection**: Identify which frameworks are present
4. **Adapter-Based Discovery**: Use framework adapters for framework-specific discovery logic
5. **Suite Identification**: Group test files into distinct test suites (by framework, directory, or file)

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

## Framework Detection

### Detection Strategy

The scanner automatically detects which test frameworks are present through:

1. **Configuration File Presence**: Framework-specific config files indicate framework usage
2. **Package Dependencies**: Package manager files list framework dependencies
3. **Directory Structure**: Framework-specific directory layouts
4. **File Extensions**: Framework-specific file extensions (e.g., `.bats` for BATS)
5. **Binary Availability**: Presence of framework executables (e.g., `bats` command for BATS)
6. **Adapter Registry**: Each framework adapter implements detection logic

### Adapter-Based Detection

Each framework adapter implements:
- **Detection Logic**: How to determine if this framework is present
- **Discovery Logic**: How to find test files/suites for this framework
- **Build Detection**: Whether this project requires building before testing
- **Build Steps**: How to build the project (if needed)
- **Execution Method**: How to run tests using the framework's tools

### Graceful Degradation

- If a framework's tools aren't available, the scanner skips that framework
- Continues detection with other available frameworks
- Provides clear error messages indicating which frameworks were detected and which were skipped

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

The Project Scanner works in conjunction with the Framework Adapter System:

1. **Initial Detection**: Scanner identifies potential frameworks through heuristics
2. **Adapter Registration**: Detected frameworks are registered with the adapter registry
3. **Adapter-Specific Discovery**: Each adapter performs framework-specific discovery
4. **Result Aggregation**: Scanner aggregates results from all adapters into unified test suite list

## Output

The Project Scanner produces:

1. **Detected Frameworks**: List of frameworks found in the project
2. **Test Suites**: Collection of discovered test suites with metadata:
   - Suite name/identifier
   - Framework type
   - Test files included
   - Build requirements (if any)
   - Execution metadata
3. **Build Requirements**: List of build steps needed before testing
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

