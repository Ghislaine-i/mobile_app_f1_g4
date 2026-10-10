import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app_f1_g4/main.dart';

void main() {
  testWidgets('App opens to the sign in screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TrackerApp());

    expect(find.text('Project & Task\nTracker app'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);
  });
}
