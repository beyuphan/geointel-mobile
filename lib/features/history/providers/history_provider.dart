import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geointel_mobile/core/network/api_client.dart';

final chatHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/v1/history/chat');
    if (response.data['success'] == true) {
      return response.data['data']['messages'] ?? [];
    }
  } catch (e) {
    return [];
  }
  return [];
});

final routeHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/v1/history/routes');
    if (response.data['success'] == true) {
      return response.data['data']['routes'] ?? [];
    }
  } catch (e) {
    return [];
  }
  return [];
});
