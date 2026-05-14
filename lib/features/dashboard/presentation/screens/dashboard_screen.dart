import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hoş Geldin,', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text('Seyyah', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person, color: AppTheme.accent),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text('Nereye Gidiyoruz?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Ana Kartlar
              _DashboardCard(
                title: 'Akıllı Rota Planla',
                subtitle: 'Yemek, mola ve yakıt duraklarıyla uzun rotanı yapay zeka ile kurgula.',
                icon: Icons.map_rounded,
                color: AppTheme.accent,
                onTap: () => context.push('/trip_wizard'),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Serbest Asistan',
                      subtitle: 'Harita üzerinden AI ile sohbet et.',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: Colors.blueAccent,
                      onTap: () => context.push('/hub'),
                      isSmall: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DashboardCard(
                      title: 'Acil Durum',
                      subtitle: 'Eczane, Hastane, Tamirci bul.',
                      icon: Icons.local_hospital_rounded,
                      color: Colors.redAccent,
                      onTap: () {
                         // Şimdilik hub'a gitsin
                         context.push('/hub');
                      },
                      isSmall: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSmall;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: isSmall ? 24 : 32),
                ),
                SizedBox(height: isSmall ? 16 : 20),
                Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: isSmall ? 12 : 14, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
