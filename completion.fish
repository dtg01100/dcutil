# Fish shell completion for dcutil
# Install by placing this file in ~/.config/fish/completions/dcutil.fish

# Main commands
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "up" -d "Start the devcontainer"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "down" -d "Stop the devcontainer"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "restart" -d "Restart the devcontainer"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "enter" -d "Enter the container shell"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "build" -d "Build the devcontainer image"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "clean" -d "Remove containers, volumes, and configuration files"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "status" -d "Show container status"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "logs" -d "Show container logs"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "list" -d "List running devcontainers"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "run" -d "Run a command in the container"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "init" -d "Initialize a devcontainer"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "install-agent" -d "Install authentication agent inside the devcontainer"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "check" -d "Check devcontainer configuration"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "ssh" -d "SSH key management"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "volumes" -d "Volume management"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "compose" -d "Docker Compose support"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "features" -d "Devcontainer Features support"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "advanced" -d "Advanced devcontainer features"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "integration" -d "Tool integration features"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "merging" -d "Image metadata merging"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "userprobe" -d "User environment probing"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "hostrequirements" -d "Host system requirements validation"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "shutdown" -d "Container shutdown actions"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "rebuild" -d "Rebuild devcontainer with preservation options"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "schema" -d "Devcontainer configuration schema validation"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "podman" -d "Podman backend configuration and status"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "version" -d "Show version information"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "completion" -d "Generate completion script"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "test" -d "Test dcutil improvements"
complete -c dcutil -f -n "not __fish_seen_subcommand_from $dcutil_all_subcommands" -a "help" -d "Show help message"

# Global flags
complete -c dcutil -s h -l help -d "Show help message"
complete -c dcutil -l version -d "Show version information"

# Init subcommands
set -l dcutil_init_subcommands fast wizard
complete -c dcutil -f -n "__fish_seen_subcommand_from init" -a "fast" -d "Create basic Ubuntu container automatically"
complete -c dcutil -f -n "__fish_seen_subcommand_from init" -a "wizard" -d "Interactive setup"
complete -c dcutil -f -n "__fish_seen_subcommand_from init" -l fast -d "Create basic Ubuntu container automatically"
complete -c dcutil -f -n "__fish_seen_subcommand_from init" -l wizard -d "Interactive setup"

# Volumes subcommands
set -l dcutil_volumes_subcommands list add remove mount unmount status backup restore
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "list" -d "List configured volumes"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "add" -d "Add a new volume"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "remove" -d "Remove a volume"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "mount" -d "Show mount configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "unmount" -d "Unmount a volume"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "status" -d "Show volume status"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "backup" -d "Create volume backup"
complete -c dcutil -f -n "__fish_seen_subcommand_from volumes" -a "restore" -d "Restore volume from backup"

# SSH subcommands
set -l dcutil_ssh_subcommands start add list mount test connect
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "start" -d "Start SSH agent"
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "add" -d "Add SSH key to agent"
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "list" -d "List SSH keys in agent"
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "mount" -d "Mount SSH agent socket"
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "test" -d "Test SSH connectivity"
complete -c dcutil -f -n "__fish_seen_subcommand_from ssh" -a "connect" -d "Connect to SSH server"

# Compose subcommands
set -l dcutil_compose_subcommands up down restart status list exec logs build clean
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "up" -d "Start Docker Compose environment"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "down" -d "Stop Docker Compose environment"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "restart" -d "Restart Docker Compose environment"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "status" -d "Show Docker Compose status"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "list" -d "List Docker Compose services"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "exec" -d "Execute command in service container"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "logs" -d "Show Docker Compose logs"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "build" -d "Build Docker Compose images"
complete -c dcutil -f -n "__fish_seen_subcommand_from compose" -a "clean" -d "Clean up Docker Compose environment"

# Build subcommands
set -l dcutil_build_subcommands info validate clean
complete -c dcutil -f -n "__fish_seen_subcommand_from build" -a "info" -d "Show build configuration information"
complete -c dcutil -f -n "__fish_seen_subcommand_from build" -a "validate" -d "Validate build configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from build" -a "clean" -d "Clean build artifacts and cache"

# Features subcommands
set -l dcutil_features_subcommands install info validate clean update check-updates
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "install" -d "Install all configured features"
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "info" -d "Show features configuration and status"
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "validate" -d "Validate features configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "clean" -d "Clean features cache and installation"
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "update" -d "Update all features"
complete -c dcutil -f -n "__fish_seen_subcommand_from features" -a "check-updates" -d "Check for available feature updates"

# Advanced subcommands
set -l dcutil_advanced_subcommands info validate apply
complete -c dcutil -f -n "__fish_seen_subcommand_from advanced" -a "info" -d "Show advanced features configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from advanced" -a "validate" -d "Validate advanced features configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from advanced" -a "apply" -d "Apply advanced features to running container"

