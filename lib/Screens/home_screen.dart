import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import 'dart:ui' as ui;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onEdit, this.setRefreshCallback});

  final VoidCallback? onEdit;
  final Function(Function)? setRefreshCallback;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _notes = [];
  Set<String> _categories = {'All'};
  String _selectedCategory = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    widget.setRefreshCallback?.call(_refreshHomePage);
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // Use the proper query with orderBy (index is ready and rules updated)
      final notesSnapshot = await FirebaseFirestore.instance
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final notes = notesSnapshot.docs
          .map((doc) => Note.fromFirestore(doc))
          .toList();

      // Extract unique categories
      final categories = {'All'};
    for (var note in notes) {
      if (note.category.isNotEmpty) {
        categories.add(note.category[0].toUpperCase() + note.category.substring(1).toLowerCase());
      }
    }

    setState(() {
      _notes = notes;
      _categories = categories;
      _isLoading = false;
    });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        _notes = [];
        _categories = {'All'};
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _refreshHomePage() {
    _loadNotes();
  }

  // Calculate text size for dynamic category button width
  Size _calculateTextSize(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.size;
  }

  // Extract plain text from Quill JSON format
  String _extractPlainText(String content) {
    try {
      // Check if content looks like JSON
      if (content.trim().startsWith('[') && content.trim().endsWith(']')) {
        final List<dynamic> delta = jsonDecode(content);
        final StringBuffer plainText = StringBuffer();
        
        for (final operation in delta) {
          if (operation is Map<String, dynamic> && operation.containsKey('insert')) {
            final insertValue = operation['insert'];
            if (insertValue is String) {
              plainText.write(insertValue);
            }
          }
        }
        
        return plainText.toString().trim();
      }
    } catch (e) {
      // If JSON parsing fails, return original content
      print('Error parsing Quill JSON: $e');
    }
    
    // Return original content if not JSON or parsing failed
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? const Center(child: Text('No notes yet. Create one!'))
                : Column(
                    children: [
                      // Horizontal Category Filters
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = List<String>.from(_categories)..sort();
                            final catName = category[index];
                            final isSelected = _selectedCategory == catName;

                            final textSize = _calculateTextSize(catName, categoryStyle);
                            final buttonWidth = textSize.width + 60;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = catName;
                                  });
                                },
                                child: Container(
                                  width: buttonWidth.clamp(100, 200),
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : theme.colorScheme.surfaceContainerHighest
                                              .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: theme.shadowColor.withValues(alpha: 0.4),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: theme.shadowColor.withValues(alpha: 0.2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    catName,
                                    style: categoryStyle.copyWith(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Notes List
                      Expanded(
                        child: _getFilteredNotes().isEmpty
                            ? Center(
                                child: Text(
                                  'No notes in "$_selectedCategory"',
                                  style: theme.textTheme.titleMedium,
                                ),
                              )
                            : ListView.builder(
                                itemCount: _getFilteredNotes().length,
                                itemBuilder: (context, index) {
                                  final note = _getFilteredNotes()[index];
                                  return _buildNoteCard(note);
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  List<Note> _getFilteredNotes() {
    if (_selectedCategory == 'All') {
      return _notes;
    }
    return _notes.where((note) {
      return note.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();
  }

  Widget _buildNoteCard(Note note) {
    final theme = Theme.of(context);
    
    // Extract plain text from content
    final plainTextContent = _extractPlainText(note.content);
    final previewText = plainTextContent.length > 120
        ? '${plainTextContent.substring(0, 120)}...'
        : plainTextContent;

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_forever_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(note.id)
              .delete();
          
          setState(() {
            _notes.removeWhere((n) => n.id == note.id);
            
            // Recalculate categories after deletion
            final categories = {'All'};
            for (var remainingNote in _notes) {
              if (remainingNote.category.isNotEmpty) {
                categories.add(remainingNote.category[0].toUpperCase() + remainingNote.category.substring(1).toLowerCase());
              }
            }
            _categories = categories;
            
            // If the current selected category no longer exists, switch to 'All'
            if (!_categories.contains(_selectedCategory)) {
              _selectedCategory = 'All';
            }
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete note: $e'),
                backgroundColor: Colors.red,
              ),
            );
            _refreshHomePage();
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoteEditorScreen(
                  noteId: note.id,
                  initialTitle: note.title,
                  initialContent: note.content,
                ),
              ),
            );
            if (updated == true) {
              _refreshHomePage();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Favorite Star Icon
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        // Optimistic update - update UI immediately
                        setState(() {
                          final noteIndex = _notes.indexWhere((n) => n.id == note.id);
                          if (noteIndex != -1) {
                            _notes[noteIndex] = _notes[noteIndex].copyWith(
                              isFavorite: !_notes[noteIndex].isFavorite,
                            );
                          }
                        });

                        // Show immediate feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(note.isFavorite 
                                ? 'Removed from favorites' 
                                : 'Added to favorites'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: note.isFavorite ? Colors.orange : Colors.green,
                          ),
                        );

                        // Update in Firestore
                        try {
                          await FirebaseFirestore.instance
                              .collection('notes')
                              .doc(note.id)
                              .update({'isFavorite': !note.isFavorite});
                        } catch (e) {
                          // Revert optimistic update on error
                          setState(() {
                            final noteIndex = _notes.indexWhere((n) => n.id == note.id);
                            if (noteIndex != -1) {
                              _notes[noteIndex] = _notes[noteIndex].copyWith(
                                isFavorite: !_notes[noteIndex].isFavorite,
                              );
                            }
                          });
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update favorite: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Icon(
                        note.isFavorite ? Icons.star : Icons.star_border,
                        color: note.isFavorite ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // AI Summary (if available)
                if (note.hasSummary)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: theme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note.summary!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.primaryColor.withValues(alpha: 0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content Preview
                Text(
                  previewText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Tags + Updated Time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Tags
                    if (note.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: note.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${tag[0].toUpperCase() + tag.substring(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const Spacer(),

                    // Last updated
                    Text(
                      'Updated ${DateFormat('MMM d').format(note.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}