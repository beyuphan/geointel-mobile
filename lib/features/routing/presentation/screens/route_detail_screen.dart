import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeInfo = ref.watch(activeRouteInfoProvider);

    if (routeInfo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rota Detayı')),
        body: const Center(child: Text('Henüz aktif bir rota bulunamadı.', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigasyon Özeti', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                image: const DecorationImage(
                  image: NetworkImage('https://maps.googleapis.com/maps/api/staticmap?size=600x300&maptype=roadmap&style=feature:all|element:all|invert_lightness:true'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
              child: const Center(
                child: Icon(Icons.navigation_rounded, size: 64, color: AppTheme.accent),
              ),
            ),
            const SizedBox(height: 24),
            Text(routeInfo['title'] ?? 'Aktif Rota', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tahmini Süre: ${routeInfo['duration']} dk • Mesafe: ${routeInfo['distance']} km', style: const TextStyle(color: AppTheme.accent, fontSize: 16)),
            const SizedBox(height: 24),
            const Text('GÜZERGAH ÖZETİ', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildTimelineStep('Mevcut Konum', 'Başlangıç Noktası', isFirst: true),
            _buildTimelineStep('Hedef', routeInfo['title'] ?? 'Varış Noktası', isLast: true),
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
