import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? name;
  final String? examYear;
  final bool isRegister;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.name,
    this.examYear,
    this.isRegister = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _resendSeconds = 60;
  bool _canResend = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _nodes[0].requestFocus();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _canResend = false;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) _canResend = true;
      });
      return _resendSeconds > 0;
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(
      _otp,
      phone: widget.phoneNumber,
      name: widget.name,
      examYear: widget.examYear,
    );

    if (success && mounted) {
      if (widget.isRegister) {
        // Show optional DP setup step for new registrants
        _showDpSetupDialog();
      } else {
        context.go(auth.isAdmin ? '/admin' : '/student');
      }
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await File(image.path).readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await context.read<AuthProvider>().updateProfilePhoto(base64String);
      }
    } catch (e) {
      debugPrint('Error uploading DP on register: $e');
    } finally {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        context.go(auth.isAdmin ? '/admin' : '/student');
      }
    }
  }

  void _showDpSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.backgroundSoft,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Profile Picture 📸',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your photo so your teachers and classmates can recognize you in the leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),

            // Take Photo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Choose from Gallery
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Skip Button
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                context.go(auth.isAdmin ? '/admin' : '/student');
              },
              child: const Text(
                'Skip for Now',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Verify WhatsApp OTP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit verification code to your WhatsApp:\n'),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) {
                      _nodes[i + 1].requestFocus();
                    } else if (val.isEmpty && i > 0) {
                      _nodes[i - 1].requestFocus();
                    }
                    if (_otp.length == 6) {
                      _verify();
                    }
                  },
                )),
              ),
              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _verify,
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
                          'Verify & Login 🚀',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: () async {
                          await context.read<AuthProvider>().sendOtp(
                                widget.phoneNumber,
                                name: widget.name,
                                examYear: widget.examYear,
                              );
                          _startResendTimer();
                        },
                        child: const Text(
                          'Resend OTP Code',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Text(
                        'Resend code in ${_resendSeconds}s',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
              ),

              const SizedBox(height: 12),

              // Instant WhatsApp Direct Code Helper
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openWhatsAppForCode,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                  label: const Text(
                    'Get Code via WhatsApp 💬',
                    style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsAppForCode() async {
    final cleanPhone = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/94701068489?text=OTP%20for%20%2B$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;

    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue ? AppColors.primary : AppColors.border,
          width: hasValue ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }
}
