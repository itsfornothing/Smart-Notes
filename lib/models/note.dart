import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a note in the Smart Notes application with AI summarization support
class Note {
  final String id;
  final String title;
  final String content;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // AI Summary fields
  final String? summary;
  final DateTime? summaryTimestamp;
  final bool summaryOutdated;
  final String? summaryModel;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.summary,
    this.summaryTimestamp,
    this.summaryOutdated = false,
    this.summaryModel,
  });

  /// Creates a Note from Firestore document data
  /// Maintains backward compatibility with existing notes that don't have summary fields
  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Note(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: data['summary'],
      summaryTimestamp: (data['summaryTimestamp'] as Timestamp?)?.toDate(),
      summaryOutdated: data['summaryOutdated'] ?? false,
      summaryModel: data['summaryModel'],
    );
  }

  /// Creates a Note from a Map (for testing or other data sources)
  factory Note.fromMap(Map<String, dynamic> data, String id) {
    return Note(
      id: id,
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] is DateTime 
          ? data['createdAt'] 
          : (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt'] is DateTime 
          ? data['updatedAt'] 
          : (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: data['summary'],
      summaryTimestamp: data['summaryTimestamp'] is DateTime 
          ? data['summaryTimestamp'] 
          : (data['summaryTimestamp'] as Timestamp?)?.toDate(),
      summaryOutdated: data['summaryOutdated'] ?? false,
      summaryModel: data['summaryModel'],
    );
  }

  /// Converts Note to Map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (summary != null) 'summary': summary,
      if (summaryTimestamp != null) 'summaryTimestamp': Timestamp.fromDate(summaryTimestamp!),
      'summaryOutdated': summaryOutdated,
      if (summaryModel != null) 'summaryModel': summaryModel,
    };
  }

  /// Converts Note to Map (for testing or other uses)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'userId': userId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (summary != null) 'summary': summary,
      if (summaryTimestamp != null) 'summaryTimestamp': summaryTimestamp,
      'summaryOutdated': summaryOutdated,
      if (summaryModel != null) 'summaryModel': summaryModel,
    };
  }

  /// Creates a copy of this Note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? summary,
    DateTime? summaryTimestamp,
    bool? summaryOutdated,
    String? summaryModel,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      summary: summary ?? this.summary,
      summaryTimestamp: summaryTimestamp ?? this.summaryTimestamp,
      summaryOutdated: summaryOutdated ?? this.summaryOutdated,
      summaryModel: summaryModel ?? this.summaryModel,
    );
  }

  /// Creates a new Note for creation (without ID)
  static Map<String, dynamic> createData({
    required String title,
    required String content,
    required String userId,
  }) {
    final now = DateTime.now();
    return {
      'title': title.trim().isEmpty ? 'Untitled' : title.trim(),
      'content': content.trim(),
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'summaryOutdated': false,
    };
  }

  /// Creates update data for existing notes
  static Map<String, dynamic> updateData({
    String? title,
    String? content,
    String? summary,
    String? summaryModel,
    bool? summaryOutdated,
  }) {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) {
      data['title'] = title.trim().isEmpty ? 'Untitled' : title.trim();
    }
    if (content != null) {
      data['content'] = content.trim();
    }
    if (summary != null) {
      data['summary'] = summary;
      data['summaryTimestamp'] = FieldValue.serverTimestamp();
    }
    if (summaryModel != null) {
      data['summaryModel'] = summaryModel;
    }
    if (summaryOutdated != null) {
      data['summaryOutdated'] = summaryOutdated;
    }

    return data;
  }

  /// Checks if the note has a summary
  bool get hasSummary => summary != null && summary!.isNotEmpty;

  /// Checks if the note content is long enough for summarization (>100 characters)
  bool get isEligibleForSummarization => content.length > 100;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.userId == userId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.summary == summary &&
        other.summaryTimestamp == summaryTimestamp &&
        other.summaryOutdated == summaryOutdated &&
        other.summaryModel == summaryModel;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      content,
      userId,
      createdAt,
      updatedAt,
      summary,
      summaryTimestamp,
      summaryOutdated,
      summaryModel,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, content: ${content.length} chars, '
           'hasSummary: $hasSummary, summaryOutdated: $summaryOutdated)';
  }
}