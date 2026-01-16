from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from firebase_admin import auth
from django.contrib.auth import get_user_model

User = get_user_model()

class FirebaseAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None  # No token provided → unauthenticated (will 403 if IsAuthenticated)

        token = auth_header.split(' ')[1]

        try:
            decoded_token = auth.verify_id_token(token)
            firebase_uid = decoded_token['uid']
            email = decoded_token.get('email')
        except Exception as exc:
            raise AuthenticationFailed('Invalid or expired Firebase token')

        # Get or create the Django user
        user, created = User.objects.get_or_create(
            firebase_uid=firebase_uid,
            defaults={
                'email': email or f"{firebase_uid}@firebase.local",
                'username': firebase_uid[:30],  # Required field, truncate if needed
            }
        )

        # Sync email if it changed in Firebase
        if email and user.email != email:
            user.email = email
            user.save(update_fields=['email'])

        return (user, decoded_token)  # Crucial: return real user → authenticated!