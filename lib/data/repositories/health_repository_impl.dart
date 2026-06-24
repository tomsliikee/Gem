import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../domain/entities/health_metric.dart';
import '../../domain/repositories/health_repository.dart';
import '../models/health_metric_model.dart';
import '../services/oauth_service.dart';
import 'local_health_cache.dart';

class GoogleFitHealthRepository implements HealthRepository {
  final OAuthService _oauthService;
  final http.Client _client;
  final LocalHealthCache _cache;

  GoogleFitHealthRepository(
    this._oauthService, [
    http.Client? client,
    LocalHealthCache? cache,
  ])  : _client = client ?? http.Client(),
        _cache = cache ?? LocalHealthCache();

  @override
  Future<List<HealthMetric>> getStepsHistory() async {
    try {
      final token = await _oauthService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      final response = await _client.get(
        Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset/step_count'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = _parseSteps(body);
      await _cache.writeMetrics(MetricType.steps, metrics);
      return metrics;
    } catch (e) {
      developer.log('Error fetching steps: $e. Falling back to cache.', name: 'GoogleFitHealthRepository');
      return _cache.readMetrics(MetricType.steps);
    }
  }

  @override
  Future<List<HealthMetric>> getSleepHistory() async {
    try {
      final token = await _oauthService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      final response = await _client.get(
        Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset/sleep'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = _parseSleep(body);
      await _cache.writeMetrics(MetricType.sleep, metrics);
      return metrics;
    } catch (e) {
      developer.log('Error fetching sleep: $e. Falling back to cache.', name: 'GoogleFitHealthRepository');
      return _cache.readMetrics(MetricType.sleep);
    }
  }

  @override
  Future<List<HealthMetric>> getHeartRateHistory() async {
    try {
      final token = await _oauthService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      final response = await _client.get(
        Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources/heart_rate'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = _parseHeartRate(body);
      await _cache.writeMetrics(MetricType.heartRate, metrics);
      return metrics;
    } catch (e) {
      developer.log('Error fetching heart rate: $e. Falling back to cache.', name: 'GoogleFitHealthRepository');
      return _cache.readMetrics(MetricType.heartRate);
    }
  }

  @override
  Future<List<HealthMetric>> getCaloriesHistory() async {
    try {
      final token = await _oauthService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      final response = await _client.get(
        Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset/calories'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = _parseCalories(body);
      await _cache.writeMetrics(MetricType.calories, metrics);
      return metrics;
    } catch (e) {
      developer.log('Error fetching calories: $e. Falling back to cache.', name: 'GoogleFitHealthRepository');
      return _cache.readMetrics(MetricType.calories);
    }
  }

  @override
  Future<void> syncWithGoogleFit() async {
    await getStepsHistory();
    await getSleepHistory();
    await getHeartRateHistory();
    await getCaloriesHistory();
  }

  List<HealthMetric> _parseCalories(Map<String, dynamic> body) {
    final points = body['point'] as List<dynamic>? ?? [];
    return points.map((p) {
      final startNanos = int.parse(p['startTimeNanos'].toString());
      final timestamp = DateTime.fromMillisecondsSinceEpoch(startNanos ~/ 1000000, isUtc: true);
      final valueList = p['value'] as List<dynamic>;
      final val = valueList.isNotEmpty ? (valueList[0]['fpVal'] as num).toDouble() : 0.0;
      return HealthMetricModel(
        timestamp: timestamp,
        type: MetricType.calories,
        value: val,
      );
    }).toList();
  }

  List<HealthMetric> _parseSteps(Map<String, dynamic> body) {
    final points = body['point'] as List<dynamic>? ?? [];
    return points.map((p) {
      final startNanos = int.parse(p['startTimeNanos'].toString());
      final timestamp = DateTime.fromMillisecondsSinceEpoch(startNanos ~/ 1000000, isUtc: true);
      final valueList = p['value'] as List<dynamic>;
      final val = valueList.isNotEmpty ? (valueList[0]['intVal'] as int).toDouble() : 0.0;
      return HealthMetricModel(
        timestamp: timestamp,
        type: MetricType.steps,
        value: val,
      );
    }).toList();
  }

  List<HealthMetric> _parseSleep(Map<String, dynamic> body) {
    final points = body['point'] as List<dynamic>? ?? [];
    return points.map((p) {
      final startNanos = int.parse(p['startTimeNanos'].toString());
      final endNanos = int.parse(p['endTimeNanos'].toString());
      final durationSeconds = (endNanos - startNanos) / 1000000000;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(startNanos ~/ 1000000, isUtc: true);
      return HealthMetricModel(
        timestamp: timestamp,
        type: MetricType.sleep,
        value: durationSeconds,
      );
    }).toList();
  }

  List<HealthMetric> _parseHeartRate(Map<String, dynamic> body) {
    final points = body['point'] as List<dynamic>? ?? [];
    return points.map((p) {
      final startNanos = int.parse(p['startTimeNanos'].toString());
      final timestamp = DateTime.fromMillisecondsSinceEpoch(startNanos ~/ 1000000, isUtc: true);
      final valueList = p['value'] as List<dynamic>;
      final val = valueList.isNotEmpty ? (valueList[0]['fpVal'] as num).toDouble() : 0.0;
      return HealthMetricModel(
        timestamp: timestamp,
        type: MetricType.heartRate,
        value: val,
      );
    }).toList();
  }
}
