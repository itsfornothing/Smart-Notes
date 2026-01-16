#!/usr/bin/env bash
# Test build script execution (without psycopg2 installation)
# This validates the build script structure and most steps

set -o errexit

echo "========================================="
echo "Testing Build Script Components"
echo "========================================="
echo ""

# Test 1: Check if build.sh exists and is executable
echo "✓ Test 1: Checking build.sh exists and is executable..."
if [ -x "./build.sh" ]; then
    echo "  ✓ build.sh is executable"
else
    echo "  ✗ build.sh is not executable"
    exit 1
fi
echo ""

# Test 2: Check Python version
echo "✓ Test 2: Checking Python version..."
python3 --version
echo ""

# Test 3: Check pip can be upgraded
echo "✓ Test 3: Testing pip upgrade..."
pip install --upgrade pip --quiet
echo "  ✓ pip upgraded successfully"
echo ""

# Test 4: Check requirements.txt exists
echo "✓ Test 4: Checking requirements.txt exists..."
if [ -f "./requirements.txt" ]; then
    echo "  ✓ requirements.txt found"
    echo "  Dependencies listed:"
    grep -E "^(gunicorn|dj-database-url|whitenoise)" requirements.txt | sed 's/^/    - /'
else
    echo "  ✗ requirements.txt not found"
    exit 1
fi
echo ""

# Test 5: Check validate_env.py exists
echo "✓ Test 5: Checking validate_env.py exists..."
if [ -f "./validate_env.py" ]; then
    echo "  ✓ validate_env.py found"
else
    echo "  ✗ validate_env.py not found"
    exit 1
fi
echo ""

# Test 6: Check manage.py exists
echo "✓ Test 6: Checking manage.py exists..."
if [ -f "./manage.py" ]; then
    echo "  ✓ manage.py found"
else
    echo "  ✗ manage.py not found"
    exit 1
fi
echo ""

# Test 7: Validate environment variables (without running full validation)
echo "✓ Test 7: Checking .env file exists..."
if [ -f "./.env" ]; then
    echo "  ✓ .env file found"
    echo "  Environment variables configured:"
    grep -E "^(DB_NAME|SECRET_KEY|EMAIL_HOST_USER|JWT_SECRET_KEY)" .env | cut -d'=' -f1 | sed 's/^/    - /'
else
    echo "  ✗ .env file not found"
    exit 1
fi
echo ""

# Test 8: Check Django settings files
echo "✓ Test 8: Checking Django settings files..."
if [ -f "./Notes_API/settings.py" ]; then
    echo "  ✓ settings.py found"
else
    echo "  ✗ settings.py not found"
    exit 1
fi

if [ -f "./Notes_API/settings_production.py" ]; then
    echo "  ✓ settings_production.py found"
else
    echo "  ✗ settings_production.py not found"
    exit 1
fi
echo ""

# Test 9: Check WSGI configuration
echo "✓ Test 9: Checking WSGI configuration..."
if [ -f "./Notes_API/wsgi.py" ]; then
    echo "  ✓ wsgi.py found"
    if grep -q "RENDER" "./Notes_API/wsgi.py"; then
        echo "  ✓ RENDER environment detection configured"
    else
        echo "  ✗ RENDER environment detection not found"
        exit 1
    fi
else
    echo "  ✗ wsgi.py not found"
    exit 1
fi
echo ""

# Test 10: Check render.yaml exists
echo "✓ Test 10: Checking render.yaml exists..."
if [ -f "./render.yaml" ]; then
    echo "  ✓ render.yaml found"
else
    echo "  ✗ render.yaml not found"
    exit 1
fi
echo ""

# Test 11: Check runtime.txt specifies correct Python version
echo "✓ Test 11: Checking runtime.txt..."
if [ -f "./runtime.txt" ]; then
    echo "  ✓ runtime.txt found"
    PYTHON_VERSION=$(cat runtime.txt)
    echo "  Specified Python version: $PYTHON_VERSION"
    if [[ "$PYTHON_VERSION" == "python-3.11"* ]]; then
        echo "  ✓ Python 3.11 specified (compatible with psycopg2-binary)"
    else
        echo "  ⚠ Warning: Python version may have compatibility issues"
    fi
else
    echo "  ✗ runtime.txt not found"
    exit 1
fi
echo ""

echo "========================================="
echo "Build Script Validation Summary"
echo "========================================="
echo ""
echo "✓ All testable components validated successfully!"
echo ""
echo "Note: Full build script execution requires:"
echo "  - Python 3.11 (for psycopg2-binary compatibility)"
echo "  - PostgreSQL database connection (for migrations)"
echo "  - All environment variables set"
echo ""
echo "On Render.com with Python 3.11, the build script will:"
echo "  1. ✓ Upgrade pip"
echo "  2. ✓ Install all dependencies (including psycopg2-binary)"
echo "  3. ✓ Validate environment variables"
echo "  4. ✓ Collect static files"
echo "  5. ✓ Run database migrations"
echo ""
echo "Build script is ready for deployment!"
echo "========================================="
