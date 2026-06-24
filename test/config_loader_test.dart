import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/data/models/app_config.dart';

void main() {
  group('ConfigLoader Unit Tests', () {
    test('Loads valid config.json successfully', () {
      const jsonContent = '''
      {
        "client_id": "test_client.apps.googleusercontent.com",
        "client_secret": "test_secret",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token"
      }
      ''';
      final config = AppConfig.fromJson(jsonDecode(jsonContent) as Map<String, dynamic>);
      expect(config.clientId, 'test_client.apps.googleusercontent.com');
      expect(config.clientSecret, 'test_secret');
      expect(config.authUri, 'https://accounts.google.com/o/oauth2/auth');
      expect(config.tokenUri, 'https://oauth2.googleapis.com/token');
    });

    test('Throws FormatException when config is missing key fields', () {
      const jsonContent = '{"auth_uri": "https://accounts.google.com"}';
      expect(
        () => AppConfig.fromJson(jsonDecode(jsonContent) as Map<String, dynamic>),
        throwsA(isA<FormatException>()),
      );
    });

    test('Throws FormatException on invalid JSON syntax', () {
      const jsonContent = '{invalid_json_format}';
      expect(
        () => jsonDecode(jsonContent),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
