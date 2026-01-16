from rest_framework import serializers
from .models import Note, Category, customuser, NoteVersion
from datetime import datetime
from django.utils import timezone
from dotenv import load_dotenv
import os
import requests
import json

load_dotenv(dotenv_path='/Users/user/Desktop/ALX_Backend/finale/ALX_Capstone/Notes_API/.env')

class RegisterationSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(required=True)
    username = serializers.CharField(required=True)
    password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = customuser
        fields = ['email', 'username', 'password']

    def validate(self, data):
        if customuser.objects.filter(username=data['username']).exists():
            raise serializers.ValidationError({'username': 'Username already exists'})
        
        if customuser.objects.filter(email=data['email']).exists():  # ← Add this
            raise serializers.ValidationError({'email': 'Email already exists'})
    
        return data
    
    def create(self, validated_data):
        user = customuser.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'])
        user.set_password(validated_data['password'])
        user.save()
        return user
    

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, required=True)

    def validate(self, data):
        email = data.get('email')
        password = data.get('password')

        user = customuser.objects.filter(email=email).first()

        if not user:
            raise serializers.ValidationError({'error': 'Invalid credentials'})

        if not user.check_password(password):
            raise serializers.ValidationError({'error': 'Invalid credentials'})

        data['user'] = user
        return data


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['name']

class NoteSerializer(serializers.ModelSerializer):
    category = CategorySerializer()
    tags = serializers.ListField(child=serializers.CharField(max_length=50), allow_empty=True)

    class Meta:
        model = Note
        fields = [
            'id', 'title', 'category', 'tags', 'content', 'summary',
            'reminder_date', 'created_at', 'updated_at', 'is_favorite', 'owner',
        ]
        read_only_fields = ['created_at', 'updated_at', 'owner']

    def validate_category(self, value):
        user = self.context['request'].user
        if not isinstance(value, dict) or 'name' not in value:
            raise serializers.ValidationError("Invalid category format.")
        
        category_name = value['name'].strip().lower()
        category, _ = Category.objects.get_or_create(name=category_name, owner=user)
        return category

    def validate_reminder_date(self, value):
        if value and value < timezone.now().date():
            raise serializers.ValidationError("Reminder date cannot be in the past.")
        return value

    def _get_openrouter_summary(self, content: str) -> str:
        """
        Helper method to get summary using OpenRouter API
        """
        api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key:
            return "Summary unavailable: OPENROUTER_API_KEY not set in .env"

        headers = {
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": os.getenv("YOUR_SITE_URL", "https://your-app.com"),      
            "X-Title": os.getenv("YOUR_SITE_NAME", "Smart Notes App"),              
            "Content-Type": "application/json"
        }

        payload = {
            "model": "openai/gpt-4o-mini",         
            "messages": [
                {
                    "role": "user",
                    "content": f"Summarize this note clearly and concisely in 2-4 sentences:\n\n{content}"
                }
            ],
            "temperature": 0.3,                     
            "max_tokens": 150
        }

        try:
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=15
            )
            response.raise_for_status()  

            result = response.json()
            summary = result['choices'][0]['message']['content'].strip()

            return summary if summary else "Summary generation returned empty result."

        except requests.exceptions.RequestException as e:
            return f"Summary unavailable: OpenRouter API error - {str(e)}"
        except (KeyError, IndexError) as e:
            return f"Summary unavailable: Invalid response format from OpenRouter - {str(e)}"
        except Exception as e:
            return f"Summary unavailable: {str(e)}"

    def create(self, validated_data):
        validated_data['owner'] = self.context['request'].user

        content = validated_data.get('content', '')
        if content:
            validated_data['summary'] = self._get_openrouter_summary(content)
        else:
            validated_data['summary'] = ""

        return super().create(validated_data)

    def update(self, instance, validated_data):
        new_content = validated_data.get('content')
        if new_content is not None and new_content != instance.content:
            validated_data['summary'] = self._get_openrouter_summary(new_content)

        return super().update(instance, validated_data)
    

class NoteVersionSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)

    class Meta:
        model = NoteVersion
        fields = '__all__'

class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = customuser
        fields = ['email', 'username', 'profile_url']
        read_only_fields = ['email', 'username']