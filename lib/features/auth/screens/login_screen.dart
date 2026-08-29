import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login Controllers
  final _loginPhoneCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _obscureLoginPw = true;

  // Register Controllers
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmPasswordCtrl = TextEditingController();
  bool _obscureRegPw = true;
  bool _obscureRegConfirmPw = true;

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
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  String _cleanPhone(String raw) {
    var digits = raw.trim();
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '$_countryCode$digits';
  }

  // ── 1. LOGIN WITH PASSWORD (Instant) ──────────────────────────────────────
  Future<void> _handlePasswordLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    HapticFeedbackService.light();

    final phone = _cleanPhone(_loginPhoneCtrl.text);
    final password = _loginPasswordCtrl.text.trim();

    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithPassword(phone: phone, password: password);

    if (success && mounted) {
      HapticFeedbackService.success();
      context.go(auth.isAdmin ? '/admin' : '/student');
    } else if (!success && mounted) {
      _showError(auth.error ?? 'Invalid phone number or password.');
    }
  }

  // ── 2. LOGIN WITH WHATSAPP 1-TAP OTP ──────────────────────────────────────
  Future<void> _handleWhatsAppOtpLogin() async {
    final rawNumber = _loginPhoneCtrl.text.trim();
    if (rawNumber.isEmpty) {
      _showError('Please enter your phone number first');
      return;
    }

    HapticFeedbackService.medium();
    final phone = _cleanPhone(rawNumber);
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');

    final auth = context.read<AuthProvider>();
    final otpCode = await auth.prepareWhatsAppLoginOtp(phone);

    // Open WhatsApp prefilled with clean, professional request message
    final message = 'Hi EduPeak! Please send my login verification code for +$cleanDigits';
    final uri = Uri.parse(
      'https://wa.me/94707938883?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      context.push('/auth/otp', extra: {
        'phone': phone,
        'isRegister': false,
      });
    }
  }

  // ── 3. REGISTER WITH PASSWORD (Instant, No waiting) ───────────────────────
  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    HapticFeedbackService.light();

    final phone = _cleanPhone(_regPhoneCtrl.text);
    final name = _regNameCtrl.text.trim();
    final password = _regPasswordCtrl.text.trim();

    final auth = context.read<AuthProvider>();
    final success = await auth.registerWithPassword(
      name: name,
      phone: phone,
      password: password,
      examYear: _selectedExamYear,
    );

    if (success && mounted) {
      HapticFeedbackService.success();
      context.go(auth.isAdmin ? '/admin' : '/student');
    } else if (!success && mounted) {
      _showError(auth.error ?? 'Registration failed. Please try again.');
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
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.cake_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'EduPeak',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'A/L Pastry & Dessert Institute 🍰',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
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
                      'Secure authentication for EduPeak Students',
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
      onTap: () {
        HapticFeedbackService.light();
        setState(() => _selectedTabIndex = index);
      },
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

  // ── 1. LOGIN FORM (Phone + Password OR WhatsApp 1-Tap OTP) ────────────────
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
              'Sign In',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your phone number and password to access your portal',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Phone Field
            _buildPhoneInput(_loginPhoneCtrl),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _loginPasswordCtrl,
              obscureText: _obscureLoginPw,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLoginPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureLoginPw = !_obscureLoginPw),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your password' : null,
            ),
            const SizedBox(height: 20),

            // Primary: Sign In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.loading ? null : _handlePasswordLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                        'Sign In 🚀',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // OR Divider
            Row(
              children: const [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),

            const SizedBox(height: 16),

            // Secondary: WhatsApp 1-Tap OTP Login Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: auth.loading ? null : _handleWhatsAppOtpLogin,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 19),
                label: const Text(
                  'Login via WhatsApp OTP 💬',
                  style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. REGISTER FORM (Name + Phone + Exam Year + Password) ────────────────
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
              'Create your password to instantly access your portal',
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
            const SizedBox(height: 14),

            // Phone Input
            _buildPhoneInput(_regPhoneCtrl),
            const SizedBox(height: 14),

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
            const SizedBox(height: 14),

            // Password Input
            TextFormField(
              controller: _regPasswordCtrl,
              obscureText: _obscureRegPw,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Create Password',
                hintText: 'Min 4 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureRegPw = !_obscureRegPw),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Password required';
                if (v.trim().length < 4) return 'Password must be at least 4 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password Input
            TextFormField(
              controller: _regConfirmPasswordCtrl,
              obscureText: _obscureRegConfirmPw,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegConfirmPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureRegConfirmPw = !_obscureRegConfirmPw),
                ),
              ),
              validator: (v) {
                if (v != _regPasswordCtrl.text.trim()) return 'Passwords do not match';
                return null;
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
                        'Create Account (Instant Sign-in) 🚀',
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
