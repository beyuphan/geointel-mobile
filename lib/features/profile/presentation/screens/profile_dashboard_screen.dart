import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileDashboardScreen extends ConsumerWidget {
  const ProfileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.surface,
              child: Icon(Icons.security, size: 50, color: AppTheme.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              'G-7821-X',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const Text(
              'Alpha Clearance',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppTheme.accent),
            ),
            const SizedBox(height: 32),
            _buildStatCard('Operasyon Bölgesi', 'Marmara / İstanbul', Icons.map),
            const SizedBox(height: 12),
            _buildStatCard('Tamamlanan Rota', '142', Icons.route),
            const SizedBox(height: 12),
            _buildStatCard('Keşfedilen POI', '87', Icons.place),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: AppTheme.surface,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        subtitle: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
