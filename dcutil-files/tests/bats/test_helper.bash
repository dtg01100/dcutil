#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-}"
BATS_TEST_FILENAME="${BATS_TEST_FILENAME:-}"
BATS_TEST_NUMBER="${BATS_TEST_NUMBER:-}"
BATS_TEST_DESCRIPTION="${BATS_TEST_DESCRIPTION:-}"

export BATS_MOCK_TMPDIR="${BATS_MOCK_TMPDIR:-/tmp/bats-mocks-$$}"
export BATS_LIB_DIR="${BATS_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"

setup_mocks_dir() {
	mkdir -p "$BATS_MOCK_TMPDIR"
}

teardown_mocks_dir() {
	if [ -d "$BATS_MOCK_TMPDIR" ]; then
		rm -rf "$BATS_MOCK_TMPDIR"
	fi
}

setup_test_tmpdir() {
	export BATS_TEST_TMPDIR
	BATS_TEST_TMPDIR="$(mktemp -d)"
}

teardown_test_tmpdir() {
	if [ -n "${BATS_TEST_TMPDIR:-}" ] && [ -d "$BATS_TEST_TMPDIR" ]; then
		rm -rf "$BATS_TEST_TMPDIR"
	fi
}

setup() {
	setup_mocks_dir
	setup_test_tmpdir
	export DETECTED_BACKEND=""
	unset DCUTIL_ALLOW_ROOT
}

teardown() {
	teardown_test_tmpdir
	teardown_mocks_dir
}

mock_command() {
	local cmd="$1"
	local mock_dir="$BATS_MOCK_TMPDIR/bin"
	mkdir -p "$mock_dir"

	local mock_script="$mock_dir/$cmd"
	shift

	cat >"$mock_script" <<MOCK_EOF
#!/usr/bin/env bash
echo "MOCK $cmd called with args: \$*" >> "$BATS_MOCK_TMPDIR/mock_calls.log"
MOCK_EOF

	if [ $# -gt 0 ]; then
		local behavior="$1"
		case "$behavior" in
		"success")
			cat >>"$mock_script" <<'BEHAVIOR_EOF'
exit 0
BEHAVIOR_EOF
			;;
		"failure")
			cat >>"$mock_script" <<'BEHAVIOR_EOF'
exit 1
BEHAVIOR_EOF
			;;
		"echo")
			cat >>"$mock_script" <<'BEHAVIOR_EOF'
echo "$@"
exit 0
BEHAVIOR_EOF
			;;
		esac
	fi

	chmod +x "$mock_script"
	export PATH="$mock_dir:$PATH"
}

create_docker_mock() {
	mock_command docker "$@"
	cat >>"$BATS_MOCK_TMPDIR/bin/docker" <<'DOCKER_EOF'
case "$1" in
    ps)
        if [[ "$*" == *"--format"* ]]; then
            echo "mock-container"
        else
            echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
            echo "abc123def456   image   /bin/sh   ...       ...      ...     mock-container"
        fi
        ;;
    ps|-a)
        echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
        echo "abc123def456   image   /bin/sh   ...       ...      ...     mock-container"
        ;;
    images)
        echo "REPOSITORY   TAG   IMAGE ID   CREATED   SIZE"
        echo "mock/image   latest   abc123   ...   100MB"
        ;;
    inspect)
        echo '[{"State":{"Running":true}}]'
        ;;
    compose)
        shift
        echo "MOCK docker compose called with args: $*" >> "$BATS_MOCK_TMPDIR/mock_calls.log"
        ;;
    *)
        echo "MOCK docker $@"
        ;;
esac
exit 0
DOCKER_EOF
	chmod +x "$BATS_MOCK_TMPDIR/bin/docker"
}

create_podman_mock() {
	mock_command podman "$@"
	cat >>"$BATS_MOCK_TMPDIR/bin/podman" <<'PODMAN_EOF'
case "$1" in
    ps)
        if [[ "$*" == *"--format"* ]]; then
            echo "mock-container"
        else
            echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
            echo "abc123def456   image   /bin/sh   ...       ...      ...     mock-container"
        fi
        ;;
    ps|-a)
        echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
        echo "abc123def456   image   /bin/sh   ...       ...      ...     mock-container"
        ;;
    images)
        echo "REPOSITORY   TAG   IMAGE ID   CREATED   SIZE"
        echo "mock/image   latest   abc123   ...   100MB"
        ;;
    inspect)
        echo '[{"State":{"Running":true}}]'
        ;;
    compose)
        shift
        echo "MOCK podman compose called with args: $*" >> "$BATS_MOCK_TMPDIR/mock_calls.log"
        ;;
    *)
        echo "MOCK podman $@"
        ;;
esac
exit 0
PODMAN_EOF
	chmod +x "$BATS_MOCK_TMPDIR/bin/podman"
}

create_devcontainer_mock() {
	mock_command devcontainer "$@"
	cat >>"$BATS_MOCK_TMPDIR/bin/devcontainer" <<'DEVCONTAINER_EOF'
case "$1" in
    "exec")
        shift
        echo "MOCK devcontainer exec: $@"
        ;;
    "up")
        echo '{"outcome":"success"}'
        ;;
    "build")
        echo '{"outcome":"success"}'
        ;;
    *)
        echo "MOCK devcontainer $@"
        ;;
