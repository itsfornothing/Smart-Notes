import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_notes/models/note.dart';
import 'package:smart_notes/services/summary_service.dart';
import 'package:smart_notes/widgets/summary_widget.dart';

// Mock SummaryService for testing
class MockSummaryService implements SummaryService {
  @override
  Future<SummaryResult> generateSummary(Note note) async {
    if (!note.isEligibleForSummarization) {
      throw const SummaryException(
        'Note content is too short for summarization (minimum 100 characters)',
        code: 'CONTENT_TOO_SHORT',
      );
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    return const SummaryResult(
      summary: 'This is a test summary of the note content.',
      model: 'test-model',
    );
  }

  @override
  SummaryResult? getCachedSummary(Note note) => null;

  @override
  bool hasCachedSummary(Note note) => false;

  @override
  Future<void> clearCachedSummary(String noteId) async {}

  @override
  Future<void> clearAllCache() async {}

  @override
  Map<String, dynamic> getCacheStats() => {};

  @override
  void cancelPendingRequest(String noteId) {}

  @override
  void cancelAllPendingRequests() {}

  @override
  void dispose() {}
}

void main() {
  group('SummaryWidget', () {
    late MockSummaryService mockSummaryService;

    setUp(() {
      mockSummaryService = MockSummaryService();
    });

    testWidgets('shows generate button for eligible notes', (tester) async {
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: 'This is a test note with more than 100 characters. ' * 3,
        userId: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryWidget(
              note: note,
              summaryService: mockSummaryService,
            ),
          ),
        ),
      );

      expect(find.text('Generate Summary'), findsOneWidget);
      expect(find.text('AI Summary'), findsOneWidget);
    });

    testWidgets('hides widget for ineligible notes', (tester) async {
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: 'Short content',
        userId: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryWidget(
              note: note,
              summaryService: mockSummaryService,
            ),
          ),
        ),
      );

      expect(find.byType(SummaryWidget), findsOneWidget);
      expect(find.text('Generate Summary'), findsNothing);
    });

    testWidgets('displays existing summary', (tester) async {
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: 'This is a test note with more than 100 characters. ' * 3,
        userId: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        summary: 'Existing summary',
        summaryTimestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryWidget(
              note: note,
              summaryService: mockSummaryService,
            ),
          ),
        ),
      );

      expect(find.text('AI Summary'), findsOneWidget);
      expect(find.text('Existing summary'), findsOneWidget);
    });

    testWidgets('shows loading state during generation', (tester) async {
      final note = Note(
        id: 'test-id',
        title: 'Test Note',
        content: 'This is a test note with more than 100 characters. ' * 3,
        userId: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryWidget(
              note: note,
              summaryService: mockSummaryService,
            ),
          ),
        ),
      );

      // Tap generate button
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Generating summary...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      
      // Wait for the async operation to complete
      await tester.pumpAndSettle();
    });
  });
}