import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'support/browser_test_assets_stub.dart'
    if (dart.library.js_interop) 'support/browser_test_assets_web.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installBrowserTestAssets);
  await testMain();
}
