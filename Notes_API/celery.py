import os
from celery import Celery
from celery.schedules import crontab


os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Notes_API.settings')
app = Celery('Notes_API')

app.conf.beat_schedule = {
    'send_email_to_remind': {
        'task': 'api.tasks.send_email',
        'schedule': crontab(hour=7, minute=00
        ),  
    },
    
}

app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
