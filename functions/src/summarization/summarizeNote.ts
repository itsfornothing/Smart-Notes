import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
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
  model?: string;
  error?: string;
  code?: string;
}

interface UserUsageStats {
  dailyRequests: number;
  monthlyRequests: number;
  lastRequestTime: admin.firestore.Timestamp;
  requestsInLastHour: number;
  requestsInLastMinute: number;
  hourlyResetTime: admin.firestore.Timestamp;
  minutelyResetTime: admin.firestore.Timestamp;
}

export const summarizeNote = onCall(
  async (request): Promise<SummarizeNoteResponse> => {
    const data = request.data as SummarizeNoteRequest;
    
    try {
      // Verify user authentication
      if (!request.auth) {
        throw new HttpsError(
          'unauthenticated',
          'User must be authenticated to summarize notes.'
        );
      }

      // Verify user ID matches authenticated user
      if (request.auth.uid !== data.userId) {
        throw new HttpsError(
          'permission-denied',
          'User can only summarize their own notes.'
        );
      }

      // Validate input parameters
      if (!data.noteId || !data.content || !data.userId) {
        throw new HttpsError(
          'invalid-argument',
          'Missing required parameters: noteId, content, or userId.'
        );
      }

      // Validate content length using environment configuration (Requirements 3.5)
      const maxLength = Environment.getMaxContentLength();
      if (data.content.length > maxLength) {
        throw new HttpsError(
          'invalid-argument',
          `Note content exceeds maximum length of ${maxLength} characters. Current length: ${data.content.length} characters.`
        );
      }

      // Validate minimum content length (Requirements 1.1, 1.4)
      const minLength = Environment.getMinContentLength();
      if (data.content.length < minLength) {
        throw new HttpsError(
          'invalid-argument',
          `Note content must be at least ${minLength} characters long for summarization. Current length: ${data.content.length} characters.`
        );
      }

      // Check rate limits and quotas (Requirements 3.4, 5.4)
      await checkRateLimitsAndQuotas(data.userId);

      // Verify note ownership by checking Firestore
      const noteRef = admin.firestore().collection('notes').doc(data.noteId);
      const noteDoc = await noteRef.get();
      
      if (!noteDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Note not found.'
        );
      }

      const noteData = noteDoc.data();
      if (noteData?.userId !== data.userId) {
        throw new HttpsError(
          'permission-denied',
          'User does not own this note.'
        );
      }

      // Initialize OpenRouter service
      const openRouterService = new OpenRouterService();
      
      // Generate summary using AI service with enhanced error handling
      let summary: string;
      let model = 'openai/gpt-3.5-turbo'; // Default model
      
      try {
        summary = await openRouterService.generateSummary(data.content);
      } catch (error) {
        // Log the error for monitoring
        console.error('AI summarization failed', {
          userId: data.userId,
          noteId: data.noteId,
          contentLength: data.content.length,
          error: error
        });
        
        // Update usage stats even for failed requests to prevent abuse
        await updateUsageStats(data.userId, false);
        
        // Re-throw the error (it's already properly formatted by OpenRouterService)
        throw error;
      }

      // Save summary to Firestore (Requirements 2.1)
      await noteRef.update({
        summary: summary,
        summaryTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        summaryOutdated: false,
        summaryModel: model
      });

      // Update usage statistics for successful requests
      await updateUsageStats(data.userId, true);

      // Log successful summarization for monitoring
      logger.info('Summary generated successfully', {
        userId: data.userId,
        noteId: data.noteId,
        contentLength: data.content.length,
        summaryLength: summary.length,
        model: model
      });

      return {
        success: true,
        summary: summary,
        model: model
      };

    } catch (error) {
      // Enhanced error logging with context
      logger.error('Error in summarizeNote function:', {
        error: error,
        userId: data?.userId,
        noteId: data?.noteId,
        contentLength: data?.content?.length,
        timestamp: new Date().toISOString()
      });
      
      // Handle known Firebase errors
      if (error instanceof HttpsError) {
        throw error;
      }

      // Handle unexpected errors with generic message
      throw new HttpsError(
        'internal',
        'An internal error occurred while processing the summarization request. Please try again later.'
      );
    }
  }
);

/**
 * Check rate limits and quotas for a user (Requirements 3.4, 5.4)
 */
