import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/main_screen.dart';
import '../../services/update_service.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  static const String credentialsKey = 'uni_credentials';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _hasCredentials = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCredentialsState();
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentialsState() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCredentials = preferences.getString(credentialsKey);
    final hasCredentials = _isValidStoredCredentials(storedCredentials);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCredentials = hasCredentials;
      _isLoading = false;
    });
  }

  bool _isValidStoredCredentials(String? storedCredentials) {
    if (storedCredentials == null || storedCredentials.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(storedCredentials);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final rollNumber = decoded['roll_number'];
      final password = decoded['password'];
      return rollNumber is String &&
          rollNumber.isNotEmpty &&
          password is String &&
          password.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String? _validateRollNumber(String? value) {
    final rollNumber = value?.trim() ?? '';
    if (rollNumber.isEmpty) {
      return 'Enter your university roll number';
    }

    final isValid = RegExp(r'^\d{2}[a-zA-Z]-\d{4}$').hasMatch(rollNumber);
    if (!isValid) {
      return 'Use format like 23L-0000';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Enter your password';
    }

    return null;
  }

  Future<void> _saveCredentials() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final preferences = await SharedPreferences.getInstance();
    final rollNumber = _rollNumberController.text.trim().toUpperCase();
    final password = _passwordController.text;

    await preferences.setString(
      credentialsKey,
      jsonEncode({'roll_number': rollNumber, 'password': password}),
    );

    // Initialize default sync semester code based on the student's batch year Fall
    if (rollNumber.length >= 2) {
      final yrPart = int.tryParse(rollNumber.substring(0, 2));
      if (yrPart != null) {
        final yr = 2000 + yrPart;
        await preferences.setString('flex_selected_sync_semester', '${yr}3');
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCredentials = true;
      _isSaving = false;
    });
  }

  Widget _buildMaterialApp(Widget home) {
    return MaterialApp(
      title: 'Flex Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      themeMode: ThemeMode.light,
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildMaterialApp(
        const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2563EB),
            ),
          ),
        ),
      );
    }

    if (_hasCredentials) {
      return _buildMaterialApp(const MainScreen());
    }

    return _buildMaterialApp(
      Scaffold(
        body: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              UpdateService.checkForUpdates(context);
            });

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo & Brand Header
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/logo.jpg',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Flex Connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'YOUR ACADEMIC HUB',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Login Form Container Card
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set up university account'.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your credentials to sync your dashboard.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Roll Number Field
                                _buildLabel('University Roll Number', isDark),
                                TextFormField(
                                  controller: _rollNumberController,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: _buildInputDecoration('e.g. 23L-0000', isDark),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                                    const RollNumberFormatter(),
                                  ],
                                  validator: _validateRollNumber,
                                ),
                                const SizedBox(height: 18),

                                // Password Field
                                _buildLabel('Portal Password', isDark),
                                TextFormField(
                                  controller: _passwordController,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: _buildInputDecoration('Enter your password', isDark),
                                  obscureText: true,
                                  validator: _validatePassword,
                                ),
                                const SizedBox(height: 28),

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isSaving ? null : _saveCredentials,
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

class RollNumberFormatter extends TextInputFormatter {
  const RollNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Force uppercase
    String text = newValue.text.toUpperCase();
    int selectionIndex = newValue.selection.end;

    // If deleting text, let it be deleted normally
    if (newValue.text.length < oldValue.text.length) {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: selectionIndex),
      );
    }

    // Auto-formatting rule 1: If length is 3 (e.g. "23L"), append "-"
    if (text.length == 3) {
      final reg = RegExp(r'^\d{2}[A-Z]$');
      if (reg.hasMatch(text)) {
        text = '$text-';
        selectionIndex = text.length;
      }
    } 
    // Auto-formatting rule 2: If typed without hyphen (e.g., pasting "23L3038" or typing "23L3")
    else if (text.length > 3 && !text.contains('-')) {
      final reg = RegExp(r'^(\d{2})([A-Z])(.*)$');
      final match = reg.firstMatch(text);
      if (match != null) {
        text = '${match.group(1)}${match.group(2)}-${match.group(3)}';
        selectionIndex = text.length;
      }
    }

    // Max length constraint: 8 characters ("23L-0000")
    if (text.length > 8) {
      text = text.substring(0, 8);
      if (selectionIndex > 8) selectionIndex = 8;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
