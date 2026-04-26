import 'dart:async';
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

class _HubScreenState extends ConsumerState<HubScreen> {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(41.0082, 28.9784); // Istanbul
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  StreamSubscription<Position>? _positionStreamSub;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocationStream();
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

    // Harita merkezini anında kendi konumuna çekmek istersen
    final initialPos = await Geolocator.getCurrentPosition();
    _currentPosition = initialPos;
    ref.read(chatProvider.notifier).updateCurrentLocation(initialPos.latitude, initialPos.longitude);
    
    if (mounted) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(initialPos.latitude, initialPos.longitude), 14.0
      ));
    }

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Sadece 10 metre değişirse güncelle
      ),
    ).listen((Position position) {
      _currentPosition = position;
      ref.read(chatProvider.notifier).updateCurrentLocation(position.latitude, position.longitude);
    });
  }

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
  ]
  ''';

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_darkMapStyle);
    
    if (_currentPosition != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14.0
      ));
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(text);
      _textController.clear();
    }
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum servisleri kapalı.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum izni reddedildi.')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi.')));
      return;
    } 

    final position = await Geolocator.getCurrentPosition();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
  }

  void _showPoiDetailModal(BuildContext context, Map<String, dynamic> poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5), width: 1)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.place, color: AppTheme.accent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi['title'] ?? poi['name'] ?? 'Bilinmeyen Nokta',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          poi['type'] ?? poi['snippet'] ?? 'Nokta Detayı',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (poi['address'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(poi['address'], style: const TextStyle(color: AppTheme.textSecondary))),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _textController.text = "${poi['title']} için rota çiz";
                    _sendMessage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Buraya Rota Çiz', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showProfileModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppTheme.accent),
            SizedBox(width: 8),
            Text('Ajan Profili', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: G-7821-X', style: TextStyle(color: AppTheme.textSecondary)),
            SizedBox(height: 8),
            Text('Yetki Seviyesi: Alpha', style: TextStyle(color: AppTheme.textSecondary)),
            SizedBox(height: 8),
            Text('Bölge: İstanbul / Marmara', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/profile');
            },
            child: const Text('DETAYLAR', style: TextStyle(color: AppTheme.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('KAPAT', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (_mapController == null) return;
      
      bool markersChanged = previous?.markers.length != next.markers.length;
      bool polylinesChanged = previous?.polylines.length != next.polylines.length;
      
      if (markersChanged || polylinesChanged) {
        if (next.markers.isEmpty && next.polylines.isEmpty) return;

        double minLat = 90.0;
        double maxLat = -90.0;
        double minLng = 180.0;
        double maxLng = -180.0;

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

        if (hasPoints) {
          // 🚨 FIX: Web tarafında harita henüz hazır değilken animasyon yapılması çökme yapabilir.
          // Küçük bir gecikme ve try-catch ile koruma sağlıyoruz.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_mapController == null) return;
            try {
              if (minLat == maxLat || minLng == maxLng) {
                _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0));
              } else {
                final bounds = LatLngBounds(
                  southwest: LatLng(minLat, minLng),
                  northeast: LatLng(maxLat, maxLng),
                );
                
                _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0))
                .catchError((e) {
                   // Fallback: Bounds başarısız olursa (Web-Specific error) merkeze zoom yap
                   final centerLat = (minLat + maxLat) / 2;
                   final centerLng = (minLng + maxLng) / 2;
                   _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 13.0));
                   return null;
                });
              }
            } catch (e) {
              debugPrint('⚠️ Harita odaklanırken hata oluştu (Web-Safe): $e');
            }
          });
        }
      }
    });

    ref.listen<Map<String, dynamic>?>(selectedPoiProvider, (previous, next) {
      if (next != null && context.mounted) {
        _showPoiDetailModal(context, next);
        // Clear it immediately so it can be opened again if tapped
        Future.delayed(Duration.zero, () {
          ref.read(selectedPoiProvider.notifier).setPoi(null);
        });
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: AppTheme.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.surface),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.satellite_alt, size: 48, color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('GeoIntel Sistem Menüsü', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppTheme.textSecondary),
              title: const Text('Tarihçe ve Loglar', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                context.push('/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks, color: AppTheme.textSecondary),
              title: const Text('Kayıtlı Konumlar', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                context.push('/locations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppTheme.textSecondary),
              title: const Text('Sistem Ayarları', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 12.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: chatState.markers,
            polylines: chatState.polylines,
          ),
          
          // Top Bar (Glassmorphism or dark gradient)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.9),
                    AppTheme.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  _buildFloatingIconButton(Icons.menu, () {
                    _scaffoldKey.currentState?.openDrawer();
                  }),
                  Expanded(
                    child: Center(
                      child: Text(
                        'GeoIntel',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                  ),
                  _buildFloatingIconButton(Icons.person, _showProfileModal),
                ],
              ),
            ),
          ),

          // Draggable Bottom Sheet for AI Chat / Interaction
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == chatState.messages.length) {
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(color: AppTheme.accent),
                                ),
                              );
                            }
                            final msg = chatState.messages[index];
                            return _buildChatBubble(msg);
                          },
                          childCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: _buildChatInput(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 140.0), // Above the bottom sheet
        child: FloatingActionButton(
          backgroundColor: AppTheme.surface,
          child: const Icon(Icons.my_location, color: AppTheme.accent),
          onPressed: _goToMyLocation,
        ),
      ),
    );
  }

  Widget _buildFloatingIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textPrimary),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isAi = msg.isAi;
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAi ? AppTheme.background : AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isAi ? const Radius.circular(0) : const Radius.circular(16),
                  bottomRight: !isAi ? const Radius.circular(0) : const Radius.circular(16),
                ),
                border: Border.all(color: isAi ? Colors.white10 : AppTheme.accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
                  ),
                  if (msg.toolsUsed != null && msg.toolsUsed!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: msg.toolsUsed!.map((tool) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "⚙️ ${tool.toUpperCase()}",
                          style: const TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (msg.actionCards != null && msg.actionCards!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.actionCards!.map((card) {
                  return ActionChip(
                    backgroundColor: AppTheme.surface,
                    side: const BorderSide(color: AppTheme.accent, width: 1),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (card['icon'] != null && card['icon'].toString().isNotEmpty)
                           Text(card['icon'], style: const TextStyle(fontSize: 14)),
                        if (card['icon'] != null && card['icon'].toString().isNotEmpty)
                           const SizedBox(width: 4),
                        Text(card['label'] ?? 'Aksiyon', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                      ],
                    ),
                    onPressed: () {
                      final action = card['action']?.toString();
                      final label = card['label']?.toString() ?? '';
                      
                      if (action == 'start_navigation') {
                        context.push('/route_detail');
                      } else {
                        // AI'ya mesaj gönder: 'action' varsa onu, yoksa 'label'ı gönder
                        final messageToSend = (action != null && action.length > 3) ? action : label;
                        if (messageToSend.isNotEmpty) {
                          ref.read(chatProvider.notifier).sendMessage(messageToSend);
                        }
                      }
                    },
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'GeoIntel\'e sor...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.accent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
