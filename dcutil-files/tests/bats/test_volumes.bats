#!/usr/bin/env bats

load test_helper
load load_lib

setup() {
    setup_mocks_dir
    setup_test_tmpdir
    export DETECTED_BACKEND=""
    unset DCUTIL_ALLOW_ROOT
    unset CI
    unset GITHUB_ACTIONS
    unset DCUTIL_QUIET
    unset DEVCONTAINER_CONFIG_FILE
    unset PROJECT_DIR
    export HOME="$BATS_TEST_TMPDIR"
    SCRIPT_DIR="$BATS_TEST_TMPDIR"
    export SCRIPT_DIR
    export PATH="$BATS_MOCK_TMPDIR/bin:$PATH"

    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/id" <<'EOF'
#!/usr/bin/env bash
echo "1000"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/id"

    FEATURES_REGISTRY="ghcr.io"
    export FEATURES_REGISTRY
    FEATURES_NAMESPACE="devcontainers/features"
    export FEATURES_NAMESPACE
    FEATURES_DEFAULT_VERSION="1"
    export FEATURES_DEFAULT_VERSION
}

teardown() {
    teardown_test_tmpdir
    teardown_mocks_dir
}

load_volumes_lib() {
    source_lib "volumes"
}

# Tests that need jq - use system jq if available
# Remove mock_jq stub and let tests use system jq

stub_docker_fail() {
    mkdir -p "$BATS_MOCK_TMPDIR/bin"
    cat > "$BATS_MOCK_TMPDIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$BATS_MOCK_TMPDIR/bin/docker"
}

stub_docker_success() {
    mkdir -p "$BATS_MOCK_TMPDIR/bin"
    cat > "$BATS_MOCK_TMPDIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$BATS_MOCK_TMPDIR/bin/docker"
}

# ============================================
# Tests for get_volume_config_file()
# ============================================

@test "get_volume_config_file: uses DEVCONTAINER_CONFIG_FILE when set" {
    load_volumes_lib

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{}' > "$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    result=$(get_volume_config_file)
    [[ "$result" == *".devcontainer/volumes.json" ]]
    [[ "$result" == "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json" ]]
}

@test "get_volume_config_file: strips quotes from DEVCONTAINER_CONFIG_FILE" {
    load_volumes_lib

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{}' > "$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"

    export DEVCONTAINER_CONFIG_FILE="\"$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json\""
    unset PROJECT_DIR

    result=$(get_volume_config_file)
    [[ "$result" == *".devcontainer/volumes.json" ]]
}

@test "get_volume_config_file: uses PROJECT_DIR when DEVCONTAINER_CONFIG_FILE not set" {
    load_volumes_lib

    unset DEVCONTAINER_CONFIG_FILE
    export PROJECT_DIR="$BATS_TEST_TMPDIR/project"

    result=$(get_volume_config_file)
    [[ "$result" == "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json" ]]
}

@test "get_volume_config_file: falls back to relative path when no env vars" {
    load_volumes_lib

    unset DEVCONTAINER_CONFIG_FILE
    unset PROJECT_DIR

    cd "$BATS_TEST_TMPDIR"
    result=$(get_volume_config_file)
    # realpath -m converts relative to absolute
    [[ "$result" == *".devcontainer/volumes.json" ]]
}

@test "get_volume_config_file: handles non-existent paths gracefully" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="/nonexistent/path/devcontainer.json"
    unset PROJECT_DIR

    result=$(get_volume_config_file)
    [[ "$result" == *"/nonexistent/path/volumes.json" ]]
}

# ============================================
# Tests for ensure_volume_config()
# ============================================

@test "ensure_volume_config: creates directory if doesn't exist" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config

    [ -d "$BATS_TEST_TMPDIR/project/.devcontainer" ]
}

@test "ensure_volume_config: creates volumes.json with empty volumes object" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config

    [ -f "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json" ]
    
    run bash -c "cat '$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json' | jq -e '.volumes'"
    [ "$status" -eq 0 ]
}

@test "ensure_volume_config: leaves existing file untouched" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {"myvol": {"host_path": "/tmp/data", "container_path": "/data", "mount_type": "bind"}}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    ensure_volume_config

    run bash -c "jq -r '.volumes.myvol.host_path' '$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json'"
    [ "$status" -eq 0 ]
    [[ "$output" == "/tmp/data" ]]
}

