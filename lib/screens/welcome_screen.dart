import 'package:flutter/material.dart';
import '../utils/user_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const WelcomeScreen({super.key, required this.onComplete});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = 'male'; // Default to male
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveUserInfo() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Save user data
      await UserPreferences.setName(_nameController.text.trim());
      await UserPreferences.setGender(_selectedGender);
      await UserPreferences.completeFirstLaunch();

      // Notify parent
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: const Image(
                              image: AssetImage('assets/images/logo.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Welcome Text
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'SAT Exam Prep',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 50),
                      // Name Input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your name',
                              border: InputBorder.none,
                              icon: Icon(
                                Icons.person_outline,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Gender Selection
                      const Text(
                        'Select Your Gender',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGenderOption(
                            label: 'Male',
                            value: 'male',
                            icon: Icons.male_rounded,
                          ),
                          const SizedBox(width: 20),
                          _buildGenderOption(
                            label: 'Female',
                            value: 'female',
                            icon: Icons.female_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),
                      // Get Started Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveUserInfo,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1976D2),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'GET STARTED',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedGender == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border:
                  isSelected ? Border.all(color: Colors.white, width: 3) : null,
            ),
            child: Icon(
              icon,
              size: 50,
              color: isSelected
                  ? const Color(0xFF1976D2)
                  : Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
