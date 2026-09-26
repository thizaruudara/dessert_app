import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/daily_physics_insight_model.dart';
import '../../../core/services/daily_physics_insight_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../auth/providers/auth_provider.dart';

class AdminDailyInsightScreen extends StatefulWidget {
  const AdminDailyInsightScreen({super.key});

  @override
  State<AdminDailyInsightScreen> createState() => _AdminDailyInsightScreenState();
}

class _AdminDailyInsightScreenState extends State<AdminDailyInsightScreen> {
  final DailyPhysicsInsightService _service = DailyPhysicsInsightService();

  // Mode: false = Random Daily (Default), true = Custom Pinned
  bool _isCustomMode = false;
  bool _isLoading = true;
  bool _isSaving = false;

  // Form Controllers
  final _titleSinhalaCtrl = TextEditingController();
  final _titleEnglishCtrl = TextEditingController();
  final _unitSinhalaCtrl = TextEditingController();
  final _unitEnglishCtrl = TextEditingController();
  final _formulaCtrl = TextEditingController();
  final _tipSinhalaCtrl = TextEditingController();
  final _tipEnglishCtrl = TextEditingController();
  final _topicCodeCtrl = TextEditingController();

  int? _selectedPresetIndex;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _titleSinhalaCtrl.dispose();
    _titleEnglishCtrl.dispose();
    _unitSinhalaCtrl.dispose();
    _unitEnglishCtrl.dispose();
    _formulaCtrl.dispose();
    _tipSinhalaCtrl.dispose();
    _tipEnglishCtrl.dispose();
    _topicCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final config = await _service.getInsight();
      if (mounted) {
        setState(() {
          _isCustomMode = config.isCustom;
          if (config.isCustom) {
            _titleSinhalaCtrl.text = config.titleSinhala;
            _titleEnglishCtrl.text = config.titleEnglish;
            _unitSinhalaCtrl.text = config.unitSinhala;
            _unitEnglishCtrl.text = config.unitEnglish;
            _formulaCtrl.text = config.formula;
            _tipSinhalaCtrl.text = config.tipSinhala;
            _tipEnglishCtrl.text = config.tipEnglish;
            _topicCodeCtrl.text = config.topicCode;
          } else {
            // Preload 1st preset as template in case they want to switch to custom
            _populateFromPreset(DailyPhysicsInsightModel.presetBank[0], index: 0, updateStateOnly: false);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _populateFromPreset(DailyPhysicsInsightModel.presetBank[0], index: 0, updateStateOnly: false);
        });
      }
    }
  }

  void _populateFromPreset(DailyPhysicsInsightModel preset, {int? index, bool updateStateOnly = true}) {
    _titleSinhalaCtrl.text = preset.titleSinhala;
    _titleEnglishCtrl.text = preset.titleEnglish;
    _unitSinhalaCtrl.text = preset.unitSinhala;
    _unitEnglishCtrl.text = preset.unitEnglish;
    _formulaCtrl.text = preset.formula;
    _tipSinhalaCtrl.text = preset.tipSinhala;
    _tipEnglishCtrl.text = preset.tipEnglish;
    _topicCodeCtrl.text = preset.topicCode;
    _selectedPresetIndex = index;
    if (updateStateOnly && mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCustomInsight() async {
    if (_titleSinhalaCtrl.text.trim().isEmpty || _formulaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ කරුණාකර මාතෘකාව සහ සූත්‍රය ඇතුළත් කරන්න (Please fill title and formula).'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedbackService.light();

    try {
      final auth = context.read<AuthProvider>();
      final adminName = auth.user?.name ?? 'Admin';

      final model = DailyPhysicsInsightModel(
        isCustom: true,
        titleSinhala: _titleSinhalaCtrl.text.trim(),
        titleEnglish: _titleEnglishCtrl.text.trim(),
        unitSinhala: _unitSinhalaCtrl.text.trim(),
        unitEnglish: _unitEnglishCtrl.text.trim(),
        formula: _formulaCtrl.text.trim(),
        tipSinhala: _tipSinhalaCtrl.text.trim(),
        tipEnglish: _tipEnglishCtrl.text.trim(),
        topicCode: _topicCodeCtrl.text.trim(),
      );

      await _service.saveCustomInsight(model, adminName: adminName);
      HapticFeedbackService.success();

      if (mounted) {
        setState(() {
          _isCustomMode = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Custom Physics Concept pinned for all students!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving insight: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _resetToRandomMode() async {
    setState(() => _isSaving = true);
    HapticFeedbackService.medium();

    try {
      final auth = context.read<AuthProvider>();
      await _service.setRandomDailyMode(adminName: auth.user?.name);
      HapticFeedbackService.success();

      if (mounted) {
        setState(() {
          _isCustomMode = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎲 Mode reset to Automatic Random Daily Rotation!'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error resetting mode: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Daily Physics Insight Manager',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _isCustomMode ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isCustomMode ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_isCustomMode ? '📌' : '🎲', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  _isCustomMode ? 'Custom Pinned' : 'Random Daily',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isCustomMode ? const Color(0xFF92400E) : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mode Switcher Card ──────────────────────────────────────
                  _buildModeSwitcherCard(),
                  const SizedBox(height: 20),

                  // ── Live Student Preview ────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'Live Student Screen Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _isCustomMode ? 'What students see right now' : 'Sample preview (auto rotates)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildLivePreviewCard(),
                  const SizedBox(height: 24),

                  // ── Preset Quick Pick Bar ───────────────────────────────────
                  Text(
                    'Curated A/L Syllabus Presets Bank',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any preset to load its bilingual details into the editor below:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPresetsList(),
                  const SizedBox(height: 24),

                  // ── Custom Concept Editor Form ──────────────────────────────
                  _buildEditorSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildModeSwitcherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display Mode for Students',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose whether formulas rotate automatically or show a specific concept pinned by you.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Options Row
          Row(
            children: [
              // Option 1: Random Daily
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedbackService.light();
                    if (_isCustomMode) {
                      _resetToRandomMode();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isCustomMode ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isCustomMode ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: !_isCustomMode ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🎲', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'Random Daily',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: !_isCustomMode ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Default • Refreshes daily at 00:00 midnight',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Option 2: Custom Pinned
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedbackService.light();
                    setState(() => _isCustomMode = true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isCustomMode ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isCustomMode ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        width: _isCustomMode ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📌', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'Custom Pinned',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _isCustomMode ? const Color(0xFFB45309) : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pinned by Admin • Overrides rotation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final titleSi = _titleSinhalaCtrl.text.isNotEmpty ? _titleSinhalaCtrl.text : 'කාර්යය-ශක්ති ප්‍රමේයය';
    final titleEn = _titleEnglishCtrl.text.isNotEmpty ? _titleEnglishCtrl.text : 'Work-Energy Theorem';
    final unitSi = _unitSinhalaCtrl.text.isNotEmpty ? _unitSinhalaCtrl.text : 'යාන්ත්‍ර විද්‍යාව';
    final unitEn = _unitEnglishCtrl.text.isNotEmpty ? _unitEnglishCtrl.text : 'Mechanics';
    final formula = _formulaCtrl.text.isNotEmpty ? _formulaCtrl.text : 'W_net = ΔK = ½mv² - ½mu²';
    final tipSi = _tipSinhalaCtrl.text.isNotEmpty ? _tipSinhalaCtrl.text : 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය වෙන්ව සලකා බලන්න.';
    final tipEn = _tipEnglishCtrl.text.isNotEmpty ? _tipEnglishCtrl.text : 'Always compute work against friction separately.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚛️', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      'PHYSICS MICRO-INSIGHT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _isCustomMode ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isCustomMode ? const Color(0xFFFDE68A) : Colors.transparent,
                  ),
                ),
                child: Text(
                  _isCustomMode ? '📌 විශේෂ සූත්‍රය • Pinned' : 'අද දවසේ සූත්‍රය • Daily',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _isCustomMode ? const Color(0xFF92400E) : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$unitSi • $unitEn',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                height: 1.3,
              ),
              children: [
                TextSpan(text: titleSi),
                TextSpan(
                  text: '  ($titleEn)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                formula,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      'විභාග උපදෙස (Exam Tip):',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tipSi,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF78350F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'En: $tipEn',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF92400E).withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsList() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DailyPhysicsInsightModel.presetBank.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final preset = DailyPhysicsInsightModel.presetBank[i];
          final isSelected = _selectedPresetIndex == i;
          return InkWell(
            onTap: () {
              HapticFeedbackService.light();
              _populateFromPreset(preset, index: i);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                '${preset.titleSinhala} (${preset.unitEnglish})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                'Edit Micro-Insight Content',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildField(
            label: 'මාතෘකාව (Sinhala Title)',
            controller: _titleSinhalaCtrl,
            hint: 'උදා: කාර්යය-ශක්ති ප්‍රමේයය',
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'Title (English Scientific Term)',
            controller: _titleEnglishCtrl,
            hint: 'e.g. Work-Energy Theorem & Friction Losses',
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: 'පාඩම (Sinhala Unit)',
                  controller: _unitSinhalaCtrl,
                  hint: 'උදා: යාන්ත්‍ර විද්‍යාව',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildField(
                  label: 'Unit (English)',
                  controller: _unitEnglishCtrl,
                  hint: 'e.g. Mechanics',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'Formula (ගණිතමය සූත්‍රය)',
            controller: _formulaCtrl,
            hint: 'e.g. W_net = ΔK = ½mv² - ½mu²',
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'විභාග උපදෙස (Sinhala Exam Tip)',
            controller: _tipSinhalaCtrl,
            hint: 'විභාගයේදී ලකුණු අඩුවන තැන් සහ විශේෂ ක්‍රම...',
            maxLines: 3,
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'Exam Tip (English Summary)',
            controller: _tipEnglishCtrl,
            hint: 'Key physics reminder in English...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'AI Tutor Topic Code (Optional)',
            controller: _topicCodeCtrl,
            hint: 'e.g. topic_work_energy',
          ),
          const SizedBox(height: 20),

          // Action Buttons Row
          Row(
            children: [
              if (_isCustomMode)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _resetToRandomMode,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Revert to Random',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              if (_isCustomMode) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCustomInsight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.push_pin_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Save & Pin to All Students',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
