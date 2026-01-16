#!/usr/bin/env python
"""
Local Production Settings Testing Script

This script validates that production settings work correctly in a local environment
before deploying to Render.com.

Usage:
    python test_production_settings.py
"""

import os
import sys
from pathlib import Path

# Add the project directory to the Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

def load_env_file(env_file='.env.production.local'):
    """Load environment variables from file"""
    env_path = BASE_DIR / env_file
    if not env_path.exists():
        print(f"❌ Error: {env_file} not found")
        print(f"   Expected location: {env_path}")
        return False
    
    from dotenv import load_dotenv
    load_dotenv(env_path)
    print(f"✅ Loaded environment from {env_file}")
    return True

def test_environment_variables():
    """Test that all required environment variables are set"""
    print("\n" + "="*60)
    print("Testing Environment Variables")
    print("="*60)
    
    required_vars = [
        'RENDER',
        'SECRET_KEY',
        'JWT_SECRET_KEY',
        'DATABASE_URL',
        'REDIS_URL',
        'ALLOWED_HOSTS',
        'EMAIL_HOST_USER',
        'EMAIL_HOST_PASSWORD',
        'OPENROUTER_API_KEY',
    ]
    
    missing_vars = []
    for var in required_vars:
        value = os.getenv(var)
        if value:
            # Mask sensitive values
            if 'KEY' in var or 'PASSWORD' in var:
                display_value = value[:10] + "..." if len(value) > 10 else "***"
            else:
                display_value = value
            print(f"✅ {var}: {display_value}")
        else:
            print(f"❌ {var}: NOT SET")
            missing_vars.append(var)
    
    if missing_vars:
        print(f"\n❌ Missing required variables: {', '.join(missing_vars)}")
        return False
    
    print("\n✅ All required environment variables are set")
    return True

