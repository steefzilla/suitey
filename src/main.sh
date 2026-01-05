# ============================================================================
# Help Text
# ============================================================================
#
# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# Editor hints: Max line length: 120 characters
# Editor hints: Max function size: 50 lines
# Editor hints: Max functions per file: 20
# Editor hints: Max file length: 1000 lines
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

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

# Helper: Parse arguments
_main_parse_arguments() {
	local project_root_arg=""
	for arg in "$@"; do
		case "$arg" in
		-h|--help)
			show_help
			exit 0
			;;
		-*)
			echo "Error: Unknown option: $arg" >&2
			echo "Run 'suitey.sh --help' for usage information." >&2
			exit 2
			;;
		*)
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
	echo "${project_root_arg:-.}"
}

# Helper: Handle subcommand
_main_handle_subcommand() {
	local subcommand="$1"
	shift
	if [[ "$subcommand" == "test-suite-discovery-registry" ]]; then
		local project_root_arg
		project_root_arg=$(_main_parse_arguments "$@")
		test_suite_discovery_with_registry "$project_root_arg"
		exit 0
	fi
}

# Helper: Handle help flags
_main_handle_help() {
	for arg in "$@"; do
		case "$arg" in
		-h|--help)
			show_help
			exit 0
			;;
		esac
	done
}

main() {
	if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
		_main_handle_subcommand "$@"
	fi

	_main_handle_help "$@"

	local project_root_arg=""
	for arg in "$@"; do
		case "$arg" in
		-h|--help)
			;;
		-*)
			echo "Error: Unknown option: $arg" >&2
			echo "Run 'suitey.sh --help' for usage information." >&2
			exit 2
			;;
		*)
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

	if [[ -z "$project_root_arg" ]]; then
		show_help
		exit 0
	fi

	PROJECT_ROOT="$(cd "$project_root_arg" && pwd)"
	scan_project
	output_results
}

# Run main function only if this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi

