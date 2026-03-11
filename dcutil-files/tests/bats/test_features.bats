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
    FEATURES_DEFAULT_VERSION="latest"
    export FEATURES_DEFAULT_VERSION

    FEATURES_CACHE_DIR="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$FEATURES_CACHE_DIR"
    export FEATURES_CACHE_DIR

    set +u
}

teardown() {
    set +u
    teardown_test_tmpdir
    teardown_mocks_dir

    unset FEATURES_REGISTRY
    unset FEATURES_NAMESPACE
    unset FEATURES_DEFAULT_VERSION
    unset FEATURES_CACHE_DIR
    unset FEATURES_DIR
    unset FEATURES_INSTALL_LOG
    unset FEATURES_DRY_RUN
    unset FEATURE_ID
    unset FEATURE_NAME
    unset FEATURE_VERSION
    unset VERSION

    local var
    for var in $(env | grep -E '^(DCUTIL_INPUT_|DCUTIL_FEATURE_INPUT_)' 2>/dev/null | cut -d= -f1); do
        unset "$var" 2>/dev/null || true
    done

    unset INPUTS_NAMES
    unset INPUTS_DEFAULTS
    unset INPUTS_DESCRIPTIONS
    unset INPUTS_VALUES
}

load_features_lib() {
    source_lib "core"
    source_lib "features"
}

create_jq_mock_for_features() {
    local jq_mock="$BATS_TEST_TMPDIR/bin/jq"
    mkdir -p "$(dirname "$jq_mock")"

    cat > "$jq_mock" <<'JQ_EOF'
#!/usr/bin/env bash
if [ $# -eq 0 ]; then
    echo "Usage: jq [options...] filter [files...]" >&2
    exit 1
fi

args=("$@")
filter=""
files=()
arg_name=""
arg_val=""
validate_mode=""

i=0
while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
        -e)
            if [[ "${args[$((i+1))]:-}" == "." ]]; then
                validate_mode=1
            fi
            ;;
        -r|-c|-n|-M|-S|-s|-0|-a|-j|-L|-f|-tab|-pri|-rnt)
            ;;
        --arg)
            arg_name="${args[$((i+1))]:-}"
            arg_val="${args[$((i+2))]:-}"
            i=$((i + 3))
            continue
            ;;
        --argjson)
            i=$((i + 2))
            continue
            ;;
        *)
            ;;
    esac
    i=$((i + 1))
done

i=0
while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
        -e|-r|-c|-n|-M|-S|-s|-0|-a|-j|-L|-f|-tab|-pri|-rnt)
            ;;
        --arg)
            i=$((i + 3))
            continue
            ;;
        --argjson)
            i=$((i + 2))
            continue
            ;;
        *)
            if [[ "${args[$i]}" == -* ]]; then
                :
            elif [[ -z "$filter" ]]; then
                filter="${args[$i]}"
            else
                files+=("${args[$i]}")
            fi
            ;;
    esac
    i=$((i + 1))
done

