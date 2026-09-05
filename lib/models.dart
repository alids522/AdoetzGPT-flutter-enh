import 'dart:convert';

import 'package:uuid/uuid.dart';

const _idGenerator = Uuid();

enum AppView { chat, settings, tokenUsage }

enum AppLanguage { en, id }

AppLanguage normalizeLanguage(Object? value) {
  return value == 'en' || value == AppLanguage.en
      ? AppLanguage.en
      : AppLanguage.id;
}

String languageCode(AppLanguage language) =>
    language == AppLanguage.en ? 'en' : 'id';

String stringValue(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

int intValue(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double doubleValue(Object? value, [double fallback = 0.0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

List<Map<String, dynamic>> mapList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value).map(
    (key, item) => MapEntry(key, intValue(item)),
  )..removeWhere((key, item) => key.trim().isEmpty || item <= 0);
}

Map<String, double> _doubleMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value).map(
    (key, item) => MapEntry(key, doubleValue(item)),
  )..removeWhere((key, item) => key.trim().isEmpty || item < 0);
}

enum ChatTargetType { model, agentServer }

ChatTargetType chatTargetTypeFromJson(Object? value) {
  final text = stringValue(value, 'model').trim().toLowerCase();
  return text == 'agent_server' || text == 'agentserver'
      ? ChatTargetType.agentServer
      : ChatTargetType.model;
}

String chatTargetTypeCode(ChatTargetType value) =>
    value == ChatTargetType.agentServer ? 'agent_server' : 'model';

enum ConnectorStatus {
  online,
  offline,
  authFailed,
  timeout,
  unknown,
  streamingFailed,
  syncFailed,
}

ConnectorStatus connectorStatusFromJson(Object? value) {
  final text = stringValue(value, 'unknown').trim().toLowerCase();
  return switch (text) {
    'online' => ConnectorStatus.online,
    'offline' => ConnectorStatus.offline,
    'auth_failed' || 'authfailed' => ConnectorStatus.authFailed,
    'timeout' => ConnectorStatus.timeout,
    'streaming_failed' || 'streamingfailed' => ConnectorStatus.streamingFailed,
    'sync_failed' || 'syncfailed' => ConnectorStatus.syncFailed,
    _ => ConnectorStatus.unknown,
  };
}

String connectorStatusCode(ConnectorStatus value) => switch (value) {
  ConnectorStatus.online => 'online',
  ConnectorStatus.offline => 'offline',
  ConnectorStatus.authFailed => 'auth_failed',
  ConnectorStatus.timeout => 'timeout',
  ConnectorStatus.streamingFailed => 'streaming_failed',
  ConnectorStatus.syncFailed => 'sync_failed',
  ConnectorStatus.unknown => 'unknown',
};

String connectorStatusLabel(ConnectorStatus value) => switch (value) {
  ConnectorStatus.online => 'Online',
  ConnectorStatus.offline => 'Offline',
  ConnectorStatus.authFailed => 'Auth failed',
  ConnectorStatus.timeout => 'Timeout',
  ConnectorStatus.streamingFailed => 'Streaming failed',
  ConnectorStatus.syncFailed => 'Sync failed',
  ConnectorStatus.unknown => 'Unknown',
};

enum ConnectorType { openclawGateway, hermesAgent, genericOpenAiCompatible }

ConnectorType connectorTypeFromJson(Object? value) {
  final text = stringValue(
    value,
    'generic_openai_compatible',
  ).trim().toLowerCase();
  return switch (text) {
    'openclaw_gateway' || 'openclaw' => ConnectorType.openclawGateway,
    'hermes_agent' || 'hermes' => ConnectorType.hermesAgent,
    _ => ConnectorType.genericOpenAiCompatible,
  };
}

String connectorTypeCode(ConnectorType value) => switch (value) {
  ConnectorType.openclawGateway => 'openclaw_gateway',
  ConnectorType.hermesAgent => 'hermes_agent',
  ConnectorType.genericOpenAiCompatible => 'generic_openai_compatible',
};

String connectorTypeLabel(ConnectorType value) => switch (value) {
  ConnectorType.openclawGateway => 'OpenClaw',
  ConnectorType.hermesAgent => 'Hermes',
  ConnectorType.genericOpenAiCompatible => 'OpenAI Compatible',
};

enum ToolPermissionMode {
  toolsDisabled,
  safeAuto,
  askBeforeWrite,
  askBeforeEveryTool,
}

enum ThinkingEffort {
  auto,
  light,
  medium,
  high,
  xhigh,
}

ThinkingEffort thinkingEffortFromJson(Object? value) {
  final text = stringValue(value, 'auto').trim().toLowerCase();
  return switch (text) {
    'light' || 'low' => ThinkingEffort.light,
    'medium' || 'med' => ThinkingEffort.medium,
    'high' => ThinkingEffort.high,
    'xhigh' || 'extra_high' || 'max' => ThinkingEffort.xhigh,
    _ => ThinkingEffort.auto,
  };
}

String thinkingEffortCode(ThinkingEffort value) => switch (value) {
  ThinkingEffort.auto => 'auto',
  ThinkingEffort.light => 'light',
  ThinkingEffort.medium => 'medium',
  ThinkingEffort.high => 'high',
  ThinkingEffort.xhigh => 'xhigh',
};

String thinkingEffortLabel(ThinkingEffort value) => switch (value) {
  ThinkingEffort.auto => 'Auto Reasoning',
  ThinkingEffort.light => 'Light Thinking (~1k)',
  ThinkingEffort.medium => 'Medium Thinking (~4k)',
  ThinkingEffort.high => 'High Thinking (~16k)',
  ThinkingEffort.xhigh => 'Extra High Thinking (~32k)',
};

int thinkingBudgetTokens(ThinkingEffort value) => switch (value) {
  ThinkingEffort.auto => 0,
  ThinkingEffort.light => 1024,
  ThinkingEffort.medium => 4096,
  ThinkingEffort.high => 16384,
  ThinkingEffort.xhigh => 32768,
};

ToolPermissionMode toolPermissionModeFromJson(Object? value) {
  final text = stringValue(value, 'ask_before_write').trim().toLowerCase();
  return switch (text) {
    'tools_disabled' || 'disabled' => ToolPermissionMode.toolsDisabled,
    'safe_auto' || 'safe' => ToolPermissionMode.safeAuto,
    'ask_before_every_tool' ||
    'ask_every' => ToolPermissionMode.askBeforeEveryTool,
    _ => ToolPermissionMode.askBeforeWrite,
  };
}

String toolPermissionModeCode(ToolPermissionMode value) => switch (value) {
  ToolPermissionMode.toolsDisabled => 'tools_disabled',
  ToolPermissionMode.safeAuto => 'safe_auto',
  ToolPermissionMode.askBeforeWrite => 'ask_before_write',
  ToolPermissionMode.askBeforeEveryTool => 'ask_before_every_tool',
};

String toolPermissionModeLabel(ToolPermissionMode value) => switch (value) {
  ToolPermissionMode.toolsDisabled => 'Tools disabled',
  ToolPermissionMode.safeAuto => 'Safe auto',
  ToolPermissionMode.askBeforeWrite => 'Ask before write',
  ToolPermissionMode.askBeforeEveryTool => 'Ask before every tool',
};

class AttachmentData {
  const AttachmentData({
    required this.name,
    required this.type,
    required this.data,
    this.url,
  });

  final String name;
  final String type;
  final String data;
  final String? url;

  factory AttachmentData.fromJson(Map<String, dynamic> json) {
    return AttachmentData(
      name: stringValue(json['name']),
      type: stringValue(json['type']),
      data: stringValue(json['data']),
      url: json['url'] == null ? null : stringValue(json['url']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'data': data,
    if (url != null) 'url': url,
  };
}

class Message {
  const Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.model,
    this.attachments = const [],
    this.tokenCount,
    this.targetId,
    this.targetType,
    this.targetName,
    this.connectorId,
    this.modelOrAgentId,
    this.toolEventIds = const [],
    this.isEstimatedTokenCount = true,
    this.generationTimeMs,
  });

  final String id;
  final String text;
  final String sender;
  final String timestamp;
  final String? model;
  final List<AttachmentData> attachments;
  final int? tokenCount;
  final String? targetId;
  final ChatTargetType? targetType;
  final String? targetName;
  final String? connectorId;
  final String? modelOrAgentId;
  final List<String> toolEventIds;
  final bool isEstimatedTokenCount;
  final int? generationTimeMs;

  bool get isUser => sender == 'user';
  bool get isSystem => sender == 'system';

