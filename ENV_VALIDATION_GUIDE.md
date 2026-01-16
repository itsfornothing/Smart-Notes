# Environment Variable Validation Guide

This guide explains how to validate your environment variables before deploying to Render.com.

---

## Overview

The `validate_env.py` script checks that all required environment variables are:
- Present and not empty
- Properly formatted
- Meet security requirements

This helps catch configuration errors before deployment, saving time and preventing runtime issues.

---

## Quick Start

### Validate Current Environment

```bash
python validate_env.py
```

### Validate Environment File

```bash
python validate_env.py --env-file .env.production.local
```

---

## Required Environment Variables

The following variables **must** be set for the application to work:

| Variable | Description | Example |
|----------|-------------|---------|
| `SECRET_KEY` | Django secret key (50+ chars) | `dhjfalkjwhfer@*&#Y32972y91473...` |
| `JWT_SECRET_KEY` | JWT token signing key | `jakFDBHJKWHAHA123$#@dhfbhkajw...` |
| `DATABASE_URL` | PostgreSQL connection URL | `postgresql://user:pass@host/db` |
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379/0` |
| `EMAIL_HOST_USER` | Email address for notifications | `your-email@gmail.com` |
| `EMAIL_HOST_PASSWORD` | Email password or app password | `your-app-password` |
| `OPENROUTER_API_KEY` | OpenRouter API key | `sk-or-v1-...` |

---

## Optional Environment Variables

These variables are optional but recommended:

| Variable | Description | Default |
|----------|-------------|---------|
| `ALLOWED_HOSTS` | Comma-separated hostnames | `.onrender.com` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated CORS origins | Empty (no CORS) |
| `FIREBASE_CREDENTIALS` | Firebase service account JSON | None |
| `RENDER` | Environment detection flag | `false` |

---

## Validation Checks

### 1. Presence Check
- Verifies all required variables are set
- Checks that values are not empty

### 2. Format Validation

#### SECRET_KEY
- ✓ Should be at least 50 characters long
- ✓ Should contain mixed characters (letters, numbers, symbols)

#### DATABASE_URL
- ✓ Must start with `postgresql://`, `postgres://`, or `sqlite://`
- ✓ Must include hostname for PostgreSQL
- ✓ Format: `postgresql://user:password@host:port/database`

#### REDIS_URL
- ✓ Must start with `redis://` or `rediss://`
- ✓ Format: `redis://host:port/db`

#### EMAIL_HOST_USER
- ✓ Should contain `@` symbol (valid email format)

#### EMAIL_HOST_PASSWORD
- ✓ Should be at least 8 characters
- ✓ For Gmail, use an App Password (not your account password)

#### OPENROUTER_API_KEY
- ✓ Should start with `sk-or-v1-`

#### FIREBASE_CREDENTIALS
- ✓ Must be valid JSON
- ✓ Must contain required keys: `type`, `project_id`, `private_key`, `client_email`

#### ALLOWED_HOSTS
- ✓ Comma-separated list of hostnames
- ✓ Example: `localhost,127.0.0.1,myapp.onrender.com`

#### CORS_ALLOWED_ORIGINS
- ✓ Comma-separated list of URLs
- ✓ Each origin should start with `http://` or `https://`
- ✓ Example: `https://myapp.com,https://www.myapp.com`

---

## Usage Examples

### Example 1: Validate Before Deployment

```bash
# Load production environment and validate
python validate_env.py --env-file .env.production.local
```

### Example 2: Validate Render Environment

On Render, the environment variables are set in the dashboard. To validate them:

1. SSH into your Render service (if available)
2. Run: `python validate_env.py`

Or check the logs during deployment - the build script can include validation.

### Example 3: Add to Build Script

Add validation to your `build.sh`:

```bash
#!/usr/bin/env bash
set -o errexit

# Validate environment variables
echo "Validating environment variables..."
python validate_env.py || exit 1

# Continue with build
pip install --upgrade pip
pip install -r requirements.txt
python manage.py collectstatic --no-input
python manage.py migrate
```

---

## Understanding Output

### Success Output

```
======================================================================
Environment Variable Validation for Render Deployment
======================================================================

Checking Required Variables:

  ✓ SECRET_KEY: Django secret key for cryptographic signing
  ✓ JWT_SECRET_KEY: JWT token signing key
  ✓ DATABASE_URL: PostgreSQL database connection URL
  ...

✓ All required environment variables are valid!
Your application is ready for deployment to Render.
```

### Warning Output

```
Warnings:
  ⚠ FIREBASE_CREDENTIALS is not set (optional but recommended)
  ⚠ SECRET_KEY should be at least 50 characters long
```