if [ -n "$validate_mode" ] && [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
    python3 -c "import json; json.load(open('${files[0]}'))" 2>/dev/null
    if [ $? -eq 0 ]; then
        cat "${files[0]}"
        exit 0
    else
        exit 1
    fi
fi

json_input=""
if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
    json_input=$(cat "${files[0]}" 2>/dev/null)
elif [ ! -t 0 ]; then
    json_input=$(cat)
fi

simple_match() {
    local pattern="$1"
    echo "$json_input" | grep -oP "\"$pattern\"\s*:\s*\"\K[^\"]+" 2>/dev/null | head -1
}

case "$filter" in
    ".features")
        if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
            if grep -q '"features"' "${files[0]}" 2>/dev/null; then
                echo '{}'
                exit 0
            fi
        fi
        echo "$json_input"
        ;;
    ".features | type == \"object\"")
        if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
            echo 'true'
            exit 0
        fi
        echo 'false'
        ;;
    ".features | type == \"array\"")
        echo 'false'
        ;;
    ".features[$key]")
        echo '{}'
        ;;
    ".features[$key] | type == \"object\"")
        echo 'true'
        ;;
    ".features[$key].version")
        echo '"1.0.0"'
        ;;
    ".id")
        simple_match "id"
        ;;
    ".version")
        simple_match "version"
        ;;
    ".features | keys[]")
        if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
            grep -o '"[^"]*"\s*:' "${files[0]}" | sed 's/:.*//;s/"//g' | head -5
        fi
        ;;
    ".[]")
        echo "$json_input"
        ;;
    ".features[]")
        echo "$json_input"
        ;;
    ".[] | select(.id | test(\$name; \"i\")) | .id")
        if [ -n "$arg_val" ]; then
            result=$(echo "$json_input" | grep -io "\"id\"\s*:\s*\"[^\"]*$arg_val[^\"]*\"" | head -1)
            if [ -n "$result" ]; then
                echo "$result" | grep -oP '"\K[^"]+' | head -1
            else
                echo ""
            fi
        else
            echo ""
        fi
        ;;
    ".[] | select(.id | endswith(\$basename)) | .id")
        if [ -n "$arg_val" ]; then
            result=$(echo "$json_input" | grep -o "\"id\"\s*:\s*\"[^\"]*$arg_val\"" | head -1)
            if [ -n "$result" ]; then
                echo "$result" | grep -oP '"\K[^"]+' | head -1
            else
                echo ""
            fi
        else
            echo ""
        fi
        ;;
    "keys[]")
        if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
            grep -o '"\w*"\s*:' "${files[0]}" | sed 's/:.*//;s/"//g' | head -10
        fi
        ;;
    ".dependsOn[]")
        if [ ${#files[@]} -gt 0 ] && [ -f "${files[0]}" ]; then
            grep -oP '"dependsOn"\s*:\s*\[\K[^\]]+' "${files[0]}" | grep -oP '"[^"]+' | tr -d '"' || echo ""
        fi
        ;;
    "length")
        if [ ${#files[@]} -gt 0 ]; then
            local content
            content=$(cat "${files[0]}" 2>/dev/null || echo "[]")
            echo "$content" | grep -o '{' | wc -l | tr -d ' '
        else
            echo "0"
        fi
        ;;
    "empty")
        exit 1
        ;;
    *)
        echo '{}'
        ;;
esac
exit 0
JQ_EOF
    chmod +x "$jq_mock"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

stub_command() {
    local cmd="$1"
    local return_code="${2:-0}"
    local output="${3:-}"

    local mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"

    local mock_script="$mock_dir/$cmd"
    cat > "$mock_script" <<STUB_EOF
#!/usr/bin/env bash
STUB_EOF
    if [ -n "$output" ]; then
        cat >> "$mock_script" <<STUB_EOF
echo "$output"
STUB_EOF
    fi
    cat >> "$mock_script" <<STUB_EOF
exit $return_code
STUB_EOF
    chmod +x "$mock_script"
    export PATH="$mock_dir:$PATH"
}

create_curl_mock_success() {
    stub_command curl 0 ""
    local curl_mock="$BATS_TEST_TMPDIR/bin/curl"
    cat > "$curl_mock" <<'CURL_EOF'
#!/usr/bin/env bash
exit 0
CURL_EOF
    chmod +x "$curl_mock"
}

create_curl_mock_failure() {
    stub_command curl 1 ""
}

# ============================================
# parse_feature_spec() tests
# ============================================

@test "parse_feature_spec: short format - simple name" {
    load_features_lib

    run parse_feature_spec "node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: short format with version" {
    load_features_lib

    run parse_feature_spec "node:1"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:1" ]
}

@test "parse_feature_spec: medium format - devcontainers/features/name" {
    load_features_lib

    run parse_feature_spec "devcontainers/features/node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: medium format with version" {
    load_features_lib

    run parse_feature_spec "devcontainers/features/node:2"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:2" ]
}

@test "parse_feature_spec: full format - ghcr.io/.../name" {
    load_features_lib

    run parse_feature_spec "ghcr.io/devcontainers/features/node"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "parse_feature_spec: full format with version" {
    load_features_lib

    run parse_feature_spec "ghcr.io/devcontainers/features/node:3"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:3" ]
}

@test "parse_feature_spec: custom registry - myregistry.com/user/feature" {
    load_features_lib

    run parse_feature_spec "myregistry.com/user/feature"
    [ "$status" -eq 0 ]
    [ "$output" = "myregistry.com/user/feature:latest" ]
}

@test "parse_feature_spec: custom registry with version" {
    load_features_lib

    run parse_feature_spec "myregistry.com/user/feature:v1.0"
    [ "$status" -eq 0 ]
    [ "$output" = "myregistry.com/user/feature:v1.0" ]
}

@test "parse_feature_spec: default version is latest when not specified" {
    load_features_lib

    run parse_feature_spec "docker-in-docker"
    [ "$status" -eq 0 ]
    [[ "$output" == *":latest" ]]
}

@test "parse_feature_spec: handles empty version as empty (not latest)" {
    load_features_lib

    run parse_feature_spec "node:"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:" ]
}

@test "parse_feature_spec: handles special characters in feature name" {
    load_features_lib

    run parse_feature_spec "docker-in-docker"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/docker-in-docker:latest" ]
}

# ============================================
# feature_exists_in_downloaded_list() tests
# ============================================

@test "feature_exists_in_downloaded_list: returns 0 when list is empty" {
    load_features_lib

    run feature_exists_in_downloaded_list "node" "[]"
    [ "$status" -eq 0 ]
}

@test "feature_exists_in_downloaded_list: returns 0 when list is not provided" {
    load_features_lib

    run feature_exists_in_downloaded_list "node" ""
    [ "$status" -eq 0 ]
}

@test "feature_exists_in_downloaded_list: returns 0 when feature found by id" {
    load_features_lib
    create_jq_mock_for_features

    local json='[{"id": "node"}]'
    run feature_exists_in_downloaded_list "node" "$json"
    [ "$status" -eq 0 ]
}

@test "feature_exists_in_downloaded_list: returns 0 when feature found by case-insensitive match" {
    load_features_lib
    create_jq_mock_for_features

    local json='[{"id": "node"}]'
    run feature_exists_in_downloaded_list "NODE" "$json"
    [ "$status" -eq 0 ]
}

@test "feature_exists_in_downloaded_list: returns 0 when feature found by basename" {
    load_features_lib
    create_jq_mock_for_features

    local json='[{"id": "devcontainers/features/node"}]'
    run feature_exists_in_downloaded_list "node" "$json"
    [ "$status" -eq 0 ]
}

@test "feature_exists_in_downloaded_list: returns 1 when feature not found" {
    load_features_lib
    create_jq_mock_for_features

    local json='[{"id": "docker-in-docker"}]'
    run feature_exists_in_downloaded_list "nonexistent-feature" "$json"
    [ "$status" -eq 1 ]
}

@test "feature_exists_in_downloaded_list: handles full path feature id" {
    load_features_lib
    create_jq_mock_for_features

    local json='[{"id": "ghcr.io/devcontainers/features/node"}]'
    run feature_exists_in_downloaded_list "ghcr.io/devcontainers/features/node" "$json"
    [ "$status" -eq 0 ]
}

# ============================================
# validate_feature_cache_dir() tests
# ============================================

@test "validate_feature_cache_dir: returns 1 for empty path" {
    load_features_lib

    run validate_feature_cache_dir ""
    [ "$status" -eq 1 ]
}

@test "validate_feature_cache_dir: returns 1 for non-existent directory" {
    load_features_lib

    run validate_feature_cache_dir "$BATS_TEST_TMPDIR/nonexistent"
    [ "$status" -eq 1 ]
}

@test "validate_feature_cache_dir: returns 0 when devcontainer-feature.json exists" {
    load_features_lib

    local cache_dir="$BATS_TEST_TMPDIR/feature1"
    mkdir -p "$cache_dir"
    echo '{}' > "$cache_dir/devcontainer-feature.json"

    run validate_feature_cache_dir "$cache_dir"
    [ "$status" -eq 0 ]
}

@test "validate_feature_cache_dir: returns 0 when src/install.sh exists" {
    load_features_lib

    local cache_dir="$BATS_TEST_TMPDIR/feature2"
    mkdir -p "$cache_dir/src"
    echo '#!/bin/bash' > "$cache_dir/src/install.sh"

    run validate_feature_cache_dir "$cache_dir"
    [ "$status" -eq 0 ]
}

@test "validate_feature_cache_dir: returns 1 for directory without required files" {
    load_features_lib

    local cache_dir="$BATS_TEST_TMPDIR/feature3"
    mkdir -p "$cache_dir"

    run validate_feature_cache_dir "$cache_dir"
    [ "$status" -eq 1 ]
}

@test "validate_feature_cache_dir: validates JSON when jq is available" {
    load_features_lib
    create_jq_mock_for_features

    local cache_dir="$BATS_TEST_TMPDIR/feature4"
    mkdir -p "$cache_dir"
    echo '{}' > "$cache_dir/devcontainer-feature.json"

    run validate_feature_cache_dir "$cache_dir"
    [ "$status" -eq 0 ]
}

@test "validate_feature_cache_dir: returns 1 for invalid JSON when jq is available" {
    load_features_lib
    create_jq_mock_for_features

    local cache_dir="$BATS_TEST_TMPDIR/feature5"
    mkdir -p "$cache_dir"
    echo 'invalid{json' > "$cache_dir/devcontainer-feature.json"

    run validate_feature_cache_dir "$cache_dir"
    [ "$status" -eq 1 ]
}

# ============================================
# env_prepare_inputs_for_feature() tests
# ============================================

@test "env_prepare_inputs_for_feature: exports standard feature variables" {
    load_features_lib

    unset FEATURE_ID
    unset FEATURE_NAME
    unset FEATURE_VERSION
    unset VERSION

    env_prepare_inputs_for_feature "node:latest" "{}"

    [ -n "$FEATURE_ID" ]
    [ -n "$FEATURE_NAME" ]
    [ -n "$FEATURE_VERSION" ]
    [ -n "$VERSION" ]
}

@test "env_prepare_inputs_for_feature: sets FEATURE_ID to full registry path" {
    load_features_lib

    env_prepare_inputs_for_feature "node:latest" "{}"

    [ "$FEATURE_ID" = "ghcr.io/devcontainers/features/node" ]
}

@test "env_prepare_inputs_for_feature: sets FEATURE_NAME to basename" {
    load_features_lib

    env_prepare_inputs_for_feature "node:latest" "{}"

    [ "$FEATURE_NAME" = "node" ]
}

@test "env_prepare_inputs_for_feature: sets FEATURE_VERSION correctly" {
    load_features_lib

    env_prepare_inputs_for_feature "node:1.2.3" "{}"

    [ "$FEATURE_VERSION" = "1.2.3" ]
    [ "$VERSION" = "1.2.3" ]
}

@test "env_prepare_inputs_for_feature: handles global inputs from INPUTS_NAMES" {
    load_features_lib

    INPUTS_NAMES=("variant")
    INPUTS_DEFAULTS=([variant]="18")
    INPUTS_VALUES=([variant]="20")

    env_prepare_inputs_for_feature "node:latest" "{}"

    [ -n "$DCUTIL_INPUT_VARIANT" ]
}

@test "env_prepare_inputs_for_feature: exports feature-specific input variables" {
    load_features_lib

    INPUTS_NAMES=("variant")
    INPUTS_DEFAULTS=([variant]="18")
    INPUTS_VALUES=([variant]="20")

    env_prepare_inputs_for_feature "node:latest" "{}"

    [ -n "$DCUTIL_FEATURE_INPUT_NODE_VARIANT" ]
}

@test "env_prepare_inputs_for_feature: handles feature config object" {
    load_features_lib
    create_jq_mock_for_features

    env_prepare_inputs_for_feature "node:latest" '{"version":"20.04"}'

    [ -n "$VERSION" ] || [ -n "$DCUTIL_FEATURE_INPUT_NODE_VERSION" ]
}

@test "env_prepare_inputs_for_feature: handles complex feature names with hyphens" {
    load_features_lib

    env_prepare_inputs_for_feature "docker-in-docker:latest" "{}"

    echo "FEATURE_NAME=$FEATURE_NAME"
    [ "$FEATURE_NAME" = "docker-in-docker" ]
}

# ============================================
# env_clear_inputs_for_feature() tests
# ============================================

@test "env_clear_inputs_for_feature: unsets global input variables" {
    load_features_lib

    INPUTS_NAMES=("variant")
    export DCUTIL_INPUT_VARIANT="test-value"

    env_clear_inputs_for_feature "NODE"

    [ -z "${DCUTIL_INPUT_VARIANT:-}" ]
}

@test "env_clear_inputs_for_feature: unsets feature-specific input variables" {
    load_features_lib

    INPUTS_NAMES=("variant")
    export DCUTIL_FEATURE_INPUT_NODE_VARIANT="test-value"

    env_clear_inputs_for_feature "NODE"

    [ -z "${DCUTIL_FEATURE_INPUT_NODE_VARIANT:-}" ]
}

@test "env_clear_inputs_for_feature: handles multiple inputs" {
    load_features_lib

    INPUTS_NAMES=("variant" "version" "option")
    export DCUTIL_INPUT_VARIANT="v1"
    export DCUTIL_INPUT_VERSION="v2"
    export DCUTIL_INPUT_OPTION="v3"
    export DCUTIL_FEATURE_INPUT_NODE_VARIANT="fv1"
    export DCUTIL_FEATURE_INPUT_NODE_VERSION="fv2"
    export DCUTIL_FEATURE_INPUT_NODE_OPTION="fv3"

    env_clear_inputs_for_feature "NODE"

    [ -z "${DCUTIL_INPUT_VARIANT:-}" ]
    [ -z "${DCUTIL_INPUT_VERSION:-}" ]
    [ -z "${DCUTIL_INPUT_OPTION:-}" ]
    [ -z "${DCUTIL_FEATURE_INPUT_NODE_VARIANT:-}" ]
    [ -z "${DCUTIL_FEATURE_INPUT_NODE_VERSION:-}" ]
    [ -z "${DCUTIL_FEATURE_INPUT_NODE_OPTION:-}" ]
}

@test "env_clear_inputs_for_feature: does not fail on non-existent variables" {
    load_features_lib

    INPUTS_NAMES=()

    run env_clear_inputs_for_feature "NODE"

    [ "$status" -eq 0 ]
}

# ============================================
# match_requested_feature_by_id() tests
# ============================================

@test "match_requested_feature_by_id: returns exact match" {
    load_features_lib

    local requested=("ghcr.io/devcontainers/features/node:latest")

    run match_requested_feature_by_id "node" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "match_requested_feature_by_id: matches by id without version" {
    load_features_lib

    local requested=("ghcr.io/devcontainers/features/node:latest")

    run match_requested_feature_by_id "ghcr.io/devcontainers/features/node" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "match_requested_feature_by_id: returns canonicalized dep when no match" {
    load_features_lib

    local requested=("ghcr.io/devcontainers/features/docker-in-docker:latest")

    run match_requested_feature_by_id "nonexistent" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "match_requested_feature_by_id: handles empty requested features array" {
    load_features_lib

    run match_requested_feature_by_id "node" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "match_requested_feature_by_id: handles version in dependency" {
    load_features_lib

    local requested=("ghcr.io/devcontainers/features/node:latest")

    run match_requested_feature_by_id "node:1.0.0" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "match_requested_feature_by_id: handles multiple requested features" {
    load_features_lib

    local requested=(
        "ghcr.io/devcontainers/features/node:latest"
        "ghcr.io/devcontainers/features/docker-in-docker:latest"
    )

    run match_requested_feature_by_id "docker-in-docker" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/docker-in-docker:latest" ]
}

@test "match_requested_feature_by_id: prefers exact id match" {
    load_features_lib

    local requested=(
        "ghcr.io/devcontainers/features/node:latest"
        "ghcr.io/devcontainers/features/node:1.0"
    )

    run match_requested_feature_by_id "node" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

# ============================================
# Integration tests - combined scenarios
# ============================================

@test "parse_feature_spec then validate_feature_cache_dir: round-trip" {
    load_features_lib

    local spec
    spec=$(parse_feature_spec "node:1.0")
    local feature_id="${spec%:*}"
    local feature_name="${feature_id##*/}"

    [ "$feature_name" = "node" ]
    [ "$spec" = "ghcr.io/devcontainers/features/node:1.0" ]
}

@test "env_prepare then env_clear: cleanup works correctly" {
    load_features_lib

    INPUTS_NAMES=("testInput")
    INPUTS_VALUES=([testInput]="testValue")

    env_prepare_inputs_for_feature "test-feature:latest" "{}"
    local original_value="$DCUTIL_INPUT_TESTINPUT"

    env_clear_inputs_for_feature "TEST_FEATURE"

    [ -z "${DCUTIL_INPUT_TESTINPUT:-}" ]
}

@test "feature_exists_in_downloaded_list with parse_feature_spec: validation workflow" {
    load_features_lib
    create_jq_mock_for_features

    local canonical_spec
    canonical_spec=$(parse_feature_spec "node")
    local feature_name="${canonical_spec%%:*}"
    feature_name="${feature_name##*/}"

    local features_json='[{"id":"node","name":"Node.js"}]'
    run feature_exists_in_downloaded_list "$feature_name" "$features_json"

    [ "$status" -eq 0 ]
}

@test "match_requested_feature_by_id with multiple dependencies" {
    load_features_lib

    local requested=(
        "ghcr.io/devcontainers/features/node:latest"
        "ghcr.io/devcontainers/features/docker-in-docker:latest"
        "ghcr.io/devcontainers/features/git:latest"
    )

    run match_requested_feature_by_id "docker-in-docker" "${requested[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/devcontainers/features/docker-in-docker:latest" ]
}

@test "validate_feature_cache_dir: with mock jq returns correct status" {
    load_features_lib
    create_jq_mock_for_features

    local valid_cache="$BATS_TEST_TMPDIR/valid_cache"
    mkdir -p "$valid_cache"
    echo '{"id":"test"}' > "$valid_cache/devcontainer-feature.json"

    run validate_feature_cache_dir "$valid_cache"
    [ "$status" -eq 0 ]

    local invalid_cache="$BATS_TEST_TMPDIR/invalid_cache"
    mkdir -p "$invalid_cache"
    echo 'invalid json' > "$invalid_cache/devcontainer-feature.json"

    run validate_feature_cache_dir "$invalid_cache"
    [ "$status" -eq 1 ]
}

@test "env_prepare_inputs_for_feature: feature safe name generation" {
    load_features_lib

    env_prepare_inputs_for_feature "docker-in-docker:latest" "{}"

    local safe_name="${FEATURE_NAME//[\/\\.-]/_}"
    safe_name="${safe_name^^}"

    [ "$safe_name" = "DOCKER_IN_DOCKER" ]
}

@test "parse_feature_spec: handles various version formats" {
    load_features_lib

    run parse_feature_spec "node:1"
    [ "$output" = "ghcr.io/devcontainers/features/node:1" ]

    run parse_feature_spec "node:1.0"
    [ "$output" = "ghcr.io/devcontainers/features/node:1.0" ]

    run parse_feature_spec "node:1.0.0"
    [ "$output" = "ghcr.io/devcontainers/features/node:1.0.0" ]

    run parse_feature_spec "node:v1.0.0"
    [ "$output" = "ghcr.io/devcontainers/features/node:v1.0.0" ]

    run parse_feature_spec "node:latest"
    [ "$output" = "ghcr.io/devcontainers/features/node:latest" ]
}

@test "feature_exists_in_downloaded_list: empty list assumes feature might exist" {
    load_features_lib

    run feature_exists_in_downloaded_list "any-feature" "[]"
    [ "$status" -eq 0 ]

    run feature_exists_in_downloaded_list "any-feature" ""
    [ "$status" -eq 0 ]
}

@test "env_prepare_inputs_for_feature: handles empty config" {
    load_features_lib

    env_prepare_inputs_for_feature "node:latest" ""

    [ -n "$FEATURE_ID" ]
    [ -n "$FEATURE_NAME" ]
    [ -n "$FEATURE_VERSION" ]
}

@test "env_prepare_inputs_for_feature: handles null config" {
    load_features_lib

    env_prepare_inputs_for_feature "node:latest" "null"

    [ -n "$FEATURE_ID" ]
    [ -n "$FEATURE_NAME" ]
}
