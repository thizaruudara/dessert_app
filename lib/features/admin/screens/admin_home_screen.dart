import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../core/models/dessert_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    context.read<DessertsProvider>().listenToAllDesserts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final desserts = context.watch<DessertsProvider>();
    final pending = desserts.pendingDesserts;
    final approved = desserts.desserts.where((d) => d.isApproved).toList();
    final rejected = desserts.desserts.where((d) => d.isRejected).toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                              ),
                              child: const Text('👑 Admin',
                                  style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          auth.user?.name ?? 'Admin',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) context.go('/auth/login');
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Approved (${approved.length})'),
                Tab(text: 'Rejected (${rejected.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _DessertFeed(
              desserts: pending,
              emptyMessage: 'All caught up! No pending reviews 🎉',
            ),
            _DessertFeed(
              desserts: approved,
              emptyMessage: 'No approved submissions yet',
            ),
            _DessertFeed(
              desserts: rejected,
              emptyMessage: 'No rejected submissions',
            ),
          ],
        ),
      ),
    );
  }
}

class _DessertFeed extends StatelessWidget {
  final List<DessertModel> desserts;
  final String emptyMessage;

  const _DessertFeed({required this.desserts, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (desserts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(emptyMessage, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: desserts.length,
      itemBuilder: (_, i) => _AdminDessertCard(dessert: desserts[i]),
    );
  }
}

class _AdminDessertCard extends StatelessWidget {
  final DessertModel dessert;
  const _AdminDessertCard({required this.dessert});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/admin/review/${dessert.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dessert.isPending ? AppColors.gold.withOpacity(0.4) : AppColors.darkBorder,
            width: dessert.isPending ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    dessert.studentName.isNotEmpty ? dessert.studentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dessert.studentName,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      Text(dessert.studentPhone,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (dessert.isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Review',
                        style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (dessert.caption != null && dessert.caption!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                dessert.caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (dessert.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${dessert.mediaUrls.length} file(s)',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              timeago.format(dessert.submittedAt),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
