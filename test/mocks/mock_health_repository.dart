import 'package:gem/domain/entities/health_metric.dart';
import 'package:gem/domain/repositories/health_repository.dart';

class FakeHealthRepository implements HealthRepository {
  bool simulateError = false;
  List<HealthMetric> cachedData;
  
  FakeHealthRepository(this.cachedData);

  @override
  Future<List<HealthMetric>> getStepsHistory() async {
    if (simulateError) {
      // Fallback to cache on error
      return cachedData;
    }
    return [
      HealthMetric(timestamp: DateTime.now(), type: MetricType.steps, value: 8000),
    ];
  }

  @override
  Future<List<HealthMetric>> getSleepHistory() async => [];
  @override
  Future<List<HealthMetric>> getHeartRateHistory() async => [];
  @override
  Future<List<HealthMetric>> getCaloriesHistory() async => [];
  @override
  Future<void> syncWithGoogleFit() async {
    if (simulateError) {
      throw Exception('HTTP 500 Internal Error');
    }
  }

  void pruneCache(DateTime now) {
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    cachedData = cachedData.where((metric) => !metric.timestamp.isBefore(thirtyDaysAgo)).toList();
  }
}
