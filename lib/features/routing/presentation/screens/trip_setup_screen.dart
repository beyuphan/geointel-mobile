import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

class TripSetupScreen extends ConsumerStatefulWidget {
  const TripSetupScreen({super.key});

  @override
  ConsumerState<TripSetupScreen> createState() => _TripSetupScreenState();
}

class _TripSetupScreenState extends ConsumerState<TripSetupScreen> {
  final _originCtrl = TextEditingController(text: 'Mevcut Konumum');
  final _destCtrl = TextEditingController();
  final _stopCtrl = TextEditingController();
  final _mealTimeCtrl = TextEditingController();

  double _fuelRange = 200;
  String _breakFreq = '2 saatte bir';
  String _foodPref = 'Ortaları';

  String _foodType = 'Fark etmez';
  final _foodTypeOptions = ['Yöresel', 'Fast Food', 'Ev Yemeği', 'Fark etmez'];

  final _breakOptions = ['1 saatte bir', '2 saatte bir', '3 saatte bir', 'Molasız'];
  final _foodOptions = ['Yolun başları', 'Ortaları', 'Sonları', 'Şehir yaz'];

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _stopCtrl.dispose();
    _mealTimeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_destCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir hedef girin.')));
      return;
    }

    final origin = _originCtrl.text.trim();
    final dest = _destCtrl.text.trim();
    final stop = _stopCtrl.text.trim();
    final mealTime = _mealTimeCtrl.text.trim();

    String msg = "Başlangıç: $origin, Hedef: $dest. ";
    if (stop.isNotEmpty) msg += "Rota üstünde şu duraklardan geç: $stop. ";
    msg += "Tercihlerim: Aracımın ${int.parse(_fuelRange.toStringAsFixed(0))} km menzili var. $_breakFreq mola veririm. Yemek lokasyonu tercihim: $_foodPref, yemek tarzı tercihim: $_foodType. ";
    if (_foodPref == 'Şehir yaz' && mealTime.isNotEmpty) msg += "Özellikle şu şehirde yemek yemek istiyorum: $mealTime. ";
    msg += "Bana en uygun mekanları ve yakıt duraklarını öner, poi overlay olarak göster.";

    context.push('/hub');
    Future.delayed(const Duration(milliseconds: 500), () {
      ref.read(chatProvider.notifier).sendMessage(msg);
    });
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, color: AppTheme.accent.withValues(alpha: 0.7)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Akıllı Rota Planla', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rota Bilgileri
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _buildTextField('Nereden', _originCtrl, icon: Icons.my_location),
                  const SizedBox(height: 16),
                  _buildTextField('Nereye', _destCtrl, icon: Icons.location_on),
                  const SizedBox(height: 16),
                  _buildTextField('Durak Ekle (Opsiyonel)', _stopCtrl, icon: Icons.add_circle_outline),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tercihler
            const Text('Yolculuk Tercihleri', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Araç Yakıt Menzili', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                Text('${_fuelRange.toInt()} km', style: const TextStyle(color: AppTheme.accent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _fuelRange, min: 50, max: 800, divisions: 15,
              activeColor: AppTheme.accent, inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _fuelRange = v),
            ),
            const SizedBox(height: 24),

            const Text('Mola Sıklığı', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _breakOptions.map((opt) {
                final isSel = _breakFreq == opt;
                return ChoiceChip(
                  label: Text(opt), selected: isSel,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(color: isSel ? AppTheme.accent : AppTheme.textSecondary),
                  side: BorderSide(color: isSel ? AppTheme.accent : Colors.white12),
                  onSelected: (_) => setState(() => _breakFreq = opt),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Yemek Lokasyonu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _foodOptions.map((opt) {
                final isSel = _foodPref == opt;
                return ChoiceChip(
                  label: Text(opt), selected: isSel,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(color: isSel ? AppTheme.accent : AppTheme.textSecondary),
                  side: BorderSide(color: isSel ? AppTheme.accent : Colors.white12),
                  onSelected: (_) => setState(() => _foodPref = opt),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Yemek Tarzı', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _foodTypeOptions.map((opt) {
                final isSel = _foodType == opt;
                return ChoiceChip(
                  label: Text(opt), selected: isSel,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(color: isSel ? AppTheme.accent : AppTheme.textSecondary),
                  side: BorderSide(color: isSel ? AppTheme.accent : Colors.white12),
                  onSelected: (_) => setState(() => _foodType = opt),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (_foodPref == 'Şehir yaz') ...[
              _buildTextField('Şehir Adı', _mealTimeCtrl, icon: Icons.location_city),
              const SizedBox(height: 48),
            ] else
              const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Rotayı ve Önerileri Hazırla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
