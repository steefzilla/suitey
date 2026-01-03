# Framework Detector Specification

## Overview

The Framework Detector is a specialized component of Suitey responsible for automatically identifying which test frameworks are present and available in a project directory. It is called by Project Scanner as the **first phase** of the execution workflow. Framework Detector operates through adapter-based detection logic, where each framework adapter implements framework-specific heuristics. The Framework Detector works in conjunction with the Adapter Registry to coordinate framework-specific detection across multiple testing frameworks. Its results inform subsequent phases: Test Suite Discovery and Build System Detection.

## Responsibilities

The Framework Detector is responsible for:

1. **Framework Identification**: Determining which test frameworks are present in the project
2. **Adapter Coordination**: Working with the Adapter Registry to execute framework-specific detection logic
3. **Binary Availability Checking**: Verifying that required framework tools are available
4. **Detection Result Aggregation**: Collecting and organizing detection results from all adapters
5. **Framework Metadata Collection**: Gathering information about detected frameworks for downstream use

## Architecture Position

The Framework Detector operates as part of the main suitey process:

```
┌─────────────────────────────────────┐
│         suitey (main process)       │
├─────────────────────────────────────┤
│  Project Scanner (Orchestrator)     │
│  ├─ Framework Detector             │ ← This component
│  │  └─ Adapter Registry            │
│  ├─ Test Suite Discovery           │
│  └─ Build System Detector           │
│  ...                                │
└─────────────────────────────────────┘
```

### Relationship to Other Components

- **Project Scanner**: The Project Scanner orchestrates overall project analysis and calls the Framework Detector as the **first step** in the workflow. Framework Detector's results inform subsequent phases (Test Suite Discovery and Build System Detection).
- **Adapter Registry**: The Framework Detector uses the Adapter Registry to access framework-specific detection logic. Each adapter implements detection methods that Framework Detector coordinates.
- **Test Suite Discovery**: Framework detection results are used by Test Suite Discovery to determine which framework adapters to use for finding test files. Test Suite Discovery operates **after** Framework Detection completes.
- **Build System Detector**: Framework detection results may inform build system detection, as some frameworks require specific build steps. Build System Detector operates **after** Framework Detection completes.

## Detection Strategy

The Framework Detector uses a multi-layered approach to identify test frameworks:

### 1. Adapter-Based Detection

The primary detection mechanism uses framework adapters registered in the Adapter Registry. Each adapter implements framework-specific detection logic:

- **Detection Logic**: How to determine if this framework is present
- **Heuristic Application**: Framework-specific heuristics (file patterns, config files, directory structures)
- **Binary Checking**: Verification that required framework tools are available

### 2. Detection Heuristics

Each framework adapter may use multiple heuristics to detect framework presence:

#### Configuration File Presence
- Framework-specific configuration files indicate framework usage
- Examples:
  - `jest.config.js`, `jest.config.ts` - Jest
  - `pytest.ini`, `setup.cfg`, `pyproject.toml` - pytest
  - `vitest.config.*` - Vitest
  - `mocha.opts`, `.mocharc.*` - Mocha
  - `Cargo.toml` - Rust
  - `.bats` file extension - BATS
  - And more as needed

#### Package Manager Files
- Package manager configuration files indicate project type and may list framework dependencies
- Examples:
  - `package.json` - JavaScript/TypeScript (may list Jest, Mocha, Vitest, etc.)
  - `Cargo.toml` - Rust
  - `go.mod` - Go
  - `pom.xml` - Java (Maven)
  - `build.gradle` - Java (Gradle)
  - `requirements.txt`, `setup.py`, `pyproject.toml` - Python
  - `Gemfile` - Ruby
  - And more as needed

#### Directory Structure Patterns
- Framework-specific directory layouts indicate framework usage
- Examples:
  - `./tests/bats/` - BATS
  - `./src/` with `#[cfg(test)]` modules - Rust
  - `./tests/` with `.rs` files - Rust integration tests
  - `./__tests__/` - Jest
  - `./spec/` - RSpec, Jasmine
  - And more as needed

