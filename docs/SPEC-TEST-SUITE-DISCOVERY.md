# Test Suite Discovery Specification

## Overview

Test Suite Discovery is a core component of Suitey responsible for automatically finding test files and grouping them into distinct test suites after test frameworks have been identified. It is orchestrated by Project Scanner as the **second phase** of the execution workflow, operating **after** Framework Detector has identified which test frameworks are present in the project. Test Suite Discovery uses framework adapters to find test files using framework-specific patterns and heuristics, enabling zero-configuration test discovery across multiple languages and frameworks.

## Responsibilities

Test Suite Discovery is responsible for:

1. **Test File Discovery**: Finding test files for each detected framework using framework-specific patterns
2. **Suite Identification**: Grouping test files into distinct test suites (by framework, directory, or file)
3. **Test Counting**: Counting individual tests within each test file/suite
4. **Metadata Collection**: Gathering metadata about discovered test suites (file paths, test counts, framework type, etc.)
5. **Result Aggregation**: Returning discovered test suites with metadata to Project Scanner

## Architecture Position

Test Suite Discovery operates as part of the main suitey process:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner (Orchestrator)     │
│  ├─ Framework Detector             │
│  │  └─ Adapter Registry            │
│  ├─ Test Suite Discovery           │ ← This component
│  └─ Build System Detector           │
│  ...                                │
└─────────────────────────────────────┘
```

### Relationship to Other Components

- **Project Scanner**: Project Scanner orchestrates Test Suite Discovery as part of the scanning workflow. Test Suite Discovery operates **after** Framework Detection completes and **before** Build System Detection.

- **Framework Detector**: Test Suite Discovery uses the results from Framework Detector to determine which framework adapters to use for finding test files. Framework detection results inform which adapters are available and should be used for discovery.

- **Adapter Registry**: Test Suite Discovery uses framework adapters (via Adapter Registry) to find test files. Each adapter implements framework-specific discovery logic that Test Suite Discovery coordinates.

- **Build System Detector**: Test Suite Discovery results may inform build system detection, as some test suites may require specific build artifacts before execution.

## Discovery Process

The discovery process follows this sequential workflow:

1. **Framework Detection Phase** (prerequisite, performed by Framework Detector):
   - Project Scanner calls Framework Detector to identify which test frameworks are present
   - Framework Detector uses the Adapter Registry to detect frameworks
   - Returns list of detected frameworks with metadata

2. **Test Suite Discovery Phase** (orchestrated by Project Scanner):
   - For **each** detected framework, Project Scanner uses the framework's adapter to discover test files
   - Each adapter implements framework-specific discovery logic using:
     - Test directory patterns (`./test/`, `./tests/`, `./__tests__/`, `./spec/`, etc.)
     - File naming patterns: `test_*.*`, `*_test.*`, `*_spec.*`, `*-test.*`, `*-spec.*`
     - Framework-specific patterns (e.g., `#[cfg(test)]` for Rust, `@test` for BATS)
   - Test files are grouped into distinct test suites (by framework, directory, or file)
   - Test counts are calculated for each suite
   - Suite metadata is collected and returned to Project Scanner

### Critical Requirement: All Frameworks

Test Suite Discovery **must** discover test suites for **all** detected frameworks, not just the first one. This ensures that multi-framework projects have all their test suites discovered and available for execution.

## Discovery Heuristics

Test Suite Discovery uses multiple heuristics to identify test files, implemented through framework adapters:

### 1. Test Directory Patterns

Scans for common test directory patterns:
- `./test/`
- `./tests/`
- `./__tests__/`
- `./spec/`
- `./specs/`
- Framework-specific patterns (e.g., `./src/test/` for Java, `./tests/bats/` for BATS)

### 2. File Naming Patterns

Identifies test files through naming conventions:
- `test_*.*` (e.g., `test_user.py`, `test_utils.js`)
- `*_test.*` (e.g., `user_test.go`, `utils_test.rs`)
- `*_spec.*` (e.g., `user_spec.rb`, `utils_spec.js`)
- `*-test.*` (e.g., `user-test.ts`)
- `*-spec.*` (e.g., `utils-spec.js`)
- `*.bats` - BATS test files (e.g., `suitey.bats`, `utils.bats`)

### 3. Framework-Specific Patterns

Each framework adapter implements framework-specific discovery patterns:

