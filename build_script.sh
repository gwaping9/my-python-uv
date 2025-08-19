#!/bin/bash

# Generic build script for AWS Glue jobs
# Usage: ./build_app.sh APP_NAME [--clean] [--upload-s3 BUCKET_NAME] [--python-version VERSION]

set -e  # Exit on any error

# Check if app name is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: App name is required"
    echo "Usage: $0 APP_NAME [--clean] [--upload-s3 BUCKET_NAME] [--python-version VERSION]"
    echo "Available apps:"
    ls apps/ | grep -E "^[^.]" | sed 's/^/  - /'
    exit 1
fi

APP_NAME="$1"
shift

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/$APP_NAME"
BUILD_DIR="$ROOT_DIR/build/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "❌ Error: App '$APP_NAME' not found in apps directory"
    echo "Available apps:"
    ls apps/ | grep -E "^[^.]" | sed 's/^/  - /'
    exit 1
fi

# Parse command line arguments
CLEAN=false
UPLOAD_S3=""
PYTHON_VERSION="3.9"  # AWS Glue default
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --upload-s3)
            UPLOAD_S3="$2"
            shift 2
            ;;
        --python-version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 APP_NAME [--clean] [--upload-s3 BUCKET_NAME] [--python-version VERSION]"
            exit 1
            ;;
    esac
done

echo "🚀 Building $APP_NAME (Python $PYTHON_VERSION)..."

# Clean previous build if requested
if [ "$CLEAN" = true ]; then
    echo "🧹 Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    rm -rf "$DIST_DIR/$APP_NAME"*
fi

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ Error: uv is not installed. Please install it first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  Or: pip install uv"
    exit 1
fi

# Create a temporary virtual environment using uv
echo "📦 Setting up temporary environment with uv..."
TEMP_VENV="$BUILD_DIR/temp_venv"
uv venv "$TEMP_VENV" --python ${PYTHON_VERSION}
source "$TEMP_VENV/bin/activate"

# Install app dependencies using uv
echo "📦 Installing $APP_NAME dependencies..."
if [ -f "$APP_DIR/pyproject.toml" ]; then
    cd "$APP_DIR"
    uv pip install -e .
elif [ -f "$APP_DIR/requirements.txt" ]; then
    uv pip install -r "$APP_DIR/requirements.txt"
else
    echo "⚠️  Warning: No pyproject.toml or requirements.txt found for $APP_NAME"
fi

# Install shared libraries using uv
echo "📦 Installing shared libraries..."
for lib_dir in "$ROOT_DIR/libraries"/*; do
    if [ -d "$lib_dir" ] && [ -f "$lib_dir/pyproject.toml" ]; then
        lib_name=$(basename "$lib_dir")
        echo "  📚 Installing library: $lib_name"
        cd "$lib_dir"
        uv pip install -e .
    fi
done

# Create the deployment package
echo "📦 Creating deployment package..."
cd "$BUILD_DIR"

# Copy app source code
echo "📂 Copying app source code..."
if [ -d "$APP_DIR/src" ]; then
    cp -r "$APP_DIR/src"/* .
else
    echo "⚠️  Warning: No src directory found in $APP_DIR"
    cp -r "$APP_DIR"/*.py . 2>/dev/null || echo "⚠️  No Python files found in app root"
fi

# Copy shared libraries source code
echo "📂 Copying shared libraries..."
for lib_dir in "$ROOT_DIR/libraries"/*; do
    if [ -d "$lib_dir" ]; then
        lib_name=$(basename "$lib_dir")
        echo "  📚 Copying library: $lib_name"
        mkdir -p "$lib_name"
        if [ -d "$lib_dir/src" ]; then
            cp -r "$lib_dir/src"/* "$lib_name/"
        else
            cp -r "$lib_dir"/*.py "$lib_name/" 2>/dev/null || true
        fi
    fi
done

# Install third-party dependencies to lib directory using uv
echo "📦 Installing third-party dependencies..."
# Get only third-party packages (exclude local editable installs)
uv pip freeze | grep -v "^-e" > requirements_frozen.txt
if [ -s requirements_frozen.txt ]; then
    uv pip install --target lib -r requirements_frozen.txt
else
    echo "ℹ️  No third-party dependencies to install"
fi

# Create requirements file for Glue job reference
cp requirements_frozen.txt "$DIST_DIR/${APP_NAME}_requirements.txt"

# Create the final zip package
echo "📦 Creating zip package..."
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PACKAGE_NAME="${APP_NAME}_glue_job_${TIMESTAMP}.zip"
zip -r "$DIST_DIR/$PACKAGE_NAME" . -x "*.pyc" "*__pycache__*" "*.git*" "requirements_frozen.txt"

# Create a latest symlink
cd "$DIST_DIR"
ln -sf "$PACKAGE_NAME" "${APP_NAME}_glue_job_latest.zip"

# Cleanup
cd "$BUILD_DIR"
deactivate
rm -rf "$TEMP_VENV"

echo "✅ Build completed successfully!"
echo "📦 Package created: $DIST_DIR/$PACKAGE_NAME"
echo "🔗 Latest link: $DIST_DIR/${APP_NAME}_glue_job_latest.zip"
echo "📋 Requirements: $DIST_DIR/${APP_NAME}_requirements.txt"

# Upload to S3 if specified
if [ -n "$UPLOAD_S3" ]; then
    echo "☁️  Uploading to S3 bucket: $UPLOAD_S3"
    aws s3 cp "$DIST_DIR/$PACKAGE_NAME" "s3://$UPLOAD_S3/glue-jobs/$PACKAGE_NAME"
    aws s3 cp "$DIST_DIR/${APP_NAME}_glue_job_latest.zip" "s3://$UPLOAD_S3/glue-jobs/${APP_NAME}_glue_job_latest.zip"
    aws s3 cp "$DIST_DIR/${APP_NAME}_requirements.txt" "s3://$UPLOAD_S3/glue-jobs/${APP_NAME}_requirements.txt"
    echo "✅ Upload completed!"
    echo "📍 S3 location: s3://$UPLOAD_S3/glue-jobs/$PACKAGE_NAME"
fi

# Display package contents
echo ""
echo "📋 Package contents:"
unzip -l "$DIST_DIR/$PACKAGE_NAME" | head -20

echo ""
echo "🎉 $APP_NAME build process finished!"
