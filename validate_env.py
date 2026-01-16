#!/usr/bin/env python3
"""
Environment Variable Validation Script for Render Deployment

This script validates that all required environment variables are present
and properly formatted before deployment to Render.com.

Usage:
    python validate_env.py
    python validate_env.py --env-file .env.production.local
"""

import os
import sys
import json
import argparse
from typing import Dict, List, Tuple
from urllib.parse import urlparse


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


class EnvValidator:
    """Validates environment variables for production deployment"""
    
    # Required environment variables
    REQUIRED_VARS = {
        'SECRET_KEY': 'Django secret key for cryptographic signing',
        'JWT_SECRET_KEY': 'JWT token signing key',
        'DATABASE_URL': 'PostgreSQL database connection URL',
        'EMAIL_HOST_USER': 'Email address for sending notifications',
        'EMAIL_HOST_PASSWORD': 'Email password or app password',
        'OPENROUTER_API_KEY': 'OpenRouter API key for AI features',
    }
    
    # Optional but recommended variables
    OPTIONAL_VARS = {
        'REDIS_URL': 'Redis connection URL for Celery (required for background tasks)',
        'ALLOWED_HOSTS': 'Comma-separated list of allowed hostnames',
        'CORS_ALLOWED_ORIGINS': 'Comma-separated list of allowed CORS origins',
        'FIREBASE_CREDENTIALS': 'Firebase service account JSON (single-line string)',
        'RENDER': 'Environment detection flag (set to "true" on Render)',
    }
    
    def __init__(self, env_file: str = None):
        """Initialize validator with optional env file"""
        self.env_file = env_file
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.passed: List[str] = []
        
        # Load environment variables from file if specified
        if env_file and os.path.exists(env_file):
            self._load_env_file(env_file)
    
    def _load_env_file(self, filepath: str):
        """Load environment variables from a file"""
        print(f"{Colors.BLUE}Loading environment from: {filepath}{Colors.END}\n")
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()
    
    def validate_all(self) -> bool:
        """Run all validations and return overall success status"""
        print(f"{Colors.BOLD}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}Environment Variable Validation for Render Deployment{Colors.END}")
        print(f"{Colors.BOLD}{'='*70}{Colors.END}\n")
        
        # Validate required variables
        print(f"{Colors.BOLD}Checking Required Variables:{Colors.END}\n")
        for var, description in self.REQUIRED_VARS.items():
            self._validate_required(var, description)
        
        # Validate optional variables
        print(f"\n{Colors.BOLD}Checking Optional Variables:{Colors.END}\n")
        for var, description in self.OPTIONAL_VARS.items():
            self._validate_optional(var, description)
        
        # Run specific format validations
        print(f"\n{Colors.BOLD}Running Format Validations:{Colors.END}\n")
        self._validate_secret_key()
        self._validate_database_url()
        self._validate_redis_url()
        self._validate_email()
        self._validate_api_key()
        self._validate_firebase_credentials()
        self._validate_allowed_hosts()
        self._validate_cors_origins()
        
        # Print summary
        self._print_summary()
        
        return len(self.errors) == 0
    
    def _validate_required(self, var: str, description: str):
        """Validate that a required variable exists and is not empty"""
        value = os.getenv(var)
        if not value or value.strip() == '':
            self.errors.append(f"{var} is required but not set")
            print(f"  {Colors.RED}✗{Colors.END} {var}: {description}")
            print(f"    {Colors.RED}ERROR: Not set or empty{Colors.END}")
        else:
            self.passed.append(var)
            print(f"  {Colors.GREEN}✓{Colors.END} {var}: {description}")
    
    def _validate_optional(self, var: str, description: str):
        """Validate optional variables and warn if missing"""
        value = os.getenv(var)
        if not value or value.strip() == '':
            self.warnings.append(f"{var} is not set (optional but recommended)")
            print(f"  {Colors.YELLOW}⚠{Colors.END} {var}: {description}")
            print(f"    {Colors.YELLOW}WARNING: Not set{Colors.END}")
        else:
            self.passed.append(var)
            print(f"  {Colors.GREEN}✓{Colors.END} {var}: {description}")
    
    def _validate_secret_key(self):
        """Validate SECRET_KEY format and strength"""
        secret_key = os.getenv('SECRET_KEY', '')
        if secret_key:
            if len(secret_key) < 50:
                self.warnings.append("SECRET_KEY should be at least 50 characters long")
                print(f"  {Colors.YELLOW}⚠{Colors.END} SECRET_KEY length: {len(secret_key)} chars (recommend 50+)")
            else:
                print(f"  {Colors.GREEN}✓{Colors.END} SECRET_KEY length: {len(secret_key)} chars")
    
    def _validate_database_url(self):
        """Validate DATABASE_URL format"""
        db_url = os.getenv('DATABASE_URL', '')
        if db_url:
            try:
                parsed = urlparse(db_url)
                if parsed.scheme not in ['postgresql', 'postgres', 'sqlite']:
                    self.errors.append(f"DATABASE_URL has invalid scheme: {parsed.scheme}")
                    print(f"  {Colors.RED}✗{Colors.END} DATABASE_URL scheme: {parsed.scheme} (expected postgresql/postgres/sqlite)")
                else:
                    print(f"  {Colors.GREEN}✓{Colors.END} DATABASE_URL scheme: {parsed.scheme}")
                
                if parsed.scheme in ['postgresql', 'postgres']:
                    if not parsed.hostname:
                        self.errors.append("DATABASE_URL missing hostname")
                        print(f"  {Colors.RED}✗{Colors.END} DATABASE_URL hostname: missing")
                    else:
                        print(f"  {Colors.GREEN}✓{Colors.END} DATABASE_URL hostname: {parsed.hostname}")
            except Exception as e:
                self.errors.append(f"DATABASE_URL format invalid: {str(e)}")
                print(f"  {Colors.RED}✗{Colors.END} DATABASE_URL format: invalid")
    
    def _validate_redis_url(self):
        """Validate REDIS_URL format"""
        redis_url = os.getenv('REDIS_URL', '')
        if redis_url:
            try:
                parsed = urlparse(redis_url)
                if parsed.scheme not in ['redis', 'rediss']:
                    self.errors.append(f"REDIS_URL has invalid scheme: {parsed.scheme}")
                    print(f"  {Colors.RED}✗{Colors.END} REDIS_URL scheme: {parsed.scheme} (expected redis/rediss)")
                else:
                    print(f"  {Colors.GREEN}✓{Colors.END} REDIS_URL scheme: {parsed.scheme}")
            except Exception as e:
                self.errors.append(f"REDIS_URL format invalid: {str(e)}")
                print(f"  {Colors.RED}✗{Colors.END} REDIS_URL format: invalid")
    
    def _validate_email(self):
        """Validate email configuration"""
        email_user = os.getenv('EMAIL_HOST_USER', '')
        email_pass = os.getenv('EMAIL_HOST_PASSWORD', '')
        
        if email_user and '@' not in email_user:
            self.warnings.append("EMAIL_HOST_USER doesn't appear to be a valid email")
            print(f"  {Colors.YELLOW}⚠{Colors.END} EMAIL_HOST_USER format: may be invalid (no @ symbol)")
        elif email_user:
            print(f"  {Colors.GREEN}✓{Colors.END} EMAIL_HOST_USER format: appears valid")
        
        if email_pass and len(email_pass) < 8:
            self.warnings.append("EMAIL_HOST_PASSWORD seems too short")
            print(f"  {Colors.YELLOW}⚠{Colors.END} EMAIL_HOST_PASSWORD length: {len(email_pass)} chars (seems short)")
        elif email_pass:
            print(f"  {Colors.GREEN}✓{Colors.END} EMAIL_HOST_PASSWORD: set")
    
    def _validate_api_key(self):
        """Validate OPENROUTER_API_KEY format"""
        api_key = os.getenv('OPENROUTER_API_KEY', '')
        if api_key:
            if not api_key.startswith('sk-or-v1-'):
                self.warnings.append("OPENROUTER_API_KEY doesn't match expected format")
                print(f"  {Colors.YELLOW}⚠{Colors.END} OPENROUTER_API_KEY format: unexpected (should start with 'sk-or-v1-')")
            else:
                print(f"  {Colors.GREEN}✓{Colors.END} OPENROUTER_API_KEY format: valid")
    
    def _validate_firebase_credentials(self):
        """Validate FIREBASE_CREDENTIALS JSON format"""
        firebase_creds = os.getenv('FIREBASE_CREDENTIALS', '')
        if firebase_creds:
            try:
                cred_dict = json.loads(firebase_creds)
                required_keys = ['type', 'project_id', 'private_key', 'client_email']
                missing_keys = [key for key in required_keys if key not in cred_dict]
                
                if missing_keys:
                    self.errors.append(f"FIREBASE_CREDENTIALS missing keys: {', '.join(missing_keys)}")
                    print(f"  {Colors.RED}✗{Colors.END} FIREBASE_CREDENTIALS: missing keys {missing_keys}")
                else:
                    print(f"  {Colors.GREEN}✓{Colors.END} FIREBASE_CREDENTIALS: valid JSON with required keys")
            except json.JSONDecodeError:
                self.errors.append("FIREBASE_CREDENTIALS is not valid JSON")
                print(f"  {Colors.RED}✗{Colors.END} FIREBASE_CREDENTIALS: invalid JSON format")
    
    def _validate_allowed_hosts(self):
        """Validate ALLOWED_HOSTS format"""
        allowed_hosts = os.getenv('ALLOWED_HOSTS', '')
        if allowed_hosts:
            hosts = [h.strip() for h in allowed_hosts.split(',') if h.strip()]
            if not hosts:
                self.warnings.append("ALLOWED_HOSTS is set but empty after parsing")
                print(f"  {Colors.YELLOW}⚠{Colors.END} ALLOWED_HOSTS: empty after parsing")
            else:
                print(f"  {Colors.GREEN}✓{Colors.END} ALLOWED_HOSTS: {len(hosts)} host(s) configured")
                for host in hosts:
                    print(f"    - {host}")
    
    def _validate_cors_origins(self):
        """Validate CORS_ALLOWED_ORIGINS format"""
        cors_origins = os.getenv('CORS_ALLOWED_ORIGINS', '')
        if cors_origins:
            origins = [o.strip() for o in cors_origins.split(',') if o.strip()]
            if not origins:
                self.warnings.append("CORS_ALLOWED_ORIGINS is set but empty after parsing")
                print(f"  {Colors.YELLOW}⚠{Colors.END} CORS_ALLOWED_ORIGINS: empty after parsing")
            else:
                print(f"  {Colors.GREEN}✓{Colors.END} CORS_ALLOWED_ORIGINS: {len(origins)} origin(s) configured")
                for origin in origins:
                    if not origin.startswith(('http://', 'https://')):
                        self.warnings.append(f"CORS origin '{origin}' should start with http:// or https://")
                        print(f"    {Colors.YELLOW}⚠{Colors.END} {origin} (should start with http:// or https://)")
                    else:
                        print(f"    {Colors.GREEN}✓{Colors.END} {origin}")
    
    def _print_summary(self):
        """Print validation summary"""
        print(f"\n{Colors.BOLD}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}Validation Summary{Colors.END}")
        print(f"{Colors.BOLD}{'='*70}{Colors.END}\n")
        
        print(f"{Colors.GREEN}✓ Passed:{Colors.END} {len(self.passed)} checks")
        print(f"{Colors.YELLOW}⚠ Warnings:{Colors.END} {len(self.warnings)} issues")
        print(f"{Colors.RED}✗ Errors:{Colors.END} {len(self.errors)} critical issues\n")
        
        if self.warnings:
            print(f"{Colors.YELLOW}{Colors.BOLD}Warnings:{Colors.END}")
            for warning in self.warnings:
                print(f"  {Colors.YELLOW}⚠{Colors.END} {warning}")
            print()
        
        if self.errors:
            print(f"{Colors.RED}{Colors.BOLD}Errors:{Colors.END}")
            for error in self.errors:
                print(f"  {Colors.RED}✗{Colors.END} {error}")
            print()
        
        if len(self.errors) == 0:
            print(f"{Colors.GREEN}{Colors.BOLD}✓ All required environment variables are valid!{Colors.END}")
            print(f"{Colors.GREEN}Your application is ready for deployment to Render.{Colors.END}\n")
        else:
            print(f"{Colors.RED}{Colors.BOLD}✗ Validation failed!{Colors.END}")
            print(f"{Colors.RED}Please fix the errors above before deploying.{Colors.END}\n")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Validate environment variables for Render deployment'
    )
    parser.add_argument(
        '--env-file',
        type=str,
        help='Path to environment file to load (e.g., .env.production.local)'
    )
    
    args = parser.parse_args()
    
    validator = EnvValidator(env_file=args.env_file)
    success = validator.validate_all()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
