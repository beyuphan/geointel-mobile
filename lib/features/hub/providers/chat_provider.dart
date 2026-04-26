import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geointel_mobile/core/network/api_client.dart';
import 'package:geointel_mobile/core/theme/app_theme.dart';

@immutable
class ChatMessage {
  final String text;
  final bool isAi;
  final List<dynamic>? actionCards;
  final List<String>? toolsUsed;

  const ChatMessage({
    required this.text,
    required this.isAi,
    this.actionCards,
    this.toolsUsed,
  });
}

@immutable
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.markers = const {},
    this.polylines = const {},
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
    );
  }
}

class ActiveRouteInfoNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void setRoute(Map<String, dynamic>? route) => state = route;
}
final activeRouteInfoProvider = NotifierProvider<ActiveRouteInfoNotifier, Map<String, dynamic>?>(ActiveRouteInfoNotifier.new);

class SelectedPoiNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void setPoi(Map<String, dynamic>? poi) => state = poi;
}
final selectedPoiProvider = NotifierProvider<SelectedPoiNotifier, Map<String, dynamic>?>(SelectedPoiNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  String get sessionId => "default_session";
  double _currentLat = 41.0082;
  double _currentLon = 28.9784;

  void updateCurrentLocation(double lat, double lon) {
    _currentLat = lat;
    _currentLon = lon;
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    if (encoded.startsWith('B') || encoded.startsWith('v')) {
      return _decodeFlexiblePolyline(encoded);
    }
    return _decodeGooglePolyline(encoded);
  }

  List<LatLng> _decodeGooglePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  List<LatLng> _decodeFlexiblePolyline(String encoded) {
    List<LatLng> points = [];
    try {
      int index = 0;
      int b = encoded.codeUnitAt(index++) - 63;
      int result = b & 0x1f;
      int shift = 5;
      while (b >= 0x20) {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      }
      b = encoded.codeUnitAt(index++) - 63;
      result = b & 0x1f;
      shift = 5;
      while (b >= 0x20) {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      }
      double multiplier = result == 7 ? 1e7 : 1e5;
      int lat = 0, lng = 0;
      while (index < encoded.length) {
        shift = 0; result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        shift = 0; result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        points.add(LatLng(lat / multiplier, lng / multiplier));
      }
    } catch (e) {
      debugPrint('v6 decoder error: $e');
    }
    return points;
  }

  List<LatLng> _processPoints(String polyStr) {
    List<LatLng> points = [];
    if (polyStr.startsWith('[')) {
      final List<dynamic> raw = jsonDecode(polyStr);
      points = raw.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
    } else {
      points = _decodePolyline(polyStr);
    }

    // 🚀 OPTIMIZATION (Orijinal 406 satırlık koddaki sihirli dokunuş)
    if (points.length > 500) {
      debugPrint('📍 Received Polyline (Length: ${points.length})');
      int skipCount = (points.length / 400).ceil();
      List<LatLng> simplifiedPoints = [];
      for (int i = 0; i < points.length; i += skipCount) {
        simplifiedPoints.add(points[i]);
      }
      if (simplifiedPoints.last != points.last) simplifiedPoints.add(points.last);
      points = simplifiedPoints;
      debugPrint('📍 Optimized to ${points.length} points for stability.');
    }
    return points;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(messages: [...state.messages, ChatMessage(text: text, isAi: false)], isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/v1/chat', data: {
        'message': text,
        'session_id': sessionId,
        'current_lat': _currentLat,
        'current_lon': _currentLon,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final dataBlock = response.data['data'] ?? {};
        final replyText = dataBlock['message'] ?? "";
        final mapData = dataBlock['map'] ?? {};
        
        Set<Polyline> newPolylines = {};
        if (mapData['polyline'] != null) {
          final pts = _processPoints(mapData['polyline'] as String);
          newPolylines.add(Polyline(
            polylineId: const PolylineId('active'),
            points: pts,
            color: AppTheme.accent,
            width: 5,
            zIndex: 10,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ));

          if (mapData['alternatives'] != null) {
            final alts = mapData['alternatives'] as List;
            for (int i = 0; i < alts.length; i++) {
              final aPts = _processPoints(alts[i] as String);
              newPolylines.add(Polyline(
                polylineId: PolylineId('alt_$i'),
                points: aPts,
                color: Colors.white.withValues(alpha: 0.3),
                width: 4,
                zIndex: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ));
            }
          }

          ref.read(activeRouteInfoProvider.notifier).setRoute({
            'title': text, 
            'distance': dataBlock['distance_km'] ?? '?', 
            'duration': dataBlock['duration_min'] ?? '?',
          });
        }

        Set<Marker> newMarkers = {};
        if (mapData['markers'] != null) {
          final markersList = mapData['markers'] as List;
          for (int i = 0; i < markersList.length; i++) {
            final m = markersList[i];
            newMarkers.add(Marker(
              markerId: MarkerId('m_$i'),
              position: LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()),
              infoWindow: InfoWindow(title: m['title'] ?? m['name']),
              onTap: () => ref.read(selectedPoiProvider.notifier).setPoi(m as Map<String, dynamic>),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            ));
          }
        }

        final toolsUsed = (dataBlock['tools_used'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        state = state.copyWith(
          messages: [...state.messages, ChatMessage(
            text: replyText, 
            isAi: true, 
            actionCards: dataBlock['action_cards'],
            toolsUsed: toolsUsed,
          )],
          isLoading: false,
          markers: newMarkers.isNotEmpty ? newMarkers : state.markers,
          polylines: newPolylines.isNotEmpty ? newPolylines : state.polylines,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
