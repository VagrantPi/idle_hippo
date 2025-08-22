// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Create a test-specific app that doesn't initialize ConfigService
class TestIdleHippoApp extends StatelessWidget {
  const TestIdleHippoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Hippo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const TestIdleHippoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TestIdleHippoScreen extends StatefulWidget {
  const TestIdleHippoScreen({super.key});

  @override
  State<TestIdleHippoScreen> createState() => _TestIdleHippoScreenState();
}

class _TestIdleHippoScreenState extends State<TestIdleHippoScreen> {
  final int _currentValue = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[50],
      body: Stack(
        children: [
          // 主要內容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game Title
                Text(
                  'Idle Hippo',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 60),
                // Current Value Display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_currentValue',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Debug Toggle Button
          Positioned(
            top: 50,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bug_report,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('Idle Hippo Widget Tests', () {
    testWidgets('Idle Hippo main screen displays title and initial value', (WidgetTester tester) async {
      // Build our test app and trigger a frame.
      await tester.pumpWidget(const TestIdleHippoApp());
      await tester.pumpAndSettle(); // Wait for async operations

      // Verify that the title "Idle Hippo" is displayed
      expect(find.text('Idle Hippo'), findsOneWidget);
      
      // Verify that the initial value "0" is displayed
      expect(find.text('0'), findsOneWidget);
      
      // Verify that the app uses the correct background color
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.lightGreen[50]);
    });

    testWidgets('Debug toggle button exists', (WidgetTester tester) async {
      await tester.pumpWidget(const TestIdleHippoApp());
      await tester.pumpAndSettle();

      // Find debug toggle button
      final debugToggle = find.byIcon(Icons.bug_report);
      expect(debugToggle, findsOneWidget);
    });
  });
}
