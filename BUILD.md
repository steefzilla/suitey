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

To create a minified version (removes comments and unnecessary whitespace), use:

```bash
./build.sh --minify
# or
./build.sh -m
```

**Note:** The minified version is output to `suitey.min.sh` (not `suitey.sh`), so you can have both versions available.

The build script:
1. Creates a new output file (`suitey.sh` or `suitey.min.sh`) with the shebang and set options
2. Concatenates all source modules in dependency order
3. (Optional) Minifies the output by removing comments and whitespace
4. Makes the output file executable

### Minification

The `--minify` option performs aggressive optimization while preserving functionality:

**Removed:**
- All comment-only lines (except shebang and `set` commands)
- Inline/trailing comments (where safe to remove)
- All empty lines
- Trailing whitespace
- Trailing semicolons (bash doesn't require them)
- Multiple consecutive spaces (compressed to single space)
- Unnecessary spaces around braces and parentheses: `{ }` → `{}`, `( )` → `()`
- Spaces before semicolons: ` ;` → `;`

**Optimized:**
- Variable assignments: `variable = value` → `variable=value` (where safe)
- Local/declare statements: `local var = value` → `local var=value`
- Whitespace compression (preserves indentation structure)

**Name Mangling:**
- Function names: `adapter_registry_initialize` → `h`
- Variable names: `DETECTED_FRAMEWORKS` → `aB`
- String keys in JSON: `"name"` → `"a"` (where applicable)
- All names mapped to single or double characters
- Mapping file generated: `suitey.min.map` for test compatibility

**Preserved:**
- Heredoc content (completely untouched)
- String literals (including `#` characters within strings)
- Code indentation structure
- Case statement terminators (`;;`)
- Conditional expressions (`[[ ]]`, `[ ]`, comparisons)
- Command flags (e.g., `declare -A` not affected)
- All functional code

**Results:**
- File size reduction: ~39% (53,866 → 32,942 bytes)
- Line reduction: ~36% (1864 → 1197 lines)
- Full functionality maintained
- Syntax validated before output

### Mapping File

The minification process generates `suitey.min.map` which contains:
- Forward mappings: `original_name=minified_name`
- Reverse mappings: `#REVERSE:minified_name=original_name`

This mapping file can be used by the test suite to call minified functions by their original names. See `tests/bats/helpers/minified_mapping.bash` for helper functions to load and use the mappings.

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

