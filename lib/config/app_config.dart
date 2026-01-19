class AppConfig {
  // OpenRouter AI API Configuration
  static const String openRouterApiKey = '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';
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'openai/gpt-4o-mini';
  
  // App Information
  static const String appName = 'Smart Notes';
  static const String appVersion = '1.0.0';
  static const String appUrl = 'https://smart-notes-app.com';
  
  // AI Summary Configuration
  static const int minContentLengthForSummary = 100; // Fixed: Match with Note model
  static const int maxSummaryTokens = 150;
  static const int maxShortSummaryTokens = 50;
  static const double summaryTemperature = 0.3;
}