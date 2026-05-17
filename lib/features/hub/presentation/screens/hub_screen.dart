import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:geointel_mobile/core/theme/app_theme.dart';
import 'package:geointel_mobile/features/hub/providers/chat_provider.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});
  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<Position>? _posSub;
  late AnimationController _pulse;

  static const _darkStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#0a0a0a"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#555"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0a0a0a"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1a1a1a"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#003d5c"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#00a8e8"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000510"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    ref.read(chatProvider.notifier).updateCurrentLocation(pos.latitude, pos.longitude);
    _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14));

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((p) => ref.read(chatProvider.notifier).updateCurrentLocation(p.latitude, p.longitude));
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    c.setMapStyle(_darkStyle);
  }

  void _send() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(t);
    _textCtrl.clear();
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _fitBounds(ChatState s) {
    if (_mapController == null) return;
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    bool any = false;
    for (final m in s.markers) {
      any = true;
      final p = m.position;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    for (final poly in s.polylines) {
      for (final p in poly.points) {
        any = true;
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
    }
    if (!any) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_mapController == null) return;
      try {
        if ((maxLat - minLat).abs() < 0.001) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLon), 14));
        } else {
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)), 60));
        }
      } catch (_) {}
    });
  }

  void _showPoiModal(Map<String, dynamic> poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PoiModal(poi: poi, onNavigate: (dest) {
        Navigator.pop(context);
        ref.read(chatProvider.notifier).sendMessage('$dest için rota oluştur');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider, (prev, next) {
      final markersChanged = prev?.markers.length != next.markers.length;
      final polysChanged = prev?.polylines.length != next.polylines.length;
      if (markersChanged || polysChanged) _fitBounds(next);
      
      if (prev?.messages.length != next.messages.length) {
        Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
      }

      // POI Overlay tetiklendi
      if (next.poiOverlay != null && prev?.poiOverlay != next.poiOverlay) {
        context.push('/poi_selection', extra: next.poiOverlay);
      }
    });

    ref.listen<Map<String, dynamic>?>(selectedPoiProvider, (_, next) {
      if (next != null && mounted) {
        _showPoiModal(next);
        Future.delayed(Duration.zero, () => ref.read(selectedPoiProvider.notifier).setPoi(null));
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: _buildDrawer(),
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────
        Consumer(builder: (_, ref, __) {
          final markers = ref.watch(chatProvider.select((s) => s.markers));
          final polylines = ref.watch(chatProvider.select((s) => s.polylines));
          return GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
          );
        }),

        // ── Top gradient ─────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.background.withValues(alpha: 0.95), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Top bar ───────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _GlassBtn(icon: Icons.menu, onTap: () => _scaffoldKey.currentState?.openDrawer()),
                const Spacer(),
                Flexible(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.4 + _pulse.value * 0.6),
                          boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('GeoIntel',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18,
                                fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
                _GlassBtn(icon: Icons.person_outline, onTap: () => context.push('/profile')),
              ]),
            ),
          ),
        ),

        // ── My location button ────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).size.height * 0.44,
          child: _GlassBtn(
            icon: Icons.my_location,
            size: 52,
            onTap: () async {
              final p = await Geolocator.getCurrentPosition();
              _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15));
            },
          ),
        ),

        // ── Chat Panel ────────────────────────────────────────────────────
        Consumer(builder: (ctx, ref, __) {
          final state = ref.watch(chatProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.12,
            maxChildSize: 0.90,
            builder: (_, sheetCtrl) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D).withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  child: Column(children: [
                    // Handle
                    const SizedBox(height: 12),
                    Container(width: 44, height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(height: 8),

                    // Loading indicator
                    if (state.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text('Analiz ediliyor...', style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                        ]),
                      ),

                    // Messages
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) => _ChatBubble(msg: state.messages[i]),
                      ),
                    ),

                    // Input
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).padding.bottom + 12),
                      child: _buildInput(),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                onSubmitted: (_) => _send(),
                maxLines: null,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'GeoIntel\'e sor...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 10)],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.92),
          child: ListView(padding: EdgeInsets.zero, children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.accent.withValues(alpha: 0.2), AppTheme.surface],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.satellite_alt, size: 30, color: AppTheme.accent),
                ),
                const SizedBox(height: 12),
                const Text('GeoIntel', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Akıllı Coğrafi Asistan', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
              ]),
            ),
            _DrawerItem(icon: Icons.history_rounded, label: 'Tarihçe', onTap: () { Navigator.pop(context); context.push('/history'); }),
            _DrawerItem(icon: Icons.bookmark_rounded, label: 'Kayıtlı Konumlar', onTap: () { Navigator.pop(context); context.push('/locations'); }),
            _DrawerItem(icon: Icons.settings_rounded, label: 'Ayarlar', onTap: () { Navigator.pop(context); context.push('/settings'); }),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT BUBBLE — Markdown rendering, no action cards
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isAi = msg.isAi;

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isAi ? const Radius.circular(4) : const Radius.circular(20),
            bottomRight: isAi ? const Radius.circular(20) : const Radius.circular(4),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAi
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppTheme.accent.withValues(alpha: 0.3),
                border: Border.all(
                  color: isAi
                      ? Colors.white.withValues(alpha: 0.09)
                      : AppTheme.accent.withValues(alpha: 0.5),
                ),
              ),
              child: isAi
                  ? MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.55),
                        strong: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        em: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontStyle: FontStyle.italic),
                        h1: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.w600),
                        listBullet: TextStyle(color: AppTheme.accent, fontSize: 14),
                        blockquoteDecoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(left: BorderSide(color: AppTheme.accent.withValues(alpha: 0.6), width: 3)),
                        ),
                        blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        code: TextStyle(
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: AppTheme.accent,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                        ),
                      ),
                      selectable: true,
                    )
                  : Text(
                      msg.text,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POI MODAL
// ─────────────────────────────────────────────────────────────────────────────

class _PoiModal extends StatelessWidget {
  final Map<String, dynamic> poi;
  final void Function(String dest) onNavigate;
  const _PoiModal({required this.poi, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final name = poi['title'] as String? ?? poi['name'] as String? ?? 'Mekan';
    final address = poi['address'] as String? ?? poi['snippet'] as String?;
    final type = poi['type'] as String? ?? 'poi';
    final rating = poi['rating'];
    final openNow = poi['open_now'] as bool?;
    final phone = poi['phone'] as String?;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35), width: 1.5),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  type == 'pharmacy' ? Icons.local_pharmacy :
                  type == 'fuel_station' ? Icons.local_gas_station :
                  Icons.place,
                  color: AppTheme.accent, size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                if (openNow != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: openNow ? Colors.greenAccent : Colors.redAccent)),
                    const SizedBox(width: 6),
                    Text(openNow ? 'Açık' : 'Kapalı',
                        style: TextStyle(color: openNow ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ],
              ])),
            ]),

            // Meta
            if (address != null) ...[
              const SizedBox(height: 16),
              _MetaRow(icon: Icons.location_on, text: address),
            ],
            if (rating != null) ...[
              const SizedBox(height: 8),
              _MetaRow(icon: Icons.star_rounded, text: '$rating ★', iconColor: Colors.amber),
            ],
            if (phone != null) ...[
              const SizedBox(height: 8),
              _MetaRow(icon: Icons.phone, text: phone),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onNavigate(name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.directions, size: 20),
                label: const Text('Buraya Rota Çiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _MetaRow({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: iconColor ?? AppTheme.accent.withValues(alpha: 0.7), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _GlassBtn({required this.icon, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: Colors.white, size: size * 0.44),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent.withValues(alpha: 0.8)),
      title: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
