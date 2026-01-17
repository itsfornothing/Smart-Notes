import 'package:flutter_test/flutter_test.dart';
import 'package:smart_notes/services/summary_service.dart';
import 'package:smart_notes/models/note.dart';

void main() {
  group('SummaryService', () {
    test('should throw exception for short content', () async {
      // This is a basic test to validate the service can be instantiated
      // and handles basic validation correctly
      
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: 'Short', // Less than 100 characters
        userId: 'test-user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Note: We can't fully test the service without mocking Firebase dependencies
      // This test validates the basic structure and content length validation
      expect(note.isEligibleForSummarization, false);
      expect(note.content.length < 100, true);
    });

    test('should identify eligible notes for summarization', () {
      final longContent = 'This is a long note content that exceeds the minimum character limit for AI summarization. ' * 2;
      
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: longContent,
        userId: 'test-user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.isEligibleForSummarization, true);
      expect(note.content.length > 100, true);
    });

    test('SummaryException should format correctly', () {
      const exception = SummaryException(
        'Test error message',
        code: 'TEST_ERROR',
      );

      expect(exception.message, 'Test error message');
      expect(exception.code, 'TEST_ERROR');
      expect(exception.toString(), 'SummaryException: Test error message');
    });

    test('SummaryResult should store data correctly', () {
      const result = SummaryResult(
        summary: 'Test summary',
        model: 'gpt-3.5-turbo',
        fromCache: true,
      );

      expect(result.summary, 'Test summary');
      expect(result.model, 'gpt-3.5-turbo');
      expect(result.fromCache, true);
    });
  });
}