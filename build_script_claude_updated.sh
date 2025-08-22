#!/bin/bash

# AWS Glue Python Shell Build Script using UV
# Usage: ./build.sh <app_name> [clean]
# Example: ./build.sh app1
# Example: ./build.sh app2 clean

set -e  # Exit on any error

APP_NAME="$1"
CLEAN_FLAG="$2"

# Configuration
ROOT_DIR="$(pwd)"
APPS_DIR="$ROOT_DIR/apps"
LIBRARIES_DIR="$ROOT_DIR/libraries"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 <app_name> [clean]"
    echo ""
    echo "Available apps:"
    if [ -d "$APPS_DIR" ]; then
        for app in "$APPS_DIR"/*; do
            if [ -d "$app" ]; then
                echo "  - $(basename "$app")"
            fi
        done
    else
        echo "  No apps directory found"
    fi
    echo ""
    echo "Options:"
    echo "  clean    Clean build artifacts before building"
    echo ""
    echo "Examples:"
    echo "  $0 app1"
    echo "  $0 app2 clean"
    exit 1
}

# Function to clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR/$APP_NAME"
    rm -rf "$DIST_DIR/${APP_NAME}.zip"
    log_success "Build artifacts cleaned"
}

# Function to check if UV is installed
check_uv() {
    if ! command -v uv &> /dev/null; then
        log_error "UV is not installed or not in PATH"
        echo "Please install UV: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
    log_info "UV version: $(uv --version)"
}

# Function to validate app structure
validate_app() {
    local app_dir="$APPS_DIR/$APP_NAME"
    
    if [ ! -d "$app_dir" ]; then
        log_error "App '$APP_NAME' not found in $APPS_DIR"
        usage
    fi
    
    if [ ! -f "$app_dir/pyproject.toml" ]; then
        log_error "pyproject.toml not found in $app_dir"
        exit 1
    fi
    
    if [ ! -d "$app_dir/src" ]; then
        log_error "src directory not found in $app_dir"
        exit 1
    fi
    
    log_success "App structure validated"
}

# Function to create build directories
setup_build_dirs() {
    mkdir -p "$BUILD_DIR/$APP_NAME"
    mkdir -p "$DIST_DIR"
    log_success "Build directories created"
}

# Function to build core libraries
build_core_libraries() {
    log_info "Building core libraries..."
    
    local core_dir="$LIBRARIES_DIR/core"
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    
    if [ ! -d "$core_dir" ]; then
        log_warning "Core libraries directory not found, skipping..."
        return 0
    fi
    
    # Change to core directory
    cd "$core_dir"
    
    # Install core dependencies and build wheel
    log_info "Installing core library dependencies..."
    uv sync --no-dev
    
    # Build the core library wheel
    log_info "Building core library wheel..."
    uv build --wheel
    
    # Copy the built wheel to app build directory
    if [ -d "dist" ]; then
        cp dist/*.whl "$app_build_dir/"
        log_success "Core library wheel copied to build directory"
    else
        log_error "Core library build failed - no dist directory found"
        exit 1
    fi
    
    cd "$ROOT_DIR"
}

# Function to install app dependencies
install_app_dependencies() {
    log_info "Installing app dependencies for $APP_NAME..."
    
    local app_dir="$APPS_DIR/$APP_NAME"
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    
    # Change to app directory
    cd "$app_dir"
    
    # Create a virtual environment for dependency resolution
    log_info "Creating virtual environment for dependency resolution..."
    uv venv "$app_build_dir/venv"
    
    # Activate virtual environment and install dependencies
    source "$app_build_dir/venv/bin/activate"
    
    # Install the core library wheel if it exists
    if ls "$app_build_dir"/*.whl >/dev/null 2>&1; then
        log_info "Installing core library wheels..."
        uv pip install "$app_build_dir"/*.whl
    fi
    
    # Install app dependencies
    log_info "Installing app dependencies..."
    uv pip install -r <(uv export --no-hashes --no-dev)
    
    # Export installed packages to requirements file (for reference)
    uv pip freeze > "$app_build_dir/requirements.txt"
    
    deactivate
    cd "$ROOT_DIR"
    
    log_success "App dependencies installed"
}

# Function to copy app source code
copy_app_source() {
    log_info "Copying app source code..."
    
    local app_dir="$APPS_DIR/$APP_NAME"
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    
    # Copy app source code
    cp -r "$app_dir/src"/* "$app_build_dir/"
    
    log_success "App source code copied"
}

# Function to copy core library source (alternative to wheels)
copy_core_source() {
    log_info "Copying core library source..."
    
    local core_dir="$LIBRARIES_DIR/core"
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    
    if [ ! -d "$core_dir/src" ]; then
        log_warning "Core library source not found, skipping..."
        return 0
    fi
    
    # Copy core source to build directory
    cp -r "$core_dir/src"/* "$app_build_dir/"
    
    log_success "Core library source copied"
}

# Function to package third-party dependencies
package_dependencies() {
    log_info "Packaging third-party dependencies (including transitive)..."
    
    local app_dir="$APPS_DIR/$APP_NAME"
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    local venv_dir="$app_build_dir/venv"
    
    # Change to app directory for dependency resolution
    cd "$app_dir"
    
    # Use UV to get complete dependency tree (including transitive dependencies)
    log_info "Resolving complete dependency tree with UV..."
    
    # Create a comprehensive requirements file with all resolved dependencies
    # This includes transitive dependencies that UV automatically resolves
    uv export --no-hashes --no-dev --format requirements-txt > "$app_build_dir/all_requirements.txt"
    
    # Show dependency count for verification
    local dep_count=$(grep -c "^[^#]" "$app_build_dir/all_requirements.txt" || echo "0")
    log_info "Found $dep_count total dependencies (including transitive)"
    
    # Use the existing virtual environment to get site-packages
    if [ -d "$venv_dir" ]; then
        log_info "Copying packages from virtual environment (ensures all transitive deps)..."
        
        # Find the site-packages directory
        local site_packages=$(find "$venv_dir" -name "site-packages" -type d | head -1)
        
        if [ -n "$site_packages" ] && [ -d "$site_packages" ]; then
            # Copy all installed packages except pip, setuptools, wheel, and distutils
            cd "$site_packages"
            
            for package in */; do
                package_name=$(basename "$package")
                
                # Skip standard library and build tools
                if [[ ! "$package_name" =~ ^(pip|setuptools|wheel|distutils|_distutils_hack|__pycache__|.*\.dist-info|.*\.egg-info)$ ]]; then
                    log_info "Including package: $package_name"
                    cp -r "$package" "$app_build_dir/" 2>/dev/null || {
                        log_warning "Failed to copy $package_name, but continuing..."
                    }
                fi
            done
            
            # Also copy any .pth files that might be needed
            find . -name "*.pth" -exec cp {} "$app_build_dir/" \; 2>/dev/null || true
            
        else
            log_error "Could not find site-packages directory in virtual environment"
            exit 1
        fi
    else
        log_error "Virtual environment not found - dependency installation may have failed"
        exit 1
    fi
    
    cd "$ROOT_DIR"
    
    log_success "All dependencies (including transitive) packaged successfully"
    
    # Create a dependency manifest for debugging
    create_dependency_manifest
}