async function checkRateLimitsAndQuotas(userId: string): Promise<void> {
  const rateLimitConfig = Environment.getRateLimitConfig();
  const quotaLimits = Environment.getQuotaLimits();
  const now = admin.firestore.Timestamp.now();
  
  const userStatsRef = admin.firestore().collection('userUsageStats').doc(userId);
  
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const userStatsDoc = await transaction.get(userStatsRef);
      
      let stats: UserUsageStats;
      
      if (!userStatsDoc.exists) {
        // Initialize stats for new user
        stats = {
          dailyRequests: 0,
          monthlyRequests: 0,
          lastRequestTime: now,
          requestsInLastHour: 0,
          requestsInLastMinute: 0,
          hourlyResetTime: now,
          minutelyResetTime: now
        };
      } else {
        stats = userStatsDoc.data() as UserUsageStats;
      }
      
      // Reset counters if time windows have passed
      const oneHourAgo = new Date(now.toDate().getTime() - 60 * 60 * 1000);
      const oneMinuteAgo = new Date(now.toDate().getTime() - 60 * 1000);
      const oneDayAgo = new Date(now.toDate().getTime() - 24 * 60 * 60 * 1000);
      const oneMonthAgo = new Date(now.toDate().getTime() - 30 * 24 * 60 * 60 * 1000);
      
      if (stats.hourlyResetTime.toDate() < oneHourAgo) {
        stats.requestsInLastHour = 0;
        stats.hourlyResetTime = now;
      }
      
      if (stats.minutelyResetTime.toDate() < oneMinuteAgo) {
        stats.requestsInLastMinute = 0;
        stats.minutelyResetTime = now;
      }
      
      if (stats.lastRequestTime.toDate() < oneDayAgo) {
        stats.dailyRequests = 0;
      }
      
      if (stats.lastRequestTime.toDate() < oneMonthAgo) {
        stats.monthlyRequests = 0;
      }
      
      // Check rate limits
      if (stats.requestsInLastMinute >= rateLimitConfig.maxRequestsPerMinute) {
        throw new HttpsError(
          'resource-exhausted',
          `Rate limit exceeded: Maximum ${rateLimitConfig.maxRequestsPerMinute} requests per minute. Please wait before trying again.`
        );
      }
      
      if (stats.requestsInLastHour >= rateLimitConfig.maxRequestsPerHour) {
        throw new HttpsError(
          'resource-exhausted',
          `Rate limit exceeded: Maximum ${rateLimitConfig.maxRequestsPerHour} requests per hour. Please try again later.`
        );
      }
      
      // Check quotas
      if (stats.dailyRequests >= quotaLimits.dailyRequestsPerUser) {
        throw new HttpsError(
          'resource-exhausted',
          `Daily quota exceeded: Maximum ${quotaLimits.dailyRequestsPerUser} summaries per day. Quota resets at midnight.`
        );
      }
      
      if (stats.monthlyRequests >= quotaLimits.monthlyRequestsPerUser) {
        throw new HttpsError(
          'resource-exhausted',
          `Monthly quota exceeded: Maximum ${quotaLimits.monthlyRequestsPerUser} summaries per month. Quota resets monthly.`
        );
      }
      
      // Increment counters (will be committed if no errors thrown)
      stats.requestsInLastMinute++;
      stats.requestsInLastHour++;
      stats.dailyRequests++;
      stats.monthlyRequests++;
      stats.lastRequestTime = now;
      
      transaction.set(userStatsRef, stats);
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    
    logger.error('Error checking rate limits:', {
      userId,
      error
    });
    
    // Allow request to proceed if rate limit check fails (fail open)
    logger.warn('Rate limit check failed, allowing request to proceed', { userId });
  }
}

/**
 * Update usage statistics after request completion
 */
async function updateUsageStats(userId: string, success: boolean): Promise<void> {
  try {
    const userStatsRef = admin.firestore().collection('userUsageStats').doc(userId);
    
    await userStatsRef.update({
      lastRequestTime: admin.firestore.FieldValue.serverTimestamp(),
      [`${success ? 'successful' : 'failed'}Requests`]: admin.firestore.FieldValue.increment(1)
    });
  } catch (error) {
    // Don't fail the main request if stats update fails
    logger.warn('Failed to update usage stats:', {
      userId,
      success,
      error
    });
  }
}