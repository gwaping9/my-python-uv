#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MODE="local"
APP=""
CLEAN=false
VERBOSE=false

# Directories
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$ROOT_DIR/apps"
LIBS_DIR="$ROOT_DIR/libraries"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build script for Python monorepo with UV package manager

OPTIONS:
    -m, --mode MODE         Build mode: 'local' or 'glue' (default: local)
    -a, --app APP          Specific app to build (e.g., app1, app2)
    -c, --clean            Clean build directories before building
    -v, --verbose          Enable verbose output
    -h, --help             Show this help message

MODES:
    local                  Install dependencies for local development
    glue                   Package applications for AWS Glue deployment

EXAMPLES:
    $0 --mode local                    # Install all dependencies locally
    $0 --mode local --app app1         # Install dependencies for app1 only
    $0 --mode glue --app app1          # Package app1 for AWS Glue
    $0 --mode glue --clean             # Clean and package all apps for Glue
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -a|--app)
                APP="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate mode
    if [[ "$MODE" != "local" && "$MODE" != "glue" ]]; then
        print_error "Invalid mode: $MODE. Must be 'local' or 'glue'"
        exit 1
    fi
}

# Function to check if UV is installed
check_uv() {
    if ! command -v uv &> /dev/null; then
        print_error "UV is not installed. Please install UV first:"
        echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    print_status "Using UV version: $(uv --version)"
}

# Function to clean build directories
clean_build() {
    if [[ "$CLEAN" == true ]]; then
        print_status "Cleaning build directories..."
        rm -rf "$BUILD_DIR" "$DIST_DIR"
        find "$ROOT_DIR" -name "*.pyc" -delete
        find "$ROOT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find "$ROOT_DIR" -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
        print_success "Build directories cleaned"
    fi
}

# Function to get all apps or specified app
get_apps() {
    if [[ -n "$APP" ]]; then
        if [[ ! -d "$APPS_DIR/$APP" ]]; then
            print_error "App '$APP' not found in $APPS_DIR"
            exit 1
        fi
        echo "$APP"
    else
        find "$APPS_DIR" -maxdepth 1 -type d -not -path "$APPS_DIR" -exec basename {} \;
    fi
}

# Function to sync libraries for local development
sync_libraries() {
    print_status "Syncing libraries for local development..."
    
    for lib_dir in "$LIBS_DIR"/*; do
        if [[ -d "$lib_dir" && -f "$lib_dir/pyproject.toml" ]]; then
            lib_name=$(basename "$lib_dir")
            print_status "Syncing library: $lib_name"
            
            cd "$lib_dir"
            
            if [[ "$VERBOSE" == true ]]; then
                uv sync --dev
            else
                uv sync --dev --quiet
            fi
            
            print_success "Library $lib_name synced"
        fi
    done
}

# Function to sync apps for local development
sync_apps() {
    print_status "Syncing applications for local development..."
    
    local apps
    apps=$(get_apps)
    
    for app in $apps; do
        app_dir="$APPS_DIR/$app"
        print_status "Syncing app: $app"
        
        cd "$app_dir"
        
        if [[ "$VERBOSE" == true ]]; then
            uv sync --dev
        else
            uv sync --dev --quiet
        fi
        
        print_success "App $app synced"
    done
}

# Function to build library wheels
build_library_wheels() {
    print_status "Building library wheels..."
    mkdir -p "$BUILD_DIR/wheels"
    
    for lib_dir in "$LIBS_DIR"/*; do
        if [[ -d "$lib_dir" && -f "$lib_dir/pyproject.toml" ]]; then
            lib_name=$(basename "$lib_dir")
            print_status "Building wheel for library: $lib_name"
            
            cd "$lib_dir"
            
            if [[ "$VERBOSE" == true ]]; then
                uv build --out-dir "$BUILD_DIR/wheels"
            else
                uv build --out-dir "$BUILD_DIR/wheels" --quiet
            fi
            
            print_success "Library $lib_name wheel built"
        fi
    done
}

# Function to export dependencies for Glue
export_dependencies() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    local deps_file="$BUILD_DIR/$app_name/requirements.txt"
    
    print_status "Exporting dependencies for $app_name..."
    mkdir -p "$(dirname "$deps_file")"
    
    cd "$app_dir"
    
    # Export production dependencies only (no dev dependencies)
    if [[ "$VERBOSE" == true ]]; then
        uv export --no-dev --format requirements-txt --output-file "$deps_file"
    else
        uv export --no-dev --format requirements-txt --output-file "$deps_file" --quiet
    fi
    
    print_success "Dependencies exported to $deps_file"
}

# Function to package app for Glue deployment
package_app_for_glue() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    local package_dir="$BUILD_DIR/$app_name"
    local final_package="$DIST_DIR/$app_name-glue.zip"
    
    print_status "Packaging $app_name for AWS Glue..."
    
    mkdir -p "$package_dir" "$DIST_DIR"
    
    # Copy application source code
    print_status "Copying application source code..."
    cp -r "$app_dir/src/"* "$package_dir/"
    
    # Install dependencies to package directory
    print_status "Installing dependencies..."
    cd "$app_dir"
    
    if [[ "$VERBOSE" == true ]]; then
        uv export --no-dev --format requirements-txt | uv pip install --target "$package_dir" -r -
    else
        uv export --no-dev --format requirements-txt | uv pip install --target "$package_dir" -r - --quiet
    fi
    
    # Install local library dependencies
    print_status "Installing local library wheels..."
    if ls "$BUILD_DIR/wheels"/*.whl 1> /dev/null 2>&1; then
        uv pip install --target "$package_dir" "$BUILD_DIR/wheels"/*.whl --quiet
    fi
    
    # Create the deployment package
    print_status "Creating deployment package..."
    cd "$package_dir"
    zip -r "$final_package" . -x "*.pyc" "*__pycache__*" "*.egg-info*" > /dev/null
    
    print_success "Package created: $final_package"
    print_status "Package size: $(du -h "$final_package" | cut -f1)"
}

# Function for local development setup
setup_local() {
    print_status "Setting up local development environment..."
    
    # Sync libraries first (dependencies for apps)
    sync_libraries
    
    # Sync applications
    sync_apps
    
    print_success "Local development environment ready!"
    print_status "You can now run applications using: cd apps/<app_name> && uv run python src/<app_name>.py"
}

# Function for Glue deployment packaging
package_for_glue() {
    print_status "Packaging applications for AWS Glue deployment..."
    
    # Build library wheels first
    build_library_wheels
    
    local apps
    apps=$(get_apps)
    
    for app in $apps; do
        export_dependencies "$app"
        package_app_for_glue "$app"
    done
    
    print_success "All applications packaged for AWS Glue!"
    print_status "Deployment packages available in: $DIST_DIR"
}

# Main execution function
main() {
    parse_args "$@"
    
    print_status "Starting build process..."
    print_status "Mode: $MODE"
    if [[ -n "$APP" ]]; then
        print_status "Target app: $APP"
    else
        print_status "Target: All applications"
    fi
    
    check_uv
    clean_build
    
    case "$MODE" in
        local)
            setup_local
            ;;
        glue)
            package_for_glue
            ;;
    esac
    
    print_success "Build process completed successfully!"
}

# Run main function with all arguments
main "$@"