@test "ensure_volume_config: creates lockfile reference (not file itself)" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config

    local volume_file="$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"
    local lockfile="${volume_file}.lock"
    
    [ -f "$volume_file" ]
}

# ============================================
# Tests for open_lock() / close_lock()
# ============================================

@test "open_lock: acquires exclusive lock successfully" {
    load_volumes_lib

    local lockfile="$BATS_TEST_TMPDIR/test.lock"

    fd=$(open_lock "$lockfile" true)
    [ -n "$fd" ]
    [ "$fd" -eq 100 ]

    [ -f "$lockfile" ]
}

@test "open_lock: fails when lockfile cannot be created (read-only dir)" {
    load_volumes_lib

    local readonly_dir="$BATS_TEST_TMPDIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 555 "$readonly_dir"

    local lockfile="$readonly_dir/test.lock"

    # open_lock should fail (return non-zero) when it can't create the lock file
    set +e
    output=$(open_lock "$lockfile" true 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
}

# ============================================
# Tests for add_volume() input validation
# These tests verify that the function validates inputs correctly
# ============================================

@test "add_volume: fails with missing arguments" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    # Test with empty volume_name
    set +e
    output=$(add_volume "" "/path" "/container" "bind" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"required"* ]]
}

@test "add_volume: fails with invalid mount type" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(add_volume "testvol" "/host" "/container" "invalid" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Invalid mount type"* ]]
}

@test "add_volume: accepts valid mount types" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR
    export HOME="$BATS_TEST_TMPDIR"

    for type in "bind" "volume" "tmpfs"; do
        mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
        mkdir -p "$HOME/testdata"
        echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

        set +e
        output=$(add_volume "testvol" "$HOME/testdata" "/container" "$type" 2>&1)
        status=$?
        set -e
        
        # Should fail due to docker/podman, not mount type
        [ $status -ne 0 ]
        [[ "$output" != *"Invalid mount type"* ]]
    done
}

@test "add_volume: rejects duplicate volume name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {"existing": {"host_path": "/tmp/existing", "container_path": "/existing", "mount_type": "bind"}}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(add_volume "existing" "/tmp/new" "/new" "bind" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "add_volume: validates path traversal" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR
    export HOME="$BATS_TEST_TMPDIR"

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(add_volume "testvol" "../../../etc" "/container" "bind" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
}

# ============================================
# Tests for remove_volume() input validation
# ============================================

