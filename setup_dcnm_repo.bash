#!/usr/bin/env bash
#
# Setup script for DCNM Ansible Collection using uv
# This script installs and configures the DCNM Ansible Collection with uv package manager
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ============================================================================
# Configuration Variables (can be overridden via environment)
# ============================================================================
PYTHON_VERSION=${DCNM_PYTHON_VERSION:-3.11}
REPOS_HOME=${DCNM_REPOS_HOME:-$HOME/repos}
ANSIBLE_HOME=${DCNM_ANSIBLE_HOME:-$REPOS_HOME/ansible}
ANSIBLE_COLLECTIONS_PATH=$ANSIBLE_HOME/collections
REPO_DCNM=$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cisco/dcnm
REPO_NETCOMMON=$ANSIBLE_COLLECTIONS_PATH/ansible_collections/ansible/netcommon
REPO_SETUP=$REPOS_HOME/ansible-dcnm-setup

# Repository URLs
NETCOMMON_REPO="https://github.com/ansible-collections/ansible.netcommon.git"
DCNM_REPO="https://github.com/CiscoDevNet/ansible-dcnm.git"

# Script options
DRY_RUN=${DRY_RUN:-false}
SKIP_CLONE=${SKIP_CLONE:-false}
SKIP_UV_INSTALL=${SKIP_UV_INSTALL:-false}
SKIP_PYTHON_INSTALL=${SKIP_PYTHON_INSTALL:-false}
SKIP_VENV=${SKIP_VENV:-false}
SKIP_DEPS=${SKIP_DEPS:-false}
VERBOSE=${VERBOSE:-false}

# ============================================================================
# Logging Functions
# ============================================================================
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

log_step() {
    echo -e "\n\033[1;36m==>\033[0m \033[1m$*\033[0m"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "\033[0;90m[DEBUG]\033[0m $*"
    fi
}

run_command() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would execute: $*"
        return 0
    else
        log_verbose "Executing: $*"
        "$@"
    fi
}

# ============================================================================
# Cleanup and Error Handling
# ============================================================================
cleanup_on_error() {
    local exit_code=$?
    log_error "Setup failed with exit code $exit_code"
    log_info "You may need to manually clean up partial installation"
    exit $exit_code
}

trap cleanup_on_error ERR

# ============================================================================
# Validation Functions
# ============================================================================
check_prerequisites() {
    log_step "Checking prerequisites"

    # Check for active virtual environment
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        log_error "Please deactivate the current virtual environment before running this script."
        log_info "Run: deactivate"
        exit 1
    fi
    log_success "No active virtual environment detected"

    # Check for git
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git first."
        exit 1
    fi
    log_success "git is available"

    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl first."
        exit 1
    fi
    log_success "curl is available"

    # Check if setup repository exists
    if [ ! -d "$REPO_SETUP" ]; then
        log_warn "Setup repository not found at $REPO_SETUP"
        log_info "Looking for dcnm/pyproject.toml in current directory..."
        if [ -f "./dcnm/pyproject.toml" ]; then
            REPO_SETUP=$(pwd)
            log_success "Using current directory as setup repository"
        else
            log_error "Cannot find dcnm/pyproject.toml. Please run from ansible-dcnm-setup directory."
            exit 1
        fi
    fi
}

validate_uv_installed() {
    if ! command -v uv &> /dev/null; then
        log_error "uv not found in PATH after installation"
        log_info "Try sourcing: source \$HOME/.local/bin/env"
        return 1
    fi
    log_success "uv is available: $(uv --version)"
    return 0
}

validate_python_version() {
    local required_version=$1
    if ! uv python list | grep -q "$required_version"; then
        log_warn "Python $required_version not found in uv python list"
        return 1
    fi
    log_success "Python $required_version is available"
    return 0
}

# ============================================================================
# Setup Functions
# ============================================================================
setup_environment_variables() {
    log_step "Setting up environment variables"

    log_verbose "PYTHON_VERSION=$PYTHON_VERSION"
    log_verbose "REPOS_HOME=$REPOS_HOME"
    log_verbose "ANSIBLE_HOME=$ANSIBLE_HOME"
    log_verbose "ANSIBLE_COLLECTIONS_PATH=$ANSIBLE_COLLECTIONS_PATH"
    log_verbose "REPO_DCNM=$REPO_DCNM"
    log_verbose "REPO_NETCOMMON=$REPO_NETCOMMON"
    log_verbose "REPO_SETUP=$REPO_SETUP"

    log_success "Environment variables configured"
}

