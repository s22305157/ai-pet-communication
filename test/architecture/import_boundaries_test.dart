import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature import boundaries remain explicit', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib/features',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll('\\', '/');
      final feature = path.split('/')[2];
      for (final match in RegExp(
        r'''(?:import|export) ['"]([^'"]+)['"]''',
      ).allMatches(file.readAsStringSync())) {
        final uri = match[1]!;
        if (path.contains('/domain/') &&
            (uri.contains('firebase') ||
                uri.contains('cloud_firestore') ||
                uri.startsWith('package:flutter/'))) {
          violations.add('$path: domain imports $uri');
        }
        if (path.contains('/application/') &&
            (uri.contains('get_it') || uri.endsWith('injection.dart'))) {
          violations.add('$path: application resolves dependencies from $uri');
        }
        final dependency = RegExp(r'features/([^/]+)/data/').firstMatch(uri);
        if (dependency != null && dependency[1] != feature) {
          violations.add(
            '$path: imports another feature data implementation $uri',
          );
        }
      }
    }
    expect(violations, isEmpty);
  });
}
