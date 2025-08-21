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
      // Borrower screens
      _screens = [
        const DashboardScreen(),
        const ChemicalsScreen(),
        const EquipmentScreen(),
        const BorrowingsScreen(),
      ];

      _titles = [
        'Dashboard',
        'Chemicals',
        'Equipment',
        'My Requests',
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
          label: 'My Requests',
        ),
      ];
    } else {
      // Admin/Technician screens
      _screens = [
        const DashboardScreen(),
        const ChemicalsScreen(),
        const EquipmentScreen(),
        const BorrowingsScreen(),
        const LectureSchedulesScreen(),
        const ReportsScreen(),
      ];

      _titles = [
        'Dashboard',
        'Chemicals',
        'Equipment',
        'Borrowings',
        'Lecture Schedules',
        'Reports',
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
      ];

      // Add Users screen for admin
      if (userRole == 'admin') {
        _screens.add(const UsersScreen());
        _titles.add('Users');
        _navItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        );
      }
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
    // ignore: unused_local_variable
    final userRole = authProvider.userRole;

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