def test_django_settings():
    """Test that Django settings load correctly"""
    print("\n" + "="*60)
    print("Testing Django Settings")
    print("="*60)
    
    try:
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Notes_API.settings_production')
        import django
        django.setup()
        
        from django.conf import settings
        
        # Test critical settings
        tests = [
            ('DEBUG', False, settings.DEBUG),
            ('ALLOWED_HOSTS', list, type(settings.ALLOWED_HOSTS)),
            ('DATABASES', dict, type(settings.DATABASES)),
            ('SECURE_SSL_REDIRECT', True, settings.SECURE_SSL_REDIRECT),
            ('SESSION_COOKIE_SECURE', True, settings.SESSION_COOKIE_SECURE),
            ('CSRF_COOKIE_SECURE', True, settings.CSRF_COOKIE_SECURE),
        ]
        
        all_passed = True
        for name, expected, actual in tests:
            if expected == actual or (isinstance(expected, type) and isinstance(actual, expected)):
                print(f"✅ {name}: {actual}")
            else:
                print(f"❌ {name}: Expected {expected}, got {actual}")
                all_passed = False
        
        # Check database configuration
        db_config = settings.DATABASES['default']
        print(f"\n📊 Database Configuration:")
        print(f"   Engine: {db_config.get('ENGINE', 'Not set')}")
        print(f"   Name: {db_config.get('NAME', 'Not set')}")
        
        # Check static files
        print(f"\n📁 Static Files:")
        print(f"   STATIC_URL: {settings.STATIC_URL}")
        print(f"   STATIC_ROOT: {settings.STATIC_ROOT}")
        
        if all_passed:
            print("\n✅ Django settings loaded successfully")
            return True
        else:
            print("\n❌ Some Django settings failed validation")
            return False
            
    except Exception as e:
        print(f"❌ Error loading Django settings: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_database_connection():
    """Test database connectivity"""
    print("\n" + "="*60)
    print("Testing Database Connection")
    print("="*60)
    
    try:
        from django.db import connection
        
        # Test connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            
        print(f"✅ Database connection successful")
        print(f"   Database: {connection.settings_dict['NAME']}")
        print(f"   Engine: {connection.settings_dict['ENGINE']}")
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("\n💡 Troubleshooting:")
        print("   - Ensure PostgreSQL is running locally")
        print("   - Create database: createdb smart_notes_test")
        print("   - Or use SQLite by uncommenting DATABASE_URL in .env.production.local")
        return False

def test_redis_connection():
    """Test Redis connectivity"""
    print("\n" + "="*60)
    print("Testing Redis Connection")
    print("="*60)
    
    try:
        import redis
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        
        # Parse Redis URL
        r = redis.from_url(redis_url)
        r.ping()
        
        print(f"✅ Redis connection successful")
        print(f"   URL: {redis_url}")
        return True
        
    except Exception as e:
        print(f"❌ Redis connection failed: {e}")
        print("\n💡 Troubleshooting:")
        print("   - Ensure Redis is running: redis-server")
        print("   - Or install Redis: brew install redis (macOS)")
        return False

def test_static_files():
    """Test static files collection"""
    print("\n" + "="*60)
    print("Testing Static Files Collection")
    print("="*60)
    
    try:
        from django.core.management import call_command
        from io import StringIO
        
        # Capture output
        out = StringIO()
        call_command('collectstatic', '--noinput', '--clear', stdout=out, stderr=out)
        
        output = out.getvalue()
        print(f"✅ Static files collected successfully")
        
        # Check if staticfiles directory was created
        from django.conf import settings
        static_root = Path(settings.STATIC_ROOT)
        if static_root.exists():
            file_count = len(list(static_root.rglob('*')))
            print(f"   Location: {static_root}")
            print(f"   Files collected: {file_count}")
        
        return True
        
    except Exception as e:
        print(f"❌ Static files collection failed: {e}")
        return False

def test_migrations():
    """Test database migrations"""
    print("\n" + "="*60)
    print("Testing Database Migrations")
    print("="*60)
    
    try:
        from django.core.management import call_command
        from io import StringIO
        
        # Check for unapplied migrations
        out = StringIO()
        call_command('showmigrations', '--plan', stdout=out, stderr=out)
        
        print(f"✅ Migration check completed")
        
        # Try to run migrations
        print("\n   Running migrations...")
        out = StringIO()
        call_command('migrate', '--noinput', stdout=out, stderr=out)
        
        print(f"✅ Migrations applied successfully")
        return True
        
    except Exception as e:
        print(f"❌ Migration test failed: {e}")
        return False

def test_security_settings():
    """Test security settings"""
    print("\n" + "="*60)
    print("Testing Security Settings")
    print("="*60)
    
    try:
        from django.conf import settings
        
        security_checks = [
            ('DEBUG is False', not settings.DEBUG),
            ('SECURE_SSL_REDIRECT enabled', settings.SECURE_SSL_REDIRECT),
            ('SESSION_COOKIE_SECURE enabled', settings.SESSION_COOKIE_SECURE),
            ('CSRF_COOKIE_SECURE enabled', settings.CSRF_COOKIE_SECURE),
            ('SECURE_HSTS_SECONDS set', settings.SECURE_HSTS_SECONDS > 0),
            ('X_FRAME_OPTIONS set', settings.X_FRAME_OPTIONS == 'DENY'),
        ]
        
        all_passed = True
        for check_name, result in security_checks:
            if result:
                print(f"✅ {check_name}")
            else:
                print(f"❌ {check_name}")
                all_passed = False
        
        if all_passed:
            print("\n✅ All security settings configured correctly")
            return True
        else:
            print("\n⚠️  Some security settings need attention")
            return False
            
    except Exception as e:
        print(f"❌ Security settings test failed: {e}")
        return False

def run_all_tests():
    """Run all tests"""
    print("\n" + "="*60)
    print("PRODUCTION SETTINGS LOCAL TEST")
    print("="*60)
    
    # Load environment
    if not load_env_file():
        return False
    
    # Run tests
    results = {
        'Environment Variables': test_environment_variables(),
        'Django Settings': test_django_settings(),
        'Database Connection': test_database_connection(),
        'Redis Connection': test_redis_connection(),
        'Static Files': test_static_files(),
        'Migrations': test_migrations(),
        'Security Settings': test_security_settings(),
    }
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    print(f"\n{'='*60}")
    print(f"Results: {passed}/{total} tests passed")
    print("="*60)
    
    if passed == total:
        print("\n🎉 All tests passed! Production settings are ready for deployment.")
        return True
    else:
        print(f"\n⚠️  {total - passed} test(s) failed. Please fix the issues before deploying.")
        return False

if __name__ == '__main__':
    success = run_all_tests()
    sys.exit(0 if success else 1)
