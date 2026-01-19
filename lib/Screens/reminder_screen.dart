import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/notification_service.dart';
import '../provider/notification_provider.dart';

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({
    super.key,
    this.onEdit,
    this.setRefreshCallback,
  });

  final VoidCallback? onEdit;
  final Function(VoidCallback)? setRefreshCallback;

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  Map<String, List<Note>> _reminders = {
    'overdue': [],
    'today': [],
    'tomorrow': [],
    'future': [],
  };
  bool _isLoading = true;
  String _selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.setRefreshCallback != null) {
      widget.setRefreshCallback!(_refreshReminders);
    }
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));

      // Use the simple query to avoid index issues
      final query = FirebaseFirestore.instance
          .collection('notes')
          .where('userId', isEqualTo: user.uid);

      final snapshot = await query.get();
      
      // Filter notes with reminders in memory
      final List<Note> notes = snapshot.docs
          .map((doc) => Note.fromFirestore(doc))
          .where((note) => note.reminderDate != null)
          .toList();

      final Map<String, List<Note>> categorized = {
        'overdue': [],
        'today': [],
        'tomorrow': [],
        'future': [],
      };

      for (final note in notes) {
        final reminder = note.reminderDate!;
        final reminderDay = DateTime(reminder.year, reminder.month, reminder.day);
        
        if (reminderDay.isBefore(todayStart)) {
          categorized['overdue']!.add(note);
        } else if (reminderDay.isAtSameMomentAs(todayStart)) {
          categorized['today']!.add(note);
        } else if (reminderDay.isAtSameMomentAs(tomorrowStart)) {
          categorized['tomorrow']!.add(note);
        } else {
          categorized['future']!.add(note);
        }
      }

      // Sort each category by reminder date
      for (final category in categorized.values) {
        category.sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));
      }

      setState(() {
        _reminders = categorized;
        _isLoading = false;
      });

      // Optional: show summary notification if enabled
      if (ref.read(notificationsEnabledProvider)) {
        final total = notes.length;
        if (total > 0) {
          final overdue = categorized['overdue']!.length;
          final today = categorized['today']!.length;
          String message = 'You have $total upcoming ';
          if (overdue > 0) message += '($overdue overdue) ';
          message += 'reminders.';
          
          ref.read(notiServiceProvider).showNotification(
            title: 'Reminder Update',
            body: message,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reminders: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _refreshReminders() {
    _loadReminders();
  }

  List<Note> _getDisplayedNotes() {
    if (_selectedTab == 'All') {
      return [
        ..._reminders['overdue']!,
        ..._reminders['today']!,
        ..._reminders['tomorrow']!,
        ..._reminders['future']!,
      ];
    }
    return _reminders[_selectedTab.toLowerCase()] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReminders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getDisplayedNotes().isEmpty && _selectedTab == 'All'
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReminders,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: _buildReminderSections(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['All', 'Overdue', 'Today', 'Tomorrow', 'Future'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          final count = _reminders[tab.toLowerCase()]?.length ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withOpacity(0.25) 
                            : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                              ? Colors.white 
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTab = tab);
                }
              },
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildReminderSections() {
    final List<Widget> sections = [];
    
    if (_selectedTab == 'All') {
      if (_reminders['overdue']!.isNotEmpty) {
        sections.add(_buildSection('Overdue', _reminders['overdue']!, Colors.red));
      }
      if (_reminders['today']!.isNotEmpty) {
        sections.add(_buildSection('Today', _reminders['today']!, Colors.orange));
      }
      if (_reminders['tomorrow']!.isNotEmpty) {
        sections.add(_buildSection('Tomorrow', _reminders['tomorrow']!, Colors.green));
      }
      if (_reminders['future']!.isNotEmpty) {
        sections.add(_buildSection('Later', _reminders['future']!, Colors.blue));
      }
    } else {
      final notes = _getDisplayedNotes();
      if (notes.isNotEmpty) {
        sections.add(_buildSection(_selectedTab, notes, null));
      }
    }

    if (sections.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No ${_selectedTab.toLowerCase()} reminders',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildSection(String title, List<Note> notes, Color? accentColor) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        ...notes.map((note) => _buildReminderTile(note, color)),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildReminderTile(Note note, Color accentColor) {
    final timeFormat = DateFormat('h:mm a');
    final isOverdue = note.reminderDate!.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 4,
          decoration: BoxDecoration(
            color: isOverdue ? Colors.red : accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          note.title.isEmpty ? 'Untitled' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isOverdue ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              timeFormat.format(note.reminderDate!),
              style: TextStyle(
                color: isOverdue ? Colors.red : accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (note.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  children: note.tags.take(3).map((tag) {
                    return Chip(
                      label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 22),
          onPressed: widget.onEdit,
        ),
        onTap: () {
          // You could navigate to editor here
          // Navigator.push(...);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            'No reminders set yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Set reminders in your notes to see them here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}