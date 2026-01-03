# Suitey Build System

This document describes the build system for Suitey, which compiles modular source files into a single `suitey.sh` script.

## Structure

The source code is organized into the following modules in the `src/` directory:

- **`common.sh`** - Common helper functions, colors, and state variables
- **`adapter_registry.sh`** - Adapter registry system for managing framework adapters
- **`framework_detector.sh`** - Framework detection core and JSON parsing utilities
- **`adapters/bats.sh`** - BATS framework adapter and detection functions
- **`adapters/rust.sh`** - Rust framework adapter and detection functions
- **`scanner.sh`** - Main scanner orchestration functions
- **`main.sh`** - Main entry point and help text

## Building

To compile all modules into `suitey.sh`, run:

```bash
./build.sh
```

The build script:
1. Creates a new `suitey.sh` with the shebang and set options
2. Concatenates all source modules in dependency order
3. Makes the output file executable

## Module Dependencies

The modules are included in this order to satisfy dependencies:

1. `common.sh` - No dependencies
2. `adapter_registry.sh` - Depends on common.sh
3. `framework_detector.sh` - Depends on adapter_registry.sh and common.sh
4. `adapters/bats.sh` - Depends on framework_detector.sh, adapter_registry.sh, and common.sh
5. `adapters/rust.sh` - Depends on framework_detector.sh, adapter_registry.sh, and common.sh
6. `scanner.sh` - Depends on all previous modules
7. `main.sh` - Depends on scanner.sh and all previous modules

## Development Workflow

1. Edit source files in `src/` directory
2. Run `./build.sh` to compile
3. Test the compiled `suitey.sh` script
4. Commit both source files and compiled output (if desired)

## Notes

- The compiled `suitey.sh` includes source file markers in comments for easier debugging
- All functions are preserved in the compiled output
- The build process maintains the exact functionality of the original monolithic script

