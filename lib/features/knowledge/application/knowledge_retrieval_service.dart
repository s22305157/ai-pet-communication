import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

typedef KnowledgeIndexLoader = Future<String> Function();

class KnowledgeHit {
  final String id;
  final String documentId;
  final String sectionId;
  final String title;
  final List<String> tags;
  final String safetyLevel;
  final String content;
  final String sourcePath;
  final int lineStart;
  final int lineEnd;
  final double score;

  const KnowledgeHit({
    required this.id,
    required this.documentId,
    required this.sectionId,
    required this.title,
    required this.tags,
    required this.safetyLevel,
    required this.content,
    required this.sourcePath,
    required this.lineStart,
    required this.lineEnd,
    required this.score,
  });

  factory KnowledgeHit.fromMap(Map<String, dynamic> map) => KnowledgeHit(
    id: map['id'] as String,
    documentId: map['documentId'] as String,
    sectionId: map['sectionId'] as String,
    title: map['title'] as String,
    tags: List<String>.from(map['tags'] as List? ?? const []),
    safetyLevel: map['safetyLevel'] as String,
    content: map['content'] as String,
    sourcePath: map['sourcePath'] as String? ?? 'protected-knowledge',
    lineStart: (map['lineStart'] as num?)?.toInt() ?? 0,
    lineEnd: (map['lineEnd'] as num?)?.toInt() ?? 0,
    score: (map['score'] as num).toDouble(),
  );

  Map<String, dynamic> toPromptMap({int maxContentLength = 1400}) {
    final excerpt = content.length <= maxContentLength
        ? content
        : '${content.substring(0, maxContentLength)}…';
    return {
      'chunk_id': id,
      'document_id': documentId,
      'section_id': sectionId,
      'title': title,
      'safety_level': safetyLevel,
      'content': excerpt,
      'source': '$sourcePath:$lineStart-$lineEnd',
    };
  }
}

class KnowledgeRetrievalService {
  static const Map<String, String> _queryExpansions = {
    '一直叫': '吠叫 哀鳴',
    '沒有尿': '無尿 排尿 尿道阻塞',
    '尿不出': '無尿 排尿 尿道阻塞',
    '打架': '衝突 攻擊',
    '獨自在家': '獨處 分離困擾',
    '撿到': '拾食 物品',
    '老貓': '高齡貓',
  };

  final KnowledgeIndexLoader? _loader;
  final FirebaseFunctions? _functions;
  Future<Map<String, dynamic>>? _cachedIndex;

  KnowledgeRetrievalService({
    KnowledgeIndexLoader? loader,
    FirebaseFunctions? functions,
  }) : _loader = loader,
       _functions =
           functions ?? (loader == null ? FirebaseFunctions.instance : null);

  Future<List<KnowledgeHit>> search({
    required String query,
    String species = '',
    int limit = 4,
  }) async {
    if (query.trim().isEmpty || limit <= 0) return const [];
    if (_loader == null) {
      return _searchRemote(query: query, species: species, limit: limit);
    }
    final index = await _loadIndex();
    final chunks = (index['chunks'] as List).cast<Map<String, dynamic>>();
    final invertedIndex = (index['inverted_index'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, List<String>.from(value as List)),
    );
    final chunkById = {
      for (final chunk in chunks) chunk['id'] as String: chunk,
    };

    final expanded = StringBuffer('$query $species');
    for (final entry in _queryExpansions.entries) {
      if (query.contains(entry.key)) expanded.write(' ${entry.value}');
    }
    final queryTerms = _terms(expanded.toString());
    final scores = <String, double>{};

    for (final term in queryTerms) {
      final postings = invertedIndex[term] ?? const [];
      final weight = 1.0 + (1.0 / (postings.isEmpty ? 1 : postings.length));
      for (final id in postings) {
        scores[id] = (scores[id] ?? 0) + weight;
      }
    }

    final normalizedSpecies = species.toLowerCase();
    final isCat =
        normalizedSpecies.contains('貓') || normalizedSpecies.contains('cat');
    final isDog =
        normalizedSpecies.contains('狗') ||
        normalizedSpecies.contains('犬') ||
        normalizedSpecies.contains('dog');

    for (final entry in scores.entries.toList()) {
      final chunk = chunkById[entry.key]!;
      final titleTerms = _terms(chunk['title'] as String);
      var score =
          entry.value + 2.0 * queryTerms.intersection(titleTerms).length;
      final tags = List<String>.from(chunk['tags'] as List);
      if (tags.contains('P')) score += 3.5;
      final documentId = chunk['document_id'] as String;
      if (isCat && documentId == 'doc-006') score += 2.0;
      if (isDog && (documentId == 'doc-004' || documentId == 'doc-005')) {
        score += 2.0;
      }
      scores[entry.key] = score;
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });

    return ranked
        .take(limit)
        .map((entry) {
          final chunk = chunkById[entry.key]!;
          final source = chunk['source'] as Map<String, dynamic>;
          return KnowledgeHit(
            id: entry.key,
            documentId: chunk['document_id'] as String,
            sectionId: chunk['section_id'] as String,
            title: chunk['title'] as String,
            tags: List<String>.from(chunk['tags'] as List),
            safetyLevel: chunk['safety_level'] as String,
            content: chunk['content'] as String,
            sourcePath: source['path'] as String,
            lineStart: source['line_start'] as int,
            lineEnd: source['line_end'] as int,
            score: entry.value,
          );
        })
        .toList(growable: false);
  }

  Future<List<KnowledgeHit>> _searchRemote({
    required String query,
    required String species,
    required int limit,
  }) async {
    final result = await _functions!.httpsCallable('retrieveKnowledge').call({
      'query': query,
      'species': species,
      'limit': limit.clamp(1, 5),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final hits = data['hits'];
    if (hits is! List)
      throw const FormatException('Invalid knowledge response');
    return hits
        .map(
          (hit) => KnowledgeHit.fromMap(Map<String, dynamic>.from(hit as Map)),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _loadIndex() {
    return _cachedIndex ??= _readAndValidateIndex();
  }

  Future<Map<String, dynamic>> _readAndValidateIndex() async {
    final decoded = jsonDecode(await _loader!());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('RAG index root must be an object');
    }
    if (decoded['schema_version'] != 1 ||
        decoded['chunks'] is! List ||
        decoded['inverted_index'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported or incomplete RAG index');
    }
    final stats = decoded['stats'];
    if (stats is! Map<String, dynamic> ||
        stats['chunk_count'] != (decoded['chunks'] as List).length) {
      throw const FormatException('RAG index statistics do not match chunks');
    }
    return decoded;
  }

  static Set<String> _terms(String input) {
    final text = input.toLowerCase();
    final result = <String>{};
    for (final match in RegExp(r'[a-z0-9][a-z0-9_-]+').allMatches(text)) {
      result.add(match.group(0)!);
    }
    for (final match in RegExp(
      r'[\u3400-\u4dbf\u4e00-\u9fff]+',
    ).allMatches(text)) {
      final span = match.group(0)!;
      for (final size in const [2, 3]) {
        for (var i = 0; i <= span.length - size; i++) {
          result.add(span.substring(i, i + size));
        }
      }
    }
    return result;
  }
}
