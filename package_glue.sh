#!/bin/bash
# scripts/package-for-glue.sh
# Package applications for AWS Glue deployment

set -e

APP_NAME=$1
if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    echo "Example: $0 app1"
    exit 1
fi

if [ ! -d "apps/$APP_NAME" ]; then
    echo "Error: Application 'apps/$APP_NAME' not found"
    exit 1
fi

echo "📦 Packaging $APP_NAME for AWS Glue..."

# Create package directory
PACKAGE_DIR="dist/glue-packages/$APP_NAME"
mkdir -p "$PACKAGE_DIR"

# Clean previous builds
rm -rf "$PACKAGE_DIR"/*

echo "🔄 Installing dependencies in isolated environment..."

# Create temporary directory for dependency extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Install the app and its dependencies to temporary directory
cd "apps/$APP_NAME"
uv export --format requirements-txt --no-dev > "$TEMP_DIR/requirements.txt"

# Install dependencies to temporary directory
pip install --target "$TEMP_DIR/site-packages" -r "$TEMP_DIR/requirements.txt" --no-deps

# Copy application files
echo "📋 Copying application files..."
cp -r "src/"* "../../$PACKAGE_DIR/"

# Copy dependencies (excluding standard library and AWS pre-installed packages)
echo "📚 Copying dependencies..."
if [ -d "$TEMP_DIR/site-packages" ]; then
    # Exclude AWS and standard packages that are pre-installed in Glue
    rsync -av --exclude='boto*' \
              --exclude='aws*' \
              --exclude='__pycache__' \
              --exclude='*.pyc' \
              --exclude='*.pyo' \
              --exclude='*.dist-info' \
              --exclude='*.egg-info' \
              "$TEMP_DIR/site-packages/" "../../$PACKAGE_DIR/"
fi

# Copy shared package files
echo "🔗 Copying shared package..."
if [ -d "../../packages/shared/src" ]; then
    cp -r ../../packages/shared/src/* "../../$PACKAGE_DIR/"
fi

cd "../.."

# Create zip file for Glue
echo "🗜️  Creating deployment package..."
cd "$PACKAGE_DIR"
zip -r "../${APP_NAME}-glue.zip" . -x "*.pyc" "*__pycache__*"
cd "../../.."

# Create requirements.txt for Glue job (for --additional-python-modules)
cd "apps/$APP_NAME"
uv export --format requirements-txt --no-dev | grep -v "^shared" > "../../dist/glue-packages/${APP_NAME}-requirements.txt" || true

echo "✅ Package created successfully!"
echo "📁 Deployment package: dist/glue-packages/${APP_NAME}-glue.zip"
echo "📄 Requirements file: dist/glue-packages/${APP_NAME}-requirements.txt"
echo ""
echo "🚀 Upload the zip file to S3 and use it as the --extra-py-files parameter in your Glue job"
