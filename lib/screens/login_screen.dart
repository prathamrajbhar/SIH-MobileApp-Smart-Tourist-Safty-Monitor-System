import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/tourist.dart';
import '../widgets/modern_app_wrapper.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isLoginMode = true; // true for login, false for register

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingUser() async {
    await _apiService.initializeAuth();
    
    // Only try to get current user if we have a valid token
    if (_apiService.isAuthenticated) {
      final response = await _apiService.getCurrentUser();
      
      if (response['success'] == true) {
        final userData = response['user'];
        final tourist = Tourist.fromJson(userData);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ModernAppWrapper(tourist: tourist),
            ),
          );
        }
      }
    }
    // If no valid token or getCurrentUser fails, user stays on login screen
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.loginTourist(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response['success'] == true) {
        // Get current user profile with enhanced error handling
        final userResponse = await _apiService.getCurrentUser();
        if (userResponse['success'] == true) {
          final tourist = Tourist.fromJson(userResponse['user']);
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ModernAppWrapper(tourist: tourist),
              ),
            );
          }
        } else {
          // Handle 403/token corruption specifically
          if (userResponse['message']?.contains('corrupted') == true) {
            _showError('Authentication token corrupted. Please try logging in again.');
          } else if (userResponse['message']?.contains('403') == true) {
            _showError('Access denied. Please check your credentials and try again.');
          } else {
            _showError(userResponse['message'] ?? 'Failed to load user profile');
          }
        }
      } else {
        _showError(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      _showConnectionError('Connection failed. Please check your internet connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.registerTourist(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        emergencyContact: _emergencyContactController.text.trim().isNotEmpty ? _emergencyContactController.text.trim() : null,
        emergencyPhone: _emergencyPhoneController.text.trim().isNotEmpty ? _emergencyPhoneController.text.trim() : null,
      );

      if (response['success'] == true) {
        _showSuccess('Registration successful! Please login with your credentials.');
        setState(() {
          _isLoginMode = true;
        });
      } else {
        _showError(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showError('Registration failed. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showConnectionError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }



  void _switchMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _emergencyContactController.clear();
      _emergencyPhoneController.clear();
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isLoginMode && (value == null || value.trim().isEmpty)) {
      return 'Name is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Logo/Title
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                const Text(
                  'SafeHorizon',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  _isLoginMode ? 'Welcome back!' : 'Create your account',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // Name field (only for registration)
                if (!_isLoginMode) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: _validateName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  obscureText: true,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Additional fields for registration
                if (!_isLoginMode) ...[
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emergencyContactController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Name (Optional)',
                      prefixIcon: Icon(Icons.contact_emergency_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emergencyPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Phone (Optional)',
                      prefixIcon: Icon(Icons.phone_in_talk_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                const SizedBox(height: AppSpacing.lg),
                
                // Login/Register button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_isLoginMode ? _login : _register),
                    style: primaryButtonStyle,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isLoginMode ? 'Sign In' : 'Create Account'),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Switch mode button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoginMode
                          ? "Don't have an account? "
                          : "Already have an account? ",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _switchMode,
                      style: textButtonStyle,
                      child: Text(
                        _isLoginMode ? 'Sign Up' : 'Sign In',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
