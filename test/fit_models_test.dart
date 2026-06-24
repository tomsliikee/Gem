import 'package:flutter_test/flutter_test.dart';
import 'package:gem/data/models/health_metric_model.dart';
import 'package:gem/domain/entities/health_metric.dart';

void main() {
  group('HealthMetricModel - Steps', () {
    test('Correctly deserializes and serializes Steps data', () {
      final json = {'date': '2026-06-19', 'count': 10000};
      final model = HealthMetricModel.fromJson(json, MetricType.steps);
      
      expect(model.type, MetricType.steps);
      expect(model.value, 10000.0);
      expect(model.timestamp, DateTime.parse('2026-06-19'));
      
      final serialized = model.toJson();
      expect(serialized['date'], '2026-06-19');
      expect(serialized['count'], 10000);
    });
  });

  group('HealthMetricModel - Sleep', () {
    test('Correctly deserializes and serializes Sleep data', () {
      final json = {'date': '2026-06-19', 'duration_seconds': 28800};
      final model = HealthMetricModel.fromJson(json, MetricType.sleep);
      
      expect(model.type, MetricType.sleep);
      expect(model.value, 28800.0);
      expect(model.timestamp, DateTime.parse('2026-06-19'));
      
      final serialized = model.toJson();
      expect(serialized['date'], '2026-06-19');
      expect(serialized['duration_seconds'], 28800);
    });
  });

  group('HealthMetricModel - Heart Rate', () {
    test('Correctly deserializes and serializes Heart Rate data', () {
      final json = {'timestamp': '2026-06-19T18:50:00.000Z', 'bpm': 72};
      final model = HealthMetricModel.fromJson(json, MetricType.heartRate);
      
      expect(model.type, MetricType.heartRate);
      expect(model.value, 72.0);
      expect(model.timestamp, DateTime.parse('2026-06-19T18:50:00.000Z'));
      
      final serialized = model.toJson();
      expect(serialized['bpm'], 72);
      expect(serialized['timestamp'], '2026-06-19T18:50:00.000Z');
    });
  });

  group('HealthMetricModel - Calories', () {
    test('Correctly deserializes and serializes Calories data', () {
      final json = {'date': '2026-06-19', 'kcal': 2500};
      final model = HealthMetricModel.fromJson(json, MetricType.calories);
      
      expect(model.type, MetricType.calories);
      expect(model.value, 2500.0);
      expect(model.timestamp, DateTime.parse('2026-06-19'));
      
      final serialized = model.toJson();
      expect(serialized['date'], '2026-06-19');
      expect(serialized['kcal'], 2500);
    });
  });
}
