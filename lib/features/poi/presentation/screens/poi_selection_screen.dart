import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geointel_mobile/core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

/// Aşamalı POI seçim ekranı:
/// 1. Eğer sections'da hem food hem fuel varsa → önce yemek, onaydan sonra yakıt
/// 2. Tek section varsa → direkt o section
/// Seçimler /api/v1/trip/add_stops'a gider — LLM YOK
class PoiSelectionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? overlayData;
  const PoiSelectionScreen({super.key, this.overlayData});

  @override
  ConsumerState<PoiSelectionScreen> createState() => _PoiSelectionScreenState();
}

class _PoiSelectionScreenState extends ConsumerState<PoiSelectionScreen>
    with TickerProviderStateMixin {
  late final List<Map<String, dynamic>> _sections;
  int _currentSectionIndex = 0;
  final Map<int, Set<int>> _selectedBySection = {}; // sectionIdx → Set<cardIdx>
  bool _isSubmitting = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _sections = _parseSections(widget.overlayData);
    for (var i = 0; i < _sections.length; i++) {
      _selectedBySection[i] = {};
    }
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseSections(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['sections'] as List<dynamic>?;
    if (raw != null && raw.isNotEmpty) {
      return raw.cast<Map<String, dynamic>>();
    }
    // sections yoksa cards'ı tek section olarak dön
    final cards = data['cards'] as List<dynamic>? ?? [];
    if (cards.isNotEmpty) {
      return [
        {
          'type': 'poi',
          'title': data['title'] ?? 'Önerilen Mekanlar',
          'subtitle': data['subtitle'] ?? '',
          'cards': cards,
        }
      ];
    }
    return [];
  }

  Map<String, dynamic> get _currentSection => _sections[_currentSectionIndex];
  List<dynamic> get _currentCards => _currentSection['cards'] as List<dynamic>? ?? [];
  Set<int> get _currentSelected => _selectedBySection[_currentSectionIndex]!;
  bool get _isFood => (_currentSection['type'] as String?) == 'food';
  bool get _isFuel => (_currentSection['type'] as String?) == 'fuel';
  bool get _isBreak => (_currentSection['type'] as String?) == 'break';
  bool get _isLastSection => _currentSectionIndex == _sections.length - 1;

  void _toggleCard(int index) {
    setState(() {
      if (_currentSelected.contains(index)) {
        _currentSelected.remove(index);
      } else {
        // Yemek ve mola için tekil seçim (max 1), yakıt için çoklu
        if (_isFood) {
          _currentSelected.clear();
        }
        _currentSelected.add(index);
      }
    });
  }

  void _advanceOrSubmit() async {
    if (_isLastSection) {
      await _submitAll();
    } else {
      setState(() => _currentSectionIndex++);
      _slideCtrl.reset();
      _slideCtrl.forward();
    }
  }

  void _skipSection() {
    if (_isLastSection) {
      context.pop();
    } else {
      setState(() => _currentSectionIndex++);
      _slideCtrl.reset();
      _slideCtrl.forward();
    }
  }

  Future<void> _submitAll() async {
    // Tüm section'lardan seçilenleri topla
    final allSelected = <Map<String, dynamic>>[];
    for (var si = 0; si < _sections.length; si++) {
      final sec = _sections[si];
      final cards = sec['cards'] as List<dynamic>? ?? [];
      final selected = _selectedBySection[si] ?? {};
      for (final idx in selected) {
        if (idx < cards.length) {
          final card = cards[idx] as Map<String, dynamic>;
          allSelected.add({
            'lat': card['lat'],
            'lon': card['lon'],
            'name': card['name'] ?? 'Durak',
            'address': card['address'] ?? '',
            'type': sec['type'] == 'fuel'
                ? 'fuel_station'
                : sec['type'] == 'break'
                    ? 'break_stop'
                    : 'poi',
          });
        }
      }
    }

    if (allSelected.isEmpty) {
      context.pop();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(dioProvider);
      final sessionId = ref.read(chatProvider.notifier).sessionId;
      final notifier = ref.read(chatProvider.notifier);

      final response = await dio.post('/api/v1/trip/add_stops', data: {
        'session_id': sessionId,
        'selected_stops': allSelected,
        'current_lat': notifier.currentLat,
        'current_lon': notifier.currentLon,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        await notifier.processExternalResponse(response.data['data'] ?? {});
      } else {
        // Fallback: session_id ile normal chat mesajı gönder
        final coords = allSelected.map((s) => '${s['lat']},${s['lon']}').join('|');
        await notifier.sendMessage('Şu koordinatları rotama waypoint olarak ekle: $coords');
      }
    } catch (e) {
      final coords = allSelected.map((s) => '${s['lat']},${s['lon']}').join('|');
      ref.read(chatProvider.notifier).sendMessage('Şu koordinatları rotama waypoint olarak ekle: $coords');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text('Öneri bulunamadı', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 24),
            TextButton(onPressed: () => context.pop(), child: const Text('Geri Dön')),
          ]),
        ),
      );
    }

    final sectionType = _currentSection['type'] as String? ?? 'poi';
    final sectionTitle = _currentSection['title'] as String? ?? 'Öneriler';
    final sectionSubtitle = _currentSection['subtitle'] as String? ?? '';
    final targetKm = _currentSection['target_km'] as int?;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(sectionType, sectionTitle, sectionSubtitle, targetKm),

            // ── Step dots ──────────────────────────────────────────────────
            if (_sections.length > 1) _buildStepDots(),

            // ── Weather warnings ───────────────────────────────────────────
            Builder(builder: (_) {
              final warnings = (widget.overlayData?['weather_warnings'] as List<dynamic>?) ?? [];
              return warnings.isNotEmpty ? _buildWeatherBanner(warnings) : const SizedBox.shrink();
            }),

            // ── Cards list ─────────────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _currentCards.length,
                  itemBuilder: (_, i) {
                    final card = _currentCards[i] as Map<String, dynamic>;
                    final isSelected = _currentSelected.contains(i);
                    return _buildCard(card, i, isSelected, sectionType);
                  },
                ),
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────────────
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String type, String title, String subtitle, int? targetKm) {
    final icon = type == 'food' ? '🍽️' : type == 'fuel' ? '⛽' : type == 'break' ? '☕' : '📍';
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              ),
              Text(icon, style: const TextStyle(fontSize: 28)),
            ]),
            if (targetKm != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.route, color: AppTheme.accent.withValues(alpha: 0.8), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Rota ~$targetKm. km\'sinde önerilir',
                    style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_sections.length, (i) {
          final active = i == _currentSectionIndex;
          final done = i < _currentSectionIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: done ? AppTheme.accent.withValues(alpha: 0.4) : (active ? AppTheme.accent : Colors.white12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: done
                ? const Icon(Icons.check, size: 8, color: Colors.black)
                : null,
          );
        }),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> card, int index, bool isSelected, String sectionType) {
    final name = card['name'] as String? ?? 'İsimsiz Mekan';
    final address = card['address'] as String? ?? '';
    final devLabel = card['deviation_label'] as String?;
    final impact = card['route_impact_label'] as String?;
    final eta = card['eta'] as String?;
    final isOpen = card['open_now'] as bool? ?? card['is_open'] as bool?;
    final rating = card['rating'];
    final isRecommended = card['is_recommended'] == true;
    final recReason = card['recommendation_reason'] as String?;
    final aiRec = card['ai_recommendation'] as String?;
    final fuelPrice = card['fuel_price_info'] as Map<String, dynamic>?;
    final reviewCount = card['review_count'] as int?;

    return GestureDetector(
      onTap: () => _toggleCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent
                : isRecommended
                    ? Colors.amber.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
            width: isSelected || isRecommended ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.12), blurRadius: 12, spreadRadius: 2)]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Recommended badge ─────────────────────────────────────
                if (isRecommended) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 5),
                      Text(recReason ?? 'GeoIntel Önerisi',
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],

                // ── Fuel price — en üstte belirgin ───────────────────────
                if (fuelPrice != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accent.withValues(alpha: 0.18), AppTheme.accent.withValues(alpha: 0.06)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Text('⛽', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          '${fuelPrice['price_per_liter']} TL/L',
                          style: TextStyle(color: AppTheme.accent, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (fuelPrice['company'] != null)
                          Text(fuelPrice['company'] as String,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ],

                // ── Name row + checkbox ───────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26, height: 26,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                        : null,
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Name + open status
                      Row(children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        if (isOpen != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOpen ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(isOpen ? 'Açık' : 'Kapalı',
                                  style: TextStyle(
                                      color: isOpen ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      ]),

                      // Address
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(address,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],

                      const SizedBox(height: 10),

                      // ── Chips row ─────────────────────────────────────
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (devLabel != null) _Chip(icon: Icons.route_rounded, text: devLabel),
                        if (impact != null && impact != 'Sıfır ek süre')
                          _Chip(icon: Icons.timer_outlined, text: impact, color: Colors.orange),
                        if (eta != null) _Chip(icon: Icons.access_time_rounded, text: 'ETA $eta'),
                        if (rating != null)
                          _Chip(icon: Icons.star_rounded, text: '$rating${reviewCount != null ? ' ($reviewCount)' : ''}', color: Colors.amber),
                      ]),

                      // ── AI Recommendation text ─────────────────────────
                      if (aiRec != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: AppTheme.accent.withValues(alpha: 0.7), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                aiRec,
                                style: TextStyle(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                    fontSize: 12, height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final selCount = _currentSelected.length;
    final isFood = _isFood;
    final isLast = _isLastSection;

    String primaryLabel;
    if (_isSubmitting) {
      primaryLabel = 'Hesaplanıyor...';
    } else if (selCount == 0) {
      primaryLabel = isLast ? 'Geç / Tamamla' : 'Geç';
    } else if (isLast) {
      primaryLabel = 'Tamamla ($selCount seçildi)';
    } else {
      primaryLabel = _isFood
          ? 'Yemeği Seç ve Devam Et'
          : 'Ekle ve Devam Et';
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Seçim sayısı göstergesi
            if (selCount > 0 && !_isSubmitting) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isFood
                        ? '1 yemek durağı seçildi'
                        : _isBreak
                            ? '$selCount mola noktası seçildi'
                            : '$selCount istasyon seçildi',
                    style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (!isLast)
                    Text(_nextSectionHint(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ]),
              ),
            ],

            // Primary button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : (selCount > 0 || isLast ? _advanceOrSubmit : _skipSection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selCount > 0 ? AppTheme.accent : Colors.white.withValues(alpha: 0.08),
                  foregroundColor: selCount > 0 ? Colors.black : Colors.white54,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2.5)),
                        const SizedBox(width: 10),
                        const Text('Mola noktaları hesaplanıyor...',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ])
                    : Text(primaryLabel,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),

            // Skip button (seçim yokken)
            if (selCount == 0 && !_isSubmitting) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _skipSection,
                child: Text(
                  isLast ? 'Hayır, devam et' : 'Bu adımı atla',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  String _nextSectionHint() {
    if (_currentSectionIndex + 1 < _sections.length) {
      final next = _sections[_currentSectionIndex + 1];
      final type = next['type'] as String? ?? '';
      if (type == 'fuel') return 'Sonra: Yakıt durağı ⛽';
      if (type == 'food') return 'Sonra: Yemek durağı 🍽️';
      if (type == 'break') return 'Sonra: Mola noktası ☕';
    }
    return '';
  }

  Widget _buildWeatherBanner(List<dynamic> warnings) {
    final first = warnings.first as Map<String, dynamic>;
    final severity = first['severity'] as String? ?? 'warning';
    final color = severity == 'critical' ? Colors.red : severity == 'info' ? Colors.green : Colors.orange;
    final message = first['message'] as String? ?? 'Kötü hava koşulları mevcut';
    final label = warnings.length > 1 ? '$message (+${warnings.length - 1} bölge)' : message;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.cloud_outlined, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Chip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
