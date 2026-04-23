import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: 'Rotalar'),
              Tab(text: 'Sohbetler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRouteHistory(context),
            _buildChatHistory(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHistory(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.route, color: AppTheme.accent),
            title: Text('Kadıköy - Beşiktaş (Alternatif ${index + 1})', style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Dün, 14:30', style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              context.push('/route_detail');
            },
          ),
        );
      },
    );
  }

  Widget _buildChatHistory(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.accent),
            title: Text('Session #${1024 - index}', style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Son mesaj: "Bana en yakın benzin istasyonu..."', style: TextStyle(color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              context.go('/hub'); // Go back to hub for chat
            },
          ),
        );
      },
    );
  }
}
