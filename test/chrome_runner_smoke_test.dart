import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chrome Flutter runner smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Chrome ready')));
    expect(find.text('Chrome ready'), findsOneWidget);
  });
}
