import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';

class UserFormScreen extends StatefulWidget {
  final User? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'borrower';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _emailController.text = widget.user!.email;
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final currentUser =
            Provider.of<AuthProvider>(context, listen: false).user!;

        // Prepare user data
        final userData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
        };

        // Add password only for new users or when changing password
        if (widget.user == null || _passwordController.text.isNotEmpty) {
          if (_passwordController.text.isNotEmpty) {
            userData['password'] = _passwordController.text;
          } else if (widget.user == null) {
            // For new users, password is required
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Password is required for new users')),
            );
            setState(() => _isLoading = false);
            return;
          }
        }

        if (widget.user == null) {
          // Create new user - only admins can do this
          if (currentUser.role != 'admin') {
            throw Exception('Only admins can create new users');
          }

          await ApiService.createStaffUser(userData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User created successfully')),
          );
        } else {
          // Update existing user
          if (currentUser.role != 'admin' &&
              currentUser.id != widget.user!.id) {
            throw Exception(
                'Permission denied: You can only update your own profile');
          }

          await ApiService.updateUser(widget.user!.id, userData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User updated successfully')),
          );
        }

        Navigator.pop(context, true);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: ${error.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user!;
    final isCurrentUserAdmin = currentUser.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user == null ? 'Add User' : 'Edit User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  border: const OutlineInputBorder(),
                  hintText: _selectedRole == 'admin'
                      ? 'user@example.com'
                      : 'user@institution.edu', // ✅ Added contextual hint
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }

                  // ✅ Institutional email requirement for technicians and borrowers
                  if (_selectedRole != 'admin') {
                    // List of acceptable institutional domains
                    final allowedDomains = [
                      '.edu', // Educational institutions
                      '.ac.', // Academic institutions (e.g., .ac.uk, .ac.ug)
                      '.org', // Non-profit organizations
                      '.gov' // Government institutions
                    ];

                    bool hasValidDomain = false;
                    for (var domain in allowedDomains) {
                      if (value.toLowerCase().contains(domain)) {
                        hasValidDomain = true;
                        break;
                      }
                    }

                    if (!hasValidDomain) {
                      return '⚠️ Institutional email required\n'
                          '✅ Must end with: .edu, .ac, .org, or .gov\n'
                          '📝 Examples:\n'
                          '   • student@university.edu\n'
                          '   • tech@college.ac.uk\n'
                          '   • staff@institute.org';
                    }
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: widget.user == null
                      ? 'Password *'
                      : 'New Password (leave blank to keep current)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (widget.user == null && (value == null || value.isEmpty)) {
                    return 'Please enter password';
                  }
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: widget.user == null
                      ? 'Confirm Password *'
                      : 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (widget.user == null && (value == null || value.isEmpty)) {
                    return 'Please confirm password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Only admins can change user roles
              if (isCurrentUserAdmin) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'borrower', child: Text('Borrower')),
                    DropdownMenuItem(
                        value: 'technician', child: Text('Technician')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Non-admins see their role but can't change it
                TextFormField(
                  initialValue: widget.user?.role.toUpperCase() ?? 'BORROWER',
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          widget.user == null ? 'Create User' : 'Update User',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
