import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class AISummaryService {
  // Use the working model as primary, with fallbacks
  static const List<String> _fallbackModels = [
    'openai/gpt-4o-mini',
    'google/gemma-2-9b-it:free',
    'meta-llama/llama-3.2-3b-instruct:free', 
    'microsoft/phi-3-mini-128k-instruct:free',
  ];

  /// Generate a summary for the given note content
  Future<String> generateSummary(String content, String title) async {
    // Check if content is long enough for summarization
    if (content.trim().length < AppConfig.minContentLengthForSummary) {
      throw Exception('Content too short for summarization (minimum ${AppConfig.minContentLengthForSummary} characters)');
    }

    // Try each model until one works
    for (int i = 0; i < _fallbackModels.length; i++) {
      final model = _fallbackModels[i];
      try {
        print('Trying AI model: $model');
        final summary = await _generateWithModel(content, title, model);
        print('Successfully generated summary with model: $model');
        return summary;
      } catch (e) {
        print('Model $model failed: $e');
        if (i == _fallbackModels.length - 1) {
          // Last model failed, rethrow the error
          rethrow;
        }
        // Continue to next model
        continue;
      }
    }
    
    throw Exception('All AI models failed to generate summary');
  }

  Future<String> _generateWithModel(String content, String title, String model) async {
    try {
      // Create the prompt similar to the working Python implementation
      final prompt = 'Summarize this note clearly and concisely in 2-4 sentences:\n\nTitle: $title\n\nContent: $content';

      print('Making API request to OpenRouter...');
      print('Model: $model');
      print('API URL: ${AppConfig.openRouterBaseUrl}/chat/completions');
      print('Content length: ${content.length}');
      print('Using API key: ${AppConfig.openRouterApiKey.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse('${AppConfig.openRouterBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.openRouterApiKey}', // Already has "Bearer " prefix
          'Content-Type': 'application/json',
          'HTTP-Referer': AppConfig.appUrl,
          'X-Title': AppConfig.appName,
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.3, // Match Python implementation
          'max_tokens': 150,
        }),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          String summary = data['choices'][0]['message']['content'].toString().trim();
          
          // Clean up the summary - remove any prefixes
          summary = summary.replaceAll(RegExp(r'^(Summary:|AI Summary:)', caseSensitive: false), '').trim();
          if (summary.startsWith('"') && summary.endsWith('"')) {
            summary = summary.substring(1, summary.length - 1);
          }
          
          if (summary.isEmpty) {
            throw Exception('Summary generation returned empty result.');
          }
          
          return summary;
        } else {
          throw Exception('No summary generated - choices array is empty');
        }
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again in a moment.');
      } else if (response.statusCode == 401) {
        throw Exception('API authentication failed - check API key');
      } else if (response.statusCode == 402) {
        throw Exception('Insufficient credits - please check your OpenRouter account');
      } else {
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
          throw Exception('OpenRouter API error (${response.statusCode}): $errorMessage');
        } catch (parseError) {
          throw Exception('OpenRouter API error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      print('AI Error: $e'); // Enhanced debug logging
      if (kDebugMode) {
        print('Full error details: $e');
      }
      rethrow;
    }
  }

  /// Check if content is eligible for summarization
  bool isEligibleForSummarization(String content) {
    return content.trim().length >= AppConfig.minContentLengthForSummary;
  }

  /// Generate a shorter summary for display on cards (1 sentence)
  Future<String> generateShortSummary(String content, String title) async {
    try {
      if (content.trim().length < AppConfig.minContentLengthForSummary) {
        throw Exception('Content too short for summarization');
      }

      final prompt = 'Please provide a very brief one-sentence summary of this note:\n\nTitle: $title\nContent: $content\n\nOne-sentence summary:';

      final response = await http.post(
        Uri.parse('${AppConfig.openRouterBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': AppConfig.appUrl,
          'X-Title': AppConfig.appName,
        },
        body: jsonEncode({
          'model': _fallbackModels[0], // Use primary model for short summaries
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': AppConfig.maxShortSummaryTokens,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          String summary = data['choices'][0]['message']['content'].toString().trim();
          
          // Clean up the summary
          summary = summary.replaceAll('One-sentence summary:', '').trim();
          if (summary.startsWith('"') && summary.endsWith('"')) {
            summary = summary.substring(1, summary.length - 1);
          }
          
          return summary.isEmpty ? 'Summary unavailable' : summary;
        } else {
          throw Exception('No summary generated');
        }
      } else {
        throw Exception('Failed to generate short summary (${response.statusCode})');
      }
    } catch (e) {
      print('Short Summary Error: $e');
      if (kDebugMode) {
        print('Short Summary Error details: $e');
      }
      rethrow;
    }
  }
}