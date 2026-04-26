import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../../hub/providers/chat_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tarihçe ve Loglar', style: TextStyle(fontWeight: FontWeight.bold)),
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
            _buildRouteHistory(context, ref),
            _buildChatHistory(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHistory(BuildContext context, WidgetRef ref) {
    final routeHistory = ref.watch(routeHistoryProvider);

    return routeHistory.when(
      data: (routes) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.route, color: AppTheme.accent),
              title: Text('${route['origin']} - ${route['destination']}', style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${route['date'] ?? ''} • ${route['distance_km']} km', style: const TextStyle(color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () {
                context.push('/route_detail');
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildChatHistory(BuildContext context, WidgetRef ref) {
    final chatHistory = ref.watch(chatHistoryProvider);

    return chatHistory.when(
      data: (messages) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final isAi = msg['role'] == 'assistant';
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(isAi ? Icons.smart_toy_outlined : Icons.person_outline, 
                          color: isAi ? AppTheme.accent : AppTheme.textSecondary),
              title: Text(isAi ? 'GeoIntel' : 'Siz', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(msg['content'] ?? '', 
                           style: const TextStyle(color: AppTheme.textSecondary), 
                           maxLines: 2, 
                           overflow: TextOverflow.ellipsis),
              onTap: () {
                context.go('/hub');
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}
