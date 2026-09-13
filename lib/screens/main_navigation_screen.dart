import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'schedules_tab.dart';
import 'history_tab.dart';
import 'analytics_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    StorageService().addListener(_onDataChanged);
  }

  @override
  void dispose() {
    StorageService().removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SchedulesTab(onDataChanged: _onDataChanged),
      HistoryTab(onDataChanged: _onDataChanged),
      const AnalyticsTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.surfaceHighlight, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note),
              activeIcon: Icon(Icons.event_note, color: AppTheme.primary),
              label: 'Schedules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              activeIcon: Icon(Icons.history, color: AppTheme.primary),
              label: 'Logbook',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              activeIcon: Icon(Icons.insights, color: AppTheme.primary),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}
