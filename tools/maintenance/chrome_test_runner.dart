import 'dart:convert';
import 'dart:io';

// Serve only Flutter's generated test bundle, never the project or user files.
Future<void> main(List<String> args) async {
  final sdk = args.first;
  final dart =
      '$sdk/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
  final toolArgs = [
    '--packages=$sdk/packages/flutter_tools/.dart_tool/package_config.json',
    '$sdk/bin/cache/flutter_tools.snapshot',
  ];
  Future<int> flutter(List<String> arguments) async {
    final process = await Process.start(dart, [...toolArgs, ...arguments]);
    final result = await Future.wait([
      process.exitCode,
      stdout.addStream(process.stdout).then((_) => 0),
      stderr.addStream(process.stderr).then((_) => 0),
    ]);
    return result.first;
  }

  // This refreshes the real bundle and its manifest when assets have changed.
  exitCode = await flutter([
    'test',
    '--no-pub',
    '--reporter',
    'expanded',
    'test/chrome_runner_smoke_test.dart',
  ]);
  if (exitCode != 0) return;

  final bundle = Directory('build/unit_test_assets').absolute;
  final files = <String, File>{};
  await for (final entry in bundle.list(recursive: true, followLinks: false)) {
    if (entry is File) {
      files[entry.path.substring(bundle.path.length).replaceAll('\\', '/')] =
          entry;
    }
  }
  files['/__test_fonts/Ahem.ttf'] = File(
    '$sdk/packages/flutter_tools/static/Ahem.ttf',
  );
  // Flutter Web uses a JSON/base64 representation of this same binary manifest.
  final webManifest = jsonEncode(
    base64Encode(await files['/AssetManifest.bin']!.readAsBytes()),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');
    try {
      final path = Uri.decodeComponent(request.uri.path);
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (path == '/AssetManifest.bin.json') {
        response.headers.contentType = ContentType.json;
        response.write(webManifest);
      } else if (files[path] case final file?) {
        await response.addStream(file.openRead());
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  });
  try {
    exitCode = await flutter([
      'test',
      '--no-pub',
      '--platform',
      'chrome',
      '--timeout',
      '90s',
      '--reporter',
      'expanded',
      '--dart-define=PAWLINK_TEST_ASSET_BASE=http://127.0.0.1:${server.port}/',
      ...args.skip(1),
    ]);
  } finally {
    await server.close(force: true);
  }
}
