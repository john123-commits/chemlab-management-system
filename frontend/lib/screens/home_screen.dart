import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/screens/dashboard_screen.dart';
import 'package:chemlab_frontend/screens/chemicals_screen.dart';
import 'package:chemlab_frontend/screens/equipment_screen.dart';
import 'package:chemlab_frontend/screens/borrowings_screen.dart';
import 'package:chemlab_frontend/screens/reports_screen.dart';
import 'package:chemlab_frontend/screens/users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  late List<String> _titles;

  @override
  void initState() {
    super.initState();
    _updateScreens();
  }

  void _updateScreens() {
    final userRole = Provider.of<AuthProvider>(context, listen: false).userRole;

    _screens = [
      const DashboardScreen(),
      const ChemicalsScreen(),
      const EquipmentScreen(),
      const BorrowingsScreen(),
      const ReportsScreen(),
    ];

    _titles = [
      'Dashboard',
      'Chemicals',
      'Equipment',
      'Borrowings',
      'Reports',
    ];

    // Add Users screen for admin
    if (userRole == 'admin') {
      _screens.add(const UsersScreen());
      _titles.add('Users');
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
    final userRole = authProvider.userRole;

    // Update screens if role changes
    if (_screens.length != _titles.length ||
        (userRole == 'admin' && _screens.length == 5)) {
      _updateScreens();
    }

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
                  // TODO: Implement profile screen
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
        items: [
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
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          if (userRole == 'admin')
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
