import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../credits/providers/credits_provider.dart';

class StudentMcqSprintScreen extends StatefulWidget {
  final String? targetDate;

  const StudentMcqSprintScreen({super.key, this.targetDate});

  @override
  State<StudentMcqSprintScreen> createState() => _StudentMcqSprintScreenState();
}

class _StudentMcqSprintScreenState extends State<StudentMcqSprintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  // Quiz state
  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionIndex -> optionIndex
  bool _isSubmitting = false;

  // Timer
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  bool _quizStarted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.targetDate != null) {
      final parsed = DateTime.tryParse(widget.targetDate!);
      if (parsed != null) _selectedDate = parsed;
    }
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _startTimerIfNotRunning() {
    if (!_quizStarted) {
      _quizStarted = true;
      _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _elapsedSeconds++);
        }
      });
    }
  }

  String _formatDuration(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/student');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🔥', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text(
                  'Daily MCQ Sprint',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'A/L Physics • දවසේ MCQ 5',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          // Date Selector Button
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: AppColors.accent.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.accent),
            label: Text(
              _dateStr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
            ),
            onPressed: _pickSprintDate,
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: 'MCQ Quiz'),
            Tab(icon: Icon(Icons.leaderboard_rounded, size: 18), text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuizTab(user?.uid ?? ''),
          _buildLeaderboardTab(),
        ],
      ),
    );
  }

  Future<void> _pickSprintDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentQuestionIndex = 0;
        _selectedAnswers.clear();
        _elapsedSeconds = 0;
        _quizStarted = false;
        _stopwatchTimer?.cancel();
      });
    }
  }

  // ── Tab 1: Quiz Experience ───────────────────────────────────────────────
  Widget _buildQuizTab(String studentUid) {
    // 1. Listen to sprint document for selected date
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('daily_sprints')
          .doc(_dateStr)
          .snapshots(),
      builder: (context, sprintSnap) {
        if (sprintSnap.connectionState == ConnectionState.waiting && !sprintSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final sprintData = sprintSnap.data?.data();
        if (sprintData == null) {
          // If today has no direct doc, search for latest active sprint
          return _buildNoSprintFallback();
        }

        final sprintTitle = sprintData['title'] ?? 'Daily MCQ Sprint';
        final unit = sprintData['unit'] ?? 'General Physics';
        final questions = (sprintData['questions'] as List<dynamic>?) ?? [];

        if (questions.isEmpty) {
          return _buildEmptySprintState();
        }

        // 2. Check if student already submitted this sprint
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sprint_attempts')
              .where('date', isEqualTo: _dateStr)
              .where('studentId', isEqualTo: studentUid)
              .limit(1)
              .snapshots(),
          builder: (context, attemptSnap) {
            if (attemptSnap.connectionState == ConnectionState.waiting && !attemptSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }

            final attempts = attemptSnap.data?.docs ?? [];
            if (attempts.isNotEmpty) {
              // Student already completed! Show results & explanations
              final myAttempt = attempts.first.data();
              return _buildCompletedReviewView(sprintTitle, unit, questions, myAttempt);
            }

            // Student hasn't completed yet -> Interactive Quiz Mode!
            _startTimerIfNotRunning();
            return _buildActiveQuizView(sprintTitle, unit, questions);
          },
        );
      },
    );
  }

  // ── Active Quiz Mode ─────────────────────────────────────────────────────
  Widget _buildActiveQuizView(
    String sprintTitle,
    String unit,
    List<dynamic> questions,
  ) {
    if (_currentQuestionIndex >= questions.length) {
      _currentQuestionIndex = 0;
    }

    final q = questions[_currentQuestionIndex] as Map<String, dynamic>;
    final qText = q['question'] ?? '';
    final options = (q['options'] as List<dynamic>?) ?? [];
    final selectedOpt = _selectedAnswers[_currentQuestionIndex];
    final answeredCount = _selectedAnswers.length;

    return Column(
      children: [
        // Top Quiz Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Topic / Unit Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sprintTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unit: $unit • ${questions.length} Questions',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Live Stopwatch Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 15, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_elapsedSeconds),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Progress Indicators (1 to 5)
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  Text(
                    '$answeredCount/${questions.length} Answered',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: answeredCount == questions.length ? Colors.green : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(questions.length, (idx) {
                  final isCurrent = idx == _currentQuestionIndex;
                  final isAnswered = _selectedAnswers.containsKey(idx);

                  Color barColor = AppColors.border;
                  if (isCurrent) {
                    barColor = AppColors.accent;
                  } else if (isAnswered) {
                    barColor = const Color(0xFF10B981);
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedbackService.selection();
                        setState(() => _currentQuestionIndex = idx);
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: idx < questions.length - 1 ? 6 : 0),
                        height: 6,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Question Content & Options
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Question Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Q${_currentQuestionIndex + 1}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'A/L Physics Standard',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      qText,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Select the correct answer:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                ),
              ),

              // Options List
              ...List.generate(options.length, (optIdx) {
                final optText = options[optIdx].toString();
                final isSelected = selectedOpt == optIdx;

                return GestureDetector(
                  onTap: () {
                    HapticFeedbackService.light();
                    setState(() {
                      _selectedAnswers[_currentQuestionIndex] = optIdx;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent.withOpacity(0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.border,
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Option Circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.accent : AppColors.backgroundSoft,
                            border: Border.all(
                              color: isSelected ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${optIdx + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            optText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),

        // Bottom Navigation & Submit Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Prev'),
                  onPressed: () {
                    HapticFeedbackService.selection();
                    setState(() => _currentQuestionIndex--);
                  },
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 10),

              Expanded(
                child: _currentQuestionIndex < questions.length - 1
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Next Question',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          HapticFeedbackService.selection();
                          setState(() => _currentQuestionIndex++);
                        },
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Finish & Submit Sprint 🚀',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isSubmitting ? null : () => _confirmSubmitSprint(questions),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Confirmation & Submission ─────────────────────────────────────────────
  Future<void> _confirmSubmitSprint(List<dynamic> questions) async {
    final unanswered = questions.length - _selectedAnswers.length;
    if (unanswered > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Unanswered Questions', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text('You have $unanswered unanswered question(s). Are you sure you want to finish the sprint?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Review Questions'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    _submitSprint(questions);
  }

  Future<void> _submitSprint(List<dynamic> questions) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    _stopwatchTimer?.cancel();

    // 1. Calculate Score
    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i] as Map<String, dynamic>;
      final correctIdx = q['correctIndex'] ?? 0;
      final studentChoice = _selectedAnswers[i];
      if (studentChoice == correctIdx) {
        score++;
      }
    }

    final xpEarned = score * 10;
    final formattedTime = _formatDuration(_elapsedSeconds);

    // 2. Prepare Payload for Firestore collection 'sprint_attempts'
    // Matches exact leaderboard query requirements in admin_mcq_sprint_screen.dart
    final attemptData = {
      'studentId': user.uid,
      'studentName': user.name.isNotEmpty ? user.name : 'Student',
      'phone': user.phone,
      'examYear': user.examYear ?? '2027 A/L',
      'date': _dateStr,
      'score': score,
      'totalQuestions': questions.length,
      'timeTakenSeconds': _elapsedSeconds,
      'timeTakenFormatted': '${_elapsedSeconds ~/ 60}m ${_elapsedSeconds % 60}s',
      'answers': _selectedAnswers.map((k, v) => MapEntry(k.toString(), v)),
      'xpEarned': xpEarned,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Save attempt
      await FirebaseFirestore.instance.collection('sprint_attempts').add(attemptData);

      // Increment student credits in Firestore
      if (xpEarned > 0) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'credits': FieldValue.increment(xpEarned),
        });

        if (mounted) {
          context.read<CreditsProvider>().updateCredits(user.credits + xpEarned);
        }
      }

      HapticFeedbackService.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving submission: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Tab 1: Completed Mode (Results & Explanations) ─────────────────────────
  Widget _buildCompletedReviewView(
    String sprintTitle,
    String unit,
    List<dynamic> questions,
    Map<String, dynamic> attempt,
  ) {
    final score = (attempt['score'] ?? 0) as int;
    final total = (attempt['totalQuestions'] ?? questions.length) as int;
    final timeFormatted = attempt['timeTakenFormatted'] ?? '${attempt['timeTakenSeconds'] ?? 0}s';
    final xpEarned = attempt['xpEarned'] ?? (score * 10);
    final answers = (attempt['answers'] as Map<dynamic, dynamic>?) ?? {};

    final isPerfect = score == total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Celebration Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPerfect
                  ? [const Color(0xFF065F46), const Color(0xFF047857)]
                  : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (isPerfect ? Colors.green : Colors.blue).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(isPerfect ? '🏆 PERFECT SCORE!' : '🎉 SPRINT COMPLETED!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  Text(
                    ' / $total',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildResultPill('⏱️ Time: $timeFormatted', Colors.white.withOpacity(0.18)),
                  _buildResultPill('⚡ +$xpEarned XP Added', const Color(0xFFFBBF24).withOpacity(0.25)),
                  _buildResultPill('📚 $unit', Colors.white.withOpacity(0.18)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Question Review & Explanations (විවරණ)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
            ),
            TextButton.icon(
              icon: const Icon(Icons.leaderboard_outlined, size: 16),
              label: const Text('View Ranks'),
              onPressed: () => _tabController.animateTo(1),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Review Question Cards
        ...questions.asMap().entries.map((entry) {
          final qIdx = entry.key;
          final q = entry.value as Map<String, dynamic>;
          final qText = q['question'] ?? '';
          final options = (q['options'] as List<dynamic>?) ?? [];
          final correctIdx = q['correctIndex'] ?? 0;
          final explanation = q['explanation']?.toString().trim() ?? '';

          final studentChoice = answers[qIdx.toString()] ?? answers[qIdx];
          final isStudentCorrect = studentChoice == correctIdx;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isStudentCorrect ? Colors.green.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isStudentCorrect ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Q${qIdx + 1}',
                        style: TextStyle(
                          color: isStudentCorrect ? Colors.green : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isStudentCorrect ? 'Correct (+10 XP)' : 'Incorrect (0 XP)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isStudentCorrect ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  qText,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 12),

                // Options with indicator
                ...List.generate(options.length, (optIdx) {
                  final optText = options[optIdx].toString();
                  final isAnswer = optIdx == correctIdx;
                  final isPicked = optIdx == studentChoice;

                  Color optBg = AppColors.backgroundSoft;
                  Color optBorder = AppColors.border;
                  Color textColor = AppColors.textSecondary;

                  if (isAnswer) {
                    optBg = Colors.green.withOpacity(0.1);
                    optBorder = Colors.green;
                    textColor = Colors.green.shade800;
                  } else if (isPicked && !isAnswer) {
                    optBg = Colors.redAccent.withOpacity(0.08);
                    optBorder = Colors.redAccent;
                    textColor = Colors.redAccent.shade700;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: optBorder),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '(${optIdx + 1})',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            optText,
                            style: TextStyle(fontSize: 13, color: textColor, fontWeight: isAnswer ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                        if (isAnswer)
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16)
                        else if (isPicked)
                          const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 16),
                      ],
                    ),
                  );
                }),

                // Explanation Box (විවරණය)
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'විවරණය (Explanation):',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                explanation,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildResultPill(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Tab 2: Live Leaderboard ──────────────────────────────────────────────
  Widget _buildLeaderboardTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sprint_attempts')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final todayDocs = allDocs
            .map((d) => d.data())
            .where((d) {
              if (d['date'] != _dateStr) return false;
              final phone = (d['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
              if (phone.contains('711388991')) return false;
              return true;
            })
            .toList()
          ..sort((a, b) {
            final scoreDiff = ((b['score'] ?? 0) as num).compareTo((a['score'] ?? 0) as num);
            if (scoreDiff != 0) return scoreDiff;
            return ((a['timeTakenSeconds'] ?? 0) as num).compareTo((b['timeTakenSeconds'] ?? 0) as num);
          });

        if (todayDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'No completions for $_dateStr yet',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Be the first student to complete today\'s sprint and claim rank #1!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: todayDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final att = todayDocs[i];
            final rank = i + 1;
            final name = att['studentName'] ?? 'Student';
            final score = att['score'] ?? 0;
            final total = att['totalQuestions'] ?? 5;
            final time = att['timeTakenFormatted'] ?? '${att['timeTakenSeconds'] ?? 0}s';
            final xp = att['xpEarned'] ?? 0;

            final medal = rank == 1
                ? '🥇'
                : rank == 2
                    ? '🥈'
                    : rank == 3
                        ? '🥉'
                        : '#$rank';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rank <= 3 ? AppColors.accent.withOpacity(0.06) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: rank <= 3 ? AppColors.accent.withOpacity(0.3) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Text(
                      medal,
                      style: TextStyle(
                        fontSize: rank <= 3 ? 22 : 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '⏱️ $time • +$xp XP',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$score / $total',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Empty / Fallback States ──────────────────────────────────────────────
  Widget _buildNoSprintFallback() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('daily_sprints')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aDate = a.data()['targetDate']?.toString() ?? '';
            final bDate = b.data()['targetDate']?.toString() ?? '';
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Daily Sprint Coming Soon',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The tutor hasn\'t posted today\'s 5-MCQ sprint yet. Please check back shortly!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final latest = docs.first;
        final latestDate = latest.data()['targetDate']?.toString() ?? '';

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📅', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(
                  'No Sprint for $_dateStr',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Latest active sprint was posted for $latestDate.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(
                    'Open Sprint for $latestDate',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final parsed = DateTime.tryParse(latestDate);
                    if (parsed != null) {
                      setState(() {
                        _selectedDate = parsed;
                        _currentQuestionIndex = 0;
                        _selectedAnswers.clear();
                        _elapsedSeconds = 0;
                        _quizStarted = false;
                        _stopwatchTimer?.cancel();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySprintState() {
    return const Center(
      child: Text(
        'Sprint set contains no questions.',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