#### File Naming Patterns
- Framework-specific file naming conventions
- Examples:
  - `*.bats` - BATS test files
  - `*_test.rs` - Rust test files
  - `test_*.py` - pytest test files
  - `*.test.js` - Jest test files
  - And more as needed

#### Binary Availability
- Presence of framework executables indicates framework availability
- Examples:
  - `bats` command - BATS framework
  - `cargo` command - Rust framework
  - `npm`, `yarn`, `pnpm` - Node.js frameworks
  - `pytest` command - pytest framework
  - And more as needed

### 3. Detection Process

The Framework Detector follows this process:

1. **Adapter Registration**: Access registered framework adapters from the Adapter Registry
2. **Parallel Detection**: Execute detection logic for all registered adapters (in parallel where possible)
3. **Heuristic Application**: Each adapter applies its framework-specific heuristics
4. **Binary Verification**: Check availability of required framework tools
5. **Result Collection**: Aggregate detection results from all adapters
6. **Metadata Extraction**: Collect framework metadata (name, version, capabilities, etc.)
7. **Error Collection**: Gather warnings and errors (e.g., framework detected but tools unavailable)

## Supported Frameworks

The Framework Detector supports detection of multiple test frameworks across different languages:

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
- Additional frameworks can be added through the adapter system

## Detection Results

The Framework Detector produces:

1. **Detected Frameworks**: List of frameworks found in the project
   - Framework identifier/name
   - Detection confidence level
   - Framework version (if detectable)
   - Detection method used

2. **Framework Metadata**: Additional information about each detected framework
   - Required tools/binaries
   - Configuration file locations
   - Test file patterns
   - Build requirements
   - Execution capabilities

3. **Binary Availability Status**: For each detected framework
   - Required binaries found
   - Required binaries missing
   - Binary versions (if detectable)

4. **Detection Warnings**: Issues encountered during detection
   - Framework detected but tools unavailable
   - Multiple versions of same framework detected
   - Conflicting framework configurations
   - Ambiguous detection results

5. **Detection Errors**: Critical issues preventing framework detection
   - Invalid configuration files
   - Corrupted project structure
   - Unreadable files or directories

## Integration with Adapter System

The Framework Detector works in conjunction with the Framework Adapter System:

1. **Adapter Access**: Retrieves registered adapters from the Adapter Registry
2. **Detection Delegation**: Delegates framework-specific detection to each adapter
3. **Result Aggregation**: Collects and organizes results from all adapters
4. **Metadata Collection**: Gathers framework metadata from adapters
5. **Error Handling**: Processes and reports errors from adapter detection

### Adapter Interface

Each framework adapter implements a detection interface:

- **`detect()`**: Returns whether the framework is present in the project
- **`get_metadata()`**: Returns framework metadata (name, version, capabilities)
- **`check_binaries()`**: Verifies required tools are available
- **`get_heuristics()`**: Returns list of heuristics used for detection

## Binary Availability Checking

The Framework Detector verifies that required framework tools are available:

### Checking Strategy

1. **Binary Detection**: Check for framework executables in PATH
2. **Version Detection**: Attempt to detect framework version (if applicable)
3. **Capability Detection**: Verify framework capabilities (if detectable)
4. **Container Availability**: Check if binaries are available in Docker containers (for containerized execution)

### Error Handling

- **Framework Detected, Binary Missing**: 
  - Framework is still marked as detected
  - Warning is generated indicating binary is unavailable
  - Framework may be skipped during test execution
  - Clear error message indicates what needs to be installed

- **Binary Available, Version Incompatible**:
  - Framework is marked as detected
  - Warning is generated about version incompatibility
  - May affect test execution capabilities

## Detection Confidence Levels

The Framework Detector may assign confidence levels to detection results:

- **High Confidence**: Multiple strong indicators (config file + binary + test files)
- **Medium Confidence**: Some indicators present (config file or test files)
- **Low Confidence**: Weak indicators only (file patterns, directory structure)

Confidence levels help prioritize frameworks and resolve conflicts when multiple frameworks are detected.

