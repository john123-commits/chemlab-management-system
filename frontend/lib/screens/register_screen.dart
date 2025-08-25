import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();

  final String _selectedRole = 'borrower';
  String _selectedInstitution = '';
  String _selectedEducationLevel = '';
  String _selectedSemester = '';
  String _selectedDepartment = '';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Predefined institutions (you can modify based on your region)
  final List<String> _institutions = [
    'Busitema University',
    'Makerere University',
    'Kyambogo University',
    'Mbarara University',
    'Gulu University',
    'Uganda Christian University',
    'Islamic University in Uganda',
    'Kampala International University',
    'Other'
  ];

  final List<String> _educationLevels = [
    'Certificate',
    'Diploma',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'PhD',
    'Postgraduate Diploma'
  ];

  final List<String> _semesters = [
    'Semester 1',
    'Semester 2',
    'Year 1',
    'Year 2',
    'Year 3',
    'Year 4',
    'Year 5',
    'Final Year'
  ];

  final List<String> _departments = [
    'Chemistry',
    'Biology',
    'Physics',
    'Biochemistry',
    'Environmental Science',
    'Chemical Engineering',
    'Biomedical Sciences',
    'Pharmacy',
    'Medicine',
    'Nursing',
    'Agriculture',
    'Food Science',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Enhanced registration data
        await Provider.of<AuthProvider>(context, listen: false).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          // Additional institutional data
          phone: _phoneController.text.trim(),
          studentId: _studentIdController.text.trim(),
          institution: _selectedInstitution,
          educationLevel: _selectedEducationLevel,
          semester: _selectedSemester,
          department: _selectedDepartment,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registration successful! Please wait for admin approval.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String? _validateInstitutionEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your institutional email';
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Please enter a valid email format';
    }

    if (!value.toLowerCase().endsWith('.edu') &&
        !value.toLowerCase().endsWith('.ac.ug') &&
        !value.toLowerCase().endsWith('.edu.ug')) {
      return 'Please use your institutional email (.edu, .ac.ug, or .edu.ug)';
    }

    // Validate institution match
    if (_selectedInstitution.isNotEmpty) {
      String domain = value.split('@')[1].toLowerCase();
      String institutionKey = _selectedInstitution.toLowerCase();

      // Basic domain validation (you can enhance this)
      if (institutionKey.contains('busitema') && !domain.contains('busitema')) {
        return 'Email domain should match selected institution';
      }
      if (institutionKey.contains('makerere') && !domain.contains('mak')) {
        return 'Email domain should match selected institution';
      }
      // Add more validations as needed
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    // Uganda phone number validation
    if (!RegExp(r'^(\+256|0)[0-9]{9}$').hasMatch(value.replaceAll(' ', ''))) {
      return 'Please enter a valid phone number (+256XXXXXXXXX or 07XXXXXXXX)';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Registration'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Student Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your institutional details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Personal Information Section
              _buildSectionHeader('Personal Information'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  hintText: 'Enter your full name as on student ID',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  if (value.trim().split(' ').length < 2) {
                    return 'Please enter your full name (first and last name)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '+256XXXXXXXXX or 07XXXXXXXX',
                ),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 24),

              // Institutional Information Section
              _buildSectionHeader('Institutional Information'),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value:
                    _selectedInstitution.isEmpty ? null : _selectedInstitution,
                decoration: const InputDecoration(
                  labelText: 'Institution *',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                ),
                items: _institutions.map((institution) {
                  return DropdownMenuItem(
                    value: institution,
                    child: Text(institution),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInstitution = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your institution';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Institutional Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  hintText: 'john@institution.edu',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validateInstitutionEmail,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(
                  labelText: 'Student ID/Registration Number *',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                  hintText: 'Enter your student ID number',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your student ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department/Faculty *',
                  prefixIcon: Icon(Icons.science),
                  border: OutlineInputBorder(),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Text(dept),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your department';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Academic Information Section
              _buildSectionHeader('Academic Information'),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedEducationLevel.isEmpty
                    ? null
                    : _selectedEducationLevel,
                decoration: const InputDecoration(
                  labelText: 'Level of Education *',
                  prefixIcon: Icon(Icons.school_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _educationLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEducationLevel = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your education level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedSemester.isEmpty ? null : _selectedSemester,
                decoration: const InputDecoration(
                  labelText: 'Current Semester/Year *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                items: _semesters.map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSemester = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your current semester/year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Security Section
              _buildSectionHeader('Security'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: const OutlineInputBorder(),
                  hintText: 'Minimum 8 characters',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
                    return 'Password must contain both letters and numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Information Card
              Card(
                color: Colors.blue[50],
                elevation: 2,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 28),
                      SizedBox(height: 8),
                      Text(
                        'Registration Requirements',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('• Use your official institutional email address'),
                      Text('• Provide accurate student ID for verification'),
                      Text('• Account will be reviewed before activation'),
                      Text(
                          '• Only registered students can access lab resources'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Register Student Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Login here'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
