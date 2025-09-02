import 'package:chemlab_frontend/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/screens/dashboard_screen.dart';
import 'package:chemlab_frontend/screens/chemicals_screen.dart';
import 'package:chemlab_frontend/screens/equipment_screen.dart';
import 'package:chemlab_frontend/screens/borrowings_screen.dart';
import 'package:chemlab_frontend/screens/reports_screen.dart';
import 'package:chemlab_frontend/screens/users_screen.dart';
import 'package:chemlab_frontend/screens/lecture_schedules_screen.dart';
import 'package:chemlab_frontend/screens/live_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  late List<String> _titles;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _updateScreens();
  }

  void _updateScreens() {
    final userRole = Provider.of<AuthProvider>(context, listen: false).userRole;

    if (userRole == 'borrower') {
      // Borrower screens - ONLY dashboard and borrowings
      _screens = [
        const DashboardScreen(),
        const BorrowingsScreen(),
      ];

      _titles = [
        'Dashboard',
        'My Requests',
      ];

      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'My Requests',
        ),
      ];
    } else if (userRole == 'technician') {
      // Technician screens - No users screen
      _screens = [
        const DashboardScreen(),
        const ChemicalsScreen(),
        const EquipmentScreen(),
        const BorrowingsScreen(),
        const LectureSchedulesScreen(),
        const ReportsScreen(),
        const LiveChatScreen(),
      ];

      _titles = [
        'Dashboard',
        'Chemicals',
        'Equipment',
        'Borrowings',
        'Lecture Schedules',
        'Reports',
        'Live Chat',
      ];

      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.science),
          label: 'Chemicals',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.build),
          label: 'Equipment',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Borrowings',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Lecture Schedules',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Live Chat',
        ),
      ];
    } else {
      // Admin screens - All features
      _screens = [
        const DashboardScreen(),
        const ChemicalsScreen(),
        const EquipmentScreen(),
        const BorrowingsScreen(),
        const LectureSchedulesScreen(),
        const ReportsScreen(),
        const UsersScreen(), // Admin only
        const LiveChatScreen(),
      ];

      _titles = [
        'Dashboard',
        'Chemicals',
        'Equipment',
        'Borrowings',
        'Lecture Schedules',
        'Reports',
        'Users',
        'Live Chat',
      ];

      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.science),
          label: 'Chemicals',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.build),
          label: 'Equipment',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Borrowings',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Lecture Schedules',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Live Chat',
        ),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Update screens if role changes
    _updateScreens();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Profile'),
                onTap: () {
                  // Navigate to profile screen after a small delay to allow menu to close
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: () {
                  authProvider.logout();
                },
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
