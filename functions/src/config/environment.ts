import * as functions from 'firebase-functions';

/**
 * Environment configuration for Firebase Functions
 * Handles both local development (.env) and production (Firebase config) environments
 */
export class Environment {
  /**
   * Get OpenRouter API key from environment
   * Priority: Firebase config > Environment variable
   */
  static getOpenRouterApiKey(): string {
    // Try Firebase config first (production)
    const firebaseConfig = functions.config().openrouter?.api_key;
    if (firebaseConfig) {
      return firebaseConfig;
    }

    // Fall back to environment variable (local development)
    const envKey = process.env.OPENROUTER_API_KEY;
    if (envKey) {
      return envKey;
    }

    throw new Error(
      'OpenRouter API key not configured. ' +
      'Set OPENROUTER_API_KEY environment variable or configure Firebase functions config.'
    );
  }

  /**
   * Get Firebase project ID
   */
  static getProjectId(): string {
    return process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'smart-notes-dev';
  }

  /**
   * Check if running in development mode
   */
  static isDevelopment(): boolean {
    return process.env.FUNCTIONS_EMULATOR === 'true';
  }

  /**
   * Get request timeout in milliseconds
   */
  static getRequestTimeout(): number {
    return 30000; // 30 seconds as per requirements
  }

  /**
   * Get maximum content length for summarization
   */
  static getMaxContentLength(): number {
    return 10000; // 10,000 characters as per requirements
  }

  /**
   * Get minimum content length for summarization
   */
  static getMinContentLength(): number {
    return 100; // 100 characters as per requirements
  }
}