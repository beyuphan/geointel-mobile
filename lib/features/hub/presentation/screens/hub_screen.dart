import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _HubScreenState extends ConsumerState<HubScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(41.0082, 28.9784);
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<Position>? _positionStreamSub;
  Position? _currentPosition;
  late AnimationController _pulseController;

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#0d0d0d"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#6b6b6b"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0d0d0d"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#2a2a2a"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#111111"}]},
    {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#1e1e1e"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#003d5c"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#00a8e8"}]},
    {"featureType": "transit", "stylers": [{"visibility": "off"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000510"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initLocationStream();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final initialPos = await Geolocator.getCurrentPosition();
    _currentPosition = initialPos;
    ref.read(chatProvider.notifier).updateCurrentLocation(initialPos.latitude, initialPos.longitude);
    if (mounted) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(initialPos.latitude, initialPos.longitude), 14.0));
    }
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      _currentPosition = position;
      ref.read(chatProvider.notifier).updateCurrentLocation(position.latitude, position.longitude);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_darkMapStyle);
    if (_currentPosition != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14.0));
    }
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(text);
      _textController.clear();
    }
  }

  Future<void> _goToMyLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getCurrentPosition();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
  }

  void _fitMapToBounds(ChatState next) {
    if (_mapController == null) return;
    if (next.markers.isEmpty && next.polylines.isEmpty) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    bool hasPoints = false;
    for (final m in next.markers) {
      hasPoints = true;
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }
    for (final p in next.polylines) {
      for (final point in p.points) {
        hasPoints = true;
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }
    if (!hasPoints) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_mapController == null) return;
      try {
        if (minLat == maxLat || minLng == maxLng) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0));
        } else {
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 60.0))
            .catchError((e) {
              final cLat = (minLat + maxLat) / 2;
              final cLng = (minLng + maxLng) / 2;
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(cLat, cLng), 12.0));
              return null;
            });
        }
      } catch (e) {
        debugPrint('Map bounds error: $e');
      }
    });
  }

  void _showPoiDetailModal(BuildContext context, Map<String, dynamic> poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 24),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4))),
                    child: const Icon(Icons.place, color: AppTheme.accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(poi['title'] ?? poi['name'] ?? 'Bilinmeyen Nokta', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(poi['type'] ?? poi['snippet'] ?? 'Nokta Detayı', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ])),
                ]),
                if (poi['address'] != null) ...[
                  const SizedBox(height: 20),
                  Row(children: [
                    const Icon(Icons.location_on, color: AppTheme.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(poi['address'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  ]),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _textController.text = "${poi['title']} için rota çiz"; _sendMessage(); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.directions),
                    label: const Text('Buraya Rota Çiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider, (previous, next) {
      final markersChanged = previous?.markers.length != next.markers.length;
      final polylinesChanged = previous?.polylines.length != next.polylines.length;
      if (markersChanged || polylinesChanged) _fitMapToBounds(next);
    });
    ref.listen<Map<String, dynamic>?>(selectedPoiProvider, (previous, next) {
      if (next != null && context.mounted) {
        _showPoiDetailModal(context, next);
        Future.delayed(Duration.zero, () => ref.read(selectedPoiProvider.notifier).setPoi(null));
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // MAP — isolated Consumer: only rebuilds when markers/polylines change
          Consumer(builder: (context, ref, _) {
            final markers = ref.watch(chatProvider.select((s) => s.markers));
            final polylines = ref.watch(chatProvider.select((s) => s.polylines));
            return GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _center, zoom: 12.0),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: markers,
              polylines: polylines,
            );
          }),

          // Top gradient fade
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppTheme.background.withValues(alpha: 0.95), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  _buildGlassButton(Icons.menu, () => _scaffoldKey.currentState?.openDrawer()),
                  Expanded(child: Center(child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.4 + _pulseController.value * 0.6),
                          boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('GeoIntel', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ]),
                  ))),
                  _buildGlassButton(Icons.person_outline, () => context.push('/profile')),
                ]),
              ),
            ),
          ),

          // My location FAB
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.42,
            child: _buildGlassButton(Icons.my_location, _goToMyLocation, size: 52),
          ),

          // CHAT PANEL — isolated Consumer
          Consumer(builder: (context, ref, _) {
            final chatState = ref.watch(chatProvider);
            return DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.12,
              maxChildSize: 0.88,
              builder: (ctx, scrollController) => ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D).withValues(alpha: 0.82),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: Column(children: [
                          const SizedBox(height: 12),
                          Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 4),
                          if (chatState.isLoading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text('GeoIntel analiz ediyor...', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 11)),
                              ]),
                            )
                          else
                            const SizedBox(height: 12),
                        ])),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final msg = chatState.messages[index];
                              return _buildChatBubble(msg);
                            },
                            childCount: chatState.messages.length,
                          )),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).padding.bottom + 12),
                              child: _buildChatInput(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: const Color(0xFF0D0D0D).withValues(alpha: 0.9),
            child: ListView(padding: EdgeInsets.zero, children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppTheme.accent.withValues(alpha: 0.2), AppTheme.surface]),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4))),
                    child: const Icon(Icons.satellite_alt, size: 32, color: AppTheme.accent)),
                  const SizedBox(height: 12),
                  const Text('GeoIntel', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Akıllı Coğrafi Asistan', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                ]),
              ),
              _buildDrawerItem(Icons.history_rounded, 'Tarihçe', () { Navigator.pop(context); context.push('/history'); }),
              _buildDrawerItem(Icons.bookmark_rounded, 'Kayıtlı Konumlar', () { Navigator.pop(context); context.push('/locations'); }),
              _buildDrawerItem(Icons.settings_rounded, 'Ayarlar', () { Navigator.pop(context); context.push('/settings'); }),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent.withValues(alpha: 0.8)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap, {double size = 44}) {
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
            icon: Icon(icon, color: Colors.white, size: size * 0.45),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isAi = msg.isAi;
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            ClipRRect(
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
                    color: isAi ? Colors.white.withValues(alpha: 0.06) : AppTheme.accent.withValues(alpha: 0.35),
                    border: Border.all(color: isAi ? Colors.white.withValues(alpha: 0.1) : AppTheme.accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(msg.text, style: const TextStyle(color: AppTheme.textPrimary, height: 1.5, fontSize: 14)),
                    if (msg.toolsUsed != null && msg.toolsUsed!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: msg.toolsUsed!.map((tool) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3))),
                        child: Text("⚙️ ${tool.toUpperCase()}", style: const TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                      )).toList()),
                    ],
                  ]),
                ),
              ),
            ),
            if (msg.actionCards != null && msg.actionCards!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: msg.actionCards!.map((card) {
                  final action = card['action']?.toString() ?? '';
                  final label = card['label']?.toString() ?? '';
                  final icon = card['icon']?.toString() ?? '';
                  final isNav = action == 'start_navigation';
                  return GestureDetector(
                    onTap: () {
                      if (action == 'ui:start_navigation' || action == 'start_navigation') {
                        context.push('/route_detail');
                      } else if (action == 'ui:fuel_range_prompt') {
                        _showFuelRangeDialog(card);
                      } else if (action == 'ui:show_alternatives') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alternatif rotalar haritada gösteriliyor...')));
                      } else {
                        final m = action.length > 3 ? action : label;
                        if (m.isNotEmpty) ref.read(chatProvider.notifier).sendMessage(m);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isNav ? AppTheme.accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: isNav ? AppTheme.accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.2), width: 1.2),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (icon.isNotEmpty) ...[Text(icon, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6)],
                            Text(label, style: TextStyle(color: isNav ? AppTheme.accent : AppTheme.textPrimary, fontSize: 12, fontWeight: isNav ? FontWeight.bold : FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
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
                controller: _textController,
                onSubmitted: (_) => _sendMessage(),
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
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 8)]),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showFuelRangeDialog(Map<String, dynamic> card) {
    final TextEditingController rangeController = TextEditingController(text: "150");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: const Text('Yakıt Durumu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Şu anki yakıtınızla tahminen kaç km daha gidebilirsiniz?', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: rangeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppTheme.accent),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                suffixText: 'km',
                suffixStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              final range = rangeController.text;
              Navigator.pop(context);
              String template = card['action_template'] ?? "Yakıt analizimi yap, {range_km} km menzilim var";
              String message = template.replaceAll('{range_km}', range);
              ref.read(chatProvider.notifier).sendMessage(message);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Analiz Et', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
