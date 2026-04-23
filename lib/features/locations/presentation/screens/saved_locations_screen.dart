import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          final locations = [
            {'name': 'Merkez Üssü', 'desc': 'Maslak HQ', 'icon': Icons.home},
            {'name': 'Hedef Bölge Alpha', 'desc': 'Karaköy Liman', 'icon': Icons.flag},
            {'name': 'Güvenli Ev', 'desc': 'Gizli Konum', 'icon': Icons.security},
          ];
          
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(locations[index]['icon'] as IconData, color: AppTheme.accent),
              title: Text(locations[index]['name'] as String, style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(locations[index]['desc'] as String, style: const TextStyle(color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              onTap: () {
                context.push('/poi_detail');
              },
            ),
          );
        },
      ),
    );
  }
}
