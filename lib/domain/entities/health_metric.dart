enum MetricType { steps, sleep, heartRate, calories }

class HealthMetric {
  final DateTime timestamp;
  final MetricType type;
  final double value;

  const HealthMetric({
    required this.timestamp,
    required this.type,
    required this.value,
  });
}