esac
exit 0
DEVCONTAINER_EOF
	chmod +x "$BATS_MOCK_TMPDIR/bin/devcontainer"
}

create_jq_mock() {
	mock_command jq "$@"
	cat >>"$BATS_MOCK_TMPDIR/bin/jq" <<'JQ_EOF'
if [ $# -eq 0 ]; then
    echo "Usage: jq [options...] filter [files...]" >&2
    exit 1
fi
filter="$1"
shift
if [ $# -gt 0 ]; then
    input_file="$1"
    if [ -f "$input_file" ]; then
        case "$filter" in
            ".[].*")
                echo '["item1","item2"]'
                ;;
            ".key")
                echo '"value"'
                ;;
            ".[]")
                cat "$input_file"
                ;;
            *)
                cat "$input_file"
                ;;
        esac
    fi
else
    case "$filter" in
        ".[].*")
            echo '["item1","item2"]'
            ;;
        ".key")
            echo '"value"'
            ;;
        *)
            echo '{}'
            ;;
    esac
fi
exit 0
JQ_EOF
	chmod +x "$BATS_MOCK_TMPDIR/bin/jq"
}

create_python3_mock() {
	mock_command python3 "$@"
	cat >>"$BATS_MOCK_TMPDIR/bin/python3" <<'PYTHON3_EOF'
if [[ "$1" == "-c"* ]]; then
    code="${1#-c}"
    python3 -c "$code" "${@:2}" 2>/dev/null || echo "mock python output"
else
    command python3 "$@"
fi
PYTHON3_EOF
	chmod +x "$BATS_MOCK_TMPDIR/bin/python3"
}

create_mocks() {
	create_docker_mock
	create_podman_mock
	create_devcontainer_mock
	create_jq_mock
	create_python3_mock
}

stub_command() {
	local cmd="$1"
	local return_code="${2:-0}"
	local output="${3:-}"

	local mock_dir="$BATS_MOCK_TMPDIR/bin"
	mkdir -p "$mock_dir"

	local mock_script="$mock_dir/$cmd"
	cat >"$mock_script" <<STUB_EOF
#!/usr/bin/env bash
STUB_EOF
	if [ -n "$output" ]; then
		cat >>"$mock_script" <<STUB_EOF
echo "$output"
STUB_EOF
	fi
	cat >>"$mock_script" <<STUB_EOF
exit $return_code
STUB_EOF
	chmod +x "$mock_script"
	export PATH="$mock_dir:$PATH"
}

get_mock_call_count() {
	local cmd="$1"
	if [ -f "$BATS_MOCK_TMPDIR/mock_calls.log" ]; then
		grep -c "MOCK $cmd called" "$BATS_MOCK_TMPDIR/mock_calls.log" 2>/dev/null || echo "0"
	else
		echo "0"
	fi
}

get_mock_calls() {
	local cmd="$1"
	if [ -f "$BATS_MOCK_TMPDIR/mock_calls.log" ]; then
		grep "MOCK $cmd called" "$BATS_MOCK_TMPDIR/mock_calls.log" 2>/dev/null || true
	fi
}

source_lib() {
	local lib_name="$1"
	local lib_path="$BATS_LIB_DIR/${lib_name}.sh"

	if [ ! -f "$lib_path" ]; then
		echo "ERROR: Library file not found: $lib_path" >&2
		return 1
	fi

	source "$lib_path"
}

create_test_config() {
	local config_type="${1:-devcontainer}"
	local target_dir="${2:-$BATS_TEST_TMPDIR}"

	mkdir -p "$target_dir/.devcontainer"

	case "$config_type" in
	devcontainer)
		cat >"$target_dir/.devcontainer/devcontainer.json" <<'CONFIG_EOF'
{
    "name": "Test Dev Container",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/devcontainers/features/docker-in-docker:1": {}
    }
}
CONFIG_EOF
		;;
	docker)
		cat >"$target_dir/Dockerfile" <<'DOCKERFILE_EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl
WORKDIR /workspaces
DOCKERFILE_EOF
		;;
	compose)
		cat >"$target_dir/docker-compose.yml" <<'COMPOSE_EOF'
version: '3.8'
services:
  app:
    image: ubuntu:22.04
COMPOSE_EOF
		;;
	esac
}

skip_without_bats() {
	if ! command -v bats &>/dev/null; then
		skip "bats not installed"
	fi
}

assert_function_defined() {
	local func_name="$1"
	if ! declare -f "$func_name" >/dev/null 2>&1; then
		echo "ERROR: Function '$func_name' is not defined" >&2
		return 1
	fi
}

assert_file_exists() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo "ERROR: File does not exist: $file" >&2
		return 1
	fi
}

assert_directory_exists() {
	local dir="$1"
	if [ ! -d "$dir" ]; then
		echo "ERROR: Directory does not exist: $dir" >&2
		return 1
	fi
}
