import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginPhoneCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();

  static const String _countryCode = '+94';
  int _selectedTabIndex = 0; // 0 = Login, 1 = Register

  final List<String> _examYears = ['2024 A/L', '2025 A/L', '2026 A/L', '2027 A/L', '2028 A/L', 'Other'];
  late String _selectedExamYear;

  @override
  void initState() {
    super.initState();
    _selectedExamYear = _examYears[1]; // Default: 2025 A/L
  }

  @override
  void dispose() {
    _loginPhoneCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    String cleanNumber = _loginPhoneCtrl.text.trim();
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }
    final phone = '$_countryCode$cleanNumber';

    final auth = context.read<AuthProvider>();
    final success = await auth.sendOtp(phone);

    if (success && mounted) {
      context.push('/auth/otp', extra: {
        'phone': phone,
        'isRegister': false,
      });
    } else if (!success && mounted) {
      _showError(auth.error ?? 'Failed to send OTP. Please check your connection.');
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    String cleanNumber = _regPhoneCtrl.text.trim();
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }
    final phone = '$_countryCode$cleanNumber';
    final name = _regNameCtrl.text.trim();

    final auth = context.read<AuthProvider>();
    final success = await auth.sendOtp(phone, name: name, examYear: _selectedExamYear);

    if (success && mounted) {
      context.push('/auth/otp', extra: {
        'phone': phone,
        'name': name,
        'examYear': _selectedExamYear,
        'isRegister': true,
      });
    } else if (!success && mounted) {
      _showError(auth.error ?? 'Failed to send OTP. Please check your connection.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── EduPeak Logo & Header ────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/edupeak_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'EduPeak',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Advanced Level Student Portal',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Login / Register Segmented Switcher ──────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton('Sign In', 0),
                    ),
                    Expanded(
                      child: _buildSegmentButton('Register', 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tab View Content ─────────────────────────────────
              if (_selectedTabIndex == 0) _buildLoginForm(auth) else _buildRegisterForm(auth),

              const SizedBox(height: 32),

              // ── Footer Note ──────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Secure login via official WhatsApp OTP',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. LOGIN FORM (Just Phone Number) ──────────────────────────────
  Widget _buildLoginForm(AuthProvider auth) {
    return Form(
      key: _loginFormKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In with Phone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your registered phone number to receive your login code',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Phone Field
            _buildPhoneInput(_loginPhoneCtrl),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.loading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Send WhatsApp OTP 💬',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. REGISTER FORM (Name + Phone + Exam Year) ───────────────────
  Widget _buildRegisterForm(AuthProvider auth) {
    return Form(
      key: _registerFormKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Student Registration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create your EduPeak student account to access homework & tutor',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Full Name Input
            TextFormField(
              controller: _regNameCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Thisaru Udara',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your full name' : null,
            ),
            const SizedBox(height: 16),

            // Phone Input
            _buildPhoneInput(_regPhoneCtrl),
            const SizedBox(height: 16),

            // Exam Year Dropdown
            DropdownButtonFormField<String>(
              value: _selectedExamYear,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'A/L Examination Year',
                prefixIcon: Icon(Icons.school_outlined, color: AppColors.textMuted),
              ),
              items: _examYears
                  .map((year) => DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedExamYear = val);
              },
            ),
            const SizedBox(height: 24),

            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.loading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Account & Get Code 🚀',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput(TextEditingController controller) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇱🇰 ', style: TextStyle(fontSize: 16)),
              Text(
                '+94',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '7XXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final digits = v.trim().replaceAll(RegExp(r'\D'), '');
              if (digits.length < 8) return 'Enter a valid number';
              return null;
            },
          ),
        ),
      ],
    );
  }
}
