#!/usr/bin/env bash
# exit on error
set -o errexit

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

# Validate environment variables before proceeding
echo "Validating environment variables..."
python validate_env.py || {
    echo "Environment validation failed! Please check your environment variables."
    exit 1
}

# Collect static files
python manage.py collectstatic --no-input

# Run database migrations
python manage.py migrate
