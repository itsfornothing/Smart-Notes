import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../widgets/summary_widget.dart';
import '../services/summary_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String initialTitle;
  final String initialContent;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialTitle = '',
    this.initialContent = '',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;
  Note? _currentNote;
  SummaryService? _summaryService;
  String? _originalContent;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _originalContent = widget.initialContent;
    
    // Initialize SummaryService asynchronously
    _initializeSummaryService();
    
    // Load existing note if editing
    if (widget.noteId != null) {
      _loadNote();
    }
    
    // Listen for content changes to detect summary staleness
    _contentController.addListener(_onContentChanged);
  }

  Future<void> _initializeSummaryService() async {
    try {
      _summaryService = await SummaryService.create();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle initialization error silently for now
    }
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _currentNote = Note.fromFirestore(doc);
        });
      }
    } catch (e) {
      // Handle error silently for now, note will be created on save
    }
  }

  void _onContentChanged() {
    // Implement summary staleness detection on content changes
    if (_currentNote != null && _currentNote!.hasSummary) {
      final currentContent = _contentController.text.trim();
      final originalContent = _originalContent ?? '';
      
      // Check if content has changed significantly (more than 10% difference)
      final contentDiff = (currentContent.length - originalContent.length).abs();
      final changePercentage = originalContent.isEmpty ? 1.0 : contentDiff / originalContent.length;
      
      if (changePercentage > 0.1 || currentContent != originalContent) {
        // Mark summary as outdated if content changed significantly
        if (!_currentNote!.summaryOutdated) {
          setState(() {
            _currentNote = _currentNote!.copyWith(summaryOutdated: true);
          });
        }
      }
    }
  }

  void _onNoteUpdated() {
    // Reload the note to get updated summary data
    if (widget.noteId != null) {
      _loadNote();
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty && 
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to save')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final noteData = {
        'title': _titleController.text.trim().isEmpty 
            ? 'Untitled' 
            : _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Handle summary staleness detection on content changes
      if (_currentNote != null && _currentNote!.hasSummary) {
        final currentContent = _contentController.text.trim();
        final originalContent = _originalContent ?? '';
        
        if (currentContent != originalContent) {
          noteData['summaryOutdated'] = true;
        }
      }

      if (widget.noteId == null) {
        // Create new note
        noteData['createdAt'] = FieldValue.serverTimestamp();
        noteData['summaryOutdated'] = false;
        final docRef = await FirebaseFirestore.instance.collection('notes').add(noteData);
        
        // Update current note with new ID
        setState(() {
          _currentNote = Note.fromMap({
            ...noteData,
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          }, docRef.id);
        });
      } else {
        // Update existing note
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.noteId)
            .update(noteData);
        
        // Update original content reference
        _originalContent = _contentController.text.trim();
        
        // Reload note to get updated data
        await _loadNote();
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving note: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Note title...',
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: 'Start writing your note...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      minLines: 10,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                    // Add SummaryWidget to note editor layout
                    if (_currentNote != null && _summaryService != null)
                      SummaryWidget(
                        note: _currentNote!.copyWith(
                          title: _titleController.text.trim().isEmpty 
                              ? 'Untitled' 
                              : _titleController.text.trim(),
                          content: _contentController.text.trim(),
                        ),
                        summaryService: _summaryService!,
                        onNoteUpdated: _onNoteUpdated,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}