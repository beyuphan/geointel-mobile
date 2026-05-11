import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  double _fuelRange = 200;
  String _breakFreq = '2 saatte bir';
  String _foodPref = 'Yöresel Lezzetler';

  final _breakOptions = ['1 saatte bir', '2 saatte bir', '3 saatte bir', 'Sadece acil durumda'];
  final _foodOptions = ['Yöresel Lezzetler', 'Fast Food', 'Ev Yemekleri', 'Kahve & Tatlı', 'Fark etmez'];

  void _submit() {
    final msg = "Rotam üzerinde $_fuelRange km menzilim var, $_breakFreq mola veriyorum. Yemek tercihim: $_foodPref. Bana uygun mola ve yemek yerleri öner.";
    ref.read(chatProvider.notifier).sendMessage(msg);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Yolculuk Planlayıcı', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uzun bir yola çıkıyorsun. Sana en uygun mekanları önerebilmemiz için birkaç detaya ihtiyacımız var.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            // Yakıt Menzili
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Araç Yakıt Menzili', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_fuelRange.toInt()} km', style: const TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: _fuelRange,
              min: 50,
              max: 800,
              divisions: 15,
              activeColor: AppTheme.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _fuelRange = v),
            ),
            const SizedBox(height: 32),

            // Mola Sıklığı
            const Text('Mola Sıklığı', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _breakOptions.map((opt) {
                final isSelected = _breakFreq == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppTheme.accent : Colors.white12),
                  ),
                  onSelected: (_) => setState(() => _breakFreq = opt),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Yemek Tercihi
            const Text('Yemek Tercihi', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _foodOptions.map((opt) {
                final isSelected = _foodPref == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppTheme.accent : Colors.white12),
                  ),
                  onSelected: (_) => setState(() => _foodPref = opt),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Önerileri Getir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
