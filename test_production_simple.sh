#!/bin/bash

# Simple Production Settings Test Script
# Tests production configuration without running full Django setup

echo "============================================================"
echo "PRODUCTION SETTINGS VALIDATION TEST"
echo "============================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Function to print test result
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

echo "Test 1: Checking if .env.production.local exists"
if [ -f ".env.production.local" ]; then
    test_result 0 ".env.production.local file exists"
else
    test_result 1 ".env.production.local file not found"
fi
echo ""

echo "Test 2: Checking if settings_production.py exists"
if [ -f "Notes_API/settings_production.py" ]; then
    test_result 0 "settings_production.py file exists"
else
    test_result 1 "settings_production.py file not found"
fi
echo ""

echo "Test 3: Checking if build.sh exists and is executable"
if [ -f "build.sh" ] && [ -x "build.sh" ]; then
    test_result 0 "build.sh exists and is executable"
elif [ -f "build.sh" ]; then
    test_result 1 "build.sh exists but is not executable (run: chmod +x build.sh)"
else
    test_result 1 "build.sh not found"
fi
echo ""

echo "Test 4: Checking if render.yaml exists"
if [ -f "render.yaml" ]; then
    test_result 0 "render.yaml file exists"
else
    test_result 1 "render.yaml file not found"
fi
echo ""

echo "Test 5: Checking if runtime.txt exists"
if [ -f "runtime.txt" ]; then
    test_result 0 "runtime.txt file exists"
    echo "   Content: $(cat runtime.txt)"
else
    test_result 1 "runtime.txt file not found"
fi
echo ""

echo "Test 6: Checking if .gitignore exists"
if [ -f ".gitignore" ]; then
    test_result 0 ".gitignore file exists"
else
    test_result 1 ".gitignore file not found"
fi
echo ""

echo "Test 7: Checking if requirements.txt contains production dependencies"
if [ -f "requirements.txt" ]; then
    if grep -q "gunicorn" requirements.txt && \
       grep -q "dj-database-url" requirements.txt && \
       grep -q "whitenoise" requirements.txt; then
        test_result 0 "Production dependencies found in requirements.txt"
    else
        test_result 1 "Missing production dependencies in requirements.txt"
    fi
else
    test_result 1 "requirements.txt not found"
fi
echo ""

echo "Test 8: Validating settings_production.py configuration"
if [ -f "Notes_API/settings_production.py" ]; then
    if grep -q "DEBUG = False" Notes_API/settings_production.py && \
       grep -q "SECURE_SSL_REDIRECT = True" Notes_API/settings_production.py && \
       grep -q "SESSION_COOKIE_SECURE = True" Notes_API/settings_production.py; then
        test_result 0 "Production security settings configured correctly"
    else
        test_result 1 "Production security settings not configured correctly"
    fi
else
    test_result 1 "Cannot validate settings_production.py (file not found)"
fi
echo ""

echo "Test 9: Checking environment variables in .env.production.local"
if [ -f ".env.production.local" ]; then
    REQUIRED_VARS=("RENDER" "SECRET_KEY" "JWT_SECRET_KEY" "DATABASE_URL" "REDIS_URL" "ALLOWED_HOSTS")
    ALL_PRESENT=true
    
    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^${var}=" .env.production.local; then
            echo -e "   ${YELLOW}⚠️${NC}  Missing or commented: $var"
            ALL_PRESENT=false
        fi
    done
    
    if [ "$ALL_PRESENT" = true ]; then
        test_result 0 "All required environment variables present"
    else
        test_result 1 "Some required environment variables missing"
    fi
else
    test_result 1 "Cannot check environment variables (file not found)"
fi
echo ""

echo "Test 10: Checking wsgi.py for production settings detection"
if [ -f "Notes_API/wsgi.py" ]; then
    if grep -q "RENDER" Notes_API/wsgi.py && \
       grep -q "settings_production" Notes_API/wsgi.py; then
        test_result 0 "wsgi.py configured for production environment detection"
    else
        test_result 1 "wsgi.py not configured for production environment detection"
    fi
else
    test_result 1 "wsgi.py not found"
fi
echo ""

# Summary
echo "============================================================"
echo "TEST SUMMARY"
echo "============================================================"
TOTAL=$((PASSED + FAILED))
echo -e "Results: ${GREEN}${PASSED}${NC}/${TOTAL} tests passed"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed! Production settings are ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the configuration files"
    echo "2. Test with Django: export RENDER=true && python manage.py check"
    echo "3. Commit changes to Git"
    echo "4. Deploy to Render.com"
    exit 0
else
    echo ""
    echo -e "${RED}⚠️  ${FAILED} test(s) failed. Please fix the issues.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "- Ensure all configuration files are created"
    echo "- Check file permissions (build.sh should be executable)"
    echo "- Verify environment variables in .env.production.local"
    exit 1
fi
