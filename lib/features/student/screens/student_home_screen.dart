import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../core/models/dessert_model.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';
import '../../credits/providers/credits_provider.dart';
import '../widgets/credit_badge.dart';
import '../widgets/dessert_list_tile.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      context.read<DessertsProvider>().listenToStudentDesserts(auth.user!.uid);
      context.read<CreditsProvider>().updateCredits(auth.user!.credits);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final desserts = context.watch<DessertsProvider>();
    final credits = context.watch<CreditsProvider>();
    final user = auth.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/student/profile'),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: ClipOval(
                                  child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                      ? MediaImageView(url: user.avatarUrl!, fit: BoxFit.cover)
                                      : Container(
                                          color: Colors.white.withOpacity(0.2),
                                          child: Center(
                                            child: Text(
                                              user?.name.isNotEmpty == true
                                                  ? user!.name[0].toUpperCase()
                                                  : '🍰',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Good ${_greeting()}! 👋',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    user?.name ?? 'Student',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_outline, color: Colors.white),
                              tooltip: 'My Profile',
                              onPressed: () => context.push('/student/profile'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Credit Card ───────────────────────────────
                  CreditBadge(credits: credits.totalCredits, level: credits.creditLevel),
                  const SizedBox(height: 28),

                  // ── Stats Row ─────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: 'Submitted',
                        value: '${desserts.desserts.length}',
                        icon: Icons.send_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Approved',
                        value: '${desserts.desserts.where((d) => d.isApproved).length}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Pending',
                        value: '${desserts.pendingDesserts.length}',
                        icon: Icons.hourglass_empty_rounded,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Recent Desserts ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Submissions', style: Theme.of(context).textTheme.headlineMedium),
                      TextButton(
                        onPressed: () => context.go('/student/desserts'),
                        child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          if (desserts.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (desserts.desserts.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                onSubmit: () => context.go('/student/submit'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final d = desserts.desserts.take(5).toList()[i];
                    return DessertListTile(
                      dessert: d,
                      onTap: () => context.push('/student/dessert/${d.id}'),
                    );
                  },
                  childCount: desserts.desserts.take(5).length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyState({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍰', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No desserts yet!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Submit your first homework via WhatsApp',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('How to Submit'),
          ),
        ],
      ),
    );
  }
}
