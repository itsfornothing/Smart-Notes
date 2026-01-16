from rest_framework.test import APITestCase
from django.urls import reverse
from .models import Note, Category
from django.contrib.auth.models import User
from datetime import datetime, timedelta, timezone
from django.conf import settings
import jwt


# Create your tests here.
def generate_token(user):
    payload = {
        'user_id': user.id,
        'username': user.username,
        'exp': datetime.now(timezone.utc) + timedelta(hours=24),
        'iat': datetime.now(timezone.utc),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token

class JWTAuthentication:
    def authenticate(self, request):
        auth_header = request.headers.get('token')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None
        token = auth_header.split(' ')[1]
        try:
            payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
            user = User.objects.get(id=payload['user_id'])
            return (user, token)
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
            return None
        
    def authenticate_header(self, request):
        return 'Bearer'

class NoteApiTest(APITestCase):
    def setUp(self):
        self.test_user = User.objects.create_user(email="kalidmohamed9321@gmail.com", username="itsforsmth", password="hellnaaah123")
        self.category = Category.objects.create(name='ALX', owner=self.test_user)
        self.note = Note.objects.create(
            title='DRF',
            owner = self.test_user,
            category = self.category,
            tags = ['alx'],
            content = "Methods which create a request body, such as post, put and patch, include a format argument, which make it easy to generate requests using a wide set of request formats. When using this argument, the factory will select an appropriate renderer and its configured content_type.",
            reminder_date = '2025-03-20'
        )
        self.url = reverse('note_by_id', kwargs={"note_id": self.note.pk})
        self.token = generate_token(self.test_user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Bearer {self.token}'



    def test_get_note(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['title'], self.note.title)
