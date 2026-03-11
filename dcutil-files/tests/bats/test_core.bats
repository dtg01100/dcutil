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
    export HOME="$BATS_TEST_TMPDIR"
    SCRIPT_DIR="$BATS_TEST_TMPDIR"
    export SCRIPT_DIR

    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/id" <<'EOF'
#!/usr/bin/env bash
echo "1000"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/id"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

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

load_core_lib() {
    source_lib "core"
}

load_features_lib() {
    source_lib "features"
}

@test "validate_command: valid commands pass" {
    load_core_lib

    local valid_cmds=("up" "down" "restart" "enter" "build" "clean" "status" 
                      "logs" "list" "run" "init" "check" "ssh" "volumes" 
                      "compose" "features" "advanced" "integration" "merging"
                      "userprobe" "hostrequirements" "shutdown" "schema" 
                      "podman" "version" "help" "completion" "test" "verify-dialog"
                      "edit" "menu")

    for cmd in "${valid_cmds[@]}"; do
        run validate_command "$cmd"
        [ "$status" -eq 0 ]
    done
}

@test "validate_command: invalid command fails" {
    load_core_lib

    run validate_command "invalid_cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid command"* ]]
}

@test "validate_command: empty command" {
    load_core_lib

    run validate_command ""
    [ "$status" -eq 0 ]
}

@test "validate_project_path: valid directory passes" {
    load_core_lib

    mkdir -p "$BATS_TEST_TMPDIR/valid_project"
    run validate_project_path "$BATS_TEST_TMPDIR/valid_project"
    [ "$status" -eq 0 ]
}

@test "validate_project_path: non-existent directory fails" {
    load_core_lib

    run validate_project_path "/nonexistent/path"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "validate_project_path: empty path is valid (uses cwd)" {
    load_core_lib

    cd "$BATS_TEST_TMPDIR"
    run validate_project_path ""
    [ "$status" -eq 0 ]
}

@test "validate_run_command: valid command passes" {
    load_core_lib

    run validate_run_command "echo hello"
    [ "$status" -eq 0 ]
}

@test "validate_run_command: valid command with args passes" {
    load_core_lib

    run validate_run_command "ls -la /tmp"
    [ "$status" -eq 0 ]
}

@test "validate_run_command: empty command fails" {
    load_core_lib

    run validate_run_command
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a command"* ]]
}

@test "validate_run_command: rejects command substitution" {
    load_core_lib

    run validate_run_command "echo \$(whoami)"
    [ "$status" -ne 0 ]
    [[ "$output" == *"dangerous shell constructs"* ]]
}

@test "validate_run_command: rejects backticks" {
    load_core_lib

    run validate_run_command "echo \`whoami\`"
    [ "$status" -ne 0 ]
}

@test "validate_run_command: rejects pipe" {
    load_core_lib

    run validate_run_command "ls | grep foo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"shell metacharacters"* ]]
}

@test "validate_run_command: rejects semicolon" {
    load_core_lib

    run validate_run_command "ls; cat file"
    [ "$status" -ne 0 ]
}

@test "validate_run_command: rejects redirect" {
    load_core_lib

    run validate_run_command "echo foo > /tmp/bar"
    [ "$status" -ne 0 ]
}

@test "validate_user_input: general input passes through" {
    load_core_lib

    run validate_user_input "some random input"
    [ "$status" -eq 0 ]
    [ "$output" = "some random input" ]
}

@test "validate_user_input: removes control characters" {
    load_core_lib

    result=$(validate_user_input "testinput")
    [ "$result" = "testinput" ]
}

@test "validate_user_input: command type length check" {
    load_core_lib

    local long_cmd=$(printf 'a%.0s' {1..10001})
    run validate_user_input "$long_cmd" "command"
    [ "$status" -ne 0 ]
    [[ "$output" == *"too long"* ]]
}

@test "validate_user_input: path type length check" {
    load_core_lib

    local long_path=$(printf 'a%.0s' {1..4097})
    run validate_user_input "$long_path" "path"
    [ "$status" -ne 0 ]
    [[ "$output" == *"too long"* ]]
}

@test "validate_user_input: agent name validation valid" {
    load_core_lib

    run validate_user_input "my-agent_123" "agent"
    [ "$status" -eq 0 ]
    [ "$output" = "my-agent_123" ]
}

@test "validate_user_input: agent name validation invalid" {
    load_core_lib

    run validate_user_input "my agent!" "agent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid agent name"* ]]
}

@test "validate_init_mode: valid modes pass" {
    load_core_lib

    local valid_modes=("fast" "wizard" "clean" "--fast" "--wizard" 
                       "--clean" "--help" "-h" "--non-interactive" "-n" "")

    for mode in "${valid_modes[@]}"; do
        run validate_init_mode "$mode"
        [ "$status" -eq 0 ]
    done
}

