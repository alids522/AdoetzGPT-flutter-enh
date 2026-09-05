import '../models.dart';

class MemoryAgentAction {
  const MemoryAgentAction({
    required this.action,
    required this.type,
    required this.key,
    required this.value,
    required this.scope,
    required this.confidence,
    required this.sensitivity,
    required this.reason,
  });

  final String action;
  final String type;
  final String key;
  final String value;
  final String scope;
  final double confidence;
  final String sensitivity;
  final String reason;

  bool get applies =>
      action != 'ignore' &&
      key.isNotEmpty &&
      key != 'none' &&
      confidence >= 0.7 &&
      sensitivity != 'high';

  Map<String, dynamic> toJson() => {
    'action': action,
    'type': type,
    'key': key,
    'value': value,
    'scope': scope,
    'confidence': confidence,
    'sensitivity': sensitivity,
    'reason': reason,
  };
}

class MemoryAgent {
  const MemoryAgent();

  List<MemoryAgentAction> analyze({
    required String message,
    required List<Memory> existingMemories,
  }) {
    final clean = _clean(message);
    if (clean.isEmpty) return [_ignore('The message is empty.')];

    final lower = clean.toLowerCase();
    final normalized = _normalize(clean);
    if (_containsSecret(clean) || _containsHighSensitivity(lower)) {
      return [_ignore('The message contains sensitive information.')];
    }

    final delete = _deleteAction(clean, normalized, existingMemories);
    if (delete != null) return [delete];

    final actions = <MemoryAgentAction>[
      ..._personalActions(clean, normalized, existingMemories),
      ..._preferenceActions(clean, lower, normalized, existingMemories),
      ..._projectActions(clean, lower, normalized, existingMemories),
      ..._rememberActions(clean, lower, normalized, existingMemories),
    ];

    final unique = <String, MemoryAgentAction>{};
    for (final action in actions.where((item) => item.applies)) {
      unique[action.key] = action;
    }
    if (unique.isEmpty) {
      return [_ignore('No clearly useful cross-session memory was found.')];
    }
    return unique.values.toList();
  }

  List<MemoryAgentAction> _personalActions(
    String clean,
    String normalized,
    List<Memory> existing,
  ) {
    final actions = <MemoryAgentAction>[];

    // User Name: EN & ID
    final name = _firstMatch(clean, [
      RegExp(r"\bmy name is\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bi am\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bi'm\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bnama saya\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bnama aku\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bnamaku\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
    ]);
    if (name != null && !_looksLikeActivity(name)) {
      final pretty = _titleName(name);
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.userName,
          type: 'personal_fact',
          value: "User's name is $pretty.",
          scope: 'global',
          confidence: 1.0,
          existing: existing,
          reason: 'The user explicitly stated their name.',
        ),
      );
    }

