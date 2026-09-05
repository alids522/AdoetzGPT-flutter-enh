import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> readIoState(String appStateKey) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, 'adoetzgpt_state.json'));
  final tempFile = File(path.join(directory.path, 'adoetzgpt_state.json.tmp'));

  String raw = '';
  if (await file.exists()) {
    try {
      raw = await file.readAsString();
    } catch (_) {}
  }
  if (raw.isEmpty && await tempFile.exists()) {
    try {
      raw = await tempFile.readAsString();
    } catch (_) {}
  }
  if (raw.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    raw = prefs.getString(appStateKey) ?? prefs.getString('appState') ?? '';
  }
  return raw;
}

Future<void> writeIoState(String appStateKey, String encoded) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, 'adoetzgpt_state.json'));
  final tempFile = File(path.join(directory.path, 'adoetzgpt_state.json.tmp'));
  await tempFile.writeAsString(encoded, flush: true);
  if (await file.exists()) {
    await file.delete();
  }
  await tempFile.rename(file.path);
}

Future<void> writeIoAuth(String userKey, String userJson, String tokenKey, String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(userKey, userJson);
  await prefs.setString(tokenKey, token);
}

Future<Map<String, String>?> readIoAuth(String userKey, String tokenKey) async {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString(userKey);
  final token = prefs.getString(tokenKey) ?? '';
  if (userJson != null && userJson.isNotEmpty) {
    return {'user': userJson, 'token': token};
  }
  return null;
}

Future<void> clearIoAuth(String userKey, String tokenKey) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(userKey);
  await prefs.remove(tokenKey);
}
