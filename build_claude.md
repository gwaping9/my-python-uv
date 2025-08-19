# Python Monorepo Build System with UV

This build system provides comprehensive tooling for managing a Python monorepo with applications and shared libraries, optimized for both local development and AWS Glue deployment.

## 📁 Repository Structure

```
Root/
├── 📄 build.sh                 # Main build script
├── 📄 setup-workspace.sh       # Initial workspace setup
├── 📄 dev-tools.sh             # Development utilities
├── 📄 deploy.sh                # AWS Glue deployment
├── 📄 pyproject.toml           # Workspace configuration
├── 📁 apps/                    # Applications
│   ├── 📁 app1/
│   │   ├── 📄 pyproject.toml
│   │   └── 📁 src/
│   └── 📁 app2/
│       ├── 📄 pyproject.toml
│       └── 📁 src/
└── 📁 libraries/               # Shared libraries
    └── 📁 core/
        ├── 📄 pyproject.toml
        └── 📁 src/
```

## 🚀 Quick Start

### 1. Initial Setup

```bash
# Make scripts executable
chmod +x *.sh

# Set up the workspace (installs UV if needed)
./setup-workspace.sh

# Install dependencies for local development
./build.sh --mode local
```

### 2. Development Workflow

```bash
# Run tests
./dev-tools.sh test

# Format code
./dev-tools.sh format

# Run linting
./dev-tools.sh lint

# Run a specific app
./dev-tools.sh run app1

# Open shell in app environment
./dev-tools.sh shell app1
```

### 3. AWS Glue Deployment

```bash
# Build packages for Glue
./build.sh --mode glue

# Deploy to S3
./deploy.sh --bucket my-glue-bucket

# Create Glue jobs (review generated script first)
./dist/glue-job-commands.sh
```

## 🛠 Scripts Overview

### `build.sh` - Main Build Script

The primary build script supporting both local development and AWS Glue packaging.

**Usage:**
```bash
./build.sh [OPTIONS]

Options:
  -m, --mode MODE     Build mode: 'local' or 'glue' (default: local)
  -a, --app APP      Specific app to build (e.g., app1, app2)
  -c, --clean        Clean build directories before building
  -v, --verbose      Enable verbose output
  -h, --help         Show help message
```

**Examples:**
```bash
# Local development setup
./build.sh --mode local

# Build specific app for local development
./build.sh --mode local --app app1

# Package all apps for AWS Glue
./build.sh --mode glue --clean

# Package specific app for Glue with verbose output
./build.sh --mode glue --app app1 --verbose
```

**What it does:**

**Local Mode:**
- Syncs all library dependencies using `uv sync`
- Syncs all application dependencies
- Creates development environment for immediate use

**Glue Mode:**
- Builds wheel files for all libraries
- Exports production dependencies (no dev dependencies)
- Installs dependencies to package directory
- Creates deployment-ready ZIP files in `dist/` directory

### `setup-workspace.sh` - Initial Setup

Sets up the UV workspace and creates necessary configuration files.

**Usage:**
```bash
./setup-workspace.sh
```

**What it does:**
- Installs UV if not present
- Creates workspace `pyproject.toml`
- Generates `pyproject.toml` files for apps and libraries (if missing)
- Creates `.gitignore` file
- Initializes UV workspace

### `dev-tools.sh` - Development Utilities

Provides common development tasks across the monorepo.

**Usage:**
```bash
./dev-tools.sh <command> [target]

Commands:
  test [app|lib]         Run tests
  lint [app|lib]         Run linting (flake8)
  format [app|lib]       Format code (black)
  type-check [app|lib]   Run type checking (mypy)
  deps [app|lib]         Show dependency tree
  clean                  Clean build artifacts
  run <app>              Run specific application
  shell <app|lib>        Open shell in environment
```

**Examples:**
```bash
# Run all tests
./dev-tools.sh test

# Test specific app
./dev-tools.sh test app1

# Format all code
./dev-tools.sh format

# Lint specific library
./dev-tools.sh lint libraries/core

# Run app1
./dev-tools.sh run app1

# Open shell in app2 environment
./dev-tools.sh shell app2

# Clean all build artifacts
./dev-tools.sh clean
```

### `deploy.sh` - AWS Glue Deployment

Uploads packaged applications to S3 and generates Glue job creation scripts.

**Usage:**
```bash
./deploy.sh [OPTIONS]

Options:
  -b, --bucket BUCKET    S3 bucket for packages (required)
  -p, --prefix PREFIX    S3 prefix (default: glue-jobs)
  -r, --region REGION    AWS region (default: us-east-1)
  -a, --app APP         Deploy specific app only
  -d, --dry-run         Show what would be deployed
  -f, --force           Overwrite existing packages
  -h, --help            Show help
```

