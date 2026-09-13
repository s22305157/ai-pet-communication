import 'package:flutter/material.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/app/injection.dart';
import '../domain/planet_card.dart';
import '../domain/planet_collection_repository.dart';

class PetPlanetScreen extends StatelessWidget {
  final PlanetCollectionRepository? repository;
  const PetPlanetScreen({super.key, this.repository});
  @override
  Widget build(BuildContext context) {
    final source =
        repository ??
        (getIt.isRegistered<PlanetCollectionRepository>()
            ? getIt<PlanetCollectionRepository>()
            : null);
    if (source == null) return const PlanetCatalog(collectedIds: {});
    return StreamBuilder<PlanetCollection>(
      stream: source.watch(),
      builder: (context, snapshot) {
        final status = snapshot.hasError
            ? CollectionStatus.unavailable
            : snapshot.data?.status ?? CollectionStatus.loading;
        return PlanetCatalog(
          collectedIds: snapshot.data?.ids ?? {},
          status: switch (status) {
            CollectionStatus.signedOut => '登入後可查看收藏',
            CollectionStatus.loading => '正在載入收藏…',
            CollectionStatus.unavailable => '收藏暫時無法載入，請稍後重新開啟圖鑑',
            CollectionStatus.ready => null,
          },
        );
      },
    );
  }
}

class PlanetCatalog extends StatelessWidget {
  final Set<String> collectedIds;
  final String? status;
  const PlanetCatalog({super.key, required this.collectedIds, this.status});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('寵物星球圖鑑')),
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每一張卡，都是更懂牠的一小步。',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status ??
                        '已收藏 ${planetCards.where((card) => collectedIds.contains(card.id)).length}／${planetCards.length} 張・依溝通知識點收集',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.crossAxisExtent / 280)
                    .floor()
                    .clamp(1, 4);
                // Each row sizes to its text, including accessibility text scaling.
                return SliverList.builder(
                  itemCount: (planetCards.length / columns).ceil(),
                  itemBuilder: (context, row) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(columns, (column) {
                        final index = row * columns + column;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: column < columns - 1 ? 16 : 0,
                            ),
                            child: index < planetCards.length
                                ? _CardTile(
                                    card: planetCards[index],
                                    collected: collectedIds.contains(
                                      planetCards[index].id,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _CardTile extends StatelessWidget {
  final PlanetCard card;
  final bool collected;
  const _CardTile({required this.card, required this.collected});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _CardDetailScreen(card: card, collected: collected),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardImage(card: card, collected: collected),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.id}・${card.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(card.category),
                const SizedBox(height: 8),
                Text(
                  collected ? '已收藏' : '尚未收藏・預覽',
                  style: TextStyle(
                    color: collected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CardDetailScreen extends StatelessWidget {
  final PlanetCard card;
  final bool collected;
  const _CardDetailScreen({required this.card, required this.collected});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${card.id}・${card.title}')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardImage(card: card, collected: collected),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('放大查看卡片'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(card.title)),
                        body: SafeArea(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: Center(
                              child: _CardImage(
                                card: card,
                                collected: collected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  card.category,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  card.petVoice,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Text('知識點', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(card.knowledgePoint),
                const SizedBox(height: 20),
                Text(
                  card.source,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CardImage extends StatelessWidget {
  final PlanetCard card;
  final bool collected;
  const _CardImage({required this.card, required this.collected});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2 / 3,
    child: ColorFiltered(
      colorFilter: collected
          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
          : const ColorFilter.matrix([
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
      child: Image.asset(
        card.imageAsset,
        fit: BoxFit.contain,
        semanticLabel: '${card.title}：${card.knowledgePoint}',
        errorBuilder: (_, _, _) => const Center(child: Text('卡片圖片暫時無法載入')),
      ),
    ),
  );
}
