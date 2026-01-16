from django.db import models
from django.contrib.auth.models import AbstractUser

class customuser(AbstractUser):  # Consider renaming to CustomUser (capitalized)
    username = models.CharField(max_length=100, unique=True, null=True, blank=True)
    email = models.EmailField(unique=True, null=False, blank=False, db_index=True)
    firebase_uid = models.CharField(max_length=128, unique=True, null=True, blank=True)  # New field
    date_joined = models.DateTimeField(auto_now_add=True)
    profile_url = models.URLField(max_length=1250, blank=True, null=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    def __str__(self):
        return self.email or self.firebase_uid or 'Anonymous'


class Category(models.Model):
    name = models.CharField(max_length=50)
    owner = models.ForeignKey('customuser', on_delete=models.CASCADE, related_name='categories')


class Note(models.Model):
    title = models.CharField(max_length=255, unique=False)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    tags = models.JSONField(default=list)
    content = models.TextField()
    summary = models.TextField(blank=True)
    reminder_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    owner = models.ForeignKey('customuser', on_delete=models.CASCADE, related_name='notes')
    is_favorite = models.BooleanField(default=False)


class NoteVersion(models.Model):
    note = models.ForeignKey(Note, on_delete=models.CASCADE, related_name='versions')
    title = models.CharField(max_length=255)
    content = models.TextField()  # Stored as Quill Delta JSON string
    tags = models.JSONField(default=list)
    summary = models.TextField(blank=True)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    reminder_date = models.DateField(null=True, blank=True)
    is_favorite = models.BooleanField(default=False)
    version_number = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_draft = models.BooleanField(default=False)  # Flag for auto-saved drafts

    class Meta:
        ordering = ['-created_at']
        unique_together = ['note', 'version_number']

    def __str__(self):
        return f"{self.note.title} v{self.version_number} {'(Draft)' if self.is_draft else ''}"