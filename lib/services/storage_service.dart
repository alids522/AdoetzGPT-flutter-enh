import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'storage_io.dart';

class StorageService {
  static const appStateKey = 'adoetzgpt.appState';
  static const authUserKey = 'adoetzgpt.auth_user';
  static const authTokenKey = 'adoetzgpt.auth_token';

  Future<PersistedAppState?> load() async {
    try {
      final raw = await readIoState(appStateKey);
      if (raw != null && raw.trim().isNotEmpty) {
        var parsed = PersistedAppState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw)),
        );
        if (parsed.currentUser == null) {
          final authMap = await readIoAuth(authUserKey, authTokenKey);
          if (authMap != null && authMap['user'] != null && authMap['user']!.isNotEmpty) {
            final user = UserAccount.fromJson(Map<String, dynamic>.from(jsonDecode(authMap['user']!)));
            parsed = parsed.copyWith(
              currentUser: user,
              authToken: authMap['token'] ?? parsed.authToken,
              userName: user.label,
            );
          }
        }
        return parsed;
      }
    } catch (e) {
      debugPrint('StorageService.load error: $e');
    }

    // Attempt dedicated auth recovery if root state was missing or failed to decode
    try {
      final authMap = await readIoAuth(authUserKey, authTokenKey);
      if (authMap != null && authMap['user'] != null && authMap['user']!.isNotEmpty) {
        final user = UserAccount.fromJson(Map<String, dynamic>.from(jsonDecode(authMap['user']!)));
        final savedToken = authMap['token'] ?? '';
        final defaults = PersistedAppState.defaults();
        return defaults.copyWith(
          currentUser: user,
          authToken: savedToken,
          userName: user.label,
        );
      }
    } catch (_) {}

    return null;
  }

  Future<void> save(PersistedAppState state) async {
    try {
      final encoded = _compactForStorage(state).encode();
      await writeIoState(appStateKey, encoded);

      // Save dedicated auth keys for quick recovery (works for both authenticated users and guests)
      if (state.currentUser != null) {
        await writeIoAuth(
          authUserKey,
          jsonEncode(state.currentUser!.toJson()),
          authTokenKey,
          state.authToken,
        );
      } else {
        await clearIoAuth(authUserKey, authTokenKey);
      }
    } catch (e) {
      debugPrint('StorageService.save error: $e');
    }
  }

  Future<void> clearAuth() async {
    try {
      await clearIoAuth(authUserKey, authTokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUser');
      await prefs.remove('authToken');
    } catch (_) {}
  }

  PersistedAppState _compactForStorage(PersistedAppState state) {
    final compactSessions = state.sessions.map((session) {
      final compactMessages = session.messages.map((message) {
        final attachments = message.attachments.map((attachment) {
          return AttachmentData(
            name: attachment.name,
            type: attachment.type,
            data: attachment.data.length <= 4000000 ? attachment.data : '',
            url: null,
          );
        }).toList();
        return message.copyWith(attachments: attachments);
      }).toList();
      return session.copyWith(messages: compactMessages);
    }).toList();

    return PersistedAppState(
      currentUser: state.currentUser,
      authToken: state.authToken,
      syncSettings: state.syncSettings,
      language: state.language,
      theme: state.theme,
      visualTheme: state.visualTheme,
      selectedModel: state.selectedModel,
      selectedTargetId: state.selectedTargetId,
      isThinkingMode: state.isThinkingMode,
      isArtifactMode: state.isArtifactMode,
      userName: state.userName,
      geminiApiKey: state.geminiApiKey,
      endpoints: state.endpoints,
      agentConnectors: state.agentConnectors,
      modelContextOverrides: state.modelContextOverrides,
      modelInputCosts: state.modelInputCosts,
      modelOutputCosts: state.modelOutputCosts,
      modelCacheHitCosts: state.modelCacheHitCosts,
      genSettings: state.genSettings,
      voiceSettings: state.voiceSettings,
      sessions: compactSessions,
      currentSessionId: state.currentSessionId,
      memories: state.memories,
      tokenUsageData: state.tokenUsageData.length > 500
          ? state.tokenUsageData.take(500).toList()
          : state.tokenUsageData,
      customCounters: state.customCounters,
      mcpServers: state.mcpServers,
      cronJobs: state.cronJobs,
      personas: state.personas,
      soundEffectsEnabled: state.soundEffectsEnabled,
      isLiveVideoEnabled: state.isLiveVideoEnabled,
      isLiveFrontCamera: state.isLiveFrontCamera,
      cachedPasswordHash: state.cachedPasswordHash,
      lastSyncAt: state.lastSyncAt,
      savedAt: state.savedAt,
    );
  }
}
