## Workflow Examples

### Daily Development Workflow
```bash
# 1. Start development session
./scripts/test-local.sh

# 2. Make changes to your code
# ... edit files ...

# 3. Run specific app locally
GLUE_TEST_MODE=true uv run python apps/app1/src/app1.py

# 4. Run tests
uv run pytest tests/test_app1.py -v

# 5. Validate dependencies before deployment
python scripts/validate-deps.py
```

### Deployment Workflow
```bash
# 1. Validate and test everything
./scripts/test-local.sh

# 2. Build packages
./scripts/build.sh

# 3. Deploy to AWS
./scripts/deploy-glue.sh app1 my-glue-bucket

# 4. Monitor the job
python scripts/monitor-glue.py my-app1-job

# 5. Check logs in AWS CloudWatch
aws logs tail /aws-glue/jobs/logs-v2 --follow
```

### Debugging Failed Glue Jobs
```bash
# Get recent job runs
python scripts/monitor-glue.py my-app1-job

# Check specific run details  
python scripts/monitor-glue.py my-app1-job jr_abc123def456

# Download and inspect logs
aws logs get-log-events \
  --log-group-name /aws-glue/jobs/logs-v2 \
  --log-stream-name my-app1-job-run-123
```

## Key Benefits

1. **🏗️ Workspace Management**: UV workspace handles all inter-package dependencies automatically
2. **🔄 Shared Code**: Common utilities in the `shared` package avoid duplication
3. **🏠 Isolated Apps**: Each app has its own dependencies and can be deployed separately
4. **⚡ Development Friendly**: Easy local development with `uv run` and comprehensive testing
5. **🚀 Production Ready**: Automated build, validation, and deployment scripts
6. **📦 Dependency Intelligence**: Smart bundling that only includes what Glue doesn't provide
7. **🔍 Type Safety**: Proper package structure enables excellent IDE support and type checking
8. **🧪 Testing First**: Comprehensive test setup with mocking for AWS services
9. **📊 Monitoring**: Built-in job monitoring and debugging tools
10. **⚠️ Validation**: Dependency compatibility checking before deployment

## Troubleshooting Common Issues

### Import Errors in Glue
- **Problem**: `ModuleNotFoundError` in Glue job
- **Solution**: Ensure dependency is in `bundle_deps` in pyproject.toml
- **Check**: Run `python scripts/validate-deps.py` before deployment

### Large Package Sizes
- **Problem**: Glue job takes too long to start
- **Solution**: Review bundled dependencies, use Glue-provided versions when possible
- **Command**: `du -sh dist/app*-deps/` to check bundle sizes

### Version Conflicts
- **Problem**: Dependency version conflicts
- **Solution**: Pin specific versions in pyproject.toml dependencies
- **Tool**: Use `uv lock` to generate lock file for reproducible builds

### Local vs Glue Environment Differences
- **Problem**: Code works locally but fails in Glue
- **Solution**: Set `GLUE_TEST_MODE=true` and use conditional imports
- **Pattern**: Mock AWS services in test mode, use real ones in production

This comprehensive setup provides everything you need for professional AWS Glue development with proper dependency management, testing, and deployment automation.# UV + AWS Glue Multi-App Setup Guide

## Project Structure Overview

```
apps/
├── app1/
│   ├── pyproject.toml
│   └── src/
│       ├── reader/
│       │   ├── __init__.py
│       │   └── app1_reader.py
│       └── app1.py
├── app2/
│   ├── pyproject.toml
│   └── src/
│       ├── reader/
│       │   ├── __init__.py
│       │   └── app2_reader.py
│       └── app2.py
packages/
└── shared/
    ├── pyproject.toml
    └── src/
        ├── error/
        │   └── error.py
        └── reader/
            └── reader.py
```

## Configuration Files

### Root `pyproject.toml`
```toml
[project]
name = "glue-apps-workspace"
version = "0.1.0"
description = "Multi-app AWS Glue workspace"
requires-python = ">=3.9"

[tool.uv.workspace]
members = [
    "apps/app1",
    "apps/app2", 
    "packages/shared"
]

[tool.uv]
dev-dependencies = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
    "toml>=0.10.2",  # For dependency bundling script
]
```

### `packages/shared/pyproject.toml`
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "shared"
version = "0.1.0"
description = "Shared utilities for Glue apps"
requires-python = ">=3.9"
dependencies = [
    "boto3>=1.26.0",
    "pyspark>=3.3.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
]

