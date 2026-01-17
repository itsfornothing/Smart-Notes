import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenRouterService } from '../services/openRouterService';
import { Environment } from '../config/environment';

interface SummarizeNoteRequest {
  noteId: string;
  content: string;
  userId: string;
}

interface SummarizeNoteResponse {
  success: boolean;
  summary?: string;
  error?: string;
}

export const summarizeNote = functions.https.onCall(
  async (data: SummarizeNoteRequest, context): Promise<SummarizeNoteResponse> => {
    try {
      // Verify user authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'User must be authenticated to summarize notes.'
        );
      }

      // Verify user ID matches authenticated user
      if (context.auth.uid !== data.userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User can only summarize their own notes.'
        );
      }

      // Validate input parameters
      if (!data.noteId || !data.content || !data.userId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Missing required parameters: noteId, content, or userId.'
        );
      }

      // Validate content length using environment configuration (Requirements 3.5)
      const maxLength = Environment.getMaxContentLength();
      if (data.content.length > maxLength) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Note content exceeds maximum length of ${maxLength} characters.`
        );
      }

      // Validate minimum content length (Requirements 1.1, 1.4)
      const minLength = Environment.getMinContentLength();
      if (data.content.length < minLength) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Note content must be at least ${minLength} characters long for summarization.`
        );
      }

      // Verify note ownership by checking Firestore
      const noteRef = admin.firestore().collection('notes').doc(data.noteId);
      const noteDoc = await noteRef.get();
      
      if (!noteDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Note not found.'
        );
      }

      const noteData = noteDoc.data();
      if (noteData?.userId !== data.userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User does not own this note.'
        );
      }

      // Initialize OpenRouter service
      const openRouterService = new OpenRouterService();
      
      // Generate summary using AI service
      const summary = await openRouterService.generateSummary(data.content);

      // Save summary to Firestore (Requirements 2.1)
      await noteRef.update({
        summary: summary,
        summaryTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        summaryOutdated: false,
        summaryModel: 'openai/gpt-3.5-turbo'
      });

      return {
        success: true,
        summary: summary
      };

    } catch (error) {
      functions.logger.error('Error in summarizeNote function:', error);
      
      // Handle known Firebase errors
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Handle unknown errors
      throw new functions.https.HttpsError(
        'internal',
        'An internal error occurred while processing the summarization request.'
      );
    }
  }
);