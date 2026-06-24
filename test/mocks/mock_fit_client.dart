import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MockGoogleFitHttpClient {
  static http.Client createMockClient({
    required List<Map<String, dynamic>> stepsData,
    required List<Map<String, dynamic>> sleepData,
    required List<Map<String, dynamic>> heartRateData,
    int statusCode = 200,
    bool simulateUnauthorized = false,
  }) {
    return MockClient((request) async {
      if (simulateUnauthorized) {
        return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
      }

      if (statusCode != 200) {
        return http.Response(jsonEncode({'error': 'Server Error'}), statusCode);
      }

      // Check header token injection
      if (!request.headers.containsKey('Authorization') || 
          !request.headers['Authorization']!.startsWith('Bearer ')) {
        return http.Response(jsonEncode({'error': 'Missing access token'}), 401);
      }

      final urlPath = request.url.path;

      // Steps query
      if (urlPath.contains('/v1/users/me/dataset') && urlPath.contains('step_count')) {
        return http.Response(jsonEncode({
          'point': stepsData.map((d) => {
            'startTimeNanos': '${DateTime.parse(d['date'] as String).millisecondsSinceEpoch}000000',
            'endTimeNanos': '${DateTime.parse(d['date'] as String).add(const Duration(hours: 24)).millisecondsSinceEpoch}000000',
            'dataTypeName': 'com.google.step_count.delta',
            'value': [{'intVal': d['count'] as int}]
          }).toList()
        }), statusCode);
      }

      // Sleep query
      if (urlPath.contains('/v1/users/me/dataset') && urlPath.contains('sleep')) {
        return http.Response(jsonEncode({
          'point': sleepData.map((d) => {
            'startTimeNanos': '${DateTime.parse(d['date'] as String).millisecondsSinceEpoch}000000',
            'endTimeNanos': '${DateTime.parse(d['date'] as String).add(Duration(seconds: d['duration_seconds'] as int)).millisecondsSinceEpoch}000000',
            'dataTypeName': 'com.google.sleep.segment',
            'value': [{'intVal': 1}]
          }).toList()
        }), statusCode);
      }

      // Heart rate queries
      if (urlPath.contains('/v1/users/me/dataSources') || urlPath.contains('heart_rate')) {
        return http.Response(jsonEncode({
          'point': heartRateData.map((d) => {
            'startTimeNanos': '${DateTime.parse(d['timestamp'] as String).millisecondsSinceEpoch}000000',
            'endTimeNanos': '${DateTime.parse(d['timestamp'] as String).millisecondsSinceEpoch}000000',
            'dataTypeName': 'com.google.heart_rate.bpm',
            'value': [{'fpVal': (d['bpm'] as num).toDouble()}]
          }).toList()
        }), statusCode);
      }

      return http.Response(jsonEncode({'error': 'Not Found'}), 404);
    });
  }
}