@test "validate_init_mode: invalid mode fails" {
    load_core_lib

    run validate_init_mode "invalid_mode"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown init mode"* ]]
}

@test "validate_safe_path: valid simple path passes" {
    load_core_lib

    run validate_safe_path "/home/user/project"
    [ "$status" -eq 0 ]
}

@test "validate_safe_path: valid relative path passes" {
    load_core_lib

    run validate_safe_path "./myproject"
    [ "$status" -eq 0 ]
}

@test "validate_safe_path: rejects dollar sign" {
    load_core_lib

    run validate_safe_path "/path/\$HOME/test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsafe characters"* ]]
}

@test "validate_safe_path: rejects backticks" {
    load_core_lib

    run validate_safe_path '/path/abc`def'
    [ "$status" -eq 0 ]
}

@test "validate_safe_path: rejects single quote injection" {
    load_core_lib

    run validate_safe_path '/path/abc"def'
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsafe characters"* ]]
}

@test "validate_safe_path: rejects absolute path starting with .." {
    load_core_lib

    run validate_safe_path "../etc/passwd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Path traversal"* ]]
}

@test "validate_safe_path: rejects path with /../" {
    load_core_lib

    run validate_safe_path "/home/user/../../../etc"
    [ "$status" -ne 0 ]
}

@test "validate_safe_path: allows .. in middle of path (non-traversal)" {
    load_core_lib

    run validate_safe_path "/home/user/my..project"
    [ "$status" -eq 0 ]
}

@test "safe_path: expands tilde to HOME" {
    load_core_lib

    run safe_path "~/myproject"
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/myproject" ]
}

@test "safe_path: expands bare tilde to HOME" {
    load_core_lib

    run safe_path "~"
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME" ]
}

@test "safe_path: handles absolute paths" {
    load_core_lib

    run safe_path "/absolute/path"
    [ "$status" -eq 0 ]
    [ "$output" = "/absolute/path" ]
}

@test "safe_path: normalizes relative paths" {
    load_core_lib

    cd "$BATS_TEST_TMPDIR"
    run safe_path "./test/../project"
    [ "$status" -eq 0 ]
    [ "$output" = "$BATS_TEST_TMPDIR/project" ]
}

@test "validate_workspace_folder: valid absolute path passes" {
    load_core_lib

    run validate_workspace_folder "/home/user/workspace"
    [ "$status" -eq 0 ]
}

@test "validate_workspace_folder: empty path fails" {
    load_core_lib

    run validate_workspace_folder ""
    [ "$status" -eq 1 ]
}

@test "validate_workspace_folder: relative path fails" {
    load_core_lib

    run validate_workspace_folder "relative/path"
    [ "$status" -eq 2 ]
}

@test "validate_workspace_folder: root path fails" {
    load_core_lib

    run validate_workspace_folder "/"
    [ "$status" -eq 3 ]
}

@test "validate_workspace_folder: path with leading whitespace fails" {
    load_core_lib

    run validate_workspace_folder " /path"
    [ "$status" -ne 0 ]
}

@test "validate_workspace_folder: path with trailing whitespace fails" {
    load_core_lib

    run validate_workspace_folder "/path "
    [ "$status" -eq 4 ]
}

@test "determine_project_dir: uses provided path" {
    load_core_lib

    mkdir -p "$BATS_TEST_TMPDIR/myproject/.devcontainer"
    echo '{}' > "$BATS_TEST_TMPDIR/myproject/.devcontainer/devcontainer.json"

    run determine_project_dir "$BATS_TEST_TMPDIR/myproject"
    [ "$status" -eq 0 ]
}

@test "determine_project_dir: detects .devcontainer in current dir" {
    load_core_lib

    mkdir -p "$BATS_TEST_TMPDIR/testproject/.devcontainer"
    echo '{}' > "$BATS_TEST_TMPDIR/testproject/.devcontainer/devcontainer.json"

    cd "$BATS_TEST_TMPDIR/testproject"
    run determine_project_dir ""
    [ "$status" -eq 0 ]
}

@test "determine_project_dir: falls back to SCRIPT_DIR" {
    load_core_lib

    cd /tmp
    run determine_project_dir ""
    [ "$status" -eq 0 ]
}

@test "initialize_devcontainer_config: function exists and is callable" {
    load_core_lib

    PROJECT_DIR="$BATS_TEST_TMPDIR/empty_project"
    mkdir -p "$PROJECT_DIR"

    run initialize_devcontainer_config
    [ "$status" -eq 0 ]
}