- **BATS**: Discovers `.bats` files in common test directories (`./tests/bats/`, `./test/bats/`, etc.)
- **Rust**: Discovers unit tests in `src/` (files with `#[cfg(test)]` modules) and integration tests in `tests/` directory
- **JavaScript/TypeScript**: Discovers test files using framework-specific patterns (Jest, Mocha, Vitest, etc.)
- **Python**: Discovers test files using pytest/unittest patterns
- **Go**: Discovers test files using `*_test.go` naming convention
- **Java**: Discovers test files in `src/test/` directory structure
- **Ruby**: Discovers test files using RSpec/Minitest patterns
- And more as needed

## Framework-Specific Discovery Details

### BATS Discovery

BATS (Bash Automated Testing System) test files are discovered through:

1. **File Extension**: All `.bats` files in the project
2. **Directory Patterns**: Common BATS test directory structures:
   - `./tests/bats/` - Common pattern for BATS test organization
   - `./test/bats/` - Alternative directory structure
   - `./tests/` - May contain `.bats` files directly
3. **Test Annotation**: Files containing `@test` annotations
4. **Shebang Patterns**: Files with `#!/usr/bin/env bats` or `#!/usr/bin/bats` shebang

**Test Counting**: Counts `@test` annotations in each `.bats` file

**Suite Grouping**: Each `.bats` file typically becomes a separate test suite

### Rust Discovery

Rust test files are discovered through:

1. **Unit Tests**: `.rs` files in `src/` directory containing `#[cfg(test)]` modules
2. **Integration Tests**: `.rs` files in `tests/` directory
3. **Test Annotation**: Functions annotated with `#[test]`

**Test Counting**: Counts `#[test]` annotations in each `.rs` file

**Suite Grouping**: Each `.rs` file with tests becomes a separate test suite

### JavaScript/TypeScript Discovery

JavaScript/TypeScript test files are discovered through framework-specific patterns:

1. **Jest**: Files in `__tests__/` directories or files matching `*.test.js`, `*.test.ts`, `*.spec.js`, `*.spec.ts`
2. **Mocha**: Files matching `test/*.js`, `test/**/*.js` patterns
3. **Vitest**: Files matching configured test patterns (typically `*.test.ts`, `*.spec.ts`)
4. **Jasmine**: Files matching `*.spec.js` patterns

**Test Counting**: Framework-specific (e.g., Jest uses `test()` or `it()` calls, Mocha uses `describe()`/`it()`)

**Suite Grouping**: Framework-specific (may group by directory or file)

### Python Discovery

Python test files are discovered through:

1. **pytest**: Files matching `test_*.py`, `*_test.py` patterns
2. **unittest**: Files matching `test_*.py` patterns in test directories
3. **nose2**: Files matching test patterns in configured directories

**Test Counting**: Counts test methods (functions starting with `test_` or classes inheriting from `unittest.TestCase`)

**Suite Grouping**: Typically by file or test class

## Suite Identification and Grouping

Test files are grouped into distinct test suites using one of these strategies:

1. **By File**: Each test file becomes a separate test suite (common for BATS, Rust integration tests)
2. **By Directory**: All test files in a directory become one suite (common for some JavaScript frameworks)
3. **By Framework**: All test files for a framework become one suite (less common, typically used for simple projects)

The grouping strategy is determined by the framework adapter based on framework conventions and project structure.

## Test Counting

Each framework adapter implements test counting logic specific to its framework:

- **BATS**: Counts `@test` annotations
- **Rust**: Counts `#[test]` function annotations
- **JavaScript/TypeScript**: Counts test functions (framework-specific: `test()`, `it()`, `describe()` blocks)
- **Python**: Counts test methods or test functions
- **Go**: Counts `Test*` functions
- **Java**: Counts `@Test` annotated methods
- **Ruby**: Counts test methods or `it` blocks

Test counts are included in suite metadata and used for reporting and progress tracking.

## Integration with Adapter System

Test Suite Discovery works in conjunction with the Framework Adapter System:

1. **Adapter Access**: Uses framework adapters from the Adapter Registry (via Framework Detector results)
2. **Discovery Delegation**: Delegates framework-specific discovery to each adapter
3. **Result Aggregation**: Collects and organizes discovered test suites from all adapters
4. **Metadata Collection**: Gathers suite metadata (file paths, test counts, framework type) from adapters

### Adapter Interface

Each framework adapter implements a discovery interface:

- **`discover()`**: Finds test files/suites for this framework using framework-specific patterns
- **`count_tests()`**: Counts individual tests in a test file
- **`group_suites()`**: Groups test files into test suites (by file, directory, or framework)

## Output

Test Suite Discovery produces:

1. **Discovered Test Suites**: Collection of test suites with metadata:
   - Suite name/identifier (generated from file path or directory)
   - Framework type
   - Test files included
   - Relative file paths
   - Absolute file paths
   - Test counts (number of individual tests in each suite)
   - Execution metadata

