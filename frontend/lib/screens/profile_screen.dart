import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  // Add controllers for enhanced fields
  late TextEditingController _phoneController;
  late TextEditingController _studentIdController;
  late TextEditingController _institutionController;
  late TextEditingController _departmentController;
  late TextEditingController _educationLevelController;
  late TextEditingController _semesterController;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  bool _isEditing = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user!;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    // Initialize enhanced field controllers
    _phoneController = TextEditingController(text: user.phone ?? '');
    _studentIdController = TextEditingController(text: user.studentId ?? '');
    _institutionController =
        TextEditingController(text: user.institution ?? '');
    _departmentController = TextEditingController(text: user.department ?? '');
    _educationLevelController =
        TextEditingController(text: user.educationLevel ?? '');
    _semesterController = TextEditingController(text: user.semester ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    // Dispose enhanced field controllers
    _phoneController.dispose();
    _studentIdController.dispose();
    _institutionController.dispose();
    _departmentController.dispose();
    _educationLevelController.dispose();
    _semesterController.dispose();
    // Dispose password controllers
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing && !_isChangingPassword)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue[100],
                      child: Icon(
                        user.role == 'admin'
                            ? Icons.admin_panel_settings
                            : user.role == 'technician'
                                ? Icons.build
                                : Icons.person,
                        size: 50,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing && !_isChangingPassword) ...[
                      _buildInfoCard('Name', user.name),
                      _buildInfoCard('Email', user.email),
                      // Display enhanced information
                      if (user.phone != null && user.phone!.isNotEmpty)
                        _buildInfoCard('Phone', user.phone!),
                      if (user.studentId != null && user.studentId!.isNotEmpty)
                        _buildInfoCard('Student ID', user.studentId!),
                      if (user.institution != null &&
                          user.institution!.isNotEmpty)
                        _buildInfoCard('Institution', user.institution!),
                      if (user.department != null &&
                          user.department!.isNotEmpty)
                        _buildInfoCard('Department', user.department!),
                      if (user.educationLevel != null &&
                          user.educationLevel!.isNotEmpty)
                        _buildInfoCard('Education Level', user.educationLevel!),
                      if (user.semester != null && user.semester!.isNotEmpty)
                        _buildInfoCard('Semester', user.semester!),
                      _buildInfoCard(
                        'Role',
                        user.role.toUpperCase(),
                        isRole: true,
                      ),
                      _buildInfoCard(
                        'Member Since',
                        '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isChangingPassword = true;
                          });
                        },
                        child: const Text('Change Password'),
                      ),
                    ] else if (_isEditing)
                      _buildEditForm(authProvider)
                    else if (_isChangingPassword)
                      _buildPasswordChangeForm(authProvider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, {bool isRole = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: isRole
                  ? (value == 'ADMIN'
                      ? Colors.red
                      : value == 'TECHNICIAN'
                          ? Colors.green
                          : Colors.blue)
                  : Colors.black,
              fontWeight: isRole ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Enhanced fields for editing
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _studentIdController,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _institutionController,
            decoration: const InputDecoration(
              labelText: 'Institution',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _departmentController,
            decoration: const InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _educationLevelController,
            decoration: const InputDecoration(
              labelText: 'Education Level',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _semesterController,
            decoration: const InputDecoration(
              labelText: 'Semester',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Profile update completed successfully
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Profile updated successfully!')),
                    );

                    // Exit edit mode
                    setState(() {
                      _isEditing = false;
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeForm(AuthProvider authProvider) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmNewPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isChangingPassword = false;
                    // Clear password fields
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmNewPasswordController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_passwordFormKey.currentState!.validate()) {
                    try {
                      await ApiService.changePassword({
                        'current_password': _currentPasswordController.text,
                        'new_password': _newPasswordController.text,
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Password changed successfully! Please login again.')),
                        );

                        // Clear password fields
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmNewPasswordController.clear();

                        // Exit password change mode
                        setState(() {
                          _isChangingPassword = false;
                        });

                        // Optional: Logout user to force re-login with new password
                        // authProvider.logout();
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to change password: ${error.toString()}')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Change Password'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
