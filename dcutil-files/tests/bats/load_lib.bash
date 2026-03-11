#!/usr/bin/env bash

DCUTIL_LIB_DIR="${DCUTIL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"

load_library() {
	local lib_name="$1"
	local lib_path="$DCUTIL_LIB_DIR/${lib_name}.sh"

	if [ ! -f "$lib_path" ]; then
		echo "ERROR: Library not found: $lib_path" >&2
		return 1
	fi

	source "$lib_path"
}

load_core() {
	load_library "core"
}

load_docker() {
	load_library "docker"
}

load_podman() {
	load_library "podman"
}

load_ux() {
	load_library "ux"
}

load_features() {
	load_library "features"
}

load_init() {
	load_library "init"
}

load_integration() {
	load_library "integration"
}

load_compose() {
	load_library "compose"
}

load_build() {
	load_library "build"
}

load_volumes() {
	load_library "volumes"
}

load_environment() {
	load_library "environment"
}

load_lifecycle() {
	load_library "lifecycle"
}

load_lockfile() {
	load_library "lockfile"
}

load_merging() {
	load_library "merging"
}

load_monitoring() {
	load_library "monitoring"
}

load_security() {
	load_library "security"
}

load_shutdown() {
	load_library "shutdown"
}

load_userprobe() {
	load_library "userprobe"
}

load_hostrequirements() {
	load_library "hostrequirements"
}

load_advanced() {
	load_library "advanced"
}

load_api_official_cli() {
	load_library "api_official_cli"
}

load_integration_official_cli() {
	load_library "integration_official_cli"
}

load_template_integration() {
	load_library "template_integration"
}

load_schema_validation() {
	load_library "schema-validation"
}

load_all_libs() {
	load_core
	load_ux
	load_features
	load_init
	load_integration
	load_compose
	load_build
	load_volumes
	load_environment
	load_lifecycle
	load_lockfile
	load_merging
	load_monitoring
	load_security
	load_shutdown
	load_userprobe
	load_hostrequirements
	load_advanced
	load_api_official_cli
	load_integration_official_cli
	load_template_integration
	load_schema_validation
}

list_available_libs() {
	if [ -d "$DCUTIL_LIB_DIR" ]; then
		ls -1 "$DCUTIL_LIB_DIR"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//'
	fi
}

get_lib_path() {
	local lib_name="$1"
	echo "$DCUTIL_LIB_DIR/${lib_name}.sh"
}

lib_exists() {
	local lib_name="$1"
	[ -f "$DCUTIL_LIB_DIR/${lib_name}.sh" ]
}
