import 'dart:convert';
import 'dart:collection';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a cached summary entry for local storage
class SummaryCacheEntry {
  final String noteId;
  final String summary;
  final DateTime timestamp;
  final String contentHash;
  final String? summaryModel;

  const SummaryCacheEntry({
    required this.noteId,
    required this.summary,
    required this.timestamp,
    required this.contentHash,
    this.summaryModel,
  });

  /// Creates a SummaryCacheEntry from JSON
  factory SummaryCacheEntry.fromJson(Map<String, dynamic> json) {
    return SummaryCacheEntry(
      noteId: json['noteId'] as String,
      summary: json['summary'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      contentHash: json['contentHash'] as String,
      summaryModel: json['summaryModel'] as String?,
    );
  }

  /// Converts SummaryCacheEntry to JSON
  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'summary': summary,
      'timestamp': timestamp.toIso8601String(),
      'contentHash': contentHash,
      if (summaryModel != null) 'summaryModel': summaryModel,
    };
  }

  /// Creates a content hash from note content for change detection
  static String createContentHash(String content) {
    final bytes = utf8.encode(content.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryCacheEntry &&
        other.noteId == noteId &&
        other.summary == summary &&
        other.timestamp == timestamp &&
        other.contentHash == contentHash &&
        other.summaryModel == summaryModel;
  }

  @override
  int get hashCode {
    return Object.hash(noteId, summary, timestamp, contentHash, summaryModel);
  }

  @override
  String toString() {
    return 'SummaryCacheEntry(noteId: $noteId, summary: ${summary.length} chars, '
           'timestamp: $timestamp, model: $summaryModel)';
  }
}

/// Manages local caching of AI-generated summaries with LRU eviction
class SummaryCache {
  static const String _cacheKey = 'summary_cache';
  static const String _accessOrderKey = 'summary_cache_access_order';
  static const int _maxCacheSize = 100; // Maximum number of cached summaries

  final SharedPreferences _prefs;
  final LinkedHashMap<String, SummaryCacheEntry> _cache = LinkedHashMap();
  final Queue<String> _accessOrder = Queue();

  SummaryCache._(this._prefs);

  /// Creates and initializes a SummaryCache instance
  static Future<SummaryCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = SummaryCache._(prefs);
    await cache._loadCache();
    return cache;
  }

  /// Loads cached summaries from SharedPreferences
  Future<void> _loadCache() async {
    try {
      final cacheJson = _prefs.getString(_cacheKey);
      final accessOrderJson = _prefs.getStringList(_accessOrderKey) ?? [];

      if (cacheJson != null) {
        final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
        
        for (final entry in cacheData.entries) {
          final cacheEntry = SummaryCacheEntry.fromJson(
            entry.value as Map<String, dynamic>
          );
          _cache[entry.key] = cacheEntry;
        }
      }

      // Restore access order
      _accessOrder.clear();
      _accessOrder.addAll(accessOrderJson);

      // Clean up access order to only include existing cache entries
      _accessOrder.removeWhere((noteId) => !_cache.containsKey(noteId));
    } catch (e) {
      // If loading fails, start with empty cache
      _cache.clear();
      _accessOrder.clear();
    }
  }

  /// Saves the cache to SharedPreferences
  Future<void> _saveCache() async {
    try {
      final cacheData = <String, dynamic>{};
      for (final entry in _cache.entries) {
        cacheData[entry.key] = entry.value.toJson();
      }

      await _prefs.setString(_cacheKey, jsonEncode(cacheData));
      await _prefs.setStringList(_accessOrderKey, _accessOrder.toList());
    } catch (e) {
      // Silently fail - cache is not critical
    }
  }

  /// Gets a cached summary for a note
  /// Returns null if not cached or if content has changed
  SummaryCacheEntry? get(String noteId, String currentContent) {
    final entry = _cache[noteId];
    if (entry == null) return null;

    // Check if content has changed
    final currentHash = SummaryCacheEntry.createContentHash(currentContent);
    if (entry.contentHash != currentHash) {
      // Content changed, remove stale entry
      remove(noteId);
      return null;
    }

    // Update access order (move to end)
    _updateAccessOrder(noteId);
    
    return entry;
  }

  /// Caches a summary for a note
  Future<void> put(
    String noteId,
    String summary,
    String content, {
    String? summaryModel,
  }) async {
    final contentHash = SummaryCacheEntry.createContentHash(content);
    final entry = SummaryCacheEntry(
      noteId: noteId,
      summary: summary,
      timestamp: DateTime.now(),
      contentHash: contentHash,
      summaryModel: summaryModel,
    );

    _cache[noteId] = entry;
    _updateAccessOrder(noteId);

    // Enforce cache size limit with LRU eviction
    await _evictIfNeeded();
    
    await _saveCache();
  }

  /// Removes a cached summary
  Future<void> remove(String noteId) async {
    _cache.remove(noteId);
    _accessOrder.remove(noteId);
    await _saveCache();
  }

  /// Checks if a summary is cached and valid for the given content
  bool isValid(String noteId, String currentContent) {
    final entry = _cache[noteId];
    if (entry == null) return false;

    final currentHash = SummaryCacheEntry.createContentHash(currentContent);
    return entry.contentHash == currentHash;
  }

  /// Gets all cached note IDs
  List<String> get cachedNoteIds => _cache.keys.toList();

  /// Gets the number of cached summaries
  int get size => _cache.length;

  /// Clears all cached summaries
  Future<void> clear() async {
    _cache.clear();
    _accessOrder.clear();
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_accessOrderKey);
  }

  /// Updates the access order for LRU tracking
  void _updateAccessOrder(String noteId) {
    _accessOrder.remove(noteId);
    _accessOrder.addLast(noteId);
  }

  /// Evicts least recently used entries if cache exceeds size limit
  Future<void> _evictIfNeeded() async {
    while (_cache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final lruNoteId = _accessOrder.removeFirst();
      _cache.remove(lruNoteId);
    }
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'oldestEntry': _accessOrder.isNotEmpty ? _accessOrder.first : null,
      'newestEntry': _accessOrder.isNotEmpty ? _accessOrder.last : null,
    };
  }

  /// Validates cache integrity (for testing)
  bool validateIntegrity() {
    // Check that access order matches cache entries
    final cacheKeys = _cache.keys.toSet();
    final accessKeys = _accessOrder.toSet();
    
    return cacheKeys == accessKeys && _cache.length <= _maxCacheSize;
  }
}