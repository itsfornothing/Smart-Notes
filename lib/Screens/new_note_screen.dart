import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../provider/notification_provider.dart';

class NewNoteScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNoteCreated;

  const NewNoteScreen({super.key, this.onNoteCreated});

  @override
  ConsumerState<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends ConsumerState<NewNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final QuillController _quillController = QuillController.basic();

  DateTime? _reminderDate;
  final List<String> _tags = [];
  String _category = 'General';
  bool _isSaving = false;

  Future<void> _addTag() async {
    final TextEditingController tagController = TextEditingController();

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: tagController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tag name',
              hintText: 'e.g. flutter',
            ),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final value = tagController.text.trim().toLowerCase();
      if (value.isNotEmpty && !_tags.contains(value)) {
        setState(() {
          _tags.add(value);
        });
      }
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController controller = TextEditingController(
      text: _category,
    );

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Work, Personal',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        _category = controller.text.trim();
      });
    }
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _reminderDate = date);
    }
  }

  Future<void> _createNote() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final contentJson = jsonEncode(
        _quillController.document.toDelta().toJson(),
      );

      final noteData = {
        'title': _titleController.text.trim(),
        'content': contentJson,
        'userId': user.uid,
        'category': _category,
        'tags': _tags,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isFavorite': false,
        'summaryOutdated': false,
      };

      if (_reminderDate != null) {
        noteData['reminderDate'] = Timestamp.fromDate(_reminderDate!);
      }

      await FirebaseFirestore.instance.collection('notes').add(noteData);

      // Schedule notification if reminder date is set and notifications are enabled
      if (_reminderDate != null && _reminderDate!.isAfter(DateTime.now())) {
        final notificationService = ref.read(notiServiceProvider);
        final noteTitle = _titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim();
        final plainTextContent = _quillController.document.toPlainText().trim();
        final notificationId = noteTitle.hashCode;
        
        await notificationService.scheduleNotification(
          id: notificationId,
          title: 'Reminder: $noteTitle',
          body: plainTextContent.length > 100 
              ? '${plainTextContent.substring(0, 100)}...' 
              : plainTextContent,
          scheduledDate: _reminderDate!,
          ref: ref,
        );
        
        print('Notification scheduled for new note: ${_reminderDate!} with ID: $notificationId');
      }

      widget.onNoteCreated?.call();
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating note: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Note'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              : TextButton(
                  onPressed: _createNote,
                  child: const Text('Save', style: TextStyle(fontSize: 17)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Note Title',
              ),
            ),

            const SizedBox(height: 16),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._tags.map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                  ),
                ),
                ActionChip(
                  label: const Text('Add Tag'),
                  avatar: const Icon(Icons.add, size: 18),
                  onPressed: _addTag,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Category
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(_category),
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(color: Colors.orange),
                ),
                ActionChip(
                  label: const Text('+ Change Category'),
                  onPressed: _addCategory,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reminder
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _reminderDate == null
                    ? 'Add reminder'
                    : 'Reminder: ${DateFormat('MMM d, yyyy').format(_reminderDate!)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickReminder,
            ),

            const SizedBox(height: 20),

            // Quill Toolbar
            QuillSimpleToolbar(
              controller: _quillController,
              config: const QuillSimpleToolbarConfig(),
            ),

            const SizedBox(height: 12),

            // Quill Editor
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  height: 400,
                  child: QuillEditor(
                    controller: _quillController,
                    scrollController: ScrollController(),
                    focusNode: FocusNode(),
                    config: const QuillEditorConfig(
                      placeholder: 'Start writing your note...',
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}