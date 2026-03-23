import 'package:blood_donation_app/screens/home/blood_drive_screen.dart';
import 'package:flutter/material.dart';

import 'home/sos_feed_screen.dart';
import 'profile/profile_screen.dart';
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SosFeedScreen(),      // Tab 0: Danh sách tin SOS
    const BloodDriveScreen(), // Tab 1: Map
    const ProfileScreen(),      // Tab 2: Hồ sơ
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Tin SOS'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Sự kiện'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}