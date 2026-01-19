import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password Sign Up
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveToken();
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  // Email/Password Login
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveToken();
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In with forced account selection
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      
      // Clear any existing sign-in to force account selection
      await _googleSignIn.signOut();
      
      print('Attempting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return null;
      }

      print('Google account selected: ${googleUser.email}');
      print('Getting authentication details...');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      print('Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print('Signing in to Firebase...');
      UserCredential cred = await _auth.signInWithCredential(credential);
      
      print('Firebase sign-in successful');
      await _saveToken();
      return cred.user;
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Save authentication token
  Future<void> _saveToken() async {
    final String? token = await _auth.currentUser?.getIdToken();
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
    }
  }

  // Get ID Token for API calls
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && _auth.currentUser != null;
  }

  // Logout
  Future<void> logout() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      
      // Sign out from Google (this will clear cached credentials)
      await _googleSignIn.signOut();
      
      // Disconnect Google account to force fresh sign-in next time
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        // Ignore disconnect errors (user might not be connected)
        print('Google disconnect error (can be ignored): $e');
      }
      
      // Clear stored token
      await _storage.delete(key: 'auth_token');
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Check if user is currently signed in with Google
  Future<bool> isSignedInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      return googleUser != null;
    } catch (e) {
      return false;
    }
  }

  // Force sign out from all services
  Future<void> forceSignOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
      await _storage.deleteAll();
    } catch (e) {
      print('Force sign out error: $e');
    }
  }
}