#!/bin/bash

# This script fixes the Glue deployment approach to properly handle entry points

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status "AWS Glue Entry Point Configuration Guide"
print_status "========================================"

cat << 'EOF'

ISSUE: AWS Glue jobs need to know which script to execute as the entry point.

SOLUTIONS: There are 3 approaches for AWS Glue deployment:

1. PYTHON SHELL JOBS (Recommended for simple scripts)
   - ScriptLocation: Points to your main .py file 
   - --extra-py-files: Points to your dependencies ZIP
   - Entry point: The main .py file itself

2. SPARK ETL JOBS (For Spark-based processing)
   - ScriptLocation: Points to your main .py file
   - --extra-py-files: Points to your dependencies ZIP  
   - Entry point: The main .py file itself

3. SINGLE EXECUTABLE (All-in-one approach)
   - Create a launcher script that imports and runs your app
   - Package everything into one structure

Let me create the proper deployment structure for you...

EOF

# Create improved build script modifications
print_status "Creating improved Glue packaging..."

cat > "$ROOT_DIR/build-glue-improved.sh" << 'EOF'
#!/bin/bash

# Improved Glue packaging that separates scripts from dependencies

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$ROOT_DIR/apps"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"

package_app_for_glue_improved() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    local build_app_dir="$BUILD_DIR/$app_name"
    
    echo "Packaging $app_name with proper Glue structure..."
    
    mkdir -p "$build_app_dir" "$DIST_DIR"
    
    # 1. Create the main script (entry point)
    echo "Creating main script..."
    local main_script="$DIST_DIR/${app_name}.py"
    cat > "$main_script" << MAIN_SCRIPT
#!/usr/bin/env python3
"""
AWS Glue Job Entry Point for $app_name
Generated automatically - DO NOT EDIT manually
"""

