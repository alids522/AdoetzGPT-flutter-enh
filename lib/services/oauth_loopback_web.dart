import 'dart:async';

class OAuthLoopbackResult {
  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;
  final Map<String, String> queryParameters;

  const OAuthLoopbackResult({
    this.code,
    this.state,
    this.error,
    this.errorDescription,
    this.queryParameters = const {},
  });

  bool get isSuccess => code != null && code!.isNotEmpty && error == null;
}

class OAuthLoopbackServer {
  OAuthLoopbackServer._();

  int get port => 3000;
  String get redirectUri => 'http://127.0.0.1:3000/api/auth/oauth/callback';

  static Future<OAuthLoopbackServer?> start({int preferredPort = 3000}) async {
    // Loopback HTTP server is not supported on web
    return null;
  }

  Future<OAuthLoopbackResult?> waitForResult({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    return null;
  }

  Future<void> stop() async {}
}
