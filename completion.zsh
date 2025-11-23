#compdef dcutil

# Zsh completion for dcutil
# Install by placing this file in your fpath or in ~/.zsh/completion/

_dcutil() {
    local -a commands
    commands=(
        'up:Start the devcontainer'
        'down:Stop the devcontainer'
        'restart:Restart the devcontainer'
        'enter:Enter the container shell'
        'build:Build the devcontainer image'
        'clean:Remove containers, volumes, and configuration files'
        'status:Show container status'
        'logs:Show container logs'
        'list:List running devcontainers'
        'run:Run a command in the container'
        'init:Initialize a devcontainer'
        'install-agent:Install authentication agent inside the devcontainer'
        'check:Check devcontainer configuration'
        'ssh:SSH key management'
        'volumes:Volume management'
        'compose:Docker Compose support'
        'features:Devcontainer Features support'
        'advanced:Advanced devcontainer features'
        'integration:Tool integration features'
        'merging:Image metadata merging'
        'userprobe:User environment probing'
        'hostrequirements:Host system requirements validation'
        'shutdown:Container shutdown actions'
        'rebuild:Rebuild devcontainer with preservation options'
        'schema:Devcontainer configuration schema validation'
        'podman:Podman backend configuration and status'
        'version:Show version information'
        'completion:Generate completion script'
        'test:Test dcutil improvements'
        'help:Show help message'
    )

    local -a init_commands
    init_commands=(
        'fast:Create basic Ubuntu container automatically'
        'wizard:Interactive setup'
        '--fast:Create basic Ubuntu container automatically'
        '--wizard:Interactive setup'
        '--help:Show init help'
        '-h:Show init help'
    )

    local -a volumes_commands
    volumes_commands=(
        'list:List configured volumes'
        'add:Add a new volume'
        'remove:Remove a volume'
        'mount:Show mount configuration'
        'unmount:Unmount a volume'
        'status:Show volume status'
        'backup:Create volume backup'
        'restore:Restore volume from backup'
        'help:Show volumes help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a ssh_commands
    ssh_commands=(
        'start:Start SSH agent'
        'add:Add SSH key to agent'
        'list:List SSH keys in agent'
        'mount:Mount SSH agent socket'
        'test:Test SSH connectivity'
        'connect:Connect to SSH server'
        'help:Show SSH help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a compose_commands
    compose_commands=(
        'up:Start Docker Compose environment'
        'down:Stop Docker Compose environment'
        'restart:Restart Docker Compose environment'
        'status:Show Docker Compose status'
        'list:List Docker Compose services'
        'exec:Execute command in service container'
        'logs:Show Docker Compose logs'
        'build:Build Docker Compose images'
        'clean:Clean up Docker Compose environment'
        'help:Show compose help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a build_commands
    build_commands=(
        'info:Show build configuration information'
        'validate:Validate build configuration'
        'clean:Clean build artifacts and cache'
        'help:Show build help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a features_commands
    features_commands=(
        'install:Install all configured features'
        'info:Show features configuration and status'
        'validate:Validate features configuration'
        'clean:Clean features cache and installation'
        'update:Update all features'
        'check-updates:Check for available feature updates'
        'help:Show features help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a advanced_commands
    advanced_commands=(
        'info:Show advanced features configuration'
        'validate:Validate advanced features configuration'
        'apply:Apply advanced features to running container'
        'help:Show advanced help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a integration_commands
    integration_commands=(
        'info:Show tool integration configuration'
        'validate:Validate tool integration configuration'
        'apply:Apply tool integration features to running container'
        'help:Show integration help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a merging_commands
    merging_commands=(
        'show:Show merged configuration (image metadata + devcontainer.json)'
        'validate:Validate merged configuration'
        'cleanup:Cleanup temporary merged configuration files'
        'help:Show merging help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a userprobe_commands
    userprobe_commands=(
        'probe:Probe user environment variables using configured shell'
        'show:Show probed environment variables'
        'apply:Apply probed environment variables to running container'
        'validate:Validate userEnvProbe configuration'
        'cleanup:Cleanup probed environment variables'
        'help:Show userprobe help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a hostrequirements_commands
    hostrequirements_commands=(
        'validate:Validate host system meets configured requirements'
        'show:Show host requirements configuration and status'
        'cleanup:Cleanup validation state'
        'help:Show hostrequirements help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a shutdown_commands
    shutdown_commands=(
        'execute:Execute shutdown action for running container'
        'show:Show shutdown action configuration'
        'validate:Validate shutdown action configuration'
        'help:Show shutdown help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a schema_commands
    schema_commands=(
        'validate:Validate devcontainer.json against specification schema'
        'show:Show schema validation status and results'
        'cleanup:Cleanup validation state'
        'help:Show schema help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a podman_commands
    podman_commands=(
        'status:Show Podman backend status and configuration'
        'validate:Validate Podman backend configuration'
        'init:Initialize Podman backend'
        'help:Show podman help'
        '--help:Show help'
        '-h:Show help'
    )

    local -a rebuild_options
    rebuild_options=(
        '--force:-f:Force rebuild without prompts'
        '--preserve-volumes:Preserve volumes during rebuild'
        '--preserve-ssh:Preserve SSH agent during rebuild'
        '--preserve-agents:Preserve authentication agents during rebuild'
        '--preserve-all:Preserve all state during rebuild'
        '--help:-h:Show help'
    )

    local -a up_options
    up_options=(
        '--project-home:Set home folder to project directory'
        '--help:-h:Show help'
    )

    local -a common_container_commands
    common_container_commands=(
        'bash:Bash shell'
        'sh:POSIX shell'
        'npm:Node Package Manager'
        'node:Node.js runtime'
        'python:Python interpreter'
        'pip:Python package installer'
        'go:Go compiler'
        'make:Make build tool'
        'cmake:CMake build system'
        'cargo:Rust package manager'
        'rustc:Rust compiler'
    )

    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '*: :->args' \
        && return 0

    case $state in
        command)
            _describe 'command' commands
            ;;
        args)
            case $line[1] in
                init)
                    if [[ $line[2] == --* || $line[2] == -h ]]; then
                        _describe 'init option' init_commands
                    else
                        _describe 'init mode' init_commands
                    fi
                    ;;
                volumes)
                    _describe 'volume command' volumes_commands
                    ;;
                ssh)
                    _describe 'ssh command' ssh_commands
                    ;;
                compose)
                    _describe 'compose command' compose_commands
                    ;;
                build)
                    _describe 'build command' build_commands
                    ;;
                features)
                    _describe 'features command' features_commands
                    ;;
                advanced)
                    _describe 'advanced command' advanced_commands
                    ;;
                integration)
                    _describe 'integration command' integration_commands
                    ;;
                merging)
                    _describe 'merging command' merging_commands
                    ;;
                userprobe)
                    _describe 'userprobe command' userprobe_commands
                    ;;
                hostrequirements)
                    _describe 'hostrequirements command' hostrequirements_commands
                    ;;
                shutdown)
                    _describe 'shutdown command' shutdown_commands
                    ;;
                schema)
                    _describe 'schema command' schema_commands
                    ;;
                podman)
                    _describe 'podman command' podman_commands
                    ;;
                rebuild)
                    _describe 'rebuild options' rebuild_options
                    ;;
                up)
                    if [[ $line[2] == --* ]]; then
                        _describe 'up options' up_options
                    else
                        _alternative \
                            'paths:project path:_directories -S /' \
                            'devcontainer-projects:devcontainer projects:_dcutil_devcontainer_projects'
                    fi
                    ;;
                run)
                    if [[ ${#line} -eq 2 ]]; then
                        _alternative \
                            'paths:project path:_directories -S /' \
                            'devcontainer-projects:devcontainer projects:_dcutil_devcontainer_projects'
                    else
                        _describe 'container command' common_container_commands
                    fi
                    ;;
                *)
                    if [[ $line[2] == --* ]]; then
                        # If the argument starts with a dash, provide general options
                        local general_options
                        general_options=(
                            '--help:Show help message'
                            '-h:Show help message'
                            '--version:Show version information'
                        )
                        _describe 'global options' general_options
                    else
                        # For most commands, provide paths if no specific subcommand
                        _alternative \
                            'paths:project path:_directories -S /' \
                            'devcontainer-projects:devcontainer projects:_dcutil_devcontainer_projects'
                    fi
                    ;;
            esac
            ;;
    esac
}

_dcutil_devcontainer_projects() {
    local -a projects
    for dir in */; do
        if [[ -d "$dir" && ( -f "$dir.devcontainer/devcontainer.json" || -f "$dir.devcontainer.json" ) ]]; then
            projects+=("${dir%/}")
        fi
    done
    if [[ -f ".devcontainer/devcontainer.json" || -f ".devcontainer.json" ]]; then
        projects+=(".")
    fi
    _describe 'devcontainer projects' projects
}

_dcutil "$@"