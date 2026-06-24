class AppConfig {
  final String clientId;
  final String clientSecret;
  final String authUri;
  final String tokenUri;

  AppConfig({
    required this.clientId,
    required this.clientSecret,
    required this.authUri,
    required this.tokenUri,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    if (json['client_id'] == null || json['client_secret'] == null || json['auth_uri'] == null || json['token_uri'] == null) {
      throw const FormatException('Missing required fields');
    }
    return AppConfig(
      clientId: (json['client_id'] as String).trim(),
      clientSecret: (json['client_secret'] as String).trim(),
      authUri: (json['auth_uri'] as String).trim(),
      tokenUri: (json['token_uri'] as String).trim(),
    );
  }
}
