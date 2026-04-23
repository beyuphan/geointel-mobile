import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'package:dio/dio.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class ChatMessage {
  final String text;
  final bool isAi;
  final List<dynamic>? actionCards;
  final List<String>? toolsUsed;
  
  ChatMessage({
    required this.text, 
    required this.isAi, 
    this.actionCards,
    this.toolsUsed,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  ChatState({
    required this.messages, 
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

class ChatNotifier extends Notifier<ChatState> {
  final String sessionId = 'mobile_session_${DateTime.now().millisecondsSinceEpoch}';

  @override
  ChatState build() {
    return ChatState(messages: [
      ChatMessage(text: "Şehir analiz sistemleri devrede. Hangi bölgeyi incelemek istersiniz?", isAi: true)
    ]);
  }

  // Google Encoded Polyline Decoder
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
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

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    debugPrint('📍 Decoded ${poly.length} points.');
    return poly;
  }

  double _currentLat = 41.0082;
  double _currentLon = 28.9784;

  void updateCurrentLocation(double lat, double lon) {
    _currentLat = lat;
    _currentLon = lon;
    
    // Arka planda sunucuyu güncelle ki Redis'te her an canlı kalsın
    try {
      ref.read(dioProvider).post('/api/v1/location/update', data: {
        'session_id': sessionId,
        'lat': lat,
        'lon': lon,
      });
    } catch (e) {
      // Sessizce yut, arka plan işlemi
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isAi: false)],
      isLoading: true,
      // 🚨 FIX: Artık mesaj gönderirken haritayı temizlemiyoruz, 
      // böylece yeni yanıt gelene kadar eski rota ekranda kalmaya devam ediyor.
      // markers: const {},
      // polylines: const {},
    );

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
        final replyText = dataBlock['message'] ?? "Boş yanıt alındı.";
        final mapData = dataBlock['map'] ?? {};
        final actionCards = dataBlock['action_cards'] as List<dynamic>? ?? [];
        
        Set<Marker> newMarkers = {};
        Set<Polyline> newPolylines = {};
        
        if (mapData['markers'] != null) {
          final markersList = mapData['markers'] as List;
          for (int i = 0; i < markersList.length; i++) {
            final m = markersList[i];
            final mLat = m['lat'] is String ? double.tryParse(m['lat']) ?? 0.0 : (m['lat'] as num?)?.toDouble() ?? 0.0;
            final mLon = m['lon'] is String ? double.tryParse(m['lon']) ?? 0.0 : (m['lon'] as num?)?.toDouble() ?? 0.0;
            final mType = m['type']?.toString().toLowerCase() ?? '';
            
            double hue = BitmapDescriptor.hueCyan;
            if (mType.contains('pharmacy')) hue = BitmapDescriptor.hueRed;
            else if (mType.contains('fuel')) hue = BitmapDescriptor.hueOrange;
            else if (mType.contains('origin')) hue = BitmapDescriptor.hueGreen;
            else if (mType.contains('destination')) hue = BitmapDescriptor.hueAzure;

            newMarkers.add(Marker(
              markerId: MarkerId('marker_$i'),
              position: LatLng(mLat, mLon),
              infoWindow: InfoWindow(title: m['title'] ?? m['name'] ?? 'Nokta'),
              onTap: () {
                ref.read(selectedPoiProvider.notifier).setPoi(m as Map<String, dynamic>);
              },
              icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            ));
          }
        }

        if (mapData['polyline'] != null) {
          final polylineStr = mapData['polyline'] as String;
          debugPrint('📍 Received Polyline (Length: ${polylineStr.length})');
          // 🚨 FIX: Köşeli parantez kontrolünü gevşettik, sadece uzunluk kontrolü yapıyoruz.
          // Çünkü bazen koordinat listesi string olarak gelebilir.
          if (polylineStr.isNotEmpty && polylineStr.length > 50) {
            try {
              final points = _decodePolyline(polylineStr);
              debugPrint('📍 Successfully decoded ${points.length} points.');
              newPolylines.add(
                Polyline(
                  polylineId: PolylineId('route_${DateTime.now().millisecondsSinceEpoch}'),
                  points: points,
                  color: AppTheme.accent,
                  width: 6,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                )
              );
            } catch (e) {
              debugPrint('❌ Error decoding polyline: $e');
            }
          } else {
            debugPrint('⚠️ Polyline string skipped (contains [ or GİZLENDİ or empty)');
          }
        }
        
        final toolsUsed = (dataBlock['tools_used'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        
        state = state.copyWith(
          messages: [...state.messages, ChatMessage(
            text: replyText, 
            isAi: true, 
            actionCards: actionCards,
            toolsUsed: toolsUsed,
          )],
          isLoading: false,
          markers: newMarkers.isNotEmpty ? newMarkers : state.markers,
          polylines: newPolylines.isNotEmpty ? newPolylines : state.polylines,
        );
      } else {
        throw Exception("API Error");
      }
    } catch (e) {
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text: "Bağlantı hatası: Sunucuya ulaşılamadı. Lütfen backend'in çalıştığından emin olun.", isAi: true)],
        isLoading: false,
      );
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

class SelectedPoiNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  
  void setPoi(Map<String, dynamic>? poi) {
    state = poi;
  }
}

final selectedPoiProvider = NotifierProvider<SelectedPoiNotifier, Map<String, dynamic>?>(() {
  return SelectedPoiNotifier();
});