@test "remove_volume: fails with missing volume_name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(remove_volume "" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "remove_volume: fails when volume doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    # Provide "n" to skip confirmation prompt
    set +e
    output=$(printf "n\n" | remove_volume "nonexistent" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ============================================
# Tests for mount_volume() input validation
# ============================================

@test "mount_volume: fails with missing volume_name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(mount_volume "" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "mount_volume: fails when volume doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(mount_volume "nonexistent" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ============================================
# Tests for unmount_volume() input validation
# ============================================

@test "unmount_volume: fails with missing volume_name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    set +e
    output=$(unmount_volume "" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ============================================
# Tests for backup_volume() input validation
# ============================================

@test "backup_volume: fails with missing volume_name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    # Function should fail when called with empty volume name
    # The function checks [ -z "$volume_name" ] and calls error_exit
    set +e
    output=$(backup_volume 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    # Either shows usage or fails due to empty argument
    [[ "$output" == *"Usage"* ]] || [ $status -ne 0 ]
}

@test "backup_volume: fails when volume doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    # Function should fail when volume doesn't exist
    run backup_volume "nonexistent"
    [ "$status" -ne 0 ]
}

@test "backup_volume: fails when host_path doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {"myvol": {"host_path": "/nonexistent/path", "container_path": "/container", "mount_type": "bind"}}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    run backup_volume "myvol"
    [ "$status" -ne 0 ]
}

# ============================================
# Tests for restore_volume() input validation
# ============================================

@test "restore_volume: fails with missing volume_name" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(printf "n\n" | restore_volume "" "/tmp/backup.tar.gz" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "restore_volume: fails with missing backup_path" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(printf "n\n" | restore_volume "myvol" "" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "restore_volume: fails when volume doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(printf "n\n" | restore_volume "nonexistent" "/tmp/backup.tar.gz" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "restore_volume: fails when backup file doesn't exist" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {"myvol": {"host_path": "'"$BATS_TEST_TMPDIR"'/host/data", "container_path": "/container", "mount_type": "bind"}}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    set +e
    output=$(printf "n\n" | restore_volume "myvol" "/nonexistent/backup.tar.gz" 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ============================================
# Tests for volume_status()
# ============================================

@test "volume_status: runs with no volumes configured" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    # volume_status calls run_in_container which requires docker/podman
    # Since docker is mocked to fail, the function will fail
    # But it should still show some output related to volumes
    set +e
    output=$(volume_status 2>&1 || true)
    status=$?
    set -e
    
    # The function may fail due to docker not running, but should show volume info
    [[ "$output" == *"Volume status"* ]] || [[ "$output" == *"volumes"* ]]
}

# ============================================
# Tests for list_volumes()
# ============================================

@test "list_volumes: shows no volumes when empty" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    echo '{"volumes": {}}' > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json"

    output=$(list_volumes 2>&1 || true)
    [ -n "$output" ]
}

@test "list_volumes: lists configured volumes" {
    load_volumes_lib
    # Tests use system jq - no mocking needed
    stub_docker_fail

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/project/.devcontainer"
    cat > "$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json" <<'EOF'
{
  "volumes": {
    "myvolume": {
      "host_path": "/tmp/data",
      "container_path": "/data",
      "mount_type": "bind",
      "auto_mount": false
    }
  }
}
EOF

    output=$(list_volumes 2>&1 || true)
    [[ "$output" == *"myvolume"* ]]
}

# ============================================
# Additional tests
# ============================================

@test "multiple ensure_volume_config calls are idempotent" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config
    ensure_volume_config
    ensure_volume_config

    run bash -c "jq -e '.' '$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json'"
    [ "$status" -eq 0 ]
}

@test "volume config directory creation works with nested paths" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/subdir/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config

    [ -d "$BATS_TEST_TMPDIR/project/subdir/.devcontainer" ]
    [ -f "$BATS_TEST_TMPDIR/project/subdir/.devcontainer/volumes.json" ]
}

@test "get_volume_config_file: handles special characters in path" {
    load_volumes_lib

    mkdir -p "$BATS_TEST_TMPDIR/project with spaces/.devcontainer"
    echo '{}' > "$BATS_TEST_TMPDIR/project with spaces/.devcontainer/devcontainer.json"

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project with spaces/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    result=$(get_volume_config_file)
    [[ "$result" == *"project with spaces"* ]]
    [[ "$result" == *"volumes.json" ]]
}

@test "get_volume_config_file: handles path with symlinks" {
    load_volumes_lib

    mkdir -p "$BATS_TEST_TMPDIR/real/.devcontainer"
    ln -s "$BATS_TEST_TMPDIR/real" "$BATS_TEST_TMPDIR/link"
    echo '{}' > "$BATS_TEST_TMPDIR/real/.devcontainer/devcontainer.json"

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/link/real/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    result=$(get_volume_config_file)
    [ -n "$result" ]
}

@test "ensure_volume_config: creates valid JSON" {
    load_volumes_lib

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/project/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    ensure_volume_config

    # Verify the JSON is valid and has the expected structure
    run bash -c "cat '$BATS_TEST_TMPDIR/project/.devcontainer/volumes.json' | jq '.'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"volumes"* ]]
}

@test "ensure_volume_config fails when directory cannot be created" {
    load_volumes_lib

    touch "$BATS_TEST_TMPDIR/notadir"

    export DEVCONTAINER_CONFIG_FILE="$BATS_TEST_TMPDIR/notadir/.devcontainer/devcontainer.json"
    unset PROJECT_DIR

    set +e
    output=$(ensure_volume_config 2>&1)
    status=$?
    set -e
    
    [ $status -ne 0 ]
}

@test "lock can be acquired properly" {
    load_volumes_lib

    local lockfile="$BATS_TEST_TMPDIR/concurrent.lock"

    fd1=$(open_lock "$lockfile" true)
    [ -n "$fd1" ]

    [ -f "$lockfile" ]
}

@test "lock file persists after acquisition" {
    load_volumes_lib

    local lockfile="$BATS_TEST_TMPDIR/test_cleanup.lock"

    fd=$(open_lock "$lockfile" true)

    [ -f "$lockfile" ]
}