import sys
import os
import zipfile
import tempfile
import shutil

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def setup_dependencies():
    """Extract and setup dependencies from the ZIP file"""
    # Look for the dependencies ZIP file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dep_zip = os.path.join(script_dir, '${app_name}-deps.zip')
    
    if os.path.exists(dep_zip):
        # Create temporary directory for dependencies
        temp_dir = tempfile.mkdtemp(prefix='glue_deps_')
        
        # Extract dependencies
        with zipfile.ZipFile(dep_zip, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
        
        # Add to Python path
        sys.path.insert(0, temp_dir)
        
        # Store for cleanup
        global _temp_dep_dir
        _temp_dep_dir = temp_dir
    else:
        print(f"Warning: Dependencies ZIP not found at {dep_zip}")

def cleanup_dependencies():
    """Clean up temporary dependencies"""
    global _temp_dep_dir
    if '_temp_dep_dir' in globals() and os.path.exists(_temp_dep_dir):
        shutil.rmtree(_temp_dep_dir)

def main():
    """Main entry point for the Glue job"""
    try:
        # Setup dependencies
        setup_dependencies()
        
        # Import the actual application
        from src.${app_name} import main as app_main
        
        # Run the application
        app_main()
        
    except Exception as e:
        print(f"Error in Glue job: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        # Cleanup
        cleanup_dependencies()

if __name__ == "__main__":
    main()
MAIN_SCRIPT
    
    echo "Main script created: $main_script"
    
    # 2. Create dependencies ZIP (without the main application code)
    echo "Creating dependencies package..."
    local deps_dir="$build_app_dir/deps"
    mkdir -p "$deps_dir"
    
    # Install dependencies to deps directory
    cd "$app_dir"
    uv export --no-dev --format requirements-txt | uv pip install --target "$deps_dir" -r - --quiet
    
    # Install local library dependencies
    if ls "$BUILD_DIR/wheels"/*.whl 1> /dev/null 2>&1; then
        uv pip install --target "$deps_dir" "$BUILD_DIR/wheels"/*.whl --quiet
    fi
    
    # Copy application source code to deps
    cp -r "$app_dir/src" "$deps_dir/"
    
    # Create dependencies ZIP
    local deps_zip="$DIST_DIR/${app_name}-deps.zip"
    cd "$deps_dir"
    zip -r "$deps_zip" . -x "*.pyc" "*__pycache__*" "*.egg-info*" > /dev/null
    
    echo "Dependencies ZIP created: $deps_zip"
    
    # 3. Create alternative: Single executable approach
    echo "Creating single executable package..."
    local single_dir="$build_app_dir/single"
    mkdir -p "$single_dir"
    
    # Copy all dependencies and app code
    cp -r "$deps_dir"/* "$single_dir/"
    
    # Create launcher script
    cat > "$single_dir/${app_name}_launcher.py" << LAUNCHER
#!/usr/bin/env python3
"""
Single executable launcher for $app_name
"""
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def main():
    """Main entry point"""
    try:
        from src.${app_name} import main as app_main
        app_main()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
LAUNCHER
    
    # Create single executable ZIP
    local single_zip="$DIST_DIR/${app_name}-single.zip"
    cd "$single_dir"
    zip -r "$single_zip" . -x "*.pyc" "*__pycache__*" "*.egg-info*" > /dev/null
    
    echo "Single executable created: $single_zip"
    
    # 4. Create deployment info
    cat > "$DIST_DIR/${app_name}-deployment-info.txt" << INFO
Deployment Information for $app_name
===================================

Created Files:
1. ${app_name}.py - Main script (entry point)
2. ${app_name}-deps.zip - Dependencies package  
3. ${app_name}-single.zip - Single executable package

Deployment Options:

OPTION 1: Python Shell with Separate Dependencies (Recommended)
- Upload both ${app_name}.py and ${app_name}-deps.zip to S3
- ScriptLocation: s3://your-bucket/path/${app_name}.py
- --extra-py-files: s3://your-bucket/path/${app_name}-deps.zip

OPTION 2: Single Executable Package
- Upload ${app_name}-single.zip to S3, extract it
- Upload ${app_name}_launcher.py as main script
- ScriptLocation: s3://your-bucket/path/${app_name}_launcher.py
- --extra-py-files: s3://your-bucket/path/ (directory with extracted files)

AWS CLI Commands:

# Option 1 - Python Shell Job
aws glue create-job \\
    --name "$app_name" \\
    --role "arn:aws:iam::YOUR_ACCOUNT:role/GlueServiceRole" \\
    --command '{
        "Name": "pythonshell",
        "ScriptLocation": "s3://YOUR_BUCKET/${app_name}.py",
        "PythonVersion": "3.9"
    }' \\
    --default-arguments '{
        "--extra-py-files": "s3://YOUR_BUCKET/${app_name}-deps.zip"
    }' \\
    --max-capacity 0.0625

# Option 2 - Spark ETL Job (if you need Spark)
aws glue create-job \\
    --name "${app_name}-spark" \\
    --role "arn:aws:iam::YOUR_ACCOUNT:role/GlueServiceRole" \\
    --command '{
        "Name": "glueetl", 
        "ScriptLocation": "s3://YOUR_BUCKET/${app_name}.py",
        "PythonVersion": "3"
    }' \\
    --default-arguments '{
        "--extra-py-files": "s3://YOUR_BUCKET/${app_name}-deps.zip"
    }' \\
    --glue-version "4.0" \\
    --number-of-workers 2 \\
    --worker-type "G.1X"

INFO
    
    echo "Deployment info created: $DIST_DIR/${app_name}-deployment-info.txt"
    
    cd "$ROOT_DIR"
    echo "✓ Improved Glue packaging completed for $app_name"
}

# Main execution
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <app_name>"
    echo "Example: $0 app1"
    exit 1
fi

APP_NAME="$1"

if [[ ! -d "$APPS_DIR/$APP_NAME" ]]; then
    echo "Error: App '$APP_NAME' not found in $APPS_DIR"
    exit 1
fi

# Build library wheels first
echo "Building library wheels..."
mkdir -p "$BUILD_DIR/wheels"
for lib_dir in "$ROOT_DIR/libraries"/*; do
    if [[ -d "$lib_dir" && -f "$lib_dir/pyproject.toml" ]]; then
        cd "$lib_dir"
        uv build --out-dir "$BUILD_DIR/wheels" --quiet
    fi
done

# Package the app
package_app_for_glue_improved "$APP_NAME"

echo ""
echo "Next steps:"
echo "1. Review: $DIST_DIR/${APP_NAME}-deployment-info.txt"
echo "2. Upload files to S3"
echo "3. Create Glue job using the provided commands"
echo "4. Test the job with sample data"

EOF

chmod +x "$ROOT_DIR/build-glue-improved.sh"

print_success "Created improved Glue build script: build-glue-improved.sh"

# Create updated deployment script
cat > "$ROOT_DIR/deploy-glue-improved.sh" << 'EOF'
#!/bin/bash

# Improved Glue deployment script with proper entry point handling

set -e

BUCKET=""
APP=""
PREFIX="glue-jobs"
REGION="us-east-1"

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bucket) BUCKET="$2"; shift 2 ;;
        -a|--app) APP="$2"; shift 2 ;;
        -p|--prefix) PREFIX="$2"; shift 2 ;;
        -r|--region) REGION="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$BUCKET" || -z "$APP" ]]; then
    echo "Usage: $0 --bucket BUCKET --app APP [--prefix PREFIX] [--region REGION]"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"

echo "Deploying $APP to S3..."

# Upload main script
echo "Uploading main script..."
aws s3 cp "$DIST_DIR/${APP}.py" "s3://$BUCKET/$PREFIX/${APP}.py" --region "$REGION"

# Upload dependencies
echo "Uploading dependencies..."
aws s3 cp "$DIST_DIR/${APP}-deps.zip" "s3://$BUCKET/$PREFIX/${APP}-deps.zip" --region "$REGION"

# Upload single executable (optional)
if [[ -f "$DIST_DIR/${APP}-single.zip" ]]; then
    echo "Uploading single executable..."
    aws s3 cp "$DIST_DIR/${APP}-single.zip" "s3://$BUCKET/$PREFIX/${APP}-single.zip" --region "$REGION"
fi

echo "✓ Deployment completed!"
echo ""
echo "Files uploaded:"
echo "  - s3://$BUCKET/$PREFIX/${APP}.py"
echo "  - s3://$BUCKET/$PREFIX/${APP}-deps.zip"
echo ""
echo "Create Glue job with:"
echo "aws glue create-job \\"
echo "    --name \"$APP\" \\"
echo "    --role \"arn:aws:iam::YOUR_ACCOUNT:role/GlueServiceRole\" \\"
echo "    --command '{"
echo "        \"Name\": \"pythonshell\","
echo "        \"ScriptLocation\": \"s3://$BUCKET/$PREFIX/${APP}.py\","
echo "        \"PythonVersion\": \"3.9\""
echo "    }' \\"
echo "    --default-arguments '{"
echo "        \"--extra-py-files\": \"s3://$BUCKET/$PREFIX/${APP}-deps.zip\""
echo "    }' \\"
echo "    --max-capacity 0.0625"

EOF

chmod +x "$ROOT_DIR/deploy-glue-improved.sh"

print_success "Created improved deployment script: deploy-glue-improved.sh"

print_status ""
print_status "SUMMARY:"
print_status "========="
print_status "The entry point issue is solved by creating:"
print_status ""
print_status "1. Main Script (${APP_NAME}.py):"
print_status "   - This is what ScriptLocation points to"
print_status "   - Contains the entry point logic"
print_status "   - Handles dependency loading"
print_status ""
print_status "2. Dependencies ZIP (${APP_NAME}-deps.zip):"
print_status "   - Referenced by --extra-py-files"
print_status "   - Contains all your libraries and code"
print_status ""
print_status "Usage:"
print_status "  ./build-glue-improved.sh app1"
print_status "  ./deploy-glue-improved.sh --bucket my-bucket --app app1"

EOF
