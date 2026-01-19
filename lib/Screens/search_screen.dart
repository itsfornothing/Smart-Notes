import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'All'; // All, Category, Tags
  String _searchQuery = '';
  List<Note> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final user = FirebaseAuth.instance.currentUser!;
    final lowerQuery = query.toLowerCase();

    try {
      final notesSnapshot = await FirebaseFirestore.instance
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .get();

      final allNotes = notesSnapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();

      List<Note> filteredNotes = [];

      if (_selectedTab == 'All') {
        filteredNotes = allNotes.where((note) {
          return note.title.toLowerCase().contains(lowerQuery) ||
                 note.content.toLowerCase().contains(lowerQuery);
        }).toList();
      } else if (_selectedTab == 'Category') {
        filteredNotes = allNotes.where((note) {
          return note.category.toLowerCase().contains(lowerQuery);
        }).toList();
      } else if (_selectedTab == 'Tags') {
        filteredNotes = allNotes.where((note) {
          return note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      setState(() {
        _searchResults = filteredNotes;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),

            // Tabs: All, Category, Tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Category', 'Tags'].map((tab) {
                  final isSelected = _selectedTab == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTab = tab);
                        if (_searchQuery.isNotEmpty) {
                          _performSearch(_searchQuery);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.primaryColor
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tab,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _searchQuery.isEmpty
                  ? Center(
                      child: Text(
                        'Start typing to search in $_selectedTab',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                'No results found for "$_searchQuery"',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _searchResults.length + 2,
                              itemBuilder: (context, index) {
                                // Header
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Top results',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${_searchResults.length} found',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // End of results
                                if (index == _searchResults.length + 1) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32),
                                    child: Center(
                                      child: Text(
                                        'End of Results',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // Note Card
                                final note = _searchResults[index - 1];
                                return _buildNoteCard(note);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final theme = Theme.of(context);
    final preview = note.content.length > 150
        ? '${note.content.substring(0, 150)}...'
        : note.content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              note.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Content Preview
            Text(
              preview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

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
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${tag[0].toUpperCase() + tag.substring(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const Spacer(),

                // Updated time
                Text(
                  DateFormat('MMM d, yyyy').format(note.updatedAt),
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
    );
  }
}