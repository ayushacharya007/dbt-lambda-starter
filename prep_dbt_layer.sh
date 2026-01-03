#!/bin/bash
set -eou pipefail

# Configuration
LAYER_NAME="dbt_layer"
PLATFORM="manylinux2014_aarch64"
LAMBDA_UNZIPPED_LIMIT_MB=250


# Read Python version from project root
if [ ! -f ".python-version" ]; then
    echo "Error: .python-version not found in project root. Make sure to run this script from the project root directory."
    exit 1
fi

PYTHON_VERSION=$(cat .python-version)

echo "--- Starting Lambda Layer Preparation: $LAYER_NAME ---"

# Parse dependencies from pyproject.toml using Python
echo "Extracting dependencies from pyproject.toml..."
python3 << 'EOF' > requirements.txt
import tomllib

with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

dependencies = data.get("project", {}).get("dependencies", [])
if not dependencies:
    print("Error: No dependencies found in pyproject.toml")
    exit(1)

for dep in dependencies:
    print(dep)
EOF

echo "Generated requirements.txt"
echo "Found dependencies:"
cat requirements.txt
echo ""

# Cleanup previous runs
echo "Cleaning up previous build artifacts..."
rm -rf python "${LAYER_NAME}.zip"

# Create build directory
mkdir -p python

# Install dependencies for arm64 with full dependency resolution
echo "Installing dependencies for Python $PYTHON_VERSION on $PLATFORM..."
python3 -m pip install \
    --platform "$PLATFORM" \
    --python-version "$PYTHON_VERSION" \
    --only-binary=:all: \
    --target python/ \
    --implementation cp \
    -r requirements.txt

# Optimization: Remove unnecessary files to reduce layer size
echo "Optimizing layer size..."

# Remove __pycache__ everywhere
find python/ -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Remove compiled files
find python/ -name "*.pyc" -delete
find python/ -name "*.pyo" -delete
find python/ -name "*.pyd" -delete
find python/ -name "*.exe" -delete

# Check unzipped size
UNZIPPED_SIZE=$(du -sm python | cut -f1)
echo "Unzipped layer size: ${UNZIPPED_SIZE}MB"

if [ "$UNZIPPED_SIZE" -gt "$LAMBDA_UNZIPPED_LIMIT_MB" ]; then
    echo "WARNING: Unzipped size (${UNZIPPED_SIZE}MB) exceeds AWS Lambda limit (${LAMBDA_UNZIPPED_LIMIT_MB}MB)!"
    echo "Consider removing non-essential dependencies or using a different approach."
fi

# Create zip archive with maximum compression
echo "Creating zip archive with compression..."
zip -r9q "${LAYER_NAME}.zip" python

# Final stats
ZIPPED_SIZE=$(du -sh "${LAYER_NAME}.zip" | cut -f1)
echo ""
echo "--- Success! ---"
echo "Layer package: ${LAYER_NAME}.zip"
echo "Zipped size: $ZIPPED_SIZE"
echo "Unzipped size: ${UNZIPPED_SIZE}MB"

# Cleanup build directory
rm -rf python

# Remove generated requirements.txt
rm -f requirements.txt

echo "Layer is ready to be deployed!"
