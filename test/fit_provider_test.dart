import 'package:flutter_test/flutter_test.dart';
import 'package:gem/domain/entities/health_metric.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  test('Retrieves local cached data when API fails (Offline Fallback)', () async {
    final cachedSteps = [
      HealthMetric(timestamp: DateTime.parse('2026-06-18'), type: MetricType.steps, value: 5000),
    ];
    final repo = FakeHealthRepository(cachedSteps);
    
    // Test happy path
    var data = await repo.getStepsHistory();
    expect(data.first.value, 8000);

    // Force error, triggers fallback
    repo.simulateError = true;
    data = await repo.getStepsHistory();
    
    expect(data.first.value, 5000);
    expect(data.first.timestamp, DateTime.parse('2026-06-18'));
  });
}