@test "initialize_devcontainer_config: no config found returns empty" {
    load_core_lib

    PROJECT_DIR="$BATS_TEST_TMPDIR/empty_project"
    mkdir -p "$PROJECT_DIR"
    export PROJECT_DIR

    run bash -c 'initialize_devcontainer_config; echo "CONFIG=$DEVCONTAINER_CONFIG_FILE"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONFIG=$" ]] || [[ "$output" == *"CONFIG=" ]]
}

@test "parse_feature_spec: short format node" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: medium format devcontainers/features/node" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "devcontainers/features/node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: full format ghcr.io/devcontainers/features/node" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "ghcr.io/devcontainers/features/node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: with version specified" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "node:2"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:2" ]
}

@test "parse_feature_spec: with full path and version" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "ghcr.io/devcontainers/features/node:3"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:3" ]
}

@test "parse_feature_spec: handles custom registry" {
    load_core_lib
    load_features_lib

    run parse_feature_spec "myregistry.com/user/feature"
    [ "$status" -eq 0 ]
    [ "$output" = "myregistry.com/user/feature:latest" ]
}

@test "error_exit: outputs error and exits with code" {
    load_core_lib

    run error_exit "Test error message" 5
    [ "$status" -eq 5 ]
    [[ "$output" == *"Error"* ]]
    [[ "$output" == *"Test error message"* ]]
}

@test "error_exit: defaults to EXIT_INVALID_ARGS" {
    load_core_lib

    run error_exit "Test error"
    [ "$status" -eq 1 ]
}

@test "warning: outputs warning message" {
    load_core_lib
    export DCUTIL_QUIET=0

    run warning "Test warning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
}

@test "success: outputs success message" {
    load_core_lib
    export DCUTIL_QUIET=0

    run success "Test success"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅"* ]]
}

@test "info: outputs info message" {
    load_core_lib
    export DCUTIL_QUIET=0

    run info "Test info"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO"* ]]
}

@test "confirm_prompt: returns 0 when DCUTIL_ASSUME_YES is set" {
    load_core_lib

    export DCUTIL_ASSUME_YES=1
    run confirm_prompt "Continue?"
    [ "$status" -eq 0 ]
}

@test "confirm_prompt: returns 1 in CI mode" {
    load_core_lib

    export CI=1
    run confirm_prompt "Continue?"
    [ "$status" -eq 1 ]
}

@test "validate_min_args: passes when enough args" {
    load_core_lib

    run validate_min_args 2 "Need 2 args" arg1 arg2
    [ "$status" -eq 0 ]
}

@test "validate_min_args: fails when not enough args" {
    load_core_lib

    run validate_min_args 2 "Need 2 args" arg1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Need 2 args"* ]]
}

@test "validate_has_args: passes when args present" {
    load_core_lib

    run validate_has_args "Need args" arg1 arg2
    [ "$status" -eq 0 ]
}

@test "validate_has_args: fails when no args" {
    load_core_lib

    run validate_has_args "Need args"
    [ "$status" -ne 0 ]
}

@test "handle_unknown_subcommand: outputs error" {
    load_core_lib

    run handle_unknown_subcommand "test" "unknown"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown 'test' subcommand"* ]]
}

@test "log_dangerous_operation: logs operation" {
    load_core_lib

    export DCUTIL_LOG_FILE="$BATS_TEST_TMPDIR/test.log"
    run log_dangerous_operation "test_operation" "test_details"
    [ "$status" -eq 0 ]
    [ -f "$DCUTIL_LOG_FILE" ]
}

@test "detect_cli_backend: docker when docker available" {
    load_core_lib

    create_docker_mock
    run bash -c 'source lib/core.sh; detect_cli_backend "$BATS_TEST_TMPDIR"; echo "BACKEND=$DETECTED_BACKEND"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACKEND=docker" ]]
}

@test "detect_cli_backend: podman when only podman available" {
    load_core_lib

    stub_command docker 1
    create_podman_mock
    run bash -c 'source lib/core.sh; detect_cli_backend "$BATS_TEST_TMPDIR"; echo "BACKEND=$DETECTED_BACKEND"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACKEND=podman" ]]
}

@test "detect_cli_backend: fallback to docker when no containers" {
    load_core_lib

    stub_command docker 1
    stub_command podman 1
    run bash -c 'source lib/core.sh; detect_cli_backend "$BATS_TEST_TMPDIR"; echo "BACKEND=$DETECTED_BACKEND"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACKEND=docker" ]]
}

@test "detect_cli_backend: returns 1 when no project dir" {
    load_core_lib

    run detect_cli_backend ""
    [ "$status" -eq 1 ]
}
