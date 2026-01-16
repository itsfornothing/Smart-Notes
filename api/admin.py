from django.contrib import admin
from .models import Note, Category

class NoteAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_at', 'updated_at') 
    search_fields = ('title', 'content')  
    list_filter = ('created_at', 'updated_at')  

class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'description')  
    search_fields = ('name',) 


admin.site.register(Note)
admin.site.register(Category)