**Examples:**
```bash
# Deploy all apps
./deploy.sh --bucket my-glue-bucket

# Deploy specific app
./deploy.sh --bucket my-glue-bucket --app app1

# Dry run to see what would be deployed
./deploy.sh --bucket my-glue-bucket --dry-run

# Deploy to different region with custom prefix
./deploy.sh --bucket my-glue-bucket --region us-west-2 --prefix my-jobs
```

**What it does:**
- Validates AWS credentials and S3 bucket access
- Uploads ZIP packages to S3
- Generates `glue-job-commands.sh` script for creating Glue jobs
- Creates deployment summary

## 📦 Package Management with UV

This build system leverages UV's workspace features for efficient dependency management:

### Workspace Structure
- **Root `pyproject.toml`**: Defines workspace members and shared dev dependencies
- **Library `pyproject.toml`**: Individual library dependencies and build config
- **App `pyproject.toml`**: Application dependencies including local libraries

### Key Features
- **Unified dependency resolution** across all workspace members
- **Fast incremental builds** with UV's caching
- **Virtual environment management** per component
- **Wheel building** for efficient packaging

### Adding Dependencies

**To an application:**
```bash
cd apps/app1
uv add requests boto3
uv add --dev pytest black
```

**To a library:**
```bash
cd libraries/core
uv add pandas numpy
```

**Local library dependencies in apps:**
```toml
# In apps/app1/pyproject.toml
[project]
dependencies = [
    "requests>=2.28.0",
    "core @ file://${PROJECT_ROOT}/libraries/core",
]
```

## 🏗 AWS Glue Deployment Process

### 1. Package Building
```bash
./build.sh --mode glue
```
This creates:
- `build/wheels/` - Library wheel files
- `build/{app}/requirements.txt` - Exported dependencies
- `dist/{app}-glue.zip` - Deployment packages

### 2. S3 Upload
```bash
./deploy.sh --bucket your-glue-bucket
```
This creates:
- `dist/deployed-packages.txt` - S3 URIs of uploaded packages
- `dist/glue-job-commands.sh` - Job creation script
- `dist/deployment-summary.txt` - Deployment details

### 3. Glue Job Creation
```bash
# Review and customize first!
vim dist/glue-job-commands.sh

# Update the GLUE_ROLE variable
# Then run:
./dist/glue-job-commands.sh
```

## 🔧 Customization

### Adding New Applications

1. Create directory structure:
```bash
mkdir -p apps/new-app/src
```

2. Run workspace setup:
```bash
./setup-workspace.sh
```

3. Add your application code in `apps/new-app/src/`

### Adding New Libraries

1. Create directory structure:
```bash
mkdir -p libraries/new-lib/src
```

2. Run workspace setup:
```bash
./setup-workspace.sh
```

3. Add your library code in `libraries/new-lib/src/`

### Customizing Build Process

The build scripts are designed to be modular. You can:

- **Modify dependency installation**: Edit the sync functions in `build.sh`
- **Add build steps**: Add functions and call them in the main execution flow
- **Custom packaging**: Modify the `package_app_for_glue` function
- **Add validation**: Extend the prerequisite checks

### Environment Variables

You can set these environment variables to customize behavior:

```bash
export UV_INDEX_URL="https://your-private-pypi.com/simple/"
export AWS_DEFAULT_REGION="us-west-2"
export BUILD_VERBOSE="true"
```

## 🐛 Troubleshooting

### Common Issues

**UV not found:**
```bash
# Install UV manually
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"
```

**Build failures:**
```bash
# Clean and rebuild
./build.sh --clean --mode local --verbose
```

**AWS deployment issues:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket-name
```

**Missing dependencies:**
```bash
# Check dependency tree
./dev-tools.sh deps app1

# Resync dependencies
cd apps/app1 && uv sync
```

### Debugging Tips

1. **Use verbose mode**: Add `--verbose` to build commands
2. **Check individual components**: Use `--app` flag to isolate issues
3. **Validate pyproject.toml files**: Use `uv tree` to check dependencies
4. **Test locally first**: Always test with `--mode local` before Glue packaging

## 📝 Best Practices

### Development Workflow
1. Always run tests before committing: `./dev-tools.sh test`
2. Format code regularly: `./dev-tools.sh format`
3. Use type hints and run type checking: `./dev-tools.sh type-check`
4. Keep dependencies minimal and up-to-date

### Deployment Workflow
1. Test locally first: `./build.sh --mode local`
2. Build clean packages: `./build.sh --mode glue --clean`
3. Use dry-run for deployment: `./deploy.sh --dry-run`
4. Review generated Glue job scripts before execution

### Dependency Management
1. Pin major versions in production
2. Use `[project.optional-dependencies]` for dev tools
3. Regular dependency audits: `uv tree`
4. Document any special requirements in README files

This build system provides a robust foundation for managing complex Python monorepos with UV, supporting both local development and cloud deployment workflows.
