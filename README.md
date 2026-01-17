# Smart Notes

A modern note-taking application built with Flutter and Firebase. Create, edit, and manage your notes with real-time synchronization across devices.

## Features

- **User Authentication**: Sign in with email/password or Google account
- **Real-time Sync**: Notes are automatically synchronized across devices using Firebase Firestore
- **Rich Text Editing**: Create and edit notes with a clean, intuitive interface
- **AI-Powered Summarization**: Generate intelligent summaries of your notes using advanced AI
- **Smart Caching**: Offline support with intelligent caching for better performance
- **Secure Storage**: All data is securely stored in Firebase with user authentication
- **Cross-platform**: Works on Android, iOS, and web platforms

## Technologies Used

- **Flutter**: Cross-platform mobile development framework
- **Firebase Authentication**: Secure user authentication
- **Cloud Firestore**: Real-time NoSQL database
- **Firebase Functions**: Serverless backend for AI processing
- **Firebase Storage**: File and image storage
- **Google Sign-In**: OAuth authentication with Google
- **OpenAI Integration**: Advanced AI for note summarization

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Firebase project setup

### Installation

1. Clone the repository:
   ```bash
   git clone <your-repository-url>
   cd smart_notes
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add your Android/iOS app to the project
   - Download and add the configuration files:
     - `android/app/google-services.json` (Android)
     - `ios/Runner/GoogleService-Info.plist` (iOS)
   - Update `lib/firebase_options.dart` with your project configuration

4. Enable Firebase services:
   - Authentication (Email/Password and Google Sign-In)
   - Cloud Firestore
   - Firebase Storage (optional)

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run tests
flutter test

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

## Development Mode

The app includes AI summarization features that work in development using Firebase emulators:

1. **Start Firebase Functions Emulator**:
   ```bash
   cd functions
   npm install
   firebase emulators:start --only functions
   ```

2. **Run the app** - it will automatically connect to local emulators for AI features

## Firebase Setup

### 1. Authentication Setup

Enable the following sign-in methods in Firebase Console:
- Email/Password
- Google Sign-In

### 2. Firestore Database

Create a Firestore database with the following security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notes/{noteId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### 3. Storage Rules (if using file uploads)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
└── screens/
    ├── login_screen.dart     # Authentication screen
    ├── home_screen.dart      # Notes list screen
    └── note_editor_screen.dart # Note editing screen
```

## Building for Release

### Android

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties`:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-keystore>
   ```

3. Build release APK:
   ```bash
   flutter build apk --release
   ```

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing & capabilities
3. Build for release

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support or questions, please open an issue in the GitHub repository.