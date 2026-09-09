import 'package:flutter/material.dart';

class JournalTextFields extends StatelessWidget {
  const JournalTextFields({
    super.key,
    required this.observation,
    required this.action,
    required this.outcome,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController observation, action, outcome;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: observation,
        enabled: enabled,
        maxLength: 2000,
        minLines: 3,
        maxLines: 7,
        decoration: const InputDecoration(
          labelText: '我觀察到的事',
          hintText: '例如：今天牠第一次自己走進外出籠',
        ),
        onChanged: (_) => onChanged(),
      ),
      TextField(
        controller: action,
        enabled: enabled,
        maxLength: 500,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '我做過的事（選填）'),
        onChanged: (_) => onChanged(),
      ),
      TextField(
        controller: outcome,
        enabled: enabled,
        maxLength: 500,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '後來如何（選填）'),
        onChanged: (_) => onChanged(),
      ),
    ],
  );
}
