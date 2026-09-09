import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';
import 'journal_image.dart';

class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.repository,
    required this.enabled,
    required this.canWrite,
    required this.onSelected,
  });
  final JournalEntry entry;
  final JournalRepository repository;
  final bool enabled;
  final bool canWrite;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('yyyy/MM/dd HH:mm').format(entry.occurredAt)} · ${entry.context}',
                ),
              ),
              PopupMenuButton<String>(
                enabled: enabled,
                onSelected: onSelected,
                itemBuilder: (_) => [
                  if (canWrite)
                    const PopupMenuItem(value: 'edit', child: Text('編輯')),
                  const PopupMenuItem(value: 'delete', child: Text('刪除')),
                ],
              ),
            ],
          ),
          if (entry.observation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(entry.observation),
            ),
          if (entry.action.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText('我做過的事\n${entry.action}'),
            ),
          if (entry.outcome.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText('後來如何\n${entry.outcome}'),
            ),
          if (entry.mediaIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.mediaIds
                    .map(
                      (id) => JournalImage(
                        key: ValueKey('${entry.revision}/$id'),
                        repository: repository,
                        mediaId: id,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}
