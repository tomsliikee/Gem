import '../../domain/entities/health_metric.dart';

class HealthMetricModel extends HealthMetric {
  const HealthMetricModel({
    required super.timestamp,
    required super.type,
    required super.value,
  });

  factory HealthMetricModel.fromJson(Map<String, dynamic> json, MetricType type) {
    switch (type) {
      case MetricType.steps:
        final count = (json['count'] as num).toDouble();
        if (count < 0 || count > 1000000) {
          throw const FormatException('Step count is out of bounds');
        }
        return HealthMetricModel(
          timestamp: DateTime.parse(json['date'] as String),
          type: type,
          value: count,
        );
      case MetricType.sleep:
        final duration = (json['duration_seconds'] as num).toDouble();
        if (duration < 0 || duration > 86400) {
          throw const FormatException('Sleep duration is out of bounds');
        }
        return HealthMetricModel(
          timestamp: DateTime.parse(json['date'] as String),
          type: type,
          value: duration,
        );
      case MetricType.heartRate:
        final bpm = (json['bpm'] as num).toDouble();
        if (bpm < 0 || bpm > 300) {
          throw const FormatException('Heart rate is out of bounds');
        }
        return HealthMetricModel(
          timestamp: DateTime.parse(json['timestamp'] as String),
          type: type,
          value: bpm,
        );
      case MetricType.calories:
        final kcal = (json['kcal'] as num).toDouble();
        if (kcal < 0 || kcal > 20000) {
          throw const FormatException('Calories value is out of bounds');
        }
        return HealthMetricModel(
          timestamp: DateTime.parse(json['date'] as String),
          type: type,
          value: kcal,
        );
    }
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case MetricType.steps:
        return {
          'date': timestamp.toIso8601String().substring(0, 10),
          'count': value.toInt(),
        };
      case MetricType.sleep:
        return {
          'date': timestamp.toIso8601String().substring(0, 10),
          'duration_seconds': value.toInt(),
        };
      case MetricType.heartRate:
        return {
          'timestamp': timestamp.toIso8601String(),
          'bpm': value.toInt(),
        };
      case MetricType.calories:
        return {
          'date': timestamp.toIso8601String().substring(0, 10),
          'kcal': value.toInt(),
        };
    }
  }
}
