import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

/// Akıllı Rota Sihirbazı — 4 adımlı, animasyonlu form
/// Yakıt = anlık km cinsinden; LLM'e doğal dil değil,
/// yapılandırılmış istek (/api/v1/trip/plan) gönderir.
class SmartTripWizard extends ConsumerStatefulWidget {
  const SmartTripWizard({super.key});

  @override
  ConsumerState<SmartTripWizard> createState() => _SmartTripWizardState();
}

class _SmartTripWizardState extends ConsumerState<SmartTripWizard>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 4;

  // — Step 1: Rota —
  final _destCtrl = TextEditingController();
  final _waypointCtrl = TextEditingController();

  // — Step 2: Tercihler —
  double _breakHours = 2.0;
  String _foodPref = 'Fark etmez';
  String _foodLocation = 'Ortaları';

  final _foodPrefOptions = [
    'Yöresel Lezzetler',
    'Fast Food',
    'Ev Yemekleri',
    'Kahve & Tatlı',
    'Fark etmez',
  ];
  final _foodLocOptions = ['Başları', 'Ortaları', 'Sonları'];

  // — Step 3: Yakıt —
  double _fuelRemainingKm = 0; // 0 = bilinmiyor

  // — Step 4: Ek Not —
  final _noteCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _destCtrl.dispose();
    _waypointCtrl.dispose();
    _noteCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _next() {
    if (_currentStep == 0 && _destCtrl.text.trim().isEmpty) {
      _showSnack('Lütfen bir hedef girin.');
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _fadeCtrl
        ..reset()
        ..forward();
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submit() {
    final dest = _destCtrl.text.trim();
    final waypoints = _waypointCtrl.text.trim().isNotEmpty
        ? _waypointCtrl.text.trim().split(',').map((e) => e.trim()).toList()
        : <String>[];

    context.push('/hub');
    Future.delayed(const Duration(milliseconds: 400), () {
      ref.read(chatProvider.notifier).planTrip(
        destination: dest,
        waypoints: waypoints,
        breakIntervalHours: _breakHours,
        foodPreference: _foodPref,
        foodLocation: _foodLocation,
        fuelRemainingKm: _fuelRemainingKm,
        customNote: _noteCtrl.text.trim(),
      );
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1Route(),
                    _buildStep2Preferences(),
                    _buildStep3Fuel(),
                    _buildStep4Note(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final titles = ['Nereye Gidiyoruz?', 'Yolculuk Tercihleri', 'Yakıt Durumu', 'Son Detaylar'];
    final subtitles = [
      'Hedefini ve varsa duraklarını seç',
      'Mola ve yemek planını oluşturalım',
      'Anlık yakıt durumunu gir',
      'Ek bir notun var mı?',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            GestureDetector(
              onTap: _prev,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textSecondary),
              ),
            )
          else
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentStep],
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitles[_currentStep],
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '${_currentStep + 1}/$_totalSteps',
            style: TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
          minHeight: 4,
        ),
      ),
    );
  }

  // ── Step 1: Rota ─────────────────────────────────────────────────────────

  Widget _buildStep1Route() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildGlassCard(
            child: Column(
              children: [
                _buildTextField(
                  label: 'Başlangıç',
                  hint: 'Mevcut konumunuz',
                  icon: Icons.my_location_rounded,
                  enabled: false,
                ),
                const _Divider(),
                _buildTextField(
                  label: 'Hedef',
                  hint: 'Örn: Ankara, Trabzon',
                  icon: Icons.location_on_rounded,
                  controller: _destCtrl,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const _Divider(),
                _buildTextField(
                  label: 'Ara Duraklar (Opsiyonel)',
                  hint: 'Bolu, Düzce  (virgülle ayır)',
                  icon: Icons.add_location_alt_rounded,
                  controller: _waypointCtrl,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoChip('💡 Harita üzerinden seçim yakında geliyor!'),
        ],
      ),
    );
  }

  // ── Step 2: Tercihler ────────────────────────────────────────────────────

  Widget _buildStep2Preferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Mola Sıklığı
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('⏱️ Mola Sıklığı', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      _breakHours == 0 ? 'Molasız' : '${_breakHours.toStringAsFixed(1)} saatte bir',
                      style: TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.accent,
                    overlayColor: AppTheme.accent.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _breakHours,
                    min: 0,
                    max: 4,
                    divisions: 8,
                    onChanged: (v) => setState(() => _breakHours = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Molasız', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    Text('4 saat', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Yemek Tarzı
          _buildSectionLabel('🍽️ Yemek Tercihi'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _foodPrefOptions.map((opt) => _buildChip(
              label: opt,
              selected: _foodPref == opt,
              onTap: () => setState(() => _foodPref = opt),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // Yemek Lokasyonu
          _buildSectionLabel('📍 Rotanın Neresinde Yemek?'),
          const SizedBox(height: 10),
          Row(
            children: _foodLocOptions.map((opt) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt == _foodLocOptions.last ? 0 : 8),
                child: _buildChip(
                  label: opt,
                  selected: _foodLocation == opt,
                  onTap: () => setState(() => _foodLocation = opt),
                  fullWidth: true,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Yakıt ────────────────────────────────────────────────────────

  Widget _buildStep3Fuel() {
    final fuelLabel = _fuelRemainingKm == 0
        ? 'Bilmiyorum'
        : '~${_fuelRemainingKm.toInt()} km';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⛽', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Şu an yaklaşık kaç km gidebilirsiniz?',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Yakıt duraklarını buna göre planlayacağız',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      fuelLabel,
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.accent,
                    overlayColor: AppTheme.accent.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _fuelRemainingKm,
                    min: 0,
                    max: 800,
                    divisions: 16,
                    onChanged: (v) => setState(() => _fuelRemainingKm = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bilmiyorum', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    Text('800 km', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoChip('💡 "Bilmiyorum" seçersen araç profiliinden hesaplanır.'),
        ],
      ),
    );
  }

  // ── Step 4: Not ─────────────────────────────────────────────────────────

  Widget _buildStep4Note() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✍️ Ek Not (Opsiyonel)',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rotayla ilgili özel bir isteğin varsa yaz',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Örn: "Sahil yolundan git", "Ücretli yoldan kaçın"...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Özet
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Özet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 12),
          _buildSummaryRow('🎯 Hedef', _destCtrl.text.trim().isEmpty ? '—' : _destCtrl.text.trim()),
          if (_waypointCtrl.text.trim().isNotEmpty)
            _buildSummaryRow('📍 Duraklar', _waypointCtrl.text.trim()),
          _buildSummaryRow('⏱️ Mola', _breakHours == 0 ? 'Molasız' : '${_breakHours.toStringAsFixed(1)} saatte bir'),
          _buildSummaryRow('🍽️ Yemek', '$_foodPref · Rotanın $_foodLocation'),
          _buildSummaryRow('⛽ Yakıt', _fuelRemainingKm == 0 ? 'Araç profilinden hesaplanacak' : '~${_fuelRemainingKm.toInt()} km menzil'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'Rotayı Hesapla' : 'Devam Et',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    TextEditingController? controller,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: AppTheme.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: enabled
                  ? TextField(
                      controller: controller,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                      textCapitalization: textCapitalization,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    )
                  : Text(
                      hint,
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 15),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600));
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.8), fontSize: 13)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
    );
  }
}
