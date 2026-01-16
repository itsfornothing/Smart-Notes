import jwt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import datetime, timedelta
from django.utils import timezone  
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from .serializers import NoteSerializer, CategorySerializer, ProfileSerializer, NoteVersionSerializer  
from .models import Note, Category, NoteVersion
from .authentication import FirebaseAuthentication


def generate_token(user):
    expire_time = datetime.now(timezone.UTC) + timedelta(days=7)
    payload = {
        'user_id': user.id,
        'username': user.username,
        'exp': expire_time,
        'iat': datetime.now(timezone.UTC),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, expire_time

class CreateNoteView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = NoteSerializer(data=request.data, context={'request': request})

        if serializer.is_valid():
            serializer.save(owner=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def get(self, request):
        
        all_notes = Note.objects.filter(owner=request.user)
        serializer = NoteSerializer(all_notes, many=True, context={'request': request}) 

        return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)

class NoteDetailView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            note = Note.objects.get(pk=pk, owner=request.user)
            serializer = NoteSerializer(note, context={'request': request})
            return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)
        except Note.DoesNotExist:
            return Response({"status": "error", "message": "Note not found"}, status=status.HTTP_404_NOT_FOUND)
    
    def put(self, request, pk):
        try:
            note = Note.objects.get(pk=pk, owner=request.user)
            serializer = NoteSerializer(note, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data, status=status.HTTP_200_OK)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Note.DoesNotExist:
            return Response({"status": "error", "message": "Note not found"}, status=status.HTTP_404_NOT_FOUND)
        
    def delete(self, request, pk):
        try:
            note = Note.objects.get(pk=pk, owner=request.user)
            note.delete()  # This deletes the note and its reminder_date
            return Response({"status": "success", 'msg': 'Note deleted successfully'}, status=status.HTTP_204_NO_CONTENT)
        except Note.DoesNotExist:
            return Response({"status": "error", "message": "Note not found"}, status=status.HTTP_404_NOT_FOUND)
        
class NoteCategorySearchView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NoteSerializer

    def get(self, request, category):
        try:
            note = Note.objects.filter(category__name__icontains=category, category__owner=request.user)
            serializer = NoteSerializer(note, many=True, context={'request': request})

            return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)
        
        except Note.DoesNotExist:
            return Response({"status": "error", "message": f"Notes with {category} category not found"}, status=status.HTTP_404_NOT_FOUND)
        

    def delete(self, request, category):
        try:
            note = Note.objects.filter(category__name__icontains=category, category__owner=request.user)
            if note.exists():
                note.delete()
                return Response({"status": "success", 'msg': 'Note deleted successfully'}, status=status.HTTP_204_NO_CONTENT)

        except Note.DoesNotExist:
            return Response({"status": "error", "message": f"Notes with {category} category not found"}, status=status.HTTP_404_NOT_FOUND)


class CategoryView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        all_categories = Category.objects.filter(owner=request.user)
        serializer = CategorySerializer(all_categories, many=True, context={'request': request}) 

        if not all_categories.exists():
            return Response({"status": "empty", "message": "No categories found."}, status=status.HTTP_204_NO_CONTENT)
        else:
            return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)

class NoteTagSearchView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NoteSerializer

    def delete(self, request, tag):
        try:
            note = Note.objects.filter(tags__contains=[tag], owner=request.user)
            if note.exists():
                note.delete()
                return Response({"status": "success", 'msg': 'Note deleted successfully'}, status=status.HTTP_204_NO_CONTENT)

        except Note.DoesNotExist:
            return Response({"status": "error", "message": f"Notes with {tag} tag not found"}, status=status.HTTP_404_NOT_FOUND)
        

