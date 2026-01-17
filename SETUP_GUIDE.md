# Smart Notes - Setup Guide

## Quick Setup for Testing

### Prerequisites
- Flutter SDK installed
- Android Studio or VS Code
- Firebase account

### 1. Clone and Setup
```bash
git clone https://github.com/itsfornothing/Smart-Notes.git
cd Smart-Notes
flutter pub get
```

### 2. Firebase Configuration
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package name: `com.example.smart_notes`
3. Download `google-services.json` and place in `android/app/`
4. Enable Authentication (Email/Password and Google Sign-In)
5. Create Firestore database with test mode rules

### 3. Update Firebase Options
Edit `lib/firebase_options.dart` with your project configuration from Firebase console.

### 4. Run the App
```bash
flutter run
```

## Features to Test
- Sign up with email/password
- Sign in with Google (if configured)
- Create new notes
- Edit existing notes
- Real-time sync across devices
- Secure user authentication

## Build APK for Sharing
```bash
flutter build apk --release
```
APK will be in `build/app/outputs/flutter-apk/app-release.apk`