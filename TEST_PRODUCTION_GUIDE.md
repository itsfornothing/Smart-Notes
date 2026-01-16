# Local Production Settings Testing Guide

This guide explains how to test production settings locally before deploying to Render.com.

## Prerequisites

Before running the tests, ensure you have:

1. **PostgreSQL installed and running** (recommended)
   ```bash
   # macOS
   brew install postgresql
   brew services start postgresql
   
   # Create test database
   createdb smart_notes_test
   ```

2. **Redis installed and running**
   ```bash
   # macOS
   brew install redis
   brew services start redis
   
   # Or start manually
   redis-server
   ```

3. **Python dependencies installed**
   ```bash
   cd Final_Proj/backend/Notes_API
   pip install -r requirements.txt
   ```

## Quick Start

### Option 1: Full Production Testing (Recommended)

Test with PostgreSQL and Redis (closest to production):

```bash
cd Final_Proj/backend/Notes_API
python test_production_settings.py
```

### Option 2: Quick Testing with SQLite

If you don't have PostgreSQL installed, you can use SQLite for quick testing:

1. Edit `.env.production.local` and uncomment the SQLite DATABASE_URL:
   ```
   # DATABASE_URL=postgresql://localhost/smart_notes_test
   DATABASE_URL=sqlite:///./db_production_test.sqlite3
   ```

2. Run the test:
   ```bash
   python test_production_settings.py
   ```

## What Gets Tested

The test script validates:

1. **Environment Variables**
   - All required variables are set
   - Values are properly formatted

2. **Django Settings**
   - Production settings load correctly
   - DEBUG is False
   - Security settings are enabled
   - Database configuration is valid

3. **Database Connection**
   - Can connect to database
   - Database engine is correct

4. **Redis Connection**
   - Can connect to Redis
   - Celery broker is accessible

5. **Static Files**
   - Static files can be collected
   - Whitenoise is configured

6. **Migrations**
   - Migrations can be applied
   - Database schema is up to date

7. **Security Settings**
   - HTTPS enforcement
   - Secure cookies
   - HSTS headers
   - XSS protection

## Understanding Test Results

### ✅ All Tests Pass

```
🎉 All tests passed! Production settings are ready for deployment.
```

Your production settings are configured correctly and ready for Render.com deployment.

### ❌ Some Tests Fail

The script will show which tests failed and provide troubleshooting tips.

Common issues:

**Database Connection Failed**
```
💡 Troubleshooting:
   - Ensure PostgreSQL is running locally
   - Create database: createdb smart_notes_test
   - Or use SQLite by uncommenting DATABASE_URL in .env.production.local
```

**Redis Connection Failed**
```
💡 Troubleshooting:
   - Ensure Redis is running: redis-server
   - Or install Redis: brew install redis (macOS)
```

## Configuration Files

### `.env.production.local`

This file simulates the production environment locally. Key settings:

- `RENDER=true` - Triggers production settings
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `ALLOWED_HOSTS` - Comma-separated list of allowed hosts
- `CORS_ALLOWED_ORIGINS` - Comma-separated list of CORS origins

### `test_production_settings.py`

The test script that validates all production settings.

## Manual Testing

After automated tests pass, you can manually test the application:

### 1. Start the Development Server with Production Settings

```bash
# Set environment variable
export RENDER=true

# Load production environment
export $(cat .env.production.local | xargs)

# Run server
python manage.py runserver
```

### 2. Test API Endpoints

```bash
# Health check
curl http://localhost:8000/admin/

# API endpoints
curl http://localhost:8000/api/notes/
```

### 3. Test Static Files

Visit `http://localhost:8000/admin/` and verify that:
- CSS loads correctly
- Images display properly
- No 404 errors in browser console

### 4. Test Celery Workers

In a separate terminal:

```bash
# Load environment
export $(cat .env.production.local | xargs)

# Start Celery worker
celery -A Notes_API worker --loglevel=info
```

### 5. Test Celery Beat

In another terminal:

```bash
# Load environment
export $(cat .env.production.local | xargs)

# Start Celery beat
celery -A Notes_API beat --loglevel=info
```

## Troubleshooting

### Issue: "Module not found" errors

**Solution:** Ensure all dependencies are installed:
```bash
pip install -r requirements.txt
```

### Issue: Database connection errors

**Solution:** Check PostgreSQL is running:
```bash
# Check status
brew services list | grep postgresql

# Start if not running
brew services start postgresql

# Create database
createdb smart_notes_test
```

### Issue: Redis connection errors

**Solution:** Check Redis is running:
```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# Start if not running
brew services start redis
```

### Issue: Static files not collecting

**Solution:** Ensure STATIC_ROOT directory is writable:
```bash
# Create directory if it doesn't exist
mkdir -p staticfiles

# Set permissions
chmod 755 staticfiles
```

### Issue: Migration errors

**Solution:** Reset migrations if needed:
```bash
# Drop and recreate database
dropdb smart_notes_test
createdb smart_notes_test

# Run migrations
python manage.py migrate
```

## Next Steps

Once all tests pass:

1. ✅ Review test results
2. ✅ Fix any failing tests
3. ✅ Commit changes to Git
4. ✅ Push to repository
5. ✅ Deploy to Render.com following the deployment guide

## Notes

- **Security:** The `.env.production.local` file contains sensitive data and should NOT be committed to Git
- **Database:** The test uses a separate database (`smart_notes_test`) to avoid affecting your development data
- **Redis:** Uses the same Redis instance as development (database 0)
- **Static Files:** Collected to `staticfiles/` directory (gitignored)

## Additional Resources

- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Render Django Deployment Guide](https://render.com/docs/deploy-django)
- [Celery Documentation](https://docs.celeryproject.org/)
