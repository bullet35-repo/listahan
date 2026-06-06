import 'package:flutter_test/flutter_test.dart';

import 'package:botoys_listhan/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BotoysListahanApp());
    expect(find.text("Botoy's Listahan"), findsOneWidget);
  });
}
