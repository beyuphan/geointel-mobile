import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Ayarları', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Görünüm'),
          _buildSwitchTile('Karanlık Tema (Silent Luxury)', true, (val) {}),
          _buildSwitchTile('Yüksek Karşıtlık Haritası', false, (val) {}),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Veri ve Gizlilik'),
          _buildSwitchTile('Arkaplan Konum İzi', true, (val) {}),
          ListTile(
            title: const Text('Önbelleği Temizle', style: TextStyle(color: AppTheme.textPrimary)),
            trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Hesap'),
          ListTile(
            title: const Text('Oturumu Kapat', style: TextStyle(color: Colors.redAccent)),
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
    );
  }
}
