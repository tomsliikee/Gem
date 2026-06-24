import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/health_metric.dart';
import '../models/health_metric_model.dart';

class LocalHealthCache {
  final String _filename;

  LocalHealthCache({this._filename = 'health_metrics_cache.json'});

  Future<File> _getCacheFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/$_filename');
    } catch (e) {
      try {
        final directory = await getApplicationSupportDirectory();
        return File('${directory.path}/$_filename');
      } catch (e) {
        return File('${Directory.systemTemp.path}/$_filename');
      }
    }
  }

  Future<List<HealthMetricModel>> readMetrics(MetricType type) async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      final String key = _getKeyForType(type);
      final List<dynamic>? list = data[key] as List<dynamic>?;
      if (list == null) return [];
      return list.map((item) => HealthMetricModel.fromJson(item as Map<String, dynamic>, type)).toList();
    } catch (e) {
      developer.log('Error reading health cache: $e', name: 'LocalHealthCache');
      return [];
    }
  }

  Future<void> writeMetrics(MetricType type, List<HealthMetric> metrics) async {
    try {
      final file = await _getCacheFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          data = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }
      final String key = _getKeyForType(type);

      final models = metrics.map((m) {
        if (m is HealthMetricModel) {
          return m;
        } else {
          return HealthMetricModel(timestamp: m.timestamp, type: m.type, value: m.value);
        }
      }).toList();

      data[key] = models.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      developer.log('Error writing health cache: $e', name: 'LocalHealthCache');
    }
  }

  String _getKeyForType(MetricType type) {
    switch (type) {
      case MetricType.steps:
        return 'steps';
      case MetricType.sleep:
        return 'sleep';
      case MetricType.heartRate:
        return 'heart_rate';
      case MetricType.calories:
        return 'calories';
    }
  }
}
