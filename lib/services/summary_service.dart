import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';
import '../models/summary_cache.dart';

/// Exception thrown when summary generation fails
class SummaryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const SummaryException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'SummaryException: $message';
}

/// Result of a summary generation request
class SummaryResult {
  final String summary;
  final String? model;
  final bool fromCache;

  const SummaryResult({
    required this.summary,
    this.model,
    this.fromCache = false,
  });
}

/// Service for managing AI-powered note summarization
/// Handles Firebase Functions communication, caching, offline detection, and retry logic
class SummaryService {
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 1);

  final FirebaseFunctions _functions;
  final SummaryCache _cache;
  final Connectivity _connectivity;
  final FirebaseAuth _auth;

  // Request debouncing
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Completer<SummaryResult>> _pendingRequests = {};

  // Retry logic
  final Map<String, int> _retryAttempts = {};

  SummaryService._({
    required FirebaseFunctions functions,
    required SummaryCache cache,
    required Connectivity connectivity,
    required FirebaseAuth auth,
  })  : _functions = functions,
        _cache = cache,
        _connectivity = connectivity,
        _auth = auth;

  /// Creates and initializes a SummaryService instance
  static Future<SummaryService> create() async {
    final functions = FirebaseFunctions.instance;
    final cache = await SummaryCache.create();
    final connectivity = Connectivity();
    final auth = FirebaseAuth.instance;

    return SummaryService._(
      functions: functions,
      cache: cache,
      connectivity: connectivity,
      auth: auth,
    );
  }

  /// Generates a summary for the given note
  /// Implements debouncing, caching, offline detection, and retry logic
  Future<SummaryResult> generateSummary(Note note) async {
    // Validate note eligibility
    if (!note.isEligibleForSummarization) {
      throw const SummaryException(
        'Note content is too short for summarization (minimum 100 characters)',
        code: 'CONTENT_TOO_SHORT',
      );
    }

    // Check authentication
    final user = _auth.currentUser;
    if (user == null) {
      throw const SummaryException(
        'User must be authenticated to generate summaries',
        code: 'UNAUTHENTICATED',
      );
    }

    // Check cache first
    final cachedEntry = _cache.get(note.id, note.content);
    if (cachedEntry != null) {
      return SummaryResult(
        summary: cachedEntry.summary,
        model: cachedEntry.summaryModel,
        fromCache: true,
      );
    }

    // Check network connectivity
    if (!await _isOnline()) {
      throw const SummaryException(
        'Network connection required for summary generation',
        code: 'OFFLINE',
      );
    }

    // Handle request debouncing
    return _debouncedRequest(note);
  }

  /// Handles debounced summary requests to prevent duplicate calls
  Future<SummaryResult> _debouncedRequest(Note note) async {
    final requestKey = note.id;

    // Cancel existing timer for this note
    _debounceTimers[requestKey]?.cancel();

    // If there's already a pending request, return its future
    if (_pendingRequests.containsKey(requestKey)) {
      return _pendingRequests[requestKey]!.future;
    }

    // Create new completer for this request
    final completer = Completer<SummaryResult>();
    _pendingRequests[requestKey] = completer;

    // Set up debounce timer
    _debounceTimers[requestKey] = Timer(_debounceDelay, () async {
      try {
        final result = await _performSummaryRequest(note);
        completer.complete(result);
      } catch (error) {
        completer.completeError(error);
      } finally {
        _debounceTimers.remove(requestKey);
        _pendingRequests.remove(requestKey);
        _retryAttempts.remove(requestKey);
      }
    });

    return completer.future;
  }

  /// Performs the actual summary request with retry logic
  Future<SummaryResult> _performSummaryRequest(Note note) async {
    final requestKey = note.id;
    final attemptCount = _retryAttempts[requestKey] ?? 0;

    try {
      final callable = _functions.httpsCallable('summarizeNote');
      
      final result = await callable.call({
        'noteId': note.id,
        'content': note.content,
        'userId': note.userId,
      }).timeout(_requestTimeout);

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw SummaryException(
          data['error'] ?? 'Unknown error occurred',
          code: data['code'],
        );
      }

      final summary = data['summary'] as String;
      final model = data['model'] as String?;

      // Cache the result
      await _cache.put(
        note.id,
        summary,
        note.content,
        summaryModel: model,
      );

      return SummaryResult(
        summary: summary,
        model: model,
        fromCache: false,
      );
    } catch (error) {
      // Handle specific error types for retry logic
      if (_shouldRetry(error) && attemptCount < _maxRetries) {
        _retryAttempts[requestKey] = attemptCount + 1;
        
        // Calculate exponential backoff delay
        final delay = _calculateRetryDelay(attemptCount);
        await Future.delayed(delay);
        
        return _performSummaryRequest(note);
      }

      // Convert various error types to SummaryException
      throw _convertToSummaryException(error);
    }
  }

  /// Checks if the device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Additional check by attempting to resolve a DNS lookup
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Determines if an error should trigger a retry
  bool _shouldRetry(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;
    
    if (error is FirebaseFunctionsException) {
      // Retry on server errors but not client errors
      final code = error.code;
      return code == 'internal' || 
             code == 'unavailable' || 
             code == 'deadline-exceeded';
    }

    return false;
  }

  /// Calculates retry delay with exponential backoff
  Duration _calculateRetryDelay(int attemptCount) {
    final multiplier = (1 << attemptCount); // 2^attemptCount
    return Duration(
      milliseconds: _initialRetryDelay.inMilliseconds * multiplier,
    );
  }

  /// Converts various error types to SummaryException
  SummaryException _convertToSummaryException(dynamic error) {
    if (error is SummaryException) return error;
    
    if (error is TimeoutException) {
      return const SummaryException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    }

    if (error is SocketException) {
      return const SummaryException(
        'Network error. Please check your connection.',
        code: 'NETWORK_ERROR',
      );
    }

    if (error is FirebaseFunctionsException) {
      String message;
      switch (error.code) {
        case 'unauthenticated':
          message = 'Authentication required';
          break;
        case 'permission-denied':
          message = 'Permission denied';
          break;
        case 'resource-exhausted':
          message = 'Usage quota exceeded. Please try again later.';
          break;
        case 'invalid-argument':
          message = 'Invalid request. Please try again.';
          break;
        default:
          message = error.message ?? 'Service temporarily unavailable';
      }
      
      return SummaryException(
        message,
        code: error.code,
        originalError: error,
      );
    }

    return SummaryException(
      'An unexpected error occurred: ${error.toString()}',
      code: 'UNKNOWN_ERROR',
      originalError: error,
    );
  }

  /// Checks if a note has a valid cached summary
  bool hasCachedSummary(Note note) {
    return _cache.isValid(note.id, note.content);
  }

  /// Gets a cached summary if available and valid
  SummaryResult? getCachedSummary(Note note) {
    final entry = _cache.get(note.id, note.content);
    if (entry == null) return null;

    return SummaryResult(
      summary: entry.summary,
      model: entry.summaryModel,
      fromCache: true,
    );
  }

  /// Clears cached summary for a specific note
  Future<void> clearCachedSummary(String noteId) async {
    await _cache.remove(noteId);
  }

  /// Clears all cached summaries
  Future<void> clearAllCache() async {
    await _cache.clear();
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  /// Cancels any pending requests for a specific note
  void cancelPendingRequest(String noteId) {
    _debounceTimers[noteId]?.cancel();
    _debounceTimers.remove(noteId);
    
    final completer = _pendingRequests.remove(noteId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const SummaryException('Request cancelled', code: 'CANCELLED'),
      );
    }
    
    _retryAttempts.remove(noteId);
  }

  /// Cancels all pending requests
  void cancelAllPendingRequests() {
    for (final noteId in _pendingRequests.keys.toList()) {
      cancelPendingRequest(noteId);
    }
  }

  /// Disposes of the service and cleans up resources
  void dispose() {
    cancelAllPendingRequests();
  }
}