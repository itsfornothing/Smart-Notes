from django.urls import path
from .views import CreateNoteView, NoteDetailView, NoteCategorySearchView, CategoryView, NoteTagSearchView, ProfileView, ReminderView, DraftView, VersionHistoryView, SearchByTagView, SearchByCategoryView

urlpatterns = [
    path('notes', CreateNoteView.as_view(), name='notes'),
    path('note/<int:pk>/', NoteDetailView.as_view(), name='note_detail'),  
    path('notes/search/category/<str:category>', NoteCategorySearchView.as_view(), name='search_by_category'),
    path('categories', CategoryView.as_view(), name='categories'),
    path('notes/bulkdelete/tag/<str:tag>', NoteTagSearchView.as_view(), name='delete_by_tag'),
    path('notes/bulkdelete/category/<str:category>', NoteCategorySearchView.as_view(), name='delete_by_category'),
    path('setting/', ProfileView.as_view(), name='setting'),
    path('reminders/', ReminderView.as_view(), name='reminders'),
    path('notes/<int:note_id>/draft/', DraftView.as_view()),
    path('notes/<int:note_id>/versions/', VersionHistoryView.as_view()),
    path('notes/<int:note_id>/restore/', VersionHistoryView.as_view()),
    path('notes/search/tag/<str:tag_name>/', SearchByTagView.as_view(), name='search-by-tag'),
    path('notes/search/category/<str:category_name>/', SearchByCategoryView.as_view(), name='search-by-category'),
]