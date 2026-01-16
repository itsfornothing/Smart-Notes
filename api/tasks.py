from celery import shared_task
from .models import Note
from datetime import datetime, timezone
from django.core.mail import send_mail
from django.conf import settings


@shared_task
def send_email():
    notes_to_review = Note.objects.filter(reminder_date=datetime.now(timezone.utc).date())

    for note in notes_to_review:
        try:
            subject = "Just a Friendly Reminder: Check Your Note Today!"
            message = f"Hello ,\n\nJust a quick reminder that today's the day to check your {note.title} note! We hope it brings you some value." \
            "\n\nHave a great day!\n\nBest,\n\n\nSmart Notes."

            send_mail(subject, message, settings.EMAIL_HOST_USER, [note.owner.email])
            print(f'Email sent successfully to {note.owner.email}')
        except Exception as e:
            print(f'Error sending email: {e}')