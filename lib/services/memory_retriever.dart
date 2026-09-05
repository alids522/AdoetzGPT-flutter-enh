import 'dart:math';

import '../models.dart';

/// Contextual relevance retrieval engine for persistent memories.
/// Replaces blunt top-20 dumps with BM25 lexical relevance scoring + Core Profile prioritization.
class MemoryRetriever {
  const MemoryRetriever._();

  static const Set<String> _stopwords = {
    // English
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
    'and', 'any', 'are', 'arent', 'as', 'at', 'be', 'because', 'been',
    'before', 'being', 'below', 'between', 'both', 'but', 'by', 'cant',
    'cannot', 'could', 'couldnt', 'did', 'didnt', 'do', 'does', 'doesnt',
    'doing', 'dont', 'down', 'during', 'each', 'few', 'for', 'from',
    'further', 'had', 'hadnt', 'has', 'hasnt', 'have', 'havent', 'having',
    'he', 'hed', 'hell', 'hes', 'her', 'here', 'heres', 'hers', 'herself',
    'him', 'himself', 'his', 'how', 'hows', 'i', 'id', 'ill', 'im', 'ive',
    'if', 'in', 'into', 'is', 'isnt', 'it', 'its', 'itself', 'lets', 'me',
    'more', 'most', 'mustnt', 'my', 'myself', 'no', 'nor', 'not', 'of',
    'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our', 'ours',
    'ourselves', 'out', 'over', 'own', 'same', 'shant', 'she', 'shed',
    'shell', 'shes', 'should', 'shouldnt', 'so', 'some', 'such', 'than',
    'that', 'thats', 'the', 'their', 'theirs', 'them', 'themselves',
    'then', 'there', 'theres', 'these', 'they', 'theyd', 'theyll', 'theyre',
    'theyve', 'this', 'those', 'through', 'to', 'too', 'under', 'until',
    'up', 'very', 'was', 'wasnt', 'we', 'wed', 'well', 'were', 'werent',
    'weve', 'what', 'whats', 'when', 'whens', 'where', 'wheres', 'which',
    'while', 'who', 'whos', 'whom', 'why', 'whys', 'with', 'wont', 'would',
    'wouldnt', 'you', 'youd', 'youll', 'youre', 'youve', 'your', 'yours',
    'yourself', 'yourselves',

    // Indonesian
    'ada', 'adalah', 'adanya', 'adapun', 'agak', 'agar', 'akan', 'akankah',
    'akhir', 'akhiri', 'akhirnya', 'aku', 'akulah', 'amat', 'amatlah', 'anda',
    'andalah', 'antar', 'antara', 'antaranya', 'apa', 'apaan', 'apabila',
    'apakah', 'apalagi', 'apatah', 'artinya', 'asal', 'asalkan', 'atas',
    'atau', 'ataukah', 'ataupun', 'awal', 'awalnya', 'bagai', 'bagaikan',
    'bagaimana', 'bagaimanakah', 'bagaimanapun', 'bagi', 'bagian', 'bahkan',
    'bahwa', 'bahwasanya', 'baik', 'bakal', 'bakalan', 'balik', 'banyak',
    'bapak', 'baru', 'bawah', 'beberapa', 'begini', 'beginian', 'beginikah',
    'beginilah', 'begitu', 'begitukah', 'begitulah', 'begitupun', 'bekerja',
    'belakang', 'belakangan', 'belum', 'belumlah', 'benar', 'benarkah',
    'benarlah', 'berada', 'berakhir', 'berakhirlah', 'berakhirnya', 'berapa',
    'berapakah', 'berapalah', 'berapapun', 'berarti', 'berawal', 'berbagai',
    'berdatangan', 'beri', 'berikan', 'berikut', 'berikutnya', 'berjumlah',
    'berkata', 'berkehendak', 'berkeinginan', 'berkenaan', 'berlainan',
    'berlalu', 'berlangsung', 'berlebihan', 'bermacam', 'bermaksud',
    'bermula', 'bersama', 'bersiap', 'bertanya', 'berturut', 'bertutur',
    'berujar', 'berupa', 'besar', 'betul', 'betulkah', 'biasa', 'biasanya',
    'bila', 'bilakah', 'bisa', 'bisakah', 'boleh', 'bolehkah', 'bolehlah',
    'buat', 'bukan', 'bukankah', 'bukanlah', 'bukannya', 'cuma', 'percuma',
    'dahulu', 'dalam', 'dan', 'dapat', 'dari', 'daripada', 'dekat', 'demi',
    'demikian', 'demikianlah', 'dengan', 'depan', 'di', 'dia', 'diam',
    'dialah', 'dini', 'diri', 'dirinya', 'disebut', 'disebutkan',
    'disebutkannya', 'disini', 'disinilah', 'disitu', 'disitulah', 'ditandaskan',
    'ditanya', 'ditanyai', 'ditegaskan', 'ditujukan', 'ditunjuk', 'ditunjuki',
    'ditunjukkan', 'ditunjukkannya', 'ditunjuknya', 'dituturkan',
    'dituturkannya', 'diucapkan', 'diucapkannya', 'diungkapkan', 'dong',
    'dua', 'dulu', 'empat', 'enggak', 'enggaknya', 'entah', 'entahlah',
    'guna', 'gunakan', 'hal', 'hampir', 'hanya', 'hanyalah', 'hari', 'harus',
    'haruslah', 'harusnya', 'hendak', 'hendaklah', 'hendaknya', 'hingga',
    'ia', 'ialah', 'ibarat', 'ibaratkan', 'ibaratnya', 'ibu', 'ikut',
    'ingat', 'ingin', 'inginkah', 'inginkan', 'ini', 'inikah', 'inilah',
    'itu', 'itukah', 'itulah', 'jadi', 'jadilah', 'jadinya', 'jangan',
    'jangankan', 'janganlah', 'jauh', 'jawab', 'jawaban', 'jawabnya',
    'jelas', 'jelaskan', 'jelaslah', 'jelasnya', 'jika', 'jikalau', 'juga',
    'jumlah', 'jumlahnya', 'justru', 'kala', 'kalau', 'kalaulah', 'kalaupun',
    'kalian', 'kami', 'kamilah', 'kamu', 'kamulah', 'kan', 'kapan',
    'kapankah', 'kapanpun', 'karena', 'karenanya', 'kasus', 'kata',
    'katakan', 'katakanlah', 'katanya', 'ke', 'keadaan', 'kebetulan',
    'kecil', 'kedua', 'keduanya', 'keinginan', 'kelamaan', 'kelihatan',
    'kelihatannya', 'kelima', 'keluar', 'kembali', 'kemudian', 'kemungkinan',
    'kemungkinannya', 'kenapa', 'kepada', 'kepadanya', 'kesampaian',
    'keseluruhan', 'keseluruhannya', 'keterlaluan', 'ketika', 'khususnya',
    'kini', 'kinilah', 'kira', 'kiranya', 'kita', 'kitalah', 'kok', 'kurang',
    'lagi', 'lagian', 'lah', 'lain', 'lainnya', 'lalu', 'lama', 'lamanya',
    'lanjut', 'lanjutnya', 'lebih', 'lewat', 'lima', 'luar', 'macam',
    'maka', 'makanya', 'makin', 'malah', 'malahan', 'mampu', 'mampukah',
    'mana', 'manakala', 'manalagi', 'masih', 'masihkah', 'masing', 'mau',
    'maupun', 'melainkan', 'melakukan', 'melalui', 'melihat', 'melihatnya',
    'memang', 'memastikan', 'memberi', 'memberikan', 'membuat', 'memerlukan',
    'memihak', 'meminta', 'memintakan', 'memisalkan', 'memperbuat',
    'mempergunakan', 'memperkirakan', 'memperlihatkan', 'mempersiapkan',
    'mempersoalkan', 'mempertanyakan', 'mempunyai', 'memulai', 'memungkinkan',
    'menaiki', 'menandaskan', 'menanti', 'menantikan', 'menanya', 'menanyai',
    'menanyakan', 'mendapat', 'mendapatkan', 'mendatang', 'mendatangi',
    'mendatangkan', 'menegaskan', 'mengakhiri', 'mengapa', 'mengatakan',
    'mengatakannya', 'mengenai', 'mengerjakan', 'mengetahui', 'menggunakan',
    'menghendaki', 'mengibaratkan', 'mengibaratkannya', 'mengingat',
    'mengingatkan', 'menginginkan', 'mengira', 'mengucapkan', 'mengucapkannya',
    'mengungkapkan', 'menjadi', 'menjawab', 'menuju', 'menunjuk', 'menunjuki',
    'menunjukkan', 'menunjuknya', 'menurut', 'menurutnya', 'menuturkan',
    'menyampaikan', 'menyangkut', 'menyatakan', 'menyebutkan', 'menyeluruh',
    'menyiapkan', 'merasa', 'mereka', 'merekalah', 'merupakan', 'meski',
    'meskipun', 'meyakini', 'meyakinkan', 'minta', 'mirip', 'misal',
    'misalkan', 'misalnya', 'mula', 'mulai', 'mulailah', 'mulanya', 'mungkin',
    'mungkinkah', 'nah', 'naik', 'namun', 'nanti', 'nantinya', 'nyaris',
    'nyatanya', 'oleh', 'olehnya', 'orang', 'pada', 'padahal', 'padanya',
    'pak', 'paling', 'panjang', 'pantas', 'para', 'pasti', 'pastilah',
    'penting', 'pentingnya', 'per', 'pernah', 'persoalan', 'perlu',
    'pertama', 'pertanyaan', 'pihak', 'pula', 'pun', 'punya', 'rasa', 'rasanya',
    'rata', 'rupanya', 'saat', 'saatnya', 'saja', 'sajalah', 'saling', 'sama',
    'sambil', 'sampai', 'sana', 'sangat', 'sangatlah', 'satu', 'saya', 'sayalah',
    'sebab', 'sebabnya', 'sebagai', 'sebagaimana', 'sebagainya', 'sebagian',
    'sebaik', 'sebaiknya', 'sebaliknya', 'sebanyak', 'sebegini', 'sebegitu',
    'sebelum', 'sebelumnya', 'sebenarnya', 'seberapa', 'sebesar', 'sebetulnya',
    'sebisanya', 'sebuah', 'secara', 'secukupnya', 'sedang', 'sedangkan',
    'sedemikian', 'sedikit', 'sedikitnya', 'seenaknya', 'segala', 'segalanya',
    'segera', 'seharusnya', 'sehingga', 'seingat', 'sejak', 'sejauh', 'sejenak',
    'sejumlah', 'sekadar', 'sekadarnya', 'sekali', 'sekalian', 'sekaligus',
    'sekalipun', 'sekarang', 'sekaranglah', 'sekecil', 'seketika', 'sekiranya',
    'sekitar', 'sekitarnya', 'sekurang', 'sekurangnya', 'sela', 'selain',
    'selaku', 'selalu', 'selama', 'selamanya', 'selanjutnya', 'seluruh',
    'seluruhnya', 'semacam', 'semakin', 'semampu', 'semampunya', 'semasa',
    'semasih', 'semata', 'semaunya', 'sementara', 'semisal', 'semisalnya',
    'sempat', 'semua', 'semuanya', 'semula', 'sendiri', 'sendirian', 'sendirinya',
    'seolah', 'seorang', 'sepanjang', 'sepantasnya', 'sepantasnyalah',
    'seperlunya', 'seperti', 'sepertinya', 'sering', 'seringnya', 'serta',
    'serupa', 'sesaat', 'sesama', 'sesampai', 'sesegera', 'sesekali', 'seseorang',
    'sesuatu', 'sesuatunya', 'sesudah', 'sesudahnya', 'setelah', 'setempat',
    'setengah', 'seterusnya', 'setiap', 'setiba', 'setibanya', 'setidak',
    'setidaknya', 'setinggi', 'seusai', 'sewaktu', 'siap', 'siapa', 'siapakah',
    'siapapun', 'sini', 'sinilah', 'suatu', 'sudah', 'sudahlah', 'sudahkah',
    'tahu', 'tahun', 'tak', 'tambah', 'tampak', 'tampaknya', 'tengah',
    'tentang', 'tentu', 'tentulah', 'tentunya', 'tepat', 'terakhir', 'terasa',
    'terbanyak', 'terdahulu', 'terdapat', 'terdiri', 'terhadap', 'terhadapnya',
    'teringat', 'terjadi', 'terjadilah', 'terjadinya', 'terkira', 'terlalu',
    'terlebih', 'terlihat', 'termasuk', 'ternyata', 'tersampaikan', 'tersebut',
    'tersebutlah', 'tertentu', 'tertuju', 'terus', 'terutama', 'tetap',
    'tetapi', 'tiap', 'tiba', 'tidak', 'tidakkah', 'tidaklah', 'tidaknya',
    'toh', 'tunjuk', 'turut', 'tutur', 'tuturnya', 'ucap', 'ucapnya', 'ujar',
    'ujarnya', 'umum', 'umumnya', 'ungkap', 'ungkapnya', 'untuk', 'usah',
    'usai', 'waduh', 'wah', 'wahai', 'waktu', 'waktunya', 'walau', 'walaupun',
    'wong', 'yaitu', 'yakin', 'yakni', 'yang',
  };