create_directory_structure() {
    log_step "Creating directory structure"

    local dirs=(
        "$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cisco"
        "$ANSIBLE_COLLECTIONS_PATH/ansible_collections/ansible"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Directory already exists: $dir"
        else
            run_command mkdir -p "$dir"
            log_success "Created directory: $dir"
        fi
    done
}

clone_netcommon_collection() {
    if [ "$SKIP_CLONE" = true ]; then
        log_info "Skipping netcommon clone (SKIP_CLONE=true)"
        return 0
    fi

    log_step "Setting up ansible.netcommon collection"

    if [ -d "$REPO_NETCOMMON/.git" ]; then
        log_info "netcommon repository already exists"
        if [ "$DRY_RUN" = false ]; then
            cd "$REPO_NETCOMMON"
            log_info "Pulling latest changes..."
            git pull || log_warn "Failed to pull latest changes, continuing with existing version"
        fi
    else
        log_info "Cloning ansible.netcommon into $REPO_NETCOMMON..."
        if [ "$DRY_RUN" = false ]; then
            cd "$ANSIBLE_COLLECTIONS_PATH/ansible_collections/ansible"
        fi
        run_command git clone "$NETCOMMON_REPO" netcommon
        log_success "Cloned ansible.netcommon"
    fi
}

clone_dcnm_collection() {
    if [ "$SKIP_CLONE" = true ]; then
        log_info "Skipping DCNM clone (SKIP_CLONE=true)"
        return 0
    fi

    log_step "Setting up ansible-dcnm collection"

    if [ -d "$REPO_DCNM/.git" ]; then
        log_info "DCNM repository already exists"
        if [ "$DRY_RUN" = false ]; then
            cd "$REPO_DCNM"
            log_info "Pulling latest changes..."
            git pull || log_warn "Failed to pull latest changes, continuing with existing version"
        fi
    else
        log_info "Cloning ansible-dcnm into $REPO_DCNM..."
        if [ "$DRY_RUN" = false ]; then
            cd "$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cisco"
        fi
        run_command git clone "$DCNM_REPO" dcnm
        log_success "Cloned ansible-dcnm"
    fi
}

copy_configuration_files() {
    log_step "Copying configuration files to DCNM repository"

    # Ensure target directories exist
    run_command mkdir -p "$REPO_DCNM/env"

    # Copy pyproject.toml
    local source_pyproject="$REPO_SETUP/dcnm/pyproject.toml"
    local target_pyproject="$REPO_DCNM/pyproject.toml"

    if [ ! -f "$source_pyproject" ]; then
        log_error "Source file not found: $source_pyproject"
        exit 1
    fi

    if [ -f "$target_pyproject" ]; then
        log_info "pyproject.toml already exists, overwriting..."
    fi
    run_command cp "$source_pyproject" "$target_pyproject"
    log_success "Copied pyproject.toml"

    # Copy env file
    local source_env="$REPO_SETUP/dcnm/env"
    local target_env="$REPO_DCNM/env/env"

    if [ ! -f "$source_env" ]; then
        log_error "Source file not found: $source_env"
        exit 1
    fi

    if [ -f "$target_env" ]; then
        log_info "env file already exists, overwriting..."
    fi
    run_command cp "$source_env" "$target_env"
    log_success "Copied env file"
}

install_uv() {
    if [ "$SKIP_UV_INSTALL" = true ]; then
        log_info "Skipping uv installation (SKIP_UV_INSTALL=true)"
        return 0
    fi

    log_step "Installing uv package manager"

    if command -v uv &> /dev/null; then
        local uv_version=$(uv --version)
        log_info "uv is already installed: $uv_version"
        log_info "To upgrade, run: curl -LsSf https://astral.sh/uv/install.sh | sh"
    else
        log_info "Downloading and installing uv..."
        if [ "$DRY_RUN" = false ]; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
            # Source the env file to make uv available
            if [ -f "$HOME/.local/bin/env" ]; then
                source "$HOME/.local/bin/env"
            fi
        else
            log_info "[DRY-RUN] Would execute: curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi
    fi

    # Validate installation
    if [ "$DRY_RUN" = false ]; then
        # Try sourcing env if uv not in path
        if ! command -v uv &> /dev/null; then
            if [ -f "$HOME/.local/bin/env" ]; then
                source "$HOME/.local/bin/env"
            fi
        fi
        validate_uv_installed || exit 1
    fi
}

install_python() {
    if [ "$SKIP_PYTHON_INSTALL" = true ]; then
        log_info "Skipping Python installation (SKIP_PYTHON_INSTALL=true)"
        return 0
    fi

    log_step "Installing Python $PYTHON_VERSION via uv"

    if [ "$DRY_RUN" = false ]; then
        if validate_python_version "$PYTHON_VERSION" 2>/dev/null; then
            log_info "Python $PYTHON_VERSION already installed"
        else
            run_command uv python install "$PYTHON_VERSION"
            log_success "Installed Python $PYTHON_VERSION"
        fi
    else
        run_command uv python install "$PYTHON_VERSION"
    fi
}

create_virtual_environment() {
    if [ "$SKIP_VENV" = true ]; then
        log_info "Skipping virtual environment creation (SKIP_VENV=true)"
        return 0
    fi

    log_step "Creating virtual environment in DCNM repository"

    if [ "$DRY_RUN" = false ]; then
        cd "$REPO_DCNM"
    fi

    if [ -d "$REPO_DCNM/.venv" ]; then
        log_info "Virtual environment already exists at $REPO_DCNM/.venv"
        log_warn "To recreate, delete .venv directory and run again"
    else
        run_command uv venv .venv --python "$PYTHON_VERSION" --prompt dcnm
        log_success "Created virtual environment"
    fi
}

install_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping dependency installation (SKIP_DEPS=true)"
        return 0
    fi

    log_step "Installing base dependencies"

    if [ "$DRY_RUN" = false ]; then
        cd "$REPO_DCNM"
    fi

    log_info "Installing base runtime dependencies (excluding dev and test groups)..."
    run_command uv sync --no-group dev --no-group test
    log_success "Base dependencies installed"

    log_info ""
    log_info "To install additional dependencies:"
    log_info "  Test dependencies:  uv sync --group test"
    log_info "  Dev dependencies:   uv sync --group dev"
    log_info "  All dependencies:   uv sync --all-groups"
}

