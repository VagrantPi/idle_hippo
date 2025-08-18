// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:idle_hippo/main.dart';

void main() {
  testWidgets('Idle Hippo main screen displays title and initial value', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const IdleHippoApp());

    // Verify that the title "Idle Hippo" is displayed
    expect(find.text('Idle Hippo'), findsOneWidget);
    
    // Verify that the initial value "0" is displayed
    expect(find.text('0'), findsOneWidget);
    
    // Verify that the app uses the correct background color
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.lightGreen[50]);
  });
}
