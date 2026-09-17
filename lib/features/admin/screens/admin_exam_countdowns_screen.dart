import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/exam_countdown_model.dart';
import '../../../core/services/exam_countdown_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';

class AdminExamCountdownsScreen extends StatefulWidget {
  const AdminExamCountdownsScreen({super.key});

  @override
  State<AdminExamCountdownsScreen> createState() => _AdminExamCountdownsScreenState();
}

class _AdminExamCountdownsScreenState extends State<AdminExamCountdownsScreen> {
  final ExamCountdownService _service = ExamCountdownService();

  @override
  void initState() {
    super.initState();
    _service.seedDefaultConfigsIfEmpty();
  }

  Future<void> _pickDateTime(BuildContext context, ExamCountdownConfig config) async {
    HapticFeedbackService.selection();

    // 1. Pick Date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: config.targetDate.isAfter(DateTime(2020))
          ? config.targetDate
          : DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    // 2. Pick Time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(config.targetDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    final newTarget = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      await _service.updateTargetDateTime(
        examYear: config.examYear,
        targetDate: newTarget,
      );
      HapticFeedbackService.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${config.examYear} Target Date updated to ${DateFormat('dd MMM yyyy, hh:mm a').format(newTarget)}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating date: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _editCustomTitle(ExamCountdownConfig config) {
    final textCtrl = TextEditingController(text: config.customTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Title for ${config.examYear}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. ${config.examYear} Physics Final Countdown',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              await _service.saveConfig(config.copyWith(customTitle: textCtrl.text.trim()));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addNewBatchDialog() {
    final yearCtrl = TextEditingController(text: '2029 A/L');
    DateTime selectedDate = DateTime(2029, 11, 25, 8, 30);
    bool isVisible = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Text(
                  'Add Exam Batch',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exam Batch Name:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: yearCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2029 A/L',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Target Exam Date & Time:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (t != null) {
                          setDialogState(() {
                            selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Countdown to Students:', style: TextStyle(color: Colors.white, fontSize: 12)),
                      Switch(
                        value: isVisible,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) => setDialogState(() => isVisible = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                onPressed: () async {
                  final batchName = yearCtrl.text.trim();
                  if (batchName.isEmpty) return;
                  await _service.saveConfig(
                    ExamCountdownConfig(
                      id: ExamCountdownConfig.normalizeDocId(batchName),
                      examYear: batchName,
                      targetDate: selectedDate,
                      isEnabled: isVisible,
                      customTitle: '$batchName Physics Target',
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Add Batch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A/L Exam Target Dates & Countdowns',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Manage exact exam dates and student visibility per batch',
              style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 26),
            tooltip: 'Add Custom Exam Year',
            onPressed: _addNewBatchDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<ExamCountdownConfig>>(
        stream: _service.streamAllConfigs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          final configs = snapshot.data ?? [];

          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty, color: Color(0xFF64748B), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No countdown batches found.',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                    onPressed: () => _service.seedDefaultConfigsIfEmpty(),
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text('Load Standard A/L Batches', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final config = configs[index];
              return _buildConfigCard(config);
            },
          );
        },
      ),
    );
  }

  Widget _buildConfigCard(ExamCountdownConfig config) {
    final now = DateTime.now();
    final remaining = config.targetDate.difference(now);
    final isPassed = remaining.isNegative;
    final remainingStr = isPassed
        ? 'Exam Date Elapsed'
        : '${remaining.inDays}d ${remaining.inHours % 24}h ${remaining.inMinutes % 60}m remaining';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: config.isEnabled ? const Color(0xFF334155) : const Color(0xFF475569).withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Batch Name & Visibility Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: config.isEnabled
                          ? const Color(0xFF2563EB).withOpacity(0.2)
                          : const Color(0xFF64748B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: config.isEnabled ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                      ),
                    ),
                    child: Text(
                      '⚡ ${config.examYear}',
                      style: GoogleFonts.poppins(
                        color: config.isEnabled ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: config.isEnabled
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      config.isEnabled ? 'VISIBLE TO STUDENTS' : 'HIDDEN FROM STUDENTS',
                      style: GoogleFonts.poppins(
                        color: config.isEnabled ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Visibility Switch
              Row(
                children: [
                  Text(
                    config.isEnabled ? 'Visible' : 'Hidden',
                    style: TextStyle(
                      color: config.isEnabled ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch(
                    value: config.isEnabled,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (newVal) async {
                      HapticFeedbackService.light();
                      await _service.toggleVisibility(config.examYear, newVal);
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Custom Title & Edit Action
          Row(
            children: [
              Expanded(
                child: Text(
                  config.customTitle.isNotEmpty
                      ? config.customTitle
                      : '${config.examYear} Final Examination',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF818CF8), size: 18),
                tooltip: 'Edit Title',
                onPressed: () => _editCustomTitle(config),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Target Exam Date & Time Button (Manual Setting)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_available, color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Exam Date & Time:',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy • hh:mm a').format(config.targetDate),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _pickDateTime(context, config),
                  icon: const Icon(Icons.edit_calendar, size: 14, color: Colors.white),
                  label: const Text(
                    'Change Date',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Live Countdown Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: config.isEnabled
                  ? const Color(0xFF10B981).withOpacity(0.08)
                  : const Color(0xFF64748B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isPassed ? Icons.event_busy : Icons.timer,
                  size: 14,
                  color: isPassed ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Calculation: ',
                  style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11),
                ),
                Text(
                  remainingStr,
                  style: GoogleFonts.poppins(
                    color: isPassed ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
