import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geointel_mobile/core/network/api_client.dart';
import 'package:geointel_mobile/core/theme/app_theme.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

@immutable
class ChatMessage {
  final String text;
  final bool isAi;

  const ChatMessage({required this.text, required this.isAi});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Map<String, dynamic>? poiOverlay;
  final double? distanceKm;
  final int? durationMin;
  final String? etaDisplay;
  final Map<String, dynamic>? tollInfo;
  final List<dynamic> weatherWarnings;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.markers = const {},
    this.polylines = const {},
    this.poiOverlay,
    this.distanceKm,
    this.durationMin,
    this.etaDisplay,
    this.tollInfo,
    this.weatherWarnings = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Map<String, dynamic>? poiOverlay,
    double? distanceKm,
    int? durationMin,
    String? etaDisplay,
    Map<String, dynamic>? tollInfo,
    List<dynamic>? weatherWarnings,
  }) => ChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    markers: markers ?? this.markers,
    polylines: polylines ?? this.polylines,
    poiOverlay: poiOverlay,
    distanceKm: distanceKm ?? this.distanceKm,
    durationMin: durationMin ?? this.durationMin,
    etaDisplay: etaDisplay ?? this.etaDisplay,
    tollInfo: tollInfo,
    weatherWarnings: weatherWarnings ?? this.weatherWarnings,
  );
}

class ActiveRouteInfoNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void setRoute(Map<String, dynamic>? route) => state = route;
}

final activeRouteInfoProvider =
    NotifierProvider<ActiveRouteInfoNotifier, Map<String, dynamic>?>(
        ActiveRouteInfoNotifier.new);

// ─── Secondary Providers ──────────────────────────────────────────────────────

class SelectedPoiNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void setPoi(Map<String, dynamic>? poi) => state = poi;
}

final selectedPoiProvider =
    NotifierProvider<SelectedPoiNotifier, Map<String, dynamic>?>(
        SelectedPoiNotifier.new);

