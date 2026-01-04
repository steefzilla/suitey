# ============================================================================
# Help Text
# ============================================================================

# Source JSON helper functions
if [[ -f "json_helpers.sh" ]]; then
  source "json_helpers.sh"
elif [[ -f "src/json_helpers.sh" ]]; then
  source "src/json_helpers.sh"
elif [[ -f "../src/json_helpers.sh" ]]; then
  source "../src/json_helpers.sh"
fi

show_help() {
  cat << 'EOF'
Suitey Project Scanner

Scans PROJECT_ROOT to detect test frameworks (BATS, Rust) and discover
test suites. Outputs structured information about detected frameworks and
discovered test suites.

USAGE:
    suitey.sh [OPTIONS] PROJECT_ROOT

OPTIONS:
    -h, --help      Show this help message and exit.
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
  # Check for subcommands

  # Check for test suite discovery subcommand
  if [[ $# -gt 0 ]] && [[ "$1" == "test-suite-discovery-registry" ]]; then
    shift
    # Process PROJECT_ROOT argument
    local project_root_arg=""
    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          show_help
          exit 0
          ;;
        -*)
          # Unknown option
          echo "Error: Unknown option: $arg" >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
          ;;
        *)
          # First non-flag argument is PROJECT_ROOT
          if [[ -z "$project_root_arg" ]]; then
            project_root_arg="$arg"
          else
            echo "Error: Multiple project root arguments specified." >&2
            echo "Run 'suitey.sh --help' for usage information." >&2
            exit 2
          fi
          ;;
      esac
    done

    # If no PROJECT_ROOT argument provided, use current directory
    if [[ -z "$project_root_arg" ]]; then
      project_root_arg="."
    fi

    # Call test suite discovery function
    test_suite_discovery_with_registry "$project_root_arg"
    exit 0
  fi

  # Check for help flags
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        show_help
        exit 0
        ;;
    esac
  done

  # Process PROJECT_ROOT argument (first non-flag argument)
  local project_root_arg=""
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        # Already handled above
        ;;
      -*)
        # Unknown option
        echo "Error: Unknown option: $arg" >&2
        echo "Run 'suitey.sh --help' for usage information." >&2
        exit 2
        ;;
      *)
        # First non-flag argument is PROJECT_ROOT
        if [[ -z "$project_root_arg" ]]; then
          project_root_arg="$arg"
        else
          echo "Error: Multiple project root arguments specified." >&2
          echo "Run 'suitey.sh --help' for usage information." >&2
          exit 2
        fi
        ;;
    esac
  done

  # If no PROJECT_ROOT argument provided, show help
  if [[ -z "$project_root_arg" ]]; then
    show_help
    exit 0
  fi

  # Set PROJECT_ROOT
  PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"

  scan_project
  output_results
}

# Run main function only if this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

