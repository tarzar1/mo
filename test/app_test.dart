import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:commute_share/main.dart';

void main() {
  group('CommuteShare App Tests', () {
    testWidgets('App loads without errors', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: CommuteShareApp()));
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