2. **Suite Metadata**: Additional information about each discovered suite:
   - Framework adapter used
   - Discovery method (directory pattern, file pattern, etc.)
   - File modification times (for caching)
   - Helper file dependencies (if any)

3. **Discovery Statistics**: Summary information:
   - Total number of suites discovered
   - Number of suites per framework
   - Total number of tests across all suites

## Error Handling

Test Suite Discovery handles:

- **No Test Files Found**: Projects with detected frameworks but no discoverable test files
- **Invalid Test Files**: Malformed or corrupted test files
- **Permission Errors**: Files or directories that cannot be read
- **Missing Helper Files**: Test files that depend on helper files that are missing
- **Framework-Specific Errors**: Errors encountered during framework-specific discovery

All errors are reported with clear, actionable messages indicating:
- Which frameworks had test suites discovered
- Which frameworks had no test suites found
- What test files were found and their locations
- What errors occurred during discovery

## Performance Considerations

- **Efficient Scanning**: Uses optimized directory traversal to minimize file system operations
- **Parallel Discovery**: Framework-specific discovery can occur in parallel where adapters are independent
- **Early Termination**: Stops scanning subdirectories when framework-specific patterns are identified
- **Caching Opportunities**: Discovery results can be cached for repeated scans (based on file modification times)
- **Minimal I/O**: Reduces file system operations through smart directory traversal and pattern matching

## Implementation Notes

### Discovery Order

1. **Framework-Based Discovery**: For each detected framework, use its adapter to discover test files
2. **Pattern Matching**: Apply framework-specific patterns (directory structures, file naming conventions)
3. **Test Counting**: Count individual tests in each discovered file
4. **Suite Grouping**: Group test files into distinct test suites
5. **Result Aggregation**: Collect all discovered suites with metadata

### Cross-Platform Considerations

- Use cross-platform file system APIs
- Handle different path separators (`/` vs `\`)
- Respect case-sensitive vs case-insensitive file systems
- Handle symbolic links appropriately
- Account for platform-specific file naming conventions

### Extensibility

Test Suite Discovery is designed to be extensible:

- New framework adapters can be added without modifying core discovery logic
- New discovery patterns can be added for additional project types
- Custom discovery patterns can be registered
- Framework-specific discovery logic is isolated in adapters

## Framework-Agnostic Approach

Test Suite Discovery works across multiple languages and frameworks:

- JavaScript/TypeScript (Jest, Mocha, Vitest, Jasmine, etc.)
- Python (pytest, unittest, nose2)
- Go (go test)
- Rust (cargo test)
- Java (JUnit via Maven/Gradle)
- Ruby (RSpec, Minitest)
- Bash/Shell (BATS - Bash Automated Testing System)
- And more as needed

Each framework adapter implements framework-specific discovery logic, enabling Suitey to work with any test framework without hardcoding framework-specific patterns in the core discovery component.

## BATS-Specific Considerations

### BATS Test File Structure

BATS test files typically:
- Have `.bats` extension
- Start with `#!/usr/bin/env bats` shebang
- Contain `@test` annotations for test cases
- May include helper files in `helpers/` subdirectories

### BATS Discovery Requirements

The BATS adapter should:
- Discover all `.bats` files in test directories
- Handle helper file dependencies (may need to be available in test execution context)
- Count `@test` annotations in each file
- Support discovery of files in nested directory structures
- Handle cases where `bats` binary is not available (discovery can still occur, execution may be skipped)

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

The discovery should recognize these patterns and group BATS files appropriately, typically treating each `.bats` file as a separate test suite.

## Rust-Specific Considerations

### Rust Test File Structure

Rust test files typically:
- Unit tests: `.rs` files in `src/` containing `#[cfg(test)]` modules with `#[test]` functions
- Integration tests: `.rs` files in `tests/` directory with `#[test]` functions

### Rust Discovery Requirements

The Rust adapter should:
- Discover unit tests in `src/` directory (files with `#[cfg(test)]` modules)
- Discover integration tests in `tests/` directory
- Count `#[test]` annotations in each file
- Handle both unit and integration test discovery
- Support discovery of tests in nested module structures

### Rust Project Patterns

Common Rust project structures:
```
project/
├── Cargo.toml
├── src/
│   └── lib.rs          (contains #[cfg(test)] mod tests { ... })
└── tests/
    └── integration_test.rs
```

The discovery should recognize these patterns and group Rust test files appropriately, typically treating each `.rs` file with tests as a separate test suite.

