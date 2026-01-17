import axios, { AxiosResponse } from 'axios';
import * as functions from 'firebase-functions';
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
}

export class OpenRouterService {
  private readonly apiKey: string;
  private readonly baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  private readonly primaryModel = 'openai/gpt-3.5-turbo';
  private readonly fallbackModel = 'anthropic/claude-3-haiku';
  private readonly timeout: number;

  constructor() {
    // Get API key from environment configuration (Requirements 3.1, 3.3)
    this.apiKey = Environment.getOpenRouterApiKey();
    this.timeout = Environment.getRequestTimeout();
  }

  /**
   * Generate a summary for the given note content
   * @param content The note content to summarize
   * @returns Promise<string> The generated summary
   */
  async generateSummary(content: string): Promise<string> {
    try {
      // Try primary model first
      return await this.callOpenRouter(content, this.primaryModel);
    } catch (error) {
      functions.logger.warn('Primary model failed, trying fallback model:', error);
      
      try {
        // Fallback to secondary model
        return await this.callOpenRouter(content, this.fallbackModel);
      } catch (fallbackError) {
        functions.logger.error('Both models failed:', fallbackError);
        throw new functions.https.HttpsError(
          'unavailable',
          'AI summarization service is currently unavailable. Please try again later.'
        );
      }
    }
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
            'HTTP-Referer': 'https://smart-notes-app.com', // Optional: for OpenRouter analytics
            'X-Title': 'Smart Notes AI Summarization'
          },
          timeout: this.timeout
        }
      );

      // Extract summary from response
      const summary = response.data.choices[0]?.message?.content?.trim();
      
      if (!summary) {
        throw new Error('Empty response from AI service');
      }

      // Validate that summary is shorter than original content (Requirements 1.2)
      if (summary.length >= content.length) {
        functions.logger.warn('Generated summary is not shorter than original content');
      }

      return summary;

    } catch (error) {
      if (axios.isAxiosError(error)) {
        // Handle specific HTTP errors
        if (error.response?.status === 429) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'Rate limit exceeded. Please try again later.'
          );
        } else if (error.response?.status === 401) {
          throw new functions.https.HttpsError(
            'permission-denied',
            'Invalid API key configuration.'
          );
        } else if (error.response && error.response.status >= 500) {
          throw new functions.https.HttpsError(
            'unavailable',
            'AI service is temporarily unavailable.'
          );
        }
      }

      // Handle timeout errors
      if (error && typeof error === 'object' && 'code' in error && error.code === 'ECONNABORTED') {
        throw new functions.https.HttpsError(
          'deadline-exceeded',
          'Request timeout. The AI service took too long to respond.'
        );
      }

      // Re-throw the error for the caller to handle
      throw error;
    }
  }
}