# Function to create a dependency manifest for verification
create_dependency_manifest() {
    log_info "Creating dependency manifest..."
    
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    local manifest_file="$app_build_dir/dependency_manifest.txt"
    
    {
        echo "# Dependency Manifest for $APP_NAME"
        echo "# Generated on $(date)"
        echo "# This file lists all included packages for verification"
        echo ""
        
        echo "## Direct Dependencies (from pyproject.toml):"
        if [ -f "$APPS_DIR/$APP_NAME/pyproject.toml" ]; then
            grep -A 20 "\[project.dependencies\]" "$APPS_DIR/$APP_NAME/pyproject.toml" | grep -E "^\s*\"" || echo "No dependencies found in pyproject.toml"
        fi
        
        echo ""
        echo "## All Resolved Dependencies (including transitive):"
        if [ -f "$app_build_dir/all_requirements.txt" ]; then
            cat "$app_build_dir/all_requirements.txt"
        fi
        
        echo ""
        echo "## Packaged Python Modules:"
        find "$app_build_dir" -maxdepth 1 -type d -not -name "venv" -not -name "." | sort
        
        echo ""
        echo "## Package Sizes:"
        find "$app_build_dir" -maxdepth 1 -type d -not -name "venv" -not -name "." -exec du -sh {} \; | sort -hr
        
    } > "$manifest_file"
    
    log_success "Dependency manifest created: $manifest_file"
}

