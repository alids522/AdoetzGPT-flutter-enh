import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

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
  OAuthLoopbackServer._(this._server, this._port);

  final HttpServer _server;
  final int _port;
  final Completer<OAuthLoopbackResult> _completer = Completer<OAuthLoopbackResult>();
  bool _stopped = false;

  int get port => _port;
  String redirectUri(String provider) =>
      'http://127.0.0.1:$_port/api/auth/oauth/$provider/callback';

  static Future<OAuthLoopbackServer?> start({int preferredPort = 3000}) async {
    HttpServer? server;
    final candidatePorts = [preferredPort, 3000, 8080, 8888, 0];

    for (final port in candidatePorts) {
      try {
        server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
        break;
      } catch (e) {
        debugPrint('Could not bind loopback server on port $port: $e');
      }
    }

    if (server == null) {
      debugPrint('Failed to start loopback server on any candidate port.');
      return null;
    }

    final loopback = OAuthLoopbackServer._(server, server.port);
    loopback._listen();
    return loopback;
  }

  void _listen() {
    _server.listen(
      (HttpRequest request) async {
        final uri = request.uri;
        final params = uri.queryParameters;
        final code = params['code'];
        final state = params['state'];
        final error = params['error'];
        final errorDesc = params['error_description'] ?? params['error_message'];

        // Determine if this is an OAuth callback or favicon / ping
        final isCallback = uri.path.contains('callback') ||
            params.containsKey('code') ||
            params.containsKey('error');

        if (!isCallback) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final isSuccess = code != null && code.isNotEmpty && error == null;

        final html = isSuccess
            ? _buildSuccessHtml()
            : _buildErrorHtml(errorDesc ?? error ?? 'Unknown OAuth error');

        request.response.statusCode = isSuccess ? HttpStatus.ok : HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.html;
        request.response.write(html);
        await request.response.close();

        if (!_completer.isCompleted) {
          _completer.complete(
            OAuthLoopbackResult(
              code: code,
              state: state,
              error: error,
              errorDescription: errorDesc,
              queryParameters: params,
            ),
          );
        }

        // Delay stopping slightly so response streams properly to the browser
        Future.delayed(const Duration(milliseconds: 1500), () {
          stop();
        });
      },
      onError: (err) {
        debugPrint('Loopback server request error: $err');
        if (!_completer.isCompleted) {
          _completer.complete(
            OAuthLoopbackResult(error: 'Loopback server error: $err'),
          );
        }
      },
    );
  }

  Future<OAuthLoopbackResult?> waitForResult({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    try {
      return await _completer.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('OAuth loopback server timed out waiting for authorization code.');
      await stop();
      return const OAuthLoopbackResult(error: 'Authentication timed out.');
    } catch (e) {
      return OAuthLoopbackResult(error: '$e');
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    try {
      await _server.close(force: true);
    } catch (e) {
      debugPrint('Error closing loopback server: $e');
    }
  }

  static String _buildSuccessHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AdoetzGPT Authentication</title>
  <style>
    body {
      background-color: #0f172a;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 16px;
      box-sizing: border-box;
    }
    .card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 20px;
      padding: 36px 28px;
      max-width: 400px;
      width: 100%;
      text-align: center;
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5);
    }
    .icon-wrap {
      width: 64px;
      height: 64px;
      background: rgba(16, 185, 129, 0.15);
      border: 2px solid rgba(16, 185, 129, 0.3);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
      color: #10b981;
      font-size: 32px;
      font-weight: bold;
    }
    h2 {
      margin: 0 0 10px;
      font-size: 22px;
      font-weight: 700;
      color: #f8fafc;
    }
    p {
      margin: 0 0 26px;
      font-size: 14px;
      line-height: 1.6;
      color: #94a3b8;
    }
    .btn {
      display: inline-block;
      background: #3b82f6;
      color: #ffffff;
      padding: 12px 24px;
      border-radius: 12px;
      text-decoration: none;
      font-size: 15px;
      font-weight: 600;
      box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.3);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-wrap">✓</div>
    <h2>Login Successful</h2>
    <p>Your OAuth authentication was verified. You can return to AdoetzGPT now.</p>
    <a href="adoetzgpt://oauth-callback" class="btn">Open AdoetzGPT</a>
  </div>
  <script>
    setTimeout(function() {
      window.location.href = 'adoetzgpt://oauth-callback';
    }, 600);
  </script>
</body>
</html>''';
  }

  static String _buildErrorHtml(String errorMessage) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AdoetzGPT Authentication</title>
  <style>
    body {
      background-color: #0f172a;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 16px;
      box-sizing: border-box;
    }
    .card {
      background: #1e293b;
      border: 1px solid #ef4444;
      border-radius: 20px;
      padding: 36px 28px;
      max-width: 400px;
      width: 100%;
      text-align: center;
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
    }
    .icon-wrap {
      width: 64px;
      height: 64px;
      background: rgba(239, 68, 68, 0.15);
      border: 2px solid rgba(239, 68, 68, 0.3);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
      color: #ef4444;
      font-size: 32px;
      font-weight: bold;
    }
    h2 {
      margin: 0 0 10px;
      font-size: 22px;
      font-weight: 700;
      color: #f8fafc;
    }
    p {
      margin: 0 0 26px;
      font-size: 14px;
      line-height: 1.6;
      color: #f87171;
      word-break: break-word;
    }
    .btn {
      display: inline-block;
      background: #475569;
      color: #ffffff;
      padding: 12px 24px;
      border-radius: 12px;
      text-decoration: none;
      font-size: 15px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-wrap">✕</div>
    <h2>Authentication Failed</h2>
    <p>${errorMessage.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</p>
    <a href="adoetzgpt://oauth-callback" class="btn">Return to App</a>
  </div>
</body>
</html>''';
  }
}