show_completion_message() {
    log_step "Setup Complete!"

    echo ""
    log_success "DCNM Ansible Collection is ready to use"
    echo ""
    echo "To start working with the collection:"
    echo ""
    echo "cd $REPO_DCNM"
    echo "source .venv/bin/activate"
    echo "source env/env"
    echo ""
    echo " To install additional dependencies, run one or more of the following:"
    echo ""
    echo "uv sync --group test"
    echo "uv sync --group dev"
    echo "uv sync --all-groups"
    echo ""
    echo "Example - Run unit tests:"
    echo ""
    echo "  cd tests/unit/modules/dcnm"
    echo "  pytest -k dcnm_fabric"
    echo ""
    echo "Happy automating!"
}

# ============================================================================
# Help and Usage
# ============================================================================
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup script for DCNM Ansible Collection using uv package manager.

OPTIONS:
    --dry-run               Show what would be done without executing
    --skip-clone            Skip cloning repositories
    --skip-uv-install       Skip installing uv
    --skip-python-install   Skip installing Python
    --skip-venv             Skip creating virtual environment
    --skip-deps             Skip installing dependencies
    --verbose               Enable verbose output
    -h, --help              Show this help message

ENVIRONMENT VARIABLES:
    DCNM_PYTHON_VERSION     Python version to install (default: 3.11)
    DCNM_REPOS_HOME         Base directory for repositories (default: \$HOME/repos)
    DCNM_ANSIBLE_HOME       Ansible directory (default: \$DCNM_REPOS_HOME/ansible)

EXAMPLES:
    # Normal installation
    $0

    # Dry run to see what would happen
    $0 --dry-run

    # Skip cloning if repositories already exist
    $0 --skip-clone

    # Only install dependencies (assumes everything else is setup)
    $0 --skip-clone --skip-uv-install --skip-python-install --skip-venv

    # Use custom Python version
    DCNM_PYTHON_VERSION=3.12 $0

    # Verbose output
    $0 --verbose

EOF
}

# ============================================================================
# Command Line Argument Parsing
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --skip-uv-install)
                SKIP_UV_INSTALL=true
                shift
                ;;
            --skip-python-install)
                SKIP_PYTHON_INSTALL=true
                shift
                ;;
            --skip-venv)
                SKIP_VENV=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Main Function
# ============================================================================
main() {
    parse_arguments "$@"

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    log_info "DCNM Ansible Collection Setup"
    log_info "=============================="

    check_prerequisites
    setup_environment_variables
    create_directory_structure
    clone_netcommon_collection
    clone_dcnm_collection
    copy_configuration_files
    install_uv
    install_python
    create_virtual_environment
    install_dependencies
    show_completion_message
}

# ============================================================================
# Script Entry Point
# ============================================================================
main "$@"