  Message copyWith({
    String? text,
    String? sender,
    String? timestamp,
    String? model,
    List<AttachmentData>? attachments,
    int? tokenCount,
    String? targetId,
    ChatTargetType? targetType,
    String? targetName,
    String? connectorId,
    String? modelOrAgentId,
    List<String>? toolEventIds,
    bool? isEstimatedTokenCount,
    int? generationTimeMs,
    bool clearModel = false,
    bool clearTokenCount = false,
    bool clearTarget = false,
  }) {
    return Message(
      id: id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      model: clearModel ? null : model ?? this.model,
      attachments: attachments ?? this.attachments,
      tokenCount: clearTokenCount ? null : tokenCount ?? this.tokenCount,
      targetId: clearTarget ? null : targetId ?? this.targetId,
      targetType: clearTarget ? null : targetType ?? this.targetType,
      targetName: clearTarget ? null : targetName ?? this.targetName,
      connectorId: clearTarget ? null : connectorId ?? this.connectorId,
      modelOrAgentId: clearTarget
          ? null
          : modelOrAgentId ?? this.modelOrAgentId,
      toolEventIds: clearTarget ? const [] : toolEventIds ?? this.toolEventIds,
      isEstimatedTokenCount: isEstimatedTokenCount ?? this.isEstimatedTokenCount,
      generationTimeMs: generationTimeMs ?? this.generationTimeMs,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: stringValue(json['id']),
      text: stringValue(json['text']),
      sender: stringValue(json['sender'], 'bot'),
      timestamp: stringValue(json['timestamp']),
      model: json['model'] == null ? null : stringValue(json['model']),
      attachments: mapList(
        json['attachments'],
      ).map(AttachmentData.fromJson).toList(),
      tokenCount: json['tokenCount'] == null
          ? null
          : intValue(json['tokenCount']),
      targetId: json['target_id'] == null && json['targetId'] == null
          ? null
          : stringValue(json['target_id'], stringValue(json['targetId'])),
      targetType: json['target_type'] == null && json['targetType'] == null
          ? null
          : chatTargetTypeFromJson(json['target_type'] ?? json['targetType']),
      targetName: json['target_name'] == null && json['targetName'] == null
          ? null
          : stringValue(json['target_name'], stringValue(json['targetName'])),
      connectorId: json['connector_id'] == null && json['connectorId'] == null
          ? null
          : stringValue(json['connector_id'], stringValue(json['connectorId'])),
      modelOrAgentId:
          json['model_or_agent_id'] == null && json['modelOrAgentId'] == null
          ? null
          : stringValue(
              json['model_or_agent_id'],
              stringValue(json['modelOrAgentId']),
            ),
      toolEventIds: (json['tool_event_ids'] is List)
          ? (json['tool_event_ids'] as List)
                .map((item) => item.toString())
                .toList()
          : (json['toolEventIds'] is List)
          ? (json['toolEventIds'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
      isEstimatedTokenCount: json.containsKey('isEstimatedTokenCount') 
          ? json['isEstimatedTokenCount'] == true 
          : true,
      generationTimeMs: json['generationTimeMs'] != null ? intValue(json['generationTimeMs']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'sender': sender,
    'timestamp': timestamp,
    if (model != null) 'model': model,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((item) => item.toJson()).toList(),
    if (tokenCount != null) 'tokenCount': tokenCount,
    if (targetId != null) 'target_id': targetId,
    if (targetType != null) 'target_type': chatTargetTypeCode(targetType!),
    if (targetName != null) 'target_name': targetName,
    if (connectorId != null) 'connector_id': connectorId,
    if (modelOrAgentId != null) 'model_or_agent_id': modelOrAgentId,
    if (toolEventIds.isNotEmpty) 'tool_event_ids': toolEventIds,
    'isEstimatedTokenCount': isEstimatedTokenCount,
    if (generationTimeMs != null) 'generationTimeMs': generationTimeMs,
  };
}

class Session {
  const Session({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.deleted = false,
    this.currentTargetId = '',
    this.startedWithTargetId = '',
    this.lastTargetId = '',
    this.targetHistory = const [],
    this.handoffSummary = '',
    this.targetSwitchEvents = const [],
    this.compactionSummary,
  });

  final String id;
  final String title;
  final List<Message> messages;
  final int createdAt;
  final int updatedAt;
  final bool pinned;
  final bool deleted;
  final String currentTargetId;
  final String startedWithTargetId;
  final String lastTargetId;
  final List<String> targetHistory;
  final String handoffSummary;
  final List<TargetSwitchEvent> targetSwitchEvents;
  final ConversationSummaryCompaction? compactionSummary;

  Session copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    int? createdAt,
    int? updatedAt,
    bool? pinned,
    bool? deleted,
    String? currentTargetId,
    String? startedWithTargetId,
    String? lastTargetId,
    List<String>? targetHistory,
    String? handoffSummary,
    List<TargetSwitchEvent>? targetSwitchEvents,
    ConversationSummaryCompaction? compactionSummary,
    bool clearCompaction = false,
  }) {
    return Session(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      deleted: deleted ?? this.deleted,
      currentTargetId: currentTargetId ?? this.currentTargetId,
      startedWithTargetId: startedWithTargetId ?? this.startedWithTargetId,
      lastTargetId: lastTargetId ?? this.lastTargetId,
      targetHistory: targetHistory ?? this.targetHistory,
      handoffSummary: handoffSummary ?? this.handoffSummary,
      targetSwitchEvents: targetSwitchEvents ?? this.targetSwitchEvents,
      compactionSummary: clearCompaction
          ? null
          : (compactionSummary ?? this.compactionSummary),
    );
  }

  factory Session.empty([String? id, String? targetId]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final effectiveTargetId = targetId ?? '';
    return Session(
      id: id ?? 'session-${_idGenerator.v4()}',
      title: effectiveTargetId.startsWith('agent:')
          ? 'New Agent Chat'
          : 'New Chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
      currentTargetId: effectiveTargetId,
      startedWithTargetId: effectiveTargetId,
      lastTargetId: effectiveTargetId,
      targetHistory: effectiveTargetId.isEmpty ? const [] : [effectiveTargetId],
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    final updatedAt = intValue(
      json['updatedAt'],
      DateTime.now().millisecondsSinceEpoch,
    );
    final currentTargetId = stringValue(
      json['current_target_id'],
      stringValue(json['currentTargetId']),
    );
    final startedWithTargetId = stringValue(
      json['started_with_target_id'],
      stringValue(json['startedWithTargetId'], currentTargetId),
    );
    final lastTargetId = stringValue(
      json['last_target_id'],
      stringValue(json['lastTargetId'], currentTargetId),
    );
    final targetHistory = (json['target_history'] is List)
        ? (json['target_history'] as List)
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList()
        : (json['targetHistory'] is List)
        ? (json['targetHistory'] as List)
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    return Session(
      id: stringValue(json['id']),
      title: stringValue(json['title'], 'New Chat'),
      messages: mapList(json['messages']).map(Message.fromJson).toList(),
      createdAt: intValue(
        json['createdAt'],
        intValue(json['created_at'], updatedAt),
      ),
      updatedAt: updatedAt,
      pinned: boolValue(json['pinned']),
      deleted: boolValue(json['deleted']),
      currentTargetId: currentTargetId,
      startedWithTargetId: startedWithTargetId,
      lastTargetId: lastTargetId,
      targetHistory: targetHistory,
      handoffSummary: stringValue(
        json['handoff_summary'],
        stringValue(json['handoffSummary']),
      ),
      targetSwitchEvents: mapList(
        json['target_switch_events'] ?? json['targetSwitchEvents'],
      ).map(TargetSwitchEvent.fromJson).toList(),
      compactionSummary: json['compactionSummary'] is Map
          ? ConversationSummaryCompaction.fromJson(
              Map<String, dynamic>.from(json['compactionSummary']),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((item) => item.toJson()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (pinned) 'pinned': pinned,
    if (deleted) 'deleted': deleted,
    if (currentTargetId.isNotEmpty) 'current_target_id': currentTargetId,
    if (startedWithTargetId.isNotEmpty)
      'started_with_target_id': startedWithTargetId,
    if (lastTargetId.isNotEmpty) 'last_target_id': lastTargetId,
    if (targetHistory.isNotEmpty) 'target_history': targetHistory,
    if (handoffSummary.isNotEmpty) 'handoff_summary': handoffSummary,
    if (compactionSummary != null)
      'compactionSummary': compactionSummary!.toJson(),
    if (targetSwitchEvents.isNotEmpty)
      'target_switch_events': targetSwitchEvents
          .map((event) => event.toJson())
          .toList(),
  };
}

class EndpointConfig {
  const EndpointConfig({
    required this.id,
    required this.url,
    required this.key,
    required this.name,
    this.skipModelFetch = false,
    this.models = const [],
    this.enabled = true,
  });

  final String id;
  final String url;
  final String key;
  final String name;
  final bool skipModelFetch;
  final List<String> models;
  final bool enabled;

  EndpointConfig copyWith({
    String? id,
    String? url,
    String? key,
    String? name,
    bool? skipModelFetch,
    List<String>? models,
    bool? enabled,
  }) {
    return EndpointConfig(
      id: id ?? this.id,
      url: url ?? this.url,
      key: key ?? this.key,
      name: name ?? this.name,
      skipModelFetch: skipModelFetch ?? this.skipModelFetch,
      models: models ?? this.models,
      enabled: enabled ?? this.enabled,
    );
  }

  factory EndpointConfig.fromJson(Map<String, dynamic> json) {
    return EndpointConfig(
      id: stringValue(json['id']),
      url: stringValue(json['url']),
      key: stringValue(json['key']),
      name: stringValue(json['name'], 'Endpoint'),
      skipModelFetch: boolValue(json['skipModelFetch']),
      models: (json['models'] is List)
          ? (json['models'] as List).map((item) => item.toString()).toList()
          : const [],
      enabled: json['enabled'] == null ? true : boolValue(json['enabled']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'key': key,
    'name': name,
    'skipModelFetch': skipModelFetch,
    'models': models,
    'enabled': enabled,
  };
}

class EndpointModel {
  const EndpointModel({required this.name, required this.endpointId});

  final String name;
  final String endpointId;
}

class ConnectorCapabilities {
  const ConnectorCapabilities({
    this.supportsStreaming = true,
    this.supportsChatCompletions = true,
    this.supportsResponsesApi = false,
    this.supportsModelsEndpoint = true,
    this.supportsTools = false,
    this.rawCapabilitiesJson = const {},
  });

  final bool supportsStreaming;
  final bool supportsChatCompletions;
  final bool supportsResponsesApi;
  final bool supportsModelsEndpoint;
  final bool supportsTools;
  final Map<String, dynamic> rawCapabilitiesJson;

  ConnectorCapabilities copyWith({
    bool? supportsStreaming,
    bool? supportsChatCompletions,
    bool? supportsResponsesApi,
    bool? supportsModelsEndpoint,
    bool? supportsTools,
    Map<String, dynamic>? rawCapabilitiesJson,
  }) {
    return ConnectorCapabilities(
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsChatCompletions:
          supportsChatCompletions ?? this.supportsChatCompletions,
      supportsResponsesApi: supportsResponsesApi ?? this.supportsResponsesApi,
      supportsModelsEndpoint:
          supportsModelsEndpoint ?? this.supportsModelsEndpoint,
      supportsTools: supportsTools ?? this.supportsTools,
      rawCapabilitiesJson: rawCapabilitiesJson ?? this.rawCapabilitiesJson,
    );
  }

  factory ConnectorCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ConnectorCapabilities();
    return ConnectorCapabilities(
      supportsStreaming: boolValue(json['supports_streaming'], true),
      supportsChatCompletions: boolValue(
        json['supports_chat_completions'],
        true,
      ),
      supportsResponsesApi: boolValue(json['supports_responses_api']),
      supportsModelsEndpoint: boolValue(json['supports_models_endpoint'], true),
      supportsTools: boolValue(json['supports_tools']),
      rawCapabilitiesJson: json['raw_capabilities_json'] is Map
          ? Map<String, dynamic>.from(json['raw_capabilities_json'])
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'supports_streaming': supportsStreaming,
    'supports_chat_completions': supportsChatCompletions,
    'supports_responses_api': supportsResponsesApi,
    'supports_models_endpoint': supportsModelsEndpoint,
    'supports_tools': supportsTools,
    'raw_capabilities_json': rawCapabilitiesJson,
  };
}

class ConnectorTarget {
  const ConnectorTarget({
    required this.id,
    required this.connectorId,
    required this.modelId,
    required this.displayName,
    this.contextLength,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String connectorId;
  final String modelId;
  final String displayName;
  final int? contextLength;
  final bool enabled;
  final int createdAt;
  final int updatedAt;

  ConnectorTarget copyWith({
    String? id,
    String? connectorId,
    String? modelId,
    String? displayName,
    int? contextLength,
    bool? enabled,
    int? createdAt,
    int? updatedAt,
  }) {
    return ConnectorTarget(
      id: id ?? this.id,
      connectorId: connectorId ?? this.connectorId,
      modelId: modelId ?? this.modelId,
      displayName: displayName ?? this.displayName,
      contextLength: contextLength ?? this.contextLength,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ConnectorTarget.fromJson(Map<String, dynamic> json) {
    final modelId = stringValue(json['model_id'], stringValue(json['modelId']));
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawContextLength = json['context_length'] ?? json['contextLength'];
    final parsedContextLength = intValue(rawContextLength);
    return ConnectorTarget(
      id: stringValue(
        json['id'],
        '${stringValue(json['connector_id'], stringValue(json['connectorId']))}:$modelId',
      ),
      connectorId: stringValue(
        json['connector_id'],
        stringValue(json['connectorId']),
      ),
      modelId: modelId,
      displayName: stringValue(
        json['display_name'],
        stringValue(json['displayName'], modelId),
      ),
      contextLength: parsedContextLength > 0 ? parsedContextLength : null,
      enabled: boolValue(json['enabled'], true),
      createdAt: intValue(json['created_at'], intValue(json['createdAt'], now)),
      updatedAt: intValue(json['updated_at'], intValue(json['updatedAt'], now)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'connector_id': connectorId,
    'model_id': modelId,
    'display_name': displayName,
    if (contextLength != null) 'context_length': contextLength,
    'enabled': enabled,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class AgentConnector {
  const AgentConnector({
    required this.id,
    this.userId = '',
    required this.name,
    this.type = ConnectorType.genericOpenAiCompatible,
    this.baseUrl = '',
    this.encryptedApiKey = '',
    this.enabled = true,
    this.status = ConnectorStatus.unknown,
    this.latencyMs,
    this.lastCheckedAt,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.permissionMode = ToolPermissionMode.askBeforeWrite,
    this.capabilities = const ConnectorCapabilities(),
    this.targets = const [],
    this.lastError = '',
    this.logs = const [],
  });

  final String id;
  final String userId;
  final String name;
  final ConnectorType type;
  final String baseUrl;
  final String encryptedApiKey;
  final bool enabled;
  final ConnectorStatus status;
  final int? latencyMs;
  final int? lastCheckedAt;
  final bool isDefault;
  final int createdAt;
  final int updatedAt;
  final ToolPermissionMode permissionMode;
  final ConnectorCapabilities capabilities;
  final List<ConnectorTarget> targets;
  final String lastError;
  final List<String> logs;

  String get providerLabel => connectorTypeLabel(type);

  AgentConnector copyWith({
    String? id,
    String? userId,
    String? name,
    ConnectorType? type,
    String? baseUrl,
    String? encryptedApiKey,
    bool? enabled,
    ConnectorStatus? status,
    int? latencyMs,
    int? lastCheckedAt,
    bool? isDefault,
    int? createdAt,
    int? updatedAt,
    ToolPermissionMode? permissionMode,
    ConnectorCapabilities? capabilities,
    List<ConnectorTarget>? targets,
    String? lastError,
    List<String>? logs,
    bool clearLatency = false,
    bool clearLastCheckedAt = false,
  }) {
    return AgentConnector(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      encryptedApiKey: encryptedApiKey ?? this.encryptedApiKey,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      latencyMs: clearLatency ? null : latencyMs ?? this.latencyMs,
      lastCheckedAt: clearLastCheckedAt
          ? null
          : lastCheckedAt ?? this.lastCheckedAt,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      permissionMode: permissionMode ?? this.permissionMode,
      capabilities: capabilities ?? this.capabilities,
      targets: targets ?? this.targets,
      lastError: lastError ?? this.lastError,
      logs: logs ?? this.logs,
    );
  }

  factory AgentConnector.empty({String? id}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final connectorId = id ?? now.toString();
    return AgentConnector(
      id: connectorId,
      name: 'New Agent Server',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AgentConnector.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = stringValue(json['id']);
    return AgentConnector(
      id: id,
      userId: stringValue(json['user_id'], stringValue(json['userId'])),
      name: stringValue(json['name'], 'Agent Server'),
      type: connectorTypeFromJson(json['type']),
      baseUrl: stringValue(json['base_url'], stringValue(json['baseUrl'])),
      encryptedApiKey: stringValue(
        json['encrypted_api_key'],
        stringValue(json['encryptedApiKey'], stringValue(json['apiKey'])),
      ),
      enabled: boolValue(json['enabled'], true),
      status: connectorStatusFromJson(json['status']),
      latencyMs: json['latency_ms'] == null && json['latencyMs'] == null
          ? null
          : intValue(json['latency_ms'], intValue(json['latencyMs'])),
      lastCheckedAt:
          json['last_checked_at'] == null && json['lastCheckedAt'] == null
          ? null
          : intValue(json['last_checked_at'], intValue(json['lastCheckedAt'])),
      isDefault: boolValue(json['is_default'], boolValue(json['isDefault'])),
      createdAt: intValue(json['created_at'], intValue(json['createdAt'], now)),
      updatedAt: intValue(json['updated_at'], intValue(json['updatedAt'], now)),
      permissionMode: toolPermissionModeFromJson(json['permission_mode']),
      capabilities: ConnectorCapabilities.fromJson(
        json['capabilities'] is Map
            ? Map<String, dynamic>.from(json['capabilities'])
            : null,
      ),
      targets: mapList(json['targets'])
          .map(ConnectorTarget.fromJson)
          .map(
            (target) => target.connectorId.isEmpty
                ? target.copyWith(connectorId: id)
                : target,
          )
          .toList(),
      lastError: stringValue(
        json['last_error'],
        stringValue(json['lastError']),
      ),
      logs: (json['logs'] is List)
          ? (json['logs'] as List).map((item) => item.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'type': connectorTypeCode(type),
    'base_url': baseUrl,
    'encrypted_api_key': includeSecrets ? encryptedApiKey : '',
    'enabled': enabled,
    'status': connectorStatusCode(status),
    if (latencyMs != null) 'latency_ms': latencyMs,
    if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
    'is_default': isDefault,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'permission_mode': toolPermissionModeCode(permissionMode),
    'capabilities': capabilities.toJson(),
    'targets': targets.map((target) => target.toJson()).toList(),
    if (lastError.isNotEmpty) 'last_error': lastError,
    if (logs.isNotEmpty) 'logs': logs,
  };
}

class ChatTarget {
  const ChatTarget({
    required this.id,
    required this.type,
    required this.displayName,
    required this.provider,
    this.connectorId,
    this.modelId,
    this.contextLength,
    this.status = ConnectorStatus.online,
    this.capabilities = const ConnectorCapabilities(),
    this.isDefault = false,
  });

  final String id;
  final ChatTargetType type;
  final String displayName;
  final String provider;
  final String? connectorId;
  final String? modelId;
  final int? contextLength;
  final ConnectorStatus status;
  final ConnectorCapabilities capabilities;
  final bool isDefault;

  bool get isModel => type == ChatTargetType.model;
  bool get isAgentServer => type == ChatTargetType.agentServer;

  factory ChatTarget.model(String model, {String provider = 'Model'}) {
    return ChatTarget(
      id: 'model:$model',
      type: ChatTargetType.model,
      displayName: model,
      provider: provider,
      modelId: model,
    );
  }

  factory ChatTarget.agent({
    required AgentConnector connector,
    ConnectorTarget? target,
  }) {
    final enabledTargets = connector.targets
        .where((item) => item.enabled)
        .toList();
    final selectedTarget =
        target ?? (enabledTargets.isEmpty ? null : enabledTargets.first);
    final modelId =
        selectedTarget?.modelId ??
        connector.name.toLowerCase().replaceAll(' ', '-');
    return ChatTarget(
      id: 'agent:${connector.id}',
      type: ChatTargetType.agentServer,
      displayName: connector.name,
      provider: connector.providerLabel,
      connectorId: connector.id,
      modelId: modelId,
      contextLength: selectedTarget?.contextLength,
      status: connector.status,
      capabilities: connector.capabilities,
      isDefault: connector.isDefault,
    );
  }
}

class TargetSwitchEvent {
  const TargetSwitchEvent({
    required this.id,
    required this.chatId,
    required this.fromTargetId,
    required this.toTargetId,
    required this.handoffSummary,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String fromTargetId;
  final String toTargetId;
  final String handoffSummary;
  final int createdAt;

  factory TargetSwitchEvent.fromJson(Map<String, dynamic> json) {
    return TargetSwitchEvent(
      id: stringValue(json['id']),
      chatId: stringValue(json['chat_id'], stringValue(json['chatId'])),
      fromTargetId: stringValue(
        json['from_target_id'],
        stringValue(json['fromTargetId']),
      ),
      toTargetId: stringValue(
        json['to_target_id'],
        stringValue(json['toTargetId']),
      ),
      handoffSummary: stringValue(
        json['handoff_summary'],
        stringValue(json['handoffSummary']),
      ),
      createdAt: intValue(json['created_at'], intValue(json['createdAt'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chat_id': chatId,
    'from_target_id': fromTargetId,
    'to_target_id': toTargetId,
    'handoff_summary': handoffSummary,
    'created_at': createdAt,
  };
}

class GenerationSettings {
  const GenerationSettings({
    this.memoryEnabled = true,
    this.webSearchMode = 'auto',
    this.webSearchEngine = 'gemini',
    this.webSearchProvider = 'gemini',
    this.webSearchModel = 'gemini-flash-lite-latest',
    this.webSearchEndpointId = '',
    this.antigravityEndpointId = '',
    this.antigravityModel = '',
    this.googleSearchApiKey = '',
    this.googleSearchCx = '',
    this.tavilyApiKey = '',
    this.mistralApiKey = '',
    this.mistralAgentId = '',
    this.hapticStreamingEnabled = false,
    this.titleModelEnabled = true,
    this.titleModel = '',
    this.voiceModel = 'gemini-2.0-flash-exp',
    this.liveModeEnabled = true,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.maxOutputTokens = 8192,
    this.contextLimit = 128000,
    this.thinkingEffort = ThinkingEffort.auto,
  });

  final bool memoryEnabled;
  final String webSearchMode;
  final String webSearchEngine;
  final String webSearchProvider;
  final String webSearchModel;
  final String webSearchEndpointId;
  final String antigravityEndpointId;
  final String antigravityModel;
  final String googleSearchApiKey;
  final String googleSearchCx;
  final String tavilyApiKey;
  final String mistralApiKey;
  final String mistralAgentId;
  final bool hapticStreamingEnabled;
  final bool titleModelEnabled;
  final String titleModel;
  final String voiceModel;
  final bool liveModeEnabled;
  final double temperature;
  final double topP;
  final int topK;
  final int maxOutputTokens;
  final int contextLimit;
  final ThinkingEffort thinkingEffort;

  GenerationSettings copyWith({
    bool? memoryEnabled,
    String? webSearchMode,
    String? webSearchEngine,
    String? webSearchProvider,
    String? webSearchModel,
    String? webSearchEndpointId,
    String? antigravityEndpointId,
    String? antigravityModel,
    String? googleSearchApiKey,
    String? googleSearchCx,
    String? tavilyApiKey,
    String? mistralApiKey,
    String? mistralAgentId,
    bool? hapticStreamingEnabled,
    bool? titleModelEnabled,
    String? titleModel,
    String? voiceModel,
    bool? liveModeEnabled,
    double? temperature,
    double? topP,
    int? topK,
    int? maxOutputTokens,
    int? contextLimit,
    ThinkingEffort? thinkingEffort,
  }) {
    final nextEngine = webSearchEngine ?? this.webSearchEngine;
    return GenerationSettings(
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      webSearchMode: webSearchMode ?? this.webSearchMode,
      webSearchEngine: nextEngine,
      webSearchProvider:
          webSearchProvider ??
          (nextEngine == 'endpoint'
              ? 'endpoint'
              : (nextEngine == 'antigravity' ? 'antigravity' : 'gemini')),
      webSearchModel: webSearchModel ?? this.webSearchModel,
      webSearchEndpointId: webSearchEndpointId ?? this.webSearchEndpointId,
      antigravityEndpointId:
          antigravityEndpointId ?? this.antigravityEndpointId,
      antigravityModel: antigravityModel ?? this.antigravityModel,
      googleSearchApiKey: googleSearchApiKey ?? this.googleSearchApiKey,
      googleSearchCx: googleSearchCx ?? this.googleSearchCx,
      tavilyApiKey: tavilyApiKey ?? this.tavilyApiKey,
      mistralApiKey: mistralApiKey ?? this.mistralApiKey,
      mistralAgentId: mistralAgentId ?? this.mistralAgentId,
      hapticStreamingEnabled:
          hapticStreamingEnabled ?? this.hapticStreamingEnabled,
      titleModelEnabled: titleModelEnabled ?? this.titleModelEnabled,
      titleModel: titleModel ?? this.titleModel,
      voiceModel: voiceModel ?? this.voiceModel,
      liveModeEnabled: liveModeEnabled ?? this.liveModeEnabled,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      contextLimit: contextLimit ?? this.contextLimit,
      thinkingEffort: thinkingEffort ?? this.thinkingEffort,
    );
  }

  factory GenerationSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GenerationSettings();
    final engine = stringValue(
      json['webSearchEngine'],
      json['webSearchProvider'] == 'endpoint' ? 'endpoint' : 'gemini',
    );
    return GenerationSettings(
      memoryEnabled: json.containsKey('memoryEnabled')
          ? boolValue(json['memoryEnabled'])
          : true,
      webSearchMode: stringValue(json['webSearchMode'], 'auto'),
      webSearchEngine: engine,
      webSearchProvider: engine == 'endpoint'
          ? 'endpoint'
          : (engine == 'antigravity' ? 'antigravity' : 'gemini'),
      webSearchModel: stringValue(
        json['webSearchModel'],
        'gemini-flash-lite-latest',
      ),
      webSearchEndpointId: stringValue(json['webSearchEndpointId']),
      antigravityEndpointId: stringValue(json['antigravityEndpointId']),
      antigravityModel: stringValue(json['antigravityModel']),
      googleSearchApiKey: stringValue(json['googleSearchApiKey']),
      googleSearchCx: stringValue(json['googleSearchCx']),
      tavilyApiKey: stringValue(json['tavilyApiKey']),
      mistralApiKey: stringValue(json['mistralApiKey']),
      mistralAgentId: stringValue(json['mistralAgentId']),
      hapticStreamingEnabled: boolValue(json['hapticStreamingEnabled']),
      titleModelEnabled: json['titleModelEnabled'] ?? true,
      titleModel: stringValue(json['titleModel']),
      voiceModel: stringValue(json['voiceModel'], 'gemini-2.0-flash-exp'),
      liveModeEnabled: json['liveModeEnabled'] ?? true,
      temperature: doubleValue(json['temperature'], 0.7),
      topP: doubleValue(json['topP'], 0.9),
      topK: intValue(json['topK'], 40),
      maxOutputTokens: intValue(json['maxOutputTokens'], 8192),
      contextLimit: intValue(json['contextLimit'], 128000),
      thinkingEffort: thinkingEffortFromJson(json['thinkingEffort']),
    );
  }

  Map<String, dynamic> toJson() => {
    'memoryEnabled': memoryEnabled,
    'webSearchMode': webSearchMode,
    'webSearchEngine': webSearchEngine,
    'webSearchProvider': webSearchProvider,
    'webSearchModel': webSearchModel,
    'webSearchEndpointId': webSearchEndpointId,
    'antigravityEndpointId': antigravityEndpointId,
    'antigravityModel': antigravityModel,
    'googleSearchApiKey': googleSearchApiKey,
    'googleSearchCx': googleSearchCx,
    'tavilyApiKey': tavilyApiKey,
    'mistralApiKey': mistralApiKey,
    'mistralAgentId': mistralAgentId,
    'hapticStreamingEnabled': hapticStreamingEnabled,
    'titleModelEnabled': titleModelEnabled,
    'titleModel': titleModel,
    'voiceModel': voiceModel,
    'liveModeEnabled': liveModeEnabled,
    'temperature': temperature,
    'topP': topP,
    'topK': topK,
    'maxOutputTokens': maxOutputTokens,
    'contextLimit': contextLimit,
    'thinkingEffort': thinkingEffortCode(thinkingEffort),
  };
}

class CustomPersonality {
  const CustomPersonality({
    required this.id,
    required this.name,
    required this.prompt,
  });

  final String id;
  final String name;
  final String prompt;

  factory CustomPersonality.fromJson(Map<String, dynamic> json) {
    return CustomPersonality(
      id: stringValue(json['id']),
      name: stringValue(json['name']),
      prompt: stringValue(json['prompt']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'prompt': prompt};
}

class VoiceSettings {
  const VoiceSettings({
    this.voice = 'Zephyr',
    this.personality = 'Assistant',
    this.customPersonality = '',
    this.textPersonality = 'Assistant',
    this.customTextPersonality = '',
    this.customVoicePersonalities = const [],
    this.liveModel = '',
    this.customTextPersonalities = const [],
  });

  final String voice;
  final String personality;
  final String customPersonality;
  final String textPersonality;
  final String customTextPersonality;
  final List<CustomPersonality> customVoicePersonalities;
  final List<CustomPersonality> customTextPersonalities;
  final String liveModel;

  VoiceSettings copyWith({
    String? voice,
    String? personality,
    String? customPersonality,
    String? textPersonality,
    String? customTextPersonality,
    List<CustomPersonality>? customVoicePersonalities,
    List<CustomPersonality>? customTextPersonalities,
    String? liveModel,
  }) {
    return VoiceSettings(
      voice: voice ?? this.voice,
      personality: personality ?? this.personality,
      customPersonality: customPersonality ?? this.customPersonality,
      textPersonality: textPersonality ?? this.textPersonality,
      customTextPersonality:
          customTextPersonality ?? this.customTextPersonality,
      customVoicePersonalities:
          customVoicePersonalities ?? this.customVoicePersonalities,
      customTextPersonalities:
          customTextPersonalities ?? this.customTextPersonalities,
      liveModel: liveModel ?? this.liveModel,
    );
  }

  factory VoiceSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VoiceSettings();
    return VoiceSettings(
      voice: stringValue(json['voice'], 'Zephyr'),
      personality: stringValue(json['personality'], 'Assistant'),
      customPersonality: stringValue(json['customPersonality']),
      textPersonality: stringValue(json['textPersonality'], 'Assistant'),
      customTextPersonality: stringValue(json['customTextPersonality']),
      customVoicePersonalities: mapList(
        json['customVoicePersonalities'],
      ).map(CustomPersonality.fromJson).toList(),
      customTextPersonalities: mapList(
        json['customTextPersonalities'],
      ).map(CustomPersonality.fromJson).toList(),
      liveModel: stringValue(json['liveModel']),
    );
  }

  Map<String, dynamic> toJson() => {
    'voice': voice,
    'personality': personality,
    'customPersonality': customPersonality,
    'textPersonality': textPersonality,
    'customTextPersonality': customTextPersonality,
    'customVoicePersonalities': customVoicePersonalities
        .map((item) => item.toJson())
        .toList(),
    'customTextPersonalities': customTextPersonalities
        .map((item) => item.toJson())
        .toList(),
    'liveModel': liveModel,
  };
}

class Memory {
  const Memory({
    required this.id,
    required this.content,
    required this.timestamp,
    this.updatedAt,
    this.deletedAt,
    this.key = '',
    this.type = 'preference',
    this.scope = 'global',
    this.sensitivity = 'low',
  });

  final String id;
  final String content;
  final int timestamp;
  final int? updatedAt;
  final int? deletedAt;
  final String key;
  final String type;
  final String scope;
  final String sensitivity;

  Memory copyWith({
    String? content,
    int? timestamp,
    int? updatedAt,
    int? deletedAt,
    String? key,
    String? type,
    String? scope,
    String? sensitivity,
    bool clearDeletedAt = false,
  }) => Memory(
    id: id,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    key: key ?? this.key,
    type: type ?? this.type,
    scope: scope ?? this.scope,
    sensitivity: sensitivity ?? this.sensitivity,
  );

  factory Memory.fromJson(Map<String, dynamic> json) {
    final content = stringValue(json['content']);
    final timestamp = intValue(json['timestamp']);
    final rawKey = stringValue(json['key']);
    final canonicalKey = MemoryCanonicalKeys.normalize(
      rawKey.isNotEmpty ? rawKey : MemoryCanonicalKeys.inferFromContent(content),
    );
    return Memory(
      id: stringValue(json['id']),
      content: content,
      timestamp: timestamp,
      updatedAt: json['updatedAt'] != null ? intValue(json['updatedAt']) : timestamp,
      deletedAt: json['deletedAt'] != null ? intValue(json['deletedAt']) : null,
      key: canonicalKey,
      type: stringValue(json['type'], 'preference'),
      scope: stringValue(json['scope'], 'global'),
      sensitivity: stringValue(json['sensitivity'], 'low'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'timestamp': timestamp,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (deletedAt != null) 'deletedAt': deletedAt,
    if (key.isNotEmpty) 'key': key,
    if (type.isNotEmpty) 'type': type,
    if (scope.isNotEmpty) 'scope': scope,
    if (sensitivity.isNotEmpty) 'sensitivity': sensitivity,
  };

  static String inferKey(String content) => MemoryCanonicalKeys.inferFromContent(content);
}

class MemoryCanonicalKeys {
  // Core user identity
  static const String userName = 'user.name';
  static const String userNickname = 'user.nickname';
  static const String userLocation = 'user.location';
  static const String userOccupation = 'user.occupation';
  static const String userPets = 'user.pets';

  // Communication style & tone
  static const String prefLanguage = 'pref.language';
  static const String prefTone = 'pref.tone';
  static const String prefVerbosity = 'pref.verbosity';

  // Technical preferences
  static const String prefFramework = 'pref.framework';
  static const String prefLanguageTech = 'pref.tech_language';
  static const String prefUiDesign = 'pref.ui_design';

  // Project memories
  static const String projectCurrent = 'project.current';
  static const String projectRequirement = 'project.requirement';

  static const String topicPrefix = 'topic.';

  /// Canonicalizes legacy or raw keys into the standard taxonomy.
  static String normalize(String rawKey) {
    final key = rawKey.trim().toLowerCase();
    if (key.isEmpty || key == 'none' || key == 'user_defined') return '';

    // Legacy mappings
    if (key == 'user_name' || key == 'name') return userName;
    if (key == 'nickname') return userNickname;
    if (key == 'pets' || key == 'pet') return userPets;
    if (key == 'preferred_language' || key == 'language') return prefLanguage;
    if (key == 'preferred_tone' || key == 'tone') return prefTone;
    if (key == 'preferred_framework' || key == 'preferred_mobile_framework' || key == 'framework') {
      return prefFramework;
    }
    if (key == 'ui_preference' || key == 'ui_design') return prefUiDesign;
    if (key == 'project_requirement' || key.startsWith('project_requirement_') || key.endsWith('_requirement')) {
      return projectRequirement;
    }
    if (key == 'current_project' || key.startsWith('project_')) return projectCurrent;

    // Strips random timestamped manual prefixes
    if (key.startsWith('manual_memory_') || key.startsWith('custom_memory_')) {
      return '';
    }

    // Custom topic keys
    if (key.startsWith('topic.')) return key;
    if (key.startsWith('topic_')) return 'topic.${key.substring(6)}';
    if (key.startsWith('custom_')) return 'topic.$key';

    return key;
  }

  /// Infers canonical key from text (Indonesian + English).
  static String inferFromContent(String content) {
    final value = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // User name
    if (value.contains('name is') ||
        value.contains('named') ||
        value.contains('nama saya') ||
        value.contains('nama aku') ||
        value.contains('namaku')) {
      return userName;
    }

    // Nickname
    if (value.contains('nickname') ||
        value.contains('call user') ||
        value.contains('call me') ||
        value.contains('panggil aku') ||
        value.contains('panggil saya') ||
        value.contains('panggilan')) {
      return userNickname;
    }

    // Location
    if (value.contains('live in') ||
        value.contains('lives in') ||
        value.contains('based in') ||
        value.contains('tinggal di') ||
        value.contains('domisili')) {
      return userLocation;
    }

    // Occupation
    if (value.contains('work as') ||
        value.contains('works as') ||
        value.contains('bekerja sebagai') ||
        value.contains('kerja di') ||
        value.contains('profesi')) {
      return userOccupation;
    }

    // Pets
    if (RegExp(r'\b(dog|dogs|cat|cats|pet|pets|kucing|anjing|hewan peliharaan)\b').hasMatch(value)) {
      return userPets;
    }

    // Language
    if (value.contains('language') ||
        value.contains('indonesian') ||
        value.contains('bahasa indonesia') ||
        value.contains('bahasa inggris') ||
        value.contains('english')) {
      return prefLanguage;
    }

    // Tone & verbosity
    if (value.contains('tone') ||
        value.contains('verbose') ||
        value.contains('concise') ||
        value.contains('singkat') ||
        value.contains('santai') ||
        value.contains('bertele tele') ||
        value.contains('to the point')) {
      return prefTone;
    }

    // Tech stack
    if (value.contains('framework') ||
        RegExp(r'\b(flutter|react|vue|svelte|angular|kotlin|swift|dart|python)\b').hasMatch(value)) {
      return prefFramework;
    }

    // Project
    if (value.contains('project') || value.contains('proyek') || value.contains('aplikasi yang dibangun')) {
      return projectCurrent;
    }
    if (value.contains('requirement') || value.contains('kebutuhan proyek')) {
      return projectRequirement;
    }

    return '';
  }
}

class TokenUsageRecord {
  const TokenUsageRecord({
    required this.timestamp,
    required this.model,
    required this.endpoint,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    this.cachedInputTokens = 0,
    this.cacheCreationInputTokens = 0,
    this.sessionId,
    this.isEstimated = true,
  });

  final int timestamp;
  final String model;
  final String endpoint;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cachedInputTokens;
  final int cacheCreationInputTokens;
  final String? sessionId;
  final bool isEstimated;

  factory TokenUsageRecord.fromJson(Map<String, dynamic> json) {
    return TokenUsageRecord(
      timestamp: intValue(json['timestamp']),
      model: stringValue(json['model']),
      endpoint: stringValue(json['endpoint']),
      inputTokens: intValue(json['inputTokens']),
      outputTokens: intValue(json['outputTokens']),
      totalTokens: intValue(json['totalTokens']),
      cachedInputTokens: intValue(
        json['cachedInputTokens'] ?? json['cached_input_tokens'],
      ),
      cacheCreationInputTokens: intValue(
        json['cacheCreationInputTokens'] ?? json['cache_creation_input_tokens'],
      ),
      sessionId: stringValue(json['sessionId']),
      isEstimated: json.containsKey('isEstimated') 
          ? json['isEstimated'] == true 
          : true,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'model': model,
    'endpoint': endpoint,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
    if (cachedInputTokens > 0) 'cachedInputTokens': cachedInputTokens,
    if (cacheCreationInputTokens > 0)
      'cacheCreationInputTokens': cacheCreationInputTokens,
    if (sessionId != null) 'sessionId': sessionId,
    'isEstimated': isEstimated,
  };
}

class CustomCounter {
  const CustomCounter({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.color,
  });

  final String id;
  final String name;
  final int createdAt;
  final String color;

  CustomCounter copyWith({String? name, int? createdAt, String? color}) {
    return CustomCounter(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
    );
  }

  factory CustomCounter.fromJson(Map<String, dynamic> json) {
    return CustomCounter(
      id: stringValue(json['id']),
      name: stringValue(json['name']),
      createdAt: intValue(json['createdAt']),
      color: stringValue(json['color'], '#ffffff'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
    'color': color,
  };
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.username,
    this.email,
    this.displayName,
    this.isGuest = false,
  });

  final String id;
  final String username;
  final String? email;
  final String? displayName;
  final bool isGuest;

  String get label => displayName?.isNotEmpty == true ? displayName! : username;

  factory UserAccount.guest() => const UserAccount(
    id: 'guest-local',
    username: 'guest',
    displayName: 'Guest',
    isGuest: true,
  );

  factory UserAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return UserAccount.guest();
    final username = stringValue(
      json['username'],
      stringValue(
        json['email'],
        stringValue(
          json['displayName'],
          boolValue(json['isGuest']) ? 'guest' : 'user',
        ),
      ),
    );
    return UserAccount(
      id: stringValue(
        json['id'],
        '${boolValue(json['isGuest']) ? 'guest' : 'user'}-$username',
      ),
      username: username,
      email: json['email'] == null ? null : stringValue(json['email']),
      displayName: stringValue(
        json['displayName'],
        boolValue(json['isGuest']) ? 'Guest' : username,
      ),
      isGuest: boolValue(json['isGuest']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    if (email != null) 'email': email,
    'displayName': displayName ?? username,
    if (isGuest) 'isGuest': true,
  };
}

class DatabaseSettings {
  const DatabaseSettings({
    this.databaseUrl = '',
    this.database = '',
    this.schemaName = 'adoetzgpt',
    this.user = '',
    this.password = '',
    this.port = '',
  });

  final String databaseUrl;
  final String database;
  final String schemaName;
  final String user;
  final String password;
  final String port;

  DatabaseSettings copyWith({
    String? databaseUrl,
    String? database,
    String? schemaName,
    String? user,
    String? password,
    String? port,
  }) {
    return DatabaseSettings(
      databaseUrl: databaseUrl ?? this.databaseUrl,
      database: database ?? this.database,
      schemaName: schemaName ?? this.schemaName,
      user: user ?? this.user,
      password: password ?? this.password,
      port: port ?? this.port,
    );
  }

  factory DatabaseSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DatabaseSettings();
    return DatabaseSettings(
      databaseUrl: stringValue(json['databaseUrl']),
      database: stringValue(json['database']),
      schemaName: stringValue(json['schemaName'], 'adoetzgpt'),
      user: stringValue(json['user']),
      password: stringValue(json['password']),
      port: stringValue(json['port']),
    );
  }

  Map<String, dynamic> toJson({bool includePassword = true}) => {
    'databaseUrl': databaseUrl,
    'database': database,
    'schemaName': schemaName.isEmpty ? 'adoetzgpt' : schemaName,
    'user': user,
    'password': includePassword ? password : '',
    'port': port,
  };
}

class SyncSettings {
  const SyncSettings({
    this.enabled = false,
    this.apiBaseUrl = '',
    this.database = const DatabaseSettings(),
    this.backupDatabases = const [],
    this.autoSyncBackups = false,
    this.useSupabase = false,
    this.supabaseUrl = 'https://supabase.alids.app',
    this.supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE3ODE0MjkzOTMsImV4cCI6MjA4Mjc1ODQwMH0.qgQ3hxL9JgRhZ-0vuIAG-myu8w5UeWkG1iNrsjqDvR0',
    this.e2eeEnabled = false,
    this.e2eePassphrase = '',
  });

  final bool enabled;
  final String apiBaseUrl;
  final DatabaseSettings database;
  final List<DatabaseSettings> backupDatabases;
  final bool autoSyncBackups;
  final bool useSupabase;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool e2eeEnabled;
  final String e2eePassphrase;

  SyncSettings copyWith({
    bool? enabled,
    String? apiBaseUrl,
    DatabaseSettings? database,
    List<DatabaseSettings>? backupDatabases,
    bool? autoSyncBackups,
    bool? useSupabase,
    String? supabaseUrl,
    String? supabaseAnonKey,
    bool? e2eeEnabled,
    String? e2eePassphrase,
  }) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      database: database ?? this.database,
      backupDatabases: backupDatabases ?? this.backupDatabases,
      autoSyncBackups: autoSyncBackups ?? this.autoSyncBackups,
      useSupabase: useSupabase ?? this.useSupabase,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      e2eeEnabled: e2eeEnabled ?? this.e2eeEnabled,
      e2eePassphrase: e2eePassphrase ?? this.e2eePassphrase,
    );
  }

  factory SyncSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SyncSettings();
    final db = DatabaseSettings.fromJson(
      json['database'] is Map
          ? Map<String, dynamic>.from(json['database'])
          : json,
    );
    return SyncSettings(
      enabled: boolValue(json['enabled']),
      apiBaseUrl: stringValue(json['apiBaseUrl']),
      database: db.copyWith(
        schemaName: db.schemaName.isNotEmpty
            ? db.schemaName
            : stringValue(json['schemaName'], 'adoetzgpt'),
      ),
      backupDatabases: mapList(
        json['backupDatabases'],
      ).map(DatabaseSettings.fromJson).toList(),
      autoSyncBackups: boolValue(json['autoSyncBackups']),
      useSupabase: boolValue(json['useSupabase']),
      supabaseUrl: stringValue(json['supabaseUrl']),
      supabaseAnonKey: stringValue(json['supabaseAnonKey']),
      e2eeEnabled: boolValue(json['e2eeEnabled']),
      e2eePassphrase: stringValue(json['e2eePassphrase']),
    );
  }

  Map<String, dynamic> toJson({bool includePassword = true}) => {
    'enabled': enabled,
    'apiBaseUrl': apiBaseUrl,
    'database': database.toJson(includePassword: includePassword),
    'backupDatabases': backupDatabases
        .map((db) => db.toJson(includePassword: includePassword))
        .toList(),
    'autoSyncBackups': autoSyncBackups,
    'useSupabase': useSupabase,
    'supabaseUrl': supabaseUrl,
    if (includePassword) 'supabaseAnonKey': supabaseAnonKey,
    'e2eeEnabled': e2eeEnabled,
    if (includePassword) 'e2eePassphrase': e2eePassphrase,
  };
}

class McpServerConfig {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final Map<String, String> headers;
  
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.headers = const {},
  });

  McpServerConfig copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
    Map<String, String>? headers,
  }) {
    return McpServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      headers: headers ?? this.headers,
    );
  }

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      id: stringValue(json['id'], DateTime.now().millisecondsSinceEpoch.toString()),
      name: stringValue(json['name'], 'Unknown Server'),
      url: stringValue(json['url']),
      enabled: boolValue(json['enabled'], true),
      headers: json['headers'] is Map
          ? Map<String, String>.from(json['headers'])
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'enabled': enabled,
      'headers': headers,
    };
  }
}

class PersistedAppState {
  const PersistedAppState({
    required this.currentUser,
    required this.authToken,
    required this.syncSettings,
    required this.language,
    required this.theme,
    required this.visualTheme,
    required this.selectedModel,
    required this.selectedTargetId,
    required this.isThinkingMode,
    required this.isArtifactMode,
    required this.userName,
    required this.geminiApiKey,
    required this.endpoints,
    required this.agentConnectors,
    required this.modelContextOverrides,
    required this.modelInputCosts,
    required this.modelOutputCosts,
    required this.modelCacheHitCosts,
    required this.genSettings,
    required this.voiceSettings,
    required this.sessions,
    required this.currentSessionId,
    required this.memories,
    required this.tokenUsageData,
    required this.customCounters,
    required this.mcpServers,
    this.cronJobs = const [],
    this.personas = const [],
    required this.soundEffectsEnabled,
    required this.isLiveVideoEnabled,
    required this.isLiveFrontCamera,
    this.cachedPasswordHash,
    this.lastSyncAt,
    this.savedAt,
  });

  final UserAccount? currentUser;
  final String authToken;
  final SyncSettings syncSettings;
  final AppLanguage language;
  final String theme;
  final String visualTheme;
  final String selectedModel;
  final String selectedTargetId;
  final bool isThinkingMode;
  final bool isArtifactMode;
  final String userName;
  final String geminiApiKey;
  final List<EndpointConfig> endpoints;
  final List<AgentConnector> agentConnectors;
  final Map<String, int> modelContextOverrides;
  final Map<String, double> modelInputCosts;
  final Map<String, double> modelOutputCosts;
  final Map<String, double> modelCacheHitCosts;
  final GenerationSettings genSettings;
  final VoiceSettings voiceSettings;
  final List<Session> sessions;
  final String currentSessionId;
  final List<Memory> memories;
  final List<TokenUsageRecord> tokenUsageData;
  final List<CustomCounter> customCounters;
  final List<McpServerConfig> mcpServers;
  final List<AiCronJob> cronJobs;
  final List<PersonaProfile> personas;
  final bool soundEffectsEnabled;
  final bool isLiveVideoEnabled;
  final bool isLiveFrontCamera;
  final String? cachedPasswordHash;
  final int? lastSyncAt;
  final int? savedAt;

  factory PersistedAppState.defaults() {
    final session = Session.empty();
    return PersistedAppState(
      currentUser: null,
      authToken: '',
      syncSettings: const SyncSettings(),
      language: AppLanguage.id,
      theme: 'dark',
      visualTheme: 'default',
      selectedModel: 'gemini-2.5-flash',
      selectedTargetId: 'model:gemini-2.5-flash',
      isThinkingMode: false,
      isArtifactMode: false,
      userName: 'User',
      geminiApiKey: '',
      endpoints: const [
        EndpointConfig(
          id: '1',
          name: 'OpenAI',
          url: 'https://api.openai.com/v1',
          key: '',
        ),
      ],
      agentConnectors: const [],
      modelContextOverrides: const {},
      modelInputCosts: const {},
      modelOutputCosts: const {},
      modelCacheHitCosts: const {},
      genSettings: const GenerationSettings(),
      voiceSettings: const VoiceSettings(),
      sessions: [session],
      currentSessionId: session.id,
      memories: const [],
      tokenUsageData: const [],
      customCounters: const [],
      mcpServers: const [],
      cronJobs: const [],
      personas: const [],
      soundEffectsEnabled: true,
      isLiveVideoEnabled: false,
      isLiveFrontCamera: false,
      lastSyncAt: null,
    );
  }

  factory PersistedAppState.fromJson(
    Map<String, dynamic> json, {
    bool allowEmptySessions = false,
  }) {
    final sessions = mapList(json['sessions']).map(Session.fromJson).toList();
    final defaults = PersistedAppState.defaults();
    return PersistedAppState(
      currentUser: json['currentUser'] == null
          ? null
          : UserAccount.fromJson(
              Map<String, dynamic>.from(json['currentUser']),
            ),
      authToken: stringValue(json['authToken']),
      syncSettings: SyncSettings.fromJson(
        json['syncSettings'] is Map
            ? Map<String, dynamic>.from(json['syncSettings'])
            : null,
      ),
      language: normalizeLanguage(json['language']),
      theme: stringValue(json['theme'], 'dark') == 'light' ? 'light' : 'dark',
      visualTheme: _normalizeVisualTheme(json['visualTheme']),
      selectedModel: stringValue(json['selectedModel'], defaults.selectedModel),
      selectedTargetId: stringValue(
        json['selectedTargetId'],
        stringValue(json['selected_target_id'], ''),
      ),
      isThinkingMode: boolValue(json['isThinkingMode']),
      isArtifactMode: boolValue(json['isArtifactMode']),
      userName: stringValue(json['userName'], defaults.userName),
      geminiApiKey: stringValue(json['geminiApiKey']),
      endpoints: mapList(
        json['endpoints'],
      ).map(EndpointConfig.fromJson).toList().ifEmpty(defaults.endpoints),
      agentConnectors: mapList(
        json['agentConnectors'] ?? json['agent_connectors'],
      ).map(AgentConnector.fromJson).toList(),
      modelContextOverrides: _intMap(
        json['modelContextOverrides'] ?? json['model_context_overrides'],
      ),
      modelInputCosts: _doubleMap(json['modelInputCosts']),
      modelOutputCosts: _doubleMap(json['modelOutputCosts']),
      modelCacheHitCosts: _doubleMap(json['modelCacheHitCosts']),
      genSettings: GenerationSettings.fromJson(
        json['genSettings'] is Map
            ? Map<String, dynamic>.from(json['genSettings'])
            : null,
      ),
      voiceSettings: VoiceSettings.fromJson(
        json['voiceSettings'] is Map
            ? Map<String, dynamic>.from(json['voiceSettings'])
            : null,
      ),
      sessions: sessions.isEmpty && !allowEmptySessions
          ? defaults.sessions
          : sessions,
      currentSessionId: stringValue(
        json['currentSessionId'],
        sessions.isEmpty
            ? (allowEmptySessions ? '' : defaults.currentSessionId)
            : sessions.first.id,
      ),
      memories: mapList(json['memories']).map(Memory.fromJson).toList(),
      tokenUsageData: mapList(
        json['tokenUsageData'],
      ).map(TokenUsageRecord.fromJson).toList(),
      customCounters: mapList(
        json['customCounters'],
      ).map(CustomCounter.fromJson).toList(),
      mcpServers: mapList(
        json['mcpServers'],
      ).map(McpServerConfig.fromJson).toList(),
      cronJobs: mapList(
        json['cronJobs'],
      ).map(AiCronJob.fromJson).toList(),
      personas: mapList(
        json['personas'],
      ).map(PersonaProfile.fromJson).toList(),
      soundEffectsEnabled: boolValue(json['soundEffectsEnabled'], true),
      isLiveVideoEnabled: boolValue(json['isLiveVideoEnabled']),
      isLiveFrontCamera: boolValue(json['isLiveFrontCamera']),
      cachedPasswordHash: json['cachedPasswordHash'] as String?,
      lastSyncAt: json['lastSyncAt'] == null
          ? null
          : intValue(json['lastSyncAt']),
      savedAt: json['savedAt'] == null ? null : intValue(json['savedAt']),
    );
  }

  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
    'currentUser': currentUser?.toJson(),
    'authToken': includeSecrets ? authToken : '',
    'syncSettings': syncSettings.toJson(includePassword: includeSecrets),
    'language': languageCode(language),
    'theme': theme,
    'visualTheme': visualTheme,
    'selectedModel': selectedModel,
    'selectedTargetId': selectedTargetId,
    'isThinkingMode': isThinkingMode,
    'isArtifactMode': isArtifactMode,
    'userName': userName,
    'geminiApiKey': includeSecrets ? geminiApiKey : '',
    'endpoints': endpoints
        .map(
          (item) =>
              includeSecrets ? item.toJson() : item.copyWith(key: '').toJson(),
        )
        .toList(),
    'agentConnectors': agentConnectors
        .map((item) => item.toJson(includeSecrets: includeSecrets))
        .toList(),
    'modelContextOverrides': modelContextOverrides,
    'modelInputCosts': modelInputCosts,
    'modelOutputCosts': modelOutputCosts,
    'modelCacheHitCosts': modelCacheHitCosts,
    'genSettings': genSettings.toJson(),
    'voiceSettings': voiceSettings.toJson(),
    'sessions': sessions.map((item) => item.toJson()).toList(),
    'currentSessionId': currentSessionId,
    'memories': memories.map((item) => item.toJson()).toList(),
    'tokenUsageData': tokenUsageData.map((item) => item.toJson()).toList(),
    'customCounters': customCounters.map((item) => item.toJson()).toList(),
    'mcpServers': mcpServers.map((item) => item.toJson()).toList(),
    'cronJobs': cronJobs.map((item) => item.toJson()).toList(),
    'personas': personas.map((item) => item.toJson()).toList(),
    'soundEffectsEnabled': soundEffectsEnabled,
    'isLiveVideoEnabled': isLiveVideoEnabled,
    'isLiveFrontCamera': isLiveFrontCamera,
    if (includeSecrets && cachedPasswordHash != null && cachedPasswordHash!.isNotEmpty) 'cachedPasswordHash': cachedPasswordHash,
    if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
    'savedAt': savedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  PersistedAppState copyWith({
    UserAccount? currentUser,
    String? authToken,
    SyncSettings? syncSettings,
    AppLanguage? language,
    String? theme,
    String? visualTheme,
    String? selectedModel,
    String? selectedTargetId,
    bool? isThinkingMode,
    bool? isArtifactMode,
    String? userName,
    String? geminiApiKey,
    List<EndpointConfig>? endpoints,
    List<AgentConnector>? agentConnectors,
    Map<String, int>? modelContextOverrides,
    Map<String, double>? modelInputCosts,
    Map<String, double>? modelOutputCosts,
    Map<String, double>? modelCacheHitCosts,
    GenerationSettings? genSettings,
    VoiceSettings? voiceSettings,
    List<Session>? sessions,
    String? currentSessionId,
    List<Memory>? memories,
    List<TokenUsageRecord>? tokenUsageData,
    List<CustomCounter>? customCounters,
    List<McpServerConfig>? mcpServers,
    List<AiCronJob>? cronJobs,
    List<PersonaProfile>? personas,
    bool? soundEffectsEnabled,
    bool? isLiveVideoEnabled,
    bool? isLiveFrontCamera,
    String? cachedPasswordHash,
    int? lastSyncAt,
    int? savedAt,
    bool clearCurrentUser = false,
  }) {
    return PersistedAppState(
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      authToken: authToken ?? this.authToken,
      syncSettings: syncSettings ?? this.syncSettings,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      visualTheme: visualTheme ?? this.visualTheme,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedTargetId: selectedTargetId ?? this.selectedTargetId,
      isThinkingMode: isThinkingMode ?? this.isThinkingMode,
      isArtifactMode: isArtifactMode ?? this.isArtifactMode,
      userName: userName ?? this.userName,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      endpoints: endpoints ?? this.endpoints,
      agentConnectors: agentConnectors ?? this.agentConnectors,
      modelContextOverrides: modelContextOverrides ?? this.modelContextOverrides,
      modelInputCosts: modelInputCosts ?? this.modelInputCosts,
      modelOutputCosts: modelOutputCosts ?? this.modelOutputCosts,
      modelCacheHitCosts: modelCacheHitCosts ?? this.modelCacheHitCosts,
      genSettings: genSettings ?? this.genSettings,
      voiceSettings: voiceSettings ?? this.voiceSettings,
      sessions: sessions ?? this.sessions,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      memories: memories ?? this.memories,
      tokenUsageData: tokenUsageData ?? this.tokenUsageData,
      customCounters: customCounters ?? this.customCounters,
      mcpServers: mcpServers ?? this.mcpServers,
      cronJobs: cronJobs ?? this.cronJobs,
      personas: personas ?? this.personas,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      isLiveVideoEnabled: isLiveVideoEnabled ?? this.isLiveVideoEnabled,
      isLiveFrontCamera: isLiveFrontCamera ?? this.isLiveFrontCamera,
      cachedPasswordHash: cachedPasswordHash ?? this.cachedPasswordHash,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  String encode({bool includeSecrets = true}) =>
      jsonEncode(toJson(includeSecrets: includeSecrets));
}

String _normalizeVisualTheme(Object? value) {
  final key = stringValue(value, 'default').trim().toLowerCase();
  return switch (key) {
    'liquid-glass' || 'liquidglass' || 'glass' => 'liquid-glass',
    'aurora-neon' || 'auroraneon' || 'aurora' || 'neon' => 'aurora-neon',
    'modern-minimal' || 'modernminimal' || 'minimal' => 'modern-minimal',
    'ios26' || 'vision' => 'ios26',
    'midnight-bloom' ||
    'midnightbloom' ||
    'midnight' ||
    'bloom' => 'midnight-bloom',
    'cyberpunk-oled' ||
    'cyberpunk' ||
    'cyberpunkoled' ||
    'oled' => 'cyberpunk-oled',
    'synthwave-80s' ||
    'synthwave' ||
    'synthwave80s' ||
    'outrun' => 'synthwave-80s',
    'matrix-phosphor' ||
    'matrix' ||
    'phosphor' ||
    'matrixphosphor' => 'matrix-phosphor',
    'solar-flare' ||
    'solarflare' ||
    'solar' ||
    'flare' => 'solar-flare',
    _ => 'default',
  };
}

enum ArenaBranchStatus {
  idle,
  streaming,
  completed,
  failed,
}

class ArenaBranchResult {
  const ArenaBranchResult({
    required this.id,
    required this.model,
    required this.displayName,
    this.provider = '',
    this.text = '',
    this.status = ArenaBranchStatus.idle,
    this.error,
    this.timeToFirstTokenMs,
    this.totalTimeMs,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedTokens = 0,
    this.estimatedCostUsd = 0.0,
    this.tokensPerSecond = 0.0,
  });

  final String id;
  final String model;
  final String displayName;
  final String provider;
  final String text;
  final ArenaBranchStatus status;
  final String? error;
  final int? timeToFirstTokenMs;
  final int? totalTimeMs;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final double estimatedCostUsd;
  final double tokensPerSecond;

  ArenaBranchResult copyWith({
    String? id,
    String? model,
    String? displayName,
    String? provider,
    String? text,
    ArenaBranchStatus? status,
    String? error,
    int? timeToFirstTokenMs,
    int? totalTimeMs,
    int? inputTokens,
    int? outputTokens,
    int? cachedTokens,
    double? estimatedCostUsd,
    double? tokensPerSecond,
  }) =>
      ArenaBranchResult(
        id: id ?? this.id,
        model: model ?? this.model,
        displayName: displayName ?? this.displayName,
        provider: provider ?? this.provider,
        text: text ?? this.text,
        status: status ?? this.status,
        error: error ?? this.error,
        timeToFirstTokenMs: timeToFirstTokenMs ?? this.timeToFirstTokenMs,
        totalTimeMs: totalTimeMs ?? this.totalTimeMs,
        inputTokens: inputTokens ?? this.inputTokens,
        outputTokens: outputTokens ?? this.outputTokens,
        cachedTokens: cachedTokens ?? this.cachedTokens,
        estimatedCostUsd: estimatedCostUsd ?? this.estimatedCostUsd,
        tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      );

  factory ArenaBranchResult.fromJson(Map<String, dynamic> json) =>
      ArenaBranchResult(
        id: stringValue(json['id']),
        model: stringValue(json['model']),
        displayName: stringValue(json['displayName']),
        provider: stringValue(json['provider']),
        text: stringValue(json['text']),
        status: switch (stringValue(json['status'])) {
          'streaming' => ArenaBranchStatus.streaming,
          'completed' => ArenaBranchStatus.completed,
          'failed' => ArenaBranchStatus.failed,
          _ => ArenaBranchStatus.idle,
        },
        error: json['error'] == null ? null : stringValue(json['error']),
        timeToFirstTokenMs: json['timeToFirstTokenMs'] == null
            ? null
            : intValue(json['timeToFirstTokenMs']),
        totalTimeMs: json['totalTimeMs'] == null
            ? null
            : intValue(json['totalTimeMs']),
        inputTokens: intValue(json['inputTokens']),
        outputTokens: intValue(json['outputTokens']),
        cachedTokens: intValue(json['cachedTokens']),
        estimatedCostUsd: doubleValue(json['estimatedCostUsd']),
        tokensPerSecond: doubleValue(json['tokensPerSecond']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'displayName': displayName,
        'provider': provider,
        'text': text,
        'status': status.name,
        if (error != null) 'error': error,
        if (timeToFirstTokenMs != null) 'timeToFirstTokenMs': timeToFirstTokenMs,
        if (totalTimeMs != null) 'totalTimeMs': totalTimeMs,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cachedTokens': cachedTokens,
        'estimatedCostUsd': estimatedCostUsd,
        'tokensPerSecond': tokensPerSecond,
      };
}

class ArenaSessionState {
  const ArenaSessionState({
    this.isActive = false,
    this.models = const [],
    this.branches = const [],
    this.prompt = '',
  });

  final bool isActive;
  final List<String> models;
  final List<ArenaBranchResult> branches;
  final String prompt;

  ArenaSessionState copyWith({
    bool? isActive,
    List<String>? models,
    List<ArenaBranchResult>? branches,
    String? prompt,
  }) =>
      ArenaSessionState(
        isActive: isActive ?? this.isActive,
        models: models ?? this.models,
        branches: branches ?? this.branches,
        prompt: prompt ?? this.prompt,
      );
}

class ConversationSummaryCompaction {
  const ConversationSummaryCompaction({
    required this.id,
    required this.originalMessageCount,
    required this.summaryText,
    required this.keyFacts,
    required this.activeConstraints,
    required this.compactedAt,
    this.startMessageId,
    this.endMessageId,
  });

  final String id;
  final int originalMessageCount;
  final String summaryText;
  final List<String> keyFacts;
  final List<String> activeConstraints;
  final int compactedAt;
  final String? startMessageId;
  final String? endMessageId;

  factory ConversationSummaryCompaction.fromJson(Map<String, dynamic> json) =>
      ConversationSummaryCompaction(
        id: stringValue(json['id']),
        originalMessageCount: intValue(json['originalMessageCount']),
        summaryText: stringValue(json['summaryText']),
        keyFacts: (json['keyFacts'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        activeConstraints: (json['activeConstraints'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        compactedAt: intValue(json['compactedAt']),
        startMessageId: json['startMessageId']?.toString(),
        endMessageId: json['endMessageId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalMessageCount': originalMessageCount,
        'summaryText': summaryText,
        'keyFacts': keyFacts,
        'activeConstraints': activeConstraints,
        'compactedAt': compactedAt,
        if (startMessageId != null) 'startMessageId': startMessageId,
        if (endMessageId != null) 'endMessageId': endMessageId,
      };
}

enum SwarmAgentRole {
  orchestrator,
  architect,
  coder,
  critic,
  researcher,
  custom,
}

class SwarmAgent {
  const SwarmAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.model,
    required this.systemPrompt,
    this.temperature = 0.7,
    this.iconName = 'bot',
    this.enabled = true,
  });

  final String id;
  final String name;
  final SwarmAgentRole role;
  final String model;
  final String systemPrompt;
  final double temperature;
  final String iconName;
  final bool enabled;

  factory SwarmAgent.fromJson(Map<String, dynamic> json) => SwarmAgent(
        id: stringValue(json['id']),
        name: stringValue(json['name']),
        role: switch (stringValue(json['role'])) {
          'architect' => SwarmAgentRole.architect,
          'coder' => SwarmAgentRole.coder,
          'critic' => SwarmAgentRole.critic,
          'researcher' => SwarmAgentRole.researcher,
          'orchestrator' => SwarmAgentRole.orchestrator,
          _ => SwarmAgentRole.custom,
        },
        model: stringValue(json['model'], 'gemini-2.5-flash'),
        systemPrompt: stringValue(json['systemPrompt']),
        temperature: doubleValue(json['temperature'], 0.7),
        iconName: stringValue(json['iconName'], 'bot'),
        enabled: boolValue(json['enabled'], true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'model': model,
        'systemPrompt': systemPrompt,
        'temperature': temperature,
        'iconName': iconName,
        'enabled': enabled,
      };
}

/// Default 4-role swarm pipeline: Architect -> Coder -> Critic -> Researcher.
List<SwarmAgent> defaultSwarmAgents(String model) => [
      SwarmAgent(
        id: 'swarm-architect',
        name: 'Architect',
        role: SwarmAgentRole.architect,
        model: model,
        systemPrompt:
            'You are the Architect. Break the objective into a clear, '
            'actionable plan with concrete steps, components, and interfaces. '
            'Be concise and structural; do not implement code.',
      ),
      SwarmAgent(
        id: 'swarm-coder',
        name: 'Coder',
        role: SwarmAgentRole.coder,
        model: model,
        systemPrompt:
            'You are the Coder. Using the Architect plan, produce the concrete '
            'implementation: working code, commands, or artifacts. Prefer '
            'complete, runnable output over prose.',
      ),
      SwarmAgent(
        id: 'swarm-critic',
        name: 'Critic',
        role: SwarmAgentRole.critic,
        model: model,
        systemPrompt:
            'You are the Critic. Adversarially review the implementation for '
            'bugs, edge cases, security issues, and missing requirements. List '
            'concrete problems and fixes, ranked by severity.',
      ),
      SwarmAgent(
        id: 'swarm-researcher',
        name: 'Researcher',
        role: SwarmAgentRole.researcher,
        model: model,
        systemPrompt:
            'You are the Researcher. Validate the final result against the '
            'original objective, verify factual claims, and suggest '
            'improvements or alternatives with clear justification.',
      ),
    ];

class SwarmExecutionStep {
  const SwarmExecutionStep({
    required this.agentId,
    required this.agentName,
    required this.role,
    required this.input,
    required this.output,
    required this.status,
    this.durationMs = 0,
    this.tokenCount = 0,
  });

  final String agentId;
  final String agentName;
  final SwarmAgentRole role;
  final String input;
  final String output;
  final String status;
  final int durationMs;
  final int tokenCount;

  factory SwarmExecutionStep.fromJson(Map<String, dynamic> json) =>
      SwarmExecutionStep(
        agentId: stringValue(json['agentId']),
        agentName: stringValue(json['agentName']),
        role: switch (stringValue(json['role'])) {
          'architect' => SwarmAgentRole.architect,
          'coder' => SwarmAgentRole.coder,
          'critic' => SwarmAgentRole.critic,
          'researcher' => SwarmAgentRole.researcher,
          'orchestrator' => SwarmAgentRole.orchestrator,
          _ => SwarmAgentRole.custom,
        },
        input: stringValue(json['input']),
        output: stringValue(json['output']),
        status: stringValue(json['status']),
        durationMs: intValue(json['durationMs']),
        tokenCount: intValue(json['tokenCount']),
      );

  Map<String, dynamic> toJson() => {
        'agentId': agentId,
        'agentName': agentName,
        'role': role.name,
        'input': input,
        'output': output,
        'status': status,
        'durationMs': durationMs,
        'tokenCount': tokenCount,
      };
}

class AiCronJob {
  const AiCronJob({
    required this.id,
    required this.title,
    required this.cronExpression,
    required this.prompt,
    required this.targetModel,
    this.enabled = true,
    this.lastRunAt,
    this.lastRunStatus = '',
    this.lastRunOutput = '',
    this.destinationSessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String cronExpression;
  final String prompt;
  final String targetModel;
  final bool enabled;
  final int? lastRunAt;
  final String lastRunStatus;
  final String lastRunOutput;
  final String? destinationSessionId;
  final int createdAt;
  final int updatedAt;

  AiCronJob copyWith({
    String? id,
    String? title,
    String? cronExpression,
    String? prompt,
    String? targetModel,
    bool? enabled,
    int? lastRunAt,
    String? lastRunStatus,
    String? lastRunOutput,
    String? destinationSessionId,
    int? createdAt,
    int? updatedAt,
  }) =>
      AiCronJob(
        id: id ?? this.id,
        title: title ?? this.title,
        cronExpression: cronExpression ?? this.cronExpression,
        prompt: prompt ?? this.prompt,
        targetModel: targetModel ?? this.targetModel,
        enabled: enabled ?? this.enabled,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastRunStatus: lastRunStatus ?? this.lastRunStatus,
        lastRunOutput: lastRunOutput ?? this.lastRunOutput,
        destinationSessionId:
            destinationSessionId ?? this.destinationSessionId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory AiCronJob.fromJson(Map<String, dynamic> json) => AiCronJob(
        id: stringValue(json['id']),
        title: stringValue(json['title']),
        cronExpression: stringValue(json['cronExpression'], '0 9 * * *'),
        prompt: stringValue(json['prompt']),
        targetModel: stringValue(json['targetModel'], 'gemini-2.5-flash'),
        enabled: boolValue(json['enabled'], true),
        lastRunAt: json['lastRunAt'] == null ? null : intValue(json['lastRunAt']),
        lastRunStatus: stringValue(json['lastRunStatus']),
        lastRunOutput: stringValue(json['lastRunOutput']),
        destinationSessionId: json['destinationSessionId']?.toString(),
        createdAt: intValue(json['createdAt']),
        updatedAt: intValue(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cronExpression': cronExpression,
        'prompt': prompt,
        'targetModel': targetModel,
        'enabled': enabled,
        if (lastRunAt != null) 'lastRunAt': lastRunAt,
        'lastRunStatus': lastRunStatus,
        'lastRunOutput': lastRunOutput,
        if (destinationSessionId != null)
          'destinationSessionId': destinationSessionId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class PersonaProfile {
  const PersonaProfile({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.tagline,
    required this.systemPrompt,
    this.temperature = 0.7,
    this.preferredModel,
    this.suggestedStarters = const [],
    this.tags = const [],
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String avatarEmoji;
  final String tagline;
  final String systemPrompt;
  final double temperature;
  final String? preferredModel;
  final List<String> suggestedStarters;
  final List<String> tags;
  final bool isBuiltIn;

  factory PersonaProfile.fromJson(Map<String, dynamic> json) => PersonaProfile(
        id: stringValue(json['id']),
        name: stringValue(json['name']),
        avatarEmoji: stringValue(json['avatarEmoji'], '🤖'),
        tagline: stringValue(json['tagline']),
        systemPrompt: stringValue(json['systemPrompt']),
        temperature: doubleValue(json['temperature'], 0.7),
        preferredModel: json['preferredModel']?.toString(),
        suggestedStarters: (json['suggestedStarters'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        tags: (json['tags'] as List? ?? []).map((e) => e.toString()).toList(),
        isBuiltIn: boolValue(json['isBuiltIn'], false),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarEmoji': avatarEmoji,
        'tagline': tagline,
        'systemPrompt': systemPrompt,
        'temperature': temperature,
        if (preferredModel != null) 'preferredModel': preferredModel,
        'suggestedStarters': suggestedStarters,
        'tags': tags,
        'isBuiltIn': isBuiltIn,
      };
}

extension _ListFallback<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}

