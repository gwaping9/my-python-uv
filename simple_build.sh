#!/usr/bin/env bash
set -euo pipefail

# Root directory of the repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$ROOT_DIR/apps"
LIBS_DIR="$ROOT_DIR/libraries"

# Default values
APP_NAME=""
OUTPUT_DIR="$ROOT_DIR/dist"

usage() {
    echo "Usage: $0 -a <app_name> [-o <output_dir>] [-d]"
    echo "  -a   Application name (app1, app2, ...)"
    echo "  -o   Output directory (default: dist/)"
    echo "  -d   Run locally after build (for validation)"
    exit 1
}

RUN_LOCAL=false

while getopts ":a:o:d" opt; do
  case ${opt} in
    a )
      APP_NAME=$OPTARG
      ;;
    o )
      OUTPUT_DIR=$OPTARG
      ;;
    d )
      RUN_LOCAL=true
      ;;
    \? )
      usage
      ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
    echo "❌ Application name required."
    usage
fi

APP_PATH="$APPS_DIR/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Application $APP_NAME not found in $APPS_DIR"
    exit 1
fi

echo "📦 Building application: $APP_NAME"
mkdir -p "$OUTPUT_DIR"

########################################
# 1. Install local library dependencies
########################################
echo "➡️ Installing libraries as editable deps"
for lib in "$LIBS_DIR"/*; do
    if [[ -f "$lib/pyproject.toml" ]]; then
        echo "   + Installing local library: $(basename "$lib")"
        uv pip install -e "$lib"
    fi
done

########################################
# 2. Install app dependencies
########################################
echo "➡️ Installing app dependencies"
uv pip install -e "$APP_PATH"

########################################
# 3. Build app wheel (with transitive deps)
########################################
echo "➡️ Building wheel package for $APP_NAME"
cd "$APP_PATH"
uv build --wheel --out-dir "$OUTPUT_DIR"

########################################
# 4. Export requirements for Glue
########################################
REQ_FILE="$OUTPUT_DIR/${APP_NAME}_requirements.txt"
echo "➡️ Exporting lockfile to requirements.txt"
uv export --format requirements-txt > "$REQ_FILE"

########################################
# 5. Package for AWS Glue (zip with deps)
########################################
APP_WHEEL=$(ls "$OUTPUT_DIR"/*.whl | grep "$APP_NAME" | tail -n1)
PACKAGE_DIR="$OUTPUT_DIR/${APP_NAME}_package"
ZIP_FILE="$OUTPUT_DIR/${APP_NAME}_glue.zip"

rm -rf "$PACKAGE_DIR" "$ZIP_FILE"
mkdir -p "$PACKAGE_DIR/python"

echo "➡️ Installing wheel + deps into Glue package dir"
uv pip install "$APP_WHEEL" -r "$REQ_FILE" --target "$PACKAGE_DIR/python"

echo "➡️ Creating deployment zip for AWS Glue"
cd "$PACKAGE_DIR" && zip -r "$ZIP_FILE" .

########################################
# 6. Optional: Run locally
########################################
if $RUN_LOCAL; then
    echo "➡️ Running app locally for validation"
    python "$APP_PATH/src/${APP_NAME}.py"
fi

echo "✅ Build complete. Output: $ZIP_FILE"
