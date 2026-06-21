import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_toast.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedCategory = 'Suggestion';
  bool _isLoading = false;
  bool _isPreloading = true;

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  final List<String> _categories = [
    'Suggestion',
    'Bug Report',
    'Feature Request',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadPreloadedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNumberController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPreloadedData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      
      // Load Roll Number
      String? rollNumber = preferences.getString('student_roll_number');
      if (rollNumber == null || rollNumber.isEmpty) {
        final storedCredentials = preferences.getString('uni_credentials');
        if (storedCredentials != null && storedCredentials.isNotEmpty) {
          try {
            final decoded = jsonDecode(storedCredentials);
            if (decoded is Map<String, dynamic>) {
              rollNumber = decoded['roll_number'];
            }
          } catch (_) {}
        }
      }

      // Load Name
      String? name;
      final storedDashboard = preferences.getString('flex_dashboard_data');
      if (storedDashboard != null && storedDashboard.isNotEmpty) {
        try {
          final decoded = jsonDecode(storedDashboard);
          if (decoded is Map<String, dynamic>) {
            name = decoded['name'];
          }
        } catch (_) {}
      }

      setState(() {
        if (name != null) _nameController.text = name.trim();
        if (rollNumber != null) _rollNumberController.text = rollNumber.trim();
        _isPreloading = false;
      });
    } catch (_) {
      setState(() {
        _isPreloading = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final rollNumber = _rollNumberController.text.trim().toUpperCase();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    final result = await ApiService.submitFeedback(
      name: name.isNotEmpty ? name : 'Anonymous',
      rollNumber: rollNumber.isNotEmpty ? rollNumber : 'N/A',
      email: email.isNotEmpty ? email : 'N/A',
      category: _selectedCategory,
      message: message,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success']) {
      final emailSent = result['emailSent'] ?? true;
      _showSuccessDialog(emailSent, result['message']);
    } else {
      _showErrorSnackBar(result['message']);
    }
  }

  void _showSuccessDialog(bool emailSent, String serverMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: emailSent ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emailSent ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: emailSent ? const Color(0xFF059669) : const Color(0xFFD97706),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emailSent ? 'Thank You!' : 'Submitted to Server',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : _ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emailSent 
                    ? 'Your feedback has been successfully emailed to flexconnect03@gmail.com. We appreciate your suggestions!'
                    : 'Your feedback was successfully saved on the server! Note: $serverMessage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Pop dialog
                    Navigator.pop(context); // Return to More screen
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String errorMsg) {
    CustomToast.showError(context, errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: _isPreloading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark ? Colors.white : _ink,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                            ),
                            child: const Icon(
                              Icons.rate_review_outlined,
                              color: _accent,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'App Feedback',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      // Title
                      Text(
                        'Send Feedback',
                        style: TextStyle(
                          color: isDark ? Colors.white : _ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'HELP US IMPROVE FLEX CONNECT',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Category Selector
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FEEDBACK CATEGORY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.grey[400] : _muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return ChoiceChip(
                                  label: Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : _ink),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedCategory = cat;
                                      });
                                    }
                                  },
                                  selectedColor: _accent,
                                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected
                                          ? _accent
                                          : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Fields Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            _buildLabel('YOUR NAME', isDark),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(color: isDark ? Colors.white : _ink),
                              decoration: _buildInputDecoration('Enter your name (Optional)', isDark),
                            ),
                            const SizedBox(height: 16),

                            // Roll Number
                            _buildLabel('UNIVERSITY ROLL NUMBER', isDark),
                            TextFormField(
                              controller: _rollNumberController,
                              style: TextStyle(color: isDark ? Colors.white : _ink),
                              decoration: _buildInputDecoration('e.g. 23L-0000 (Optional)', isDark),
                            ),
                            const SizedBox(height: 16),

                            // Email
                            _buildLabel('EMAIL ADDRESS (FOR REPLIES)', isDark),
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: isDark ? Colors.white : _ink),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _buildInputDecoration('Enter your email (Optional)', isDark),
                            ),
                            const SizedBox(height: 16),

                            // Message
                            _buildLabel('YOUR MESSAGE / SUGGESTION', isDark, required: true),
                            TextFormField(
                              controller: _messageController,
                              style: TextStyle(color: isDark ? Colors.white : _ink),
                              maxLines: 5,
                              maxLength: 1000,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your suggestion or feedback';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration('Tell us what we can improve, report a bug, or suggest a new feature...', isDark).copyWith(
                                counterStyle: TextStyle(color: isDark ? Colors.grey[500] : _muted, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submitFeedback,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Submit Feedback',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildLabel(String text, bool isDark, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : _muted,
              letterSpacing: 0.5,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : _muted, fontSize: 13),
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
