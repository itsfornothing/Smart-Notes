import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'reminder_screen.dart';
import 'new_note_screen.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _selectedPageIndex = 0;
  Function? _refreshHomeCallback;

  final List<String> _pageTitles = const [
    'All Notes',
    'Search',
    'Reminders',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    Widget activePage;

    switch (_selectedPageIndex) {
      case 0:
        activePage = HomeScreen(
          setRefreshCallback: (callback) => _refreshHomeCallback = callback,
        );
        break;
      case 1:
        activePage = const SearchScreen();
        break;
      case 2:
        activePage = ReminderScreen(setRefreshCallback: (callback) {});
        break;
      case 3:
        activePage = const SettingsScreen();
        break;
      default:
        activePage = const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedPageIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: activePage,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedPageIndex,
        onTap: (index) {
          setState(() {
            _selectedPageIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary, 
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant, 
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _selectedPageIndex == 0
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewNoteScreen()),
                );
                if (result == true) _refreshHomeCallback?.call();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}