Warnings indicate potential issues but won't prevent deployment.

### Error Output

```
Errors:
  ✗ SECRET_KEY is required but not set
  ✗ DATABASE_URL has invalid scheme: mysql

✗ Validation failed!
Please fix the errors above before deploying.
```

Errors indicate critical issues that must be fixed before deployment.

---

## Common Issues and Solutions

### Issue: "SECRET_KEY is required but not set"

**Solution**: Generate a strong secret key:

```python
from django.core.management.utils import get_random_secret_key
print(get_random_secret_key())
```

Or use Render's "Generate" button in the environment variables section.

### Issue: "DATABASE_URL has invalid scheme: mysql"

**Solution**: Render uses PostgreSQL, not MySQL. Update your DATABASE_URL:

```bash
# Wrong (MySQL)
DATABASE_URL=mysql://user:pass@host/db

# Correct (PostgreSQL)
DATABASE_URL=postgresql://user:pass@host/db
```

### Issue: "REDIS_URL format invalid"

**Solution**: Ensure proper Redis URL format:

```bash
# Correct format
REDIS_URL=redis://localhost:6379/0

# With authentication
REDIS_URL=redis://:password@host:6379/0
```

### Issue: "FIREBASE_CREDENTIALS is not valid JSON"

**Solution**: Convert your `serviceAccountKey.json` to a single-line string:

```bash
# On macOS/Linux
cat serviceAccountKey.json | tr -d '\n' | tr -d ' '

# Or use Python
python -c "import json; print(json.dumps(json.load(open('serviceAccountKey.json'))))"
```

### Issue: "CORS origin should start with http:// or https://"

**Solution**: Add protocol to CORS origins:

```bash
# Wrong
CORS_ALLOWED_ORIGINS=myapp.com,www.myapp.com

# Correct
CORS_ALLOWED_ORIGINS=https://myapp.com,https://www.myapp.com
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Validate Environment

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      - name: Validate Environment
        env:
          SECRET_KEY: ${{ secrets.SECRET_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          # ... other secrets
        run: |
          cd Final_Proj/backend/Notes_API
          python validate_env.py
```

---

## Best Practices

### 1. Validate Early
Run validation before committing changes to catch issues early.

### 2. Use Environment Files
Keep separate environment files for different stages:
- `.env` - Local development
- `.env.production.local` - Local production testing
- Render Dashboard - Production deployment

### 3. Never Commit Secrets
Add environment files to `.gitignore`:

```gitignore
.env
.env.local
.env.production.local
*.env
```

### 4. Use Strong Keys
- Generate random keys for SECRET_KEY and JWT_SECRET_KEY
- Use at least 50 characters
- Include mixed characters (letters, numbers, symbols)

### 5. Secure Email Credentials
- For Gmail, use App Passwords (not your account password)
- Enable 2-Factor Authentication
- Generate app-specific passwords

### 6. Document Required Variables
Keep a checklist of required variables for your team:

```markdown
## Required Environment Variables Checklist

- [ ] SECRET_KEY (generated)
- [ ] JWT_SECRET_KEY (generated)
- [ ] DATABASE_URL (from Render PostgreSQL)
- [ ] REDIS_URL (from Render Redis)
- [ ] EMAIL_HOST_USER (Gmail address)
- [ ] EMAIL_HOST_PASSWORD (Gmail app password)
- [ ] OPENROUTER_API_KEY (from OpenRouter dashboard)
- [ ] FIREBASE_CREDENTIALS (from Firebase console)
- [ ] ALLOWED_HOSTS (your-app.onrender.com)
- [ ] CORS_ALLOWED_ORIGINS (your frontend URLs)
```

---

## Troubleshooting

### Script Won't Run

**Issue**: Permission denied

**Solution**:
```bash
chmod +x validate_env.py
```

### Import Errors

**Issue**: Module not found

**Solution**: Ensure you're in the correct directory and Python environment:
```bash
cd Final_Proj/backend/Notes_API
python validate_env.py
```

### Environment File Not Found

**Issue**: File doesn't exist

**Solution**: Check the file path:
```bash
ls -la .env.production.local
python validate_env.py --env-file .env.production.local
```

---

## Additional Resources

- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Render Environment Variables](https://render.com/docs/environment-variables)
- [12-Factor App Config](https://12factor.net/config)
- [OWASP Secure Configuration](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)

---

## Support

If you encounter issues with environment validation:

1. Check the error messages carefully
2. Review this guide for solutions
3. Verify your environment file format
4. Test with the local production environment first
5. Check Render service logs for deployment issues

For Render-specific issues, contact [Render Support](https://render.com/support).
