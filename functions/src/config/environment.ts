/**
 * Environment configuration for Firebase Functions
 * Uses environment variables for configuration (modern approach)
 */
export class Environment {
  /**
   * Get OpenRouter API key from environment
   */
  static getOpenRouterApiKey(): string {
    const envKey = process.env.OPENROUTER_API_KEY;
    if (envKey) {
      return envKey;
    }

    throw new Error(
      'OpenRouter API key not configured. ' +
      'Set OPENROUTER_API_KEY environment variable.'
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

  /**
   * Get rate limit configuration
   */
  static getRateLimitConfig() {
    return {
      maxRequestsPerHour: 50, // Per user rate limit
      maxRequestsPerMinute: 5, // Burst protection
    };
  }

  /**
   * Get retry configuration
   */
  static getRetryConfig() {
    return {
      maxRetries: 3,
      initialDelayMs: 1000,
      maxDelayMs: 10000,
      backoffMultiplier: 2,
    };
  }

  /**
   * Get quota limits
   */
  static getQuotaLimits() {
    return {
      dailyRequestsPerUser: 100,
      monthlyRequestsPerUser: 1000,
    };
  }
}