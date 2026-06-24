import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gem/data/services/oauth_service_impl.dart';
import 'package:gem/data/repositories/health_repository_impl.dart';
import 'package:gem/data/repositories/local_health_cache.dart';
import 'package:gem/domain/entities/health_metric.dart';
import 'mocks/mock_oauth_service.dart';

void main() {
  group('LocalHealthCache Tests', () {
    late LocalHealthCache cache;

    setUp(() {
      cache = LocalHealthCache(filename: 'test_health_metrics_cache.json');
    });

    tearDown(() async {
      try {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/test_health_metrics_cache.json');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    });

    test('Can write and read steps metrics successfully', () async {
      final steps = [
        HealthMetric(timestamp: DateTime.parse('2026-06-18'), type: MetricType.steps, value: 5000),
        HealthMetric(timestamp: DateTime.parse('2026-06-19'), type: MetricType.steps, value: 8000),
      ];

      await cache.writeMetrics(MetricType.steps, steps);
      final read = await cache.readMetrics(MetricType.steps);

      expect(read.length, 2);
      expect(read[0].value, 5000.0);
      expect(read[0].timestamp, DateTime.parse('2026-06-18'));
      expect(read[1].value, 8000.0);
      expect(read[1].timestamp, DateTime.parse('2026-06-19'));
    });

    test('Can write and read sleep metrics successfully', () async {
      final sleep = [
        HealthMetric(timestamp: DateTime.parse('2026-06-18'), type: MetricType.sleep, value: 28800),
      ];

      await cache.writeMetrics(MetricType.sleep, sleep);
      final read = await cache.readMetrics(MetricType.sleep);

      expect(read.length, 1);
      expect(read[0].value, 28800.0);
      expect(read[0].timestamp, DateTime.parse('2026-06-18'));
    });
  });

  group('GoogleOAuthService Tests', () {
    test('Mock Mode: login, getAccessToken, isTokenExpired, logout', () async {
      // Use a non-existent config path to force mock mode
      final oauthService = GoogleOAuthService(configPath: 'non_existent_config.json');

      final loginRes = await oauthService.login();
      expect(loginRes, isTrue);

      final token = await oauthService.getAccessToken();
      expect(token, 'mock_access_token_123');

      final expired = await oauthService.isTokenExpired();
      expect(expired, isFalse);

      final states = <bool>[];
      final subscription = oauthService.authStateChanges.listen((s) => states.add(s));

      await oauthService.logout();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(states, contains(false));
      subscription.cancel();
    });

    test('Real OAuth Mode Flow with Mock Redirect Server', () async {
      // Create temporary config.json content
      final tempDir = Directory.systemTemp;
      final tempConfigFile = File('${tempDir.path}/test_config.json');
      await tempConfigFile.writeAsString(jsonEncode({
        'client_id': 'test_client_id',
        'client_secret': 'test_client_secret',
        'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
        'token_uri': 'https://oauth2.googleapis.com/token'
      }));

      // Mock redirect server
      final fakeRedirectServer = FakeOAuthRedirectServer(port: 8085, mockCode: 'auth_code_123');

      // Mock HTTP Client for token exchange
      final mockHttpClient = MockClient((request) async {
        if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
          expect(request.bodyFields['client_id'], 'test_client_id');
          expect(request.bodyFields['client_secret'], 'test_client_secret');
          expect(request.bodyFields['code'], 'auth_code_123');
          expect(request.bodyFields['grant_type'], 'authorization_code');
          return http.Response(jsonEncode({
            'access_token': 'real_access_token_abc',
            'refresh_token': 'real_refresh_token_xyz',
            'expires_in': 3600
          }), 200);
        }
        return http.Response('Not Found', 404);
      });

      final oauthService = GoogleOAuthService(
        client: mockHttpClient,
        redirectServer: fakeRedirectServer,
        configPath: tempConfigFile.path,
      );

      final loginRes = await oauthService.login();
      expect(loginRes, isTrue);

      final token = await oauthService.getAccessToken();
      expect(token, 'real_access_token_abc');

      final expired = await oauthService.isTokenExpired();
      expect(expired, isFalse);

      await tempConfigFile.delete();
      try {
        final tokenFile = File('${tempDir.path}/oauth_tokens.json');
        if (await tokenFile.exists()) {
          await tokenFile.delete();
        }
      } catch (_) {}
    });
  });

  group('GoogleFitHealthRepository Tests', () {
    late LocalHealthCache cache;
    late FakeOAuthService mockOAuth;

    setUp(() {
      cache = LocalHealthCache(filename: 'test_health_metrics_cache_repo.json');
      mockOAuth = FakeOAuthService();
    });

    tearDown(() async {
      try {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/test_health_metrics_cache_repo.json');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    });

    test('Steps API Success path & Caching', () async {
      await mockOAuth.login();

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/v1/users/me/dataset'));
        expect(request.url.path, contains('step_count'));
        expect(request.headers['Authorization'], 'Bearer mock_access_token_123');

        return http.Response(jsonEncode({
          'point': [
            {
              'startTimeNanos': '1781827200000000000', // 2026-06-18T16:00:00.000Z
              'endTimeNanos': '1781913600000000000',
              'dataTypeName': 'com.google.step_count.delta',
              'value': [{'intVal': 9200}]
            }
          ]
        }), 200);
      });

      final repo = GoogleFitHealthRepository(mockOAuth, mockClient, cache);
      final steps = await repo.getStepsHistory();

      expect(steps.length, 1);
      expect(steps.first.value, 9200.0);
      expect(steps.first.timestamp, DateTime.fromMillisecondsSinceEpoch(1781827200000, isUtc: true));

      // Read from cache to confirm
      final cached = await cache.readMetrics(MetricType.steps);
      expect(cached.length, 1);
      expect(cached.first.value, 9200.0);
    });

    test('Sleep API Success path & Duration Calculation', () async {
      await mockOAuth.login();

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/v1/users/me/dataset'));
        expect(request.url.path, contains('sleep'));

        return http.Response(jsonEncode({
          'point': [
            {
              'startTimeNanos': '1781827200000000000', // 2026-06-18T16:00:00.000Z
              'endTimeNanos': '1781856000000000000', // +28800 seconds
              'dataTypeName': 'com.google.sleep.segment',
              'value': [{'intVal': 1}]
            }
          ]
        }), 200);
      });

      final repo = GoogleFitHealthRepository(mockOAuth, mockClient, cache);
      final sleep = await repo.getSleepHistory();

      expect(sleep.length, 1);
      expect(sleep.first.value, 28800.0); // 28800 seconds (8 hours)
    });

    test('Heart Rate API Success path & fpVal parsing', () async {
      await mockOAuth.login();

      final mockClient = MockClient((request) async {
        expect(request.url.path.contains('/v1/users/me/dataSources') || request.url.path.contains('heart_rate'), isTrue);

        return http.Response(jsonEncode({
          'point': [
            {
              'startTimeNanos': '1781827200000000000',
              'endTimeNanos': '1781827200000000000',
              'dataTypeName': 'com.google.heart_rate.bpm',
              'value': [{'fpVal': 78.5}]
            }
          ]
        }), 200);
      });

      final repo = GoogleFitHealthRepository(mockOAuth, mockClient, cache);
      final hr = await repo.getHeartRateHistory();

      expect(hr.length, 1);
      expect(hr.first.value, 78.5);
    });

    test('Calories API Success path & Caching', () async {
      await mockOAuth.login();

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/v1/users/me/dataset/calories'));
        return http.Response(jsonEncode({
          'point': [
            {
              'startTimeNanos': '1781827200000000000',
              'endTimeNanos': '1781827200000000000',
              'dataTypeName': 'com.google.calories.expended',
              'value': [{'fpVal': 2250.0}]
            }
          ]
        }), 200);
      });

      final repo = GoogleFitHealthRepository(mockOAuth, mockClient, cache);
      final calories = await repo.getCaloriesHistory();

      expect(calories.length, 1);
      expect(calories.first.value, 2250.0);

      final cached = await cache.readMetrics(MetricType.calories);
      expect(cached.length, 1);
      expect(cached.first.value, 2250.0);
    });

    test('Offline Fallback when API returns error', () async {
      await mockOAuth.login();

      // Pre-populate cache
      final preCachedSteps = [
        HealthMetric(timestamp: DateTime.parse('2026-06-18'), type: MetricType.steps, value: 5000),
      ];
      await cache.writeMetrics(MetricType.steps, preCachedSteps);

      // Client returns error
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = GoogleFitHealthRepository(mockOAuth, mockClient, cache);
      final steps = await repo.getStepsHistory();

      // Should fall back to cached data
      expect(steps.length, 1);
      expect(steps.first.value, 5000.0);
      expect(steps.first.timestamp, DateTime.parse('2026-06-18'));
    });
  });
}
