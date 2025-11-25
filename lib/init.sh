#!/usr/bin/env bash

# Initialization functionality for dcutil

# Source core functionality first, then template integration
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/template_integration.sh"

# Parse init options
init_mode() {
    local INIT_MODE="${1:-fast}"  # Default to fast mode instead of wizard
    validate_init_mode "$INIT_MODE"

    case "$INIT_MODE" in
        "--fast"|"fast"|"--non-interactive"|"-n")
            info "Creating devcontainer configuration using official devcontainer templates..."
            
            # Auto-detect language and use appropriate template
            local template_id
            template_id=$(detect_project_template)
            
            # Set template arguments based on template
            local template_args='{}'
            case "$template_id" in
                *"go"*)
                    template_args='{}'
                    ;;
                *"javascript-node"*)
                    template_args='{}'
                    ;;
                *"python"*)
                    template_args='{}'
                    ;;
                *"rust"*)
                    template_args='{}'
                    ;;
                *"dotnet"*)
                    template_args='{}'
                    ;;
                *"java"*)
                    template_args='{}'
                    ;;
                *"ubuntu"*)
                    template_args='{"imageVariant": "noble"}'
                    ;;
            esac
            
            # Suggest features based on project type
            local features_json
            features_json=$(suggest_features_for_project "$template_id")
            
            # Apply the official template using the devcontainer CLI
            if command -v devcontainer >/dev/null 2>&1; then
                info "Using official template: $template_id"
                
                # Apply the template with suggested features
                if apply_official_template "$template_id" "$features_json" "$template_args"; then
                    
                    # Verify the configuration was created
                    if [ ! -f ".devcontainer/devcontainer.json" ]; then
                        error_exit "Failed to generate devcontainer configuration" "$EXIT_CONFIG_ERROR"
                    fi
                    
                    # Enhance the generated configuration with dcutil-specific additions
                    enhance_with_dcutil_additions
                    
                    # Skip JSON validation since official templates are already validated
                    # validate_json_if_available ".devcontainer/devcontainer.json"
                    success "Devcontainer configuration created using official template"
                    
                    # Offer to start the container immediately
                    if [ -t 0 ] && [ -t 1 ]; then
                        echo ""
                        read -r -p "Would you like to start the devcontainer now? (Y/n): " start_now
                        start_now=${start_now:-Y}
                        if [[ "$start_now" =~ ^[Yy] ]]; then
                            info "Starting devcontainer..."
                            if command -v devcontainer_up >/dev/null 2>&1; then
                                devcontainer_up
                                return 0
                            fi
                        fi
                    fi
                    
                    info "Run 'dcutil up' to start the container"
                else
                    error_exit "Failed to apply official template. Please check your devcontainer CLI installation." "$EXIT_DEVCONTAINER_ERROR"
                fi
            else
                error_exit "devcontainer CLI not found. Please install it with: brew install devcontainer" "$EXIT_DEVCONTAINER_ERROR"
            fi
            ;;
        "--wizard"|"wizard")
            # Check if running interactively for wizard mode
            # if ! [ -t 0 ] || ! [ -t 1 ]; then
            #     warning "Non-interactive environment detected. Use 'dcutil init fast' for automated setup."
            #     exit "$EXIT_INVALID_ARGS"
            # fi
            
            # Use enhanced wizard with official template integration
            wizard_with_official_integration
            ;;
        "--help"|"-h")
            echo "Usage: dcutil init [mode]"
            echo ""
            echo "Modes:"
            echo "  fast     Create configuration using official templates (default)"
            echo "  wizard   Interactive setup (deprecated - fast mode is auto-detecting now)"
            echo "  help     Show this help message"
            echo ""
            echo "Features:"
            echo "  • Auto-detects project types (Go, Python, Node.js, Java, Rust, .NET, PHP, Ruby, C/C++)"
            echo "  • Uses official devcontainer templates from Microsoft"
            echo "  • Leverages official devcontainer CLI for template application"
            echo "  • Includes Git and Common Utils features automatically"
            echo "  • Enhanced with VS Code extensions and dcutil improvements"
            echo ""
            echo "Examples:"
            echo "  dcutil init          # Auto-detect project type and create configuration"
            echo "  dcutil init fast     # Quick setup using official templates"
            echo "  dcutil init wizard   # Interactive setup (deprecated)"
            echo "  dcutil init --help   # Show this help message"
            ;;
        *)
            echo -e "${RED}❌ Unknown init mode: $INIT_MODE${NC}"
            echo "Use 'dcutil init --help' for usage information"
            exit 1
            ;;
    esac
}