#!/bin/bash

# Bash completion for dcutil
# Install by sourcing this file in your .bashrc or placing it in /etc/bash_completion.d/

_dcutil_completion() {
    local cur prev words cword
    _init_completion || return

    # Main commands
    local commands="up down enter build clean status logs run init install-opencode help"
    
    # Init subcommands
    local init_commands="fast wizard --fast --wizard --help -h"
    
    case "${prev}" in
        dcutil)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return
            ;;
        init)
            COMPREPLY=($(compgen -W "${init_commands}" -- "${cur}"))
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
                # Add common directory names
                paths+=($(compgen -d -- "${cur}"))
                COMPREPLY=($(compgen -W "${paths[*]}" -- "${cur}"))
            else
                # Complete common commands for running in containers
                local common_commands="bash sh npm node python pip go make cmake cargo rustc"
                COMPREPLY=($(compgen -W "${common_commands}" -- "${cur}"))
            fi
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
                # Add common directory names
                paths+=($(compgen -d -- "${cur}"))
                COMPREPLY=($(compgen -W "${paths[*]}" -- "${cur}"))
            fi
            return
            ;;
    esac

    # Handle options
    if [[ "${cur}" == -* ]]; then
        local options="--help -h"
        COMPREPLY=($(compgen -W "${options}" -- "${cur}"))
        return
    fi
}

# Register the completion function
complete -F _dcutil_completion dcutil