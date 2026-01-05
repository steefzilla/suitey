#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab textwidth=120:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# fill-column: 120
# End:

# Unit tests for Main helper functions

# Find and source suitey.sh to get the helper functions
suitey_script=""
if [[ -f "$BATS_TEST_DIRNAME/../../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../../suitey.sh"
elif [[ -f "$BATS_TEST_DIRNAME/../../suitey.sh" ]]; then
  suitey_script="$BATS_TEST_DIRNAME/../../suitey.sh"
else
  suitey_script="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)/suitey.sh"
fi

source "$suitey_script"

# Mock helper functions for testing
show_help() {
	echo "Help displayed"
	exit 0
}

test_suite_discovery_with_registry() {
	local project_root="$1"
	echo "Discovery run for: $project_root"
	exit 0
}

# ============================================================================
# Helper Function Tests
# ============================================================================

@test "_main_parse_arguments parses help flag" {
	run _main_parse_arguments "--help"

	[ "$status" -eq 0 ]
	[ "$output" = "Help displayed" ]
}

@test "_main_parse_arguments parses unknown option" {
	run _main_parse_arguments "--unknown"

	[ "$status" -eq 2 ]
	[[ "$output" == *"Error: Unknown option: --unknown"* ]]
}

@test "_main_parse_arguments parses project root" {
	local result
	result=$(_main_parse_arguments "/path/to/project")

	[ "$result" = "/path/to/project" ]
}

@test "_main_parse_arguments defaults to current directory when no args" {
	local result
	result=$(_main_parse_arguments)

	[ "$result" = "." ]
}

@test "_main_parse_arguments rejects multiple project roots" {
	run _main_parse_arguments "/path1" "/path2"

	[ "$status" -eq 2 ]
	[[ "$output" == *"Multiple project root arguments specified"* ]]
}

@test "_main_handle_subcommand calls discovery for test-suite-discovery-registry" {
	run _main_handle_subcommand "test-suite-discovery-registry" "/test/project"

	[ "$status" -eq 0 ]
	[ "$output" = "Discovery run for: /test/project" ]
}

@test "_main_handle_help calls show_help for --help" {
	run _main_handle_help "--help"

	[ "$status" -eq 0 ]
	[ "$output" = "Help displayed" ]
}

@test "_main_handle_help does nothing for non-help args" {
	local result
	result=$(_main_handle_help "other" "args")

	[ -z "$result" ]
}
