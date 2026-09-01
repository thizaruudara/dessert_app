import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';

class AdminMcqSprintScreen extends StatefulWidget {
  const AdminMcqSprintScreen({super.key});

  @override
  State<AdminMcqSprintScreen> createState() => _AdminMcqSprintScreenState();
}

class _AdminMcqSprintScreenState extends State<AdminMcqSprintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🔥 Daily MCQ Sprints', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.quiz_outlined), text: 'Sprint Sets (දවසේ 5)'),
            Tab(icon: Icon(Icons.leaderboard_outlined), text: 'Live Leaderboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: AppColors.accent),
            tooltip: 'Pick Date',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSprintsTab(),
          _buildLeaderboardTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Create 5-MCQ Sprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openCreateSprintSheet(context),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Tab 1: Sprints Manager ───────────────────────────────────────────────
  Widget _buildSprintsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('daily_sprints')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aDate = a.data()['targetDate']?.toString() ?? '';
            final bDate = b.data()['targetDate']?.toString() ?? '';
            return bDate.compareTo(aDate);
          });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.today_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Viewing: $_dateStr',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Change'),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (docs.isEmpty)
              _buildEmptyState()
            else
              ...docs.map((doc) => _buildSprintCard(doc.id, doc.data())),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('📝', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          const Text(
            'No Custom MCQ Sprints Created Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Telegram bot is currently using the high-yield A/L Mechanics fallback set. Create custom daily 5-MCQ sets below!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            label: const Text('Load Demo A/L Physics Sprint Set', style: TextStyle(color: Colors.white)),
            onPressed: _loadDemoSprint,
          ),
        ],
      ),
    );
  }

  Widget _buildSprintCard(String docId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Daily MCQ Sprint';
    final subject = data['subject'] ?? 'Physics';
    final unit = data['unit'] ?? 'General';
    final targetDate = data['targetDate'] ?? '';
    final questions = (data['questions'] as List<dynamic>?) ?? [];
    final isToday = targetDate == _dateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isToday ? AppColors.accent.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? AppColors.accent.withOpacity(0.4) : AppColors.border,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('🔥', style: TextStyle(fontSize: 22)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          '📅 $targetDate • 📚 $subject ($unit) • ⚡ ${questions.length} Questions',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...questions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final q = entry.value as Map<String, dynamic>;
                  final qText = q['question'] ?? '';
                  final options = (q['options'] as List<dynamic>?) ?? [];
                  final correctIdx = q['correctIndex'] ?? 0;
                  final explanation = q['explanation'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${idx + 1}: $qText',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        ...options.asMap().entries.map((optEntry) {
                          final optIdx = optEntry.key;
                          final optText = optEntry.value.toString();
                          final isCorrect = optIdx == correctIdx;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: isCorrect ? Colors.green : AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '(${optIdx + 1}) $optText',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCorrect ? Colors.green : AppColors.textSecondary,
                                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 විවරණය: $explanation',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => _confirmDeleteSprint(docId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            .where((d) => d['date'] == _dateStr)
            .toList()
          ..sort((a, b) {
            final scoreDiff = ((b['score'] ?? 0) as num).compareTo((a['score'] ?? 0) as num);
            if (scoreDiff != 0) return scoreDiff;
            return ((a['timeTakenSeconds'] ?? 0) as num).compareTo((b['timeTakenSeconds'] ?? 0) as num);
          });

        if (todayDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(
                  'No completions for $_dateStr yet',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Students who complete the Sprint on Telegram will appear here live!',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
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
            final phone = att['phone'] ?? '';
            final score = att['score'] ?? 0;
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
                  SizedBox(
                    width: 36,
                    child: Text(
                      medal,
                      style: TextStyle(
                        fontSize: rank <= 3 ? 22 : 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('$phone • ⏱️ $time', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score / 5',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: score == 5 ? Colors.green : AppColors.accent,
                          fontSize: 16,
                        ),
                      ),
                      Text('+$xp XP', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Create 5-MCQ Sprint Bottom Sheet ─────────────────────────────────────
  void _openCreateSprintSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateSprintSheet(
        initialDate: _selectedDate,
        onCreated: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _confirmDeleteSprint(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sprint Set?'),
        content: const Text('Are you sure you want to delete this Daily 5-MCQ Sprint?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('daily_sprints').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sprint deleted.')));
      }
    }
  }

  Future<void> _loadDemoSprint() async {
    final demo = {
      'title': '🔥 දවසේ MCQ 5 - යාන්ත්‍ර විද්‍යාව (Mechanics)',
      'subject': 'Physics',
      'unit': 'යාන්ත්‍ර විද්‍යාව',
      'targetDate': _dateStr,
      'xpPerQuestion': 10,
      'createdAt': FieldValue.serverTimestamp(),
      'questions': [
        {
          'qNum': 1,
          'question': 'නිශ්චලතාවයෙන් ගමන් ආරම්භ කරන වස්තුවක ප්‍රවේගය කාලය සමඟ V = 4t² අනුව විචලනය වේ නම්, t = 2 s හිදී එහි ත්වරණය කොපමණද?',
          'options': ['8 m s⁻²', '16 m s⁻²', '4 m s⁻²', '32 m s⁻²', '2 m s⁻²'],
          'correctIndex': 1,
          'explanation': 'ත්වරණය a = dV/dt වේ. V = 4t² බැවින් a = 8t වේ. t = 2 s විට a = 8(2) = 16 m s⁻².'
        },
        {
          'qNum': 2,
          'question': 'ස්කන්ධය m වූ වස්තුවක් u ප්‍රවේගයෙන් සිරස්ව ඉහළට විසි කරන ලදී. එය ලබාගත හැකි උපරිම උස h නම්, එය කුමන උසකදී එහි චාලක ශක්තිය මුළු ශක්තියෙන් අඩක් වේද?',
          'options': ['h / 4', 'h / 3', 'h / 2', '2h / 3', '3h / 4'],
          'correctIndex': 2,
          'explanation': 'යාන්ත්‍රික ශක්ති සංස්ථිතිය අනුව: මුළු ශක්තිය E = mgh. චාලක ශක්තිය = විභව ශක්තිය = E/2 වන විට, mgy = mgh/2 => y = h/2.'
        },
        {
          'qNum': 3,
          'question': 'තරලයක ප්‍රක්ෂිප්ත ගලනය සඳහා බර්නුලි සමීකරණය P + ½ρv² + ρgh = C හි (P/ρg) පදයේ මාන කුමක්ද?',
          'options': ['M L⁻¹ T⁻²', 'L', 'M L² T⁻²', 'L T⁻¹', 'මාන රහිතයි'],
          'correctIndex': 1,
          'explanation': 'බර්නුලි සමීකරණයේ එක් එක් පදය ρg ගෙන් බෙදූ විට පීඩන ශීර්ෂය (P/ρg), ප්‍රවේග ශීර්ෂය (v²/2g) සහ උන්නතාංශ ශීර්ෂය (h) ලැබේ. මේ සෑම පදයකම මාන දිගෙහි මාන [L] වේ.'
        },
        {
          'qNum': 4,
          'question': 'ස්කන්ධය 2 kg වන වස්තුවක් මත F = 6t N බලයක් ක්‍රියා කරයි. t = 0 සිට t = 3 s දක්වා කාලය තුළ වස්තුව ලබාගන්නා ගම්‍යතා වෙනස කොපමණද?',
          'options': ['18 N s', '27 N s', '36 N s', '54 N s', '9 N s'],
          'correctIndex': 1,
          'explanation': 'ගම්‍යතා වෙනස Δp = ∫ F dt = ∫₀³ 6t dt = [3t²]₀³ = 3(9) - 0 = 27 N s.'
        },
        {
          'qNum': 5,
          'question': 'සුමට තිරස් තලයක් මත තබා ඇති 4 kg වස්තුවක් මත 20 N තිරස් බලයක් ක්‍රියා කරමින් එය 5 m දුරක් චලනය කරයි නම්, බලය මගින් කරන ලද කාර්යය කොපමණද?',
          'options': ['50 J', '100 J', '200 J', '40 J', '20 J'],
          'correctIndex': 1,
          'explanation': 'කාර්යය W = F × s = 20 N × 5 m = 100 J.'
        }
      ]
    };

    await FirebaseFirestore.instance.collection('daily_sprints').doc(_dateStr).set(demo);
    HapticFeedbackService.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo 5-MCQ Sprint loaded for $_dateStr!')),
      );
    }
  }
}

class _CreateSprintSheet extends StatefulWidget {
  final DateTime initialDate;
  final VoidCallback onCreated;

  const _CreateSprintSheet({required this.initialDate, required this.onCreated});

  @override
  State<_CreateSprintSheet> createState() => _CreateSprintSheetState();
}

class _CreateSprintSheetState extends State<_CreateSprintSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _targetDate;
  String _subject = 'Physics';
  final _unitCtrl = TextEditingController(text: 'යාන්ත්‍ර විද්‍යාව (Mechanics)');
  final _titleCtrl = TextEditingController(text: '🔥 දවසේ MCQ 5');

  // 5 Questions
  final List<TextEditingController> _questionCtrls = List.generate(5, (_) => TextEditingController());
  final List<List<TextEditingController>> _optionCtrls = List.generate(
    5,
    (_) => List.generate(5, (_) => TextEditingController()),
  );
  final List<int> _correctIndices = List.generate(5, (_) => 0);
  final List<TextEditingController> _explanationCtrls = List.generate(5, (_) => TextEditingController());

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _targetDate = widget.initialDate;
  }

  @override
  void dispose() {
    _unitCtrl.dispose();
    _titleCtrl.dispose();
    for (var c in _questionCtrls) {
      c.dispose();
    }
    for (var list in _optionCtrls) {
      for (var c in list) {
        c.dispose();
      }
    }
    for (var c in _explanationCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Create Daily 5-MCQ Sprint',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    // Date & Subject Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _subject,
                            decoration: const InputDecoration(labelText: 'Subject'),
                            items: const [
                              DropdownMenuItem(value: 'Physics', child: Text('Physics (භෞතික විද්‍යාව)')),
                              DropdownMenuItem(value: 'Combined Maths', child: Text('Combined Maths (සංයුක්ත ගණිතය)')),
                              DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry (රසායන විද්‍යාව)')),
                              DropdownMenuItem(value: 'Biology', child: Text('Biology (ජීව විද්‍යාව)')),
                              DropdownMenuItem(value: 'ICT', child: Text('ICT')),
                            ],
                            onChanged: (v) => setState(() => _subject = v ?? 'Physics'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _targetDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) setState(() => _targetDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Sprint Date'),
                              child: Text(DateFormat('yyyy-MM-dd').format(_targetDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit / Lesson Name (e.g. දෝලන හා තරංග)'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      '5 MCQ Questions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(5, (qIdx) {
                      return Card(
                        color: AppColors.backgroundSoft,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${qIdx + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _questionCtrls[qIdx],
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Enter Question ${qIdx + 1} text here...',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Question text required' : null,
                              ),
                              const SizedBox(height: 10),
                              const Text('Options & Correct Answer:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              const SizedBox(height: 6),
                              ...List.generate(5, (optIdx) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Radio<int>(
                                        value: optIdx,
                                        groupValue: _correctIndices[qIdx],
                                        activeColor: Colors.green,
                                        onChanged: (val) => setState(() => _correctIndices[qIdx] = val ?? 0),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _optionCtrls[qIdx][optIdx],
                                          decoration: InputDecoration(
                                            hintText: 'Option (${optIdx + 1})',
                                            filled: true,
                                            fillColor: AppColors.surface,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _explanationCtrls[qIdx],
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Sinhala Explanation (විවරණය)',
                                  hintText: 'Step by step explanation shown after answering...',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Publishing...' : 'Publish 5-MCQ Sprint 🚀',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _isSaving ? null : _saveSprint,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSprint() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final targetDateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
    final questionsData = List.generate(5, (qIdx) {
      return {
        'qNum': qIdx + 1,
        'question': _questionCtrls[qIdx].text.trim(),
        'options': _optionCtrls[qIdx].map((c) => c.text.trim()).toList(),
        'correctIndex': _correctIndices[qIdx],
        'explanation': _explanationCtrls[qIdx].text.trim(),
      };
    });

    final payload = {
      'title': '🔥 ${_titleCtrl.text.trim()} - ${_unitCtrl.text.trim()}',
      'subject': _subject,
      'unit': _unitCtrl.text.trim(),
      'targetDate': targetDateStr,
      'xpPerQuestion': 10,
      'questions': questionsData,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('daily_sprints').doc(targetDateStr).set(payload);
      HapticFeedbackService.success();
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving sprint: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
