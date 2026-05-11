import 'package:flutter_test/flutter_test.dart';

import 'package:matrix_app/main.dart';

void main() {
  testWidgets('App renders scan screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MatrixApp());
    expect(find.text('Matrix LED 8x8'), findsOneWidget);
  });
}
