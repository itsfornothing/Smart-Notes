import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../services/summary_service.dart';
import 'note_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notes')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notes = snapshot.data?.docs ?? [];

          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to create your first note',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final noteDoc = notes[index];
              final note = Note.fromFirestore(noteDoc);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Display summary indicators in note list
                      _buildSummaryIndicator(note),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Show summary status (available, outdated, generating)
                      if (note.hasSummary || note.isEligibleForSummarization)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: _buildSummaryStatus(note),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteNote(context, note.id);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteEditorScreen(
                          noteId: note.id,
                          initialTitle: note.title,
                          initialContent: note.content,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoteEditorScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryIndicator(Note note) {
    if (!note.isEligibleForSummarization) {
      return const SizedBox.shrink();
    }

    if (note.hasSummary) {
      return Icon(
        Icons.auto_awesome,
        size: 16,
        color: note.summaryOutdated 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      );
    }

    return Icon(
      Icons.auto_awesome_outlined,
      size: 16,
      color: Theme.of(context).colorScheme.outline,
    );
  }

  Widget _buildSummaryStatus(Note note) {
    if (!note.isEligibleForSummarization) {
      return const SizedBox.shrink();
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (note.hasSummary) {
      if (note.summaryOutdated) {
        statusText = 'Summary outdated - tap to update';
        statusColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.warning_amber;
      } else {
        statusText = 'Summary available';
        statusColor = Theme.of(context).colorScheme.primary;
        statusIcon = Icons.auto_awesome;
      }
    } else {
      statusText = 'Summary available';
      statusColor = Theme.of(context).colorScheme.outline;
      statusIcon = Icons.auto_awesome_outlined;
    }

    return GestureDetector(
      onTap: note.summaryOutdated ? () {
        // Navigate to note editor to regenerate summary
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialContent: note.content,
            ),
          ),
        );
      } : null,
      child: Row(
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontSize: 11,
                decoration: note.summaryOutdated ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteNote(BuildContext context, String noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete note from Firestore (cascade deletion for summary data)
                await FirebaseFirestore.instance
                    .collection('notes')
                    .doc(noteId)
                    .delete();
                
                // Clean up summary data from local cache
                await _cleanupSummaryData(noteId);
                
                Navigator.pop(context);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting note: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Cleans up summary data from local cache when a note is deleted
  Future<void> _cleanupSummaryData(String noteId) async {
    try {
      // Import SummaryService to clean up local cache
      final summaryService = await SummaryService.create();
      await summaryService.clearCachedSummary(noteId);
    } catch (e) {
      // Log error but don't fail the deletion process
      debugPrint('Warning: Failed to clean up summary cache for note $noteId: $e');
    }
  }
}