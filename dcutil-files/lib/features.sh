#!/usr/bin/env bash

# Features management and interactive wizard

if [ -z "${LIB_DIR:-}" ]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -f "$LIB_DIR/template_integration.sh" ]; then
    # shellcheck disable=SC1091
    source "$LIB_DIR/template_integration.sh"
fi

features_get_devcontainer_file() {
    if [ -f ".devcontainer/devcontainer.json" ]; then
        echo ".devcontainer/devcontainer.json"
        return
    fi
    if [ -f "devcontainer.json" ]; then
        echo "devcontainer.json"
        return
    fi
    echo "devcontainer.json"
}

features_load_available() {
    if declare -f fetch_available_features_official >/dev/null 2>&1; then
        fetch_available_features_official
    else
        get_fallback_features
    fi
}

features_parse_available_to_lines() {
    local json
    json="$(features_load_available 2>/dev/null || echo "[]")"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r '.[] | [.id, .name, .description, .registry] | @tsv'
    else
        echo "$json" | sed -n 's/[{}"]//g; s/,/\n/g; p'
    fi
}

features_get_current() {
    local file
    file=$(features_get_devcontainer_file)
    if [ ! -f "$file" ]; then
        return
    fi
    if command -v jq >/dev/null 2>&1; then
        local t
        t=$(jq -r 'if .features == null then "none" else .features | type end' "$file" 2>/dev/null || echo "none")
        if [ "$t" = "array" ]; then
            jq -r '.features[]' "$file" 2>/dev/null | sed 's@.*/@@; s/:.*$//'
        elif [ "$t" = "object" ]; then
            jq -r '.features | keys[]' "$file" 2>/dev/null | sed 's@.*/@@; s/:.*$//'
        fi
    else
        grep -oE 'ghcr\\.io[^[:space:]" ]+' "$file" | sed 's@.*/@@; s/:.*$//' | sort -u
    fi
}