    // Nickname / Call name: EN & ID
    final nickname = _firstMatch(clean, [
      RegExp(r"\bcall me\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\byou can call me\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bpanggil aku\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bpanggil saya\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bpanggil aja\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
      RegExp(r"\bbisa panggil (?:aku|saya|gue)\s+([A-Za-z][A-Za-z0-9 _-]{1,40})", caseSensitive: false),
    ]);
    if (nickname != null && !_looksLikeActivity(nickname)) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.userNickname,
          type: 'personal_fact',
          value: 'User likes to be called ${_titleName(nickname)}.',
          scope: 'global',
          confidence: 1.0,
          existing: existing,
          reason: 'The user explicitly gave a preferred name.',
        ),
      );
    }

    // Location / Residence: EN & ID
    final location = _firstMatch(clean, [
      RegExp(r"\b(?:i live in|i am based in|i reside in)\s+([A-Za-z\s]{2,40})", caseSensitive: false),
      RegExp(r"\b(?:aku|saya|gue)\s+tinggal di\s+([A-Za-z\s]{2,40})", caseSensitive: false),
      RegExp(r"\bdomisili (?:saya|aku|di)?\s*([A-Za-z\s]{2,40})", caseSensitive: false),
    ]);
    if (location != null && !_looksLikeActivity(location)) {
      final prettyLoc = _titleName(location);
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.userLocation,
          type: 'personal_fact',
          value: 'User lives in $prettyLoc.',
          scope: 'global',
          confidence: 0.95,
          existing: existing,
          reason: 'The user explicitly stated their location.',
        ),
      );
    }

    // Pets: EN & ID
    final petEn = RegExp(
      r"\b(?:actually\s+)?i\s+(?:have|own)\s+([0-9]+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(dog|dogs|cat|cats|bird|birds|fish|pets)\b",
      caseSensitive: false,
    ).firstMatch(clean);
    final petId = RegExp(
      r"\b(?:aku|saya|gue)\s+(?:punya|memelihara)\s+([0-9]+|satu|dua|tiga|empat|lima)\s+(?:ekor\s+)?(kucing|anjing|burung|ikan|kelinci|hewan peliharaan)\b",
      caseSensitive: false,
    ).firstMatch(clean);

    if ((petEn != null || petId != null) && !_temporaryAnimalMention(normalized)) {
      final countWord = petEn != null ? petEn.group(1)! : petId!.group(1)!;
      final rawAnimal = petEn != null ? petEn.group(2)! : petId!.group(2)!;
      final count = _numberWordToDigit(countWord);
      final animal = _pluralizePet(rawAnimal, count);
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.userPets,
          type: 'personal_fact',
          value: 'User has $count $animal.',
          scope: 'global',
          confidence: 1.0,
          existing: existing,
          reason: 'The user explicitly stated a pet fact.',
        ),
      );
    }

    return actions;
  }

  List<MemoryAgentAction> _preferenceActions(
    String clean,
    String lower,
    String normalized,
    List<Memory> existing,
  ) {
    final actions = <MemoryAgentAction>[];

    // Language preference
    if (RegExp(
      r'\b(?:prefer|usually want|want|use)\s+(?:casual\s+)?(?:bahasa\s+)?indonesian\b',
      caseSensitive: false,
    ).hasMatch(clean) ||
        RegExp(
          r'\b(?:lebih suka|pake|pakai|gunakan|prefer)\s+bahasa\s+indonesia\b',
          caseSensitive: false,
        ).hasMatch(clean)) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefLanguage,
          type: 'communication_style',
          value: 'User prefers Indonesian when appropriate.',
          scope: 'global',
          confidence: 0.9,
          existing: existing,
          reason: 'The user clearly stated a language preference.',
        ),
      );
    } else if (RegExp(
      r'\b(?:prefer|respond in|speak in)\s+english\b',
      caseSensitive: false,
    ).hasMatch(clean) ||
        RegExp(
          r'\b(?:lebih suka|pake|pakai|gunakan|prefer)\s+bahasa\s+inggris\b',
          caseSensitive: false,
        ).hasMatch(clean)) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefLanguage,
          type: 'communication_style',
          value: 'User prefers English.',
          scope: 'global',
          confidence: 0.9,
          existing: existing,
          reason: 'The user clearly stated an English language preference.',
        ),
      );
    }

    // Tone & conciseness (EN & ID)
    if (lower.contains('hate verbose') ||
        lower.contains('not verbose') ||
        lower.contains('less verbose') ||
        lower.contains('concise answer') ||
        lower.contains('keep it concise') ||
        lower.contains('short answer') ||
        lower.contains('jangan bertele-tele') ||
        lower.contains('jangan bertele tele') ||
        lower.contains('jangan panjang lebar') ||
        lower.contains('jawab singkat') ||
        lower.contains('to the point')) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefTone,
          type: 'communication_style',
          value: 'User prefers concise answers and dislikes unnecessary verbosity.',
          scope: 'global',
          confidence: 0.9,
          existing: existing,
          reason: 'The user clearly stated a response style preference.',
        ),
      );
    }

    if (lower.contains('casual indonesian') ||
        lower.contains('casual tone') ||
        lower.contains('informal tone') ||
        lower.contains('santai aja') ||
        lower.contains('bahasa santai') ||
        lower.contains('gaya santai') ||
        lower.contains('ngomong santai')) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefTone,
          type: 'communication_style',
          value: 'User prefers a casual tone when appropriate.',
          scope: 'global',
          confidence: 0.85,
          existing: existing,
          reason: 'The user clearly stated a tone preference.',
        ),
      );
    }

    // Framework preferences (EN & ID)
    final framework = _firstMatch(clean, [
      RegExp(r'\bi\s+prefer\s+(flutter|react|vue|svelte|angular|kotlin|swift|dart|python)\b', caseSensitive: false),
      RegExp(r'\b(?:aku|saya|gue)\s+(?:lebih suka|biasa pakai|prefer)(?:\s+pakai)?\s+(flutter|react|vue|svelte|angular|kotlin|swift|dart|python)\b', caseSensitive: false),
      RegExp(r'\b(?:lebih suka|biasa pakai|prefer)(?:\s+pakai)?\s+(flutter|react|vue|svelte|angular|kotlin|swift|dart|python)\b', caseSensitive: false),
    ]);
    if (framework != null) {
      final value = _titleName(framework);
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefFramework,
          type: 'preference',
          value: 'User prefers $value.',
          scope: 'global',
          confidence: 0.95,
          existing: existing,
          reason: 'The user clearly stated a framework preference.',
        ),
      );
    }

    if (lower.contains('lightweight ui') ||
        lower.contains('minimal ui') ||
        lower.contains('premium ui') ||
        lower.contains('same ui') ||
        lower.contains('preserve the ui')) {
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.prefUiDesign,
          type: 'preference',
          value: _uiPreferenceValue(lower),
          scope: 'global',
          confidence: 0.8,
          existing: existing,
          reason: 'The user stated a durable UI preference.',
        ),
      );
    }

    return actions;
  }

  List<MemoryAgentAction> _projectActions(
    String clean,
    String lower,
    String normalized,
    List<Memory> existing,
  ) {
    final actions = <MemoryAgentAction>[];

    final projectMatch = _firstMatch(clean, [
      RegExp(r"\bi\s+am\s+building\s+(?:an?\s+)?(.{3,90})", caseSensitive: false),
      RegExp(r"\b(?:aku|saya)\s+sedang\s+(?:membuat|bikin|bangun)\s+(?:sebuah\s+)?(.{3,90})", caseSensitive: false),
    ]);
    if (projectMatch != null) {
      final projKeyWords = _normalize(projectMatch).split(' ').where((w) => w.isNotEmpty).take(3).join('_');
      final projKey = projKeyWords.isEmpty ? MemoryCanonicalKeys.projectCurrent : 'project_$projKeyWords';
      actions.add(
        _upsert(
          key: projKey,
          type: 'project_memory',
          value: 'User is building ${_trimClause(projectMatch)}.',
          scope: 'project',
          confidence: 0.9,
          existing: existing,
          reason: 'The user clearly stated their current project.',
        ),
      );
    }

    final projectRequirement = RegExp(
      r'\b(?:for this app|for this project|this app must|this app should|the app must|the app should|aplikasi ini harus|proyek ini harus)\b(.{4,220})',
      caseSensitive: false,
    ).firstMatch(clean);
    if (projectRequirement != null) {
      final clause = _trimClause(projectRequirement.group(0)!);
      actions.add(
        _upsert(
          key: MemoryCanonicalKeys.projectRequirement,
          type: 'project_memory',
          value: 'Project requirement: $clause.',
          scope: 'project',
          confidence: 0.85,
          existing: existing,
          reason: 'The user stated a stable project requirement.',
        ),
      );
    }

    return actions;
  }

  List<MemoryAgentAction> _rememberActions(
    String clean,
    String lower,
    String normalized,
    List<Memory> existing,
  ) {
    final remember = _firstMatch(clean, [
      RegExp(r'\bremember(?: that)?\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
      RegExp(r'\bplease remember\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
      RegExp(r'\bingat(?: bahwa)?\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
      RegExp(r'\btolong ingat\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
      RegExp(r'\bcatat(?: bahwa)?\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
      RegExp(r'\bjangan lupa (?:kalau|bahwa)?\s*[:,-]?\s+(.{3,220})', caseSensitive: false),
    ]);
    if (remember == null) return const [];

    final content = _trimClause(remember);
    if (content.isEmpty ||
        _containsSecret(content) ||
        _containsHighSensitivity(content.toLowerCase())) {
      return const [];
    }

    // Try sub-actions first so "Remember that my name is Adit" maps to user.name
    final nested = [
      ..._personalActions(content, _normalize(content), existing),
      ..._preferenceActions(
        content,
        content.toLowerCase(),
        _normalize(content),
        existing,
      ),
      ..._projectActions(
        content,
        content.toLowerCase(),
        _normalize(content),
        existing,
      ),
    ].where((item) => item.applies).toList();
    if (nested.isNotEmpty) return nested;

    final key = _stableCustomKey(content);
    return [
      _upsert(
        key: key,
        type: content.toLowerCase().contains('app') ||
                content.toLowerCase().contains('project') ||
                content.toLowerCase().contains('proyek') ||
                content.toLowerCase().contains('aplikasi')
            ? 'project_memory'
            : 'preference',
        value: _memorySentence(content),
        scope: content.toLowerCase().contains('app') ||
                content.toLowerCase().contains('project')
            ? 'project'
            : 'global',
        confidence: 0.9,
        existing: existing,
        reason: 'The user explicitly asked to remember this information.',
      ),
    ];
  }

  MemoryAgentAction? _deleteAction(
    String clean,
    String normalized,
    List<Memory> existing,
  ) {
    if (!RegExp(
      r"\b(forget|delete|remove|don't remember|do not remember|lupakan|hapus memori|hapus ingatan|jangan ingat)\b",
      caseSensitive: false,
    ).hasMatch(clean)) {
      return null;
    }

    final key = _deleteKey(normalized);
    return MemoryAgentAction(
      action: 'delete',
      type: _typeForKey(key),
      key: key,
      value: '',
      scope: key.startsWith('project') ? 'project' : 'global',
      confidence: key == 'none' ? 0.0 : 1.0,
      sensitivity: 'low',
      reason: key == 'none'
          ? 'The delete request did not identify a stored memory.'
          : 'The user explicitly asked to forget this memory.',
    );
  }

  String _deleteKey(String normalized) {
    if (RegExp(r'\b(dog|dogs|cat|cats|pet|pets|kucing|anjing|hewan)\b').hasMatch(normalized)) {
      return MemoryCanonicalKeys.userPets;
    }
    if (normalized.contains('name') || normalized.contains('nama')) {
      return MemoryCanonicalKeys.userName;
    }
    if (normalized.contains('nickname') ||
        normalized.contains('call me') ||
        normalized.contains('panggilan') ||
        normalized.contains('panggil aku')) {
      return MemoryCanonicalKeys.userNickname;
    }
    if (normalized.contains('location') || normalized.contains('tinggal') || normalized.contains('domisili')) {
      return MemoryCanonicalKeys.userLocation;
    }
    if (normalized.contains('language') || normalized.contains('indonesian') || normalized.contains('bahasa')) {
      return MemoryCanonicalKeys.prefLanguage;
    }
    if (normalized.contains('verbose') ||
        normalized.contains('tone') ||
        normalized.contains('style') ||
        normalized.contains('santai') ||
        normalized.contains('singkat')) {
      return MemoryCanonicalKeys.prefTone;
    }
    if (normalized.contains('framework') ||
        normalized.contains('flutter') ||
        normalized.contains('react')) {
      return MemoryCanonicalKeys.prefFramework;
    }
    return 'none';
  }

  MemoryAgentAction _upsert({
    required String key,
    required String type,
    required String value,
    required String scope,
    required double confidence,
    required List<Memory> existing,
    required String reason,
  }) {
    final canonicalKey = MemoryCanonicalKeys.normalize(key).isNotEmpty
        ? MemoryCanonicalKeys.normalize(key)
        : key;
    final action = _hasExistingKey(existing, canonicalKey) ? 'update' : 'save';
    return MemoryAgentAction(
      action: action,
      type: type,
      key: canonicalKey,
      value: value,
      scope: scope,
      confidence: confidence,
      sensitivity: 'low',
      reason: reason,
    );
  }

  bool _hasExistingKey(List<Memory> existing, String key) {
    final canonicalTarget = MemoryCanonicalKeys.normalize(key);
    return existing.any((memory) {
      if (memory.deletedAt != null) return false;
      final mKey = MemoryCanonicalKeys.normalize(
        memory.key.isNotEmpty ? memory.key : Memory.inferKey(memory.content),
      );
      return mKey == canonicalTarget;
    });
  }

  MemoryAgentAction _ignore(String reason) {
    return MemoryAgentAction(
      action: 'ignore',
      type: 'ignore',
      key: 'none',
      value: '',
      scope: 'chat',
      confidence: 0,
      sensitivity: 'low',
      reason: reason,
    );
  }

  bool _containsSecret(String value) {
    return RegExp(
      r'(api[_ -]?key\s*(?:is|=|:)|password\s*(?:is|=|:)|kata[_ -]?sandi\s*(?:is|=|:)|pin\s*(?:is|=|:)|token\s*(?:is|=|:)|cookie\s*(?:is|=|:)|private[_ -]?key|bearer\s+[a-z0-9._-]{12,}|sk-[a-z0-9_-]{12,}|AIza[0-9A-Za-z_-]{20,})',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _containsHighSensitivity(String lower) {
    return RegExp(
      r'\b(religion|political view|politics|diagnosed|diagnosis|disease|therapy|lawsuit|criminal|sexual|bank account|credit card|government id|passport|ssn|home address|nomor ktp|nik|nomor kk|kartu kredit|rekening bank|kata sandi|penyakit menular)\b',
    ).hasMatch(lower);
  }

  String? _firstMatch(String value, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      final group = match?.group(1);
      if (group != null) return _trimClause(group);
    }
    return null;
  }

  String _clean(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _trimClause(String value) {
    return _clean(value)
        .replaceAll(RegExp(r'^[,.:;\s]+'), '')
        .replaceAll(RegExp(r'["“”]+'), '')
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();
  }

  String _titleName(String value) {
    return _trimClause(value)
        .split(RegExp(r'\s+'))
        .take(3)
        .map((part) {
          if (part.isEmpty) return part;
          return part.substring(0, 1).toUpperCase() +
              part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  bool _looksLikeActivity(String value) {
    final first = _normalize(value).split(' ').firstOrNull ?? '';
    return {
      'building',
      'using',
      'trying',
      'working',
      'running',
      'facing',
      'asking',
      'looking',
      'testing',
      'not',
      'going',
      'doing',
      'writing',
      'fixing',
      'creating',
      'making',
      'interested',
      'glad',
      'happy',
      'sad',
      'sorry',
      'sure',
      'just',
      'really',
      'currently',
      'feeling',
      'sedang',
      'lagi',
      'mencoba',
      'membuat',
      'bikin',
      'bukan',
      'mau',
    }.contains(first);
  }

  bool _temporaryAnimalMention(String normalized) {
    return normalized.contains('saw ') ||
        normalized.contains('today') ||
        normalized.contains('near my house') ||
        normalized.contains('passed by') ||
        normalized.contains('tadi ') ||
        normalized.contains('melihat ') ||
        normalized.contains('lewat ');
  }

  String _numberWordToDigit(String value) {
    final lower = value.toLowerCase();
    const words = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'satu': '1',
      'dua': '2',
      'tiga': '3',
      'empat': '4',
      'lima': '5',
    };
    return words[lower] ?? value;
  }

  String _pluralizePet(String animal, String count) {
    final lower = animal.toLowerCase();
    if (lower == 'kucing' || lower == 'anjing' || lower == 'burung' || lower == 'ikan' || lower == 'kelinci') {
      return lower;
    }
    final singular = lower.replaceAll(RegExp(r's$'), '');
    return count == '1' ? singular : '${singular}s';
  }

  String _uiPreferenceValue(String lower) {
    if (lower.contains('preserve') || lower.contains('same ui')) {
      return 'User prefers preserving existing UI identity instead of redesigning it.';
    }
    if (lower.contains('premium')) return 'User prefers premium UI design.';
    if (lower.contains('minimal')) return 'User prefers minimal UI design.';
    return 'User prefers lightweight UI design.';
  }

  String _stableCustomKey(String value) {
    final stopWords = {
      'user', 'the', 'that', 'this', 'with', 'from', 'about', 'saya', 'aku',
      'bahwa', 'untuk', 'dan', 'dengan', 'yang', 'pada', 'adalah',
    };
    final words = _normalize(value)
        .split(' ')
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .take(3)
        .join('_');
    return words.isEmpty ? 'topic.custom_${DateTime.now().millisecondsSinceEpoch}' : 'topic.$words';
  }

  String _memorySentence(String content) {
    final trimmed = _trimClause(content);
    if (trimmed.toLowerCase().startsWith('user ')) return '$trimmed.';
    if (trimmed.toLowerCase().startsWith('i ')) {
      return 'User ${trimmed.substring(2)}.';
    }
    if (trimmed.toLowerCase().startsWith('saya ') || trimmed.toLowerCase().startsWith('aku ')) {
      return 'User ${trimmed.replaceFirst(RegExp(r'^(?:saya|aku)\s+', caseSensitive: false), '')}.';
    }
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  String _typeForKey(String key) {
    if (key.startsWith('pref.')) return 'preference';
    if (key.startsWith('project')) return 'project_memory';
    if (key.startsWith('user.')) return 'personal_fact';
    return 'ignore';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
