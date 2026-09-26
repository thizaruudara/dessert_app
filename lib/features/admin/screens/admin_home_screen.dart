import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedTab = 0; // 0: Pending, 1: Approved, 2: Rejected
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DessertsProvider>().listenToAllDesserts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final desserts = context.watch<DessertsProvider>();
    final pending = desserts.pendingDesserts;
    final approved = desserts.desserts.where((d) => d.isApproved).toList();
    final rejected = desserts.desserts.where((d) => d.isRejected).toList();

    List<DessertModel> currentList;
    switch (_selectedTab) {
      case 1:
        currentList = approved;
        break;
      case 2:
        currentList = rejected;
        break;
      default:
        currentList = pending;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      currentList = currentList.where((d) {
        final name = d.studentName.toLowerCase();
        final phone = d.studentPhone.toLowerCase();
        final caption = (d.caption ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q) || caption.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── 1. Executive Top Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildExecutiveHeader(auth, pending.length),
            ),

            // ── 2. Real-Time Overview Metrics Grid ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMetricsRow(
                  pendingCount: pending.length,
                  approvedCount: approved.length,
                  rejectedCount: rejected.length,
                ),
              ),
            ),

            // ── 3. Quick Action Command Hub ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildQuickActionHub(),
              ),
            ),

            // ── 4. Submissions Review Workspace Header & Tabs ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Dessert Submissions Queue',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Physics A/L',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Modern Segmented Tab Switcher
                    _buildSegmentedTabSwitcher(
                      pendingCount: pending.length,
                      approvedCount: approved.length,
                      rejectedCount: rejected.length,
                    ),

                    const SizedBox(height: 12),

                    // Quick Search Bar
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),

            // ── 5. Review Cards Feed or Empty State ───────────────────────────
            if (currentList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = currentList[index];
                      return _AdminDessertCard(
                        dessert: item,
                        key: ValueKey(item.id),
                      );
                    },
                    childCount: currentList.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Executive Header ────────────────────────────────────────────────────────
  Widget _buildExecutiveHeader(AuthProvider auth, int pendingCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Admin Brand Badge with Pulsing Live Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Admin Portal • ThiZaru',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Quick Switch to Student View Button
              InkWell(
                onTap: () => context.go('/student'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Student View',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Logout Button
              InkWell(
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) context.go('/auth/login');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Greeting Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(
                  auth.user?.name.isNotEmpty == true
                      ? auth.user!.name[0].toUpperCase()
                      : 'A',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${auth.user?.name ?? 'Admin'} 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount dessert submission(s) need your review today'
                          : 'All reviews up to date! System is running smoothly',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: pendingCount > 0 ? AppColors.gold : AppColors.textMuted,
                        fontWeight: pendingCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overview Metrics Grid ───────────────────────────────────────────────────
  Widget _buildMetricsRow({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    return Row(
      children: [
        // Pending Reviews Metric
        Expanded(
          child: _buildMetricCard(
            title: 'Pending Review',
            count: pendingCount.toString(),
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
            badge: pendingCount > 0 ? 'ACTION' : null,
            isSelected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
        ),
        const SizedBox(width: 10),

        // Approved Submissions Metric
        Expanded(
          child: _buildMetricCard(
            title: 'Approved',
            count: approvedCount.toString(),
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isSelected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
        ),
        const SizedBox(width: 10),

        // Total Submissions Metric
        Expanded(
          child: _buildMetricCard(
            title: 'Rejected',
            count: rejectedCount.toString(),
            icon: Icons.cancel_outlined,
            color: const Color(0xFFEF4444),
            isSelected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              const BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Command Hub ───────────────────────────────────────────────────────
  Widget _buildQuickActionHub() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Admin Command Center',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCommandButton(
                  title: 'Exam Dates ⏳',
                  subtitle: 'Target count down',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push('/admin/countdowns'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCommandButton(
                  title: 'Paper Sessions 📝',
                  subtitle: 'Live proctoring',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.go('/admin/papers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCommandButton(
                  title: 'MCQ Sprints ⚡',
                  subtitle: 'Rapid quiz sets',
                  icon: Icons.bolt_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.go('/admin/sprints'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCommandButton(
                  title: 'Broadcasts 📢',
                  subtitle: 'Send telegram',
                  icon: Icons.send_outlined,
                  color: const Color(0xFF06B6D4),
                  onTap: () => context.go('/admin/announcements'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCommandButton(
            title: 'Physics Micro-Insight ⚛️',
            subtitle: 'Auto-rotate random or pin custom formula',
            icon: Icons.science_outlined,
            color: const Color(0xFF10B981),
            onTap: () => context.push('/admin/daily-insight'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Segmented Tab Switcher ─────────────────────────────────────────────────
  Widget _buildSegmentedTabSwitcher({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              label: 'Pending',
              count: pendingCount,
              badgeColor: AppColors.gold,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              label: 'Approved',
              count: approvedCount,
              badgeColor: AppColors.success,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              index: 2,
              label: 'Rejected',
              count: rejectedCount,
              badgeColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required int count,
    required Color badgeColor,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? badgeColor : AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by student name, phone or notes...',
          hintStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    switch (_selectedTab) {
      case 1:
        title = 'No Approved Submissions';
        subtitle = 'Submissions you approve will show up here with marks and feedback.';
        icon = Icons.done_all_rounded;
        iconColor = AppColors.success;
        break;
      case 2:
        title = 'No Rejected Submissions';
        subtitle = 'No homework submissions have been rejected yet.';
        icon = Icons.check_circle_outline_rounded;
        iconColor = AppColors.textMuted;
        break;
      default:
        title = 'All Caught Up! 🎉';
        subtitle = 'There are no pending dessert submissions waiting for review.';
        icon = Icons.verified_rounded;
        iconColor = AppColors.primary;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/papers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.assignment_outlined, size: 16),
                label: Text(
                  'Manage Paper Sessions',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Submission Card ──────────────────────────────────────────────────────────
class _AdminDessertCard extends StatelessWidget {
  final DessertModel dessert;
  const _AdminDessertCard({super.key, required this.dessert});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (dessert.isPending) {
      statusColor = AppColors.gold;
      statusLabel = 'Pending Review';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (dessert.isApproved) {
      statusColor = AppColors.success;
      statusLabel = 'Approved (+${dessert.creditsAwarded} XP)';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = AppColors.error;
      statusLabel = 'Rejected';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dessert.isPending
              ? AppColors.gold.withOpacity(0.4)
              : AppColors.border,
          width: dessert.isPending ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/admin/review/${dessert.id}'),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Student info & status pill
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        dessert.studentName.isNotEmpty
                            ? dessert.studentName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dessert.studentName,
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone_outlined,
                                  size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                dessert.studentPhone.isNotEmpty
                                    ? dessert.studentPhone
                                    : 'No phone',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('•',
                                  style: GoogleFonts.outfit(
                                      color: AppColors.textMuted)),
                              const SizedBox(width: 8),
                              Text(
                                timeago.format(dessert.submittedAt),
                                style: GoogleFonts.outfit(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Caption or Student Submission Note
                if (dessert.caption != null && dessert.caption!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      dessert.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],

                // Media count & Subject tag & Review button
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Subject Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dessert.subject ?? 'Physics',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Media count
                    if (dessert.mediaUrls.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              '${dessert.mediaUrls.length} file(s)',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Review Action
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dessert.isPending ? 'Review Now' : 'View Details',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: dessert.isPending
                                ? AppColors.gold
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: dessert.isPending
                              ? AppColors.gold
                              : AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