class ProfileView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]
    def get(self, request):
        serializer = ProfileSerializer(request.user)
        return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = ProfileSerializer(
            request.user,
            data=request.data,
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)
        return Response({"status": "error", "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
    

class ReminderView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        now = timezone.now()
        today = now.date()
        tomorrow = today + timedelta(days=1)

        notes_with_reminders = Note.objects.filter(
            owner=request.user,
            reminder_date__isnull=False
        ).order_by('reminder_date', 'created_at')

        todays = notes_with_reminders.filter(reminder_date=today)
        tomorrows = notes_with_reminders.filter(reminder_date=tomorrow)
        overdues = notes_with_reminders.filter(reminder_date__lt=today)
        scheduleds = notes_with_reminders.filter(reminder_date__gt=tomorrow)

        serializer_context = {'request': request}
        return Response({
            'todays': NoteSerializer(todays, many=True, context=serializer_context).data,
            'tomorrows': NoteSerializer(tomorrows, many=True, context=serializer_context).data,
            'overdues': NoteSerializer(overdues, many=True, context=serializer_context).data,
            'scheduleds': NoteSerializer(scheduleds, many=True, context=serializer_context).data,
        }, status=status.HTTP_200_OK)
    

class DraftView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, note_id=None):
        data = request.data
        try:
            if note_id:
                note = Note.objects.get(id=note_id, owner=request.user)
                # Get next version number
                next_version = note.versions.count() + 1
                # Create draft version
                version = NoteVersion.objects.create(
                    note=note,
                    title=data.get('title', note.title),
                    content=data.get('content', note.content),
                    tags=data.get('tags', note.tags),
                    summary=data.get('summary', note.summary),
                    category_id=data.get('category_id', note.category_id),
                    reminder_date=data.get('reminder_date', note.reminder_date),
                    is_favorite=data.get('is_favorite', note.is_favorite),
                    version_number=next_version,
                    is_draft=True
                )
                serializer = NoteVersionSerializer(version)
                return Response({
                    'status': 'success',
                    'data': serializer.data
                }, status=status.HTTP_201_CREATED)
            else:
                # For new notes, perhaps create a temp note or handle differently
                return Response({'status': 'error', 'message': 'Note ID required for drafts'}, status=status.HTTP_400_BAD_REQUEST)
        except Note.DoesNotExist:
            return Response({'status': 'error', 'message': 'Note not found'}, status=status.HTTP_404_NOT_FOUND)

class VersionHistoryView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, note_id):
        try:
            note = Note.objects.get(id=note_id, owner=request.user)
            versions = note.versions.all().order_by('-created_at')[:20]  # Last 20 versions
            serializer = NoteVersionSerializer(versions, many=True)
            return Response({
                'status': 'success',
                'data': serializer.data
            })
        except Note.DoesNotExist:
            return Response({'status': 'error', 'message': 'Note not found'}, status=status.HTTP_404_NOT_FOUND)

    def post(self, request, note_id):  # Restore specific version
        version_id = request.data.get('version_id')
        try:
            version = NoteVersion.objects.get(id=version_id, note_id=note_id, note__owner=request.user)
            note = version.note
            # Restore fields
            note.title = version.title
            note.content = version.content
            note.tags = version.tags
            note.summary = version.summary
            note.category = version.category
            note.reminder_date = version.reminder_date
            note.is_favorite = version.is_favorite
            note.save()
            # Create new version after restore
            NoteVersion.objects.create(
                note=note,
                title=note.title,
                content=note.content,
                # ... copy all fields ...
                version_number=note.versions.count() + 1,
                is_draft=False
            )
            return Response({'status': 'success', 'message': 'Version restored'})
        except NoteVersion.DoesNotExist:
            return Response({'status': 'error', 'message': 'Version not found'}, status=status.HTTP_404_NOT_FOUND)
        
# ADD THESE TWO CLASSES to views.py

class SearchByTagView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, tag_name):
        try:
            # Case-insensitive search within the tags JSONField.
            notes = Note.objects.filter(
                owner=request.user, 
                tags__contains=[tag_name.lower()] 
            ).order_by('-updated_at')
            
            serializer = NoteSerializer(notes, many=True, context={'request': request})
            return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"status": "error", "message": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class SearchByCategoryView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, tag_name):
        try:
            received_tag = tag_name  # what came in the URL
            cleaned_tag = tag_name.strip().lower()

            print(f"[DEBUG] Received tag in URL: '{received_tag}'")
            print(f"[DEBUG] Cleaned tag: '{cleaned_tag}'")

            notes = Note.objects.filter(
                owner=request.user,
                tags__contains=[cleaned_tag]
            ).order_by('-updated_at')

            print(f"[DEBUG] Found {notes.count()} matching notes")

            serializer = NoteSerializer(notes, many=True, context={'request': request})
            
            return Response({
                "status": "success",
                "searched_tag_raw": received_tag,
                "searched_tag_cleaned": cleaned_tag,
                "found_count": notes.count(),
                "data": serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({"status": "error", "message": str(e)}, status=500)