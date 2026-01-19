import axios, { AxiosResponse, AxiosError } from 'axios';
import { HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { Environment } from '../config/environment';

interface OpenRouterMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface OpenRouterRequest {
  model: string;
  messages: OpenRouterMessage[];
  max_tokens: number;
  temperature?: number;
}

interface OpenRouterResponse {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

interface OpenRouterErrorResponse {
  error: {
    message: string;
    type: string;
    code?: string;
  };
}

export class OpenRouterService {
  private readonly apiKey: string;
  private readonly baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  private readonly primaryModel = 'openai/gpt-4o-mini';
  private readonly fallbackModel = 'google/gemma-2-9b-it:free';
  private readonly timeout: number;
  private readonly retryConfig: any;

  constructor() {
    // Get API key from environment configuration (Requirements 3.1, 3.3)
    this.apiKey = Environment.getOpenRouterApiKey();
    this.timeout = Environment.getRequestTimeout();
    this.retryConfig = Environment.getRetryConfig();
  }

  /**
   * Generate a summary for the given note content with comprehensive error handling
   * @param content The note content to summarize
   * @returns Promise<string> The generated summary
   */
  async generateSummary(content: string): Promise<string> {
    let lastError: any;

    try {
      // Try primary model first with retry logic
      return await this.callOpenRouterWithRetry(content, this.primaryModel);
    } catch (error) {
      lastError = error;
      logger.warn('Primary model failed, trying fallback model:', {
        model: this.primaryModel,
        error: this.formatErrorForLogging(error)
      });
      
      try {
        // Fallback to secondary model with retry logic
        return await this.callOpenRouterWithRetry(content, this.fallbackModel);
      } catch (fallbackError) {
        logger.error('Both models failed:', {
          primaryError: this.formatErrorForLogging(lastError),
          fallbackError: this.formatErrorForLogging(fallbackError)
        });
        
        // Determine the most appropriate error to throw
        const errorToThrow = this.selectMostRelevantError(lastError, fallbackError);
        throw this.convertToHttpsError(errorToThrow);
      }
    }
  }

  /**
   * Call OpenRouter with retry logic for transient failures
   * @param content The content to summarize
   * @param model The AI model to use
   * @returns Promise<string> The generated summary
   */
  private async callOpenRouterWithRetry(content: string, model: string): Promise<string> {
    let lastError: any;
    
    for (let attempt = 0; attempt <= this.retryConfig.maxRetries; attempt++) {
      try {
        return await this.callOpenRouter(content, model);
      } catch (error) {
        lastError = error;
        
        // Don't retry on certain error types
        if (!this.shouldRetryError(error)) {
          throw error;
        }
        
        // Don't retry on the last attempt
        if (attempt === this.retryConfig.maxRetries) {
          throw error;
        }
        
        // Calculate delay with exponential backoff
        const delay = Math.min(
          this.retryConfig.initialDelayMs * Math.pow(this.retryConfig.backoffMultiplier, attempt),
          this.retryConfig.maxDelayMs
        );
        
        logger.info(`Retrying request after ${delay}ms (attempt ${attempt + 1}/${this.retryConfig.maxRetries})`, {
          model,
          error: this.formatErrorForLogging(error)
        });
        
        await this.sleep(delay);
      }
    }
    
    throw lastError;
  }

  /**
   * Make API call to OpenRouter with specified model
   * @param content The content to summarize
   * @param model The AI model to use
   * @returns Promise<string> The generated summary
   */
  private async callOpenRouter(content: string, model: string): Promise<string> {
    const request: OpenRouterRequest = {
      model: model,
      messages: [
        {
          role: 'system',
          content: 'You are a helpful assistant that creates concise, informative summaries of text content. Focus on the main points, key ideas, and important details. Keep summaries clear and well-structured. Limit your response to 2-3 sentences for short content, or 1-2 paragraphs for longer content.'
        },
        {
          role: 'user',
          content: `Please summarize the following note content:\n\n${content}`
        }
      ],
      max_tokens: 150,
      temperature: 0.3
    };

    try {
      const response: AxiosResponse<OpenRouterResponse> = await axios.post(
        this.baseUrl,
        request,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://smart-notes-app.com',
            'X-Title': 'Smart Notes AI Summarization'
          },
          timeout: this.timeout,
          validateStatus: (status) => status < 500 // Don't throw on 4xx errors, handle them explicitly
        }
      );

      // Handle non-2xx responses
      if (response.status >= 400) {
        const errorData = response.data as unknown as OpenRouterErrorResponse;
        throw this.createErrorFromResponse(response.status, errorData);
      }

      // Extract summary from response
      const summary = response.data.choices[0]?.message?.content?.trim();
      
      if (!summary) {
        throw new Error('Empty response from AI service');
      }

      // Validate that summary is shorter than original content (Requirements 1.2)
      if (summary.length >= content.length) {
        logger.warn('Generated summary is not shorter than original content', {
          originalLength: content.length,
          summaryLength: summary.length,
          model
        });
      }

      // Log usage statistics for monitoring
      if (response.data.usage) {
        logger.info('OpenRouter API usage', {
          model,
          tokens: response.data.usage.total_tokens,
          promptTokens: response.data.usage.prompt_tokens,
          completionTokens: response.data.usage.completion_tokens
        });
      }

      return summary;

    } catch (error) {
      // Enhanced error handling with specific error types
      if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError;
        
        // Handle timeout specifically
        if (axiosError.code === 'ECONNABORTED' || axiosError.message.includes('timeout')) {
          throw new Error('REQUEST_TIMEOUT');
        }
        
        // Handle network errors
        if (axiosError.code === 'ECONNREFUSED' || axiosError.code === 'ENOTFOUND') {
          throw new Error('NETWORK_ERROR');
        }
        
        // Handle HTTP errors with response
        if (axiosError.response) {
          const errorData = axiosError.response.data as OpenRouterErrorResponse;
          throw this.createErrorFromResponse(axiosError.response.status, errorData);
        }
        
        // Handle request errors without response
        throw new Error(`NETWORK_ERROR: ${axiosError.message}`);
      }

      // Re-throw other errors as-is
      throw error;
    }
  }

  /**
   * Create appropriate error from OpenRouter API response
   */
  private createErrorFromResponse(status: number, errorData?: OpenRouterErrorResponse): Error {
    const errorMessage = errorData?.error?.message || 'Unknown API error';
    
    switch (status) {
      case 400:
        return new Error(`INVALID_REQUEST: ${errorMessage}`);
      case 401:
        return new Error(`INVALID_API_KEY: ${errorMessage}`);
      case 403:
        return new Error(`FORBIDDEN: ${errorMessage}`);
      case 429:
        return new Error(`RATE_LIMITED: ${errorMessage}`);
      case 500:
      case 502:
      case 503:
      case 504:
        return new Error(`SERVICE_UNAVAILABLE: ${errorMessage}`);
      default:
        return new Error(`API_ERROR: ${errorMessage}`);
    }
  }

  /**
   * Determine if an error should trigger a retry
   */
  private shouldRetryError(error: any): boolean {
    if (!error || typeof error.message !== 'string') {
      return false;
    }
    
    const message = error.message;
    
    // Retry on network and timeout errors
    if (message.includes('REQUEST_TIMEOUT') || 
        message.includes('NETWORK_ERROR') || 
        message.includes('SERVICE_UNAVAILABLE')) {
      return true;
    }
    
    // Don't retry on client errors
    if (message.includes('INVALID_REQUEST') || 
        message.includes('INVALID_API_KEY') || 
        message.includes('FORBIDDEN')) {
      return false;
    }
    
    // Retry on rate limits (with backoff)
    if (message.includes('RATE_LIMITED')) {
      return true;
    }
    
    return false;
  }

  /**
   * Select the most relevant error to throw when both models fail
   */
  private selectMostRelevantError(primaryError: any, fallbackError: any): any {
    // Prioritize client errors over server errors
    if (primaryError?.message?.includes('INVALID_API_KEY') || 
        fallbackError?.message?.includes('INVALID_API_KEY')) {
      return primaryError?.message?.includes('INVALID_API_KEY') ? primaryError : fallbackError;
    }
    
    if (primaryError?.message?.includes('FORBIDDEN') || 
        fallbackError?.message?.includes('FORBIDDEN')) {
      return primaryError?.message?.includes('FORBIDDEN') ? primaryError : fallbackError;
    }
    
    if (primaryError?.message?.includes('RATE_LIMITED') || 
        fallbackError?.message?.includes('RATE_LIMITED')) {
      return primaryError?.message?.includes('RATE_LIMITED') ? primaryError : fallbackError;
    }
    
    // Default to primary error
    return primaryError;
  }

  /**
   * Convert internal errors to Firebase HTTPS errors
   */
  private convertToHttpsError(error: any): HttpsError {
    if (!error || typeof error.message !== 'string') {
      return new HttpsError(
        'internal',
        'An unexpected error occurred during AI processing.'
      );
    }
    
    const message = error.message;
    
    if (message.includes('REQUEST_TIMEOUT')) {
      return new HttpsError(
        'deadline-exceeded',
        'The AI service took too long to respond. Please try again.'
      );
    }
    
    if (message.includes('NETWORK_ERROR')) {
      return new HttpsError(
        'unavailable',
        'Unable to connect to AI service. Please try again later.'
      );
    }
    
    if (message.includes('INVALID_API_KEY')) {
      return new HttpsError(
        'internal',
        'AI service configuration error. Please contact support.'
      );
    }
    
    if (message.includes('FORBIDDEN')) {
      return new HttpsError(
        'permission-denied',
        'Access denied by AI service. Please contact support.'
      );
    }
    
    if (message.includes('RATE_LIMITED')) {
      return new HttpsError(
        'resource-exhausted',
        'AI service rate limit exceeded. Please try again in a few minutes.'
      );
    }
    
    if (message.includes('SERVICE_UNAVAILABLE')) {
      return new HttpsError(
        'unavailable',
        'AI service is temporarily unavailable. Please try again later.'
      );
    }
    
    if (message.includes('INVALID_REQUEST')) {
      return new HttpsError(
        'invalid-argument',
        'Invalid request to AI service. Please try again.'
      );
    }
    
    return new HttpsError(
      'internal',
      'AI summarization service encountered an error. Please try again.'
    );
  }

  /**
   * Format error for logging (remove sensitive information)
   */
  private formatErrorForLogging(error: any): any {
    if (!error) return error;
    
    // Create a safe copy for logging
    const safeError: any = {
      message: error.message,
      code: error.code,
      status: error.status
    };
    
    // Don't log sensitive information like API keys
    if (error.config) {
      safeError.url = error.config.url;
      safeError.method = error.config.method;
    }
    
    return safeError;
  }

  /**
   * Sleep for specified milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}