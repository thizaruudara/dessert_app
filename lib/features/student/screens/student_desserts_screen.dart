import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../desserts/providers/desserts_provider.dart';
import '../widgets/dessert_list_tile.dart';

class StudentDessertsScreen extends StatelessWidget {
  const StudentDessertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final desserts = context.watch<DessertsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Desserts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${desserts.desserts.length} total'),
              backgroundColor: AppColors.darkCard,
              labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
      body: desserts.desserts.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🍰', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 16),
                  Text('No submissions yet',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: desserts.desserts.length,
              itemBuilder: (_, i) {
                final d = desserts.desserts[i];
                return DessertListTile(
                  dessert: d,
                  onTap: () => context.push('/student/dessert/${d.id}'),
                );
              },
            ),
    );
  }
}
