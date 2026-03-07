#!/usr/bin/env bash

# Bash completion for dcutil
# Install by sourcing this file in your .bashrc or placing it in /etc/bash_completion.d/

_dcutil() {
    local cur prev cword
    _init_completion || return

    # Main commands
    local commands="up down restart enter build clean status stats logs list run init check ssh volumes compose features advanced integration merging userprobe hostrequirements shutdown rebuild schema podman version completion test menu help"

    # Subcommands for various modules
    local init_commands="fast wizard --fast --wizard --help -h"
    local volumes_commands="list add remove mount unmount status backup restore help --help -h"
    local stats_commands="show watch detailed top help --help -h"
    local ssh_commands="enable disable status help --help -h"
    local compose_commands="up down restart status list exec logs build clean help --help -h"
    local build_commands="info validate clean help --help -h"
    local features_commands="install info validate clean update check-updates help --help -h"
    local advanced_commands="info validate apply help --help -h"
    local integration_commands="info validate apply help --help -h"
    local merging_commands="show validate cleanup help --help -h"
    local userprobe_commands="probe show apply validate cleanup help --help -h"
    local hostrequirements_commands="validate show cleanup help --help -h"
    local shutdown_commands="execute show validate help --help -h"
    local schema_commands="validate show cleanup help --help -h"
    local podman_commands="status validate init help --help -h"
    local rebuild_options="--force -f --preserve-volumes --preserve-ssh --preserve-agents --preserve-all --help -h"
    local up_options="--project-home --help -h"
    local clean_options="--help -h"
    local status_options="--help -h"
    local logs_options="--help -h"
    local enter_options="--help -h"
    local down_options="--help -h"
    local restart_options="--help -h"
    local run_options="--help -h"
    local check_options="--help -h"
    
    local list_options="--help -h"
    local version_options="--help -h"
    local completion_options="--help -h"
    local test_options="--help -h"

    case "${prev}" in
        dcutil)
            mapfile -t COMPREPLY < <(compgen -W "${commands}" -- "${cur}")
            return
            ;;
        init)
            mapfile -t COMPREPLY < <(compgen -W "${init_commands}" -- "${cur}")
            return
            ;;
        volumes)
            mapfile -t COMPREPLY < <(compgen -W "${volumes_commands}" -- "${cur}")
            return
            ;;
        ssh)
            mapfile -t COMPREPLY < <(compgen -W "${ssh_commands}" -- "${cur}")
            return
            ;;
        compose)
            mapfile -t COMPREPLY < <(compgen -W "${compose_commands}" -- "${cur}")
            return
            ;;
        build)
            mapfile -t COMPREPLY < <(compgen -W "${build_commands}" -- "${cur}")
            return
            ;;
        features)
            mapfile -t COMPREPLY < <(compgen -W "${features_commands}" -- "${cur}")
            return
            ;;
        advanced)
            mapfile -t COMPREPLY < <(compgen -W "${advanced_commands}" -- "${cur}")
            return
            ;;
        integration)
            mapfile -t COMPREPLY < <(compgen -W "${integration_commands}" -- "${cur}")
            return
            ;;
        merging)
            mapfile -t COMPREPLY < <(compgen -W "${merging_commands}" -- "${cur}")
            return
            ;;
        userprobe)
            mapfile -t COMPREPLY < <(compgen -W "${userprobe_commands}" -- "${cur}")
            return
            ;;
        hostrequirements)
            mapfile -t COMPREPLY < <(compgen -W "${hostrequirements_commands}" -- "${cur}")
            return
            ;;
        shutdown)
            mapfile -t COMPREPLY < <(compgen -W "${shutdown_commands}" -- "${cur}")
            return
            ;;
        schema)
            mapfile -t COMPREPLY < <(compgen -W "${schema_commands}" -- "${cur}")
            return
            ;;
        podman)
            mapfile -t COMPREPLY < <(compgen -W "${podman_commands}" -- "${cur}")
            return
            ;;
        rebuild)
            mapfile -t COMPREPLY < <(compgen -W "${rebuild_options}" -- "${cur}")
            return
            ;;
        up)
            mapfile -t COMPREPLY < <(compgen -W "${up_options}" -- "${cur}")
            return
            ;;
        clean)
            mapfile -t COMPREPLY < <(compgen -W "${clean_options}" -- "${cur}")
            return
            ;;
        status)
            mapfile -t COMPREPLY < <(compgen -W "${status_options}" -- "${cur}")
            return
            ;;
        stats)
            mapfile -t COMPREPLY < <(compgen -W "${stats_commands}" -- "${cur}")
            return
            ;;
        logs)
            mapfile -t COMPREPLY < <(compgen -W "${logs_options}" -- "${cur}")
            return
            ;;
        enter)
            mapfile -t COMPREPLY < <(compgen -W "${enter_options}" -- "${cur}")
            return
            ;;
        down)
            mapfile -t COMPREPLY < <(compgen -W "${down_options}" -- "${cur}")
            return
            ;;
        restart)
            mapfile -t COMPREPLY < <(compgen -W "${restart_options}" -- "${cur}")
            return
            ;;
        run)
            # If previous word was 'run', offer project paths and then commands
            if [[ ${cword} -eq 2 ]]; then
                # Complete project paths (directories with .devcontainer)
                local paths=()
                for dir in */; do
                    if [[ -d "${dir}" && ( -f "${dir}.devcontainer/devcontainer.json" || -f "${dir}.devcontainer.json" ) ]]; then
                        paths+=("${dir%/}")
                    fi
                done
                # Also add current directory if it has .devcontainer
                if [[ -f ".devcontainer/devcontainer.json" || -f ".devcontainer.json" ]]; then
                    paths+=(".")
                fi

                # Add directory completions that match current input
                local dir_completions
                mapfile -t dir_completions < <(compgen -d -- "${cur}")

                # Combine devcontainer paths with all directory completions
                local all_paths=("${paths[@]}" "${dir_completions[@]}")
                mapfile -t COMPREPLY < <(compgen -W "${all_paths[*]}" -- "${cur}")
             else
                 # Complete common commands for running in containers
                 local common_commands="bash sh npm node python pip go make cmake cargo rustc git vim nano ls pwd cd"
                 mapfile -t COMPREPLY < <(compgen -W "${common_commands}" -- "${cur}")
             fi
            return
            ;;
        check)
            mapfile -t COMPREPLY < <(compgen -W "${check_options}" -- "${cur}")
            return
            ;;

        list)
            mapfile -t COMPREPLY < <(compgen -W "${list_options}" -- "${cur}")
            return
            ;;
        version)
            mapfile -t COMPREPLY < <(compgen -W "${version_options}" -- "${cur}")
            return
            ;;
        completion)
            mapfile -t COMPREPLY < <(compgen -W "${completion_options}" -- "${cur}")
            return
            ;;
        test)
            mapfile -t COMPREPLY < <(compgen -W "${test_options}" -- "${cur}")
            return
            ;;
        --help|-h)
            return
            ;;
        *)
            # For other commands, complete project paths
            if [[ "${prev}" != "help" && "${prev}" != "--help" && "${prev}" != "-h" ]]; then
                local paths=()
                for dir in */; do
                    if [[ -d "${dir}" && ( -f "${dir}.devcontainer/devcontainer.json" || -f "${dir}.devcontainer.json" ) ]]; then
                        paths+=("${dir%/}")
                    fi
                done
                # Also add current directory if it has .devcontainer
                if [[ -f ".devcontainer/devcontainer.json" || -f ".devcontainer.json" ]]; then
                    paths+=(".")
                fi

                # Add directory completions that match current input
                local dir_completions
                mapfile -t dir_completions < <(compgen -d -- "${cur}")

                # Combine devcontainer paths with all directory completions
                local all_paths=("${paths[@]}" "${dir_completions[@]}")
                mapfile -t COMPREPLY < <(compgen -W "${all_paths[*]}" -- "${cur}")
            fi
            # Handle global flags when current word starts with -
            if [[ "${cur}" == -* ]]; then
                local global_options="--help -h --version completion"
                mapfile -t COMPREPLY < <(compgen -W "${global_options}" -- "${cur}")
            fi
            return
            ;;
    esac

    # Complete global flags if current word starts with -
    if [[ "${cur}" == -* ]]; then
        local global_options="--help -h --version completion"
        mapfile -t COMPREPLY < <(compgen -W "${global_options}" -- "${cur}")
        return
    fi
}

# Register the completion function
complete -F _dcutil dcutil