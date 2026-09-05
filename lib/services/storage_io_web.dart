import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

Future<String?> readIoState(String appStateKey) async {
  try {
    // 1. Direct browser localStorage check (fastest and most durable on Web)
    final direct = web.window.localStorage.getItem(appStateKey);
    if (direct != null && direct.trim().isNotEmpty) return direct;

    final directFlutter = web.window.localStorage.getItem('flutter.$appStateKey');
    if (directFlutter != null && directFlutter.trim().isNotEmpty) return directFlutter;

    // 2. SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString(appStateKey);
    if (primary != null && primary.trim().isNotEmpty) return primary;
    final fallback = prefs.getString('$appStateKey.bak') ?? prefs.getString('appState');
    return (fallback != null && fallback.trim().isNotEmpty) ? fallback : '';
  } catch (_) {
    return '';
  }
}

Future<void> writeIoState(String appStateKey, String encoded) async {
  // 1. Direct browser localStorage write
  try {
    web.window.localStorage.setItem(appStateKey, encoded);
    web.window.localStorage.setItem('flutter.$appStateKey', encoded);
  } catch (_) {}

  // 2. SharedPreferences write
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appStateKey, encoded);
  } catch (_) {}
}

Future<void> writeIoAuth(String userKey, String userJson, String tokenKey, String token) async {
  try {
    web.window.localStorage.setItem(userKey, userJson);
    web.window.localStorage.setItem('flutter.$userKey', userJson);
    web.window.localStorage.setItem(tokenKey, token);
    web.window.localStorage.setItem('flutter.$tokenKey', token);
  } catch (_) {}

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, userJson);
    await prefs.setString(tokenKey, token);
  } catch (_) {}
}

Future<Map<String, String>?> readIoAuth(String userKey, String tokenKey) async {
  try {
    // 1. Direct browser localStorage
    var userJson = web.window.localStorage.getItem(userKey);
    userJson ??= web.window.localStorage.getItem('flutter.$userKey');
    var token = web.window.localStorage.getItem(tokenKey) ?? '';
    if (token.isEmpty) {
      token = web.window.localStorage.getItem('flutter.$tokenKey') ?? '';
    }

    if (userJson != null && userJson.trim().isNotEmpty) {
      return {'user': userJson.trim(), 'token': token.trim()};
    }

    // 2. SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefUser = prefs.getString(userKey);
    final prefToken = prefs.getString(tokenKey) ?? '';
    if (prefUser != null && prefUser.trim().isNotEmpty) {
      return {'user': prefUser.trim(), 'token': prefToken.trim()};
    }
  } catch (_) {}
  return null;
}

Future<void> clearIoAuth(String userKey, String tokenKey) async {
  try {
    web.window.localStorage.removeItem(userKey);
    web.window.localStorage.removeItem('flutter.$userKey');
    web.window.localStorage.removeItem(tokenKey);
    web.window.localStorage.removeItem('flutter.$tokenKey');
  } catch (_) {}

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
    await prefs.remove(tokenKey);
  } catch (_) {}
}