  /// Core canonical keys that should always be prioritized if set
  static const Set<String> _coreKeys = {
    MemoryCanonicalKeys.userName,
    MemoryCanonicalKeys.userNickname,
    MemoryCanonicalKeys.prefLanguage,
    MemoryCanonicalKeys.prefTone,
  };

  /// Retrieves relevant memories using BM25 relevance scoring combined with core facts.
  static List<Memory> retrieve({
    required String query,
    required List<Memory> memories,
    int maxResults = 4,
  }) {
    final active = memories
        .where((m) => m.deletedAt == null && m.sensitivity != 'high')
        .toList();
    if (active.isEmpty) return const [];

    final queryTokens = _tokenize(query);

    // 1. Identify core profile facts (up to 2 items)
    final coreMemories = <Memory>[];
    final candidateMemories = <Memory>[];

    for (final memory in active) {
      final key = MemoryCanonicalKeys.normalize(
        memory.key.isNotEmpty ? memory.key : Memory.inferKey(memory.content),
      );
      if (_coreKeys.contains(key) && coreMemories.length < 2) {
        coreMemories.add(memory);
      } else {
        candidateMemories.add(memory);
      }
    }

    if (queryTokens.isEmpty || candidateMemories.isEmpty) {
      // If query has no substantive keywords (e.g. "halo", "ok"), return only core profile facts
      return coreMemories.take(maxResults).toList();
    }

    // 2. Score candidate memories via BM25 + key & recency boosting
    final scored = <_ScoredMemory>[];
    final totalDocs = candidateMemories.length;

    // Calculate document frequency (DF) for query tokens across candidates
    final docFrequency = <String, int>{};
    final docTokenLists = candidateMemories.map((m) => _tokenize(m.content)).toList();

    for (final token in queryTokens) {
      var count = 0;
      for (final tokens in docTokenLists) {
        if (tokens.contains(token)) count++;
      }
      docFrequency[token] = count;
    }

    final avgdl = docTokenLists.isEmpty
        ? 1.0
        : docTokenLists.map((t) => t.length).reduce((a, b) => a + b) / totalDocs;

    const k1 = 1.2;
    const b = 0.75;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Bilingual stem / synonym mapping for cross-lingual lexical matching
    const crossLingualMap = {
      'kucing': 'cats',
      'anjing': 'dogs',
      'hewan': 'pets',
      'peliharaan': 'pets',
      'bahasa': 'language',
      'lokasi': 'location',
      'tinggal': 'lives',
      'tempat': 'location',
    };

    final expandedTokens = <String>{...queryTokens};
    for (final q in queryTokens) {
      if (crossLingualMap.containsKey(q)) {
        expandedTokens.add(crossLingualMap[q]!);
      }
    }

    for (var i = 0; i < candidateMemories.length; i++) {
      final memory = candidateMemories[i];
      final docTokens = docTokenLists[i];
      final docLength = max(1, docTokens.length);

      var score = 0.0;
      final keyTokens = _tokenize(memory.key);

      for (final qToken in expandedTokens) {
        final df = docFrequency[qToken] ?? 0;
        final inKey = keyTokens.contains(qToken);

        // IDF calculation
        final idf = log(1.0 + (totalDocs - df + 0.5) / (max(1, df) + 0.5));

        // Term frequency in document
        final tf = docTokens.where((t) => t == qToken).length;
        if (tf == 0 && !inKey) continue;

        final num = (tf > 0 ? tf : 1) * (k1 + 1);
        final denom = (tf > 0 ? tf : 1) + k1 * (1 - b + b * (docLength / max(1.0, avgdl)));
        var termScore = idf * (num / max(0.001, denom));

        // Canonical key bonus: if query term matches memory key (e.g. 'flutter' in query and key is 'pref.framework')
        if (inKey) {
          termScore *= 1.5;
        }

        score += termScore;
      }

      if (score > 0.15) {
        // Recency boost (up to 20% boost within 14 days)
        final ageDays = max(0, (now - (memory.updatedAt ?? memory.timestamp)) / 86400000.0);
        final recencyBoost = 1.0 + 0.2 * exp(-ageDays / 14.0);
        scored.add(_ScoredMemory(memory: memory, score: score * recencyBoost));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Combine core profile memories with top-scoring contextual memories
    final result = <Memory>[...coreMemories];
    for (final item in scored) {
      if (result.length >= maxResults) break;
      if (!result.any((m) => m.id == item.memory.id)) {
        result.add(item.memory);
      }
    }

    return result;
  }

  /// Specialized retrieval for Realtime Live Voice context (keeps core profile + active topic).
  static List<Memory> retrieveCoreAndRelevant(List<Memory> memories, {int maxResults = 4}) {
    final active = memories
        .where((m) => m.deletedAt == null && m.sensitivity != 'high')
        .toList()
      ..sort((a, b) => (b.updatedAt ?? b.timestamp).compareTo(a.updatedAt ?? a.timestamp));

    final core = active.where((m) {
      final key = MemoryCanonicalKeys.normalize(
        m.key.isNotEmpty ? m.key : Memory.inferKey(m.content),
      );
      return _coreKeys.contains(key);
    }).take(2).toList();

    final remaining = active.where((m) => !core.contains(m)).take(maxResults - core.length).toList();
    return [...core, ...remaining];
  }

  static List<String> _tokenize(String text) {
    if (text.isEmpty) return const [];
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopwords.contains(w))
        .toList();
  }
}

class _ScoredMemory {
  const _ScoredMemory({required this.memory, required this.score});
  final Memory memory;
  final double score;
}