// ─── Chat Notifier ────────────────────────────────────────────────────────────

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  final String sessionId = 'default_session';
  double _lat = 41.0082;
  double _lon = 28.9784;

  double get currentLat => _lat;
  double get currentLon => _lon;

  void updateCurrentLocation(double lat, double lon) {
    _lat = lat;
    _lon = lon;
  }

  // ── Polyline decode ──────────────────────────────────────────────────────

  List<LatLng> _processPolyline(String raw) {
    List<LatLng> points = [];

    // Backend JSON list formatı: [[lat,lon],...]
    if (raw.startsWith('[')) {
      try {
        final list = jsonDecode(raw) as List;
        points = list
            .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
      } catch (_) {}
    } else {
      // Google v5 encoded polyline
      points = _decodeGoogle(raw);
    }

    // Simplify if too many points
    if (points.length > 500) {
      final step = (points.length / 400).ceil();
      final simplified = <LatLng>[];
      for (int i = 0; i < points.length; i += step) {
        simplified.add(points[i]);
      }
      if (simplified.last != points.last) simplified.add(points.last);
      return simplified;
    }
    return points;
  }

  List<LatLng> _decodeGoogle(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Plan Trip (Yapılandırılmış Yolculuk) ──────────────────────────────

  Future<void> planTrip({
    required String destination,
    List<String> waypoints = const [],
    double breakIntervalHours = 2.0,
    String foodPreference = 'Fark etmez',
    String foodLocation = 'Ortaları',
    double fuelRemainingKm = 0,
    String customNote = '',
  }) async {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: '🗺️ $destination rotam planlanıyor...', isAi: false),
      ],
      isLoading: true,
    );

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/v1/trip/plan', data: {
        'origin': 'CURRENT_LOCATION',
        'destination': destination,
        'waypoints': waypoints,
        'break_interval_hours': breakIntervalHours,
        'food_preference': foodPreference,
        'food_location': foodLocation,
        'fuel_remaining_km': fuelRemainingKm,
        'custom_note': customNote,
        'session_id': sessionId,
        'current_lat': _lat,
        'current_lon': _lon,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        await _processResponse(response.data['data'] ?? {});
      } else {
        _addError('Rota planlanamadı.');
      }
    } catch (e) {
      _addError('Bağlantı hatası: ${e.toString().split('\n').first}');
    }
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isAi: false)],
      isLoading: true,
    );

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/v1/chat', data: {
        'message': text,
        'session_id': sessionId,
        'current_lat': _lat,
        'current_lon': _lon,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        await _processResponse(response.data['data'] ?? {});
      } else {
        _addError('Sunucudan geçersiz yanıt alındı.');
      }
    } catch (e) {
      _addError('Bağlantı hatası: ${e.toString().split('\n').first}');
    }
  }

  /// Dışarıdan (POI seçim ekranı vb.) gelen hazır API yanıtını state'e yaz.
  /// LLM roundtrip olmadan doğrudan state güncelleme.
  Future<void> processExternalResponse(Map<String, dynamic> data) async {
    await _processResponse(data);
  }

  // ── Response processing (ortak — planTrip ve sendMessage paylaşır) ─────

  Future<void> _processResponse(Map<String, dynamic> data) async {
    final replyText = data['message'] as String? ?? '';
    final mapData = data['map'] as Map<String, dynamic>? ?? {};
    final overlay = data['poi_overlay'] as Map<String, dynamic>?;
    final tripPlan = data['trip_plan'] as Map<String, dynamic>?;
    final routeSummary = (overlay?['route_summary']) as Map<String, dynamic>?;

    final dist = (data['distance_km'] as num?)?.toDouble();
    final durationMin = (data['duration_min'] as num?)?.toInt();
    final etaDisplay = (tripPlan?['eta_display'] ?? routeSummary?['eta_display']) as String?;
    final tollInfo = (tripPlan?['toll_info'] ?? routeSummary?['toll']) as Map<String, dynamic>?;
    final weatherWarnings = (overlay?['weather_warnings'] as List<dynamic>?) ?? [];

    // ── Polylines ────────────────────────────────────────────────────
    final newPolylines = <Polyline>{};
    final polyStr = mapData['polyline'] as String?;
    if (polyStr != null && polyStr.isNotEmpty) {
      final pts = _processPolyline(polyStr);
      if (pts.isNotEmpty) {
        newPolylines.add(Polyline(
          polylineId: const PolylineId('active'),
          points: pts,
          color: AppTheme.accent,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 10,
        ));
      }

      final alts = mapData['alternatives'] as List<dynamic>? ?? [];
      for (int i = 0; i < alts.length; i++) {
        final aPts = _processPolyline(alts[i] as String);
        if (aPts.isNotEmpty) {
          newPolylines.add(Polyline(
            polylineId: PolylineId('alt_$i'),
            points: aPts,
            color: Colors.white.withValues(alpha: 0.25),
            width: 3,
            zIndex: 5,
          ));
        }
      }
    }

    // ── Markers ──────────────────────────────────────────────────────
    final newMarkers = <Marker>{};
    final markerList = mapData['markers'] as List<dynamic>? ?? [];
    for (int i = 0; i < markerList.length; i++) {
      final m = markerList[i] as Map<String, dynamic>;
      final lat = (m['lat'] as num).toDouble();
      final lon = (m['lon'] as num).toDouble();
      final type = m['type'] as String? ?? 'poi';

      final hue = type == 'pharmacy'
          ? BitmapDescriptor.hueGreen
          : type == 'fuel_station'
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueCyan;

      newMarkers.add(Marker(
        markerId: MarkerId('m_$i'),
        position: LatLng(lat, lon),
        infoWindow: InfoWindow(
          title: m['title'] as String? ?? m['name'] as String? ?? 'Nokta',
          snippet: m['snippet'] as String? ?? m['address'] as String?,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => ref.read(selectedPoiProvider.notifier).setPoi(m),
      ));
    }

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: replyText, isAi: true),
      ],
      isLoading: false,
      markers: newMarkers.isNotEmpty ? newMarkers : state.markers,
      polylines: newPolylines.isNotEmpty ? newPolylines : state.polylines,
      poiOverlay: overlay,
      distanceKm: dist ?? state.distanceKm,
      durationMin: durationMin ?? state.durationMin,
      etaDisplay: etaDisplay ?? state.etaDisplay,
      tollInfo: tollInfo,
      weatherWarnings: weatherWarnings.isNotEmpty ? weatherWarnings : state.weatherWarnings,
    );

    if (dist != null || durationMin != null) {
      ref.read(activeRouteInfoProvider.notifier).setRoute({
        'distance': dist ?? state.distanceKm,
        'duration': durationMin ?? state.durationMin,
        'eta': etaDisplay,
        'toll': tollInfo,
      });
    }
  }

  void _addError(String msg) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: '⚠️ $msg', isAi: true),
      ],
      isLoading: false,
    );
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
