import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota Detayları', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Icon(Icons.map, size: 64, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Kadıköy - Beşiktaş (Alternatif 1)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tahmini Süre: 45 dk • Mesafe: 18 km', style: TextStyle(color: AppTheme.accent, fontSize: 16)),
            const SizedBox(height: 24),
            const Text('GÜZERGAH ÖZETİ', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildTimelineStep('Başlangıç', 'Kadıköy Meydan', isFirst: true),
            _buildTimelineStep('Ara Nokta', 'Avrasya Tüneli', isMiddle: true),
            _buildTimelineStep('Varış', 'Beşiktaş İskele', isLast: true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('NAVİGASYONU BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, {bool isFirst = false, bool isLast = false, bool isMiddle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(isLast ? Icons.location_on : Icons.circle, size: 16, color: AppTheme.accent),
              if (!isLast)
                Container(
                  height: 30,
                  width: 2,
                  color: AppTheme.accent.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