# Integration subcommands
set -l dcutil_integration_subcommands info validate apply
complete -c dcutil -f -n "__fish_seen_subcommand_from integration" -a "info" -d "Show tool integration configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from integration" -a "validate" -d "Validate tool integration configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from integration" -a "apply" -d "Apply tool integration features to running container"

# Merging subcommands
set -l dcutil_merging_subcommands show validate cleanup
complete -c dcutil -f -n "__fish_seen_subcommand_from merging" -a "show" -d "Show merged configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from merging" -a "validate" -d "Validate merged configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from merging" -a "cleanup" -d "Cleanup temporary merged configuration files"

# Userprobe subcommands
set -l dcutil_userprobe_subcommands probe show apply validate cleanup
complete -c dcutil -f -n "__fish_seen_subcommand_from userprobe" -a "probe" -d "Probe user environment variables"
complete -c dcutil -f -n "__fish_seen_subcommand_from userprobe" -a "show" -d "Show probed environment variables"
complete -c dcutil -f -n "__fish_seen_subcommand_from userprobe" -a "apply" -d "Apply probed environment variables to running container"
complete -c dcutil -f -n "__fish_seen_subcommand_from userprobe" -a "validate" -d "Validate userEnvProbe configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from userprobe" -a "cleanup" -d "Cleanup probed environment variables"

# Hostrequirements subcommands
set -l dcutil_hostrequirements_subcommands validate show cleanup
complete -c dcutil -f -n "__fish_seen_subcommand_from hostrequirements" -a "validate" -d "Validate host system meets configured requirements"
complete -c dcutil -f -n "__fish_seen_subcommand_from hostrequirements" -a "show" -d "Show host requirements configuration and status"
complete -c dcutil -f -n "__fish_seen_subcommand_from hostrequirements" -a "cleanup" -d "Cleanup validation state"

# Shutdown subcommands
set -l dcutil_shutdown_subcommands execute show validate
complete -c dcutil -f -n "__fish_seen_subcommand_from shutdown" -a "execute" -d "Execute shutdown action for running container"
complete -c dcutil -f -n "__fish_seen_subcommand_from shutdown" -a "show" -d "Show shutdown action configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from shutdown" -a "validate" -d "Validate shutdown action configuration"

# Schema subcommands
set -l dcutil_schema_subcommands validate show cleanup
complete -c dcutil -f -n "__fish_seen_subcommand_from schema" -a "validate" -d "Validate devcontainer.json against specification schema"
complete -c dcutil -f -n "__fish_seen_subcommand_from schema" -a "show" -d "Show schema validation status and results"
complete -c dcutil -f -n "__fish_seen_subcommand_from schema" -a "cleanup" -d "Cleanup validation state"

# Podman subcommands
set -l dcutil_podman_subcommands status validate init
complete -c dcutil -f -n "__fish_seen_subcommand_from podman" -a "status" -d "Show Podman backend status and configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from podman" -a "validate" -d "Validate Podman backend configuration"
complete -c dcutil -f -n "__fish_seen_subcommand_from podman" -a "init" -d "Initialize Podman backend"

# Rebuild options
complete -c dcutil -f -n "__fish_seen_subcommand_from rebuild" -l force -s f -d "Force rebuild without prompts"
complete -c dcutil -f -n "__fish_seen_subcommand_from rebuild" -l preserve-volumes -d "Preserve volumes during rebuild"
complete -c dcutil -f -n "__fish_seen_subcommand_from rebuild" -l preserve-ssh -d "Preserve SSH agent during rebuild"
complete -c dcutil -f -n "__fish_seen_subcommand_from rebuild" -l preserve-agents -d "Preserve authentication agents during rebuild"
complete -c dcutil -f -n "__fish_seen_subcommand_from rebuild" -l preserve-all -d "Preserve all state during rebuild"

# Up options
complete -c dcutil -f -n "__fish_seen_subcommand_from up" -l project-home -d "Set home folder to project directory"

# Run command completions
complete -c dcutil -f -n "__fish_seen_subcommand_from run; and not __fish_prev_arg_from $dcutil_projects" -a "(for i in */; if test -d "\$i" -a \( -f "\$i.devcontainer/devcontainer.json" -o -f "\$i.devcontainer.json" \); echo \$i; end; if test -f ".devcontainer/devcontainer.json" -o -f ".devcontainer.json"; echo "."; end)" -d "Project directory with devcontainer"
complete -c dcutil -f -n "__fish_seen_subcommand_from run; and __fish_prev_arg_from $dcutil_projects" -a "bash sh npm node python pip go make cmake cargo rustc" -d "Common commands to run in container"

# Helper function to find devcontainer projects
function __fish_dcutil_projects
    for i in */
        if test -d "$i" -a \( -f "$i.devcontainer/devcontainer.json" -o -f "$i.devcontainer.json" \)
            echo $i
        end
    end
    if test -f ".devcontainer/devcontainer.json" -o -f ".devcontainer.json"
        echo "."
    end
end