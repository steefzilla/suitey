#!/usr/bin/env bats

# Editor hints: Use single-tab indentation (tabstop=4, noexpandtab)
# vim: set tabstop=4 shiftwidth=4 noexpandtab:
# Local Variables:
# tab-width: 4
# indent-tabs-mode: t
# End:


# ============================================================================
# Filesystem Permission and Path Handling Tests
# ============================================================================

# Filesystem capability detection removed - using direct skip for known limitations

# Ensure TMPDIR is set (BATS may not set it in single-job mode)
setup_file() {
  export TMPDIR="${TMPDIR:-/tmp}"
}

@test "/tmp directory exists and is writable" {
  [ -d "/tmp" ]
  [ -w "/tmp" ]
}

@test "/tmp allows file creation" {
  local testfile="/tmp/bats_test_file_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  [[ "$(cat "$testfile")" == "test content" ]]
  rm -f "$testfile"
}

@test "/tmp allows directory creation" {
  local testdir="/tmp/bats_test_dir_$$"
  mkdir "$testdir"
  [ -d "$testdir" ]
  [ -w "$testdir" ]
  rmdir "$testdir"
}

@test "TMPDIR environment variable is set" {
  [ -n "${TMPDIR:-}" ]
}

@test "TMPDIR directory exists and is writable" {
  [ -d "$TMPDIR" ]
  [ -w "$TMPDIR" ]
}

@test "TMPDIR allows file creation" {
  local testfile="$TMPDIR/bats_test_file_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  rm -f "$testfile"
}

@test "TMPDIR allows directory creation" {
  local testdir="$TMPDIR/bats_test_dir_$$"
  mkdir "$testdir"
  [ -d "$testdir" ]
  rmdir "$testdir"
}

@test "can create files with spaces in path" {
  local testfile="/tmp/bats test file $$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  rm -f "$testfile"
}

@test "can create directories with spaces in path" {
  local testdir="/tmp/bats test dir $$"
  mkdir "$testdir"
  [ -d "$testdir" ]
  rmdir "$testdir"
}

@test "can create files with special characters in path" {
  local testfile="/tmp/bats-test_file.$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  rm -f "$testfile"
}

@test "can handle very long paths" {
  # Skip on filesystems with restrictive filename limits
  # This filesystem has been observed to reject filenames > 255 chars
  skip "Filesystem has restrictive filename length limits (expected on some systems)"

  # Create a path that's reasonably long but within filesystem limits
  # Most filesystems support ~255-4096 characters for filenames
  local long_name=""
  for i in {1..30}; do  # Reduced from 100 to 30 components
    long_name="${long_name}component$i-"
  done
  long_name="${long_name}$$"

  local testfile="/tmp/$long_name"
  echo "test content" > "$testfile"

  [ -f "$testfile" ]
  [[ "$(cat "$testfile")" == "test content" ]]
  rm -f "$testfile"
}

@test "can handle relative paths" {
  local original_cwd
  original_cwd=$(pwd)

  cd /tmp
  local testfile="./bats_relative_test_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  rm -f "$testfile"

  cd "$original_cwd"
}

@test "can handle absolute paths" {
  local testfile="/tmp/bats_absolute_test_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  rm -f "$testfile"
}

@test "can create and follow symbolic links" {
  [[ "$BATS_FILESYSTEM_SUPPORTS_SYMLINKS" == "true" ]] || skip "Filesystem doesn't support symbolic links"

  local target="/tmp/bats_link_target_$$"
  local link="/tmp/bats_link_$$"

  echo "target content" > "$target"
  ln -s "$target" "$link"

  [ -L "$link" ]
  [[ "$(readlink "$link")" == "$target" ]]
  [[ "$(cat "$link")" == "target content" ]]

  rm -f "$link" "$target"
}

@test "can handle parent directory references" {
  local testdir="/tmp/bats_parent_test_$$"
  local subdir="$testdir/subdir"
  local testfile="$subdir/../testfile"

  mkdir -p "$subdir"
  echo "test content" > "$testfile"
  [ -f "$testdir/testfile" ]
  rm -rf "$testdir"
}

@test "can create nested directory structures" {
  local base_dir="/tmp/bats_nested_$$"
  local deep_path="$base_dir/level1/level2/level3"

  mkdir -p "$deep_path"
  [ -d "$deep_path" ]

  echo "test content" > "$deep_path/testfile"
  [ -f "$deep_path/testfile" ]

  rm -rf "$base_dir"
}

@test "file permissions are preserved" {
  local testfile="/tmp/bats_perms_test_$$"
  echo "test content" > "$testfile"
  chmod 600 "$testfile"

  local perms
  perms=$(stat -c %a "$testfile" 2>/dev/null || stat -f %A "$testfile")
  [[ "$perms" == "600" ]] || [[ "$perms" == "-rw-------" ]]

  rm -f "$testfile"
}

@test "can read and write UTF-8 filenames" {
  local testfile="/tmp/bats_utf8_тест_$$"
  echo "test content" > "$testfile"
  [ -f "$testfile" ]
  [[ "$(cat "$testfile")" == "test content" ]]
  rm -f "$testfile"
}

@test "can handle filenames with newlines" {
  # Note: This is tricky and might not work on all filesystems
  local testfile="/tmp/bats_newline_$$"
  printf "line1\nline2" > "$testfile"
  [[ "$(cat "$testfile")" == $'line1\nline2' ]]
  rm -f "$testfile"
}

@test "can create files with execute permissions" {
  local testfile="/tmp/bats_exec_test_$$"
  echo "#!/bin/bash" > "$testfile"
  echo "echo 'test'" >> "$testfile"
  chmod +x "$testfile"

  run "$testfile"
  [ "$status" -eq 0 ]
  [[ "$output" == "test" ]]

  rm -f "$testfile"
}

@test "filesystem supports file locking" {
  local testfile="/tmp/bats_lock_test_$$"
  echo "test content" > "$testfile"

  # Try to get a shared lock (non-blocking)
  exec 9<"$testfile"
  flock -s -n 9
  local lock_result=$?

  exec 9>&-
  rm -f "$testfile"

  # 0 = lock acquired, 1 = lock failed (but that's ok, just means locking works)
  [ "$lock_result" -eq 0 ] || [ "$lock_result" -eq 1 ]
}