features_ensure_object() {
    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local file="$1"
    if [ ! -f "$file" ]; then
        return 1
    fi
    jq 'if .features == null then .features = {} elif (.features | type) == "array" then .features = (.features | map({(.): {}}) | add) else . end' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

features_wizard_nonfzf() {
    local available_lines
    available_lines=$(features_parse_available_to_lines)
    local file
    file=$(features_get_devcontainer_file)

    local current
    current=$(features_get_current)

    declare -a ids names descs regs

    while IFS=$'\t' read -r id name desc registry; do
        ids+=("$id")
        names+=("$name")
        descs+=("$desc")
        regs+=("$registry")
    done <<< "$available_lines"

    if [ ${#ids[@]} -eq 0 ]; then
        printf '\nNo features are available.\n'
        return 1
    fi

    declare -A selected_map
    for id in "${ids[@]}"; do
        if printf "%s\n" "$current" | grep -qx -- "$id"; then
            selected_map["$id"]=1
        fi
    done

    while true; do
        printf '\nAvailable features:\n'
        for i in "${!ids[@]}"; do
            local idx=$((i + 1))
            local id="${ids[i]}"
            local name="${names[i]}"
            local checked="[ ]"
            if [ -n "${selected_map[$id]:-}" ]; then
                checked="[x]"
            fi
            printf '%3d) %s %s - %s\n' "$idx" "$checked" "$id" "$name"
        done

        printf '\nEnter numbers separated by space to toggle selection (e.g. "1 2 5" or ranges "1-3").\n'
        printf 'Commands: a=all, n=none, q=cancel, Enter=done\n'
        read -r -p 'Selection: ' input

        if [ -z "$input" ]; then
            break
        fi
        if [ "$input" = 'q' ]; then
            return 1
        fi
        if [ "$input" = 'a' ]; then
            for id in "${ids[@]}"; do
                selected_map["$id"]=1
            done
            continue
        fi
        if [ "$input" = 'n' ]; then
            for id in "${ids[@]}"; do
                unset "selected_map[$id]"
            done
            continue
        fi

        for token in $input; do
            if [[ "$token" == *"-"* ]]; then
                start=${token%%-*}
                end=${token##*-}
                if ! [[ "$start" =~ ^[0-9]+$ ]] || ! [[ "$end" =~ ^[0-9]+$ ]]; then
                    printf 'Invalid range: %s\n' "$token"
                    continue
                fi
                for ((j=start; j<=end; j++)); do
                    if (( j >= 1 && j <= ${#ids[@]} )); then
                        id="${ids[j-1]}"
                        if [ -n "${selected_map[$id]:-}" ]; then
                            unset "selected_map[$id]"
                        else
                            selected_map["$id"]=1
                        fi
                    fi
                done
            else
                if ! [[ "$token" =~ ^[0-9]+$ ]]; then
                    printf 'Invalid selection: %s\n' "$token"
                    continue
                fi
                if (( token >= 1 && token <= ${#ids[@]} )); then
                    id="${ids[token-1]}"
                    if [ -n "${selected_map[$id]:-}" ]; then
                        unset "selected_map[$id]"
                    else
                        selected_map["$id"]=1
                    fi
                else
                    printf 'Invalid index: %s\n' "$token"
                fi
            fi
        done
    done

    # Print selected ids (one per line)
    for id in "${ids[@]}"; do
        if [ -n "${selected_map[$id]:-}" ]; then
            printf '%s\n' "$id"
        fi
    done
}

features_wizard_fzf() {
    local available_lines
    available_lines=$(features_parse_available_to_lines)
    local file
    file=$(features_get_devcontainer_file)

    local current
    current=$(features_get_current)

    declare -a fzf_input

    while IFS=$'\t' read -r id name desc registry; do
        if printf "%s\n" "$current" | grep -qx -- "$id"; then
            fzf_input+=("[x]	$id	$name	$desc	$registry")
        else
            fzf_input+=("[ ]	$id	$name	$desc	$registry")
        fi
    done <<< "$available_lines"

    if ! command -v fzf >/dev/null 2>&1; then
        printf '\nNo interactive picker found (fzf).\n\nAvailable features:\n'
        for line in "${fzf_input[@]}"; do
            printf "%s\n" "$line"
        done
        printf '\nRun this on a machine with fzf installed for the interactive experience.\n'
        return 1
    fi

    local selected
    selected=$(printf '%s\n' "${fzf_input[@]}" | fzf --ansi --multi --header "Type to filter. Space to toggle. Enter to accept. Ctrl-A to select all." --with-nth=3,4 --preview 'printf "Description:\n\n%s\n" "{4}"' --bind 'ctrl-a:toggle-all' --height 80% --border)

    printf '%s\n' "$selected" | awk -F"\t" '{print $2}'
}

features_apply_changes() {
    local selected_ids=()
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        selected_ids+=("$id")
    done

    local file
    file=$(features_get_devcontainer_file)
    if [ ! -f "$file" ]; then
        printf 'No %s found. Creating new devcontainer.json with selected features...\n' "$file"
        cat > "$file" <<EOF
{
  "features": {}
}
EOF
    fi

    if ! command -v jq >/dev/null 2>&1; then
        printf 'jq is required to apply changes to %s\n' "$file"
        return 1
    fi

    local existing
    existing=$(jq -r 'if .features == null then "" elif (.features|type)=="object" then .features | keys[] else .features[] end' "$file" 2>/dev/null || echo "")
    existing=$(printf '%s' "$existing" | sed 's@.*/@@; s/:.*$//')

    declare -A existing_map
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        existing_map["$e"]=1
    done <<< "$existing"

    declare -A selected_map
    for id in "${selected_ids[@]}"; do
        selected_map["$id"]=1
    done

    local to_add=()
    local to_remove=()

    for id in "${selected_ids[@]}"; do
        if [ -z "${existing_map[$id]:-}" ]; then
            to_add+=("$id")
        fi
    done

    for e in "${!existing_map[@]}"; do
        if [ -z "${selected_map[$e]:-}" ]; then
            to_remove+=("$e")
        fi
    done

    if [ ${#to_add[@]} -eq 0 ] && [ ${#to_remove[@]} -eq 0 ]; then
        printf 'No changes to features.\n'
        return 0
    fi

    printf 'The following changes will be applied to %s:\n' "$file"
    if [ ${#to_add[@]} -gt 0 ]; then
        printf '  Add: %s\n' "${to_add[*]}"
    fi
    if [ ${#to_remove[@]} -gt 0 ]; then
        printf '  Remove: %s\n' "${to_remove[*]}"
    fi

    if [ "${DCUTIL_ASSUME_YES:-0}" = "1" ] || [ "${CI:-}" = "true" ]; then
        confirm=y
    else
        read -r -p 'Apply changes? (y/N): ' confirm
    fi
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf 'Aborted. No changes applied.\n'
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$file" "$tmp"

    # Ensure features is an object
    # Ensure features is an object (convert arrays to object map keys)
    features_ensure_object "$tmp" || true

    for id in "${to_add[@]}"; do
        local key
        key="ghcr.io/devcontainers/features/$id"
        jq --arg k "$key" '.features |= (. + {($k): {}})' "$tmp" > "$tmp.jq" && mv "$tmp.jq" "$tmp"
    done

    for id in "${to_remove[@]}"; do
        local key
        key="ghcr.io/devcontainers/features/$id"
        jq --arg k "$key" 'del(.features[$k])' "$tmp" > "$tmp.jq" && mv "$tmp.jq" "$tmp"
    done

    # Remove duplicate keys that may have been introduced by earlier array conversion
    jq 'if (.features|type)=="array" then .features = (map({(.): {}}) | add) else . end' "$tmp" > "$tmp.jq" && mv "$tmp.jq" "$tmp" || true

    mv "$tmp" "$file"
    printf 'Updated %s\n' "$file"
}

features_show() {
    local file
    file=$(features_get_devcontainer_file)
    if [ ! -f "$file" ]; then
        printf 'No %s found\n' "$file"
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.features' "$file"
    else
        sed -n '1,200p' "$file"
    fi
}

features_add() {
    local ids=("$@")
    if [ ${#ids[@]} -eq 0 ]; then
        printf 'Usage: dcutil features add <feature-id> [<feature-id> ...]\n'
        return 1
    fi
    local file
    file=$(features_get_devcontainer_file)
    if [ ! -f "$file" ]; then
        printf 'No %s found. Creating one.\n' "$file"
        cat > "$file" <<EOF
{
  "features": {}
}
EOF
    fi
    if ! command -v jq >/dev/null 2>&1; then
        printf 'jq required to modify %s\n' "$file"
        return 1
    fi
    for id in "${ids[@]}"; do
        IFS=',' read -ra parts <<< "$id"
        for idpart in "${parts[@]}"; do
            idpart=$(printf '%s' "$idpart" | sed -e 's/^ *//' -e 's/ *$//')
            [ -n "$idpart" ] || continue
            if [[ "$idpart" == *"/"* ]]; then
                key="$idpart"
            else
                key="ghcr.io/devcontainers/features/$idpart"
            fi
            jq --arg k "$key" 'if .features == null then .features = {} else . end | .features |= (. + {($k): {}})' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        done
    done
    printf 'Added %s to %s\n' "${ids[*]}" "$file"
}

features_remove() {
    local ids=("$@")
    if [ ${#ids[@]} -eq 0 ]; then
        printf 'Usage: dcutil features remove <feature-id> [<feature-id> ...]\n'
        return 1
    fi
    local file
    file=$(features_get_devcontainer_file)
    if [ ! -f "$file" ]; then
        printf 'No %s found\n' "$file"
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        printf 'jq required to modify %s\n' "$file"
        return 1
    fi
    for id in "${ids[@]}"; do
        IFS=',' read -ra parts <<< "$id"
        for idpart in "${parts[@]}"; do
            idpart=$(printf '%s' "$idpart" | sed -e 's/^ *//' -e 's/ *$//')
            [ -n "$idpart" ] || continue
            if [[ "$idpart" == *"/"* ]]; then
                key="$idpart"
            else
                key="ghcr.io/devcontainers/features/$idpart"
            fi
            jq --arg k "$key" 'if .features == null then . else del(.features[$k]) end' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        done
    done
    printf 'Removed %s from %s\n' "${ids[*]}" "$file"
}

features() {
    local cmd
    cmd="${1:-}"
    case "$cmd" in
        ""|"wizard")
            shift || true
            local selected
            if command -v fzf >/dev/null 2>&1; then
                selected=$(features_wizard_fzf)
            else
                selected=$(features_wizard_nonfzf)
            fi
            if [ -n "$selected" ]; then
                features_apply_changes <<< "$selected"
            fi
            ;;
        list)
            shift || true
            features_show
            ;;
        add)
            shift || true
            features_add "$@"
            ;;
        remove)
            shift || true
            features_remove "$@"
            ;;
        *)
            printf 'Usage: dcutil features [wizard|list|add|remove]\n'
            return 1
            ;;
    esac
}
