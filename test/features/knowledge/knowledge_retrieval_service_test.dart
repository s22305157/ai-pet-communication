import 'package:ai_pet_communication/features/knowledge/application/knowledge_retrieval_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'knowledge_test_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeRetrievalService service;
  setUp(
    () => service = KnowledgeRetrievalService(loader: loadKnowledgeTestIndex),
  );

  test('實際索引可依貓排尿急症召回安全片段', () async {
    final hits = await service.search(
      query: '貓咪一直進貓砂盆用力但沒有尿',
      species: '貓',
      limit: 4,
    );

    expect(hits, isNotEmpty);
    expect(hits.first.id, 'doc006-litter');
    expect(hits.first.safetyLevel, 'red_flag');
    expect(hits.first.content, contains('尿道阻塞'));
    expect(hits.first.sourcePath, endsWith('core_knowledge_base.md'));
  });

  test('實際索引可依物種召回多貓與犬隻獨處主題', () async {
    final catHits = await service.search(
      query: '新貓到家後跟原本的貓打架怎麼辦',
      species: '貓',
    );
    final dogHits = await service.search(
      query: '狗狗獨自在家一直叫，如何安排練習',
      species: '狗',
    );

    expect(catHits.first.id, 'doc006-multicat');
    expect(dogHits.first.id, 'doc004-separation');
  });

  test('召回結果有唯一 ID 且限制筆數', () async {
    final hits = await service.search(query: '寵物走失如何搜尋和記錄線索', limit: 3);

    expect(hits, hasLength(3));
    expect(hits.map((hit) => hit.id).toSet(), hasLength(3));
  });
}