# Function to create deployment package
create_deployment_package() {
    log_info "Creating deployment package..."
    
    local app_build_dir="$BUILD_DIR/$APP_NAME"
    local zip_file="$DIST_DIR/${APP_NAME}.zip"
    
    cd "$app_build_dir"
    
    # Create zip file with all contents
    zip -r "$zip_file" . -x "venv/*" "*.whl" "requirements.txt"
    
    cd "$ROOT_DIR"
    
    # Get zip file size
    local zip_size=$(du -h "$zip_file" | cut -f1)
    
    log_success "Deployment package created: $zip_file (Size: $zip_size)"
    
    # AWS Glue Python Shell size limit warning
    local size_bytes=$(stat -c%s "$zip_file")
    local size_mb=$((size_bytes / 1024 / 1024))
    
    if [ $size_mb -gt 100 ]; then
        log_warning "Package size ($size_mb MB) exceeds AWS Glue Python Shell limit (100 MB)"
        log_warning "Consider reducing dependencies or using AWS Glue ETL instead"
    fi
}

# Function to display build summary
build_summary() {
    log_info "Build Summary for $APP_NAME:"
    echo "  Build Directory: $BUILD_DIR/$APP_NAME"
    echo "  Package: $DIST_DIR/${APP_NAME}.zip"
    echo "  Package Size: $(du -h "$DIST_DIR/${APP_NAME}.zip" | cut -f1)"
    
    # Show dependency count from manifest
    if [ -f "$BUILD_DIR/$APP_NAME/all_requirements.txt" ]; then
        local total_deps=$(grep -c "^[^#]" "$BUILD_DIR/$APP_NAME/all_requirements.txt" || echo "0")
        echo "  Total Dependencies: $total_deps (including transitive)"
    fi
    
    echo "  Dependency Manifest: $BUILD_DIR/$APP_NAME/dependency_manifest.txt"
    echo ""
    echo "AWS Glue Deployment Instructions:"
    echo "1. Upload $DIST_DIR/${APP_NAME}.zip to S3"
    echo "2. Create/Update AWS Glue Job with:"
    echo "   - Job Type: Python Shell"
    echo "   - Python Library Path: s3://your-bucket/${APP_NAME}.zip"
    echo "   - Script Location: s3://your-bucket/${APP_NAME}.py (main script)"
    echo ""
}

# Main execution
main() {
    log_info "Starting AWS Glue build process for $APP_NAME"
    
    # Validate inputs
    if [ -z "$APP_NAME" ]; then
        usage
    fi
    
    # Clean if requested
    if [ "$CLEAN_FLAG" = "clean" ]; then
        clean_build
    fi
    
    # Execute build steps
    check_uv
    validate_app
    setup_build_dirs
    build_core_libraries
    copy_core_source
    copy_app_source
    package_dependencies
    create_deployment_package
    build_summary
    
    log_success "Build completed successfully for $APP_NAME!"
}

# Run main function
main "$@"
