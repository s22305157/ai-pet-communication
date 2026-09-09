import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature import boundaries remain explicit', () {
    final violations = <String>[];
    // Exact legacy edges are frozen; journal code has no exceptions.
    final legacy =
        (jsonDecode(
                  File(
                    'test/architecture/legacy_imports.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<String>()
            .toSet();
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll('\\', '/');
      final feature = RegExp(r'lib/features/([^/]+)/').firstMatch(path)?[1];
      for (final match in RegExp(
        r'''(?:import|export) ['"]([^'"]+)['"]''',
      ).allMatches(file.readAsStringSync())) {
        final uri = match[1]!;
        if ((path.contains('/domain/') || path.startsWith('lib/models/')) &&
            (uri.contains('firebase') ||
                uri.contains('cloud_firestore') ||
                uri.startsWith('package:flutter/'))) {
          violations.add('$path: domain imports $uri');
        }
        if (path.contains('/application/') &&
            (uri.contains('get_it') || uri.endsWith('injection.dart'))) {
          violations.add('$path: application resolves dependencies from $uri');
        }
        final resolved = uri.startsWith('package:ai_pet_communication/')
            ? 'lib/${uri.substring('package:ai_pet_communication/'.length)}'
            : file.absolute.uri
                  .resolve(uri)
                  .normalizePath()
                  .path
                  .replaceAll('\\', '/');
        final edge = '$path -> $uri';
        final layer = RegExp(
          r'features/([^/]+)/(data|presentation)/',
        ).firstMatch(resolved);
        if (layer != null && feature != null) {
          final invalid =
              ((path.contains('/application/') ||
                      path.contains('/presentation/')) &&
                  layer[2] == 'data') ||
              (path.contains('/presentation/') &&
                  layer[2] == 'presentation' &&
                  layer[1] != feature);
          if (invalid && (!legacy.contains(edge) || feature == 'journal')) {
            violations.add('$path: layer boundary imports $uri');
          }
        }
        final dependency = RegExp(
          r'features/([^/]+)/data/',
        ).firstMatch(resolved);
        if (dependency != null && feature != null && dependency[1] != feature) {
          violations.add(
            '$path: imports another feature data implementation $uri',
          );
        }
      }
    }
    expect(violations, isEmpty);
  });
}
