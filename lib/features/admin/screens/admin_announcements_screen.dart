import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../auth/providers/auth_provider.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _priority = 'normal'; // 'normal', 'urgent', 'homework', 'tip'
  String _targetType = 'all'; // 'all', 'year', 'single'
  String _selectedExamYear = '2026 A/L';
  String? _selectedStudentPhone;
  String? _selectedStudentName;

  bool _isSending = false;

  final List<String> _examYears = [
    '2025 A/L',
    '2026 A/L',
    '2027 A/L',
    '2028 A/L',
    'O/L',
  ];

  static const String _botToken = '8837234143:AAEFLrgpMuTa4bxwIxl-SDqAuOy4P_o7vtI';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── Dispatch Broadcast to Telegram & Firestore ─────────────────────────────
  Future<void> _handleBroadcast() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'single' && _selectedStudentPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student to send the announcement to.')),
      );
      return;
    }

    HapticFeedbackService.medium();
    setState(() => _isSending = true);

    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final auth = context.read<AuthProvider>();
    final adminName = auth.user?.name ?? 'EduPeak Admin';

    try {
      final db = FirebaseFirestore.instance;

      // 1. Query target students
      Query<Map<String, dynamic>> query = db.collection('users').where('role', isEqualTo: 'student');
      if (_targetType == 'year') {
        query = query.where('examYear', isEqualTo: _selectedExamYear);
      }

      final snap = await query.get();
      final List<Map<String, dynamic>> targetStudents = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        if (_targetType == 'single' && _selectedStudentPhone != null) {
          if (data['phone'] != _selectedStudentPhone && !(data['phone']?.toString().endsWith(_selectedStudentPhone!) ?? false)) {
            continue;
          }
        }
        if (data['telegramChatId'] != null && data['telegramChatId'].toString().isNotEmpty) {
          targetStudents.add({
            'name': data['name'] ?? 'Student',
            'chatId': data['telegramChatId'].toString(),
            'phone': data['phone'] ?? '',
            'examYear': data['examYear'] ?? 'A/L',
          });
        }
      }

      int sentCount = 0;
      int failedCount = 0;

      final priorityEmoji = _priority == 'urgent'
          ? '🚨'
          : _priority == 'homework'
              ? '📝'
              : _priority == 'tip'
                  ? '💡'
                  : '📢';

      final tgText = '$priorityEmoji <b>EduPeak Announcement</b>\n\n'
          '<b>$title</b>\n\n'
          '$message\n\n'
          '<i>— $adminName • EduPeak Institute</i>';

      // 2. Dispatch to each student via Telegram Bot API
      for (final s in targetStudents) {
        try {
          final res = await http.post(
            Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': s['chatId'],
              'text': tgText,
              'parse_mode': 'HTML',
              'reply_markup': {
                'inline_keyboard': [
                  [
                    {'text': '📱 Open Student Portal', 'url': 'https://edupeak.lk'},
                    {'text': '📚 Ask AI Tutor', 'callback_data': 'btn_ask_tutor'}
                  ]
                ]
              }
            }),
          );

          if (res.statusCode == 200) {
            sentCount++;
          } else {
            failedCount++;
          }
        } catch (_) {
          failedCount++;
        }
      }

      // 3. Save Record in Firestore announcements collection
      await db.collection('announcements').add({
        'title': title,
        'message': message,
        'priority': _priority,
        'targetType': _targetType,
        'targetExamYear': _targetType == 'year' ? _selectedExamYear : null,
        'targetStudentName': _targetType == 'single' ? _selectedStudentName : null,
        'targetStudentPhone': _targetType == 'single' ? _selectedStudentPhone : null,
        'adminName': adminName,
        'recipientsTargeted': targetStudents.length,
        'sentCount': sentCount,
        'failedCount': failedCount,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        HapticFeedbackService.success();
        _titleCtrl.clear();
        _messageCtrl.clear();
        _showSuccessDialog(targetStudents.length, sentCount, failedCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error broadcasting announcement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(int total, int sent, int failed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF229ED9), size: 28),
            SizedBox(width: 10),
            Text('Broadcast Sent! ✈️', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your announcement has been dispatched to students via @edupeakbot.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildStatRow('🎯 Total Targeted', '$total students'),
                  const SizedBox(height: 6),
                  _buildStatRow('✅ Delivered on Telegram', '$sent sent', color: Colors.green),
                  if (failed > 0) ...[
                    const SizedBox(height: 6),
                    _buildStatRow('⚠️ Pending/Inactive', '$failed failed', color: Colors.orange),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String val, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Broadcasts 📢'),
        actions: [
          IconButton(
            tooltip: 'Bot Info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connected to Telegram Bot: @edupeakbot')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF229ED9), Color(0xFF0088CC)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33229ED9),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Telegram Announcement Hub',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Instantly broadcast updates, homework alerts, or exam notices to students via @edupeakbot',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Broadcast Composer Card ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compose Announcement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),

                    // Priority selector
                    const Text('Category / Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPriorityChip('normal', '📢 Announcement', const Color(0xFF229ED9)),
                        _buildPriorityChip('urgent', '🚨 Urgent Exam Alert', Colors.red),
                        _buildPriorityChip('homework', '📝 Homework Assignment', Colors.orange),
                        _buildPriorityChip('tip', '💡 Study Tip', Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Target Audience selector
                    const Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildTargetButton('all', '🌐 All Students')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTargetButton('year', '📅 By Exam Year')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTargetButton('single', '👤 One Student')),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Conditional: Year Dropdown
                    if (_targetType == 'year') ...[
                      DropdownButtonFormField<String>(
                        value: _selectedExamYear,
                        decoration: const InputDecoration(
                          labelText: 'Select Exam Batch',
                          prefixIcon: Icon(Icons.school_outlined, color: AppColors.textMuted),
                        ),
                        items: _examYears
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedExamYear = val);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Conditional: Single Student Picker
                    if (_targetType == 'single') ...[
                      _buildSingleStudentPicker(),
                      const SizedBox(height: 14),
                    ],

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Announcement Title',
                        hintText: 'e.g. Combined Maths Past Paper 2025 Discussion',
                        prefixIcon: Icon(Icons.title_rounded, color: AppColors.textMuted),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 14),

                    // Message Body
                    TextFormField(
                      controller: _messageCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message Body',
                        hintText: 'Enter full announcement details for students...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 50),
                          child: Icon(Icons.message_outlined, color: AppColors.textMuted),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter announcement message' : null,
                    ),
                    const SizedBox(height: 20),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _handleBroadcast,
                        icon: _isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          _isSending ? 'Broadcasting to Telegram...' : 'Broadcast to Telegram ✈️',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF229ED9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Broadcast History List ─────────────────────────────────────
            const Text(
              'Past Announcements History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildBroadcastHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String key, String label, Color color) {
    final isSelected = _priority == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: AppColors.backgroundSoft,
      onSelected: (_) {
        HapticFeedbackService.selection();
        setState(() => _priority = key);
      },
    );
  }

  Widget _buildTargetButton(String key, String label) {
    final isSelected = _targetType == key;
    return GestureDetector(
      onTap: () {
        HapticFeedbackService.selection();
        setState(() => _targetType = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF229ED9).withOpacity(0.12) : AppColors.backgroundSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF229ED9) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF229ED9) : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleStudentPicker() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final students = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: _selectedStudentPhone,
          decoration: const InputDecoration(
            labelText: 'Select Specific Student',
            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
          ),
          hint: const Text('Choose a student'),
          items: students.map<DropdownMenuItem<String>>((d) {
            final data = d.data();
            final name = data['name'] ?? 'Unknown';
            final phone = data['phone']?.toString() ?? '';
            final year = data['examYear'] ?? '';
            final hasTg = data['telegramChatId'] != null ? '✈️' : '⚠️';
            return DropdownMenuItem<String>(
              value: phone,
              child: Text('$hasTg $name ($year) - $phone', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedStudentPhone = val;
              final selected = students.firstWhere((d) => d.data()['phone'] == val);
              _selectedStudentName = selected.data()['name'];
            });
          },
        );
      },
    );
  }

  Widget _buildBroadcastHistory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No announcements sent yet. Broadcast your first message above! 📢',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final title = data['title'] ?? 'Announcement';
            final msg = data['message'] ?? '';
            final priority = data['priority'] ?? 'normal';
            final target = data['targetType'] == 'year'
                ? '${data['targetExamYear']} Batch'
                : data['targetType'] == 'single'
                    ? (data['targetStudentName'] ?? 'Single Student')
                    : 'All Students';
            final sent = data['sentCount'] ?? 0;

            final priorityColor = priority == 'urgent'
                ? Colors.red
                : priority == 'homework'
                    ? Colors.orange
                    : const Color(0xFF229ED9);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          target.toUpperCase(),
                          style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '✈️ $sent delivered',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