[tool.hatch.build.targets.wheel]
packages = ["src"]

[tool.hatch.build.targets.wheel.sources]
"src" = ""
```

### `apps/app1/pyproject.toml`
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "app1"
version = "0.1.0"
description = "AWS Glue App 1"
requires-python = ">=3.9"
dependencies = [
    "shared",
    # Data processing
    "pandas>=2.0.0,<3.0.0",
    "pyarrow>=10.0.0,<15.0.0",
    "openpyxl>=3.1.0",
    # AWS services
    "boto3>=1.26.0,<2.0.0",
    "botocore>=1.29.0,<2.0.0",
    # HTTP and APIs
    "requests>=2.28.0,<3.0.0",
    "urllib3>=1.26.0,<3.0.0",
    # Utilities
    "python-dateutil>=2.8.0",
    "pytz>=2023.3",
]

[project.scripts]
app1 = "app1:main"

[tool.hatch.build.targets.wheel]
packages = ["src"]
include = [
    "src/**/*.py",
]

[tool.hatch.build.targets.wheel.sources]
"src" = ""

# Glue-specific configuration
[tool.glue]
# Dependencies that should be bundled (not available in Glue)
bundle_deps = [
    "openpyxl",
    "python-dateutil",
    "pytz",
]
# Dependencies available in Glue runtime (don't bundle)
glue_provided = [
    "pandas",
    "pyarrow", 
    "boto3",
    "botocore",
    "requests",
    "urllib3",
]
```

### `apps/app2/pyproject.toml`
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "app2"
version = "0.1.0"
description = "AWS Glue App 2"  
requires-python = ">=3.9"
dependencies = [
    "shared",
    # Scientific computing
    "numpy>=1.24.0,<2.0.0",
    "scipy>=1.10.0,<2.0.0",
    "scikit-learn>=1.3.0,<2.0.0",
    # Data processing
    "pandas>=2.0.0,<3.0.0",
    "pyarrow>=10.0.0,<15.0.0",
    # AWS services
    "boto3>=1.26.0,<2.0.0",
    "botocore>=1.29.0,<2.0.0",
    # JSON and serialization
    "jsonschema>=4.17.0",
    "pydantic>=2.0.0,<3.0.0",
    # Utilities
    "python-dateutil>=2.8.0",
]

[project.scripts]
app2 = "app2:main"

[tool.hatch.build.targets.wheel]
packages = ["src"]
include = [
    "src/**/*.py",
]

[tool.hatch.build.targets.wheel.sources]
"src" = ""

# Glue-specific configuration
[tool.glue]
# Dependencies that should be bundled (not available in Glue)
bundle_deps = [
    "scikit-learn",
    "jsonschema", 
    "pydantic",
    "python-dateutil",
]
# Dependencies available in Glue runtime (don't bundle)
glue_provided = [
    "numpy",
    "scipy",
    "pandas",
    "pyarrow",
    "boto3", 
    "botocore",
]
```

## Package Implementation

### `packages/shared/src/error/error.py`
```python
"""Shared error handling utilities."""

class GlueAppError(Exception):
    """Base exception for Glue applications."""
    pass

class DataProcessingError(GlueAppError):
    """Error during data processing."""
    pass

class ConfigurationError(GlueAppError):
    """Error in application configuration."""
    pass
```

### `packages/shared/src/reader/reader.py`
```python
"""Shared reader utilities."""
from abc import ABC, abstractmethod
from typing import Any, Dict

