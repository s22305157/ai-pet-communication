import 'package:flutter/material.dart';
import '../features/pilot/application/pilot_controller.dart';
import '../features/pilot/domain/pilot_repository.dart';

class PilotSurface<T> extends StatefulWidget {
  final String title;
  final PilotRepository repository;
  final PilotLoader<T> loader;
  final Widget Function(BuildContext, PilotController<T>) builder;
  const PilotSurface({
    super.key,
    required this.title,
    required this.repository,
    required this.loader,
    required this.builder,
  });
  @override
  State<PilotSurface<T>> createState() => _PilotSurfaceState<T>();
}

class _PilotSurfaceState<T> extends State<PilotSurface<T>>
    with WidgetsBindingObserver {
  late final c = PilotController<T>(widget.repository, () => widget.loader());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: c.busy ? null : c.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              if (c.busy) const LinearProgressIndicator(),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(c.error!),
                ),
              if (c.current)
                Expanded(child: widget.builder(context, c))
              else
                const Text('請返回首頁重新登入'),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> pilotTextDialog(
  BuildContext context,
  String title, {
  String initial = '',
  int maxLength = 500,
}) async {
  final text = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        maxLength: maxLength,
        minLines: 2,
        maxLines: 6,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (text.text.trim().isNotEmpty) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: const Text('確認'),
        ),
      ],
    ),
  );
  // Dialog exit animation can still reference the controller for this frame.
  WidgetsBinding.instance.addPostFrameCallback((_) => text.dispose());
  return result;
}

Future<bool> pilotConfirm(
  BuildContext context,
  String title,
  String content,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    ) ??
    false;
