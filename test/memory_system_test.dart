import 'package:flutter_test/flutter_test.dart';
import 'package:adoetzgpt/models.dart';
import 'package:adoetzgpt/services/memory_agent.dart';
import 'package:adoetzgpt/services/memory_retriever.dart';

void main() {
  group('Canonical Keys Normalization & Inference', () {
    test('normalizes legacy and dotted keys to canonical keys', () {
      expect(MemoryCanonicalKeys.normalize('user_name'), equals(MemoryCanonicalKeys.userName));
      expect(MemoryCanonicalKeys.normalize('preferred_language'), equals(MemoryCanonicalKeys.prefLanguage));
      expect(MemoryCanonicalKeys.normalize('preferred_framework'), equals(MemoryCanonicalKeys.prefFramework));
      expect(MemoryCanonicalKeys.normalize('user.name'), equals(MemoryCanonicalKeys.userName));
      expect(MemoryCanonicalKeys.normalize('custom_random_topic'), equals('topic.custom_random_topic'));
    });

    test('infers canonical key from memory content', () {
      expect(
        MemoryCanonicalKeys.inferFromContent("User's name is Budi Pratama."),
        equals(MemoryCanonicalKeys.userName),
      );
      expect(
        MemoryCanonicalKeys.inferFromContent("User prefers Indonesian responses."),
        equals(MemoryCanonicalKeys.prefLanguage),
      );
      expect(
        MemoryCanonicalKeys.inferFromContent("User prefers Flutter for development."),
        equals(MemoryCanonicalKeys.prefFramework),
      );
      expect(
        MemoryCanonicalKeys.inferFromContent("User has 2 pet cats."),
        equals(MemoryCanonicalKeys.userPets),
      );
    });
  });

  group('Bilingual Memory Extraction (Indonesian & English)', () {
    test('extracts Indonesian name and nickname', () {
      const agent = MemoryAgent();
      final text = 'Halo AI, perkenalkan nama saya Budi Santoso, panggil aku Budi ya.';
      final actions = agent.analyze(message: text, existingMemories: const []);

      final saveActions = actions.where((a) => a.action == 'save' || a.action == 'update').toList();
      expect(saveActions.isNotEmpty, isTrue);

      final nameAction = saveActions.firstWhere((a) => a.key == MemoryCanonicalKeys.userName);
      expect(nameAction.value, contains('Budi Santoso'));

      final nickAction = saveActions.firstWhere((a) => a.key == MemoryCanonicalKeys.userNickname);
      expect(nickAction.value, contains('Budi'));
    });

    test('extracts Indonesian communication preferences (tone & brevity)', () {
      const agent = MemoryAgent();
      final text = 'Tolong kalau jawab santai aja ya, jangan bertele-tele.';
      final actions = agent.analyze(message: text, existingMemories: const []);

      final saveActions = actions.where((a) => a.action == 'save' || a.action == 'update').toList();
      expect(saveActions.any((a) => a.key == MemoryCanonicalKeys.prefTone), isTrue);
      final tone = saveActions.firstWhere((a) => a.key == MemoryCanonicalKeys.prefTone);
      expect(tone.value.toLowerCase(), anyOf(contains('casual'), contains('santai'), contains('concise'), contains('to the point')));
    });

    test('extracts Indonesian framework preference', () {
      const agent = MemoryAgent();
      final text = 'Gua lagi buat aplikasi mobile, lebih suka pakai flutter.';
      final actions = agent.analyze(message: text, existingMemories: const []);

      final saveActions = actions.where((a) => a.action == 'save' || a.action == 'update').toList();
      expect(saveActions.any((a) => a.key == MemoryCanonicalKeys.prefFramework), isTrue);
      final fw = saveActions.firstWhere((a) => a.key == MemoryCanonicalKeys.prefFramework);
      expect(fw.value, contains('Flutter'));
    });

    test('extracts explicit Indonesian remember command', () {
      const agent = MemoryAgent();
      final text = 'Ingat bahwa saya punya kucing namanya Momo.';
      final actions = agent.analyze(message: text, existingMemories: const []);

      final saveActions = actions.where((a) => a.action == 'save' || a.action == 'update').toList();
      expect(saveActions.isNotEmpty, isTrue);
      expect(saveActions.first.value, contains('kucing'));
      expect(saveActions.first.value, contains('Momo'));
    });

    test('extracts explicit Indonesian forget command', () {
      const agent = MemoryAgent();
      final text = 'Lupakan nama saya ya';
      final actions = agent.analyze(message: text, existingMemories: const []);

      final deleteActions = actions.where((a) => a.action == 'delete').toList();
      expect(deleteActions.isNotEmpty, isTrue);
      expect(deleteActions.first.key, equals(MemoryCanonicalKeys.userName));
    });

    test('rejects sensitive secrets and PII (Indonesian & English)', () {
      const agent = MemoryAgent();
      final text1 = 'Kata sandi akun saya adalah Rahasia12345';
      final text2 = 'Nomor KTP / NIK saya 3201234567890001';
      final text3 = 'My api key is sk-proj-1234567890abcdef123456';

      expect(agent.analyze(message: text1, existingMemories: const []).every((a) => a.action == 'ignore'), isTrue);
      expect(agent.analyze(message: text2, existingMemories: const []).every((a) => a.action == 'ignore'), isTrue);
      expect(agent.analyze(message: text3, existingMemories: const []).every((a) => a.action == 'ignore'), isTrue);
    });
  });

  group('BM25 Relevance & Core Fact Retrieval', () {
    final memories = [
      Memory(
        id: 'm1',
        key: MemoryCanonicalKeys.userName,
        content: "User's name is Budi Pratama.",
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
      ),
      Memory(
        id: 'm2',
        key: MemoryCanonicalKeys.prefLanguage,
        content: "User prefers Indonesian language for explanations.",
        timestamp: DateTime.now().millisecondsSinceEpoch - 9000,
      ),
      Memory(
        id: 'm3',
        key: MemoryCanonicalKeys.prefFramework,
        content: "User prefers Flutter framework for mobile development.",
        timestamp: DateTime.now().millisecondsSinceEpoch - 8000,
      ),
      Memory(
        id: 'm4',
        key: MemoryCanonicalKeys.userPets,
        content: "User has 2 domestic cats named Momo and Kuro.",
        timestamp: DateTime.now().millisecondsSinceEpoch - 7000,
      ),
      Memory(
        id: 'm5',
        key: MemoryCanonicalKeys.userLocation,
        content: "User lives in Bandung, Indonesia.",
        timestamp: DateTime.now().millisecondsSinceEpoch - 6000,
      ),
      Memory(
        id: 'm6_deleted',
        key: 'topic.deleted',
        content: "Old deleted secret info.",
        deletedAt: DateTime.now().millisecondsSinceEpoch - 1000,
        timestamp: DateTime.now().millisecondsSinceEpoch - 5000,
      ),
    ];

    test('prioritizes core profile facts on generic queries', () {
      final result = MemoryRetriever.retrieve(
        query: 'Halo apa kabar?',
        memories: memories,
        maxResults: 4,
      );

      expect(result.any((m) => m.id == 'm6_deleted'), isFalse);
      expect(result.any((m) => m.key == MemoryCanonicalKeys.userName), isTrue);
      expect(result.any((m) => m.key == MemoryCanonicalKeys.prefLanguage), isTrue);
      // Irrelevant pet or location should not be present on greeting
      expect(result.any((m) => m.key == MemoryCanonicalKeys.userPets), isFalse);
    });

    test('retrieves contextually scored framework memory for coding queries', () {
      final result = MemoryRetriever.retrieve(
        query: 'Bagaimana cara bikin widget custom stateful di flutter?',
        memories: memories,
        maxResults: 4,
      );

      expect(result.any((m) => m.key == MemoryCanonicalKeys.prefFramework), isTrue);
      // Core profile facts should still be preserved
      expect(result.any((m) => m.key == MemoryCanonicalKeys.userName), isTrue);
      // Pet memory is completely irrelevant and must not be returned
      expect(result.any((m) => m.key == MemoryCanonicalKeys.userPets), isFalse);
    });

    test('retrieves pet memory when query is about animals or pets', () {
      final result = MemoryRetriever.retrieve(
        query: 'Kira-kira makanan apa yang bagus buat kucing aku ya?',
        memories: memories,
        maxResults: 4,
      );

      expect(result.any((m) => m.key == MemoryCanonicalKeys.userPets), isTrue);
      // Framework is irrelevant here
      expect(result.any((m) => m.key == MemoryCanonicalKeys.prefFramework), isFalse);
    });

    test('retrieveCoreAndRelevant retrieves core profile plus recent items', () {
      final liveResult = MemoryRetriever.retrieveCoreAndRelevant(memories, maxResults: 3);
      expect(liveResult.length, equals(3));
      expect(liveResult.any((m) => m.id == 'm6_deleted'), isFalse);
      expect(liveResult.any((m) => m.key == MemoryCanonicalKeys.userName), isTrue);
    });
  });
}