class BaseReader(ABC):
    """Base reader class for all data sources."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
    
    @abstractmethod
    def read(self) -> Any:
        """Read data from source."""
        pass
    
    def validate_config(self) -> bool:
        """Validate reader configuration."""
        return True
```

### `apps/app1/src/reader/__init__.py`
```python
"""App1 reader package."""
from .app1_reader import App1Reader

__all__ = ["App1Reader"]
```

### `apps/app1/src/reader/app1_reader.py`
```python
"""App1 specific reader implementation."""
from typing import Any
from shared.reader.reader import BaseReader
from shared.error.error import DataProcessingError

class App1Reader(BaseReader):
    """Reader for App1 data sources."""
    
    def read(self) -> Any:
        """Read App1 data."""
        try:
            # App1 specific reading logic
            print(f"Reading with App1Reader using config: {self.config}")
            return {"data": "app1_data", "status": "success"}
        except Exception as e:
            raise DataProcessingError(f"Failed to read App1 data: {e}")
```

### Enhanced App Examples with 3rd Party Dependencies

### `apps/app1/src/app1.py`
```python
"""Main App1 Glue job with 3rd party dependencies."""
import sys
from datetime import datetime
import pandas as pd
import boto3
from openpyxl import Workbook
from reader.app1_reader import App1Reader
from shared.error.error import GlueAppError

def process_excel_data():
    """Process data and create Excel output."""
    # Create sample data with pandas
    data = {
        'timestamp': [datetime.now()],
        'status': ['processed'],
        'records': [100]
    }
    df = pd.DataFrame(data)
    
    # Create Excel file with openpyxl
    wb = Workbook()
    ws = wb.active
    ws['A1'] = 'App1 Processing Report'
    
    # Add DataFrame to Excel
    for r_idx, row in enumerate(df.values, 2):
        for c_idx, value in enumerate(row, 1):
            ws.cell(row=r_idx, column=c_idx, value=value)
    
    # Save to /tmp (Glue's writable directory)
    output_path = '/tmp/app1_output.xlsx'
    wb.save(output_path)
    return output_path, df

def main():
    """Main entry point for App1 Glue job."""
    try:
        print("Starting App1 Glue job with 3rd party dependencies...")
        
        # Initialize S3 client
        s3_client = boto3.client('s3')
        
        # Use custom reader
        reader = App1Reader({"source": "s3://app1-bucket/data/"})
        data = reader.read()
        
        # Process data with pandas and openpyxl
        excel_path, df = process_excel_data()
        print(f"Created Excel file: {excel_path}")
        print(f"DataFrame shape: {df.shape}")
        
        # Upload results back to S3 (optional)
        # s3_client.upload_file(excel_path, 'output-bucket', 'app1/results.xlsx')
        
        print(f"Processed data: {data}")
        print("App1 job completed successfully")
        
    except GlueAppError as e:
        print(f"Glue app error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### `apps/app2/src/app2.py`
```python
"""Main App2 Glue job with ML and validation dependencies."""
import sys
import json
from datetime import datetime
import numpy as np
import pandas as pd
import boto3
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from pydantic import BaseModel, ValidationError
from jsonschema import validate, ValidationError as JsonValidationError
from reader.app2_reader import App2Reader
from shared.error.error import GlueAppError

class DataModel(BaseModel):
    """Pydantic model for data validation."""
    id: int
    value: float
    category: str
    timestamp: datetime

def validate_input_data(data):
    """Validate input data using jsonschema and pydantic."""
    schema = {
        "type": "array",
        "items": {
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "value": {"type": "number"},
                "category": {"type": "string"},
                "timestamp": {"type": "string"}
            },
            "required": ["id", "value", "category", "timestamp"]
        }
    }
    
    # JSON schema validation
    validate(instance=data, schema=schema)
    
    # Pydantic validation
    validated_items = []
    for item in data:
        try:
            validated_items.append(DataModel(**item))
        except ValidationError as e:
            raise ValueError(f"Pydantic validation failed: {e}")
    
    return validated_items

def perform_ml_analysis(df):
    """Perform ML analysis using scikit-learn."""
    # Prepare features
    features = df[['value']].values
    scaler = StandardScaler()
    scaled_features = scaler.fit_transform(features)
    
    # Perform clustering
    kmeans = KMeans(n_clusters=3, random_state=42)
    clusters = kmeans.fit_predict(scaled_features)
    
    # Add results to DataFrame
    df['cluster'] = clusters
    df['scaled_value'] = scaled_features.flatten()
    
    return df, kmeans

def main():
    """Main entry point for App2 Glue job."""
    try:
        print("Starting App2 Glue job with ML and validation...")
        
        # Initialize S3 client
        s3_client = boto3.client('s3')
        
        # Use custom reader
        reader = App2Reader({"source": "s3://app2-bucket/data/"})
        raw_data = reader.read()
        
        # Sample data for demonstration
        sample_data = [
            {
                "id": 1,
                "value": 10.5,
                "category": "A",
                "timestamp": "2024-01-01T00:00:00"
            },
            {
                "id": 2, 
                "value": 20.3,
                "category": "B",
                "timestamp": "2024-01-01T01:00:00"
            },
            {
                "id": 3,
                "value": 15.7,
                "category": "A", 
                "timestamp": "2024-01-01T02:00:00"
            }
        ]
        
        # Validate input data
        print("Validating input data...")
        validated_data = validate_input_data(sample_data)
        print(f"Validated {len(validated_data)} records")
        
        # Convert to DataFrame for ML processing
        df = pd.DataFrame([item.dict() for item in validated_data])
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        # Perform ML analysis
        print("Performing ML analysis...")
        result_df, model = perform_ml_analysis(df)
        
        print(f"Clustering results:")
        print(result_df[['id', 'value', 'cluster', 'scaled_value']])
        
        # Save results
        output_path = '/tmp/app2_ml_results.json'
        results = {
            'processed_at': datetime.now().isoformat(),
            'total_records': len(result_df),
            'clusters': result_df.groupby('cluster').size().to_dict(),
            'cluster_centers': model.cluster_centers_.tolist()
        }
        
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"Results saved to: {output_path}")
        print("App2 job completed successfully")
        
    except (ValidationError, JsonValidationError) as e:
        print(f"Data validation error: {e}")
        sys.exit(1)
    except GlueAppError as e:
        print(f"Glue app error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
``` __name__ == "__main__":
    main()
```

## Build and Deployment Scripts

### `scripts/build-deps.py` (Dependency bundling script)
```python
#!/usr/bin/env python3
"""Build dependencies for AWS Glue deployment."""
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import shutil
import toml

def get_glue_config(app_path):
    """Get Glue-specific configuration from pyproject.toml."""
    pyproject_path = app_path / "pyproject.toml"
    if not pyproject_path.exists():
        return {"bundle_deps": [], "glue_provided": []}
    
    config = toml.load(pyproject_path)
    return config.get("tool", {}).get("glue", {
        "bundle_deps": [],
        "glue_provided": []
    })

def bundle_dependencies(app_name, app_path, output_dir):
    """Bundle third-party dependencies for Glue."""
    print(f"Bundling dependencies for {app_name}...")
    
    glue_config = get_glue_config(app_path)
    bundle_deps = glue_config.get("bundle_deps", [])
    
    if not bundle_deps:
        print(f"No dependencies to bundle for {app_name}")
        return
    
    # Create temporary directory for dependency collection
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Download dependencies
        for dep in bundle_deps:
            print(f"  Downloading {dep}...")
            subprocess.run([
                "uv", "pip", "download", 
                "--dest", str(temp_path),
                "--no-deps", dep
            ], check=True)
        
        # Create bundle directory
        bundle_dir = output_dir / f"{app_name}-deps"
        bundle_dir.mkdir(exist_ok=True)
        
        # Copy wheels to bundle directory
        for wheel in temp_path.glob("*.whl"):
            shutil.copy2(wheel, bundle_dir)
            print(f"  Bundled: {wheel.name}")
    
    print(f"Dependencies bundled in: {bundle_dir}")

def main():
    """Main bundling function."""
    if len(sys.argv) != 2:
        print("Usage: python build-deps.py <app_name>")
        sys.exit(1)
    
    app_name = sys.argv[1]
    app_path = Path(f"apps/{app_name}")
    
    if not app_path.exists():
        print(f"App directory not found: {app_path}")
        sys.exit(1)
    
    output_dir = Path("dist")
    output_dir.mkdir(exist_ok=True)
    
    bundle_dependencies(app_name, app_path, output_dir)
    print("Dependency bundling complete!")

if __name__ == "__main__":
    main()
```

### `scripts/build.sh`
```bash
#!/bin/bash
set -e

echo "Building all packages for AWS Glue..."

# Install toml for dependency script
uv add --dev toml

# Create dist directory
mkdir -p dist

# Build shared package first
echo "Building shared package..."
cd packages/shared
uv build --out-dir ../../dist/
cd ../..

# Build app packages
for app in app1 app2; do
    echo "Building $app..."
    cd apps/$app
    uv build --out-dir ../../dist/
    cd ../..
    
    # Bundle third-party dependencies
    echo "Bundling dependencies for $app..."
    python scripts/build-deps.py $app
done

echo ""
echo "Build complete! Output structure:"
echo "dist/"
echo "├── shared-0.1.0-py3-none-any.whl"
echo "├── app1-0.1.0-py3-none-any.whl" 
echo "├── app2-0.1.0-py3-none-any.whl"
echo "├── app1-deps/"
echo "│   └── [bundled wheels for app1]"
echo "└── app2-deps/"
echo "    └── [bundled wheels for app2]"
```

### `scripts/deploy-glue.sh`
```bash
#!/bin/bash
set -e

APP_NAME=$1
S3_BUCKET=$2

if [ -z "$APP_NAME" ] || [ -z "$S3_BUCKET" ]; then
    echo "Usage: $0 <app_name> <s3_bucket>"
    echo "Example: $0 app1 my-glue-artifacts-bucket"
    exit 1
fi

echo "Deploying $APP_NAME to AWS Glue..."

# Build all packages and dependencies
./scripts/build.sh

# Create S3 paths
WHEELS_PATH="s3://$S3_BUCKET/wheels"
DEPS_PATH="s3://$S3_BUCKET/deps"  
SCRIPTS_PATH="s3://$S3_BUCKET/scripts"

# Upload main wheels
echo "Uploading application wheels..."
aws s3 cp dist/shared-0.1.0-py3-none-any.whl $WHEELS_PATH/
aws s3 cp dist/${APP_NAME}-0.1.0-py3-none-any.whl $WHEELS_PATH/

# Upload bundled dependencies
if [ -d "dist/${APP_NAME}-deps" ]; then
    echo "Uploading bundled dependencies..."
    aws s3 cp dist/${APP_NAME}-deps/ $DEPS_PATH/${APP_NAME}/ --recursive
fi

# Upload main script
echo "Uploading main script..."
aws s3 cp apps/$APP_NAME/src/${APP_NAME}.py $SCRIPTS_PATH/

echo ""
echo "Deployment complete!"
echo ""
echo "AWS Glue Job Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Script location:"
echo "  $SCRIPTS_PATH/${APP_NAME}.py"
echo ""
echo "Python library path (--additional-python-modules):"
echo "  $WHEELS_PATH/shared-0.1.0-py3-none-any.whl,$WHEELS_PATH/${APP_NAME}-0.1.0-py3-none-any.whl"

# Check if there are bundled dependencies
if [ -d "dist/${APP_NAME}-deps" ]; then
    echo ""
    echo "Additional bundled dependencies (add to --additional-python-modules):"
    for wheel in dist/${APP_NAME}-deps/*.whl; do
        if [ -f "$wheel" ]; then
            wheel_name=$(basename "$wheel")
            echo "  $DEPS_PATH/${APP_NAME}/$wheel_name"
        fi
    done
    
    # Generate complete parameter
    echo ""
    echo "Complete --additional-python-modules parameter:"
    printf "  %s,%s" "$WHEELS_PATH/shared-0.1.0-py3-none-any.whl" "$WHEELS_PATH/${APP_NAME}-0.1.0-py3-none-any.whl"
    for wheel in dist/${APP_NAME}-deps/*.whl; do
        if [ -f "$wheel" ]; then
            wheel_name=$(basename "$wheel")
            printf ",%s" "$DEPS_PATH/${APP_NAME}/$wheel_name"
        fi
    done
    echo ""
fi

echo ""
echo "Job Role: Ensure your Glue job role has S3 read access to:"
echo "  s3://$S3_BUCKET/wheels/*"
echo "  s3://$S3_BUCKET/deps/*"
echo "  s3://$S3_BUCKET/scripts/*"
```

### `scripts/local-dev.sh`
```bash
#!/bin/bash
set -e

echo "Setting up local development environment..."

# Install all packages in development mode
echo "Installing workspace in development mode..."
uv sync --all-extras

echo "Running tests..."
uv run pytest

echo "Local development setup complete!"
echo "You can now run:"
echo "- uv run python apps/app1/src/app1.py"
echo "- uv run python apps/app2/src/app2.py"
```

## Usage Instructions

### Local Development
```bash
# Initial setup
./scripts/local-dev.sh

# Run individual apps locally
uv run python apps/app1/src/app1.py
uv run python apps/app2/src/app2.py

# Run tests
uv run pytest

# Format code
uv run black .
uv run ruff check .
```

### AWS Glue Deployment
```bash
# Build all packages
./scripts/build.sh

# Deploy app1 to Glue
./scripts/deploy-glue.sh app1 your-s3-bucket

# Deploy app2 to Glue  
./scripts/deploy-glue.sh app2 your-s3-bucket
```

### AWS Glue Job Configuration

After deployment, configure your Glue jobs with these settings:

#### App1 Job Configuration
```
Script location: s3://your-bucket/scripts/app1.py

Job parameters:
--additional-python-modules: 
s3://your-bucket/wheels/shared-0.1.0-py3-none-any.whl,s3://your-bucket/wheels/app1-0.1.0-py3-none-any.whl,s3://your-bucket/deps/app1/openpyxl-3.1.2-py2.py3-none-any.whl,s3://your-bucket/deps/app1/python_dateutil-2.8.2-py2.py3-none-any.whl,s3://your-bucket/deps/app1/pytz-2023.3-py2.py3-none-any.whl
```

#### App2 Job Configuration
```
Script location: s3://your-bucket/scripts/app2.py

Job parameters:
--additional-python-modules:
s3://your-bucket/wheels/shared-0.1.0-py3-none-any.whl,s3://your-bucket/wheels/app2-0.1.0-py3-none-any.whl,s3://your-bucket/deps/app2/scikit_learn-1.3.2-cp39-cp39-linux_x86_64.whl,s3://your-bucket/deps/app2/jsonschema-4.17.3-py3-none-any.whl,s3://your-bucket/deps/app2/pydantic-2.5.3-py3-none-any.whl,s3://your-bucket/deps/app2/python_dateutil-2.8.2-py2.py3-none-any.whl
```

#### Important Notes for Third-Party Dependencies

**Glue-Provided Libraries** (don't bundle these):
- pandas, numpy, scipy, pyarrow 
- boto3, botocore
- requests, urllib3
- PySpark and related libraries

**Custom Dependencies** (must be bundled):
- Any library not in Glue's pre-installed list
- Specific versions different from Glue defaults
- Custom or proprietary packages

**Memory Considerations:**
- Large ML libraries (scikit-learn, tensorflow) increase job startup time
- Consider using Glue's built-in ML libraries when possible
- Monitor job memory usage with many bundled dependencies

## Advanced Features and Best Practices

### `scripts/validate-deps.py` (Dependency validation script)
```python
#!/usr/bin/env python3
"""Validate dependencies against AWS Glue compatibility."""
import json
import sys
from pathlib import Path
import toml
import requests

# Known Glue-provided packages (Glue 4.0)
GLUE_PROVIDED_PACKAGES = {
    'pandas', 'numpy', 'scipy', 'boto3', 'botocore', 'requests', 
    'urllib3', 'pytz', 'python-dateutil', 'six', 'certifi',
    'charset-normalizer', 'idna', 'jmespath', 's3transfer',
    'pyspark', 'py4j', 'pyarrow'
}

# Packages known to cause issues in Glue
PROBLEMATIC_PACKAGES = {
    'tensorflow': 'Use AWS SageMaker or bundle carefully - very large',
    'torch': 'Use AWS SageMaker or bundle carefully - very large', 
    'opencv-python': 'Use opencv-python-headless instead',
    'matplotlib': 'May have display issues in headless environment'
}

def check_app_dependencies(app_name, app_path):
    """Check app dependencies for Glue compatibility."""
    pyproject_path = app_path / "pyproject.toml"
    if not pyproject_path.exists():
        print(f"No pyproject.toml found for {app_name}")
        return
    
    config = toml.load(pyproject_path)
    dependencies = config.get("project", {}).get("dependencies", [])
    glue_config = config.get("tool", {}).get("glue", {})
    
    print(f"\n🔍 Analyzing {app_name} dependencies:")
    print("=" * 50)
    
    warnings = []
    bundled_count = 0
    provided_count = 0
    
    for dep in dependencies:
        # Extract package name (remove version specs)
        pkg_name = dep.split('>=')[0].split('==')[0].split('<')[0].split('>')[0].split('!')[0].split(';')[0].strip()
        
        if pkg_name == 'shared':
            continue  # Skip our own shared package
            
        if pkg_name in GLUE_PROVIDED_PACKAGES:
            print(f"  ✅ {pkg_name} - Provided by Glue")
            provided_count += 1
        elif pkg_name in glue_config.get('bundle_deps', []):
            print(f"  📦 {pkg_name} - Will be bundled")
            bundled_count += 1
        else:
            print(f"  ⚠️  {pkg_name} - NOT in bundle list (will use Glue version if available)")
            warnings.append(f"{pkg_name} not explicitly configured")
        
        if pkg_name in PROBLEMATIC_PACKAGES:
            print(f"     🚨 WARNING: {PROBLEMATIC_PACKAGES[pkg_name]}")
            warnings.append(f"{pkg_name}: {PROBLEMATIC_PACKAGES[pkg_name]}")
    
    print(f"\n📊 Summary for {app_name}:")
    print(f"  - Glue provided: {provided_count}")
    print(f"  - Will bundle: {bundled_count}") 
    print(f"  - Warnings: {len(warnings)}")
    
    if warnings:
        print(f"\n⚠️  Recommendations for {app_name}:")
        for warning in warnings:
            print(f"  - {warning}")
    
    return len(warnings) == 0

def main():
    """Main validation function."""
    print("🔍 AWS Glue Dependency Validation")
    print("=" * 50)
    
    apps_dir = Path("apps")
    if not apps_dir.exists():
        print("No apps directory found")
        sys.exit(1)
    
    all_good = True
    for app_dir in apps_dir.iterdir():
        if app_dir.is_dir() and (app_dir / "pyproject.toml").exists():
            if not check_app_dependencies(app_dir.name, app_dir):
                all_good = False
    
    print(f"\n{'✅' if all_good else '⚠️'} Validation {'passed' if all_good else 'completed with warnings'}")
    if not all_good:
        print("\nRecommendation: Review warnings and update [tool.glue] configurations")

if __name__ == "__main__":
    main()
```

### `scripts/test-local.sh` (Local testing script)
```bash
#!/bin/bash
set -e

echo "🧪 Running local tests for Glue apps..."

# Setup virtual environment if needed
echo "Setting up development environment..."
uv sync --all-extras

# Run dependency validation
echo ""
echo "Validating dependencies..."
python scripts/validate-deps.py

# Run tests
echo ""
echo "Running unit tests..."
uv run pytest tests/ -v

# Test individual apps locally
echo ""
echo "Testing apps locally..."

for app in app1 app2; do
    echo ""
    echo "🧪 Testing $app..."
    echo "─" $(printf "─%.0s" {1..40})
    
    # Check if app can be imported
    if uv run python -c "import sys; sys.path.append('apps/$app/src'); import $app; print('✅ Import successful')"; then
        echo "✅ $app imports successfully"
    else
        echo "❌ $app import failed"
        exit 1
    fi
    
    # Run the app (with dry-run environment variable)
    echo "Running $app in test mode..."
    GLUE_TEST_MODE=true uv run python apps/$app/src/$app.py
    
    echo "✅ $app completed successfully"
done

echo ""
echo "🎉 All local tests passed!"
echo ""
echo "Next steps:"
echo "  1. Build packages: ./scripts/build.sh"
echo "  2. Deploy to AWS: ./scripts/deploy-glue.sh app1 your-bucket"
```

### `scripts/monitor-glue.py` (Glue job monitoring helper)
```python
#!/usr/bin/env python3
"""Monitor AWS Glue job execution."""
import boto3
import sys
import time
from datetime import datetime

def monitor_job(job_name, run_id=None):
    """Monitor a specific Glue job run."""
    glue = boto3.client('glue')
    
    try:
        if run_id:
            # Monitor specific run
            print(f"Monitoring job run: {job_name} (Run ID: {run_id})")
            
            while True:
                response = glue.get_job_run(JobName=job_name, RunId=run_id)
                job_run = response['JobRun']
                
                state = job_run['JobRunState']
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Status: {state}")
                
                if state in ['SUCCEEDED', 'FAILED', 'STOPPED', 'TIMEOUT']:
                    break
                    
                time.sleep(30)  # Check every 30 seconds
            
            # Print final details
            print(f"\nFinal Status: {state}")
            if 'ExecutionTime' in job_run:
                print(f"Execution Time: {job_run['ExecutionTime']} seconds")
            if 'ErrorMessage' in job_run:
                print(f"Error: {job_run['ErrorMessage']}")
                
        else:
            # Show recent runs
            response = glue.get_job_runs(JobName=job_name, MaxResults=5)
            runs = response['JobRuns']
            
            print(f"Recent runs for {job_name}:")
            print("-" * 60)
            for run in runs:
                start_time = run.get('StartedOn', 'N/A')
                if isinstance(start_time, datetime):
                    start_time = start_time.strftime('%Y-%m-%d %H:%M:%S')
                
                print(f"Run ID: {run['Id']}")
                print(f"  Status: {run['JobRunState']}")
                print(f"  Started: {start_time}")
                if 'ExecutionTime' in run:
                    print(f"  Duration: {run['ExecutionTime']}s")
                print()
                
    except Exception as e:
        print(f"Error monitoring job: {e}")
        sys.exit(1)

def main():
    """Main monitoring function."""
    if len(sys.argv) < 2:
        print("Usage: python monitor-glue.py <job_name> [run_id]")
        sys.exit(1)
    
    job_name = sys.argv[1]
    run_id = sys.argv[2] if len(sys.argv) > 2 else None
    
    monitor_job(job_name, run_id)

if __name__ == "__main__":
    main()
```

### Testing Configuration

### `tests/conftest.py`
```python
"""Pytest configuration for Glue apps."""
import pytest
import sys
from pathlib import Path

# Add src directories to path for testing
def add_src_paths():
    """Add all app src directories to Python path."""
    project_root = Path(__file__).parent.parent
    
    # Add shared package
    shared_src = project_root / "packages" / "shared" / "src"
    if shared_src.exists():
        sys.path.insert(0, str(shared_src))
    
    # Add app packages
    apps_dir = project_root / "apps"
    if apps_dir.exists():
        for app_dir in apps_dir.iterdir():
            if app_dir.is_dir():
                app_src = app_dir / "src"
                if app_src.exists():
                    sys.path.insert(0, str(app_src))

add_src_paths()

@pytest.fixture
def mock_glue_context():
    """Mock Glue context for testing."""
    class MockGlueContext:
        def __init__(self):
            self.args = {}
        
        def getArgs(self):
            return self.args
    
    return MockGlueContext()

@pytest.fixture
def sample_config():
    """Sample configuration for testing."""
    return {
        "source": "s3://test-bucket/data/",
        "output": "s3://test-bucket/output/",
        "batch_size": 100
    }
```

### `tests/test_shared.py`
```python
"""Tests for shared utilities."""
import pytest
from shared.error.error import GlueAppError, DataProcessingError
from shared.reader.reader import BaseReader

def test_glue_app_error():
    """Test custom exception handling."""
    with pytest.raises(GlueAppError):
        raise GlueAppError("Test error")

def test_data_processing_error():
    """Test data processing exception."""
    with pytest.raises(DataProcessingError):
        raise DataProcessingError("Processing failed")

def test_base_reader_abstract():
    """Test that BaseReader is abstract."""
    with pytest.raises(TypeError):
        BaseReader({"test": "config"})

class TestReader(BaseReader):
    """Test implementation of BaseReader."""
    
    def read(self):
        return {"test": "data"}

def test_base_reader_implementation():
    """Test BaseReader implementation."""
    reader = TestReader({"source": "test"})
    assert reader.config == {"source": "test"}
    assert reader.read() == {"test": "data"}
    assert reader.validate_config() is True
```

### `tests/test_app1.py`
```python
"""Tests for App1."""
import pytest
import sys
from unittest.mock import patch, MagicMock

# Mock heavy dependencies for testing
sys.modules['openpyxl'] = MagicMock()
sys.modules['pandas'] = MagicMock()
sys.modules['boto3'] = MagicMock()

from reader.app1_reader import App1Reader

def test_app1_reader_initialization():
    """Test App1Reader initialization."""
    config = {"source": "s3://test/"}
    reader = App1Reader(config)
    assert reader.config == config

def test_app1_reader_read():
    """Test App1Reader read method."""
    reader = App1Reader({"source": "test"})
    result = reader.read()
    
    assert "data" in result
    assert "status" in result
    assert result["status"] == "success"

@patch.dict('os.environ', {'GLUE_TEST_MODE': 'true'})
def test_app1_main_dry_run():
    """Test App1 main function in test mode."""
    # This would test the main function without actual AWS calls
    pass
```

### Project Structure with Testing
```
project/
├── pyproject.toml                 # Workspace config
├── tests/                         # Test directory
│   ├── conftest.py               # Pytest configuration
│   ├── test_shared.py            # Shared utilities tests
│   ├── test_app1.py              # App1 tests
│   └── test_app2.py              # App2 tests
├── scripts/                       # Build and deployment scripts
│   ├── build.sh                  # Main build script
│   ├── build-deps.py             # Dependency bundling
│   ├── deploy-glue.sh            # AWS deployment
│   ├── validate-deps.py          # Dependency validation
│   ├── test-local.sh             # Local testing
│   └── monitor-glue.py           # Job monitoring
├── apps/                         # Application packages
│   ├── app1/
│   └── app2/
├── packages/                     # Shared packages
│   └── shared/
└── dist/                        # Build output (generated)
    ├── *.whl                    # Application wheels
    ├── app1-deps/               # App1 bundled dependencies
    └── app2-deps/               # App2 bundled dependencies
```