## Performance Considerations

- **Parallel Detection**: Framework detection can occur in parallel where adapters are independent
- **Early Termination**: Stop detection early if high-confidence result is found
- **Caching**: Detection results can be cached for repeated scans
- **Efficient Scanning**: Minimize file system operations through smart directory traversal
- **Lazy Evaluation**: Only perform expensive checks (binary detection, version checking) when framework is likely present

## Error Handling

The Framework Detector handles:

- **No Frameworks Detected**: Projects without any detectable test frameworks
- **Missing Framework Tools**: Frameworks detected but required binaries not available
- **Invalid Configuration**: Malformed or corrupted framework configuration files
- **Conflicting Frameworks**: Multiple frameworks detected in same project (may be valid for multi-language projects)
- **Ambiguous Detection**: Unclear which framework is being used
- **Unreadable Files**: Files or directories that cannot be read during detection
- **Permission Errors**: Insufficient permissions to access project files

All errors are reported with clear, actionable messages indicating:
- Which frameworks were detected
- Which frameworks were skipped and why
- What tools need to be installed
- What configuration issues exist

## Implementation Notes

### Detection Order

1. **Fast Heuristics First**: Apply quick checks (file existence, directory patterns) before expensive operations
2. **Binary Checking Last**: Only check binary availability after framework is detected
3. **Parallel Execution**: Run independent adapter detections in parallel
4. **Result Aggregation**: Collect all results before returning

### Cross-Platform Considerations

- Use cross-platform file system APIs
- Handle different path separators (`/` vs `\`)
- Respect case-sensitive vs case-insensitive file systems
- Handle symbolic links appropriately
- Account for platform-specific binary locations

### Extensibility

The Framework Detector is designed to be extensible:

- New framework adapters can be added without modifying core detector logic
- New heuristics can be added for additional project types
- Custom detection patterns can be registered
- Framework-specific detection logic is isolated in adapters

## Framework-Specific Detection Details

### BATS Detection

BATS (Bash Automated Testing System) is detected through:

1. **File Extension**: Presence of `.bats` files in the project
2. **Directory Patterns**: Common BATS test directory structures:
   - `./tests/bats/`
   - `./test/bats/`
   - `./tests/` (may contain `.bats` files)
3. **Binary Detection**: Checks for `bats` command availability
4. **Shebang Patterns**: Files with `#!/usr/bin/env bats` or `#!/usr/bin/bats` shebang

**Binary Requirement**: `bats` binary must be available for test execution (but not required for detection)

### Rust Detection

Rust framework is detected through:

1. **Cargo.toml**: Presence of `Cargo.toml` in project root
2. **Test File Patterns**: 
   - Unit tests: `.rs` files in `src/` containing `#[cfg(test)]` modules
   - Integration tests: `.rs` files in `tests/` directory
3. **Binary Detection**: Checks for `cargo` command availability

**Binary Requirement**: `cargo` binary must be available for test execution (but not required for detection)

### Future Framework Detection

Additional frameworks will be detected through their respective adapters:

- **JavaScript/TypeScript**: Detection via `package.json`, framework config files, and binary availability
- **Python**: Detection via `requirements.txt`, `setup.py`, `pyproject.toml`, and binary availability
- **Go**: Detection via `go.mod` and test file patterns
- **Java**: Detection via `pom.xml`, `build.gradle`, and test directory patterns
- **Ruby**: Detection via `Gemfile` and test file patterns

Each framework adapter implements its own detection logic following the adapter interface.

## Output Format

The Framework Detector provides detection results in a structured format:

- **Framework List**: Array of detected framework identifiers
- **Framework Details**: Object containing metadata for each framework
- **Warnings**: Array of warning messages
- **Errors**: Array of error messages
- **Binary Status**: Object mapping frameworks to binary availability status

This structured output is used by downstream components:
- **Test Suite Discovery**: Uses detected frameworks to determine which adapters to use for finding test files
- **Build System Detector**: Uses detected frameworks to determine build requirements per framework
- **Project Scanner**: Aggregates framework detection results with other component outputs

