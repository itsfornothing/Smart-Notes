# Environment Variables Quick Reference

Quick reference for all environment variables needed for Render deployment.

---

## Required Variables

Copy these to your Render service environment variables:

```bash
# Django Security
SECRET_KEY=<click Generate button on Render>
JWT_SECRET_KEY=<click Generate button on Render>

# Database (from Render PostgreSQL service)
DATABASE_URL=<paste Internal Database URL>

# Redis (from Render Redis service)
REDIS_URL=<paste Redis URL>

# Email Configuration
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=<Gmail App Password>

# API Keys
OPENROUTER_API_KEY=sk-or-v1-<your-key>

# Environment Detection
RENDER=true
```

---

## Optional Variables

```bash
# Allowed Hosts (comma-separated)
ALLOWED_HOSTS=your-app.onrender.com,www.your-app.com

# CORS Origins (comma-separated, with protocol)
CORS_ALLOWED_ORIGINS=https://your-frontend.com,https://www.your-frontend.com

# Firebase Credentials (single-line JSON string)
FIREBASE_CREDENTIALS={"type":"service_account","project_id":"..."}
```

---

## How to Get Each Variable

### SECRET_KEY & JWT_SECRET_KEY
1. On Render, click "Generate" button next to the variable
2. Or generate locally:
   ```python
   from django.core.management.utils import get_random_secret_key
   print(get_random_secret_key())
   ```

### DATABASE_URL
1. Create PostgreSQL database on Render
2. Copy "Internal Database URL" from database dashboard
3. Format: `postgresql://user:password@host:port/database`

### REDIS_URL
1. Create Redis instance on Render
2. Copy "Redis URL" from Redis dashboard
3. Format: `redis://host:port`

### EMAIL_HOST_USER & EMAIL_HOST_PASSWORD
1. Use your Gmail address for EMAIL_HOST_USER
2. For EMAIL_HOST_PASSWORD:
   - Go to Google Account → Security
   - Enable 2-Step Verification
   - Generate App Password
   - Use the 16-character password

### OPENROUTER_API_KEY
1. Sign up at [OpenRouter](https://openrouter.ai/)
2. Go to API Keys section
3. Create new API key
4. Format: `sk-or-v1-...`

### FIREBASE_CREDENTIALS
1. Download `serviceAccountKey.json` from Firebase Console
2. Convert to single-line string:
   ```bash
   cat serviceAccountKey.json | tr -d '\n' | tr -d ' '
   ```
3. Or use Python:
   ```python
   import json
   with open('serviceAccountKey.json') as f:
       print(json.dumps(json.load(f)))
   ```

### ALLOWED_HOSTS
- Your Render service URL: `your-app.onrender.com`
- Custom domains (if any): `www.your-domain.com`
- Comma-separated, no spaces

### CORS_ALLOWED_ORIGINS
- Your frontend URLs with protocol
- Example: `https://your-app.com,https://www.your-app.com`
- Must include `https://` or `http://`

---

## Validation

Before deploying, validate your environment:

```bash
# Validate local environment file
python validate_env.py --env-file .env.production.local

# Validate current environment
python validate_env.py
```

---

## Environment File Template

Create `.env.production.local` for local testing:

```bash
# Environment Detection
RENDER=true

# Security Keys
SECRET_KEY=your-secret-key-here
JWT_SECRET_KEY=your-jwt-secret-key-here

# Database (use SQLite for local testing)
DATABASE_URL=sqlite:///./db_production_test.sqlite3

# Redis
REDIS_URL=redis://localhost:6379/0

# Django Settings
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080

# Email
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# API Keys
OPENROUTER_API_KEY=sk-or-v1-your-key

# Firebase (optional for local testing)
FIREBASE_CREDENTIALS=
```

---

## Common Mistakes

### ❌ Wrong: Missing Protocol in CORS
```bash
CORS_ALLOWED_ORIGINS=myapp.com
```

### ✅ Correct: Include Protocol
```bash
CORS_ALLOWED_ORIGINS=https://myapp.com
```

---

### ❌ Wrong: Using MySQL URL
```bash
DATABASE_URL=mysql://user:pass@host/db
```

### ✅ Correct: Use PostgreSQL URL
```bash
DATABASE_URL=postgresql://user:pass@host/db
```

---

### ❌ Wrong: Multi-line Firebase Credentials
```bash
FIREBASE_CREDENTIALS={
  "type": "service_account",
  "project_id": "..."
}
```

### ✅ Correct: Single-line JSON
```bash
FIREBASE_CREDENTIALS={"type":"service_account","project_id":"..."}
```

---

### ❌ Wrong: Spaces in Comma-separated Lists
```bash
ALLOWED_HOSTS=localhost, 127.0.0.1, myapp.com
```

### ✅ Correct: No Spaces
```bash
ALLOWED_HOSTS=localhost,127.0.0.1,myapp.com
```

---

## Security Checklist

- [ ] SECRET_KEY is at least 50 characters
- [ ] JWT_SECRET_KEY is unique and random
- [ ] DATABASE_URL uses PostgreSQL (not MySQL)
- [ ] EMAIL_HOST_PASSWORD is an App Password (not account password)
- [ ] FIREBASE_CREDENTIALS is properly formatted JSON
- [ ] CORS_ALLOWED_ORIGINS includes only trusted domains
- [ ] All sensitive values are stored in Render (not in code)
- [ ] .env files are in .gitignore

---

## Testing

Test your environment configuration locally:

```bash
# 1. Create .env.production.local with your variables
# 2. Validate the environment
python validate_env.py --env-file .env.production.local

# 3. Test with production settings
RENDER=true python manage.py check --deploy

# 4. Test database connection
RENDER=true python manage.py migrate --dry-run

# 5. Test static files collection
RENDER=true python manage.py collectstatic --dry-run --no-input
```

---

## Deployment Checklist

Before deploying to Render:

1. [ ] All required variables are set in Render dashboard
2. [ ] Environment validation passes locally
3. [ ] Database URL is from Render PostgreSQL
4. [ ] Redis URL is from Render Redis
5. [ ] Email credentials are tested
6. [ ] CORS origins include your frontend URL
7. [ ] ALLOWED_HOSTS includes your Render URL
8. [ ] Firebase credentials are properly formatted
9. [ ] All secrets are secured (not in code)
10. [ ] Build script includes validation

---

## Need Help?

- Run validation: `python validate_env.py --env-file .env.production.local`
- Check guide: `ENV_VALIDATION_GUIDE.md`
- Review deployment guide: `../RENDER_DEPLOYMENT_GUIDE.md`
- Check Render logs for deployment errors
