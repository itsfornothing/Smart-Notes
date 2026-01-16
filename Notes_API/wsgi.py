"""
WSGI config for Notes_API project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

# Use production settings on Render, otherwise use default settings
if os.getenv('RENDER'):
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Notes_API.settings_production')
else:
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Notes_API.settings')

application = get_wsgi_application()
