import '../entities/health_metric.dart';

abstract class HealthRepository {
  Future<List<HealthMetric>> getStepsHistory();
  Future<List<HealthMetric>> getSleepHistory();
  Future<List<HealthMetric>> getHeartRateHistory();
  Future<List<HealthMetric>> getCaloriesHistory();
  Future<void> syncWithGoogleFit();
}
